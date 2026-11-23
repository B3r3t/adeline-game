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
var rider = null  # a second copy of Adeline's rig that shows only her near leg


func _ready() -> void:
	font = ThemeDB.fallback_font
	rig = Node2D.new()
	rig.set_script(RigScript)
	add_child(rig)
	rig.build("res://art/spirit")
	# The far legs sit in shadow.
	for part in ["leg_front_far_upper", "leg_front_far_lower", "leg_hind_far_upper", "leg_hind_far_lower"]:
		rig.tint(part, Color(0.72, 0.72, 0.78))
	# Borrow Adeline's leg art for the rider's near leg.
	rider = Node2D.new()
	rider.set_script(RigScript)
	rig.add_child(rider)
	rider.build("res://art/adeline")
	rider.show_only("leg_near")
	rider.visible = false


func place(x: float) -> void:
	position = Vector2(x, game.GROUND_Y)
	state = "idle"
	facing = 1
	speed = 0.0
	z_index = 0
	reset_physics_interpolation()


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
	if rig.scale.x != facing:
		rig.scale.x = facing
		rig.reset_physics_interpolation()
	var pose := { "tail": sin(clock * 2.0) * 5.0 + pace * 26.0, "body": sin(stride) * 2.5 * pace }
	# A gallop: each leg reaches forward, folds at the joint as it swings through, then pushes back.
	_leg(pose, "leg_front_near", stride, pace, true)
	_leg(pose, "leg_front_far", stride + 0.7, pace, true)
	_leg(pose, "leg_hind_near", stride + 2.1, pace, false)
	_leg(pose, "leg_hind_far", stride + 2.8, pace, false)
	rig.pose = pose
	rig.root_offset = Vector2(0.0, -absf(sin(stride)) * 6.0 * pace)
	rig.apply()
	# Adeline's near leg, drawn over Spirit's side while she rides.
	rider.visible = state == "mounted"
	rider.root_offset = seat() - rider.rest_pos("torso")
	rider.pose = { "leg_near_upper": -52.0, "leg_near_lower": 62.0 }
	rider.apply()


func _leg(pose: Dictionary, part: String, phase: float, pace: float, front: bool) -> void:
	var swing := sin(phase)
	var through := maxf(0.0, -cos(phase))  # 1 in the middle of the forward swing
	if front:
		pose[part + "_upper"] = swing * 36.0 * pace
		pose[part + "_lower"] = through * 72.0 * pace
	else:
		pose[part + "_upper"] = swing * 30.0 * pace
		pose[part + "_lower"] = (minf(0.0, swing) * 34.0 - through * 26.0 + maxf(0.0, swing) * 10.0) * pace


## Where a rider sits, relative to Spirit's feet and facing right.
func seat() -> Vector2:
	return rig.rest_pos("body") + rig.root_offset + SEAT


func _draw() -> void:
	if state != "mounted" and game.mode == "play" and absf(game.player.position.x - position.x) < 260.0:
		var y := -170.0
		draw_string_outline(font, Vector2(-60.0, y), NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, 5, Color(0.0, 0.0, 0.0, 0.5))
		draw_string(font, Vector2(-60.0, y), NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, Color.WHITE)
