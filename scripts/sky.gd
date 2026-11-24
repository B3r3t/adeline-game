extends Node2D
## The sky ride: Adeline and her little sister on the unicorn, high above the clouds.
##
## She flies the way a bird does. Every tap is one beat of her wings and lifts her; between
## taps she sinks. Storm clouds stand in pairs with a gap to fly through, grumpy little
## thunderclouds bob about, rainbow rings and stars hang along the way, and rainbow arches
## mark how far she has got.
##
## She has three feathers. Bumping a storm cloud costs one. With none left, or if she sinks
## out of the bottom of the sky, she tumbles back down to earth and lands in the hay.
## Then she gallops, takes off and comes back up at the last rainbow arch she reached.

const START_X := 9000.0  # the meadow she takes off from, and comes back down to
const HAY_X := 9340.0
const SKY_HEIGHT := 3200.0  # how far above the ground the middle of the sky ride is
const HALF := 330.0  # how far above and below the middle there is room to fly
const ZOOM := 0.9
const SKY_START := 12000.0  # where the course begins, up in the sky
const SPEED := 285.0
const GRAVITY := 1150.0
const FLAP := -410.0
const MAX_FALL := 520.0
const FEATHERS := 3
const BODY := Vector2(4.0, -92.0)  # the middle of her, from her hooves: what can bump into things
const BODY_SIZE := 34.0
const PILLAR_HALF := 50.0  # half the width of a storm pillar that counts as a bump
const NAMES := ["First flight", "Cloud gates", "Thunder alley", "Rainbow run", "Storm crossing", "Star road"]

var game = null
var active := false
var state := "off"  # run, climb, fly, fall, drop, landed, arrive or done
var story := false  # true when this flight is the end of the unicorn mission
var course := 1
var at := Vector2.ZERO  # her hooves
var vel := Vector2.ZERO
var in_air := false
var tilt := 0.0
var spin := 0.0  # how far she has tumbled, while falling
var feathers := FEATHERS
var safe := 0.0  # seconds left in which nothing can bump her
var glide := 0.0  # seconds left of being held up, just after arriving in the sky
var tapped := false  # whether she has beaten her wings since arriving
var white := 0.0  # how deep in cloud the picture is, from 0 to 1
var white_way := 0
var after_white: Callable
var clock := 0.0
var state_time := 0.0
var speed := SPEED
var gap := 340.0
var items: Array = []
var legs: Array = []  # where each stretch of the course starts: the beginning, then each rainbow arch
var leg := 0
var finish_x := 0.0
var finish_y := 0.0
var stars_total := 0
var stars_got := 0
var rings_total := 0
var rings_got := 0
var falls := 0
var bumps := 0
var stars := 0
var streak := 0
var sizes := {}
var backdrop: Sprite2D = null
var back_layer: CanvasLayer = null
var drifting: Array = []  # clouds that slide past at their own pace: [sprite, where it started, pace]
var hay: Sprite2D = null
var trail: CPUParticles2D = null


func _ready() -> void:
	sizes = JSON.parse_string(FileAccess.get_file_as_string("res://art/sky/sizes.json"))
	back_layer = CanvasLayer.new()
	back_layer.layer = -10
	add_child(back_layer)
	backdrop = Sprite2D.new()
	backdrop.texture = load("res://art/sky/back.jpg")
	backdrop.visible = false
	back_layer.add_child(backdrop)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func sky_y() -> float:
	return game.GROUND_Y - SKY_HEIGHT


func clear() -> void:
	active = false
	state = "off"
	white = 0.0
	white_way = 0
	backdrop.visible = false
	for child in get_children():
		if child != back_layer:
			child.queue_free()
	items.clear()
	legs.clear()
	drifting.clear()
	hay = null
	trail = null
	queue_redraw()


func start(number: int, for_story: bool) -> void:
	clear()
	story = for_story
	course = maxi(number, 1)
	feathers = FEATHERS
	leg = 0
	stars_got = 0
	rings_got = 0
	falls = 0
	bumps = 0
	stars = 0
	streak = 0
	clock = 0.0
	_build()
	active = true
	at = Vector2(START_X - 260.0, game.GROUND_Y)
	vel = Vector2.ZERO
	_go("run")


func _go(next: String) -> void:
	state = next
	state_time = 0.0


func title() -> String:
	return NAMES[(course - 1) % NAMES.size()]


