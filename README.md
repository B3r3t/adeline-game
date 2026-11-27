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

## The look and feel of the whole game

- **Title screen.** A painting of the sisters, Spirit, the pony and the unicorn, the logo,
  and five cards: Adventure, Riding course, Horse race, Fly the unicorn, Farm games. The
  riding, racing and flying cards each show the course last chosen and the stars won on it; the arrows at the ends of a card
  step through every course reached so far (one past the last one finished).
- **Menus.** "Settings" on the title screen and the Menu button everywhere else open the
  same panel: Sound, Music, Buttons (small, medium, large), Goblin fights (normal or easy),
  and either "Start a new adventure" (two taps) or "Go to the title screen". Everything
  stands still while a menu is open. Easy fights give goblins a little over half their
  health and longer warnings. All four choices are remembered (`user://settings.json`).
- **One look.** Rounded panels and buttons, hearts and stars are drawn by `scripts/ui.gd` and
  used on every screen. The typeface is Fredoka (open licence, in `art/ui`).
- **Speech.** Whoever is talking has their portrait beside the words. The portraits are cut
  from the characters' own drawings by `art_src/build_faces.py`.
- **The island.** `scripts/scenery.gd` adds a graded sky, a sun and drifting clouds; trees,
  bushes, flowers and farmyard things; butterflies round the flowers, birds crossing the
  sky, rabbits that hop away, a frog on the lily pads; moving water on the river; and a soft
  shadow under everybody. It is laid out the same way every time and none of it can be
  bumped into. The riding course and race have trees and flowers along the far side too.
- **Fights.** The damage of each hit pops out of the goblin as a number.
- **Races** start with a count of three, with the four horses lined up, and end in confetti.
- **Motion.** Nothing on screen just appears.
  - Going anywhere new (into the house, through a door, to a race, back to the title) opens
    the new place out of the dark from the middle of the screen (`scripts/curtain.gd`).
  - Menus, the speech box, results and "try again" panels pop open. Words in the speech
    box arrive a word at a time and the speaker's portrait nods as each line starts.
  - On a results panel the stars arrive one at a time, each with a higher chime.
  - The title: the name drops in, the cards come up one after another, the painting
    drifts slowly and stars twinkle on it.
  - A new goal swells and lights up; messages slide in; counters (rings, stars, place in a
    race) jump when they change; hearts shake when one is lost and the lost one floats off.
  - Thumb buttons squash when pressed and send out a ring.
  - The unicorn's wings sweep out and tuck in instead of changing in a blink, butterflies
    flutter up out of Adeline's way, and the mark over Merlin pulses when he has news.
  The timing helpers (`pop`, `ease`) are in `scripts/ui.gd`.

## Mission 3: The Missing Unicorn

Merlin offers it once the goblins are dealt with (it does not need Mission 2, but only one of
the two can be on at a time). A unicorn, Aurora, has fallen out of the sky.

1. Fetch her sister. Only the very young can see a unicorn's hoofprints.
2. Follow the trail east: three sets of rainbow hoofprints. Each shows itself only when her
   sister is close, and is found when Adeline walks up to it (or her sister reaches it with
   Adeline nearby).
3. Goblin trappers have the unicorn under a net at the east end. The fight works like the
   guards in Mission 2: her sister charges through and Adeline hits the dizzy goblins.
4. Tap FREE at the net, then FLY beside the unicorn. Both sisters ride her home through the
   sky (the sky ride below). Reaching the cloud castle ends the mission.
5. Aurora comes back to live in the stable.

- `scripts/mission3.gd` holds the mission. Where things are on the island is at the top.
- Her name is one word in two places: `MOUNTS` in `scripts/main.gd` and `UNICORN_NAME` in
  `scripts/mission3.gd`.

**Spirit or Aurora.** Once she is home, a "Swap to ..." button sits under the hearts whenever
Adeline is on foot, and a "Bring in ..." button is in the stable. Whoever is out is the one
that comes when called, is ridden in the riding course and the race, and is fed and brushed
in the stable (each has her own food, shine and love).

**Flying on the island.** On Aurora, JUMP in the air is one beat of her wings, so tapping it
keeps her up and the camera goes up with her. From her little sister's menu, "Fly on Aurora
with me!" has her climb up in front whenever Adeline mounts.

## The sky ride

"Fly the unicorn" on the title screen, and the last step of Mission 3. It is a third way to
play, next to the riding course and the race, and works the way Flappy Bird does.

- Any tap is one beat of her wings and lifts her; between taps she sinks. She flies forward
  by herself.
- Storm clouds stand in pairs with a gap to fly through, and grumpy thunderclouds sit in the
  way. Rainbow rings and stars are there to collect; the stars show the easy line.
- She has three feathers. A bump costs one. With none left, or if she sinks into the cloud
  sea at the bottom, she tumbles back down to earth and lands in the hay.
