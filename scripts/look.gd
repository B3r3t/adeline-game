extends RefCounted
## What Adeline and the horses wear from Merlin's shop: the colour of her cloak, the colour
## of Spirit's saddle blanket, a hat for the girls, and something round the horses' necks.
##
## The colours cost no new pictures. A shader picks out the purple of the cloak (or of
## the blanket) and turns it round the colour wheel, leaving everything else alone. The
## hats and neck things are pictures in art/shop, put on the puppets the same way as the
## Christmas hats, and in the same places.
##
## Every puppet that is built asks `dress` to be dressed, and is remembered, so that when
## something is bought or tried on, `refresh` can change everyone who is on the screen.

const Season := preload("res://scripts/season.gd")

const ART := "res://art/shop/"
# How far round the colour wheel, how rich, how bright. These are also in
# art_src/build_shop.py, which makes the pictures the shop shows: keep them the same.
const COLOURS := {
	"purple": [0.0, 1.0, 1.0], "red": [0.215, 1.0, 1.18], "green": [-0.375, 0.92, 1.02],
	"blue": [-0.195, 0.95, 1.22], "pink": [0.145, 0.7, 1.62],
}
const BLANKET_TURN := -0.045  # the blanket's purple is a little pinker than the cloak's
const CLOAK_BAND := Vector2(0.70, 0.86)
const BLANKET_BAND := Vector2(0.76, 0.93)
# A hat: how wide beside the Christmas hat, how far it is pushed along and down, its tilt.
const HATS := {
	"flower_crown": [1.12, Vector2(-1.0, 9.0), -4.0],
	"tiara": [0.86, Vector2(1.0, 3.0), -2.0],
	"cowgirl": [1.48, Vector2(-2.0, 12.0), -2.0],
}
# Something round a horse's neck: how wide beside the Christmas collar.
const NECKS := { "garland": 1.02, "rosette": 0.98, "stars": 1.0 }
const COLLAR_DROP := 74.0  # how tall the Christmas collar is: these hang from where its top is
const GIRLS := ["adeline", "sister"]
const HORSES := ["spirit", "pony", "unicorn"]

const SHADER := "
shader_type canvas_item;
uniform vec2 band = vec2(0.70, 0.86);
uniform float turn = 0.0;
uniform float rich = 1.0;
uniform float bright = 1.0;
vec3 to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 h = to_hsv(c.rgb);
	float pick = smoothstep(band.x, band.x + 0.03, h.x) * (1.0 - smoothstep(band.y - 0.03, band.y, h.x)) * smoothstep(0.18, 0.3, h.y) * smoothstep(0.1, 0.2, h.z);
	vec3 n = vec3(fract(h.x + turn), min(h.y * rich, 1.0), min(h.z * bright, 1.0));
	c.rgb = mix(c.rgb, to_rgb(n), pick);
	COLOR = c;
}
"

## What is worn now. This is the very dictionary kept in the save, so changing it here
## changes what is saved.
static var now := { "cloak": "purple", "blanket": "purple", "hat": "", "neck": "" }
## Something being tried on in the shop. It wins over `now` until it is put back.
static var trial := {}
static var _cloak: ShaderMaterial = null
static var _blanket: ShaderMaterial = null
static var _rigs: Array = []  # every puppet that might wear something: [a weak hold on it, its folder]


## Takes up what the save says is worn.
static func load_from(kept: Dictionary) -> void:
	for slot in ["cloak", "blanket", "hat", "neck"]:
		if not kept.has(slot):
			kept[slot] = "purple" if slot in ["cloak", "blanket"] else ""
	now = kept
	trial = {}
	refresh()


static func wearing(slot: String) -> String:
	return str(trial.get(slot, now.get(slot, "")))


static func _material(band: Vector2) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("band", band)
	return material


static func cloak() -> ShaderMaterial:
	if _cloak == null:
		_cloak = _material(CLOAK_BAND)
		_tune()
	return _cloak


static func blanket() -> ShaderMaterial:
	if _blanket == null:
		_blanket = _material(BLANKET_BAND)
		_tune()
	return _blanket


static func _tune() -> void:
	for pair in [[_cloak, "cloak", 0.0], [_blanket, "blanket", BLANKET_TURN]]:
		var material: ShaderMaterial = pair[0]
		if material == null:
			continue
		var how: Array = COLOURS.get(wearing(str(pair[1])), COLOURS["purple"])
		material.set_shader_parameter("turn", float(how[0]) + (float(pair[2]) if float(how[0]) != 0.0 else 0.0))
		material.set_shader_parameter("rich", float(how[1]))
		material.set_shader_parameter("bright", float(how[2]))


## Dresses a puppet that has just been built. `dir` is the folder its pictures came from.
static func dress(rig, dir: String) -> void:
	var who := dir.get_file()
	if not (who in GIRLS or who in HORSES):
		return
	_rigs.append([weakref(rig), dir])
	_wear(rig, who)


## A horse that is somebody else's (a rival in a race) wears nothing of Spirit's.
static func plain(rig, dir: String) -> void:
	_rigs = _rigs.filter(func(entry): return entry[0].get_ref() != rig)
	_strip(rig)
	Season.dress(rig, dir)


static func _strip(rig) -> void:
	for part in rig.info:
		var on: Node = rig.info[part]["sprite"]
		var old := on.get_node_or_null("Worn")
		if old != null:
			on.remove_child(old)
			old.queue_free()


static func _wear(rig, who: String) -> void:
	if who == "adeline":
		for part in ["cloak_back", "hood"]:
			if rig.info.has(part):
				rig.info[part]["sprite"].material = cloak()
	var slot := "hat" if who in GIRLS else "neck"
	var what := wearing(slot)
	if what == "" or not Season.WEAR.has(who):
		return
	var spec: Array = Season.WEAR[who]  # where the Christmas thing sits on this puppet
	if not rig.info.has(str(spec[1])):
		return
	var part: Dictionary = rig.info[str(spec[1])]
	var on: Node2D = part["sprite"]
	var old := on.get_node_or_null("Worn")
	if old != null:  # a bought hat is worn instead of the Christmas one
		on.remove_child(old)
		old.queue_free()
	var worn := Sprite2D.new()
	worn.name = "Worn"
	worn.texture = load(ART + what + ".png")
	var at: Vector2 = (spec[2] as Vector2) - (part["pivot"] as Vector2)
	var tilt := float(spec[4])
	var k := float(spec[3]) / worn.texture.get_width()
	if slot == "hat":
		var fit: Array = HATS[what]
		k *= float(fit[0])
		at += (fit[1] as Vector2) * (float(spec[3]) / 50.0)
		tilt += float(fit[2])
		worn.offset = Vector2(0.0, -worn.texture.get_height() / 2.0)  # it sits on its bottom edge
	else:
		k *= float(NECKS[what])
		at += Vector2(0.0, -COLLAR_DROP * float(spec[3]) / 96.0).rotated(deg_to_rad(tilt))
		worn.offset = Vector2(0.0, worn.texture.get_height() / 2.0)  # it hangs from its top edge
	worn.scale = Vector2(k, k)
	worn.position = at
	worn.rotation_degrees = tilt
	on.add_child(worn)


## Dresses everybody again, after something was bought, put on, taken off or tried.
static func refresh() -> void:
	_tune()
	var live := []
	for entry in _rigs:
		var rig = entry[0].get_ref()
		if rig == null or not is_instance_valid(rig):
			continue
		live.append(entry)
		_strip(rig)
		Season.dress(rig, str(entry[1]))
		_wear(rig, str(entry[1]).get_file())
	_rigs = live
