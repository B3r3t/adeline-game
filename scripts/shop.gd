extends Control
## Merlin's shop, where stars are spent.
##
## Every game that ends in stars (the riding course, the race, the sky ride, the farm
## games) pays them into a purse as well as keeping the best for that game, so playing
## again always earns something. The purse is spent here, on three shelves:
##   Adeline: the colour of her cloak, and hats (her sister wears the same hat)
##   Spirit:  the colour of the saddle blanket, and things for the horses' necks
##   Home:    furniture, which then appears in the tray of things to place in the house
##
## Tap a thing to look at it: Adeline or Spirit tries it on at once, on the left. The big
## button then buys it, or puts on or takes off a thing already bought. Nothing is ever
## bought by one stray tap. What is owned and worn is kept with the adventure.
##
## The shop is reached from the title screen and from Merlin's list of missions.

const Season := preload("res://scripts/season.gd")
const Ui := preload("res://scripts/ui.gd")
const Look := preload("res://scripts/look.gd")
const RigScript := preload("res://scripts/rig.gd")
const Moves := preload("res://scripts/moves.gd")

const SHELVES := ["Adeline", "Spirit", "Home"]
# id, shelf, what it is ("cloak", "blanket", "hat", "neck" or "home"), the thing itself,
# its name, its price in stars, and for furniture the room it goes in
const ITEMS := [
	["cloak_purple", 0, "cloak", "purple", "Purple cloak", 0, ""],
	["cloak_red", 0, "cloak", "red", "Ruby cloak", 4, ""],
	["cloak_green", 0, "cloak", "green", "Emerald cloak", 4, ""],
	["cloak_blue", 0, "cloak", "blue", "Sapphire cloak", 4, ""],
	["cloak_pink", 0, "cloak", "pink", "Rose cloak", 4, ""],
	["flower_crown", 0, "hat", "flower_crown", "Flower crown", 6, ""],
	["cowgirl", 0, "hat", "cowgirl", "Cowgirl hat", 6, ""],
	["tiara", 0, "hat", "tiara", "Tiara", 8, ""],
	["blanket_purple", 1, "blanket", "purple", "Purple blanket", 0, ""],
	["blanket_red", 1, "blanket", "red", "Ruby blanket", 3, ""],
	["blanket_green", 1, "blanket", "green", "Emerald blanket", 3, ""],
	["blanket_blue", 1, "blanket", "blue", "Sapphire blanket", 3, ""],
	["blanket_pink", 1, "blanket", "pink", "Rose blanket", 3, ""],
	["garland", 1, "neck", "garland", "Flower garland", 6, ""],
	["stars", 1, "neck", "stars", "Star charms", 6, ""],
	["rosette", 1, "neck", "rosette", "First prize", 8, ""],
	["globe", 2, "home", "globe", "Globe", 4, "living"],
	["aquarium", 2, "home", "aquarium", "Fish tank", 5, "living"],
	["piano", 2, "home", "piano", "Piano", 6, "living"],
	["fireplace", 2, "home", "fireplace", "Fireplace", 6, "living"],
	["star_lights", 2, "home", "star_lights", "Star lights", 4, "bedroom"],
	["telescope", 2, "home", "telescope", "Telescope", 5, "bedroom"],
	["plush_unicorn", 2, "home", "plush_unicorn", "Giant unicorn", 5, "bedroom"],
	["dollhouse", 2, "home", "dollhouse", "Dollhouse", 6, "bedroom"],
]
const PANEL_TALL := 594.0

var game = null
var font: Font
var stage: Node2D = null
var overlay: Control = null
var adeline: Node2D = null
var spirit: Node2D = null
var saddle: Sprite2D = null
var shelf := 0
var chosen := -1  # the place in ITEMS of the thing being looked at
var came_from := "title"
var age := 0.0
var clock := 0.0
var twirl := 0.0  # Adeline hops and turns when she tries something on
var shake := 0.0  # the button shakes its head when there are not enough stars
var purse_pop := 0.0
var said := ""
var said_time := 0.0
var sparks: Array = []  # [where, which way, age]
var icons := {}
var backdrop: Texture2D = null  # kept here: a picture nobody holds is let go before it is drawn
var keeper: Texture2D = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	visible = false
	stage = Node2D.new()
	add_child(stage)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_ui)
	add_child(overlay)


# --- What is owned --------------------------------------------------------------------

func purse() -> int:
	return int(game.data.get("purse", 0))


func owned(i: int) -> bool:
	return int(ITEMS[i][5]) == 0 or str(ITEMS[i][0]) in (game.data["owned"] as Array)


