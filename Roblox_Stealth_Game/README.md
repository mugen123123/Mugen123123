# Silent Contract (Roblox stealth game prototype)

A stealth game played in short missions. You sneak into a building, take out one target without being seen, and get back out. At the end you get a grade from D to S.

This is a first playable test with one building, "The Penthouse". Every player in the server gets their own private copy of the building, so it plays solo.

## How to open it

**Easy way:** download `SilentContract.rbxlx`, open it in Roblox Studio (File > Open from File), and press Play. The building makes itself when the game starts.

**If the file won't open,** make a new Baseplate place and copy the scripts in by hand:

| Make this in Studio | Where | Paste the code from |
|---|---|---|
| ModuleScript named `StealthConfig` | ReplicatedStorage | `src/shared/StealthConfig.lua` |
| Script named `StealthServer` | ServerScriptService | `src/server/StealthServer.server.lua` |
| LocalScript named `StealthClient` | StarterPlayer > StarterPlayerScripts | `src/client/StealthClient.client.lua` |
| LocalScript named `StealthMenu` | StarterPlayer > StarterPlayerScripts | `src/client/StealthMenu.client.lua` |

The names have to match exactly. `default.project.json` is there if you use Rojo.

## Main menu

The game opens on a 3D menu. The camera starts on a copy of your character at the start of a dark hallway. Each menu option glides the camera down the hallway to a board on the wall: Play (contracts), Armory, How to Play and Records. Accept Contract on the contracts board starts the mission, and Main Menu on the results screen brings you back. If you leave out the `StealthMenu` script, the game skips the menu and goes straight to the briefing.

## How to play

1. Read the briefing, pick 2 tools, press Start.
2. Find the target (red suit, marked TARGET) and take him out.
3. Get back to the green exit circle in the storage room where you started.

| Key | What it does |
|---|---|
| WASD | Move |
| C | Crouch. Slower, but silent and harder to see. |
| E | Take down a guard from behind, or use the fuse box |
| Q / R | Use tool 1 / tool 2 (aims at your mouse) |

**How guards notice you**

- The fan of lines on the floor is what a guard can see. It stops at walls and cover.
- Standing in lamp light, guards see you from far away. In the dark they have to be close. The bottom of the screen says which one you're in.
- A "?" over a guard means they are starting to notice you. A "!" means they are chasing you. If they reach you, the mission fails.
- Walking near a guard makes noise and they come to look. Crouching is silent.
- Guards who see a knocked-out guard come over to check, and it costs you points.

**Tools**

- Noise Maker: guards near where it lands walk over to it.
- Smoke Bomb: guards can't see through the smoke.
- Sleep Dart: knocks out a guard from a distance.
- Power Cutter: all lights off for 15 seconds.

**Grade**

You start with 100 points. Being spotted costs 25, a found body costs 10, each extra takedown costs 5, and going over 3 minutes slowly costs more. 95 or higher is an S.

## Changing things

Everything is in `StealthConfig.lua`: how far guards see, how fast they notice you, tool uses, and the whole building (walls, cover, lamps, patrol routes) as lists of numbers. After editing files in `src/`, run `python3 build_place.py` to rebuild the `.rbxlx`.

## Not done yet

- Guards and furniture are plain blocks. They are stand-ins for real models.
- No walking animations on guards and no real takedown animation.
- Only one mission. Scores are not saved between sessions.
- No disguises, lockpicks or grappling hook yet.
