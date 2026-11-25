extends Node2D
## Everything that makes the island feel alive but is not part of the adventure itself:
## the sky, the sun and drifting clouds; trees, flowers and farmyard things; butterflies,
## birds, rabbits and a frog; the water on the river; and a soft shadow under everybody.
##
## None of it can be bumped into and none of it is saved. It is laid out the same way every
## time, from a fixed set of dice, so the island is always the same island.

const FIXED := [
	# what, where, how big, and which side of the characters: -2 far behind, -1 behind, 3 in front
	["oak", -150.0, 1.0, -2], ["lamp", 664.0, 1.0, -1], ["apple_tree", 790.0, 0.9, -2], ["barrel", 706.0, 1.0, -1],
	["daisies", 742.0, 1.0, 3], ["grass", 868.0, 1.0, 3], ["tulips", 1010.0, 1.0, 3], ["lavender", 1310.0, 1.0, 3],
	["sunflowers", 1505.0, 1.0, -1], ["fence", 1716.0, 1.0, -1], ["fence", 1806.0, 1.0, -1],
	["scarecrow", 1930.0, 1.0, -1], ["cart", 2070.0, 1.0, -1], ["well", 2250.0, 1.0, -1], ["birdhouse", 2420.0, 1.0, -1],
]
const SCATTER := [
	["oak", 5, -2], ["pine", 5, -2], ["apple_tree", 3, -2], ["bush", 5, -1], ["blossom", 5, -1], ["boulder", 3, -1],
	["stump", 2, -1], ["mushrooms", 3, -1], ["daisies", 4, 3], ["tulips", 4, 3], ["lavender", 4, 3], ["sunflowers", 3, -1],
	["grass", 8, 3],
]
const BIRD_GAP := [7.0, 15.0]  # seconds between birds flying over
const LILY_AT := 44.0  # how far out on the river the first lily pad floats
const LILY_GAP := 62.0

var game = null
static var sizes := {}
var sky_layer: CanvasLayer = null
var sky: Sprite2D = null
var sun: Sprite2D = null
var clouds: Array = []  # [sprite, how far along the sky it is (0 to 1), height, pace, size]
var flowers: Array = []  # where the flower clumps are, for butterflies
var butterflies: Array = []
var birds: Array = []
var rabbits: Array = []
var lilies: Array = []
var frog: Sprite2D = null
var frog_home := Vector2.ZERO
var frog_hop := 0.0
var next_bird := 4.0
var clock := 0.0
var taken: Array = []  # stretches of ground that must stay clear: [from, to]


## A scenery picture standing on a spot on the ground, at its proper size.
static func stand(name: String, where: Vector2, size := 1.0) -> Sprite2D:
	if sizes.is_empty():
		sizes = JSON.parse_string(FileAccess.get_file_as_string("res://art/nature/sizes.json"))
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/nature/%s.png" % name)
	var k: float = float(sizes[name]) / sprite.texture.get_height() * size
	sprite.scale = Vector2(k, k)
	sprite.offset = Vector2(0.0, -sprite.texture.get_height() / 2.0)
	sprite.position = where
	return sprite


func _ready() -> void:
	_build_sky()
	_build_island()
	_build_river()
	_build_animals()


# --- The sky ------------------------------------------------------------------------

func _build_sky() -> void:
	sky_layer = CanvasLayer.new()
	sky_layer.layer = -20
	add_child(sky_layer)
	# Deeper blue overhead, paling toward the hills.
	var blue := Gradient.new()
	blue.set_color(0, Color(0.33, 0.62, 0.95))
	blue.set_color(1, Color(0.72, 0.9, 0.98))
	blue.add_point(0.55, Color(0.55, 0.82, 0.95))
	var tex := GradientTexture2D.new()
	tex.gradient = blue
	tex.width = 8
	tex.height = 256
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	sky = Sprite2D.new()
	sky.texture = tex
	sky.centered = false
	sky_layer.add_child(sky)
	sun = Sprite2D.new()
	sun.texture = game.spark
	sun.modulate = Color(1.0, 0.97, 0.75, 0.95)
	sky_layer.add_child(sun)
	var dice := RandomNumberGenerator.new()
	dice.seed = 41
	for i in 5:
		var cloud := Sprite2D.new()
		cloud.texture = load("res://art/sky/cloud_%d.png" % (i % 3))
		cloud.modulate = Color(1.0, 1.0, 1.0, 0.8)
		sky_layer.add_child(cloud)
		clouds.append([cloud, (i + dice.randf()) / 5.0, dice.randf_range(0.16, 0.4), dice.randf_range(0.004, 0.011), dice.randf_range(0.4, 0.7)])


