extends Node2D
## Merlin's potions. Merlin drops ingredients into the cauldron one after another, each
## with its own note; then it is Adeline's turn to put the same ones in, in the same
## order, by tapping them on the bench. Get it right and the cauldron gives up a bottle
## of potion; get it wrong and it coughs grey smoke and Merlin shows her again. Four
## potions, each one ingredient longer than the last.

const Ui := preload("res://scripts/ui.gd")

const POT := Vector2(672.0, 604.0)  # where the cauldron's feet stand, on the hearth
const BENCH := 664.0  # the ingredients sit along the bench at the front
const THINGS := [
	["mushroom", Color(0.3, 0.62, 1.0), 1.0],
	["moonflower", Color(0.68, 0.4, 0.95), 1.122],
	["feather", Color(0.95, 0.3, 0.25), 1.26],
	["crystal", Color(1.0, 0.85, 0.25), 1.498],
	["shell", Color(1.0, 0.5, 0.8), 1.682],
	["acorn", Color(0.95, 0.62, 0.2), 2.0],
]
const LENGTHS := [2, 3, 4, 5]
const BOTTLES := ["bottle_pink", "bottle_blue", "bottle_green", "bottle_gold"]

var host = null
var game = null
var who := {}
var merlin: Sprite2D = null
var pot: Sprite2D = null
var brew: Node2D = null
var items: Array = []  # the six on the bench
var flying: Array = []  # ingredients on their way into the pot: [sprite, from, age, which]
var seq: Array = []  # this potion's ingredients, by number
var phase := "wait"  # "wait", "show", "turn", "wrong", "brew", "end"
var phase_time := 0.0
var potion := 0  # which potion is being made, from 0
var step := 0  # how far through it the showing or the answering has got
var mistakes := 0
var liquid := Color(0.35, 0.8, 0.45)
var want := Color(0.35, 0.8, 0.45)
var lift := {}  # which -> seconds since it last jumped up
var bottles: Array = []
var bottle_art := {}
var wave := 0.0
var frog: Sprite2D = null


func begin() -> void:
	merlin = host.picture("res://art/props/merlin.png", Vector2(388.0, 616.0), 176.0, 600)
	pot = host.picture("res://art/mini/cauldron.png", POT, 270.0, 604)
	who = host.girl("res://art/adeline", Vector2(960.0, 614.0), 2.3)
	who["facing"] = -1
	brew = Node2D.new()
	brew.z_index = 606
	brew.draw.connect(_draw_brew)
	host.stage.add_child(brew)
	for i in THINGS.size():
		var node: Sprite2D = host.picture("res://art/mini/%s.png" % THINGS[i][0], spot(i), float(_wide(i)), 800)
		node.set_meta("size", node.scale.x)
		items.append(node)
		lift[i] = 9.0
	for name in BOTTLES:
		bottle_art[name] = load("res://art/mini/%s.png" % name)
	z_index = 700  # the glow under each ingredient


func _wide(i: int) -> int:
	return [84, 92, 80, 88, 90, 76][i]


## Where each ingredient sits on the bench.
func spot(i: int) -> Vector2:
	return Vector2(242.0 + i * 172.0, BENCH)


func how() -> String:
	return "Watch what Merlin drops into the cauldron.\nThen tap the same things in the same order."


func go() -> void:
	_new_potion()


func _new_potion() -> void:
	seq.clear()
	for i in int(LENGTHS[potion]):
		var pick := randi() % THINGS.size()
		while not seq.is_empty() and pick == int(seq[seq.size() - 1]):
			pick = randi() % THINGS.size()
		seq.append(pick)
	_go("show")
	step = -1
	game.sound.shout("merlin", "merlin_watch", 1.0, true)


func _go(to: String) -> void:
	phase = to
	phase_time = 0.0


func press(at: Vector2) -> void:
	if phase != "turn":
		return
	for i in items.size():
		if at.distance_to(spot(i) + Vector2(0.0, -46.0)) < 80.0:
			_put_in(i)
			return


