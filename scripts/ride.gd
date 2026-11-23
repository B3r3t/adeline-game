extends Node2D
## The riding course. Spirit gallops on her own; the player jumps fences, hay bales and
## logs, and times jumps to pass through golden rings. Nothing here can be lost: a knocked
## obstacle just slows Spirit for a moment, and the course ends with one to three stars.

const START_X := 8000.0
const LENGTH := 14000.0
const BASE_SPEED := 470.0
const FAST_SPEED := 600.0
const SLOW_SPEED := 350.0
const RIDER_HEIGHT := 112.0  # how far above Spirit's hooves the middle of Adeline is
const RING_OPENING := 58.0  # how far off-centre she can be and still pass through a ring
const HORSE_HALF := 40.0  # half of Spirit's length, for touching obstacles
const ART_SCALE := 1.0 / 2.2

# What each obstacle needs: how high Spirit's hooves must be, and half its width.
const OBSTACLES := {
	"fence": { "clear": 50.0, "half": 20.0 },
	"bale": { "clear": 46.0, "half": 24.0 },
	"log": { "clear": 28.0, "half": 40.0 },
}

var game = null
var active := false
var finished := false
var course := 1
var items: Array = []
var rings_total := 0
var rings_got := 0
var jumps_clean := 0
var stumbles := 0
var stumble_time := 0.0
var finish_x := 0.0
var finish_time := 0.0
var run_time := 0.0
var stars := 0
var last_x := 0.0


func clear() -> void:
	active = false
	finished = false
	for child in get_children():
		child.queue_free()
	items.clear()


func start(number: int) -> void:
	clear()
	course = maxi(number, 1)
	rings_total = 0
	rings_got = 0
	jumps_clean = 0
	stumbles = 0
	stumble_time = 0.0
	finish_time = 0.0
	run_time = 0.0
	stars = 0
	last_x = START_X
	_build()
	active = true


## Spirit's speed right now. The arrows nudge it slower or faster.
func pace(axis: float) -> float:
	if finished:
		return 0.0
	var speed := BASE_SPEED
	if axis > 0.0:
		speed = lerpf(BASE_SPEED, FAST_SPEED, axis)
	elif axis < 0.0:
		speed = lerpf(BASE_SPEED, SLOW_SPEED, -axis)
	speed *= 1.0 + 0.05 * minf(course - 1, 6.0)
	if stumble_time > 0.0:
		speed *= 0.4
	return speed


# --- Building a course -------------------------------------------------------
# The same course number always gives the same course, so it can be practised.

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + course
	var kinds := ["fence", "ring_low", "bale", "ring_mid", "log", "fence_ring", "arc"]
	if course >= 2:
		kinds.append_array(["ring_high", "arc", "fence_ring"])
	var x := START_X + 950.0
	var previous := ""
	while x < START_X + LENGTH - 800.0:
		var kind: String = kinds[rng.randi() % kinds.size()]
		if kind == previous:
			kind = kinds[rng.randi() % kinds.size()]
		previous = kind
		match kind:
			"fence", "bale", "log":
				_add_obstacle(kind, x)
			"ring_low":
				_add_ring(x, -RIDER_HEIGHT - 4.0)
			"ring_mid":
				_add_ring(x, -RIDER_HEIGHT - 105.0)
			"ring_high":
				_add_ring(x, -RIDER_HEIGHT - 150.0)
			"fence_ring":
				_add_ring(x, -RIDER_HEIGHT - 120.0)
				_add_obstacle("fence", x)
			"arc":
				# Three rings along the path of one jump.
				_add_ring(x, -RIDER_HEIGHT - 90.0)
				_add_ring(x + 120.0, -RIDER_HEIGHT - 150.0)
				_add_ring(x + 240.0, -RIDER_HEIGHT - 90.0)
				x += 240.0
		x += rng.randf_range(560.0, 780.0) - 30.0 * minf(course - 1, 4.0)
	finish_x = START_X + LENGTH - 300.0
	var arch := _sprite("finish", finish_x, 0.0)
	arch.z_index = 0


