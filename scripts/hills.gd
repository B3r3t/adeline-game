extends Node2D
## One band of rolling hills, drawn as a single filled shape. Used for the parallax backdrop.

var color := Color.WHITE
var base_y := 560.0
var amplitude := 80.0
var wavelength := 600.0
var phase := 0.0


func _draw() -> void:
	var pts := PackedVector2Array()
	var x := -2000.0
	pts.append(Vector2(x, base_y + 700.0))
	while x <= 6000.0:
		var wave := 0.5 + 0.5 * sin(x / wavelength * TAU + phase)
		pts.append(Vector2(x, base_y - amplitude * wave))
		x += 40.0
	pts.append(Vector2(6000.0, base_y + 700.0))
	draw_colored_polygon(pts, color)