# --- Building the sky ----------------------------------------------------------
# The same number always gives the same sky, so it can be practised.

func _art(name: String) -> Texture2D:
	return load("res://art/sky/%s.png" % name)


## A picture from the sky drawings, at its proper size, centred on a spot.
func _put(name: String, where: Vector2, depth := 0, size := 1.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _art(name)
	var k: float = float(sizes[name]) / sprite.texture.get_height() * size
	sprite.scale = Vector2(k, k)
	sprite.position = where
	sprite.z_index = depth
	add_child(sprite)
	return sprite


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12000 + course
	var hard := minf(course - 1, 6.0)
	speed = SPEED + 12.0 * hard
	gap = maxf(340.0 - 15.0 * hard, 250.0)
	var apart := 650.0 - 12.0 * hard
	var per_leg := 5 + int(minf(course - 1, 3.0))
	var mid := 0.0
	var x := SKY_START + 950.0
	var last := Vector2(SKY_START + 250.0, 0.0)
	legs.append(SKY_START)
	stars_total = 0
	rings_total = 0
	for stretch in 3:
		var previous := ""
		for n in per_leg:
			var kind := "gate"
			var roll := rng.randf()
			if roll > 0.52:
				kind = "ring" if roll < 0.78 else "storm"
			if kind == previous and kind != "gate":
				kind = "gate"
			if stretch == 0 and n == 0:
				kind = "ring"  # the very first thing is friendly
			previous = kind
			mid = clampf(mid + rng.randf_range(-170.0, 170.0), -150.0, 150.0)
			match kind:
				"gate":
					_add_gate(x, mid)
				"ring":
					_add_ring(x, mid)
				"storm":
					# One thundercloud in the way: the road goes past it on the other side.
					var above := rng.randf() < 0.5
					_add_storm(x, mid + (-185.0 if above else 185.0), rng.randf() * TAU, 16.0 * hard)
					mid = clampf(mid + (70.0 if above else -70.0), -170.0, 170.0)
			_add_stars(last, Vector2(x - 120.0, mid), 3)
			last = Vector2(x + 120.0, mid)
			x += apart + rng.randf_range(-40.0, 60.0)
		if stretch < 2:
			# A rainbow arch: this far is safe.
			x += 120.0
			_add_arch(x)
			mid = 0.0
			_add_stars(last, Vector2(x - 150.0, 30.0), 2)
			last = Vector2(x + 200.0, 30.0)
			x += apart + 160.0
	finish_x = x + 500.0
	finish_y = sky_y() + 40.0
	_add_stars(last, Vector2(finish_x - 260.0, 40.0), 5)
	var castle := _put("castle", Vector2(finish_x + 40.0, sky_y() - 60.0), -1)
	castle.offset = Vector2(0.0, 0.0)
	items.append({ "kind": "castle", "x": finish_x, "node": castle, "done": false })
	_dress_sky(rng, finish_x + 1400.0)
	_dress_meadow()
	trail = CPUParticles2D.new()
	trail.texture = game.spark
	trail.amount = 26
	trail.lifetime = 0.7
	trail.emitting = false
	trail.direction = Vector2(-1.0, 0.0)
	trail.spread = 22.0
	trail.initial_velocity_min = 40.0
	trail.initial_velocity_max = 120.0
	trail.gravity = Vector2(0.0, 60.0)
	trail.scale_amount_min = 0.18
	trail.scale_amount_max = 0.42
	trail.scale_amount_curve = game.shrink
	var rainbow := Gradient.new()
	rainbow.set_color(0, Color(1.0, 0.35, 0.6))
	rainbow.set_color(1, Color(0.45, 0.45, 1.0, 0.0))
	rainbow.add_point(0.3, Color(1.0, 0.85, 0.2))
	rainbow.add_point(0.6, Color(0.3, 0.9, 0.6))
	trail.color_ramp = rainbow
	trail.z_index = -1
	add_child(trail)


func _add_gate(x: float, mid: float) -> void:
	var tall := float(sizes["pillar_storm"])
	var top := _put("pillar_storm", Vector2(x, sky_y() + mid - gap / 2.0 - tall / 2.0 + 16.0), 1)
	top.flip_v = true
	var bottom := _put("pillar_storm", Vector2(x, sky_y() + mid + gap / 2.0 + tall / 2.0 - 16.0), 1)
	items.append({ "kind": "gate", "x": x, "mid": mid, "nodes": [top, bottom], "done": false, "hit": false, "rest": [top.position.y, bottom.position.y] })


func _add_storm(x: float, y: float, phase: float, swing: float) -> void:
	var node := _put("storm", Vector2(x, sky_y() + y), 1)
	items.append({ "kind": "storm", "x": x, "y": y, "node": node, "done": false, "hit": false, "phase": phase, "swing": swing })


func _add_ring(x: float, mid: float) -> void:
	# Two halves, one behind her and one in front, so she really flies through it.
	var tex := _art("ring")
	var size := tex.get_size()
	var k: float = float(sizes["ring"]) / size.y * 1.55
	var halves := []
	for i in 2:
		var half := Sprite2D.new()
		half.texture = tex
		half.region_enabled = true
		half.region_rect = Rect2(size.x / 2.0 * i, 0.0, size.x / 2.0, size.y)
		half.scale = Vector2(k, k)
		half.position = Vector2(x + (i - 0.5) * size.x / 2.0 * k, sky_y() + mid)
		half.z_index = -1 if i == 0 else 3
		add_child(half)
		halves.append(half)
	rings_total += 1
	items.append({ "kind": "ring", "x": x, "y": mid, "nodes": halves, "done": false })


## A few stars along an easy curve from one place to the next: they show the way.
func _add_stars(from: Vector2, to: Vector2, count: int) -> void:
	for i in count:
		var k := (i + 0.5) / count
		var where := Vector2(lerpf(from.x, to.x, k), lerpf(from.y, to.y, smoothstep(0.0, 1.0, k)))
		var node := _put("star", Vector2(where.x, sky_y() + where.y), 0)
		stars_total += 1
		items.append({ "kind": "star", "x": where.x, "y": where.y, "node": node, "done": false, "phase": where.x * 0.01 })


func _add_arch(x: float) -> void:
	var tex := _art("arch")
	var size := tex.get_size()
	var k: float = float(sizes["arch"]) / size.y
	var halves := []
	for i in 2:
		var half := Sprite2D.new()
		half.texture = tex
		half.region_enabled = true
		half.region_rect = Rect2(size.x / 2.0 * i, 0.0, size.x / 2.0, size.y)
		half.scale = Vector2(k * 0.5, k)  # seen nearly edge on, like the rings
		half.position = Vector2(x + (i - 0.5) * size.x / 2.0 * k * 0.5, sky_y() + 40.0)
		half.z_index = -1 if i == 0 else 3
		add_child(half)
		halves.append(half)
	legs.append(x)
	items.append({ "kind": "arch", "x": x, "nodes": halves, "done": false })


## Clouds for show: far towers standing out of the cloud sea, little clouds drifting by at
## different depths, and the sea of cloud along the bottom that she must stay above.
func _dress_sky(rng: RandomNumberGenerator, end: float) -> void:
	var from := SKY_START - 1400.0
	var x := from
	while x < end:
		var tower := _put("pillar_cloud", Vector2(x, sky_y() + HALF + rng.randf_range(-40.0, 190.0)), -6, rng.randf_range(0.55, 0.85))
		tower.modulate = Color(1.0, 1.0, 1.0, 0.55)
		drifting.append([tower, tower.position.x, 0.55])
		x += rng.randf_range(520.0, 900.0)
	x = from
	while x < end:
		var far := _put("cloud_%d" % rng.randi_range(0, 2), Vector2(x, sky_y() + rng.randf_range(-HALF, HALF * 0.5)), -5, rng.randf_range(0.7, 1.2))
		far.modulate = Color(1.0, 1.0, 1.0, 0.75)
		drifting.append([far, far.position.x, 0.35])
		x += rng.randf_range(380.0, 760.0)
	# The cloud sea: two rows of big soft clouds, the nearer one in front of her.
	for row in 2:
		x = from - 300.0
		while x < end + 600.0:
			var puff := _put("cloud_%d" % rng.randi_range(0, 2), Vector2(x, sky_y() + HALF + 96.0 + row * 46.0 + rng.randf_range(-12.0, 12.0)), 4 + row, rng.randf_range(2.1, 2.7))
			puff.flip_h = rng.randf() < 0.5
			drifting.append([puff, puff.position.x, -0.06 * row])
			x += rng.randf_range(250.0, 330.0)


func _dress_meadow() -> void:
	hay = Sprite2D.new()
	hay.texture = _art("hay")
	var k: float = float(sizes["hay"]) / hay.texture.get_height()
	hay.scale = Vector2(k, k)
	hay.offset = Vector2(0.0, -hay.texture.get_height() / 2.0)
	hay.position = Vector2(HAY_X, game.GROUND_Y + 14.0)
	hay.z_index = 2
	add_child(hay)


# --- Flying --------------------------------------------------------------------

## A tap anywhere: one beat of her wings.
func tap() -> void:
	if not active:
		return
	if state == "fly":
		vel.y = FLAP
		glide = 0.0
		tapped = true
		game.horse.beat()
	elif state == "landed" and state_time > 0.6:
		feathers = FEATHERS
		_go("run")
		game.sound.shout("adeline", "try_again", 1.0, true)


## One tick, called by Adeline (who is sitting on the unicorn) before she takes her place.
func fly(delta: float) -> void:
	clock += delta
	state_time += delta
	safe = maxf(safe - delta, 0.0)
	_cloud(delta)
	match state:
		"run":
			# A gallop along the meadow to get up speed.
			vel = Vector2(minf(vel.x + 720.0 * delta, 540.0), 0.0)
			at += vel * delta
			at.y = game.GROUND_Y
			in_air = false
			tilt = 0.0
			if state_time > 1.0:
				_go("climb")
				vel = Vector2(430.0, -640.0)
				game.horse.beat()
				game.sound.shout("adeline", "fly_up", 1.0, true)
				game.sound.play("whoosh", -6.0, 0.05, 1.3)
		"climb":
			in_air = true
			at += vel * delta
			vel.y = move_toward(vel.y, -520.0, 300.0 * delta)
			tilt = lerp_angle(tilt, -0.42, 1.0 - exp(-8.0 * delta))
			if game.horse.flap > 0.34:
				game.horse.beat()
			if at.y < game.GROUND_Y - 520.0 and white_way == 0 and white < 0.5:
				_into_cloud(_arrive_in_sky)
		"fly":
			_fly(delta)
		"fall":
			in_air = true
			vel.x = move_toward(vel.x, 70.0, 420.0 * delta)
			vel.y = minf(vel.y + 1500.0 * delta, 900.0)
			at += vel * delta
			spin += delta * 5.0
			tilt = lerp_angle(tilt, 0.75 + sin(spin) * 0.35, 1.0 - exp(-6.0 * delta))
			if at.y > sky_y() + HALF + 250.0 and white_way == 0 and white < 0.5:
				_into_cloud(_arrive_on_earth)
		"drop":
			# Down out of the clouds toward the meadow, wings out to slow her.
			in_air = true
			vel.y = minf(vel.y + 900.0 * delta, 640.0)
			at += vel * delta
			tilt = lerp_angle(tilt, 0.2 + sin(clock * 9.0) * 0.12, 1.0 - exp(-6.0 * delta))
			if game.horse.flap > 0.22:
				game.horse.beat()
			if at.y >= game.GROUND_Y:
				at.y = game.GROUND_Y
				_land()
		"landed":
			in_air = false
			tilt = lerp_angle(tilt, 0.0, 1.0 - exp(-10.0 * delta))
			# She steps out of the hay and shakes herself.
			vel = Vector2(move_toward(vel.x, 0.0, 600.0 * delta), 0.0)
			if at.x < HAY_X + 190.0:
				vel.x = 230.0
			at += vel * delta
		"arrive":
			in_air = true
			vel.x = move_toward(vel.x, 0.0, 330.0 * delta)
			vel.y = (finish_y + 96.0 - at.y) * 3.0
			at += vel * delta
			tilt = lerp_angle(tilt, 0.0, 1.0 - exp(-5.0 * delta))
			if game.horse.flap > 0.5:
				game.horse.beat()
			if state_time > 1.5:
				_go("done")
				game.on_sky_finished(course, stars)
		"done":
			in_air = true
			at.y = finish_y + 96.0 + sin(clock * 2.4) * 8.0
			vel = Vector2.ZERO
			if game.horse.flap > 0.6:
				game.horse.beat()
	if trail != null:
		trail.emitting = in_air and state != "drop"
		trail.position = at + Vector2(-70.0, -70.0)
	_dress_frame()


func _fly(delta: float) -> void:
	in_air = true
	var middle := sky_y()
	if glide > 0.0 and not tapped:
		# Just arrived: she is carried level for a moment, so there is time to get ready.
		glide -= delta
		vel.y = move_toward(vel.y, (middle + 60.0 - at.y) * 2.5, 2400.0 * delta)
		if game.horse.flap > 0.42:
			game.horse.beat()
	else:
		vel.y = minf(vel.y + GRAVITY * delta, MAX_FALL)
	vel.x = move_toward(vel.x, speed, 500.0 * delta)
	at += vel * delta
	# The top of the sky is soft: she simply cannot go higher.
	var roof := middle - HALF + 150.0
	if at.y < roof:
		at.y = roof
		vel.y = maxf(vel.y, 0.0)
	tilt = lerp_angle(tilt, clampf(vel.y / 900.0, -0.42, 0.5), 1.0 - exp(-10.0 * delta))
	if at.y + BODY.y > middle + HALF + 70.0:
		_fall("She sank into the clouds!")
		return
	var body := at + BODY
	for item in items:
		if item["done"]:
			continue
		var ix: float = item["x"]
		match str(item["kind"]):
			"gate":
				if absf(body.x - ix) < PILLAR_HALF + BODY_SIZE * 0.6:
					var dy := body.y - (middle + float(item["mid"]))
					if absf(dy) > gap / 2.0 - BODY_SIZE + 14.0:
						_bump(-signf(dy), item)
				elif body.x > ix + PILLAR_HALF + BODY_SIZE:
					item["done"] = true
			"storm":
				var where := Vector2(ix, middle + float(item["y"]) + sin(clock * 1.7 + float(item["phase"])) * float(item["swing"]))
				item["node"].position = where
				if body.distance_to(where) < 56.0 + BODY_SIZE * 0.6:
					_bump(signf(body.y - where.y), item)
				elif body.x > ix + 120.0:
					item["done"] = true
			"ring":
				if body.x >= ix - 60.0:
					if absf(body.y - (middle + float(item["y"]))) <= 118.0:
						item["done"] = true
						_ring(item)
					elif body.x > ix + 60.0:
						item["done"] = true
						streak = 0
			"star":
				var where := Vector2(ix, middle + float(item["y"]))
				if body.distance_to(where) < 74.0:
					item["done"] = true
					_star(item)
				elif body.x > ix + 160.0:
					item["done"] = true
			"arch":
				if body.x >= ix:
					item["done"] = true
					_checkpoint(item)
			"castle":
				if body.x >= ix - 60.0:
					item["done"] = true
					_finish()


func _bump(away: float, item: Dictionary) -> void:
	if safe > 0.0:
		return
	bumps += 1
	feathers -= 1
	item["hit"] = true
	game.jolt(6.0)
	game.sound.play("zap", -4.0, 0.06)
	game.sound.play("thump", -8.0, 0.1)
	var rig = game.horse.rig
	rig.modulate = Color(1.6, 1.6, 0.7)
	rig.create_tween().tween_property(rig, "modulate", Color.WHITE, 0.5)
	if feathers <= 0:
		_fall("The storm clouds knocked her out of the sky!")
		return
	safe = 1.5
	vel.y = (away if away != 0.0 else 1.0) * 300.0
	vel.x = speed * 0.55
	game.sound.shout("adeline", "whoa", 1.0, true)


func _fall(why: String) -> void:
	falls += 1
	spin = 0.0
	vel.y = maxf(vel.y, 120.0)
	_go("fall")
	game.toast(why)
	game.sound.shout("adeline", "falling", 1.0, true)
	game.sound.shout("sister", "sister_uhoh", 1.0, true)
	game.sound.play("whoosh", -5.0, 0.05, 0.7)


func _ring(item: Dictionary) -> void:
	rings_got += 1
	game.sister.cheer = 1.0
	game.sound.play("chime", -4.0, 0.0, 1.0 + 0.06 * minf(streak, 8.0), 0.0)
	streak += 1
	if streak == 3:
		game.sound.shout("sister", "sister_higher", 1.0)
	for half in item["nodes"]:
		var tween: Tween = half.create_tween()
		tween.set_parallel(true)
		tween.tween_property(half, "modulate", Color(2.0, 2.0, 1.6, 0.0), 0.35)
		tween.tween_property(half, "scale", half.scale * 1.3, 0.35)
	_sparkle(Vector2(float(item["x"]), sky_y() + float(item["y"])), 26, Color(1.0, 0.5, 0.8))


func _star(item: Dictionary) -> void:
	stars_got += 1
	game.sound.play("pop", -9.0, 0.0, 1.5 + 0.05 * (stars_got % 6), 0.0)
	var node: Sprite2D = item["node"]
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 0.0, 0.25)
	tween.tween_property(node, "scale", node.scale * 1.8, 0.25)
	tween.tween_property(node, "position:y", node.position.y - 40.0, 0.25)
	_sparkle(node.position, 8, Color(1.0, 0.8, 0.2))


