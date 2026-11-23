extends CharacterBody2D
## Placeholder Adeline, built from simple shapes. Her origin is at her feet.
## Timing, damage and reach numbers are at the top so they are easy to tune after playtests.

const FireballScript := preload("res://scripts/fireball.gd")
const RigScript := preload("res://scripts/rig.gd")

const SPEED := 300.0
const ACCEL := 2600.0
const GRAVITY := 1900.0
const JUMP_VELOCITY := -760.0
const WIDTH := 44.0
const HEIGHT := 88.0
const MAX_HEALTH := 5

# Wand strike: weak but quick. Windup, a brief window where it can hit, then recovery.
const STRIKE_WINDUP := 0.06
const STRIKE_ACTIVE := 0.1
const STRIKE_RECOVERY := 0.14
const STRIKE_REACH := 80.0
const STRIKE_DAMAGE := 1

# Fireball: three times the wand's damage, with a short wait between casts.
const FIREBALL_COOLDOWN := 1.2
const CAST_POSE_TIME := 0.32
const FIREBALL_DAMAGE := 3

# Magic shield, earned from Mission 1.
const SHIELD_TIME := 0.6
const SHIELD_COOLDOWN := 2.2

const HURT_INVULN := 0.9

# Riding Spirit: faster, with a longer jump. Fireballs work from the saddle.
const RIDE_SPEED := 560.0
const RIDE_JUMP := -820.0

# What take_hit reports back to an attacker.
const MISSED := 0
const HURT := 1
const BLOCKED := 2

var game = null
var facing := 1
var health := MAX_HEALTH
var dead := false
var strike_time := -1.0  # below zero means not striking
var strike_hits: Array = []
var fireball_cd := 0.0
var shield_time := 0.0  # time left on an active shield
var shield_cd := 0.0
var block_flash := 0.0
var invuln := 0.0
var knock := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var anim_time := 0.0
var mounted := false
var cast_time := 9.0  # seconds since the last fireball, for the casting pose
var walk_phase := 0.0
var rig = null
var min_x := -INF
var max_x := INF


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH, HEIGHT)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0.0, -HEIGHT / 2.0)
	add_child(col)
	rig = Node2D.new()
	rig.set_script(RigScript)
	add_child(rig)
	rig.build("res://art/adeline")