- A tap sends her galloping off and up again. Rainbow arches split each sky into three
  stretches: she comes back up at the last arch she flew through, with her feathers back.
- The ride ends at the cloud castle with one to three stars (three: no tumbles and most of
  the stars). Each sky number is always the same sky; later ones are faster with narrower gaps.
- Just after arriving in the sky she is held level for a couple of seconds, or until the
  first tap, so there is time to get ready.

All the numbers are at the top of `scripts/sky.gd`: `GRAVITY`, `FLAP` (how hard one beat
lifts), `SPEED`, `FEATHERS`, and in `_build` the gap between storm clouds (`gap`, 340 in the
first sky) and how far apart things are.

Tested with scripted pilots: one that flies the line finishes with three stars; one that never
taps sinks, lands, and is sent up again; one that flies into every gate loses a feather each
time and tumbles on the third; and after a tumble past an arch she comes back at the arch.

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
cooking at the stove while the table is laid, a longer while with everyone sat down to the
meal, then a short spell when the kitchen is empty. Each time round is a different meal:
breakfast (pancakes, eggs and bacon, toast, berries, juice, jam), lunch (soup, a loaf,
salad, cheese, fruit, water) and dinner (roast chicken, mash, peas and carrots, rolls,
pie, gravy). Grandma is always part of it; Mom and Dad join once they have been rescued.

- **The table** is drawn so its top can be seen, and everything on it is its own picture
  set down at a place: a plate, cutlery and a drink in front of each chair (mugs for the
  grown-ups, milk for the girls), serving dishes along the cloth down the middle, the
  flowers and the salt and pepper always there. Only the people at home get a place.
- **Laying it.** During the cooking the places go down one at a time, then the dishes
  come out; each lands with a small bounce. Late in the meal the plates are empty. When
  the kitchen is quiet the table is cleared.
- **Sitting down.** Five chairs stand along the far side. The family lean in for a
  mouthful each in their own rhythm. Adeline's sister comes to the table by herself when
  the meal is on it (on a cushion, as she is small), and "Sit down and eat" brings Adeline
  round to her own chair, where she eats with her hand coming up to her mouth.
- **Sizes.** The kitchen is drawn closer up than the other rooms, so Adeline and her
  sister are drawn 1.12 times bigger in it (`KID` in `kitchen.gd`), which puts Adeline at
  about nine tenths of Mom's height, and bigger again sat at the table (`KID_SAT`), where
  only heads and shoulders show beside the family's.

The table, chairs, tableware and food are cut from generated sheets by
`art_src/build_kitchen.py` into `art/room/kitchen`, which also reshapes the table (a
deeper top, shorter legs) and writes the size each thing is drawn at.

## Farm games

Five little games, reached from the fifth card on the title screen. Each is played on its
own painted scene, takes a minute or so, cannot be lost, and ends with one to three stars;
the best for each is kept (`mini_stars` in the save). The pause menu has a way back to the
list. Three are Adeline's own and two she plays with her little sister.

- **Apple picking.** Grandma's list is at the top: six red apples, four green, two golden.
  Apples ripen along the bottom of the old tree, shiver and drop. Hold a finger where
  Adeline should run and she catches them in her basket. Wormy apples are best left to
  fall; three stars for catching none. Grandma comes out with the pie at the end.
- **Lost lambs.** Six lambs are scattered over the meadow and the sun is going down
  (90 seconds). Tap where Adeline should walk; a lamb she reaches follows her in a line,
  and at the barn they hop in one by one. One is stuck in a bramble bush: stand by it
  until the ring fills. A fox comes by every so often. If it gets among the lambs they
  bolt back to where they were; tap it and Adeline shoos it off. Lambs still out at
  nightfall find their own way in, for one star.
- **Merlin's potions.** A memory game. Merlin drops ingredients into the cauldron, each
  with its own note, then Adeline taps the same ones in the same order. Four potions of
  two, three, four and five ingredients. A wrong one makes grey smoke and Merlin shows
  the potion again. A frog comes out of the last one.
- **Hide and seek.** Adeline counts to three with her eyes shut while her sister hides
  behind one of eight things in the farmyard. Every few seconds she peeks out and giggles;
  tap what she is behind and Adeline goes to look. From the second round a hen, a cat, a
  rabbit or a mouse hide too, and peek too. Three rounds, with shorter peeks each time.
- **Pony wash.** The pony is muddy. Rub each splat with the sponge, hold a finger where
  her sister should point the hose until the soap is gone, then rub her dry with the
  towel until every patch shines. She gets a bow at the end. Quicker hands, more stars.