func _checkpoint(item: Dictionary) -> void:
	leg = legs.find(float(item["x"]))
	feathers = FEATHERS
	game.sister.cheer = 1.6
	game.toast("Rainbow arch! You will come back up here if you fall.")
	game.sound.play("fanfare", -9.0, 0.0, 1.25)
	game.sound.shout("sister", "sister_flying", 1.0)
	_sparkle(Vector2(float(item["x"]), at.y + BODY.y), 34, Color(0.7, 0.5, 1.0))


func _finish() -> void:
	_go("arrive")
	var share := float(stars_got) / maxf(1.0, float(stars_total))
	stars = 1
	if falls <= 1 and share >= 0.4:
		stars = 2
	if falls == 0 and share >= 0.7:
		stars = 3
	game.sister.cheer = 4.0
	game.sound.play("fanfare", -5.0, 0.0)
	game.sound.shout("adeline", "we_did_it", 1.0, true)
	_sparkle(at + BODY, 40, Color(1.0, 0.85, 0.4))


func _sparkle(where: Vector2, amount: int, color: Color) -> void:
	var burst := CPUParticles2D.new()
	burst.texture = game.spark
	burst.position = where
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = amount
	burst.lifetime = 0.6
	burst.spread = 180.0
	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 260.0
	burst.gravity = Vector2(0.0, 200.0)
	burst.scale_amount_min = 0.25
	burst.scale_amount_max = 0.7
	burst.scale_amount_curve = game.shrink
	burst.color = color
	burst.z_index = 4
	burst.emitting = true
	add_child(burst)
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)


