extends RefCounted

## Shared seat identities keep setup, gameplay and results distinguishable.

const COLORS: Array[Color] = [
	Color("4da3ff"), Color("ff5c6c"), Color("55c47a"),
]


## Player colours supplement, rather than replace, the numbered labels.
static func color(player_index: int) -> Color:
	assert(player_index >= 0 and player_index < COLORS.size(), "Unknown player identity.")
	return COLORS[player_index]


## The same numbered name is used at every step of a local session.
static func name_for(player_index: int) -> String:
	assert(player_index >= 0 and player_index < COLORS.size(), "Unknown player identity.")
	return "Player %d" % (player_index + 1)


## Compact identity for portraits and space-constrained HUDs.
static func tag(player_index: int) -> String:
	assert(player_index >= 0 and player_index < COLORS.size(), "Unknown player identity.")
	return "P%d" % (player_index + 1)