How they are built: `scripts/mini.gd` sets up the scene (scaled to cover the screen;
anything that matters stays inside `SAFE`, so nothing is lost on a long phone or a squarer
tablet), passes touches to the game, and shows the opening card and the stars. A game
script has `begin`, `how`, `go`, `frame`, `press`, `drag`, `release` and `draw_ui`, and
calls `host.finish(stars, line)` when it is over. Adding a sixth is one more script and
one more line in `LIST`. The numbers that set how hard each is are constants at the top
of its file. The pictures are cut from generated sheets by `art_src/build_mini.py` into
`art/mini`.

The rules they are held to, each checked by a scripted player that plays badly on purpose
as well as one that plays well:

- A game can always be finished, however it is played, and always gives at least one star.
- Stars only ever go up: a worse go never takes away a better one. They are saved the
  moment a game ends and are still there after the app is closed.
- "Play again" starts clean, with nothing carried over from the go before.
- Opening the menu, or the app losing the screen, lets go of whatever a finger was
  holding, so nothing is left stuck to it.
- A quick double tap in Merlin's potions counts once, not as a mistake.
- In Lost lambs the result waits until every lamb that is coming home is through the
  barn door, so the count on the panel is the true one.

## Merlin's shop

Stars are worth something. Every game that ends in stars (the riding course, the race,
the sky ride, the farm games) keeps the best for that game as before, and also pays the
stars just won into a purse, so playing again always earns. The results panel says how
many went in. An adventure from before there was a shop starts with every star it had
already won.

The shop is the purple button beside Settings on the title screen, which shows the purse,
and it is also on Merlin's list of missions. It has three shelves:

- **Adeline:** five colours of cloak and three hats (a flower crown, a cowgirl hat, a
  tiara). Her little sister wears the same hat, so they match.
- **Spirit:** five colours of saddle blanket, and three things for the neck (a flower
  garland, star charms, a first-prize ribbon), which the pony and the unicorn wear too.
- **Home:** eight pieces of furniture, four for the living room and four for the bedroom.
  Once bought they are in that room's tray, to be placed, turned, sized and coloured like
  the rest.

Tapping a thing looks at it: Adeline or Spirit tries it on at once. Only the big button
buys, so a stray tap never spends anything. A thing already bought is put on or taken off
with the same button, free, as often as she likes. Everything costs 3 to 8 stars; all of
it together is 109, which is a good many games. Purse, things bought and what is worn are
kept with the adventure, and "Start a new adventure" clears them with the rest.

How it is built: `scripts/shop.gd` is the shop, and `ITEMS` at its top is the whole stock
(name, shelf, price); adding a thing is one more line there and a picture. `scripts/look.gd`
is what is worn. The colours need no pictures of their own: a shader finds the purple of
the cloak (or the blanket) and turns it round the colour wheel, and `COLOURS` says how far
for each. Hats and neck things are pictures in `art/shop`, put on the puppets in the same
places as the Christmas hats and collars (a bought hat is worn instead of the Christmas
one). Every puppet is dressed as it is built, so the choice shows everywhere: on the
island, on the rides, in the house and in the farm games. The pictures are cut from drawn
sheets by `art_src/build_shop.py`, which also makes the cards for each colour with the same
sum as the shader.

## Spirit's foal

There is a foal in the stable. The first time Adeline goes in she is asked to name her,
from six names. Then, each day, the foal wants three things, shown on a little plate over
her head: her milk (the bottle in the tray, held to her for a couple of seconds), a brush
and a cuddle (the heart). They are given just as Spirit is looked after, with the same
tray.

When all three are done she is cared for that day. That is one day of growing, and a star
for the purse. She does the growing overnight: the next day she is a little bigger, and
Adeline sees it happen as she walks in. After two days of care she stands up, after five
she trots about the stable and will take a carrot or an apple instead of her bottle, and
after ten she is all grown up, which is worth five stars. She can still be looked after
every day after that.

A missed day costs nothing. She does not go hungry or get sad: she waits, and grows the
day after she is next cared for. There is only ever one day of growing a day, so it
cannot be hurried either. At "Bedtime for Spirit" she goes to sleep too.

How it is built: `scripts/foal.gd`, a child of the indoors scene like the kitchen. What it
keeps is `foal` in the save: her name, the days she has been cared for (`days`), the size
Adeline has seen her at (`seen`), and today's milk, brush and cuddle. `GROWN` at the top is
how many days it takes, and `stage_of` says what she can do at each age. She is seven
drawn poses (`art/foal`), not a jointed puppet, and grows by being drawn bigger. The
pictures are cut by `art_src/build_shop.py`.

## Christmas

From December 1 to January 1, by the tablet's own date, the whole game dresses for
Christmas, and on January 2 it goes back as it was. Nothing has to be done to switch it.
To see it at another time of year there is a row for it under Settings on the title
screen: "Christmas: in December" (the normal way), "on now", or "off".

What changes:

