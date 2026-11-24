extends Node2D
## Adeline's little sister, who rides her pony about near home. Nobody plays her: she trots
## up and down the meadow, stops for a rest now and then, and calls hello when Adeline is near.
##
## Until she has drawings of her own, she and her pony are Adeline's and Spirit's drawings
## made small and recoloured: a cream pony, and a yellow cloak in place of the purple one.

const RigScript := preload("res://scripts/rig.gd")
const HorseScript := preload("res://scripts/horse.gd")

const PONY_SIZE := 0.58
const GIRL_SIZE := 0.64
const LEFT := 330.0  # she stays between the house and the signpost
const RIGHT := 1660.0
const TROT := 210.0

# Turns the purple of the cloak another colour and leaves everything else alone.
const CLOAK_SHADER := "
shader_type canvas_item;
uniform float shift = 0.4;
vec3 to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 0.0001)), d / (q.x + 0.0001), q.x);
}
vec3 to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 h = to_hsv(c.rgb);
	float purple = smoothstep(0.66, 0.71, h.x) * (1.0 - smoothstep(0.86, 0.92, h.x)) * smoothstep(0.2, 0.35, h.y);
	h.x = fract(h.x + shift * purple);
	h.z = mix(h.z, min(h.z * 1.6, 1.0), purple);
	c.rgb = to_rgb(h);
	COLOR = c;
}
"

var game = null
var pony = null
var girl = null
var who := { "position": Vector2.ZERO, "velocity": Vector2.ZERO, "air": false, "pitch": 0.0, "facing": 1 }
var x := 1250.0
var facing := -1
var speed := 0.0
var goal := 700.0
var rest := 1.5  # seconds left of standing still
var hello := 6.0  # seconds until she may call out again
var hop := 0.0
var clock := 0.0


func _ready() -> void:
	pony = Node2D.new()
	pony.set_script(HorseScript)
	pony.game = game
	pony.wild = true
	pony.subject = who
	add_child(pony)
	pony.state = "mounted"
	pony.scale = Vector2(PONY_SIZE, PONY_SIZE)
	pony.set_coat(0.75, Color(1.0, 0.96, 0.86), 2.9)

	girl = Node2D.new()
	girl.set_script(RigScript)
	add_child(girl)
	girl.build("res://art/adeline")
	var shader := Shader.new()
	shader.code = CLOAK_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	for part in girl.info:
		girl.info[part]["sprite"].material = material
	# Her far leg is on the other side of the pony.
	for part in ["leg_far_upper", "leg_far_lower"]:
		girl.info[part]["sprite"].visible = false


func _physics_process(delta: float) -> void:
	clock += delta
	hello = maxf(hello - delta, 0.0)
	hop = maxf(hop - delta, 0.0)
	var want := 0.0
	if rest > 0.0:
		rest -= delta
		if rest <= 0.0:
			# Off again, to somewhere a fair way from here.
			goal = randf_range(LEFT, RIGHT)
			if absf(goal - x) < 320.0:
				goal = LEFT if x > (LEFT + RIGHT) / 2.0 else RIGHT
			if game.mode == "play" and absf(game.player.position.x - x) < 700.0:
				game.sound.shout("sister", "sister_whee", 0.4)
	elif absf(goal - x) < 12.0:
		rest = randf_range(2.0, 5.0)
	else:
		facing = 1 if goal > x else -1
		want = TROT
	speed = move_toward(speed, want, 420.0 * delta)
	x += facing * speed * delta

	# A hello for Adeline when she comes close.
	if game.mode == "play" and hello <= 0.0 and absf(game.player.position.x - x) < 190.0 and not game.dialog.active:
		hello = 28.0
		hop = 0.6
		game.sound.shout("sister", "sister_hello", 1.0, true)

	var lift := -absf(sin(hop * 10.5)) * 10.0 if hop > 0.0 else 0.0
	who["position"] = Vector2(x, game.GROUND_Y + lift)
	who["velocity"] = Vector2(facing * speed, 0.0)
	who["facing"] = facing
	pony.carry(delta)

	var seat: Vector2 = pony.seat()
	var pace := clampf(speed / TROT, 0.0, 1.0)
	var sway := sin(clock * 2.4)
	girl.position = Vector2(x + seat.x * facing * PONY_SIZE, game.GROUND_Y + lift + seat.y * PONY_SIZE)
	girl.scale = Vector2(GIRL_SIZE * facing, GIRL_SIZE)
	girl.pose = {
		"leg_near_upper": -55.0, "leg_near_lower": 60.0,
		"arm_upper": -14.0 if hop <= 0.0 else -150.0, "arm_lower": 8.0,  # an arm up to wave
		"torso": 3.0 + pace * 4.0, "cloak_back": 4.0 + pace * 18.0 + sway * 3.0, "ponytail": pace * 16.0 + sway * 3.0,
	}
	girl.root_offset = -girl.rest_pos("torso") + Vector2(0.0, sin(pony.stride * 2.0) * 1.5 * pace)
	girl.apply()