func drag(_at: Vector2) -> void:
	pass


func release(_at: Vector2) -> void:
	pass


## Adeline drops ingredient `i` in. Right or wrong is known when it lands.
func _put_in(i: int) -> void:
	lift[i] = 0.0
	who["hop"] = 0.0
	_throw(i)
	if i == int(seq[step]):
		step += 1
		if step >= seq.size():
			_go("brew")
	else:
		mistakes += 1
		_go("wrong")


func _throw(i: int) -> void:
	var copy: Sprite2D = host.picture("res://art/mini/%s.png" % THINGS[i][0], spot(i), float(_wide(i)), 900)
	flying.append([copy, spot(i) + Vector2(0.0, -40.0), 0.0, i])
	game.sound.play("chime", -9.0, 0.0, float(THINGS[i][2]))


## The mouth of the cauldron, where things go in.
func mouth() -> Vector2:
	return POT + Vector2(0.0, -pot.texture.get_height() * pot.scale.y * 0.86)


func frame(delta: float) -> void:
	phase_time += delta
	wave += delta
	for i in lift:
		lift[i] = float(lift[i]) + delta
	liquid = liquid.lerp(want, minf(delta * 4.0, 1.0))
	var playing: bool = host.playing()
	# Merlin breathes, and leans in while he is showing.
	var showing := phase == "show"
	merlin.offset.y = -merlin.texture.get_height() / 2.0 - (0.5 + 0.5 * sin(wave * 2.0)) * 3.0
	merlin.rotation = sin(wave * 1.6) * 0.012 + (0.04 if showing else 0.0)
	var extra := {}
	if phase == "turn" or phase == "brew":
		extra = { "arm_upper": -96.0 + sin(wave * 5.0) * 6.0, "arm_lower": -30.0 }  # her wand hand up, ready
	host.step(who, delta, extra)
	# The ingredients on the bench: the one just shown or picked jumps up and glows.
	for i in items.size():
		var node: Sprite2D = items[i]
		var up := maxf(1.0 - float(lift[i]) / 0.5, 0.0)
		var ready := phase == "turn"
		var bob := sin(wave * 3.0 + i * 1.1) * (4.0 if ready else 1.0)
		node.position = spot(i) + Vector2(0.0, -sin(up * PI) * 46.0 + bob - 4.0)
		var k := float(node.get_meta("size")) * (1.0 + 0.3 * sin(up * PI))
		node.scale = Vector2(k, k)
		node.modulate = Color(1.0, 1.0, 1.0) if (ready or up > 0.0 or not playing) else Color(0.72, 0.72, 0.8)
	_fly(delta)
	if playing:
		match phase:
			"show":
				# One ingredient every beat, each into the pot with its note.
				var beat := int((phase_time - 0.9) / 0.85)
				if phase_time > 0.9 and beat > step and beat < seq.size():
					step = beat
					lift[int(seq[step])] = 0.0
					_throw(int(seq[step]))
				if phase_time > 0.9 + seq.size() * 0.85 + 0.5:
					_go("turn")
					step = 0
					want = Color(0.35, 0.8, 0.45)
					game.sound.shout("merlin", "merlin_turn", 1.0, true)
					if potion == 0 and mistakes == 0:
						game.sound.shout("adeline", "my_turn", 1.0)
			"wrong":
				if phase_time > 1.7:
					_go("show")
					step = -1
					want = Color(0.35, 0.8, 0.45)
			"brew":
				if phase_time > 0.7 and bottles.size() <= potion:
					_bottle()
				if phase_time > 2.4:
					potion += 1
					if potion >= LENGTHS.size():
						_go("end")
					else:
						_new_potion()
			"end":
				if phase_time > 0.6:
					host.finish(3 if mistakes == 0 else (2 if mistakes <= 2 else 1), "Four potions, and not one mistake!" if mistakes == 0 else "Four potions bottled. Merlin is proud.")
	# Bubbles rise off the pot all the time; more when it is brewing.
	if randf() < delta * (14.0 if phase == "brew" else 3.0):
		host.spark(mouth() + Vector2(randf_range(-90.0, 90.0), 0.0), "bubble")
	for b in bottles:
		b[1] = float(b[1]) + delta
	brew.queue_redraw()
	queue_redraw()


