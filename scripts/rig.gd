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
	apply()


func apply() -> void:
	var placed := {}  # name -> [position, angle]
	for part in order:
		var d: Dictionary = info[part]
		var own := deg_to_rad(float(pose.get(part, 0.0)))
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
