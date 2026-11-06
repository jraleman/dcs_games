extends SceneTree

## Development-only entry point for the screenshot tour: boots the build the
## launch selects (one standalone game, or the collection), walks every shared
## screen and saves a PNG of each for review. Nothing here ships with a game;
## run it through `tools/capture_screens.ps1`, which gives every run a fresh,
## isolated user profile.
##
##     godot --path godot-base --resolution 1280x720 \
##         --script res://tools/capture_screens.gd -- --game=triangle_rush \
##         --capture-out=C:/shots/triangle_rush --capture-profile=C:/tmp/profile
##
## `--capture-list=<file>` instead writes every catalog id, one per line, and
## quits. The wrapper runs it with `--headless -- --game=all` to discover games.
##
## A `--script` main loop is compiled before the autoloads exist, so this file
## names none of them. The tour that drives the menus is loaded at runtime from
## `capture_screens_tour.gd`, once they do.

const TOUR_PATH := "res://tools/capture_screens_tour.gd"
const LIST_ARGUMENT := "--capture-list="


func _initialize() -> void:
	# The root window, and the autoloads under it, enter the tree after this.
	_start.call_deferred()


func _start() -> void:
	var list_path := _argument(LIST_ARGUMENT)
	if not list_path.is_empty():
		quit(_write_catalog(list_path))
		return

	var script := load(TOUR_PATH) as GDScript
	if script == null or not script.can_instantiate():
		printerr("Could not load the screenshot tour at %s." % TOUR_PATH)
		quit(1)
		return
	var tour: Object = script.new()
	if not tour is Node:
		printerr("The screenshot tour at %s must extend Node." % TOUR_PATH)
		quit(1)
		return
	# A child of the root, not the current scene, so every Router.goto() the
	# tour triggers leaves it running.
	(tour as Node).name = "ScreenshotTour"
	root.add_child(tour as Node)


## Writes the id of every game this launch can see, so the wrapper never keeps
## a second list of games that could drift from the catalog.
func _write_catalog(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Could not write the game list to %s (error %d)." % [
			path, FileAccess.get_open_error(),
		])
		return 1
	for manifest in GameCatalog.all():
		file.store_line(manifest.id)
	file.close()
	return 0


func _argument(prefix: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	arguments.append_array(OS.get_cmdline_args())
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return ""
