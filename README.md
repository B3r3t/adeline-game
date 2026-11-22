# Adeline

A 2D side-view adventure game for Fire tablets and Android phones, built in Godot 4.

Play as Adeline: fight goblins with her wand, earn spells, and rescue her parents from an ogre.

## Where things stand

Step 1, the grey box. One fight scene made of placeholder shapes, to test how movement,
combat and the touch controls feel on a real tablet before any art is made.

- Move with the two arrow buttons, or A/D and the arrow keys.
- Jump, wand strike and fireball on the right, or Space, J and K.
- A goblin always warns before it attacks. Club raised: step back. Crouching: jump over the charge.
- Stars over a goblin's head mean it is recovering. That is the moment to hit back.
- Each round adds a goblin, up to three. Only one goblin attacks at a time.

## Getting the game onto a tablet

Every change pushed to `main` is built into an installable app automatically.
The newest one is always on the Releases page as `adeline.apk`.

## Project layout

- `scripts/main.gd` builds the test scene and runs rounds.
- `scripts/player.gd` is Adeline. Her speeds, reach and timings are at the top of the file.
- `scripts/goblin.gd` is the goblin and its two attacks, with timings at the top.
- `scripts/touch_controls.gd` is the on-screen buttons.
- `scripts/hud.gd` is the hearts, objective and banners.
- `.github/workflows/build-apk.yml` builds the app.
