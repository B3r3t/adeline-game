extends Node2D
## The riding course, run on real physics.
##
## The ground rolls. Spirit carries momentum: gravity slows her on the way up a hill and
## speeds her up on the way down, she flies off any ledge the ground drops away from, and
## she lands with whatever speed she still has along the slope. Jump rails, hay bales and
## logs are rigid bodies. Clip one and it is knocked away at Spirit's own speed, then
## tumbles, bounces and rolls by itself.
##
## Nothing here can be lost: a knocked obstacle costs Spirit some of her speed, and the
## course ends with one to three stars.

const HorseScript := preload("res://scripts/horse.gd")

const START_X := 8000.0
const LENGTH := 14000.0
const BASE_SPEED := 470.0
const FAST_SPEED := 600.0
const SLOW_SPEED := 350.0
const ART_SCALE := 1.0 / 2.2

# The forces on Spirit.
const GRAVITY := 1900.0
const JUMP := -820.0
const DRIVE_GAIN := 1.7  # how hard she works to get back to the pace she is asked for
const PUSH_MAX := 680.0  # the most her legs can add, per second
const BRAKE_MAX := 240.0  # she holds back only gently, so downhills really are faster
const MAX_SPEED := 900.0
const MIN_SPEED := 230.0
const KNOCK_KEEPS := 0.6  # the share of her speed she keeps after clipping something
const TICK := 1.0 / 60.0  # the step used when working out a jump in advance

const RIDER_HEIGHT := 112.0  # how far above Spirit's hooves the middle of Adeline is
const FINISH_SIZE := 1.5  # the finish gate is drawn this much bigger, so a rider fits under its banner
const CROWD_FACES := 16  # how many different spectators there are pictures of
# Who rides each of the other horses, in the order of RIVALS: their drawings and their name.
const RIDERS := [["finn", "Finn"], ["rosa", "Rosa"], ["baron", "Baron Vex"]]
const RING_OPENING := 112.0  # how far above or below a ring's middle she can be and still get it
const RING_REACH := 72.0  # Spirit is long: the ring counts from her nose reaching it to her tail leaving it
const RING_AIM := 29.0  # how closely a worked-out jump must thread a ring when the course is built
const PIECES := 4  # the collision layer for things that can be knocked over

# The jump is one picture, cut into the parts that stand still and the three rails.
const FENCE_STILL := [Rect2(0, 0, 47, 136), Rect2(215, 0, 48, 136), Rect2(47, 92, 168, 44)]
const FENCE_RAILS := [Rect2(47, 30, 168, 17), Rect2(47, 52, 168, 19), Rect2(47, 76, 168, 16)]


## Where Spirit is and how she is moving.
class Rider:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var speed := 0.0  # along the ground, while her hooves are on it
	var grounded := true
	var impact := 0.0  # how hard she last came down
	var kick := 1.0  # more than 1 while she is putting on a burst of speed


var game = null
var active := false
var finished := false
var course := 1
var rider := Rider.new()
var items: Array = []
var hills: Array = []  # [height, wave number, phase] for each layer of rolling ground
var ledges: Array = []  # [start, rise length, drop length, height]
var roughness := 1.0
var nominal := PackedFloat32Array()  # the speed an unhurried ride has at each point
var rings_total := 0
var rings_got := 0
var jumps_clean := 0
var stumbles := 0
var air_time := 0.0
var finish_x := 0.0
var crowds: Array = []  # the people watching a race: where each group is, and who is in it
var crowd_clock := 0.0
var finish_time := 0.0
var run_time := 0.0
var stars := 0
var last_x := 0.0
var shadow: Sprite2D = null
var racing := false  # a race against other horses, rather than the obstacle course
var rivals: Array = []
var jumps: Array = []  # where the things to jump are, in order, for the other horses
var rivals_home := 0  # how many of them have already finished
var place := 0  # where Spirit came, once a race is over
var boost := 0.34  # how much burst of speed is saved up, from 0 to 1; a burst uses a third
var boost_time := 0.0  # how long the burst she is on has left

# The horses Spirit races: name, how grey, what colour, how bright, and how quick.
const RIVALS := [
	["Thunder", 1.0, Color(1.0, 1.0, 1.05), 2.4, 1.0],
	["Daisy", 0.5, Color(1.0, 0.86, 0.5), 2.5, 0.97],
	["Pepper", 0.9, Color(0.92, 0.92, 1.0), 0.5, 1.03],
]
var flight := 0.0  # how long the current time in the air has lasted
var streak := 0  # rings collected in a row


func clear() -> void:
	active = false
	finished = false
	for child in get_children():
		child.queue_free()
	items.clear()
	hills.clear()
	ledges.clear()
	rivals.clear()
	crowds.clear()
	jumps.clear()
	shadow = null


