class_name GameInfo
extends RefCounted

## Single place for the studio / game identity used across every screen.
## Rename the game here and the logo, intro, menu and credits follow.

const STUDIO := "DeskCanSaw Games"
const STUDIO_SHORT := "DeskCanSaw"
const WEBSITE := "https://deskcansaw.com"

const TITLE := "Game Title"
const TAGLINE := "A DeskCanSaw Games production"

## Text cards shown by the placeholder intro, in order.
const INTRO_CARDS: Array[String] = [
	"Long before the first line of code…",
	"…there was a placeholder.",
	"Replace this scene with your own intro.",
]

## Credits sections rendered by the credits screen.
## Each entry is { "heading": String, "lines": Array }.
const CREDITS: Array[Dictionary] = [
	{
		"heading": "Design & Code",
		"lines": ["Your Name Here"],
	},
	{
		"heading": "Art",
		"lines": ["Your Name Here"],
	},
	{
		"heading": "Music & Sound",
		"lines": ["Placeholder UI sounds generated for this template"],
	},
	{
		"heading": "Built With",
		"lines": ["Godot Engine 4", "godotengine.org"],
	},
	{
		"heading": "Thanks",
		"lines": ["Everyone who played the prototype"],
	},
]

## Brand palette, mirrored by ui/theme/dcs_theme.tres.
const INK := Color("0e1519")
const DEEP := Color("162128")
const SLATE := Color("4a5a66")
const SKY := Color("afddea")
const CREAM := Color("f2f7f9")
const MUTED := Color("93a6b0")


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func copyright_line() -> String:
	return "© %d %s" % [Time.get_date_dict_from_system().year, STUDIO]
