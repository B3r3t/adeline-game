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

# Parts that bend along their length, like cloth or hair, and do not swing as one stiff
# board. Each is drawn as a row of strips, and every strip turns a little more than the one
# before it, so the tip trails and curls. "root" is how much of the swing the whole part
# makes at its joint, "curl" how much more the tip makes, "flutter" how much it ripples.
# A rig's owner can add to `bends` before build(): a horse bends its neck this way.
const SOFT := {
	"cloak_back": { "strips": 7, "root": 0.5, "curl": 1.0, "flutter": 1.0 },
	"ponytail": { "strips": 6, "root": 0.45, "curl": 1.2, "flutter": 1.3 },
	"tail": { "strips": 7, "root": 0.45, "curl": 1.1, "flutter": 0.8 },
}
var bends := {}  # part -> how it bends; filled from SOFT, plus whatever the owner adds
var clock := 0.0

var smooth := true
var sharp := {}  # parts to put exactly on their angle this tick, for quick strikes
var live := {}  # name -> the angle each part is at now
var rate := {}  # name -> how fast it is turning
var moved := false
var last_pos := Vector2.ZERO
var last_side := 1.0
var speed_x := 0.0
var wind := 0.0  # how hard the air is pulling at soft parts, from how fast the rig is moving


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
	for part in SOFT:
		if not bends.has(part):
			bends[part] = SOFT[part]
	for p in by_depth:
		var tex: Texture2D = load(dir + "/" + str(p["name"]) + ".png")
		var pivot := Vector2(p["pivot"][0], p["pivot"][1])
		var node: Node2D
		if bends.has(p["name"]):
			node = _strips(tex, bends[p["name"]], pivot)
			info[p["name"]]["shape"] = (node as Polygon2D).polygon
		else:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = false
			sprite.offset = -pivot
			node = sprite
		node.scale = Vector2(tex_scale, tex_scale)
		add_child(node)
		info[p["name"]]["sprite"] = node
	snap()


## A picture cut into strips that can each be turned on their own. Hanging parts are cut
## across (strips stacked downward from the joint); a part with "across" set is cut the
## other way (strips side by side), for a horse's neck.
func _strips(tex: Texture2D, how: Dictionary, pivot: Vector2) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.texture = tex
	poly.offset = -pivot
	var size := tex.get_size()
	var n := int(how["strips"])
	var sideways: bool = how.get("across", false)
	var points := PackedVector2Array()
	var quads := []
	for i in n + 1:
		var k := float(i) / n
		if sideways:
			points.append(Vector2(size.x * k, 0.0))
			points.append(Vector2(size.x * k, size.y))
		else:
			points.append(Vector2(0.0, size.y * k))
			points.append(Vector2(size.x, size.y * k))
		if i > 0:
			quads.append(PackedInt32Array([i * 2 - 2, i * 2 - 1, i * 2 + 1, i * 2]))
	poly.polygon = points
	poly.uv = points
	poly.polygons = quads
	return poly


## Gives a part a different picture: another hairstyle, say. `soft` scales how much it
## bends and ripples, for pictures that should hold their shape (a bun).
func swap(part: String, tex: Texture2D, pivot: Vector2, pos: Vector2, soft := 1.0) -> void:
	var d: Dictionary = info[part]
	d["pos"] = pos
	d["pivot"] = pivot
	d["soft"] = soft
	var node = d["sprite"]
	node.texture = tex
	node.offset = -pivot
	if node is Polygon2D:
		var fresh := _strips(tex, bends[part], pivot)
		node.polygon = fresh.polygon
		node.uv = fresh.uv
		node.polygons = fresh.polygons
		d["shape"] = fresh.polygon
		fresh.free()


## Bends a soft part: each strip is turned about the bend's centre by its share of `turn`
## (degrees), plus a ripple that runs down it.
func _bend(part: String, turn: float, ripple: float) -> void:
	var how: Dictionary = bends[part]
	var d: Dictionary = info[part]
	var poly: Polygon2D = d["sprite"]
	var shape: PackedVector2Array = d["shape"]
	var size := poly.texture.get_size()
	var sideways: bool = how.get("across", false)
	var pivot: Vector2 = d["pivot"]
	var centre: Vector2 = pivot
	var from: float = pivot.x / size.x if sideways else pivot.y / size.y
	var to := 1.0
	if how.has("at"):
		centre = (how["at"] as Vector2) * size
		from = float(how["from"])
		to = float(how["to"])
	var points := PackedVector2Array()
	points.resize(shape.size())
	for i in shape.size():
		var p := shape[i]
		var along := (p.x / size.x) if sideways else (p.y / size.y)
		var share := clampf((along - from) / maxf(to - from, 0.001), 0.0, 1.0)
		var angle := deg_to_rad(turn * (smoothstep(0.0, 1.0, share) if how.has("at") else pow(share, 1.3)))
		if ripple != 0.0:
			angle += deg_to_rad(ripple * share * sin(clock * (4.0 + 7.0 * wind) - share * 3.1 + float(i / 2) * 0.2))
		points[i] = centre + (p - centre).rotated(angle)
	poly.polygon = points
	d["turn"] = turn


## Where a spot on a part's picture is right now, bending included. In the rig's own space.
func point(part: String, pixel: Vector2) -> Vector2:
	var d: Dictionary = info[part]
	var node: Node2D = d["sprite"]
	var at := pixel
	if bends.has(part) and bends[part].has("at"):
		var how: Dictionary = bends[part]
		var size: Vector2 = (node as Polygon2D).texture.get_size()
		var centre: Vector2 = (how["at"] as Vector2) * size
		var share := clampf((pixel.x / size.x - float(how["from"])) / maxf(float(how["to"]) - float(how["from"]), 0.001), 0.0, 1.0)
		at = centre + (pixel - centre).rotated(deg_to_rad(float(d.get("turn", 0.0)) * smoothstep(0.0, 1.0, share)))
	return node.position + ((at - (d["pivot"] as Vector2)) * tex_scale).rotated(node.rotation)


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
	clock += delta
	var throw := _throw(delta)
	wind = lerpf(wind, clampf(absf(speed_x) / 320.0, 0.0, 1.6), minf(delta * 5.0, 1.0))
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
		if bends.has(part) and not bends[part].has("at"):
			# A soft part: a share of the swing at the joint, the rest as a curl toward the tip.
			var how: Dictionary = bends[part]
			var soft := float(d.get("soft", 1.0))
			_bend(part, now * float(how["curl"]) * soft, float(how["flutter"]) * (1.4 + 6.0 * wind) * soft)
			now *= float(how["root"])
		elif bends.has(part):
			# A part with a bending place of its own (a neck), asked for by name in the pose.
			var want_neck := float(pose.get(str(bends[part]["pose"]), 0.0))
			var key := str(bends[part]["pose"])
			var neck := want_neck
			if smooth and live.has(key) and delta > 0.0:
				neck = lerpf(float(live[key]), want_neck, minf(delta * 14.0, 1.0))
			live[key] = neck
			_bend(part, neck, 0.0)
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
		var sprite: Node2D = d["sprite"]
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
	(info[part]["sprite"] as CanvasItem).modulate = color


## Hides every part whose name does not start with the given text.
func show_only(prefix: String) -> void:
	for part in order:
		(info[part]["sprite"] as CanvasItem).visible = str(part).begins_with(prefix)