## The furniture bought for a room, by name, for the house's tray.
func furniture(room: String) -> Array:
	var out: Array = []
	for i in ITEMS.size():
		if str(ITEMS[i][2]) == "home" and str(ITEMS[i][6]) == room and owned(i):
			out.append(str(ITEMS[i][3]))
	return out


func worn(i: int) -> bool:
	var slot := str(ITEMS[i][2])
	return slot != "home" and str(Look.now.get(slot, "")) == str(ITEMS[i][3])


func on_shelf(n: int) -> Array:
	var out: Array = []
	for i in ITEMS.size():
		if int(ITEMS[i][1]) == n:
			out.append(i)
	return out


## How many things are still to be bought, for the title screen.
func left_to_buy() -> int:
	var n := 0
	for i in ITEMS.size():
		if not owned(i):
			n += 1
	return n


# --- Coming and going -----------------------------------------------------------------

func open() -> void:
	came_from = "title" if game.mode == "title" else "play"
	game.controls.release_all()
	game.mode = "shop"
	visible = true
	age = 0.0
	shelf = 0
	chosen = -1
	sparks.clear()
	backdrop = Season.tex("res://art/mini/hut.jpg")
	keeper = load("res://art/props/merlin.png")
	_build()
	_layout()
	_say("Welcome! Stars are money here.")
	game.sound.play("chime", -8.0)
	game.sound.shout("merlin", "merlin_shop", 1.0, true)


func close() -> void:
	if game.mode != "shop":
		return
	Look.trial = {}
	Look.refresh()
	for node in [adeline, spirit]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	adeline = null
	spirit = null
	saddle = null
	visible = false
	if came_from == "title":
		game.mode = "title"
	else:
		game.mode = "play"


func _build() -> void:
	adeline = Node2D.new()
	adeline.set_script(RigScript)
	stage.add_child(adeline)
	adeline.build("res://art/adeline")
	spirit = Node2D.new()
	spirit.set_script(RigScript)
	stage.add_child(spirit)
	spirit.build("res://art/spirit")
	for part in ["leg_front_far_upper", "leg_front_far_lower", "leg_hind_far_upper", "leg_hind_far_lower"]:
		spirit.tint(part, Color(0.72, 0.72, 0.78))
	# The saddle is a layer laid exactly over the body, so it rides on the body picture.
	var body = spirit.info["body"]["sprite"]
	saddle = Sprite2D.new()
	saddle.texture = load("res://art/spirit/saddle.png")
	saddle.centered = false
	saddle.offset = body.offset
	saddle.material = Look.blanket()
	body.add_child(saddle)


func _layout() -> void:
	if adeline == null:
		return
	var s := get_viewport_rect().size
	var floor_y := minf(s.y - 96.0, panel().end.y - 40.0)
	adeline.position = Vector2(panel().position.x * 0.58, floor_y)
	spirit.position = Vector2(panel().position.x * 0.66, floor_y)


func _say(text: String) -> void:
	said = text
	said_time = 0.0


# --- Where things are on the screen ---------------------------------------------------

func back_rect() -> Rect2:
	return Rect2(36.0, 30.0, 150.0, 54.0)


func panel() -> Rect2:
	var s := get_viewport_rect().size
	var top := maxf(96.0, (s.y - PANEL_TALL) / 2.0 + 30.0)
	return Rect2(s.x * 0.385, top, s.x * 0.615 - 36.0, PANEL_TALL)


func shelf_rect(n: int) -> Rect2:
	var p := panel()
	var wide := (p.size.x - 40.0 - 20.0) / 3.0
	return Rect2(p.position.x + 20.0 + n * (wide + 10.0), p.position.y + 16.0, wide, 50.0)


## The card for the n-th thing on the shelf being shown: four across, two down.
func card_rect(n: int) -> Rect2:
	var p := panel()
	var wide := (p.size.x - 40.0 - 30.0) / 4.0
	return Rect2(p.position.x + 20.0 + (n % 4) * (wide + 10.0), p.position.y + 80.0 + (n / 4) * 186.0, wide, 176.0)


func buy_rect() -> Rect2:
	var p := panel()
	return Rect2(p.end.x - 20.0 - 320.0, p.end.y - 84.0, 320.0, 64.0)


func purse_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x - 36.0 - 150.0, 30.0, 150.0, 54.0)