func _sky_frame(delta: float) -> void:
	var s := get_viewport_rect().size
	sky.scale = Vector2(s.x / 8.0, s.y / 256.0)
	sun.position = Vector2(s.x * 0.82, s.y * 0.14)
	var glow := 1.0 + 0.03 * sin(clock * 0.8)
	sun.scale = Vector2(5.2, 5.2) * glow
	# Clouds drift on the wind, and slide a little as the camera moves, wrapping round.
	var slide: float = game.cam_pos.x * 0.00002
	for entry in clouds:
		entry[1] = fposmod(float(entry[1]) + float(entry[3]) * delta, 1.0)
		var cloud: Sprite2D = entry[0]
		var along := fposmod(float(entry[1]) - slide * (0.5 + float(entry[4])), 1.0)
		cloud.position = Vector2(-220.0 + along * (s.x + 440.0), s.y * float(entry[2]))
		cloud.scale = Vector2(float(entry[4]), float(entry[4]))
	sky_layer.visible = game.mode != "house" and game.mode != "stable"


# --- Trees, flowers and farmyard things ------------------------------------------------

func _put(name: String, x: float, size: float, depth: int, sink := 0.0) -> Sprite2D:
	var sprite := stand(name, Vector2(x, game.GROUND_Y + 5.0 + sink), size)
	sprite.z_index = depth
	if depth <= -2:
		sprite.modulate = Color(0.93, 0.96, 1.0)  # a touch paler, so it sits back
	add_child(sprite)
	if name in ["daisies", "tulips", "lavender", "sunflowers", "blossom"]:
		flowers.append(Vector2(x, game.GROUND_Y - float(sizes[name]) * size * 0.8))
	return sprite


func _free_at(x: float, room: float) -> bool:
	for stretch in taken:
		if x + room > float(stretch[0]) and x - room < float(stretch[1]):
			return false
	return true


func _build_island() -> void:
	# The ground that belongs to buildings, people and the missions stays clear.
	taken = [[game.HOUSE_X - 40.0, 640.0], [game.HUT_X - 280.0, game.HUT_X + 280.0], [game.MERLIN_X - 60.0, game.MERLIN_X + 60.0],
		[game.SIGN_X - 50.0, game.SIGN_X + 50.0], [game.RIVER_X - 150.0, 99999.0], [game.mission3.NET_X - 190.0, game.mission3.NET_X + 190.0]]
	for enc in game.ENCOUNTERS:
		taken.append([float(enc["right"]) - 190.0, float(enc["right"]) + 90.0])
	for item in FIXED:
		_put(str(item[0]), float(item[1]), float(item[2]), int(item[3]), 12.0 if int(item[3]) > 0 else 0.0)
		taken.append([float(item[1]) - 40.0, float(item[1]) + 40.0])
	var dice := RandomNumberGenerator.new()
	dice.seed = 2024
	for kind in SCATTER:
		var name := str(kind[0])
		var depth := int(kind[2])
		var room := 90.0 if depth <= -2 else 46.0
		for n in int(kind[1]):
			for attempt in 12:
				var x := dice.randf_range(1960.0, game.RIVER_X - 170.0)
				if _free_at(x, room):
					_put(name, x, dice.randf_range(0.85, 1.12), depth, dice.randf_range(8.0, 16.0) if depth > 0 else 0.0).flip_h = dice.randf() < 0.5
					# Trees may overlap flowers, but not each other.
					if depth <= -2 or name in ["boulder", "stump"]:
						taken.append([x - room, x + room])
					break


# --- The river -----------------------------------------------------------------------------

func _build_river() -> void:
	# Two lily pads on the near water, this side of the boat, and a frog that goes between them.
	var dice := RandomNumberGenerator.new()
	dice.seed = 77
	for i in 2:
		var x: float = game.RIVER_X + LILY_AT + i * LILY_GAP
		var lily := stand("lily", Vector2(x, game.GROUND_Y + 36.0), 1.25)
		lily.z_index = 3
		add_child(lily)
		lilies.append([lily, lily.position.y, dice.randf() * TAU])
	frog_home = Vector2(game.RIVER_X + LILY_AT, game.GROUND_Y + 16.0)
	frog = stand("frog", frog_home)
	frog.z_index = 3
	frog.flip_h = true
	add_child(frog)


# --- Animals --------------------------------------------------------------------------------