# --- Between the earth and the sky -------------------------------------------------

## The picture goes white, as if flying into a cloud. When it is fully white, `then` is
## called to move everything, and the white clears again.
func _into_cloud(then: Callable) -> void:
	white_way = 1
	after_white = then


func _cloud(delta: float) -> void:
	if white_way == 0:
		return
	white = clampf(white + white_way * delta * (3.2 if white_way > 0 else 1.9), 0.0, 1.0)
	if white_way > 0 and white >= 1.0:
		white_way = -1
		after_white.call()
	elif white_way < 0 and white <= 0.0:
		white_way = 0


## Up through the cloud and out into the sky, at the last rainbow arch she reached.
func _arrive_in_sky() -> void:
	var from: float = legs[clampi(leg, 0, legs.size() - 1)]
	at = Vector2(from + (60.0 if leg > 0 else -200.0), sky_y() + HALF + 150.0)
	vel = Vector2(speed, -560.0)
	tilt = -0.4
	glide = 2.6
	tapped = false
	safe = 2.2
	streak = 0
	# Whatever she bumped into last time is given back, from here on.
	for item in items:
		if float(item["x"]) > at.x and str(item["kind"]) in ["gate", "storm"]:
			item["done"] = false
			item["hit"] = false
	_go("fly")
	game.snap_camera()
	if falls == 0:
		game.sound.shout("sister", "sister_flying", 1.0, true)