## Ingredients in the air: up in an arc from the bench and down into the pot.
func _fly(delta: float) -> void:
	for f in flying:
		f[2] = float(f[2]) + delta
		var k := minf(float(f[2]) / 0.5, 1.0)
		var node: Sprite2D = f[0]
		var at: Vector2 = (f[1] as Vector2).lerp(mouth(), k)
		at.y -= sin(k * PI) * 190.0
		node.position = at + Vector2(0.0, node.texture.get_height() * node.scale.y / 2.0)
		node.rotation = k * TAU
		if k >= 1.0:
			_landed(int(f[3]))
			node.queue_free()
	flying = flying.filter(func(f): return float(f[2]) < 0.5)


func _landed(i: int) -> void:
	var c: Color = THINGS[i][1]
	if phase == "wrong":
		# The pot does not like it: grey smoke, and Merlin shows her again.
		want = Color(0.45, 0.45, 0.45)
		for n in 14:
			host.spark(mouth() + Vector2(randf_range(-70.0, 70.0), 0.0), "smoke", Color(0.5, 0.5, 0.55))
		host.word(mouth() + Vector2(0.0, -70.0), "Not that one!", Color(1.0, 0.75, 0.7))
		game.sound.play("poof", -6.0)
		game.sound.shout("merlin", "merlin_oops", 1.0, true)
		return
	want = c
	for n in 8:
		host.spark(mouth() + Vector2(randf_range(-50.0, 50.0), 0.0), "drop", c, Vector2(0.0, -120.0))
	host.burst(mouth(), "star", 3)
	game.sound.play("splash", -9.0, 0.1)


## The potion is done: a bottle of it rises out of the pot.
func _bottle() -> void:
	bottles.append([BOTTLES[potion], 0.0])
	for n in 22:
		host.spark(mouth() + Vector2(randf_range(-80.0, 80.0), randf_range(-30.0, 10.0)), "smoke", liquid)
	host.burst(mouth() + Vector2(0.0, -60.0), "star", 14)
	host.word(mouth() + Vector2(0.0, -150.0), "Potion %d!" % (potion + 1))
	game.sound.play("poof", -5.0, 0.0, 1.3)
	game.sound.play("fanfare", -12.0, 0.0, 1.2)
	game.sound.shout("merlin", "merlin_splendid", 1.0, true)
	who["hop"] = 0.4
	if potion == LENGTHS.size() - 1:
		# The last one has a surprise in it.
		frog = host.picture("res://art/mini/frog.png", mouth(), 104.0, 950)
		game.sound.play("ribbit", -6.0)


## A soft glow under each ingredient while it is Adeline's turn, so they look tappable.
func _draw() -> void:
	if phase != "turn":
		return
	for i in items.size():
		var c: Color = THINGS[i][1]
		var beat := 0.5 + 0.5 * sin(wave * 3.0 + i * 1.1)
		draw_set_transform(spot(i) + Vector2(0.0, -4.0), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, 50.0 + beat * 6.0, Color(c.r, c.g, c.b, 0.35 + 0.2 * beat))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## What is in the cauldron: the potion itself, its shine, its bubbles, and the bottle or
