extends CharacterBody2D
## Placeholder goblin with two attacks. Every attack runs the same three steps
## every time: warning, attack, recovery. Direction locks when the warning ends.

enum State { APPROACH, SWING_WINDUP, SWING_ACTIVE, CHARGE_WINDUP, CHARGE_ACTIVE, RECOVERY, DEAD }

const WIDTH := 40.0
const HEIGHT := 56.0
const MAX_HEALTH := 6
const WALK_SPEED := 140.0
const GRAVITY := 1900.0

# Close swing.
const SWING_RANGE := 86.0  # starts a swing when Adeline is this close
const SWING_REACH := 84.0  # how far in front the swing hits
const SWING_WINDUP := 0.9
const SWING_ACTIVE := 0.16
const SWING_RECOVERY := 1.0

# Short charge.
const CHARGE_MIN_RANGE := 170.0
const CHARGE_MAX_RANGE := 330.0  # shorter than the distance a charge covers
const CHARGE_WINDUP := 0.9
const CHARGE_SPEED := 540.0
const CHARGE_TIME := 0.6
const CHARGE_RECOVERY := 1.1

const THINK_TIME := 0.35  # short pause before choosing the next attack

var game = null
var state: int = State.APPROACH
var state_time := 0.0
var recovery_length := 1.0
var facing := -1
var health := MAX_HEALTH
var hit_done := false
var think := 0.6
var flash := 0.0
var knock := 0.0
var fade := 1.0
var anim_time := 0.0
var hold_slot := 0  # where to wait when another goblin is attacking


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH, HEIGHT)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0.0, -HEIGHT / 2.0)
	add_child(col)


func body_rect() -> Rect2:
	return Rect2(position.x - WIDTH / 2.0, position.y - HEIGHT, WIDTH, HEIGHT)


func is_dead() -> bool:
	return state == State.DEAD


func is_attacking() -> bool:
	return state != State.APPROACH and state != State.DEAD


func _set_state(new_state: int) -> void:
	state = new_state
	state_time = 0.0