func _sprite(art: String, x: float, bottom: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/props/%s.png" % art)
	sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	var size := sprite.texture.get_size() * ART_SCALE
	sprite.offset = Vector2(0.0, -sprite.texture.get_size().y / 2.0)  # stands on its bottom edge
	sprite.position = Vector2(x, game.GROUND_Y + 4.0 + bottom)
	add_child(sprite)
	return sprite


func _add_obstacle(kind: String, x: float) -> void:
	var sprite := _sprite(kind, x, 0.0)
	sprite.z_index = 2  # in front of Spirit
	items.append({ "kind": kind, "x": x, "node": sprite, "done": false })


func _add_ring(x: float, height: float) -> void:
	# The ring is drawn as two halves, one behind Spirit and one in front,
	# so she really passes through it.
	var tex: Texture2D = load("res://art/props/ring.png")
	var size := tex.get_size()
	var halves := []
	for i in 2:
		var half := Sprite2D.new()
		half.texture = tex
		half.region_enabled = true
		half.region_rect = Rect2(size.x / 2.0 * i, 0.0, size.x / 2.0, size.y)
		half.scale = Vector2(ART_SCALE, ART_SCALE)
		half.position = Vector2(x + (i - 0.5) * size.x / 2.0 * ART_SCALE, game.GROUND_Y + height)
		half.z_index = 0 if i == 0 else 2
		add_child(half)
		halves.append(half)
	rings_total += 1
	items.append({ "kind": "ring", "x": x, "y": game.GROUND_Y + height, "nodes": halves, "done": false })


# --- Riding ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not active:
		return
	var p = game.player
	stumble_time = maxf(stumble_time - delta, 0.0)
	if finished:
		finish_time += delta
		return
	run_time += delta
	var px: float = p.position.x
	var hooves: float = game.GROUND_Y - p.position.y  # how high Spirit is off the ground
	for item in items:
		if item["done"]:
			continue
		if item["kind"] == "ring":
			if last_x < item["x"] and px >= item["x"]:
				item["done"] = true
				var rider_y: float = p.position.y - RIDER_HEIGHT
				if absf(rider_y - float(item["y"])) <= RING_OPENING:
					_collect(item)
		else:
			var spec: Dictionary = OBSTACLES[item["kind"]]
			var reach: float = float(spec["half"]) + HORSE_HALF
			if absf(px - float(item["x"])) < reach:
				if hooves < float(spec["clear"]):
					item["done"] = true
					_stumble(item)
			elif px > float(item["x"]) + reach:
				item["done"] = true
				jumps_clean += 1
	last_x = px
	if px >= finish_x:
		_finish()


func _collect(item: Dictionary) -> void:
	rings_got += 1
	for half in item["nodes"]:
		var tween: Tween = half.create_tween()
		tween.set_parallel(true)
		tween.tween_property(half, "modulate", Color(2.0, 2.0, 1.4, 0.0), 0.3)
		tween.tween_property(half, "position:y", half.position.y - 30.0, 0.3)
	var sparkle := CPUParticles2D.new()
	sparkle.texture = game.spark
	sparkle.material = game.additive
	sparkle.position = Vector2(float(item["x"]), float(item["y"]))
	sparkle.one_shot = true
	sparkle.explosiveness = 1.0
	sparkle.amount = 22
	sparkle.lifetime = 0.55
	sparkle.spread = 180.0
	sparkle.initial_velocity_min = 80.0
	sparkle.initial_velocity_max = 240.0
	sparkle.gravity = Vector2(0.0, 220.0)
	sparkle.scale_amount_min = 0.3
	sparkle.scale_amount_max = 0.7
	sparkle.scale_amount_curve = game.shrink
	sparkle.color = Color(1.0, 0.85, 0.3)
	sparkle.z_index = 3
	sparkle.emitting = true
	add_child(sparkle)


func _stumble(item: Dictionary) -> void:
	stumbles += 1
	stumble_time = 0.55
	# The obstacle tips over, and Spirit flashes to show the bump.
	var node: Sprite2D = item["node"]
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "rotation", 1.3, 0.35)
	tween.tween_property(node, "modulate:a", 0.35, 0.5)
	var rig = game.horse.rig
	rig.modulate = Color(1.7, 0.75, 0.75)
	rig.create_tween().tween_property(rig, "modulate", Color.WHITE, 0.45)


func _finish() -> void:
	finished = true
	finish_time = 0.0
	var share := float(rings_got) / maxf(1.0, float(rings_total))
	stars = 1
	if share >= 0.5 and stumbles <= 3:
		stars = 2
	if share >= 0.85 and stumbles <= 1:
		stars = 3
	game.on_ride_finished(course, stars)
