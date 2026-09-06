extends RefCounted

## Desk-Can-Saw manifest — an unlockable game earned by playing Target Rush.
##
## The gate is expressed entirely through [SliceAndSlashUnlockRule], so the
## framework hides and reveals this game without knowing what it is.

const GAME_ID := "slice_and_slash"


static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = GAME_ID
	game.title = "Desk-Can-Saw"
	game.tagline = "Slice falling cans with an electric chainsaw."
	game.gameplay_scene_path = "res://games/slice_and_slash/slice_and_slash.tscn"
	game.menu_order = 1
	game.supports_multiplayer = true
	# Desk-Can-Saw is a direct-movement game with no CPU driver.
	game.supports_cpu_opponent = false
	game.control_style = GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT
	game.copy = {
		"mode_select_intro": (
			"Choose how many electric saws are taking over the workshop desk."
		),
		"mode_select_hint": "You will confirm the separate player controls next.",
		"single_player_description": (
			"Drive an electric chainsaw across the wood desk and shred every "
			+ "falling can you can reach."
		),
		"multiplayer_description": (
			"Share the workbench: Player 1 uses the mouse and Player 2 uses the "
			+ "arrow keys."
		),
		"player_one_control_description": "Move Player 1's electric chainsaw.",
		"player_two_control_description": (
			"These controls move Player 2's chainsaw only."
		),
		"solo_confirm_title": "Ready to fire up the saw?",
		"solo_confirm_description": (
			"Guide one electric chainsaw across the workshop desk and tear through "
			+ "as many falling cans as possible before time runs out."
		),
		"versus_confirm_title": "Two saws, one workbench",
		"versus_confirm_description": (
			"Race electric chainsaws across the same wood desk. Player 1 uses the "
			+ "mouse and Player 2 uses the arrow keys by default."
		),
		"instructions_headline": "Slice every can before it lands",
		"instructions_rules": (
			"Touch a can to cut it  ·  Each can scores +1 once  ·  "
			+ "Landed cans break your streak  ·  Esc pauses"
		),
		"instructions_demo_prompt": "DRIVE THE ELECTRIC CHAIN THROUGH A CAN",
		"instructions_solo_summary": (
			"Move Player 1's electric chainsaw over the workshop desk. Each can "
			+ "erupts in sparks and scores exactly once."
		),
		"instructions_versus_summary": (
			"Both players work the same can-covered desk. The first electric "
			+ "chainsaw to tear through a can earns its point."
		),
	}
	game.hidden_until_unlocked = true
	game.unlock_rule = SliceAndSlashUnlockRule.new()
	game.tunables = SliceOptions.TUNABLES
	game.control_bindings = SliceOptions.CONTROL_BINDINGS
	game.stats_url = "https://deskcansaw.com/stats/dcs"
	game.share_art_style = ShareCardArt.STYLE_DESK_CAN_SAW
	game.tutorial_video_path = "res://assets/video/tutorial_slice_and_slash.ogv"
	game.tutorial_poster_path = (
		"res://assets/video/tutorial_slice_and_slash_poster.webp"
	)
	game.credits = [
		{
			"heading": "Game Design & Code",
			"lines": ["DeskCanSaw"],
		},
		{
			"heading": "Sound",
			"lines": [
				"Chainsaw motor, can slices and clatter synthesised in-engine",
			],
		},
		{
			"heading": "Accessibility",
			"lines": [
				"Rebindable movement keys for both players",
				"Audio captions, reduced motion and player labels",
			],
		},
	]
	game.achievements = {
		SliceAndSlashUnlockRule.RACE_CONDITION_ACHIEVEMENT: {
			"title": "Race condition",
			"description": "Lose to Player 2 after they score at least 25 points.",
			"badge": "RACE",
		},
	}
	return game
