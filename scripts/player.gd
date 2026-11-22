extends CharacterBody2D
## Placeholder Adeline, built from simple shapes. Her origin is at her feet.
## Timing and reach numbers are at the top so they are easy to tune after playtests.

const FireballScript := preload("res://scripts/fireball.gd")

const SPEED := 300.0
const ACCEL := 2600.0
const GRAVITY := 1900.0
const JUMP_VELOCITY := -760.0
const WIDTH := 44.0
const HEIGHT := 88.0
const MAX_HEALTH := 5

# Wand strike: short windup, a brief window where it can hit, then recovery.
const STRIKE_WINDUP := 0.06
const STRIKE_ACTIVE := 0.14
const STRIKE_RECOVERY := 0.2
const STRIKE_REACH := 80.0
const STRIKE_DAMAGE := 2

const FIREBALL_COOLDOWN := 1.1
const FIREBALL_DAMAGE := 1
const HURT_INVULN := 0.9

var game = null
var facing := 1
var health := MAX_HEALTH
var dead := false
var strike_time := -1.0  # below zero means not striking
var strike_hits: Array = []
var fireball_cd := 0.0
var invuln := 0.0
var knock := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var anim_time := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH, HEIGHT)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0.0, -HEIGHT / 2.0)
	add_child(col)


func reset(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	facing = 1
	health = MAX_HEALTH
	dead = false
	strike_time = -1.0
	strike_hits.clear()
	fireball_cd = 0.0
	invuln = 0.0
	knock = 0.0


func body_rect() -> Rect2:
	return Rect2(position.x - WIDTH / 2.0, position.y - HEIGHT, WIDTH, HEIGHT)


func is_striking() -> bool:
	return strike_time >= 0.0


func _physics_process(delta: float) -> void:
	anim_time += delta
	fireball_cd = maxf(fireball_cd - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	knock = move_toward(knock, 0.0, 1400.0 * delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
		coyote = maxf(coyote - delta, 0.0)
	else:
		coyote = 0.1

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		move_and_slide()
		queue_redraw()
		return

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0 and not is_striking():
		facing = 1 if dir > 0.0 else -1
	var speed := SPEED * (0.45 if is_striking() else 1.0)
	velocity.x = move_toward(velocity.x, dir * speed, ACCEL * delta)

	# Jump, with a little forgiveness on both sides of the button press.
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.12
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
	if Input.is_action_just_released("jump") and velocity.y < -260.0:
		velocity.y = -260.0  # letting go early makes a shorter hop

	if Input.is_action_just_pressed("strike") and not is_striking():
		strike_time = 0.0
		strike_hits.clear()
	if Input.is_action_just_pressed("fireball") and fireball_cd <= 0.0 and not is_striking():
		_cast_fireball()

	if is_striking():
		_update_strike(delta)

	var walk := velocity.x
	velocity.x += knock
	move_and_slide()
	velocity.x = walk
	queue_redraw()


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
	var fb = Node2D.new()
	fb.set_script(FireballScript)
	fb.game = game
	fb.direction = facing
	fb.damage = FIREBALL_DAMAGE
	fb.position = position + Vector2(facing * 34.0, -54.0)
	game.add_projectile(fb)


## Called by enemies. Returns true if the hit landed.
func take_hit(from_x: float) -> bool:
	if dead or invuln > 0.0:
		return false
	health -= 1
	invuln = HURT_INVULN
	knock = 420.0 if position.x >= from_x else -420.0
	velocity.y = -320.0
	strike_time = -1.0
	if health <= 0:
		health = 0
		dead = true
		game.on_player_defeated()
	return true


func _draw() -> void:
	if invuln > 0.0 and not dead and int(anim_time * 16.0) % 2 == 0:
		return  # blink while briefly protected after a hit
	var f := float(facing)
	var skin := Color(0.98, 0.84, 0.72)
	var hair := Color(0.62, 0.25, 0.12)
	var top := Color(0.2, 0.45, 0.9)
	var jeans := Color(0.25, 0.33, 0.55)
	var boots := Color(0.45, 0.28, 0.15)
	var cape := Color(0.75, 0.2, 0.3)

	if dead:
		draw_set_transform(Vector2(0.0, -12.0), -f * PI / 2.0, Vector2.ONE)

	var moving := absf(velocity.x) > 20.0 and is_on_floor()
	var bob := sin(anim_time * 14.0) * 2.0 if moving else 0.0
	var sway := sin(anim_time * (10.0 if moving else 3.0)) * 5.0

	# Cape, behind everything else.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-f * 10.0, -70.0 + bob),
		Vector2(-f * (32.0 + sway), -26.0),
		Vector2(-f * 8.0, -30.0),
	]), cape)
	# Legs and boots.
	draw_rect(Rect2(-14.0, -42.0, 28.0, 34.0), jeans)
	draw_rect(Rect2(-16.0, -10.0, 32.0, 10.0), boots)
	# Top.
	draw_rect(Rect2(-16.0, -72.0 + bob, 32.0, 32.0), top)
	# Hair, then head.
	draw_circle(Vector2(-f * 4.0, -84.0 + bob), 15.0, hair)
	draw_circle(Vector2(f * 1.0, -82.0 + bob), 12.0, skin)
	draw_circle(Vector2(f * 6.0, -84.0 + bob), 2.0, Color(0.3, 0.2, 0.12))

	# Wand.
	var hand := Vector2(f * 16.0, -54.0 + bob)
	var angle := -0.9  # resting angle, pointing up and forward
	if is_striking():
		var total := STRIKE_WINDUP + STRIKE_ACTIVE
		var t := clampf(strike_time / total, 0.0, 1.0)
		angle = lerpf(-1.9, 0.7, t)
		if strike_time >= STRIKE_WINDUP and strike_time < total:
			# Show the reach of the swing so it is easy to learn.
			draw_arc(hand, STRIKE_REACH - 22.0, -1.3 if f > 0.0 else PI - 0.7, 0.7 if f > 0.0 else PI + 1.3, 12, Color(1.0, 1.0, 1.0, 0.75), 8.0)
	var tip := hand + Vector2(cos(angle) * f, sin(angle)) * 34.0
	draw_line(hand, tip, Color(0.4, 0.26, 0.13), 5.0)
	draw_circle(tip, 5.0 if not is_striking() else 8.0, Color(1.0, 0.9, 0.4))

	if dead:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
