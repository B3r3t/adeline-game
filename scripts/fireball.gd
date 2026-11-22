extends Node2D
## Adeline's fireball. Flies straight, hits the first goblin it touches.

const SPEED := 640.0
const RADIUS := 14.0
const MAX_DISTANCE := 720.0

var game = null
var direction := 1
var damage := 1
var travelled := 0.0
var age := 0.0


func _physics_process(delta: float) -> void:
	age += delta
	var step := SPEED * delta
	position.x += step * direction
	travelled += step
	for g in game.goblins:
		if not is_instance_valid(g) or g.is_dead():
			continue
		var r: Rect2 = g.body_rect().grow(RADIUS)
		if r.has_point(position):
			g.take_damage(damage, direction)
			queue_free()
			return
	if travelled >= MAX_DISTANCE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var wobble := sin(age * 30.0) * 2.0
	for i in 4:
		var t := float(i) / 4.0
		draw_circle(Vector2(-direction * (10.0 + 14.0 * i), wobble * t), RADIUS * (0.8 - 0.18 * i), Color(1.0, 0.55, 0.1, 0.5 - 0.11 * i))
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.45, 0.1))
	draw_circle(Vector2.ZERO, RADIUS * 0.6, Color(1.0, 0.85, 0.3))