## Down out of the cloud over the meadow.
func _arrive_on_earth() -> void:
	at = Vector2(HAY_X - 150.0, game.GROUND_Y - 780.0)
	vel = Vector2(96.0, 300.0)
	tilt = 0.3
	_go("drop")
	game.snap_camera()


func _land() -> void:
	_go("landed")
	vel = Vector2.ZERO
	game.jolt(5.0)
	game.sound.play("thump", -3.0, 0.08)
	game.sound.play("land", -6.0, 0.08)
	game.sound.play("snort", -6.0)
	# Hay flies everywhere.
	var burst := CPUParticles2D.new()
	burst.position = Vector2(at.x, game.GROUND_Y - 60.0)
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 46
	burst.lifetime = 1.1
	burst.direction = Vector2(0.0, -1.0)
	burst.spread = 70.0
	burst.initial_velocity_min = 180.0
	burst.initial_velocity_max = 520.0
	burst.gravity = Vector2(0.0, 900.0)
	burst.angular_velocity_min = -400.0
	burst.angular_velocity_max = 400.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = Color(0.98, 0.82, 0.3)
	burst.z_index = 3
	burst.emitting = true
	add_child(burst)
	get_tree().create_timer(1.6).timeout.connect(burst.queue_free)
	if hay != null:
		hay.scale.y *= 0.72
		hay.create_tween().tween_property(hay, "scale:y", hay.scale.x, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.7).timeout.connect(func(): game.sound.shout("sister", "sister_again", 1.0, true))