func _build_animals() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 9
	for i in mini(7, flowers.size()):
		var home: Vector2 = flowers[(i * 3) % flowers.size()]
		var node := Sprite2D.new()
		node.texture = load("res://art/nature/butterfly_a.png")
		node.z_index = 3
		node.modulate = Color.from_hsv(dice.randf(), 0.25, 1.0)
		add_child(node)
		butterflies.append({ "node": node, "home": home, "phase": dice.randf() * TAU, "pace": dice.randf_range(0.7, 1.3) })
	for x in [2300.0, 3350.0, 4250.0]:
		var node := stand("rabbit_a", Vector2(x, game.GROUND_Y + 4.0))
		node.z_index = -1
		add_child(node)
		rabbits.append({ "node": node, "x": x, "home": x, "hops": 0, "air": 0.0, "dir": 1.0, "rest": 0.0 })


func _animals_frame(delta: float) -> void:
	var a_tex: Texture2D = load("res://art/nature/butterfly_a.png")
	var b_tex: Texture2D = load("res://art/nature/butterfly_b.png")
	for b in butterflies:
		var node: Sprite2D = b["node"]
		var t: float = clock * float(b["pace"]) + float(b["phase"])
		var home: Vector2 = b["home"]
		var at := home + Vector2(sin(t * 0.7) * 70.0 + sin(t * 1.9) * 18.0, -30.0 + sin(t * 1.1) * 34.0 + sin(t * 3.3) * 8.0)
		# They flutter up out of the way when Adeline comes by, and drift back down after.
		var near := clampf(1.0 - absf(at.x - float(game.player.position.x)) / 150.0, 0.0, 1.0)
		b["shy"] = move_toward(float(b.get("shy", 0.0)), near, delta * (3.0 if near > float(b.get("shy", 0.0)) else 0.8))
		at.y -= float(b["shy"]) * 150.0
		node.flip_h = cos(t * 0.7) < 0.0
		node.position = at
		var open := sin(t * 16.0) > 0.0
		node.texture = a_tex if open else b_tex
		var k: float = float(sizes["butterfly_a" if open else "butterfly_b"]) / node.texture.get_height()
		node.scale = Vector2(k, k)
	# A rabbit sits and nibbles until Adeline comes close, then hops off a little way.
	var px: float = game.player.position.x
	for r in rabbits:
		var node: Sprite2D = r["node"]
		r["rest"] = maxf(float(r["rest"]) - delta, 0.0)
		if int(r["hops"]) == 0 and float(r["rest"]) <= 0.0 and game.mode == "play":
			if absf(px - float(r["x"])) < 170.0:
				r["dir"] = 1.0 if float(r["x"]) > px else -1.0
				r["hops"] = 4
			elif absf(float(r["x"]) - float(r["home"])) > 30.0 and absf(px - float(r["x"])) > 520.0:
				r["dir"] = 1.0 if float(r["home"]) > float(r["x"]) else -1.0
				r["hops"] = 2
		var lift := 0.0
		if int(r["hops"]) > 0:
			r["air"] = float(r["air"]) + delta / 0.34
			r["x"] = float(r["x"]) + float(r["dir"]) * 230.0 * delta
			lift = sin(minf(float(r["air"]), 1.0) * PI) * 26.0
			if float(r["air"]) >= 1.0:
				r["air"] = 0.0
				r["hops"] = int(r["hops"]) - 1
				if int(r["hops"]) == 0:
					r["rest"] = 1.2
		var hopping := int(r["hops"]) > 0
		node.texture = load("res://art/nature/rabbit_b.png" if hopping else "res://art/nature/rabbit_a.png")
		var k: float = float(sizes["rabbit_b" if hopping else "rabbit_a"]) / node.texture.get_height()
		node.scale = Vector2(k, k * (1.0 if hopping else 1.0 + sin(clock * 9.0 + float(r["home"])) * 0.03))
		node.offset = Vector2(0.0, -node.texture.get_height() / 2.0)
		node.flip_h = float(r["dir"]) < 0.0
		node.position = Vector2(float(r["x"]), game.GROUND_Y + 4.0 - lift)
	# Birds cross the sky now and then.
	next_bird -= delta
	if next_bird <= 0.0 and birds.size() < 3 and game.mode != "house" and game.mode != "stable":
		next_bird = randf_range(BIRD_GAP[0], BIRD_GAP[1])
		var way := 1.0 if randf() < 0.5 else -1.0
		var view: Vector2 = get_viewport_rect().size / float(game.zoom)
		var node := Sprite2D.new()
		node.z_index = -3
		add_child(node)
		birds.append({ "node": node, "x": game.cam_pos.x - way * (view.x / 2.0 + 60.0), "y": game.cam_pos.y - view.y * randf_range(0.18, 0.42), "way": way, "pace": randf_range(170.0, 250.0), "phase": randf() * TAU })
	for b in birds:
		var node: Sprite2D = b["node"]
		b["x"] = float(b["x"]) + float(b["way"]) * float(b["pace"]) * delta
		var t := clock * 9.0 + float(b["phase"])
		var up := sin(t) > 0.0
		node.texture = load("res://art/nature/bird_a.png" if up else "res://art/nature/bird_b.png")
		var k: float = float(sizes["bird_a" if up else "bird_b"]) / node.texture.get_height()
		node.scale = Vector2(k, k)
		node.flip_h = float(b["way"]) < 0.0
		node.position = Vector2(float(b["x"]), float(b["y"]) + sin(clock * 1.3 + float(b["phase"])) * 14.0)
		if absf(float(b["x"]) - game.cam_pos.x) > 1500.0:
			node.queue_free()
			b["gone"] = true
	birds = birds.filter(func(b): return not b.has("gone"))
	# Lily pads bob, and the frog jumps to the next one every so often.
	for entry in lilies:
		entry[0].position.y = float(entry[1]) + sin(clock * 1.6 + float(entry[2])) * 2.5
	frog_hop -= delta
	if frog_hop < -5.0 and absf(px - frog_home.x) < 900.0:
		frog_hop = 0.5
		frog.flip_h = not frog.flip_h
	var jump := sin(clampf(frog_hop / 0.5, 0.0, 1.0) * PI) * 46.0
	if frog_hop > 0.0:
		frog_home.x += (LILY_GAP if not frog.flip_h else -LILY_GAP) * delta / 0.5
		frog_home.x = clampf(frog_home.x, game.RIVER_X + LILY_AT, game.RIVER_X + LILY_AT + LILY_GAP)
	frog.position = frog_home + Vector2(0.0, -jump + sin(clock * 1.6) * 2.0)