func start(number: int, race := false) -> void:
	clear()
	racing = race
	rivals_home = 0
	place = 0
	boost = 0.34
	boost_time = 0.0
	course = maxi(number, 1)
	rings_total = 0
	rings_got = 0
	jumps_clean = 0
	stumbles = 0
	air_time = 0.0
	flight = 0.0
	streak = 0
	finish_time = 0.0
	run_time = 0.0
	stars = 0
	last_x = START_X
	_build()
	rider = _rider_at(START_X, 0.0)
	active = true


## The pace Spirit is asked for. The arrows ask for a slower or faster one.
func pace(axis: float) -> float:
	if finished:
		return 0.0
	var speed := BASE_SPEED
	if axis > 0.0:
		speed = lerpf(BASE_SPEED, FAST_SPEED, axis)
	elif axis < 0.0:
		speed = lerpf(BASE_SPEED, SLOW_SPEED, -axis)
	if boost_time > 0.0:
		speed *= 1.32
	return speed * (1.0 + 0.05 * minf(course - 1, 6.0))


## A burst of speed. Bursts are saved up over time and by collecting rings and jumping cleanly.
func use_boost() -> void:
	if finished or boost < 0.33 or boost_time > 0.0:
		return
	boost -= 0.33
	boost_time = 1.5
	game.sound.play("whoosh", -2.0, 0.05, 1.25)
	game.sound.shout("adeline", "woohoo", 0.5)


# --- The ground --------------------------------------------------------------

## How high the ground stands above the flat at this point.
func elevation(x: float) -> float:
	var u := x - START_X
	var e := 0.0
	for h in hills:
		e += float(h[0]) * 0.5 * (1.0 - cos(float(h[1]) * u + float(h[2])))
	# Flat at the start and at the finish.
	e *= roughness * smoothstep(500.0, 1200.0, u) * (1.0 - smoothstep(LENGTH - 1500.0, LENGTH - 850.0, u))
	for l in ledges:
		var t: float = x - float(l[0])
		var up: float = l[1]
		if t <= 0.0 or t >= up + float(l[2]):
			continue
		if t <= up:
			e += float(l[3]) * (t / up) * (t / up)  # a ramp that gets steeper, then stops dead
		else:
			e += float(l[3]) * (1.0 - smoothstep(0.0, 1.0, (t - up) / float(l[2])))
	return e


## The line Spirit's hooves run along.
func ground_y(x: float) -> float:
	return game.GROUND_Y - elevation(x)


## How steeply the ground falls (above zero) or climbs (below zero) here.
func slope(x: float) -> float:
	return (ground_y(x + 3.0) - ground_y(x - 3.0)) / 6.0


func _slope_behind(x: float) -> float:
	return (ground_y(x) - ground_y(x - 3.0)) / 3.0


# --- How Spirit moves --------------------------------------------------------

func _rider_at(x: float, speed: float) -> Rider:
	var r := Rider.new()
	r.x = x
	r.y = ground_y(x)
	r.speed = speed
	var m := _slope_behind(x)
	var inv := 1.0 / sqrt(1.0 + m * m)
	r.vx = speed * inv
	r.vy = speed * m * inv
	return r


## One tick of riding. `target` is the pace Spirit is being asked for.
func step(r: Rider, dt: float, target: float) -> void:
	r.impact = 0.0
	if r.grounded:
		var m := _slope_behind(r.x)
		var inv := 1.0 / sqrt(1.0 + m * m)
		# Along the ground there are two forces: her own legs, and gravity's share of the slope.
		var legs := clampf((target - r.speed) * DRIVE_GAIN * r.kick, -BRAKE_MAX, PUSH_MAX * r.kick)
		if target <= 0.0:
			legs = -900.0
		r.speed += (GRAVITY * m * inv + legs) * dt
		if target > 0.0:
			r.speed = clampf(r.speed, MIN_SPEED, MAX_SPEED)
		else:
			r.speed = maxf(r.speed, 0.0)
		r.vx = r.speed * inv
		r.vy = r.speed * m * inv
		var nx := r.x + r.vx * dt
		var free_y := r.y + r.vy * dt + 0.5 * GRAVITY * dt * dt  # where she would be with nothing under her
		var gy := ground_y(nx)
		r.x = nx
		if free_y < gy - 0.05:
			# The ground has dropped away faster than she falls, so she is in the air.
			r.grounded = false
			r.y = free_y
			r.vy += GRAVITY * dt
		else:
			r.y = gy
	else:
		r.vy += GRAVITY * dt
		r.x += r.vx * dt
		r.y += r.vy * dt
		var gy := ground_y(r.x)
		if r.y >= gy:
			# Landing. She keeps the part of her speed that points along the ground.
			var m := slope(r.x)
			var inv := 1.0 / sqrt(1.0 + m * m)
			r.impact = maxf((r.vy - r.vx * m) * inv, 1.0)
			r.speed = maxf((r.vx + r.vy * m) * inv, MIN_SPEED * 0.6)
			r.y = gy
			r.grounded = true
			r.vx = r.speed * inv
			r.vy = r.speed * m * inv


