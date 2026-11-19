# Neon Knockout (Roblox fighting game)

A 1v1 side-view fighting game for Roblox. It plays like a classic 2D fighter: two fighters on a flat line, health bars, combos, blocking, special moves, a 3-bar super meter and best-of-3 rounds. The fighters, names and look are original.

## How to open it

**Easy way:** download `NeonKnockout.rbxlx`, open it in Roblox Studio (File > Open from File), and press Play. The arena builds itself when the game starts.

**If the file won't open,** make a new Baseplate place and copy the scripts in by hand:

| Make this in Studio | Where | Paste the code from |
|---|---|---|
| ModuleScript named `FightConfig` | ReplicatedStorage | `src/shared/FightConfig.lua` |
| Script named `FightServer` | ServerScriptService | `src/server/FightServer.server.lua` |
| LocalScript named `FightClient` | StarterPlayer > StarterPlayerScripts | `src/client/FightClient.client.lua` |

The names have to match exactly. If you use Rojo, `default.project.json` is set up too.

## How to play

Playing alone, you fight a training bot. With 2 or more players, the first two in line fight, the winner stays on and the loser goes to the back of the line. Pick your fighter with the panel on the left while you wait.

| Key | Move |
|---|---|
| A / D | Move |
| Space | Jump |
| J | Light attack (press up to 3 times for a chain) |
| K | Heavy attack (launches) |
| H | Grab (beats blocking, misses if they jump) |
| L | Special (projectile) |
| U | EX special, costs 1 bar of meter |
| I | Super, costs all 3 bars |
| F (hold) | Block |

Combos: when a move hits you can cancel it into a stronger one, so Light, Light, Light, Heavy, Special works. Each hit in a combo does a bit less damage. Blocking still takes a little chip damage. Meter builds when you hit or get hit and carries over between rounds.

Phones get on-screen buttons and gamepads are mapped as well.

## Fighters

- **Volt**: balanced, fast spark shot
- **Brakka**: slow, more health, hits harder, big slow boulder
- **Wisp**: very fast, less health, quick gust

## Changing things

Almost every number is in `FightConfig.lua`: fighter health and speed, move damage, startup time, stun, knockback, round time, and the keys. To add a fighter, copy one of the entries in `Config.Fighters` and add its name to `Config.FighterOrder`.

If you edit the files in `src/`, run `python3 build_place.py` to rebuild the `.rbxlx`.

## Not done yet

- Attacks use simple arm and leg swings made in code. Real animations need to be made in Studio's Animation Editor and uploaded to your account.
- Sounds are just the built-in Roblox ones.
- Only one arena and one match at a time.