- **Everywhere outdoors** it snows. The island, the riding course, the race, the sky
  ride and the farm games are drawn in snow, with lights on the house, the stable and
  Merlin's hut. The river is frozen and the frog has gone. The rings on the rides are
  holly wreaths. Butterflies are snowflakes, the birds are robins, the rabbits are
  snow hares, and a snowman stands where the lavender was.
- **Everyone is dressed for it.** Adeline, her sister and the riders wear red bobble
  hats, the goblins and the ogre wear elf hats, and Spirit, the pony and the unicorn wear
  holly collars with a bell. There is no Santa in the game.
- **The house** is hung with garlands in every room, and the stable too. In the living
  room stand a Christmas tree, a nativity scene and a pile of presents.
- **A present a day.** There is one present for each day of December up to the 25th. Tap
  the pile to open the next: it bursts into stars and a light comes on in the tree. Days
  that were missed can be opened one after another, so nobody loses out. The 25th lights
  the star on top. This is kept with the adventure, and starts again each Christmas.
- **Christmas dinner.** Dinner in the kitchen is turkey, mash, peas, a gingerbread
  house, cookies and a Christmas pudding, with a candle on the table and cocoa for the
  girls. Breakfast and lunch are as usual.
- **The title screen** has its own picture, snow on the logo, and a ribbon that counts
  the sleeps until Christmas, then says "It's Christmas Eve!", "Merry Christmas!",
  "Happy New Year's Eve!" and "Happy New Year!" on those days. Every panel and button in
  the game wears a cap of snow.
- **Music and voices.** The island, the house, the rides and the farm games each have a
  Christmas tune. The birdsong is silent. Merlin calls "Merry Christmas, Adeline!" when she
  comes by, her sister calls it or "It's snowing!", and Adeline says it when she sits down
  to dinner.

How it is built: `scripts/season.gd` answers one question, `Season.festive()`, and
everything asks it. Its dates are `FROM` and `UNTIL` at the top of the file. Every picture
is loaded through `Season.tex(path)`, which gives the picture of the same name under
`art/xmas` when it is Christmas and there is one, and the usual picture otherwise. So a
winter picture is a stand-in of exactly the same size, and nothing else in the game needs
to know. The hats and collars are put on the puppets by `Season.dress` (the table `WEAR`
says who wears what, where). The snow is `scripts/snow.gd`, the tree and presents are
`scripts/advent.gd`, and the snow caps are in `scripts/ui.gd`. The music is asked for as
"x_" and the usual tune's name. The winter pictures are made by
`art_src/build_xmas.py` from the drawings in `art_src/xmas` (run
`python3 build_xmas.py xmas ../art` in `art_src`).

To make another season later (say, autumn), the same three things are needed: dates in a
script like `season.gd`, a folder of stand-in pictures, and anything extra to wear.

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
- Sound and music are turned on and off in the settings and pause menus, and remembered.
- **Music.** Six looping tunes: the island and title, goblin fights, riding and racing, the
  sky, indoors, and a bouncy one for the farm games. One fades into the next, and music dips while someone is speaking.
  Behind it there is quiet birdsong outdoors and wind in the sky. The tunes were made with a
  music generator and asked for without singing; the recordings are in `art_src/music` and
  `art_src/build_audio.py` makes each into a loop with no seam.
- The little sister's lines in conversation are spoken as well as Merlin's.
- In the farm games Adeline, her sister and Merlin call out as things happen, and the
  animals have their own sounds (lamb, hen, cat, mouse, frog, fox). Those animal sounds
  were generated and are in `art_src/voice` as `fx_*.mp3`; the splash, puff of smoke,
  sponge and hose are made from scratch like the other effects.
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
- `scripts/horse.gd` is Spirit, and the unicorn, the pony and the race horses.
- `scripts/mission2.gd` and `scripts/mission3.gd` are the two later missions.
- `scripts/sky.gd` is the sky ride. `scripts/ride.gd` is the riding course and the race.
- `scripts/curtain.gd` opens each new place out of the dark.
- `scripts/mini.gd` is the frame the five farm games run in, and the list they are chosen
  from. Each game is its own file: `mini_apples.gd`, `mini_lambs.gd`, `mini_potions.gd`,
  `mini_hide.gd`, `mini_wash.gd`.
- `scripts/shop.gd` is Merlin's shop and `scripts/look.gd` is what Adeline and the horses
  wear from it.
- `scripts/season.gd` says whether it is Christmas and picks the winter pictures.
  `scripts/snow.gd` is the falling snow, and `scripts/advent.gd` the tree and its presents.
- `scripts/foal.gd` is Spirit's foal in the stable.
- `scripts/scenery.gd` is the sky, trees, flowers and animals. `scripts/ui.gd` is how panels
  and buttons are drawn. `scripts/sound.gd` plays every sound and the music.
- `.github/workflows/build-apk.yml` builds the app.