## Spirit pushes off. A jump taken going uphill carries higher; one taken going downhill, lower.
func jump(r: Rider) -> void:
	var rising := r.vy if r.grounded else 0.0
	r.vy = clampf(rising + JUMP, JUMP * 1.25, JUMP * 0.85)
	r.grounded = false


## Works out, in advance, the path through the air from a given spot and speed.
## The path is empty if Spirit never leaves the ground.
func trace(x: float, speed: float, with_jump: bool, target: float) -> PackedVector2Array:
	var r := _rider_at(x, speed)
	if with_jump:
		jump(r)
	var path := PackedVector2Array()
	for i in 220:
		step(r, TICK, target)
		if not r.grounded:
			path.append(Vector2(r.x, r.y))
		elif path.size() > 0:
			path.append(Vector2(r.x, r.y))
			break
		elif i > 40:
			break
	return path


## How high (as a y position) a path is when it crosses x, or INF if it never gets there.
func path_y_at(path: PackedVector2Array, x: float) -> float:
	for i in range(1, path.size()):
		if path[i].x >= x and path[i - 1].x <= x:
			var k := inverse_lerp(path[i - 1].x, path[i].x, x)
			return lerpf(path[i - 1].y, path[i].y, k)
	return INF


func nominal_speed(x: float) -> float:
	if nominal.is_empty():
		return BASE_SPEED
	return nominal[clampi(int((x - START_X) / 40.0), 0, nominal.size() - 1)]


# --- Building a course -------------------------------------------------------
# The same course number always gives the same course, so it can be practised.

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (9000 if racing else 7000) + course
	roughness = minf(0.7 + 0.1 * (course - 1), 1.15)
	hills = [
		[90.0, TAU / rng.randf_range(1500.0, 1900.0), rng.randf() * TAU],
		[45.0, TAU / rng.randf_range(800.0, 1000.0), rng.randf() * TAU],
		[10.0, TAU / rng.randf_range(400.0, 500.0), rng.randf() * TAU],
	]
	# First decide what goes where, because ledges change the shape of the ground.
	var kinds := ["fence", "ring_low", "bale", "ring_mid", "log", "fence_ring", "arc", "ledge"]
	if course >= 2:
		kinds.append_array(["ring_high", "arc", "fence_ring", "ledge"])
	if racing:
		# A race is mostly jumps, with a few rings to earn bursts of speed.
		kinds = ["fence", "bale", "log", "fence", "bale", "ring_low", "ring_mid", "ledge"]
	var plan: Array = []
	var x := START_X + 950.0
	var previous := ""
	while x < START_X + LENGTH - 1100.0:
		var kind: String = kinds[rng.randi() % kinds.size()]
		if kind == previous:
			kind = kinds[rng.randi() % kinds.size()]
		if kind == "ledge" and (previous == "ledge" or x > START_X + LENGTH - 2600.0):
			kind = "bale"
		previous = kind
		plan.append([kind, x])
		if kind == "ledge":
			ledges.append([x, 560.0, 170.0, 95.0 + 10.0 * minf(course - 1, 3.0)])
			x += 730.0 + 320.0
		elif kind == "arc":
			x += 300.0
		x += rng.randf_range(560.0, 780.0) - 30.0 * minf(course - 1, 4.0)
	finish_x = START_X + LENGTH - 300.0

	_build_ground()
	_measure_nominal()
	shadow = Sprite2D.new()
	shadow.texture = game.spark
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.6)
	add_child(shadow)

	for entry in plan:
		var kind: String = entry[0]
		var at: float = entry[1]
		match kind:
			"fence", "bale", "log":
				_add_obstacle(kind, _gentle_spot(at))
			"ring_low":
				_add_ring(at, ground_y(at) - RIDER_HEIGHT - 4.0)
			"ring_mid":
				_add_jump_ring(at, 105.0)
			"ring_high":
				_add_jump_ring(at, 145.0)
			"fence_ring":
				at = _gentle_spot(at)
				_add_ring(at, _apex_over(at) + 40.0 - RIDER_HEIGHT)
				_add_obstacle("fence", at)
			"arc":
				# Three rings along the path of one jump.
				var path := trace(at, nominal_speed(at), true, pace(0.0))
				for share in [0.25, 0.5, 0.75]:
					var p: Vector2 = path[int(path.size() * share)]
					_add_ring(p.x, p.y - RIDER_HEIGHT)
			"ledge":
				# A ring hanging in the air where Spirit flies off the edge.
				var lip: float = at + 560.0
				var path := trace(lip - 40.0, nominal_speed(lip - 40.0), false, pace(0.0))
				if path.size() >= 8:
					var p: Vector2 = path[int(path.size() * 0.45)]
					_add_ring(p.x, p.y - RIDER_HEIGHT)
	if racing:
		_add_crowds(plan)
	# The finish is a gate to ride through, so it is drawn in two layers: the far post and
	# the banner behind the horses, and the near post in front of them.
	var gate: Texture2D = load("res://art/props/finish.png")
	var size := gate.get_size()
	var split := size.x * 0.8
	for near in [false, true]:
		var part := Sprite2D.new()
		part.texture = gate
		part.region_enabled = true
		part.region_rect = Rect2(split, 0.0, size.x - split, size.y) if near else Rect2(0.0, 0.0, split, size.y)
		part.scale = Vector2(ART_SCALE, ART_SCALE) * FINISH_SIZE
		part.offset = Vector2(0.0, -size.y / 2.0)
		var middle := (split + size.x) / 2.0 if near else split / 2.0
		part.position = Vector2(finish_x + (middle - size.x / 2.0) * ART_SCALE * FINISH_SIZE, ground_y(finish_x) + 4.0)
		part.z_index = 3 if near else 0
		add_child(part)
	if racing:
		_add_rivals(rng)
		game.toast("Racing %s, %s and %s!" % [RIDERS[0][1], RIDERS[1][1], RIDERS[2][1]])


