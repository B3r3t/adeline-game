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
	if state == "mounted":
		return  # Adeline moves Spirit while she rides, so the two never drift apart
	clock += delta
	var p = game.player
	match state:
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


## Called by Adeline each tick while she rides, right after she has moved.
func carry(delta: float) -> void:
	clock += delta
	var p = game.player
	position = p.position
	facing = p.facing
	speed = p.velocity.length()
	_hoofbeats(speed * delta * 0.035, not p.air)
	if state != "idle" and absf(position.x - p.position.x) < 800.0:
		_hoofbeats(speed * delta * 0.035, true)
	stride += speed * delta * 0.035
	_animate()
	queue_redraw()


## A gallop is three quick beats and a moment in the air. The beats follow Spirit's
## stride, so they speed up and slow down with her.
func _hoofbeats(advance: float, on_ground: bool) -> void:
	if not on_ground or speed < 80.0:
		return
	var before := fmod(stride, TAU) / TAU
	var after := before + advance / TAU
	for beat in [0.08, 0.26, 0.44]:
		if (before < beat and after >= beat) or (after >= 1.0 + beat):
			game.sound.play("clop", -9.0 + 3.0 * clampf(speed / 600.0, 0.0, 1.0), 0.14, 1.0, 0.0)


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
	var bounce := -absf(sin(stride)) * 6.0 * pace
	if state == "mounted" and game.player.air:
		# In the air: front legs tuck going up and reach out coming down.
		var rising: bool = game.player.velocity.y < 0.0
		pose["body"] = -9.0 if rising else 7.0
		for side in ["near", "far"]:
			pose["leg_front_%s_upper" % side] = -52.0 if rising else -34.0
			pose["leg_front_%s_lower" % side] = 84.0 if rising else 22.0
			pose["leg_hind_%s_upper" % side] = 34.0 if rising else 16.0
			pose["leg_hind_%s_lower" % side] = 12.0 if rising else -42.0
		pose["tail"] = 34.0
		bounce = 0.0
	rig.pose = pose
	# On a hill Spirit tips to match it, turning about her hooves so all four stay on the ground.
	var tilt: float = game.player.pitch * facing if state == "mounted" else 0.0
	var joint: Vector2 = rig.rest_pos("body")
	rig.root_angle = tilt
	rig.root_offset = Vector2(0.0, bounce) + joint.rotated(tilt) - joint
	rig.apply()
	# Adeline's near leg, drawn over Spirit's side while she rides.
	rider.visible = state == "mounted"
	rider.root_offset = seat() - rider.rest_pos("torso")
	rider.root_angle = tilt
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
	return rig.rest_pos("body") + rig.root_offset + SEAT.rotated(rig.root_angle)


func _draw() -> void:
	if state != "mounted" and game.mode == "play" and absf(game.player.position.x - position.x) < 260.0:
		var y := -170.0
		draw_string_outline(font, Vector2(-60.0, y), NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, 5, Color(0.0, 0.0, 0.0, 0.5))
		draw_string(font, Vector2(-60.0, y), NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, Color.WHITE)
