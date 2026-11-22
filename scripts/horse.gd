extends Node2D
## Spirit, Adeline's horse: dark brown with a black mane and tail.
## Spirit waits in the stable, comes when called, carries Adeline at a gallop,
## and stays back from goblin fights. Placeholder shapes for now.

const GALLOP := 620.0
const BACK_HEIGHT := 78.0  # how high Spirit's back is above the ground
const NAME := "Spirit"

var game = null
var font: Font
var state := "idle"  # idle, coming, retreat or mounted
var facing := 1
var target_x := 0.0
var speed := 0.0  # ground speed, drives the leg animation
var stride := 0.0
var clock := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font


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


func _draw() -> void:
	var f := float(facing)
	var coat := Color(0.34, 0.2, 0.11)
	var coat_far := Color(0.26, 0.15, 0.08)
	var black := Color(0.07, 0.06, 0.06)
	var pace := clampf(speed / 560.0, 0.0, 1.0)
	var bob := sin(stride * 2.0) * 4.0 * pace
	var top := -BACK_HEIGHT + bob

	# Tail.
	var sway := sin(clock * 3.0) * 4.0 + pace * 16.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-f * 58.0, top + 6.0),
		Vector2(-f * (86.0 + sway), top + 34.0),
		Vector2(-f * (72.0 + sway * 0.5), top + 58.0),
		Vector2(-f * 56.0, top + 22.0),
	]), black)

	# Legs: the far pair first, then the near pair.
	for i in 4:
		var hind := i % 2 == 0
		var far := i < 2
		var base_x := (-42.0 if hind else 42.0) * f + (7.0 if far else -5.0) * f
		var phase := stride + (0.0 if hind else PI) + (PI * 0.5 if far else 0.0)
		var swing := sin(phase) * 24.0 * pace
		var lift := maxf(cos(phase), 0.0) * 16.0 * pace
		var hip := Vector2(base_x, top + 34.0)
		var hoof := Vector2(base_x + swing * f, -lift)
		draw_line(hip, hoof, coat_far if far else coat, 10.0)
		draw_rect(Rect2(hoof.x - 6.0, hoof.y - 8.0, 12.0, 8.0), black)

	# Body.
	draw_rect(Rect2(-54.0, top, 108.0, 40.0), coat)
	draw_circle(Vector2(-f * 50.0, top + 20.0), 21.0, coat)
	draw_circle(Vector2(f * 50.0, top + 20.0), 21.0, coat)
	# Neck and head.
	draw_colored_polygon(PackedVector2Array([
		Vector2(f * 34.0, top + 2.0), Vector2(f * 66.0, top + 26.0),
		Vector2(f * 92.0, top - 40.0), Vector2(f * 68.0, top - 56.0),
	]), coat)
	draw_colored_polygon(PackedVector2Array([
		Vector2(f * 68.0, top - 58.0), Vector2(f * 90.0, top - 54.0), Vector2(f * 118.0, top - 26.0),
		Vector2(f * 110.0, top - 14.0), Vector2(f * 84.0, top - 26.0),
	]), coat)
	draw_colored_polygon(PackedVector2Array([Vector2(f * 70.0, top - 56.0), Vector2(f * 74.0, top - 76.0), Vector2(f * 82.0, top - 56.0)]), coat)
	draw_circle(Vector2(f * 112.0, top - 20.0), 3.0, black)
	draw_circle(Vector2(f * 92.0, top - 42.0), 3.0, black)
	# Mane and forelock.
	draw_colored_polygon(PackedVector2Array([
		Vector2(f * 30.0, top + 2.0), Vector2(f * 62.0, top - 58.0),
		Vector2(f * 72.0, top - 54.0), Vector2(f * 50.0, top - 8.0), Vector2(f * 44.0, top + 8.0),
	]), black)
	draw_colored_polygon(PackedVector2Array([Vector2(f * 72.0, top - 58.0), Vector2(f * 90.0, top - 50.0), Vector2(f * 80.0, top - 44.0)]), black)

	if state == "mounted":
		# Adeline's near leg and boot over Spirit's side.
		draw_rect(Rect2(-8.0 + f * 4.0, top + 2.0, 16.0, 34.0), Color(0.25, 0.33, 0.55))
		draw_rect(Rect2(-10.0 + f * 7.0, top + 34.0, 22.0, 10.0), Color(0.45, 0.28, 0.15))
	elif game.mode == "play" and absf(game.player.position.x - position.x) < 240.0:
		draw_string_outline(font, Vector2(-60.0, top - 92.0), NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, 5, Color(0.0, 0.0, 0.0, 0.5))
		draw_string(font, Vector2(-60.0, top - 92.0), NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, Color.WHITE)
