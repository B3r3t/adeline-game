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
- When Adeline rides she is drawn in front of the saddle, sitting on it with her near leg over the flap; her far leg is out of sight behind Spirit.
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

## Mission 2: Rescue Mom and Dad

Merlin offers it once the goblins are dealt with. Adeline cannot do it alone, which is the
point: her little sister is needed three times.

1. Fetch her sister (walk up to her, tap SISTER, pick the rescue). She follows on her pony.
2. Take the flying boat at the river. It will not leave without her sister.
3. Goblin guards. Every few seconds her sister charges from one end of the fight to the
   other; goblins she passes see stars and lose a little health.
4. The fort gate. Two stones must be pressed at once. Stand on one and tap STAY so she waits
   there, then run to the other.
5. The ogre. Nothing hurts him while he is paying attention. When her sister gallops past he
   turns to watch her, and only then can he be hit.
6. Open the cage and everyone flies home. Mom and Dad stand by the house from then on.

- `scripts/mission2.gd` holds the mission and the island (the ground past the river). Where
  things stand on the island is at the top of the file. Progress is saved after each step.
- The ogre is the goblin script with its own drawings and numbers (`scripts/main.gd`,
  `_spawn_goblins`): bigger, slower, tougher, and only hurt while dazed.
- Her sister can follow, stay on a spot or charge to one (`scripts/sister.gd`).

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

**Boost.** Both riding games have a BOOST button. A burst lasts a second and a half and makes
Spirit about a third faster. Bursts are saved up, three to a full bar: slowly over time, and
faster by collecting rings and jumping cleanly.

**Horse race.** "Horse race" on the title screen races Spirit against three other horses
(Thunder, Daisy and Pepper) over hills and jumps. They run on the same physics as Spirit, each
in its own lane, and now and then one clips a jump and loses ground. A horse far in front
eases off and one far behind digs in, so the race stays close. Stars are for where she
comes: three for first, two for second. Tested with a scripted rider: clean jumps with boost
wins, clean jumps without boost comes second, and hitting every jump comes third.

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

### The other riders

Each of the other horses in a race has a rider: Finn in green on Thunder, Rosa in red on
Daisy, and Baron Vex, a pantomime villain in a top hat and black cape, on Pepper. They are
drawn on Adeline's pattern of sheet and built the same way (`RIDERS` in
`art_src/build_rig.py`, art in `art/rider_*`), and sit to the stride and fold over a jump
as she does (`jockey` in `scripts/horse.gd`).

### The crowd at a race

People come to watch a race: a few groups here and there along the track and a bigger
gathering either side of the finish. They stand behind a rope on the far side, hop and wave
as Spirit comes by, and give a light cheer; there is a bigger cheer when she finishes. The
cheers are four recorded voices layered at different pitches over clapping
(`crowd` in `art_src/build_audio.py`). The spectators are sixteen separate pictures
(`art/props/crowd_*.png`), put into groups by `_add_crowds` in `scripts/ride.gd`.

The finish gate is drawn in two layers, so the horses ride through it: the far post and the
banner behind them, the near post in front.

## Adeline's little sister

Her little sister rides a small cream pony up and down the meadow between the house and the
signpost, stops for a rest now and then, and waves and calls hello when Adeline comes near.
Nobody plays her. She and her pony have drawings of their own (`art/sister`, `art/pony`):
a five-year-old with a big head and short legs, and a round, shaggy pony with a big head and
short sturdy legs. A big character made small still looks like a small adult or a toy horse,
which is why they are not Adeline and Spirit shrunk. The pony uses the same script as Spirit
(`scripts/horse.gd`) and is told which drawings to wear and where her rider sits.

She is drawn as a younger Adeline (same face, freckles, hair and outfit, her own yellow
cloak), so they look like sisters. Walk up to her and tap SISTER for things to do together:

- Race you on foot: she hops off her pony, they line up, 3-2-1-GO, first past the flag.
  She runs a little slower than Adeline, so it is close but winnable.
- Do her hair: a brush, some sparkles, and the next of her four hairstyles (ponytail,
  braid, bun, pigtails). It is remembered.
- Come with me / Off you go and play: she rides along behind Adeline, or goes back to
  wandering.

### Indoors together

Her sister comes into the house with Adeline when she is close by or following, and can be
called in from inside ("Call your sister in"). She trails after Adeline from room to room,
waves now and then, and curls up on the floor when Adeline goes to sleep. Buttons on the
left of the room:

- Balloon game: tap the balloon to keep it off the floor. Her sister runs under it and bops
  it too, and sometimes misses. The count and the best score show at the top.
