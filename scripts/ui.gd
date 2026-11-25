extends RefCounted
## The look shared by every screen: rounded panels and buttons, drawn the same way
## everywhere so the whole game feels like one thing.

static var boxes := {}  # styles already made, by what they look like


static func _box(fill: Color, edge: Color, radius: float, border: float, shadow: float) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d|%d" % [fill.to_html(), edge.to_html(), int(radius), int(border), int(shadow)]
	if not boxes.has(key):
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = edge
		box.set_border_width_all(int(border))
		box.set_corner_radius_all(int(radius))
		box.corner_detail = 8
		box.anti_aliasing = true
		if shadow > 0.0:
			box.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
			box.shadow_size = int(shadow)
			box.shadow_offset = Vector2(0.0, shadow * 0.5)
		boxes[key] = box
	return boxes[key]


## A dark panel with a golden edge, for messages and menus.
static func panel(on: CanvasItem, r: Rect2, fill := Color(0.09, 0.11, 0.24, 0.9), edge := Color(1.0, 0.86, 0.45, 0.95), radius := 22.0) -> void:
	on.draw_style_box(_box(fill, edge, minf(radius, r.size.y / 2.0), 3.0, 10.0), r)


## A strip behind a line of text, with no edge.
static func plate(on: CanvasItem, r: Rect2, fill := Color(0.09, 0.11, 0.24, 0.72)) -> void:
	on.draw_style_box(_box(fill, Color(0.0, 0.0, 0.0, 0.0), r.size.y / 2.0, 0.0, 0.0), r)


## A button. Solid colours get a darker lip underneath and a soft shine across the top;
## see-through ones (quiet choices) stay flat.
static func button(on: CanvasItem, font: Font, r: Rect2, label: String, size: int, fill: Color, ink := Color.WHITE) -> void:
	var radius := minf(r.size.y * 0.4, 20.0)
	if fill.a >= 0.5:
		var lip := fill.darkened(0.42)
		lip.a = fill.a
		on.draw_style_box(_box(lip, Color(0.0, 0.0, 0.0, 0.0), radius, 0.0, 6.0), Rect2(r.position + Vector2(0.0, 5.0), r.size))
		on.draw_style_box(_box(fill, Color(1.0, 1.0, 1.0, 0.6), radius, 2.0, 0.0), r)
		on.draw_style_box(_box(Color(1.0, 1.0, 1.0, 0.15), Color(0.0, 0.0, 0.0, 0.0), radius * 0.75, 0.0, 0.0), Rect2(r.position + Vector2(5.0, 4.0), Vector2(r.size.x - 10.0, r.size.y * 0.42)))
	else:
		on.draw_style_box(_box(fill, Color(1.0, 1.0, 1.0, 0.7), radius, 2.0, 0.0), r)
	if label != "":
		var y := r.position.y + r.size.y / 2.0 + size * 0.35
		on.draw_string_outline(font, Vector2(r.position.x, y), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, 6, Color(0.0, 0.0, 0.0, 0.5))
		on.draw_string(font, Vector2(r.position.x, y), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, ink)


## How big something that pops in should be, `t` of the way through: nothing, then a
## little over full size, then full size.
static func pop(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	var u := t - 1.0
	return 1.0 + 2.4 * u * u * u + 1.4 * u * u


## Something that slides into place and slows as it arrives: 0 at the start, 1 at rest.
static func ease(t: float) -> float:
	var u := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


## A five-pointed star, lit or not.
static func star(on: CanvasItem, center: Vector2, radius: float, lit: bool) -> void:
	var pts := PackedVector2Array()
	var edge := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var far := radius if i % 2 == 0 else radius * 0.46
		pts.append(center + Vector2(cos(a), sin(a)) * far)
		edge.append(center + Vector2(cos(a), sin(a)) * (far + radius * 0.14))
	if lit:
		on.draw_colored_polygon(edge, Color(0.55, 0.3, 0.05))
		on.draw_colored_polygon(pts, Color(1.0, 0.84, 0.2))
		on.draw_circle(center + Vector2(-radius * 0.2, -radius * 0.22), radius * 0.16, Color(1.0, 1.0, 0.85, 0.9))
	else:
		on.draw_colored_polygon(edge, Color(0.0, 0.0, 0.0, 0.3))
		on.draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, 0.16))


## A heart, full or empty.
static func heart(on: CanvasItem, center: Vector2, size: float, full: bool) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := i / 40.0 * TAU
		pts.append(center + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * size / 17.0)
	var back := PackedVector2Array()
	for p in pts:
		back.append(center + (p - center) * 1.2 + Vector2(0.0, size * 0.04))
	on.draw_colored_polygon(back, Color(0.35, 0.05, 0.1, 0.85) if full else Color(0.0, 0.0, 0.0, 0.3))
	on.draw_colored_polygon(pts, Color(0.95, 0.22, 0.32) if full else Color(1.0, 1.0, 1.0, 0.14))
	if full:
		on.draw_circle(center + Vector2(-size * 0.42, -size * 0.38), size * 0.18, Color(1.0, 0.75, 0.8, 0.9))