func reset(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	facing = 1
	health = MAX_HEALTH
	dead = false
	strike_time = -1.0
	strike_hits.clear()
	fireball_cd = 0.0
	shield_time = 0.0
	shield_cd = 0.0
	block_flash = 0.0
	invuln = 0.0
	knock = 0.0
	mounted = false
	reset_physics_interpolation()


func body_rect() -> Rect2:
	return Rect2(position.x - WIDTH / 2.0, position.y - HEIGHT, WIDTH, HEIGHT)


func is_striking() -> bool:
	return strike_time >= 0.0


func is_shielding() -> bool:
	return shield_time > 0.0


func _physics_process(delta: float) -> void:
	anim_time += delta
	cast_time += delta
	fireball_cd = maxf(fireball_cd - delta, 0.0)
	shield_cd = maxf(shield_cd - delta, 0.0)
	shield_time = maxf(shield_time - delta, 0.0)
	block_flash = maxf(block_flash - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	knock = move_toward(knock, 0.0, 1400.0 * delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
		coyote = maxf(coyote - delta, 0.0)
	else:
		coyote = 0.1
		walk_phase += absf(velocity.x) * delta * 0.06

	var locked: bool = dead or game.input_locked()
	var dir := 0.0 if locked else Input.get_axis("move_left", "move_right")
	if dir != 0.0 and not is_striking():
		facing = 1 if dir > 0.0 else -1
	var speed := SPEED * (0.6 if is_striking() else 1.0)
	if mounted:
		speed = RIDE_SPEED
	velocity.x = move_toward(velocity.x, dir * speed, ACCEL * delta)

	if not locked:
		_read_actions(delta)
	if is_striking():
		_update_strike(delta)

	var walk := velocity.x
	velocity.x += knock
	move_and_slide()
	velocity.x = walk
	position.x = clampf(position.x, min_x, max_x)
	_animate()
	queue_redraw()


func _read_actions(delta: float) -> void:
	# Jump, with a little forgiveness on both sides of the button press.
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.12
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = RIDE_JUMP if mounted else JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
	if Input.is_action_just_released("jump") and velocity.y < -260.0:
		velocity.y = -260.0  # letting go early makes a shorter hop
	if Input.is_action_just_pressed("fireball") and fireball_cd <= 0.0:
		_cast_fireball()
	if mounted:
		return

	if Input.is_action_just_pressed("strike") and not is_striking():
		strike_time = 0.0
		strike_hits.clear()
	if Input.is_action_just_pressed("shield") and game.has_shield() and shield_cd <= 0.0:
		shield_time = SHIELD_TIME
		shield_cd = SHIELD_COOLDOWN


func _update_strike(delta: float) -> void:
	strike_time += delta
	if strike_time >= STRIKE_WINDUP and strike_time < STRIKE_WINDUP + STRIKE_ACTIVE:
		var reach := strike_rect()
		for g in game.goblins:
			if not is_instance_valid(g) or g.is_dead() or strike_hits.has(g):
				continue
			if reach.intersects(g.body_rect()):
				strike_hits.append(g)
				g.take_damage(STRIKE_DAMAGE, facing)
	if strike_time >= STRIKE_WINDUP + STRIKE_ACTIVE + STRIKE_RECOVERY:
		strike_time = -1.0


func strike_rect() -> Rect2:
	var x0 := position.x if facing > 0 else position.x - STRIKE_REACH - WIDTH / 2.0
	return Rect2(x0, position.y - HEIGHT - 10.0, STRIKE_REACH + WIDTH / 2.0, HEIGHT + 10.0)


func _cast_fireball() -> void:
	fireball_cd = FIREBALL_COOLDOWN
	cast_time = 0.0
	var fb = Node2D.new()
	fb.set_script(FireballScript)
	fb.game = game
	fb.direction = facing
	fb.damage = FIREBALL_DAMAGE
	fb.position = position + Vector2(facing * 46.0, -54.0 + rig.root_offset.y)
	game.add_projectile(fb)


## Called by enemies. Reports MISSED, HURT or BLOCKED.
func take_hit(from_x: float) -> int:
	if dead:
		return MISSED
	if is_shielding():
		block_flash = 0.35
		return BLOCKED
	if invuln > 0.0:
		return MISSED
	health -= 1
	invuln = HURT_INVULN
	knock = 420.0 if position.x >= from_x else -420.0
	velocity.y = -320.0
	strike_time = -1.0
	if health <= 0:
		health = 0
		dead = true
		game.on_player_defeated()
	return HURT


func _ease_out(k: float) -> float:
	return 1.0 - (1.0 - k) * (1.0 - k)


func _animate() -> void:
	var t := anim_time
	var sway := sin(t * 2.4)
	var pose := {
		"cloak_back": 2.0 + sway * 2.0, "ponytail": sway * 3.0,
		"torso": sway * 0.6, "arm_upper": sway * 1.5, "head": -sway * 0.6,
	}
	var offset := Vector2.ZERO
	rig.root_angle = 0.0
	if rig.scale.x != facing:
		rig.scale.x = facing
		rig.reset_physics_interpolation()  # turn around in one frame, not as a squash
	rig.visible = not (invuln > 0.0 and not dead and int(t * 16.0) % 2 == 0)

	if dead:
		# Lying down for a rest.
		rig.root_angle = -PI / 2.0
		offset = Vector2(-10.0, -rig.rest_pos("torso").y - 12.0)
	elif mounted:
		var pace := clampf(absf(velocity.x) / RIDE_SPEED, 0.0, 1.0)
		pose["leg_near_upper"] = -55.0
		pose["leg_near_lower"] = 60.0
		pose["leg_far_upper"] = -55.0
		pose["leg_far_lower"] = 60.0
		pose["arm_upper"] = -14.0
		pose["arm_lower"] = 8.0
		pose["torso"] = 3.0 + pace * 5.0
		pose["cloak_back"] = 4.0 + pace * 24.0 + sway * 3.0
		pose["ponytail"] = pace * 20.0 + sway * 3.0
		offset = game.horse.seat() - rig.rest_pos("torso")
	elif not is_on_floor():
		var falling := velocity.y > 0.0
		pose["leg_near_upper"] = -20.0 if falling else -40.0
		pose["leg_near_lower"] = 22.0 if falling else 54.0
		pose["leg_far_upper"] = 12.0 if falling else 20.0
		pose["leg_far_lower"] = 14.0 if falling else 24.0
		pose["arm_upper"] = -34.0 if falling else -22.0
		pose["cloak_back"] = 36.0 if falling else 16.0
		pose["ponytail"] = 28.0 if falling else 10.0
	elif absf(velocity.x) > 20.0:
		# Steps are tied to distance covered, so her feet do not slide.
		var ph := walk_phase
		pose["leg_near_upper"] = sin(ph) * 28.0
		pose["leg_near_lower"] = maxf(0.0, -cos(ph)) * 50.0
		pose["leg_far_upper"] = sin(ph + PI) * 28.0
		pose["leg_far_lower"] = maxf(0.0, -cos(ph + PI)) * 50.0
		pose["arm_upper"] = -sin(ph) * 10.0
		pose["arm_lower"] = -6.0
		pose["torso"] = 4.0
		pose["head"] = -2.0
		pose["cloak_back"] = 14.0 + sin(ph * 2.0) * 3.0
		pose["ponytail"] = 12.0 + sin(ph * 2.0 + 1.0) * 4.0
		offset.y = -absf(sin(ph)) * 2.5

	# Wand actions. Each has a wind-up, the action itself, and an easy return.
	if not dead:
		if is_striking() and not mounted:
			var s := strike_time
			if s < STRIKE_WINDUP:
				var k := s / STRIKE_WINDUP
				pose["arm_upper"] = lerpf(0.0, -125.0, k)
				pose["arm_lower"] = lerpf(0.0, -45.0, k)
				pose["torso"] = -7.0 * k
			elif s < STRIKE_WINDUP + STRIKE_ACTIVE:
				var k := _ease_out((s - STRIKE_WINDUP) / STRIKE_ACTIVE)
				pose["arm_upper"] = lerpf(-125.0, 42.0, k)
				pose["arm_lower"] = lerpf(-45.0, 42.0, k)
				pose["torso"] = lerpf(-7.0, 9.0, k)
				offset.x += 6.0 * k
			else:
				var k := _ease_out((s - STRIKE_WINDUP - STRIKE_ACTIVE) / STRIKE_RECOVERY)
				pose["arm_upper"] = lerpf(42.0, 0.0, k)
				pose["arm_lower"] = lerpf(42.0, 0.0, k)
				pose["torso"] = lerpf(9.0, 0.0, k)
				offset.x += 6.0 * (1.0 - k)
			pose["cloak_back"] = 22.0
		elif cast_time < CAST_POSE_TIME:
			# Thrust the wand forward, then ease back.
			var k := _ease_out(cast_time / CAST_POSE_TIME)
			pose["arm_upper"] = lerpf(-38.0, float(pose.get("arm_upper", 0.0)), k)
			pose["arm_lower"] = lerpf(88.0, float(pose.get("arm_lower", 0.0)), k)
			if not mounted:
				pose["torso"] = lerpf(8.0, float(pose.get("torso", 0.0)), k)
				offset.x += 4.0 * (1.0 - k)
			pose["cloak_back"] = float(pose.get("cloak_back", 0.0)) + 14.0 * (1.0 - k)
		elif is_shielding():
			pose["arm_upper"] = -95.0
			pose["arm_lower"] = -20.0
		if invuln > HURT_INVULN - 0.3 and not mounted:
			pose["torso"] = -12.0
			pose["head"] = 10.0
	rig.root_offset = offset
	rig.pose = pose
	rig.apply()


func _draw() -> void:
	# Effects only. Adeline herself is the rig.
	var f := float(facing)
	if is_striking() and not dead and strike_time >= STRIKE_WINDUP:
		# A crescent of magic sweeps out from the wand to the full reach of the strike.
		var k := clampf((strike_time - STRIKE_WINDUP) / (STRIKE_ACTIVE + STRIKE_RECOVERY), 0.0, 1.0)
		var radius := lerpf(26.0, STRIKE_REACH + 4.0, _ease_out(k))
		var alpha := 1.0 - k
		var centre := Vector2(f * 6.0, -60.0)
		var from := -1.15 if f > 0.0 else PI - 0.75
		var to := 0.75 if f > 0.0 else PI + 1.15
		draw_arc(centre, radius, from, to, 16, Color(0.75, 0.55, 1.0, 0.55 * alpha), 14.0 * (1.0 - k * 0.5))
		draw_arc(centre, radius + 2.0, from + 0.15, to - 0.15, 16, Color(1.0, 0.97, 0.8, alpha), 5.0)
	var middle := Vector2(0.0, -HEIGHT / 2.0 - 6.0)
	if is_shielding():
		draw_circle(middle, 66.0, Color(0.45, 0.75, 1.0, 0.28))
		draw_arc(middle, 66.0, 0.0, TAU, 40, Color(0.7, 0.9, 1.0, 0.9), 5.0)
	if block_flash > 0.0:
		var grow := 66.0 + (0.35 - block_flash) * 120.0
		draw_arc(middle, grow, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, block_flash / 0.35), 8.0)
