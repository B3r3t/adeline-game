# Adeline

A 2D side-view adventure game for Fire tablets and Android phones, built in Godot 4.

Play as Adeline: fight goblins with her wand, earn spells, and rescue her parents from an ogre.

## Where things stand

Step 3: all of Mission 1, "Goblin Trouble", in real art.

- Title screen with two ways to play: the adventure, and Ride with Spirit. Progress saves on its own.
- A Home button in the top corner returns to the title screen.
- The home island as one long strip: house and stable, Merlin's hut, three goblin camps, the river and the boat.
- Talk to Merlin to pick a mission from his list.
- Five goblins in three camps. The first only swings, the second only charges, the third camp mixes both with one goblin attacking at a time.
- Losing a fight restarts only that fight, with full health.
- Returning to Merlin awards the Magic Shield, then opens practice fights of one to three goblins.
- Spirit wears a leather saddle on a purple blanket, and reins that run from her bit to Adeline's hands while she rides and loop back to the saddle when she does not.
- Spirit, Adeline's horse (dark brown, black mane and tail), waits in the stable. Tap Call and Spirit comes to her, tap Ride to gallop across the island, and Spirit stays back from goblin fights.

Controls

- Left thumb: the two arrows. Right thumb: Jump, Strike, Fire, and Shield once it is earned.
- One button above the arrows changes with the moment: Talk next to Merlin, Ride next to Spirit, Hop off in the saddle, Call everywhere else.
- Keyboard for testing on a computer: A/D or arrows, Space, J, K, L and E.

Combat numbers, all at the top of `scripts/player.gd` and `scripts/goblin.gd`

- Wand strike: 1 damage, very quick.
- Fireball: 3 damage, 1.2 seconds between casts. It also works from the saddle.
- Goblin: 10 health. Each attack warns for 0.9 seconds, then recovers for about a second.

## Ride with Spirit

A second way to play, chosen on the title screen. Spirit gallops a course on her own and the
player does the jumping.

- Jump fences, hay bales and logs. Hold Jump for a higher leap. The arrows slow Spirit or speed her up.
- Ride or jump through golden rings. Some sit along the arc of a single jump.
- Nothing can be lost. Knocking an obstacle costs Spirit some of her speed.
- Each course ends with one to three stars, from rings collected and bumps taken. The best
  stars for each course are saved.
- "Next course" gives a new layout that is a little faster and hillier. A course number always
  gives the same layout, so it can be practised.

The course runs on real physics:

- The ground rolls. Gravity slows Spirit on the way up a hill and speeds her up on the way
  down, and her own legs work to bring her back to the pace she is asked for.
- Where the ground drops away faster than she falls, she flies. Ledges send her into the air
  with no button pressed, and a ring hangs on that flight.
- A jump taken going uphill carries higher, and one taken downhill carries lower. On landing
  she keeps the part of her speed that points along the slope.
- Jump rails, hay bales and logs are rigid bodies. Spirit's legs knock them away at her own
  speed, and from there the physics engine does the rest: rails spin and bounce, bales roll.
- Rings that need a jump are hung by working out real jumps in advance, so every ring can be
  reached at an easy pace.
- `scripts/ride.gd` holds all of it. The forces and speeds are at the top.

## At home

Near the front door a "Go into the house" button appears, and near the stable a "Visit
Spirit's stable" button.

- **The living room.** Twelve things to put in it: sofa, armchair, rug, table, bookshelf,
  lamp, plant, painting, clock, flowers, rocking horse and cushion. Tap one in the strip at
  the bottom to add it, drag it anywhere, and tap it to choose one of eight colours, flip
  it, change its size or remove it. Up to 30 things. The room is saved as it was left, and
  a new adventure does not clear it.
- The room behaves like a real space. The floor has depth: things further back look smaller
  and sit behind things nearer the front. A thing let go in the air falls and lands with a
  bump. Furniture stands on the floor, pictures and the clock stay on the wall, and the rug
  lies under everything. The plant, flowers and cushion can sit on the table, the bookshelf,
  the sofa or the armchair, ride along when it is moved, and drop to the floor if it is taken
  away. A touch picks the thing actually touched, not the empty corner of a bigger one.
  Tap the bare floor and Adeline walks there; she also comes over to look at whatever was
  just put down.
