extends RefCounted

## Triangle Rush manifest — the default game shipped with the base project.
##
## [GameCatalog] discovers this file automatically; nothing in the framework
## refers to Triangle Rush by name.

const GAME_ID := "triangle_rush"


static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = GAME_ID
	game.title = "Triangle Rush"
	game.tagline = "Hit your highlighted target before the clock runs out."
	game.gameplay_scene_path = "res://games/triangle_rush/gameplay.tscn"
	game.menu_order = 0
	game.supports_multiplayer = true
	game.supports_cpu_opponent = true
	game.control_style = GameManifest.CONTROL_STYLE_TARGETS
	game.copy = {
		"mode_select_intro": "Choose how many players are chasing the targets.",
		"mode_select_hint": "You will confirm the player controls next.",
	}
	game.stats_url = "https://deskcansaw.com/stats/tr"
	game.tunables = TriangleRushOptions.TUNABLES
	game.share_art_style = ShareCardArt.STYLE_TRIANGLE_RUSH
	game.tutorial_video_path = "res://assets/video/tutorial_triangle_rush.ogv"
	game.tutorial_poster_path = "res://assets/video/tutorial_triangle_rush_poster.webp"
	game.credits = [
		{
			"heading": "Game Design & Code",
			"lines": ["DeskCanSaw"],
		},
		{
			"heading": "Sound",
			"lines": ["Shared UI tones, pitched up as your streak climbs"],
		},
		{
			"heading": "Accessibility",
			"lines": [
				"One-button mode for players who cannot reach two keys",
				"Audio captions, reduced motion and player labels",
			],
		},
	]
	game.achievements = {
		"first_single_player_game": {
			"title": "Solo Starter",
			"description": "Finish your first single-player round.",
			"badge": "1P",
		},
		"first_win": {
			"title": "First Win",
			"description": "Win your first multiplayer round as Player 1.",
			"badge": "WIN",
		},
	}
	return game