## People who have come to watch the race: a few here and there along the track, and a
## bigger gathering at the finish. They stand behind a rope on the far side, hop and wave
## as Spirit comes by, and give a cheer.
func _add_crowds(plan: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + course  # their own dice, so the race itself is laid out as before
	var spots: Array = []
	var x := START_X + 620.0
	while x < finish_x - 900.0:
		spots.append([x, rng.randi_range(3, 4), false])
		x += rng.randf_range(1500.0, 2100.0)
	for gap in [-560.0, -280.0, 250.0, 520.0]:
		spots.append([finish_x + gap, rng.randi_range(5, 6), true])
	for spot in spots:
		var at: float = spot[0]
		var big: bool = spot[2]
		if not big:
			# Not where there is something to jump, and not on a ledge: look a little further
			# along until there is room.
			var found := false
			for attempt in 8:
				var here := at + attempt * 130.0
				var clear := here < finish_x - 800.0
				for item in plan:
					var from: float = item[1]
					var reach := 900.0 if str(item[0]) == "ledge" else 300.0
					if here > from - 300.0 and here < from + reach:
						clear = false
				if clear:
					at = here
					found = true
					break
			if not found:
				continue
		var count: int = spot[1]
		var people: Array = []
		var width := count * 44.0
		# Tallest at the back, so the rope and the little ones are not hidden.
		for i in count:
			var who := Sprite2D.new()
			who.texture = load("res://art/props/crowd_%d.png" % rng.randi_range(0, CROWD_FACES - 1))
			who.scale = Vector2(ART_SCALE, ART_SCALE) * 0.92
			who.flip_h = rng.randf() < 0.4
			who.offset = Vector2(0.0, -who.texture.get_size().y / 2.0)
			var px := at - width / 2.0 + (i + 0.5) * 44.0 + rng.randf_range(-7.0, 7.0)
			who.position = Vector2(px, ground_y(px) + 3.0)
			add_child(who)
			people.append([who, who.position.y, rng.randf() * TAU])
		# The rope they stand behind.
		var rope := Line2D.new()
		rope.width = 3.0
		rope.default_color = Color(0.86, 0.74, 0.5)
		var from_x := at - width / 2.0 - 26.0
		var posts := int(ceil((width + 52.0) / 58.0))
		for i in posts + 1:
			var px := from_x + (width + 52.0) * i / posts
			var py := ground_y(px) + 3.0
			var post := Line2D.new()
			post.width = 7.0
			post.default_color = Color(0.45, 0.3, 0.18)
			post.points = PackedVector2Array([Vector2(px, py), Vector2(px, py - 34.0)])
			post.begin_cap_mode = Line2D.LINE_CAP_ROUND
			post.end_cap_mode = Line2D.LINE_CAP_ROUND
			add_child(post)
			rope.add_point(Vector2(px, py - 28.0))
			if i < posts:
				rope.add_point(Vector2(px + (width + 52.0) / posts / 2.0, ground_y(px + 29.0) + 3.0 - 22.0))  # it sags
		add_child(rope)
		crowds.append({ "x": at, "people": people, "cheered": false, "big": big })


func _crowd_frame(delta: float) -> void:
	crowd_clock += delta
	for crowd in crowds:
		var away := absf(rider.x - float(crowd["x"]))
		var excited := away < 640.0 or (finished and bool(crowd["big"]))
		for person in crowd["people"]:
			var who: Sprite2D = person[0]
			var phase: float = person[2]
			if excited:
				who.position.y = float(person[1]) - absf(sin(crowd_clock * 7.0 + phase)) * 8.0
				who.rotation = sin(crowd_clock * 5.0 + phase) * 0.05
			else:
				who.position.y = float(person[1]) - (0.5 + 0.5 * sin(crowd_clock * 2.0 + phase)) * 1.5
				who.rotation = 0.0
		if not crowd["cheered"] and rider.x > float(crowd["x"]) - 430.0 and not finished:
			crowd["cheered"] = true
			game.sound.play("crowd_cheer", -9.0 if crowd["big"] else -12.0, 0.03, 1.0, 0.6)


## The other horses. Each runs on the same physics as Spirit, in a lane a little further back.
func _add_rivals(rng: RandomNumberGenerator) -> void:
	for item in items:
		if item["kind"] != "ring":
			jumps.append(float(item["x"]))
	jumps.sort()
	for i in RIVALS.size():
		var spec: Array = RIVALS[i]
		var who := { "position": Vector2(START_X, ground_y(START_X)), "velocity": Vector2.ZERO, "air": false, "pitch": 0.0, "facing": 1 }
		var node := Node2D.new()
		node.set_script(HorseScript)
		node.game = game
		node.wild = true
		node.tack = true
		node.rider_art = "res://art/rider_%s" % RIDERS[i][0]
		node.subject = who
		add_child(node)
		node.state = "mounted"
		node.set_coat(float(spec[1]), spec[2], float(spec[3]))
		# One runs on the near side of Spirit and two on the far side, each a little smaller
		# the further away it is.
		var lane: float = [-15.0, 13.0, -29.0][i]
		var size: float = [0.93, 1.05, 0.87][i]
		node.scale = Vector2(size, size)
		node.z_index = 1 if lane > 0.0 else 0
		# Now and then a horse knocks a jump. Which ones is settled before the race starts.
		var fumbles := {}
		for j in jumps.size():
			if rng.randf() < 0.2 + 0.03 * i:
				fumbles[j] = true
		rivals.append({ "node": node, "who": who, "rider": _rider_at(START_X, 0.0), "pace": float(spec[4]), "lane": lane, "want": [90.0, -210.0, -50.0][i], "next": 0, "slow": 0.0, "fumbles": fumbles, "home": false })


func _run_rivals(delta: float) -> void:
	for rival in rivals:
		var r: Rider = rival["rider"]
		var target: float = BASE_SPEED * (1.0 + 0.05 * minf(course - 1, 6.0)) * float(rival["pace"])
		# A horse far in front eases off and one far behind digs in, so the race stays close.
		# Each has its own idea of where it wants to be, and that drifts, so they jostle.
		var want: float = float(rival["want"]) + 230.0 * sin(run_time * 0.23 + float(rival["lane"]))
		target *= clampf(1.0 - (r.x - rider.x - want) / 2600.0, 0.88, 1.24)
		rival["slow"] = maxf(float(rival["slow"]) - delta, 0.0)
		if float(rival["slow"]) > 0.0:
			target *= 0.55
		if r.x >= finish_x:
			target = 0.0
			if not rival["home"]:
				rival["home"] = true
				if not finished:
					rivals_home += 1
		var n: int = rival["next"]
		if n < jumps.size() and r.grounded and float(jumps[n]) - r.x < r.speed * 0.34 + 24.0:
			rival["next"] = n + 1
			jump(r)
			if rival["fumbles"].has(n):
				r.vy *= 0.45  # too low: it clips the jump and loses ground
				rival["slow"] = 0.9
		step(r, delta, target)
		var who: Dictionary = rival["who"]
		who["position"] = Vector2(r.x, r.y + float(rival["lane"]))
		who["velocity"] = Vector2(r.vx, r.vy)
		who["air"] = not r.grounded
		var lean := atan(slope(r.x))
		if not r.grounded:
			lean = clampf(atan2(r.vy, maxf(r.vx, 60.0)) * 0.45, -0.5, 0.5)
		who["pitch"] = lerp_angle(float(who["pitch"]), lean, 1.0 - exp(-12.0 * delta))
		rival["node"].carry(delta)


## Where Spirit is in the race right now: 1 for first.
func rank() -> int:
	var ahead := 0
	for rival in rivals:
		if rival["rider"].x > rider.x:
			ahead += 1
	return ahead + 1


## The ground is one long strip of the grass picture, bent to follow the hills, with soil
## under it, plus the solid shape that knocked-over things land on.
func _build_ground() -> void:
	var x0 := START_X - 1200.0
	var x1 := START_X + LENGTH + 1800.0
	var tex: Texture2D = game.ground_art
	var k: float = game.GROUND_ART_HEIGHT / tex.get_height()
	var tile := tex.get_width() * k
	var grass := [PackedVector2Array(), PackedVector2Array(), PackedInt32Array()]
	var soil := [PackedVector2Array(), PackedVector2Array(), PackedInt32Array()]
	var deep: float = game.GROUND_Y + 800.0
	var n := 0
	var x := x0
	while x <= x1:
		var top: float = ground_y(x) - game.GRASS_RISE
		grass[0].append(Vector2(x, top))
		grass[0].append(Vector2(x, top + game.GROUND_ART_HEIGHT))
		grass[1].append(Vector2((x - x0) / tile, 0.004))
		grass[1].append(Vector2((x - x0) / tile, 0.996))
		soil[0].append(Vector2(x, top + 124.0))
		soil[0].append(Vector2(x, deep))
		soil[1].append(Vector2.ZERO)
		soil[1].append(Vector2.ZERO)
		if n > 0:
			var i := n * 2
			for strip in [grass, soil]:
				strip[2].append_array([i - 2, i, i - 1, i - 1, i, i + 1])
		n += 1
		x += 24.0
	var under := _strip(soil, null)
	under.modulate = Color(0.33, 0.17, 0.1)
	_strip(grass, tex)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var floor_y: float = game.GROUND_Y + 80.0
	x = x0
	while x < x1:
		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array([
			Vector2(x, ground_y(x)), Vector2(x + 48.0, ground_y(x + 48.0)),
			Vector2(x + 48.0, floor_y), Vector2(x, floor_y),
		])
		var col := CollisionShape2D.new()
		col.shape = shape
		body.add_child(col)
		x += 48.0
	add_child(body)


func _strip(data: Array, tex: Texture2D) -> MeshInstance2D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data[0]
	arrays[Mesh.ARRAY_TEX_UV] = data[1]
	arrays[Mesh.ARRAY_INDEX] = data[2]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance2D.new()
	node.mesh = mesh
	node.texture = tex
	node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(node)
	return node


## Rides the whole course once at an easy pace, without jumping, to learn how fast
## Spirit is going at each point. Rings are hung where that ride can reach them.
func _measure_nominal() -> void:
	nominal.resize(int((LENGTH + 600.0) / 40.0) + 1)
	nominal.fill(BASE_SPEED)
	var r := _rider_at(START_X, 0.0)
	var target := pace(0.0)
	for i in 6000:
		step(r, TICK, target)
		var slot := int((r.x - START_X) / 40.0)
		if slot >= nominal.size():
			break
		nominal[slot] = r.speed


## The nearest spot at or after x where the ground is close to level.
func _gentle_spot(x: float) -> float:
	var best := x
	var least := INF
	for i in 17:
		var at := x + i * 20.0
		var steep := maxf(absf(slope(at)), absf((ground_y(at + 50.0) - ground_y(at - 50.0)) / 100.0))
		if steep < least:
			least = steep
			best = at
		if steep < 0.08:
			break
	return best


## The top of the jump that peaks over x, as a y position for Spirit's hooves.
func _apex_over(x: float) -> float:
	var best := ground_y(x) - 150.0
	var nearest := INF
	for d in range(100, 340, 10):
		var path := trace(x - d, nominal_speed(x - d), true, pace(0.0))
		var top := Vector2(0.0, INF)
		for p in path:
			if p.y < top.y:
				top = p
		if absf(top.x - x) < nearest:
			nearest = absf(top.x - x)
			best = top.y
	return best


## A ring that needs a jump. It is lowered until a jump from somewhere really reaches it.
func _add_jump_ring(x: float, height: float) -> void:
	var h := height
	while h > 50.0:
		var y := ground_y(x) - RIDER_HEIGHT - h
		for d in range(60, 460, 20):
			var path := trace(x - d, nominal_speed(x - d), true, pace(0.0))
			if absf(path_y_at(path, x) - RIDER_HEIGHT - y) <= RING_AIM:
				_add_ring(x, y)
				return
		h -= 15.0
	_add_ring(x, ground_y(x) - RIDER_HEIGHT - 4.0)


func _sprite(art: String, x: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/props/%s.png" % art)
	sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	sprite.offset = Vector2(0.0, -sprite.texture.get_size().y / 2.0)  # stands on its bottom edge
	sprite.position = Vector2(x, ground_y(x) + 4.0)
	add_child(sprite)
	return sprite


## A piece of a picture, placed so the whole picture would stand on the ground at (0, 0).
func _cut(tex: Texture2D, region: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	sprite.position = _art_point(tex, region.get_center())
	sprite.z_index = 2  # in front of Spirit
	return sprite


func _art_point(tex: Texture2D, p: Vector2) -> Vector2:
	var size := tex.get_size()
	return Vector2((p.x - size.x / 2.0) * ART_SCALE, (p.y - size.y) * ART_SCALE + 4.0)


func _add_obstacle(kind: String, x: float) -> void:
	var root := Node2D.new()
	root.position = Vector2(x, ground_y(x))
	root.rotation = atan(slope(x))
	add_child(root)
	var tex: Texture2D = load("res://art/props/%s.png" % kind)
	var index := items.size()
	var pieces: Array = []
	match kind:
		"fence":
			# The posts and flower box stand still. Each rail can be knocked off.
			for region in FENCE_STILL:
				root.add_child(_cut(tex, region))
			for region in FENCE_RAILS:
				var shape := RectangleShape2D.new()
				shape.size = Vector2(74.0, 6.0)
				pieces.append(_piece(root, index, tex, region, region.get_center(), shape, 1.0, 0.35))
		"bale":
			var shape := CircleShape2D.new()
			shape.radius = 27.0
			var bale := _piece(root, index, tex, Rect2(Vector2.ZERO, tex.get_size()), Vector2(74.0, 70.0), shape, 2.5, 0.3)
			bale.angular_damp = 0.9
			pieces.append(bale)
		"log":
			var shape := RectangleShape2D.new()
			shape.size = Vector2(92.0, 22.0)
			pieces.append(_piece(root, index, tex, Rect2(Vector2.ZERO, tex.get_size()), Vector2(118.0, 60.0), shape, 4.0, 0.2))
	items.append({ "kind": kind, "x": x, "node": root, "pieces": pieces, "done": false, "hit": false })


## A rigid body that waits, perfectly still, until Spirit touches it.
func _piece(root: Node2D, index: int, tex: Texture2D, region: Rect2, centre: Vector2, shape: Shape2D, weight: float, bounce: float) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.position = _art_point(tex, centre)
	body.collision_layer = PIECES
	body.collision_mask = 1 | PIECES
	body.mass = weight
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	var material := PhysicsMaterial.new()
	material.friction = 0.7
	material.bounce = bounce
	body.physics_material_override = material
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	var sprite := _cut(tex, region)
	sprite.position = (region.get_center() - centre) * ART_SCALE
	body.add_child(sprite)
	body.set_meta("item", index)
	root.add_child(body)
	return body


func _add_ring(x: float, y: float) -> void:
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
		half.position = Vector2(x + (i - 0.5) * size.x / 2.0 * ART_SCALE, y)
		half.z_index = 0 if i == 0 else 2
		add_child(half)
		halves.append(half)
	rings_total += 1
	items.append({ "kind": "ring", "x": x, "y": y, "nodes": halves, "done": false })


# --- Riding ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not active:
		return
	_place_shadow()
	_run_rivals(delta)
	_crowd_frame(delta)
	boost_time = maxf(boost_time - delta, 0.0)
	rider.kick = 2.4 if boost_time > 0.0 else 1.0
	if not finished:
		boost = minf(boost + 0.018 * delta, 1.0)
		if boost_time > 0.0 and rider.grounded and int(run_time * 14.0) != int((run_time + delta) * 14.0):
			_dust(Vector2(rider.x - 50.0, rider.y), 0.7)
	if rider.impact > 0.0:
		_dust(Vector2(rider.x, rider.y), clampf(rider.impact / 500.0, 0.4, 1.4))
		game.sound.play("land", clampf(-14.0 + rider.impact / 60.0, -14.0, -2.0), 0.08)
		flight = 0.0
	if not rider.grounded and not finished:
		# A long flight, off a ledge or a big jump, earns a whoop.
		flight += delta
		if flight > 0.75 and flight - delta <= 0.75:
			game.sound.shout("adeline", "woohoo", 0.7)
	if finished:
		finish_time += delta
		return
	run_time += delta
	if not rider.grounded:
		air_time += delta
	var px := rider.x
	for item in items:
		if item["done"]:
			continue
		var ix: float = item["x"]
		if item["kind"] == "ring":
			# If any part of Spirit and Adeline goes through the ring, it counts. So the ring is
			# checked the whole time she is passing it, not at one instant, and it is given the
			# moment she lines up with it.
			if px >= ix - RING_REACH:
				if absf(rider.y - RIDER_HEIGHT - float(item["y"])) <= RING_OPENING:
					item["done"] = true
					_collect(item)
				elif px > ix + RING_REACH:
					item["done"] = true
					streak = 0
		elif px > ix + 130.0:
			item["done"] = true
			jumps_clean += 1
			boost = minf(boost + 0.09, 1.0)
	# Things left far behind are tidied away.
	for item in items:
		if item.has("node") and item["node"] != null and px > float(item["x"]) + 1700.0:
			item["node"].queue_free()
			item["node"] = null
	last_x = px
	if px >= finish_x:
		_finish()


## Called when Spirit's legs touch something that can be knocked over.
func on_touch(body: Node) -> void:
	if not active or finished or not body.has_meta("item"):
		return
	var item: Dictionary = items[int(body.get_meta("item"))]
	if not item["hit"]:
		item["hit"] = true
		item["done"] = true
		_stumble()
	# The physics engine is in the middle of its own step right now, so the shove waits a moment.
	_knock.call_deferred(body, Vector2(rider.vx, rider.vy))


## Lets a piece go and shoves it with Spirit's own speed. From here on it is on its own:
## gravity, bounces, rolling and bumping into its neighbours are all the physics engine's work.
func _knock(body: RigidBody2D, hit: Vector2) -> void:
	if not is_instance_valid(body) or not body.freeze:
		return
	body.freeze = false
	var shove := hit * randf_range(0.8, 1.0) + Vector2(0.0, -randf_range(140.0, 260.0))
	# Pushing a little off-centre is what sets it spinning.
	body.apply_impulse(shove * body.mass, Vector2(randf_range(-14.0, 14.0), randf_range(2.0, 10.0)))
	if body.get_child(0).shape is CircleShape2D:
		body.angular_velocity = hit.x / 27.0 * 0.7  # a bale starts off rolling
		game.sound.play("thump", -3.0, 0.1)
	else:
		game.sound.play("clatter", -4.0, 0.12, 1.0, 0.12)
	_dust(body.global_position, 0.8)


func _stumble() -> void:
	stumbles += 1
	# Spirit gives up part of her speed to whatever she hit, then has to build it back.
	rider.speed *= KNOCK_KEEPS
	rider.vx *= KNOCK_KEEPS + 0.15
	var rig = game.horse.rig
	rig.modulate = Color(1.7, 0.75, 0.75)
	rig.create_tween().tween_property(rig, "modulate", Color.WHITE, 0.45)
	game.sound.shout("adeline", "whoa", 1.0, true)
	game.sound.play("snort", -3.0)


func _place_shadow() -> void:
	if shadow == null:
		return
	var gy := ground_y(rider.x)
	var lift := clampf((gy - rider.y) / 240.0, 0.0, 1.0)
	shadow.position = Vector2(rider.x, gy + 3.0)
	shadow.rotation = atan(slope(rider.x))
	shadow.scale = Vector2(3.4, 0.62) * lerpf(1.0, 0.5, lift)
	shadow.modulate.a = lerpf(0.6, 0.25, lift)


func _burst(at: Vector2, amount: int, life: float) -> CPUParticles2D:
	var burst := CPUParticles2D.new()
	burst.texture = game.spark
	burst.position = at
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = amount
	burst.lifetime = life
	burst.scale_amount_curve = game.shrink
	burst.z_index = 3
	burst.emitting = true
	add_child(burst)
	get_tree().create_timer(life + 0.3).timeout.connect(burst.queue_free)
	return burst


func _dust(at: Vector2, strength: float) -> void:
	var puff := _burst(at, int(10.0 * strength) + 4, 0.5)
	puff.direction = Vector2(0.0, -1.0)
	puff.spread = 75.0
	puff.initial_velocity_min = 40.0 * strength
	puff.initial_velocity_max = 150.0 * strength
	puff.gravity = Vector2(0.0, 160.0)
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 1.1
	puff.color = Color(0.86, 0.78, 0.6, 0.55)
	puff.z_index = 1


func _collect(item: Dictionary) -> void:
	rings_got += 1
	boost = minf(boost + 0.12, 1.0)
	# Each ring in a row rings a little higher.
	game.sound.play("chime", -4.0, 0.0, 1.0 + 0.06 * minf(streak, 8.0), 0.0)
	streak += 1
	for half in item["nodes"]:
		var tween: Tween = half.create_tween()
		tween.set_parallel(true)
		tween.tween_property(half, "modulate", Color(2.0, 2.0, 1.4, 0.0), 0.3)
		tween.tween_property(half, "position:y", half.position.y - 30.0, 0.3)
	var sparkle := _burst(Vector2(float(item["x"]), float(item["y"])), 22, 0.55)
	sparkle.material = game.additive
	sparkle.spread = 180.0
	sparkle.initial_velocity_min = 80.0
	sparkle.initial_velocity_max = 240.0
	sparkle.gravity = Vector2(0.0, 220.0)
	sparkle.scale_amount_min = 0.3
	sparkle.scale_amount_max = 0.7
	sparkle.color = Color(1.0, 0.85, 0.3)


func _finish() -> void:
	finished = true
	finish_time = 0.0
	var share := float(rings_got) / maxf(1.0, float(rings_total))
	stars = 1
	if share >= 0.5 and stumbles <= 3:
		stars = 2
	if share >= 0.85 and stumbles <= 1:
		stars = 3
	if racing:
		# In a race the stars are for where she came.
		place = rivals_home + 1
		stars = 3 if place == 1 else (2 if place == 2 else 1)
		game.sound.play("crowd_big", -5.0, 0.0)
	game.on_ride_finished(course, stars)
