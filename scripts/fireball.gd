extends Node2D
## Adeline's fireball: a glowing core with a flame tail and a trail of embers.
## It flies straight, bursts on the first goblin it touches, and fizzles at the end of its range.

const SPEED := 660.0
const RADIUS := 16.0
const MAX_DISTANCE := 720.0

var game = null
var direction := 1
var damage := 3
var travelled := 0.0
var age := 0.0
var trail: CPUParticles2D


func _ready() -> void:
	var glow := Sprite2D.new()
	glow.texture = game.spark
	glow.material = game.additive
	glow.modulate = Color(1.0, 0.55, 0.15, 0.9)
	glow.scale = Vector2(2.6, 2.6)
	add_child(glow)

	trail = CPUParticles2D.new()
	trail.texture = game.spark
	trail.material = game.additive
	trail.amount = 26
	trail.lifetime = 0.42
	trail.local_coords = false
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 7.0
	trail.direction = Vector2(-direction, 0.0)
	trail.spread = 28.0
	trail.initial_velocity_min = 40.0
	trail.initial_velocity_max = 110.0
	trail.gravity = Vector2(0.0, -70.0)
	trail.scale_amount_min = 0.45
	trail.scale_amount_max = 0.8
	trail.scale_amount_curve = game.shrink
	trail.color_ramp = game.fire_ramp
	add_child(trail)
	_flash(position, 1.6)


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
			_burst(26, 1.0)
			queue_free()
			return
	if travelled >= MAX_DISTANCE:
		_burst(10, 0.5)
		queue_free()
	queue_redraw()


func _draw() -> void:
	# A flickering flame: a tail of shrinking blobs streaming behind a bright core.
	var d := float(direction)
	var flick := sin(age * 38.0)
	for i in range(6, 0, -1):
		var back := -d * (4.0 + i * 8.5)
		var wave := sin(age * 30.0 + i * 1.3) * (1.0 + i * 0.9)
		var size := RADIUS * (1.0 - i * 0.13)
		draw_circle(Vector2(back, wave), size, Color(1.0, 0.42 - i * 0.04, 0.08, 0.9 - i * 0.1))
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.5, 0.1))
	draw_circle(Vector2(d * 2.0, 0.0), RADIUS * 0.72 + flick, Color(1.0, 0.8, 0.25))
	draw_circle(Vector2(d * 4.0, 0.0), RADIUS * 0.4, Color(1.0, 0.97, 0.8))


## A quick bright pop, used when the fireball is cast and when it lands.
func _flash(at: Vector2, size: float) -> void:
	var pop := Sprite2D.new()
	pop.texture = game.spark
	pop.material = game.additive
	pop.modulate = Color(1.0, 0.8, 0.4, 1.0)
	pop.position = at
	pop.scale = Vector2(size, size)
	game.projectiles.add_child(pop)
	var tween := pop.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pop, "scale", Vector2(size * 2.4, size * 2.4), 0.18)
	tween.tween_property(pop, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(pop.queue_free)


func _burst(sparks: int, power: float) -> void:
	_flash(position, 2.2 * power + 0.8)
	var boom := CPUParticles2D.new()
	boom.texture = game.spark
	boom.material = game.additive
	boom.position = position
	boom.one_shot = true
	boom.explosiveness = 1.0
	boom.amount = sparks
	boom.lifetime = 0.5
	boom.spread = 180.0
	boom.initial_velocity_min = 90.0 * power
	boom.initial_velocity_max = 280.0 * power
	boom.gravity = Vector2(0.0, 260.0)
	boom.scale_amount_min = 0.35
	boom.scale_amount_max = 0.75
	boom.scale_amount_curve = game.shrink
	boom.color_ramp = game.fire_ramp
	boom.emitting = true
	game.projectiles.add_child(boom)
	game.get_tree().create_timer(0.8).timeout.connect(boom.queue_free)
