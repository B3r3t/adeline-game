# Adeline

A 2D side-view adventure game for Fire tablets and Android phones, built in Godot 4.

Play as Adeline: fight goblins with her wand, earn spells, and rescue her parents from an ogre.

## Where things stand

Step 2: all of Mission 1, "Goblin Trouble", in placeholder shapes. No art yet.

- Title screen with Start, Continue and New game. Progress saves on its own.
- The home island as one long strip: house and stable, Merlin's hut, three goblin camps, the river and the boat.
- Talk to Merlin to pick a mission from his list.
- Five goblins in three camps. The first only swings, the second only charges, the third camp mixes both with one goblin attacking at a time.
- Losing a fight restarts only that fight, with full health.
- Returning to Merlin awards the Magic Shield, then opens practice fights of one to three goblins.
- Spirit, Adeline's horse (dark brown, black mane and tail), waits in the stable. Tap Call and Spirit comes to her, tap Ride to gallop across the island, and Spirit stays back from goblin fights.

Controls

- Left thumb: the two arrows. Right thumb: Jump, Strike, Fire, and Shield once it is earned.
- One button above the arrows changes with the moment: Talk next to Merlin, Ride next to Spirit, Hop off in the saddle, Call everywhere else.
- Keyboard for testing on a computer: A/D or arrows, Space, J, K, L and E.

Combat numbers, all at the top of `scripts/player.gd` and `scripts/goblin.gd`

- Wand strike: 1 damage, very quick.
- Fireball: 3 damage, 2 seconds between casts.
- Goblin: 8 health. Each attack warns for 0.9 seconds, then recovers for about a second.

## Getting the game onto a tablet

Every change pushed to `main` is built into an installable app automatically.
The newest one is always on the Releases page as `adeline.apk`.

## Project layout

- `scripts/main.gd` builds the island, runs the mission, fights and saving.
- `scripts/player.gd` is Adeline. Her speeds, reach and timings are at the top of the file.
- `scripts/goblin.gd` is the goblin and its two attacks, with timings at the top.
- `scripts/touch_controls.gd` is the on-screen buttons.
- `scripts/hud.gd` is the hearts, objective, hints and title screen.
- `scripts/dialog.gd` is the dialogue box and Merlin's mission list.
- `scripts/horse.gd` is Spirit.
- `.github/workflows/build-apk.yml` builds the app.
