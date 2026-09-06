class_name StudioInfo
extends RefCounted

## Studio and application identity shared by every screen and every game.
##
## This is deliberately game-agnostic: per-game names, achievements, stats URLs
## and media live in that game's [GameManifest] under `res://games/<id>/`.
## Rebrand the project here and the logo, intro, menus and credits follow.

const STUDIO := "DeskCanSaw Games"
const STUDIO_SHORT := "DeskCanSaw"
const WEBSITE := "https://deskcansaw.com"

## Application title, shown before a game is selected. Individual games carry
## their own [member GameManifest.title].
const TITLE := "DCS Base Game"
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
		"lines": ["DeskCanSaw"],
	},
	{
		"heading": "Art",
		"lines": ["DeskCanSaw"],
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
		"heading": "Open Source",
		"lines": ["QR encoder by Greaby (MIT)"],
	},
	{
		"heading": "Thanks",
		"lines": ["Everyone who played the prototype"],
	},
]

## Heading the credits screen puts above the game list in a build that ships
## more than one game. No single game's credits would be the right ones there,
## so the roll points at the games instead of guessing.
const COLLECTION_CREDITS_HEADING := "Game Credits"

## The line under that list. The game names themselves come from GameCatalog so
## this stays true whatever the build contains; only the wording lives here,
## next to the rest of the studio copy.
const COLLECTION_CREDITS_NOTE := (
	"Each game keeps its own credits, listed in that game's own release."
)

## Brand palette, mirrored by ui/theme/dcs_theme.tres.
const INK := Color("0e1519")
const DEEP := Color("162128")
const SLATE := Color("4a5a66")
const SKY := Color("afddea")
const CREAM := Color("f2f7f9")
const MUTED := Color("93a6b0")


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func website_label() -> String:
	return WEBSITE.trim_prefix("https://").trim_prefix("http://").trim_suffix("/")


static func copyright_line() -> String:
	return "© %d %s" % [Time.get_date_dict_from_system().year, StudioInfo.STUDIO]