# --- The camera and the scenery ------------------------------------------------------

func high_up() -> bool:
	return state in ["fly", "fall", "arrive", "done"]


## Where the camera should look, given how much of the world the screen shows.
func camera_target(view: Vector2) -> Vector2:
	if state == "arrive" or state == "done":
		# The castle sits to the left, leaving room beside it for the stars she has earned.
		return Vector2(finish_x + view.x * 0.24, sky_y() + 20.0)
	if high_up():
		return Vector2(at.x + view.x * 0.22, sky_y() + 20.0)
	var y: float = minf(game.GROUND_Y - 0.27 * view.y, at.y - 0.1 * view.y)
	return Vector2(at.x + view.x * 0.16, y)


func _dress_frame() -> void:
	var cam: Vector2 = game.cam_pos
	for entry in drifting:
		var node: Sprite2D = entry[0]
		node.position.x = float(entry[1]) + (cam.x - SKY_START) * float(entry[2])
	for item in items:
		if item["done"]:
			continue
		if str(item["kind"]) == "star":
			var node: Sprite2D = item["node"]
			node.rotation = sin(clock * 2.2 + float(item["phase"])) * 0.22
			node.position.y = sky_y() + float(item["y"]) + sin(clock * 3.0 + float(item["phase"])) * 5.0
		elif str(item["kind"]) == "gate":
			# The storm pillars shiver, and flash when they have just been bumped.
			for i in 2:
				var node: Sprite2D = item["nodes"][i]
				node.position.y = float(item["rest"][i]) + sin(clock * 2.0 + float(item["x"]) * 0.01 + i) * 4.0
				node.modulate = Color(1.5, 1.5, 0.9) if item["hit"] and safe > 1.1 else Color.WHITE
	# The painted sky fills the screen whenever she is up there, and slides a little.
	var s := get_viewport_rect().size
	backdrop.visible = high_up()
	if backdrop.visible:
		var size := backdrop.texture.get_size()
		var k := maxf((s.x + 120.0) / size.x, s.y / size.y)
		backdrop.scale = Vector2(k, k)
		var along := clampf((cam.x - SKY_START) / maxf(finish_x - SKY_START, 1.0), 0.0, 1.0)
		backdrop.position = Vector2(s.x / 2.0 + 50.0 - 100.0 * along, s.y / 2.0)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	# The meadow: soil, then the same grass as the island, carried on from where it stops.
	var g: float = game.GROUND_Y
	var tex: Texture2D = game.ground_art
	var k: float = game.GROUND_ART_HEIGHT / tex.get_height()
	var tile := tex.get_width() * k
	var left: float = game.LEVEL_LEFT - 600.0 + floorf((START_X - 1500.0 - (game.LEVEL_LEFT - 600.0)) / tile) * tile
	var width := tile * 3.0
	draw_rect(Rect2(left, g + 100.0, width, 700.0), Color(0.33, 0.17, 0.1))
	draw_set_transform(Vector2(left, g - game.GRASS_RISE), 0.0, Vector2(k, k))
	draw_texture_rect(tex, Rect2(0.0, 0.0, width / k, tex.get_height()), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A soft shadow under her on the meadow.
	if not high_up() and at.y > g - 500.0:
		var near := clampf(1.0 - (g - at.y) / 500.0, 0.0, 1.0)
		draw_set_transform(Vector2(at.x, g + 4.0), 0.0, Vector2(1.0, 0.2))
		draw_circle(Vector2.ZERO, 70.0 * (0.5 + 0.5 * near), Color(0.0, 0.0, 0.0, 0.28 * near))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