func _physics_process(delta: float) -> void:
	clock += delta
	_sky_frame(delta)
	_animals_frame(delta)
	queue_redraw()


func _draw() -> void:
	var g: float = game.GROUND_Y
	# The river: bands of lighter water that slide along, and glints of sun.
	var from: float = game.RIVER_X
	for row in 5:
		var y := g + 22.0 + row * 34.0
		var points := PackedVector2Array()
		for i in 41:
			var x := from + i * 20.0
			points.append(Vector2(x, y + sin(x * 0.03 + clock * (1.4 + row * 0.3) + row) * 3.5))
		draw_polyline(points, Color(0.75, 0.9, 1.0, 0.5 - row * 0.07), 4.0 - row * 0.5)
	for i in 9:
		var t := fposmod(clock * 0.35 + i * 0.37, 1.0)
		var at := Vector2(from + 40.0 + fposmod(i * 173.0, 740.0), g + 20.0 + fposmod(i * 61.0, 110.0))
		var r := sin(t * PI) * 7.0
		draw_line(at - Vector2(r, 0.0), at + Vector2(r, 0.0), Color(1.0, 1.0, 1.0, 0.8 * sin(t * PI)), 2.0)
		draw_line(at - Vector2(0.0, r * 0.6), at + Vector2(0.0, r * 0.6), Color(1.0, 1.0, 1.0, 0.8 * sin(t * PI)), 2.0)
	if game.mode != "play":
		return
	# A soft shadow on the ground under everybody.
	var p = game.player
	if p.mounted:
		_shadow(p.position.x, 64.0, p.position.y)
	else:
		_shadow(p.position.x, 26.0, p.position.y)
		if game.horse.state != "mounted":
			_shadow(game.horse.position.x, 60.0, g)
	var sis = game.sister
	if sis.mode != "aboard":
		_shadow(sis.pony_x, 42.0, g)
		if sis.on_foot:
			_shadow(sis.x, 18.0, g)
	for gob in game.goblins:
		if is_instance_valid(gob) and not gob.is_dead():
			_shadow(gob.position.x, 26.0 * gob.size, gob.position.y)
	_shadow(game.MERLIN_X, 30.0, g)


func _shadow(x: float, half: float, feet_y: float) -> void:
	var g: float = game.GROUND_Y
	var high := clampf((g - feet_y) / 420.0, 0.0, 1.0)
	draw_set_transform(Vector2(x, g + 4.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, half * (1.0 - 0.45 * high), Color(0.0, 0.0, 0.0, 0.26 * (1.0 - 0.7 * high)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
