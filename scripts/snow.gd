extends Control
## Snow falling, at Christmas, wherever the game is out of doors: on the title, over the
## island, on the riding course, in the sky and on the farm. It is only a picture laid
## over the scene; nothing touches it. It falls faster and slants when riding or flying.

const Season := preload("res://scripts/season.gd")
const FLAKES := 90

var game = null
var flakes: Array = []  # each: [where (0..1 across and down), size, fall, sway, big]
var art: Array = []
var clock := 0.0
var showing := 0.0  # fades in and out as the game goes outdoors and in


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3900  # over everything in a scene, under the words and buttons
	visible = Season.festive()
	if not visible:
		set_process(false)
		return
	art = [load(Season.WINTER + "extra/flake_a.png"), load(Season.WINTER + "extra/flake_b.png")]
	var dice := RandomNumberGenerator.new()
	dice.seed = 1225
	for i in FLAKES:
		flakes.append([Vector2(dice.randf(), dice.randf()), dice.randf_range(2.0, 5.5), dice.randf_range(0.05, 0.13), dice.randf() * TAU, i % 9 == 0])


## Whether the game is somewhere the snow can fall.
func outdoors() -> bool:
	if game.mode == "house" or game.mode == "stable" or game.mode == "shop":
		return false
	if game.mode == "mini":
		return not (game.mini.scene() in ["hut", "burrow", "den"])
	return true


func _process(delta: float) -> void:
	if game == null:
		return
	clock += delta
	showing = move_toward(showing, 1.0 if outdoors() else 0.0, delta * 3.0)
	var rush := 2.4 if (game.mode == "ride" or game.mode == "sky") else 1.0
	for f in flakes:
		var at: Vector2 = f[0]
		at.y += float(f[2]) * delta * rush
		at.x += (sin(clock * 0.9 + float(f[3])) * 0.012 - (0.05 if rush > 1.0 else 0.0)) * delta * rush
		if at.y > 1.04:
			at = Vector2(randf(), -0.04)
		at.x = fposmod(at.x, 1.0)
		f[0] = at
	queue_redraw()


func _draw() -> void:
	if showing <= 0.01:
		return
	var s := get_viewport_rect().size
	for i in flakes.size():
		var f: Array = flakes[i]
		var at := Vector2(float(f[0].x) * s.x, float(f[0].y) * s.y)
		if bool(f[4]):
			# Now and then a big one, close to the eye, turning as it falls.
			var tex: Texture2D = art[i % 2]
			var size := 26.0 + float(f[1]) * 3.0
			draw_set_transform(at, clock * 0.6 + float(f[3]), Vector2.ONE)
			draw_texture_rect(tex, Rect2(-size / 2.0, -size / 2.0, size, size), false, Color(1.0, 1.0, 1.0, 0.85 * showing))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(at, float(f[1]), Color(1.0, 1.0, 1.0, 0.85 * showing))