## the frog coming up out of it.
func _draw_brew() -> void:
	var at := mouth() + Vector2(0.0, 8.0)
	var wide := 101.0
	brew.draw_set_transform(at, 0.0, Vector2(1.0, 0.26))
	brew.draw_circle(Vector2.ZERO, wide, liquid.darkened(0.25))
	brew.draw_circle(Vector2(0.0, -6.0), wide - 8.0, liquid)
	brew.draw_arc(Vector2(-10.0, -10.0), wide - 30.0, PI * 1.05, PI * 1.6, 16, Color(1.0, 1.0, 1.0, 0.55), 9.0)
	brew.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for n in 5:
		var t := fmod(wave * (0.7 + n * 0.13) + n * 0.37, 1.0)
		var b := at + Vector2(sin(n * 2.4) * 70.0, sin(n * 5.1) * 9.0)
		brew.draw_circle(b, 4.0 + 9.0 * t, Color(1.0, 1.0, 1.0, 0.5 * (1.0 - t)))
		brew.draw_arc(b, 4.0 + 9.0 * t, 0.0, TAU, 14, liquid.lightened(0.5), 2.0)
	# The glow of the fire under it.
	brew.draw_circle(POT + Vector2(0.0, -14.0), 70.0 + sin(wave * 9.0) * 5.0, Color(1.0, 0.5, 0.15, 0.16))
	# The newest bottle floats up out of the potion, then goes to its place at the top.
	if not bottles.is_empty():
		var newest: Array = bottles[bottles.size() - 1]
		var age := float(newest[1])
		if age < 1.6:
			var tex: Texture2D = bottle_art[str(newest[0])]
			var up := Ui.ease(age / 0.6)
			var size := Vector2(84.0, 84.0 * tex.get_height() / tex.get_width()) * Ui.pop(age / 0.4)
			var c := at + Vector2(0.0, -40.0 - up * 130.0 + sin(wave * 4.0) * 6.0)
			brew.draw_circle(c, 70.0, Color(1.0, 1.0, 0.8, 0.25 * (1.0 - age / 1.6)))
			brew.draw_texture_rect(tex, Rect2(c - size / 2.0, size), false, Color(1.0, 1.0, 1.0, clampf((1.6 - age) * 4.0, 0.0, 1.0)))
	if frog != null:
		# The frog hops out of the last potion and off across the floor.
		var age := float(bottles[bottles.size() - 1][1])
		var hop := fmod(age, 0.6) / 0.6
		frog.position = mouth() + Vector2(minf(age, 3.0) * 120.0, minf(age * 260.0, 196.0) - sin(hop * PI) * 60.0)
		frog.z_index = 950


func draw_ui(on: Control, s: Vector2) -> void:
	var line := "Watch Merlin..."
	if phase == "turn":
		line = "Your turn! Tap them in the same order."
	elif phase == "wrong":
		line = "Oops! Watch again."
	elif phase == "brew" or phase == "end":
		line = "Potion %d of %d is ready!" % [mini(potion + 1, LENGTHS.size()), LENGTHS.size()]
	host.banner(on, line, 26.0)
	# One dot for each ingredient in this potion, filling as they go in.
	var count := seq.size()
	var done := step if phase == "turn" else (count if phase == "brew" else (step + 1 if phase == "show" else 0))
	for i in count:
		var at := Vector2(s.x / 2.0 + (i - (count - 1) / 2.0) * 34.0, 96.0)
		on.draw_circle(at, 12.0, Color(0.09, 0.11, 0.24, 0.7))
		if i < done:
			var c: Color = THINGS[int(seq[i])][1]
			on.draw_circle(at, 9.0, c if phase != "turn" else Color(1.0, 0.9, 0.4))
	# The potions bottled so far.
	for i in LENGTHS.size():
		var r := Rect2(40.0 + i * 58.0, 26.0, 50.0, 66.0)
		Ui.plate(on, r.grow(4.0), Color(0.09, 0.11, 0.24, 0.5))
		if i < bottles.size() and float(bottles[i][1]) > 1.3:
			var k := Ui.pop((float(bottles[i][1]) - 1.3) / 0.3)
			var tex: Texture2D = bottle_art[str(bottles[i][0])]
			on.draw_texture_rect(tex, Rect2(r.get_center() - r.size * k / 2.0, r.size * k), false)