# --- Taps -----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if game == null or game.mode != "shop" or game.menu != "":
		return
	if not (event is InputEventScreenTouch) or not event.pressed or age < 0.35:
		return
	get_viewport().set_input_as_handled()
	var pos: Vector2 = event.position
	if back_rect().has_point(pos):
		game.sound.play("pop", -8.0, 0.0, 0.9)
		var to_title := came_from == "title"
		close()
		if to_title:
			game.go_title()
		return
	for n in SHELVES.size():
		if shelf_rect(n).has_point(pos) and n != shelf:
			shelf = n
			_choose(-1)
			game.sound.play("pop", -8.0, 0.0, 1.1)
			return
	var here := on_shelf(shelf)
	for n in here.size():
		if card_rect(n).has_point(pos):
			_choose(int(here[n]))
			game.sound.play("pop", -8.0, 0.0, 1.25)
			return
	if chosen >= 0 and buy_rect().has_point(pos):
		_press_button()


## Looks at a thing: it is tried on, but not bought and not kept on.
func _choose(i: int) -> void:
	chosen = i
	Look.trial = {}
	if i >= 0 and str(ITEMS[i][2]) != "home":
		Look.trial = { str(ITEMS[i][2]): str(ITEMS[i][3]) }
		twirl = 0.7
	Look.refresh()
	if i >= 0:
		_say(_line_for(i))


func _line_for(i: int) -> String:
	var slot := str(ITEMS[i][2])
	if not owned(i):
		if purse() < int(ITEMS[i][5]):
			return "That one is %d stars. Win %d more!" % [int(ITEMS[i][5]), int(ITEMS[i][5]) - purse()]
		return "Try it on. It is yours for %d stars." % int(ITEMS[i][5]) if slot != "home" else "For the %s. %d stars." % ["living room" if str(ITEMS[i][6]) == "living" else "bedroom", int(ITEMS[i][5])]
	if slot == "home":
		return "It is waiting in the %s at home." % ("living room" if str(ITEMS[i][6]) == "living" else "bedroom")
	return "You are wearing it." if worn(i) else "It is yours. Put it on!"


## What the big button says about the thing being looked at, and whether it can be pressed.
func button_for(i: int) -> Array:
	var slot := str(ITEMS[i][2])
	var price := int(ITEMS[i][5])
	if not owned(i):
		if purse() < price:
			return ["%d more stars to go" % (price - purse()), false]
		return ["Buy for %d" % price, true]
	if slot == "home":
		return ["It is at home", false]
	if worn(i):
		return ["Take it off", true] if slot in ["hat", "neck"] else ["Wearing it", false]
	return ["Put it on", true]


func _press_button() -> void:
	var i := chosen
	var slot := str(ITEMS[i][2])
	var how := button_for(i)
	if not bool(how[1]):
		if not owned(i):
			shake = 0.5
			game.sound.play("thump", -10.0)
			game.sound.shout("merlin", "merlin_more", 1.0)
			_say("Not enough stars yet. Go and win some more!")
		return
	if not owned(i):
		game.data["purse"] = purse() - int(ITEMS[i][5])
		(game.data["owned"] as Array).append(str(ITEMS[i][0]))
		purse_pop = 0.6
		if slot != "home":
			Look.now[slot] = str(ITEMS[i][3])
		_celebrate()
		game.sound.play("fanfare", -7.0, 0.0, 1.1)
		game.sound.shout("merlin", "merlin_sold", 1.0, true)
		_say("A fine choice!" if slot != "home" else "A fine choice! It will be at home.")
	elif worn(i):
		Look.now[slot] = ""
		game.sound.play("pop", -8.0, 0.0, 0.8)
		_say("Off it comes.")
	else:
		Look.now[slot] = str(ITEMS[i][3])
		twirl = 0.7
		game.sound.play("chime", -6.0)
		_say("Oh, that suits you!")
	Look.trial = {}
	Look.refresh()
	game._save()


func _celebrate() -> void:
	twirl = 0.9
	var from := buy_rect().get_center()
	for n in 34:
		sparks.append([from, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(140.0, 520.0) + Vector2(0.0, -260.0), 0.0])


