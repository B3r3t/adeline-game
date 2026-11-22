extends Node2D
## Spirit, Adeline's horse: dark brown with a black mane and tail.
## Spirit waits in the stable, comes when called, carries Adeline at a gallop,
## and stays back from goblin fights. Built from cutout art.

const RigScript := preload("res://scripts/rig.gd")

const GALLOP := 620.0
const SEAT := Vector2(-32.0, -27.0)  # the dip of Spirit's back, measured from the body joint
const NAME := "Spirit"

var game = null
var font: Font
var state := "idle"  # idle, coming, retreat or mounted
var facing := 1
var target_x := 0.0
var speed := 0.0  # ground speed, drives the leg animation
var stride := 0.0
var clock := 0.0
var rig = null
var rider_leg: Sprite2D


func _ready() -> void:
	font = ThemeDB.fallback_font
	rig = Node2D.new()
	rig.set_script(RigScript)
	add_child(rig)
	rig.build("res://art/spirit")
	# The far legs sit in shadow.
	rig.tint("leg_front_far", Color(0.72, 0.72, 0.78))
	rig.tint("leg_hind_far", Color(0.72, 0.72, 0.78))
	# Borrow Adeline's leg art for the rider's near leg.
	var adeline = JSON.parse_string(FileAccess.get_file_as_string("res://art/adeline/rig.json"))
	rider_leg = Sprite2D.new()
	rider_leg.texture = load("res://art/adeline/leg_near.png")
	rider_leg.centered = false
	for part in adeline["parts"]:
		if part["name"] == "leg_near":
			rider_leg.offset = -Vector2(part["pivot"][0], part["pivot"][1])
	var s := float(adeline["tex_scale"])
	rider_leg.scale = Vector2(s, s)
	rider_leg.rotation = deg_to_rad(-34.0)
	rider_leg.visible = false
	rig.add_child(rider_leg)


func place(x: float) -> void:
	position = Vector2(x, game.GROUND_Y)
	state = "idle"
	facing = 1
	speed = 0.0
	z_index = 0


func come() -> void:
	if state != "mounted":
		state = "coming"


func retreat(x: float) -> void:
	target_x = x
	state = "retreat"
	z_index = 0


func set_mounted(on: bool) -> void:
	state = "mounted" if on else "idle"
	z_index = 1 if on else 0  # in front of Adeline while she rides


func _physics_process(delta: float) -> void:
	clock += delta
	var p = game.player
	match state:
		"mounted":
			position = p.position
			facing = p.facing
			speed = absf(p.velocity.x)
		"coming":
			var side := 1.0 if p.position.x >= position.x else -1.0
			if _move_to(p.position.x - 80.0 * side, GALLOP, delta):
				state = "idle"
				facing = int(side)
		"retreat":
			if _move_to(target_x, GALLOP * 0.7, delta):
				state = "idle"
		_:
			speed = move_toward(speed, 0.0, 2400.0 * delta)
	stride += speed * delta * 0.035
	_animate()
	queue_redraw()


func _move_to(x: float, pace: float, delta: float) -> bool:
	position.y = game.GROUND_Y
	var dx := x - position.x
	if absf(dx) < 6.0:
		speed = 0.0
		return true
	facing = 1 if dx > 0.0 else -1
	position.x += minf(absf(dx), pace * delta) * facing
	speed = pace
	return false


func _animate() -> void:
	var pace := clampf(speed / 560.0, 0.0, 1.0)
	rig.scale.x = facing
	rig.pose = {
		"leg_front_near": sin(stride) * 34.0 * pace,
		"leg_front_far": sin(stride + 0.8) * 34.0 * pace,
		"leg_hind_near": sin(stride + PI) * 30.0 * pace,
		"leg_hind_far": sin(stride + PI + 0.8) * 30.0 * pace,
		"tail": sin(clock * 2.0) * 5.0 + pace * 26.0,
		"body": sin(stride * 2.0) * 2.5 * pace,
	}
	rig.root_offset = Vector2(0.0, -absf(sin(stride)) * 5.0 * pace)
	rig.apply()
	# Adeline's near leg, drawn over Spirit's side while she rides.
	rider_leg.visible = state == "mounted"
	rider_leg.position = seat() + Vector2(2.0, 2.0)


## Where a rider sits, relative to Spirit's feet and facing right.
func seat() -> Vector2:
	return rig.rest_pos("body") + rig.root_offset + SEAT


func _draw() -> void:
	if state != "mounted" and game.mode == "play" and absf(game.player.position.x - position.x) < 260.0:
		var y := -170.0
		draw_string_outline(font, Vector2(-60.0, y), NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, 5, Color(0.0, 0.0, 0.0, 0.5))
		draw_string(font, Vector2(-60.0, y), NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, Color.WHITE)