- Do her hair: pick one of four hairstyles and one of six ribbon colours. Adeline steps in
  behind her and brushes, and the new style stays on her indoors and out.

`scripts/playmate.gd` is her indoors. The hairstyles are pictures that take the place of
her ponytail (`art_src/build_hair.py`, `art/sister/hair.json`).

### The kitchen

A fourth room, reached from the living room. The family have it as they like it, so
nothing is placed here. It goes round on the clock (`scripts/kitchen.gd`): a while of
cooking at the stove while the table is laid, a longer while with everyone sat at the
table and dinner on it, then a short spell when the kitchen is empty. Grandma is always
part of it; Mom and Dad join once they have been rescued. While dinner is on the table
Adeline can sit down and eat with them.

## At home

Near the front door a "Go into the house" button appears, and near the stable a "Visit
Spirit's stable" button.

- **Two rooms to decorate**, joined by a door: the living room and Adeline's bedroom. Each
  keeps its own things. The bedroom has a bed, wardrobe, bedside table, desk, toy chest,
  mirror, heart rug, bedside lamp, teddy, toy horse, horse poster and bunting. The teddy,
  toy horse and lamp can sit on the bed, the bedside table, the desk or the chest.
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
- **The bathroom**, through a second door in the living room. The mirror shows a close-up of
  Adeline's smile with her teeth covered in plaque: yellow goo, crumbs and little green
  germs. Tap the toothpaste to load the brush, then scrub. The plaque comes off exactly
  where the brush goes, like rubbing frost off a window, so every tooth has to be reached.
  A dry brush hardly cleans, and the paste runs out and needs topping up. A bar shows how
  clean her teeth are. They get a little grubby again between visits.
  The smile and the plaque are two drawings; `art_src/build_room.py` finds the teeth in the
  first (the bright, colourless patches) so the plaque is only ever laid over teeth.
- **Sleeping.** In the bedroom, "Go to sleep" sends Adeline to her bed (the room needs one),
  where she lies down, the room goes dark and little Z's drift up. A tap wakes her. In the
  stable, "Bedtime for Spirit" does the same for Spirit, who dozes standing up as horses do.
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
- Spirit whinnies and snorts. Her hoofbeats are soft thuds on turf, one for each hoof as it
  lands, so what is heard matches her legs: four even beats at a walk, two at a trot, and at
  a gallop four quick ones and a pause. None play while she is in the air. Other horses (the
  race horses, the pony) are quieter and fade out with distance.
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
- Movement is shared: `scripts/moves.gd` holds the shapes of standing, running, jumping,
  landing, sitting in the saddle, and a horse's walk, trot and gallop. Adeline, her sister,
  Spirit, the pony and the race horses all use it.
- Parts do not jump from one pose to the next. `scripts/rig.gd` eases every joint toward
  where it should be, so a change of pose blends over a few frames. Cloaks, ponytails and
  tails are on soft springs: they trail, overshoot and settle, and are thrown back or
  forward when a character starts or stops.
- Cloaks, ponytails and tails bend along their length. Each is drawn as a row of strips, and
  every strip turns a little more than the one before, so the tip trails, curls and ripples
  in the wind of running (`SOFT` at the top of `scripts/rig.gd`). A horse's neck bends the
  same way, so her head nods at a walk, reaches out at a gallop and lifts over a jump.
- Weight: feet and hooves kick up dust, landings puff, a hit freezes the game for an instant
  and a heavy blow shakes the picture (`puff`, `hit_stop` and `jolt` in `scripts/main.gd`).
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
- A file the game has loaded is never changed while the game is running. The game reads its
  pictures out of that file as it needs them, so swapping it mid-play breaks whatever has not
  been read yet (builds 16 to 20 did this: rooms and race pieces went missing until the game
  was reopened). A download is now kept as `update_new`, becomes `update_next` at the next
  start, and is loaded on top by `scripts/handoff.gd` before any game code is read.
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
- `scripts/handoff.gd` (the scene `main.tscn`) runs next and loads the newest update on top.
  The game itself is the scene `game.tscn`.
- `scripts/main.gd` builds the island, runs the mission, fights, saving and the update check.
- `scripts/player.gd` is Adeline. Her speeds, reach and timings are at the top of the file.
- `scripts/goblin.gd` is the goblin and its two attacks, with timings at the top.
- `scripts/touch_controls.gd` is the on-screen buttons.
- `scripts/hud.gd` is the hearts, objective, hints and title screen.
- `scripts/dialog.gd` is the dialogue box and Merlin's mission list.
- `scripts/horse.gd` is Spirit.
- `.github/workflows/build-apk.yml` builds the app.