func _physics_process(delta: float) -> void:
	anim_time += delta
	state_time += delta
	flash = maxf(flash - delta, 0.0)
	knock = move_toward(knock, 0.0, 900.0 * delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var dx: float = game.player.position.x - position.x
	var dist := absf(dx)
	var toward := 1 if dx >= 0.0 else -1
	velocity.x = 0.0

	match state:
		State.APPROACH:
			facing = toward
			think = maxf(think - delta, 0.0)
			_approach(dist, toward)
		State.SWING_WINDUP:
			facing = toward  # keeps turning until the warning ends, then locks
			if state_time >= SWING_WINDUP:
				hit_done = false
				_set_state(State.SWING_ACTIVE)
		State.SWING_ACTIVE:
			if not hit_done and swing_rect().intersects(game.player.body_rect()):
				hit_done = game.player.take_hit(position.x)
			if state_time >= SWING_ACTIVE:
				recovery_length = SWING_RECOVERY
				_set_state(State.RECOVERY)
		State.CHARGE_WINDUP:
			facing = toward
			if state_time >= CHARGE_WINDUP:
				hit_done = false
				_set_state(State.CHARGE_ACTIVE)
		State.CHARGE_ACTIVE:
			velocity.x = facing * CHARGE_SPEED  # direction is locked, no tracking
			if not hit_done and body_rect().intersects(game.player.body_rect()):
				hit_done = game.player.take_hit(position.x - facing * 10.0)
			if state_time >= CHARGE_TIME or (is_on_wall() and state_time > 0.05):
				recovery_length = CHARGE_RECOVERY
				_set_state(State.RECOVERY)
		State.RECOVERY:
			if state_time >= recovery_length:
				game.release_attack(self)
				think = THINK_TIME
				_set_state(State.APPROACH)
		State.DEAD:
			fade = maxf(fade - delta * 2.0, 0.0)
			if fade <= 0.0:
				queue_free()

	velocity.x += knock
	move_and_slide()
	queue_redraw()


func _approach(dist: float, toward: int) -> void:
	if game.player.dead:
		return
	var may_attack: bool = think <= 0.0 and game.can_attack(self)
	if may_attack and dist <= SWING_RANGE:
		if game.request_attack(self):
			_set_state(State.SWING_WINDUP)
			return
	if may_attack and dist >= CHARGE_MIN_RANGE and dist <= CHARGE_MAX_RANGE:
		if game.request_attack(self):
			_set_state(State.CHARGE_WINDUP)
			return
	if game.can_attack(self):
		# Free to attack: close the gap.
		if dist > SWING_RANGE * 0.8:
			velocity.x = toward * WALK_SPEED
	else:
		# Another goblin is attacking: wait at a distance and leave room to escape.
		var want := 300.0 + 110.0 * hold_slot
		if dist > want + 30.0:
			velocity.x = toward * WALK_SPEED
		elif dist < want - 30.0:
			velocity.x = -toward * WALK_SPEED * 0.8


func swing_rect() -> Rect2:
	var x0 := position.x if facing > 0 else position.x - SWING_REACH
	return Rect2(x0, position.y - HEIGHT - 24.0, SWING_REACH, HEIGHT + 24.0)


func take_damage(amount: int, from_dir: int) -> void:
	if state == State.DEAD:
		return
	health -= amount
	flash = 0.15
	if state == State.APPROACH or state == State.RECOVERY:
		knock = from_dir * 180.0
	if health <= 0:
		health = 0
		_set_state(State.DEAD)
		game.release_attack(self)
		game.on_goblin_defeated(self)


func _draw() -> void:
	var f := float(facing)
	var body := Color(0.35, 0.65, 0.25)
	var dark := Color(0.22, 0.45, 0.16)
	var h := HEIGHT
	var w := WIDTH
	var lean := 0.0
	var warn := Color(0, 0, 0, 0)
	var pulse := 0.5 + 0.5 * sin(anim_time * 22.0)

	match state:
		State.SWING_WINDUP:
			warn = Color(1.0, 0.25, 0.2)
			body = body.lerp(Color(1.0, 0.85, 0.3), 0.35 + 0.35 * pulse)
		State.CHARGE_WINDUP:
			h = HEIGHT * 0.68  # crouch
			w = WIDTH * 1.2
			warn = Color(1.0, 0.6, 0.1)
			body = body.lerp(Color(1.0, 0.6, 0.2), 0.35 + 0.35 * pulse)
		State.CHARGE_ACTIVE:
			lean = 0.35
		State.RECOVERY:
			body = body.lerp(Color(0.6, 0.6, 0.6), 0.5)
	if flash > 0.0:
		body = Color.WHITE
	body.a = fade
	dark.a = fade

	# Ground warnings: where the attack will land.
	if state == State.SWING_WINDUP:
		var zone := Rect2(0.0 if f > 0.0 else -SWING_REACH, -6.0, SWING_REACH, 8.0)
		draw_rect(zone, Color(1.0, 0.2, 0.2, 0.35 + 0.35 * pulse))
	elif state == State.CHARGE_WINDUP:
		var tip_x := f * (70.0 + 90.0 * clampf(state_time / CHARGE_WINDUP, 0.0, 1.0))
		draw_line(Vector2(f * 26.0, -4.0), Vector2(tip_x, -4.0), Color(1.0, 0.55, 0.1, 0.9), 8.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tip_x + f * 22.0, -4.0),
			Vector2(tip_x, -18.0),
			Vector2(tip_x, 10.0),
		]), Color(1.0, 0.55, 0.1, 0.9))

	draw_set_transform(Vector2.ZERO, lean * f, Vector2.ONE)
	# Ears.
	draw_colored_polygon(PackedVector2Array([Vector2(-w / 2.0, -h + 14.0), Vector2(-w / 2.0 - 16.0, -h + 2.0), Vector2(-w / 2.0, -h + 26.0)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(w / 2.0, -h + 14.0), Vector2(w / 2.0 + 16.0, -h + 2.0), Vector2(w / 2.0, -h + 26.0)]), dark)
	# Body.
	draw_rect(Rect2(-w / 2.0, -h, w, h), body)
	# Eyes, looking where it faces.
	var eye := Color(1.0, 0.95, 0.4, fade)
	draw_circle(Vector2(f * 4.0, -h + 16.0), 4.0, eye)
	draw_circle(Vector2(f * 14.0, -h + 16.0), 4.0, eye)

	# Club.
	var hand := Vector2(f * (w / 2.0), -h * 0.5)
	var club_angle := -0.5
	if state == State.SWING_WINDUP:
		club_angle = -1.9 + sin(anim_time * 40.0) * 0.08  # raised and shaking
	elif state == State.SWING_ACTIVE:
		club_angle = lerpf(-1.9, 0.6, clampf(state_time / SWING_ACTIVE, 0.0, 1.0))
	elif state == State.RECOVERY:
		club_angle = 0.9
	var club_tip := hand + Vector2(cos(club_angle) * f, sin(club_angle)) * 44.0
	draw_line(hand, club_tip, Color(0.45, 0.3, 0.15, fade), 7.0)
	draw_circle(club_tip, 9.0, Color(0.38, 0.25, 0.12, fade))
	if state == State.SWING_ACTIVE:
		draw_arc(hand, 56.0, -1.9 if f > 0.0 else PI - 0.6, 0.6 if f > 0.0 else PI + 1.9, 12, Color(1.0, 0.3, 0.2, 0.8), 9.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Warning mark above the head, readable with sound off.
	if warn.a > 0.0:
		var mark_y := -h - 46.0
		draw_rect(Rect2(-5.0, mark_y, 10.0, 24.0), warn)
		draw_circle(Vector2(0.0, mark_y + 34.0), 6.0, warn)
	# Dizzy stars while recovering: this is the moment to hit back.
	if state == State.RECOVERY:
		for i in 3:
			var a := anim_time * 5.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 20.0, -h - 18.0 + sin(a) * 6.0), 4.0, Color(1.0, 0.95, 0.5))
	# Health pips.
	if state != State.DEAD:
		for i in MAX_HEALTH:
			var c := Color(0.9, 0.2, 0.25) if i < health else Color(0.0, 0.0, 0.0, 0.3)
			draw_rect(Rect2(-MAX_HEALTH * 6.0 + i * 12.0, -HEIGHT - 76.0, 10.0, 6.0), c)
