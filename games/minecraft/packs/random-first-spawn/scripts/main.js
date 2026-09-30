// Sends each player to a random overworld spot on their very first join, and
// makes that spot their personal spawn point until they sleep in a bed.
// Uses only the stable @minecraft/server API (no Beta APIs / experiments).
import { system, world } from "@minecraft/server";

const MIN_DISTANCE = 500;
const MAX_DISTANCE = 2500;
const MAX_ATTEMPTS = 8; // re-roll when landing on water/lava
const DROP_HEIGHT = 300;
const CHUNK_WAIT_TICKS = 400; // give up waiting for terrain after ~20s
const PLACED_TAG = "rfs:placed";

function randomTarget() {
  const center = world.getDefaultSpawnLocation();
  const angle = Math.random() * 2 * Math.PI;
  // Uniform over the ring area, not biased toward the inner edge.
  const r = Math.sqrt(Math.random() * (MAX_DISTANCE ** 2 - MIN_DISTANCE ** 2) + MIN_DISTANCE ** 2);
  return {
    x: Math.floor(center.x + r * Math.cos(angle)) + 0.5,
    z: Math.floor(center.z + r * Math.sin(angle)) + 0.5,
  };
}

function place(player, attempt) {
  const overworld = world.getDimension("overworld");
  const target = randomTarget();

  // Hold the player safely in the air while the destination chunk generates.
  player.addEffect("slow_falling", 600, { showParticles: false });
  player.addEffect("resistance", 600, { amplifier: 255, showParticles: false });
  player.teleport({ x: target.x, y: DROP_HEIGHT, z: target.z }, { dimension: overworld });

  let waited = 0;
  const run = system.runInterval(() => {
    waited += 5;
    if (!player.isValid) {
      system.clearRun(run);
      return;
    }

    let top;
    try {
      top = overworld.getTopmostBlock({ x: target.x, z: target.z });
    } catch {
      top = undefined; // chunk not loaded yet
    }
    if (!top) {
      if (waited >= CHUNK_WAIT_TICKS) system.clearRun(run);
      return;
    }
    system.clearRun(run);

    if (top.isLiquid && attempt < MAX_ATTEMPTS) {
      place(player, attempt + 1);
      return;
    }

    const spot = { x: target.x, y: top.location.y + 1, z: target.z };
    player.teleport(spot, { dimension: overworld });
    player.setSpawnPoint({ ...spot, dimension: overworld });
    player.addTag(PLACED_TAG);
    player.removeEffect("slow_falling");
    system.runTimeout(() => {
      if (player.isValid) player.removeEffect("resistance");
    }, 100);
    player.sendMessage(`§eようこそ！ランダムな場所 (${Math.floor(spot.x)}, ${spot.y}, ${Math.floor(spot.z)}) からスタートです。仲間を探しに行こう！`);
  }, 5);
}

world.afterEvents.playerSpawn.subscribe(({ player, initialSpawn }) => {
  if (!initialSpawn || player.hasTag(PLACED_TAG)) return;
  place(player, 0);
});

console.info("[RandomFirstSpawn] loaded");
