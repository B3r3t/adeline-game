extends Node2D
## A character assembled from cutout parts, like a paper puppet.
## The parts and their joints come from a rig file made by art_src/build_rig.py.
## Set angles in `pose` (degrees, by part name), then call apply().

var order: Array = []  # part names, parents before children
var info := {}  # name -> { parent, pos, sprite }
var pose := {}  # name -> degrees
var root_offset := Vector2.ZERO
var root_angle := 0.0
var tex_scale := 1.0

# How quickly parts ease to a new angle (higher is quicker), and how loose parts swing:
# [speed, how soon the bounce dies away].
const QUICK := 55.0  # legs
const QUICK_ARM := 60.0
const STEADY := 30.0  # body and head
const LOOSE := { "cloak_back": [9.0, 0.4], "ponytail": [12.0, 0.32], "hood": [15.0, 0.5], "tail": [8.0, 0.42] }

var smooth := true
var sharp := {}  # parts to put exactly on their angle this tick, for quick strikes
var live := {}  # name -> the angle each part is at now
var rate := {}  # name -> how fast it is turning
var moved := false
var last_pos := Vector2.ZERO
var last_side := 1.0
var speed_x := 0.0


func build(dir: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(dir + "/rig.json"))
	tex_scale = float(data["tex_scale"])
	var list: Array = data["parts"]
	for p in list:
		order.append(p["name"])
		info[p["name"]] = {
			"parent": p["parent"],
			"pos": Vector2(p["pos"][0], p["pos"][1]),
			"pivot": Vector2(p["pivot"][0], p["pivot"][1]),
		}
	# Sprites are added back to front, so the draw order matches the rig file.
	var by_depth := list.duplicate()
	by_depth.sort_custom(func(a, b): return a["z"] < b["z"])
	for p in by_depth:
		var sprite := Sprite2D.new()
		sprite.texture = load(dir + "/" + str(p["name"]) + ".png")
		sprite.centered = false
		sprite.offset = -Vector2(p["pivot"][0], p["pivot"][1])
		sprite.scale = Vector2(tex_scale, tex_scale)
		add_child(sprite)
		info[p["name"]]["sprite"] = sprite
	snap()


## Moves every part toward the angle asked for in `pose`.
##
## Parts do not jump to a new angle. Each one eases there, so a change of pose (standing to
## running, running to jumping) blends over a few frames. Loose parts (a cloak, a ponytail,
## a tail) are on a soft spring instead: they lag behind, overshoot and settle, and they are
## thrown back or forward when the character speeds up or stops.
func apply(delta := -1.0) -> void:
	if delta < 0.0:
		delta = get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()
	delta = clampf(delta, 0.0, 0.05)
	var throw := _throw(delta)
	var placed := {}  # name -> [position, angle]
	for part in order:
		var d: Dictionary = info[part]
		var want := float(pose.get(part, 0.0))
		if LOOSE.has(part):
			want += throw
		var now := want
		if smooth and live.has(part) and not sharp.has(part) and delta > 0.0:
			now = _ease(part, want, delta)
		else:
			rate[part] = 0.0
		live[part] = now
		var own := deg_to_rad(now)
		var pos: Vector2
		var angle: float
		if d["parent"] == "":
			pos = d["pos"] + root_offset
			angle = own + root_angle
		else:
			var parent: Array = placed[d["parent"]]
			pos = parent[0] + (d["pos"] as Vector2).rotated(parent[1])
			angle = parent[1] + own
		placed[part] = [pos, angle]
		var sprite: Sprite2D = d["sprite"]
		sprite.position = pos
		sprite.rotation = angle
	sharp.clear()


## Puts every part exactly where the pose says, with no easing. For when a character is
## placed somewhere new.
func snap() -> void:
	live.clear()
	rate.clear()
	moved = false
	apply(0.0)


func _ease(part: String, want: float, delta: float) -> float:
	var x: float = live[part]
	var v: float = rate.get(part, 0.0)
	if LOOSE.has(part):
		# A soft, bouncy spring, stepped a few times so it stays steady.
		var w: float = LOOSE[part][0]
		var z: float = LOOSE[part][1]
		var h := delta / 3.0
		for i in 3:
			v += (-2.0 * z * w * v - w * w * (x - want)) * h
			x += v * h
		rate[part] = v
		return x
	# A firm spring with no bounce, worked out exactly so fast swings stay true.
	var w := QUICK_ARM if part.begins_with("arm") else (QUICK if part.contains("leg") else STEADY)
	var gap := x - want
	var fade := exp(-w * delta)
	var push := v + w * gap
	rate[part] = (v - w * push * delta) * fade
	return want + (gap + push * delta) * fade


## How far loose parts are thrown by the character speeding up or slowing down, in degrees.
## Positive is backward. Worked out from how the rig itself has been moving.
func _throw(delta: float) -> float:
	var here := global_position
	var size := maxf(absf(global_scale.y), 0.01)
	var side := 1.0 if global_scale.x >= 0.0 else -1.0
	if not moved or delta <= 0.0 or here.distance_to(last_pos) > 220.0 * size or side != last_side:
		# Just placed, or turned around: start afresh.
		moved = true
		last_pos = here
		last_side = side
		speed_x = 0.0
		return 0.0
	var now := (here.x - last_pos.x) / delta / size * side
	var gain := (now - speed_x) / delta
	last_pos = here
	speed_x = now
	return clampf(gain * 0.006, -28.0, 28.0)


## Where a part's joint sits when the character stands still, relative to its feet.
func rest_pos(part: String) -> Vector2:
	var d: Dictionary = info[part]
	if d["parent"] == "":
		return d["pos"]
	return rest_pos(d["parent"]) + d["pos"]


func tint(part: String, color: Color) -> void:
	(info[part]["sprite"] as Sprite2D).modulate = color


## Hides every part whose name does not start with the given text.
func show_only(prefix: String) -> void:
	for part in order:
		(info[part]["sprite"] as Sprite2D).visible = str(part).begins_with(prefix)