# --- Every frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null:
		return
	visible = game.mode == "shop"
	if not visible or adeline == null:
		return
	age += delta
	clock += delta
	said_time += delta
	twirl = maxf(twirl - delta, 0.0)
	shake = maxf(shake - delta, 0.0)
	purse_pop = maxf(purse_pop - delta, 0.0)
	for s in sparks:
		s[2] = float(s[2]) + delta
		s[1] = s[1] + Vector2(0.0, 520.0 * delta)
		s[0] = s[0] + s[1] * delta
	sparks = sparks.filter(func(s): return float(s[2]) < 0.9)
	_layout()
	# Who is shown: Adeline on her shelf, Spirit on hers, neither among the furniture.
	adeline.visible = shelf == 0
	spirit.visible = shelf == 1
	var hop := sin(clampf(twirl / 0.7, 0.0, 1.0) * PI)
	var pose: Dictionary = Moves.girl_idle(clock)
	pose.erase("_lift")
	adeline.pose = pose
	adeline.root_offset = Vector2(0.0, -hop * 10.0)
	adeline.apply(delta)
	var turn := -1.0 if (twirl > 0.25 and twirl < 0.5) else 1.0  # a quick look over her shoulder
	adeline.scale = Vector2(3.5 * turn, 3.5)
	spirit.pose = { "tail": sin(clock * 2.0) * 6.0 + hop * 20.0, "body": sin(clock * 1.3) * 1.0 - hop * 3.0 }
	spirit.root_offset = Vector2(0.0, -hop * 6.0)
	spirit.apply()
	spirit.scale = Vector2(1.9, 1.9)
	queue_redraw()
	overlay.queue_redraw()


# --- Drawing --------------------------------------------------------------------------

