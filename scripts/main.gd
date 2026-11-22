extends Node2D
## Grey-box goblin fight. Everything is built here from simple shapes so the
## feel of movement, combat and touch controls can be tested before any art exists.

const PlayerScript := preload("res://scripts/player.gd")
const GoblinScript := preload("res://scripts/goblin.gd")
const HillsScript := preload("res://scripts/hills.gd")
const HudScript := preload("res://scripts/hud.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")

const GROUND_Y := 560.0
const LEVEL_LEFT := 0.0
const LEVEL_RIGHT := 2600.0
const PLAYER_START_X := 420.0
const MAX_GOBLINS := 3
const CAMERA_ZOOM := 1.4  # bigger characters are easier to read on an 8 inch screen

var player = null
var goblins: Array = []
var projectiles: Node2D
var camera: Camera2D
var hills_far: Node2D
var hills_near: Node2D
var hud = null
var controls = null

var round_number := 1
var attacker = null  # only one goblin attacks at a time
var state := "fighting"  # fighting, won or lost
var state_time := 0.0


func _ready() -> void:
	_setup_input()
	_build_backdrop()
	_build_ground()

	projectiles = Node2D.new()
	add_child(projectiles)

	player = CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.game = self
	add_child(player)

	camera = Camera2D.new()
	camera.limit_left = int(LEVEL_LEFT)
	camera.limit_right = int(LEVEL_RIGHT)
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(HudScript)
	hud.game = self
	layer.add_child(hud)
	controls = Control.new()
	controls.set_script(TouchScript)
	controls.game = self
	layer.add_child(controls)

	_start_round()
	camera.position = _camera_target()
	camera.reset_smoothing()


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("strike", [KEY_J, KEY_Z])
	_add_action("fireball", [KEY_K, KEY_X])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _build_backdrop() -> void:
	hills_far = Node2D.new()
	hills_far.set_script(HillsScript)
	hills_far.color = Color(0.62, 0.84, 0.72)
	hills_far.base_y = GROUND_Y - 40.0
	hills_far.amplitude = 190.0
	hills_far.wavelength = 900.0
	hills_far.z_index = -20
	add_child(hills_far)

	hills_near = Node2D.new()
	hills_near.set_script(HillsScript)
	hills_near.color = Color(0.45, 0.75, 0.5)
	hills_near.base_y = GROUND_Y - 10.0
	hills_near.amplitude = 110.0
	hills_near.wavelength = 520.0
	hills_near.phase = 1.7
	hills_near.z_index = -10
	add_child(hills_near)


func _build_ground() -> void:
	_add_wall(Rect2(LEVEL_LEFT - 400.0, GROUND_Y, LEVEL_RIGHT - LEVEL_LEFT + 800.0, 400.0))
	_add_wall(Rect2(LEVEL_LEFT - 200.0, GROUND_Y - 1200.0, 200.0, 1200.0))
	_add_wall(Rect2(LEVEL_RIGHT, GROUND_Y - 1200.0, 200.0, 1200.0))


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = rect.position + rect.size / 2.0
	body.add_child(col)
	add_child(body)


func _start_round() -> void:
	for g in goblins:
		if is_instance_valid(g):
			g.queue_free()
	goblins.clear()
	for p in projectiles.get_children():
		p.queue_free()
	attacker = null
	state = "fighting"
	state_time = 0.0
	player.reset(Vector2(PLAYER_START_X, GROUND_Y))

	var count := mini(round_number, MAX_GOBLINS)
	for i in count:
		var g = CharacterBody2D.new()
		g.set_script(GoblinScript)
		g.game = self
		g.hold_slot = i
		g.think = 0.6 + 0.4 * i
		g.position = Vector2(PLAYER_START_X + 620.0 + 170.0 * i, GROUND_Y)
		add_child(g)
		goblins.append(g)


func add_projectile(node: Node2D) -> void:
	projectiles.add_child(node)


# --- One attacker at a time -------------------------------------------------

func can_attack(goblin) -> bool:
	return attacker == null or not is_instance_valid(attacker) or attacker == goblin


func request_attack(goblin) -> bool:
	if can_attack(goblin):
		attacker = goblin
		return true
	return false


func release_attack(goblin) -> void:
	if attacker == goblin:
		attacker = null


# --- Win and lose -----------------------------------------------------------

func goblins_left() -> int:
	var n := 0
	for g in goblins:
		if is_instance_valid(g) and not g.is_dead():
			n += 1
	return n


func on_goblin_defeated(_goblin) -> void:
	if goblins_left() == 0 and state == "fighting":
		state = "won"
		state_time = 0.0


func on_player_defeated() -> void:
	if state == "fighting":
		state = "lost"
		state_time = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if state == "fighting" or state_time < 1.0:
		return
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventKey and event.pressed and not event.echo:
		tapped = true
	if tapped:
		if state == "won":
			round_number += 1
		_start_round()


func _camera_target() -> Vector2:
	var view_h := get_viewport_rect().size.y
	# Keep the ground about three quarters of the way down the screen on any device.
	return Vector2(player.position.x + player.facing * 60.0, GROUND_Y - 0.24 * view_h / CAMERA_ZOOM)


func _process(delta: float) -> void:
	state_time += delta
	camera.position = _camera_target()
	var cam_x := camera.get_screen_center_position().x
	hills_far.position.x = cam_x * 0.85
	hills_near.position.x = cam_x * 0.6


func _draw() -> void:
	# Grass and dirt.
	var left := LEVEL_LEFT - 400.0
	var width := LEVEL_RIGHT - LEVEL_LEFT + 800.0
	draw_rect(Rect2(left, GROUND_Y, width, 600.0), Color(0.42, 0.3, 0.2))
	draw_rect(Rect2(left, GROUND_Y, width, 26.0), Color(0.36, 0.72, 0.3))
	# Markers so movement is easy to read while there is no art.
	var x := LEVEL_LEFT
	var i := 0
	while x <= LEVEL_RIGHT:
		draw_rect(Rect2(x - 3.0, GROUND_Y - 34.0, 6.0, 34.0), Color(0.5, 0.36, 0.22))
		draw_circle(Vector2(x + 90.0, GROUND_Y + 60.0 + (i % 3) * 30.0), 10.0, Color(0.36, 0.25, 0.17))
		x += 200.0
		i += 1