- **The stable.** Hold an apple, carrot, hay or oats up to Spirit's mouth to feed her; she
  reaches for it. Her coat has dusty patches, and each one is brushed off where it is.
  Stroke her with the heart to pet her; her neck and face are her favourite places. Anything
  let go of falls into the straw. Adeline walks to Spirit's side or head to do the caring.
  Three bars (Food, Shine, Love) fill up; when all three are full Spirit whinnies and hops.
  The bars run down slowly while away (about twenty minutes from full to empty).
- `scripts/indoors.gd` holds both rooms. Colours are made by turning each picture round the
  colour wheel with a small shader, so one drawing gives every colour.

## Sound

- Merlin speaks his lines. Adeline shouts when she strikes, casts, jumps, gets hurt, calls
  Spirit and wins. Goblins cackle, growl before an attack, yelp and wail.
- Spirit whinnies and snorts, and her hoofbeats follow her stride, so they speed up and slow
  down with her.
- Effects for the wand, fireball, shield, rings, knocked rails, rolling bales and landings.
- "Sound: on / off" sits in the bottom-left corner of the title screen and is remembered.
- The voices were recorded with a text-to-speech service (Adeline uses the "Ainsley" voice and Merlin the "Landon" voice, both picked by ear). The effects are made from scratch
  by `art_src/build_audio.py`, which also trims and levels the recordings and writes
  `audio/manifest.json`. `scripts/sound.gd` plays everything; a sound missing from the list is
  simply silent. A new spoken line needs a recording added to that script's `MERLIN` list.

## Art

The look is a cartoon with thick ink outlines. Adeline is a 12-year-old girl with auburn hair,
a purple hooded cloak and swirl-patterned boots. Spirit is her dark brown horse.

All of Mission 1 is in real art now.

- Adeline, Spirit and the goblins are paper-puppet rigs: each is a set of separate parts
  (head, arm, legs, cloak, tail, club and so on) that the game rotates at the joints.
- The farmhouse with Spirit's stable, Merlin's hut, Merlin, the flying boat, the signpost
  and the goblin camps are single pictures.
- The ground and the two layers of hills are long strips that repeat sideways. The hills are
  faded toward the sky colour so the characters stand out in front of them.
- Arms and legs bend at the elbow and knee: one drawn leg is split into two overlapping halves.
- Still plain shapes: the river water, the hearts and the buttons. The fireball is drawn by code with a glow and sparks.

- `art/adeline`, `art/spirit` and `art/goblin` hold the game textures and a `rig.json` that lists the joints.
- `art/props` holds the scenery and Merlin. `art_src/build_props.py` sets how tall each one is in the game and how much the hills fade.
- `art_src` holds the original parts and `build_rig.py`, which turns them into the game files.
  Godot ignores this folder. Joint positions and part sizes are at the top of that script.
- `scripts/rig.gd` assembles a rig. The poses live in `scripts/player.gd`, `scripts/horse.gd` and `scripts/goblin.gd`.

## Getting the game onto a tablet

Every change pushed to `main` is built automatically. The Releases page always holds the newest:

- `adeline.apk` is the app to install. It only needs installing once.
- `adeline.pck` and `version.json` are the update. An installed game checks for these on its
  title screen, downloads a newer one quietly, and uses it the next time the game is opened.
  This needs the repository to be public, because the game downloads without signing in.

How updating stays safe

- A download that arrives cut short is thrown away.
- If the game fails to start with a new update, the next start throws that update away and
  runs the installed version.
- Some changes cannot arrive as an update: a new Godot version or a change in `project.godot`.
  For those, raise the number in `min_app_build.txt` to the build that must be installed.
  Older installs then show a note on the title screen asking for a fresh install.

How movement stays smooth

- Characters, the camera and the hills all move on the physics tick, and Godot's physics
  interpolation smooths them between ticks. Anything that moves should be moved in
  `_physics_process`, not `_process`, or scrolling will judder again.

## Project layout

- `scripts/boot.gd` runs first and loads a downloaded update if there is one.
- `scripts/main.gd` builds the island, runs the mission, fights, saving and the update check.
- `scripts/player.gd` is Adeline. Her speeds, reach and timings are at the top of the file.
- `scripts/goblin.gd` is the goblin and its two attacks, with timings at the top.
- `scripts/touch_controls.gd` is the on-screen buttons.
- `scripts/hud.gd` is the hearts, objective, hints and title screen.
- `scripts/dialog.gd` is the dialogue box and Merlin's mission list.
- `scripts/horse.gd` is Spirit.
- `.github/workflows/build-apk.yml` builds the app.