func _text(on: CanvasItem, pos: Vector2, text: String, text_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	on.draw_string_outline(font, pos, text, align, width, text_size, 6, Color(0.1, 0.08, 0.2, color.a * 0.85))
	on.draw_string(font, pos, text, align, width, text_size, color)


func _icon(i: int) -> Texture2D:
	var id := str(ITEMS[i][0])
	if not icons.has(id):
		icons[id] = load("res://art/room/%s.png" % str(ITEMS[i][3])) if str(ITEMS[i][2]) == "home" else load("res://art/shop/%s.png" % id)
	return icons[id]


func _fit(on: CanvasItem, tex: Texture2D, box: Rect2, tint := Color.WHITE) -> void:
	var k := minf(box.size.x / tex.get_width(), box.size.y / tex.get_height())
	var size := tex.get_size() * k
	on.draw_texture_rect(tex, Rect2(box.get_center() - size / 2.0, size), false, tint)


## Behind everything: the inside of Merlin's hut, and Merlin keeping shop.
func _draw() -> void:
	if game == null or game.mode != "shop":
		return
	var s := get_viewport_rect().size
	var art: Texture2D = backdrop
	var size := art.get_size()
	var k := maxf(s.x / size.x, s.y / size.y)
	var shown := s / k
	draw_texture_rect_region(art, Rect2(Vector2.ZERO, s), Rect2((size.x - shown.x) / 2.0, size.y - shown.y, shown.x, shown.y))
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.04, 0.14, 0.42))
	# A round rug of light for whoever is trying things on.
	var p := panel()
	var spot := Vector2(p.position.x * 0.52, minf(s.y - 96.0, p.end.y - 40.0))
	for ring in 5:
		draw_set_transform(spot, 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, 250.0 - ring * 34.0, Color(1.0, 0.9, 0.55, 0.07))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shelf == 2:
		# Among the furniture: the thing itself, large, turning gently in the light.
		if chosen >= 0:
			var tex := _icon(chosen)
			var bob := sin(clock * 2.0) * 6.0
			var grow := Ui.pop(minf(said_time / 0.3, 1.0))
			var box := Rect2(spot.x - 170.0 * grow, spot.y - 340.0 * grow - 10.0 + bob, 340.0 * grow, 340.0 * grow)
			_fit(self, tex, box)
		else:
			_text(self, Vector2(0.0, spot.y - 150.0), "Tap something to look at it.", 24, Color(1.0, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER, p.position.x)
	# Merlin, by the door.
	var merlin: Texture2D = keeper
	var tall := 230.0
	var wide := merlin.get_width() * tall / merlin.get_height()
	var sway := sin(clock * 1.6) * 0.012
	draw_set_transform(Vector2(74.0, spot.y + 22.0), sway, Vector2.ONE)
	draw_texture_rect(merlin, Rect2(-wide / 2.0, -tall - sin(clock * 3.2) * 2.0, wide, tall), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ui() -> void:
	if game == null or game.mode != "shop":
		return
	var on := overlay
	var s := get_viewport_rect().size
	var p := panel()
	var slide := (1.0 - Ui.ease(age / 0.45)) * (s.x - p.position.x + 40.0)
	on.draw_set_transform(Vector2(slide, 0.0), 0.0, Vector2.ONE)
	Ui.panel(on, p, Color(0.09, 0.11, 0.24, 0.88))
	for n in SHELVES.size():
		var r := shelf_rect(n)
		var lit := n == shelf
		Ui.button(on, font, r, SHELVES[n], 24, Color(0.82, 0.5, 0.14, 0.97) if lit else Color(0.2, 0.24, 0.42, 0.9), Color.WHITE if lit else Color(0.82, 0.85, 0.95))
	var here := on_shelf(shelf)
	for n in here.size():
		var i := int(here[n])
		var r := card_rect(n)
		r.position.y += (1.0 - Ui.pop((age - 0.15 - n * 0.04) / 0.4)) * 60.0
		var picked := i == chosen
		var mine := owned(i)
		Ui.button(on, font, r, "", 18, Color(0.3, 0.36, 0.62, 0.97) if not picked else Color(0.44, 0.34, 0.7, 0.98))
		if picked:
			on.draw_rect(r.grow(3.0), Color(1.0, 0.86, 0.4), false, 4.0)
		_fit(on, _icon(i), Rect2(r.position.x + 14.0, r.position.y + 10.0, r.size.x - 28.0, 98.0))
		_text(on, Vector2(r.position.x, r.position.y + 132.0), str(ITEMS[i][4]), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var foot := Vector2(r.get_center().x, r.end.y - 20.0)
		if worn(i):
			Ui.plate(on, Rect2(foot.x - 54.0, foot.y - 15.0, 108.0, 28.0), Color(0.2, 0.62, 0.34, 0.95))
			_text(on, Vector2(foot.x - 54.0, foot.y + 6.0), "Wearing", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 108.0)
		elif mine:
			_text(on, Vector2(r.position.x, foot.y + 6.0), "Yours", 17, Color(0.7, 1.0, 0.75), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		else:
			var can := purse() >= int(ITEMS[i][5])
			Ui.star(on, Vector2(foot.x - 14.0, foot.y - 1.0), 11.0, can)
			_text(on, Vector2(foot.x + 2.0, foot.y + 7.0), str(int(ITEMS[i][5])), 20, Color(1.0, 0.92, 0.5) if can else Color(0.75, 0.78, 0.9))
	# The foot of the panel: what Merlin says about it, and the button.
	var b := buy_rect()
	_text(on, Vector2(p.position.x + 24.0, b.get_center().y + 8.0), said, 21, Color(1.0, 0.96, 0.8), HORIZONTAL_ALIGNMENT_LEFT, b.position.x - p.position.x - 40.0)
	if chosen >= 0:
		var how := button_for(chosen)
		var live := bool(how[1])
		b.position.x += sin(shake * 40.0) * 8.0 * shake
		var fill := Color(0.26, 0.6, 0.36, 0.98) if live else Color(0.3, 0.32, 0.42, 0.9)
		var label := str(how[0])
		var buying := live and not owned(chosen)
		Ui.button(on, font, b, "" if buying else label, 26, fill, Color.WHITE if live else Color(0.8, 0.82, 0.9))
		if buying:
			# "Buy for", a star, and the price.
			var words := "Buy for"
			var w := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26).x
			var all := w + 16.0 + 30.0 + 8.0 + font.get_string_size(str(int(ITEMS[chosen][5])), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x
			var x := b.get_center().x - all / 2.0
			_text(on, Vector2(x, b.get_center().y + 9.0), words, 26, Color.WHITE)
			Ui.star(on, Vector2(x + w + 16.0 + 15.0, b.get_center().y - 1.0), 15.0, true)
			_text(on, Vector2(x + w + 16.0 + 38.0, b.get_center().y + 10.0), str(int(ITEMS[chosen][5])), 28, Color(1.0, 0.92, 0.5))
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Across the top: the way out, the name over the door, and the purse.
	var head := (1.0 - Ui.ease(age / 0.4)) * -90.0
	Ui.button(on, font, back_rect(), "Back", 22, Color(0.09, 0.11, 0.24, 0.7))
	_text(on, Vector2(0.0, 72.0 + head), "Merlin's shop", 44, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	var pr := purse_rect()
	var swell := 1.0 + sin(purse_pop / 0.6 * PI) * 0.18
	on.draw_set_transform(pr.get_center(), 0.0, Vector2(swell, swell))
	Ui.plate(on, Rect2(-pr.size / 2.0, pr.size), Color(0.09, 0.11, 0.24, 0.8))
	Ui.star(on, Vector2(-38.0, 0.0), 17.0, true)
	_text(on, Vector2(-14.0, 11.0), str(purse()), 30, Color.WHITE)
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for sp in sparks:
		var fade := 1.0 - float(sp[2]) / 0.9
		Ui.star(on, sp[0], 6.0 + 12.0 * fade, true)
