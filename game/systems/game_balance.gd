extends RefCounted

# VOLT PATH gameplay balance constants.
# Keep shared HP, BAT costs, and skill damage values here so UI text and
# gameplay logic cannot silently drift apart.

const ENEMY_HP_PER_CELL := 2
const REROLL_COST := 2
const FULL_CHARGE_MOVE_DAMAGE := 1
const FULL_CHARGE_ENEMY_DAMAGE := 1

const ARC_COST := 1
const SURGE_COST := 6
const BOMB_COST := 7
const WARP_COST := 2
const DASH_COST := 2
const LOOP_COST := 4

const ARC_DAMAGE := 2
const SURGE_DAMAGE_PER_CELL := 1
const BOMB_DAMAGE_PER_CELL := 2
const DASH_DAMAGE_PER_CELL := 1
const LOOP_DAMAGE_PER_CELL := 3
