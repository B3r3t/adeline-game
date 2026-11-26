extends RefCounted
## Christmas. From the first of December to the first of January the whole game dresses
## up: snow on the island, lights on the house, hats on heads, a tree in the living room,
## Christmas dinner on the table, carols for music. This script is how everything else
## knows whether it is that time, and where the winter version of a picture is.
##
## The winter pictures live in `art/xmas`, each at the same place under it as the picture
## it stands in for and exactly the same size, so nothing else has to change: ask for a
## picture with `Season.tex(...)` and the right one comes back. A picture with no winter
## version is simply used as it is.
##
## Whether it is Christmas is decided by the tablet's own date, unless the settings say
## otherwise (`mode`): "auto", "on" all year, or "off".

const FROM := [12, 1]  # month and day it starts
const UNTIL := [1, 1]  # and the last day of it
const ROOT := "res://art/"
const WINTER := "res://art/xmas/"

# What everyone wears at Christmas, by the folder their drawings are in: the thing, the
# part of them it goes on, where on that part's picture its bottom middle sits, how wide
# it is there, and its tilt in degrees.
const WEAR := {
	"adeline": ["hat", "head", Vector2(27.0, 15.0), 50.0, -4.0],
	"sister": ["hat", "head", Vector2(32.0, 17.0), 54.0, -4.0],
	"goblin": ["elf_hat", "head", Vector2(44.0, 14.0), 46.0, -6.0],
	"ogre": ["elf_hat", "head", Vector2(66.0, 26.0), 78.0, -6.0],
	"spirit": ["collar", "body", Vector2(214.0, 140.0), 96.0, -34.0],
	"pony": ["collar", "body", Vector2(152.0, 110.0), 72.0, -34.0],
	"unicorn": ["collar", "body", Vector2(212.0, 140.0), 96.0, -34.0],
}

static var mode := "auto"
static var _known := {}
static var _seen := -1  # what the calendar said when the game started: 1 Christmas, 0 not  # picture -> where to find it this season, looked up once


## True while the game should be dressed for Christmas.
static func festive() -> bool:
	if mode == "on":
		return true
	if mode == "off":
		return false
	if _seen < 0:
		look()
	return _seen == 1


## Looks at the calendar. This is done once when the game starts, not every time
## somebody asks, so a game left open past midnight on the last day does not end up half
## in summer and half in snow. It changes over the next time the game is opened.
static func look() -> void:
	var today := Time.get_date_dict_from_system()
	_seen = 1 if in_season(int(today["month"]), int(today["day"])) else 0


## Whether a day of the year falls inside the season, which runs over the new year.
static func in_season(month: int, day: int) -> bool:
	var now := month * 100 + day
	var from := int(FROM[0]) * 100 + int(FROM[1])
	var until := int(UNTIL[0]) * 100 + int(UNTIL[1])
	return now >= from or now <= until


## Where the picture at `path` is to be found today: its winter version if it is Christmas
## and there is one.
static func art(path: String) -> String:
	if not festive() or not path.begins_with(ROOT):
		return path
	if not _known.has(path):
		var winter := WINTER + path.substr(ROOT.length())
		_known[path] = winter if ResourceLoader.exists(winter) else path
	return _known[path]


static func tex(path: String) -> Resource:
	return load(art(path))


## Puts the Christmas hat (or a horse's holly collar) on a puppet that has just been built.
## `dir` is the folder its drawings came from, which says who it is.
static func dress(rig, dir: String) -> void:
	if not festive():
		return
	var who := dir.get_file()
	if who == "rider_baron":
		return  # he keeps his top hat
	if who.begins_with("rider_"):
		who = "adeline"
	if not WEAR.has(who) or not rig.info.has(str(WEAR[who][1])):
		return
	var spec: Array = WEAR[who]
	var part: Dictionary = rig.info[str(spec[1])]
	var on: Node2D = part["sprite"]
	var worn := Sprite2D.new()
	worn.name = "Worn"
	worn.texture = load(WINTER + "extra/%s.png" % spec[0])
	var k: float = float(spec[3]) / worn.texture.get_width()
	worn.scale = Vector2(k, k)
	worn.offset = Vector2(0.0, -worn.texture.get_height() / 2.0)  # it sits on its bottom edge
	worn.position = (spec[2] as Vector2) - (part["pivot"] as Vector2)
	worn.rotation_degrees = float(spec[4])
	on.add_child(worn)


## Days left until Christmas Day, 0 on the day itself, -1 once it has passed.
static func days_to_christmas() -> int:
	var today := Time.get_date_dict_from_system()
	if int(today["month"]) != 12 or int(today["day"]) > 25:
		return -1
	return 25 - int(today["day"])


## What to say on the title screen today.
static func greeting() -> String:
	var today := Time.get_date_dict_from_system()
	var month := int(today["month"])
	var day := int(today["day"])
	if month == 1 and day == 1:
		return "Happy New Year!"
	if month == 12 and day == 25:
		return "Merry Christmas!"
	if month == 12 and day == 24:
		return "It's Christmas Eve!"
	if month == 12 and day < 24:
		return "%d sleeps until Christmas" % (25 - day)
	if month == 12 and day == 31:
		return "Happy New Year's Eve!"
	return "Merry Christmas!"
