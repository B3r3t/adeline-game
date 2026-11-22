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
const STRIKE_WINDUP := 0.04
const STRIKE_ACTIVE := 0.1
const STRIKE_RECOVERY := 0.1
const STRIKE_REACH := 80.0
const STRIKE_DAMAGE := 1

# Fireball: three times the wand's damage, with a wait between casts.
const FIREBALL_COOLDOWN := 2.0
const FIREBALL_DAMAGE := 3

# Magic shield, earned from Mission 1.
const SHIELD_TIME := 0.6
const SHIELD_COOLDOWN := 2.2

const HURT_INVULN := 0.9

# Riding Spirit: faster, with a longer jump. No attacks from the saddle.
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
	if mounted:
		return

	if Input.is_action_just_pressed("strike") and not is_striking():
		strike_time = 0.0
		strike_hits.clear()
	if Input.is_action_just_pressed("fireball") and fireball_cd <= 0.0:
		_cast_fireball()
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
	fb.position = position + Vector2(facing * 44.0, -58.0)
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


func _animate() -> void:
	var t := anim_time
	var sway := sin(t * 2.4)
	var pose := { "cloak_back": 2.0 + sway * 2.0, "ponytail": sway * 3.0 }
	rig.root_offset = Vector2.ZERO
	rig.root_angle = 0.0
	rig.scale.x = facing
	rig.visible = not (invuln > 0.0 and not dead and int(t * 16.0) % 2 == 0)

	if dead:
		# Lying down for a rest.
		rig.root_angle = -PI / 2.0
		rig.root_offset = Vector2(-10.0, -rig.rest_pos("torso").y - 12.0)
	elif mounted:
		var pace := clampf(absf(velocity.x) / RIDE_SPEED, 0.0, 1.0)
		pose["leg_near"] = -62.0
		pose["leg_far"] = -62.0
		pose["arm"] = -8.0
		pose["cloak_back"] = 4.0 + pace * 22.0 + sway * 3.0
		pose["ponytail"] = pace * 18.0 + sway * 3.0
		rig.root_offset = game.horse.seat() - rig.rest_pos("torso")
	elif not is_on_floor():
		var falling := velocity.y > 0.0
		pose["leg_near"] = -30.0
		pose["leg_far"] = 24.0
		pose["cloak_back"] = 34.0 if falling else 16.0
		pose["ponytail"] = 26.0 if falling else 10.0
		pose["arm"] = -20.0
	elif absf(velocity.x) > 20.0:
		var step := sin(t * 12.0)
		pose["leg_near"] = step * 28.0
		pose["leg_far"] = -step * 28.0
		pose["arm"] = -step * 6.0
		pose["cloak_back"] = 12.0 + step * 3.0
		pose["ponytail"] = 10.0 + step * 3.0
		rig.root_offset.y = -absf(cos(t * 12.0)) * 2.0

	# Actions take over the wand arm. The cloak sweeps back so the swing reads clearly.
	if not dead and not mounted:
		if is_striking():
			var k := clampf(strike_time / (STRIKE_WINDUP + STRIKE_ACTIVE), 0.0, 1.0)
			pose["arm"] = lerpf(-105.0, 45.0, k)
			pose["torso"] = lerpf(-4.0, 8.0, k)
			pose["cloak_back"] = 20.0
		elif cast_time < 0.25:
			pose["arm"] = 32.0
			pose["torso"] = 5.0
			pose["cloak_back"] = 18.0
		elif is_shielding():
			pose["arm"] = -70.0
		if invuln > HURT_INVULN - 0.3:
			pose["torso"] = -12.0
			pose["head"] = 10.0
	rig.pose = pose
	rig.apply()


func _draw() -> void:
	# Effects only. Adeline herself is the rig.
	if is_striking() and not dead:
		var total := STRIKE_WINDUP + STRIKE_ACTIVE
		if strike_time >= STRIKE_WINDUP and strike_time < total:
			var f := float(facing)
			var hand := Vector2(f * 18.0, -58.0)
			draw_arc(hand, STRIKE_REACH - 20.0, -1.3 if f > 0.0 else PI - 0.7, 0.7 if f > 0.0 else PI + 1.3, 12, Color(1.0, 1.0, 1.0, 0.8), 8.0)
	var centre := Vector2(0.0, -HEIGHT / 2.0 - 6.0)
	if is_shielding():
		draw_circle(centre, 66.0, Color(0.45, 0.75, 1.0, 0.28))
		draw_arc(centre, 66.0, 0.0, TAU, 40, Color(0.7, 0.9, 1.0, 0.9), 5.0)
	if block_flash > 0.0:
		var grow := 66.0 + (0.35 - block_flash) * 120.0
		draw_arc(centre, grow, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, block_flash / 0.35), 8.0)
