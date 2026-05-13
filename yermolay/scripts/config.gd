extends Node

const W := 1100
const H := 720

# ── Enemy types ──────────────────────────────────────────────
const ET_DRONE     := 0
const ET_INTER     := 1
const ET_HEAVY     := 2
const ET_OBS       := 3
const ET_NODE      := 4
const ET_BERSERKER := 5
const ET_TITAN     := 6
const ET_PREDATOR  := 7
const ET_REAPER    := 8
const ET_HUNTER    := 9
const ET_COLOSSUS  := 10
const ET_OMEGA     := 11

const ECFG := {
	0:  {"r": 15, "speed": 90,  "hp": 2,    "score": 10,   "dmg": 8,  "is_boss": false, "shoot_rate": 0.0, "is_final": false},
	1:  {"r": 11, "speed": 175, "hp": 1,    "score": 15,   "dmg": 6,  "is_boss": false, "shoot_rate": 0.0, "is_final": false},
	2:  {"r": 24, "speed": 50,  "hp": 10,   "score": 50,   "dmg": 18, "is_boss": false, "shoot_rate": 0.0, "is_final": false},
	3:  {"r": 19, "speed": 72,  "hp": 6,    "score": 35,   "dmg": 12, "is_boss": false, "shoot_rate": 0.0, "is_final": false},
	4:  {"r": 35, "speed": 36,  "hp": 25,   "score": 200,  "dmg": 28, "is_boss": false, "shoot_rate": 4.0, "is_final": false},
	5:  {"r": 14, "speed": 230, "hp": 8,    "score": 80,   "dmg": 20, "is_boss": false, "shoot_rate": 0.0, "is_final": false},
	6:  {"r": 30, "speed": 42,  "hp": 40,   "score": 160,  "dmg": 35, "is_boss": false, "shoot_rate": 0.0, "is_final": false},
	7:  {"r": 17, "speed": 160, "hp": 18,   "score": 120,  "dmg": 28, "is_boss": false, "shoot_rate": 0.0, "is_final": false},
	8:  {"r": 22, "speed": 105, "hp": 30,   "score": 180,  "dmg": 40, "is_boss": false, "shoot_rate": 2.5, "is_final": false},
	9:  {"r": 40, "speed": 80,  "hp": 200,  "score": 500,  "dmg": 45, "is_boss": true,  "shoot_rate": 2.2, "is_final": false, "boss_name": "Охотник"},
	10: {"r": 55, "speed": 50,  "hp": 500,  "score": 1200, "dmg": 65, "is_boss": true,  "shoot_rate": 1.5, "is_final": false, "boss_name": "Колосс"},
	11: {"r": 70, "speed": 38,  "hp": 1000, "score": 3000, "dmg": 90, "is_boss": true,  "shoot_rate": 0.8, "is_final": true,  "boss_name": "Омега"},
}

const BOSS_SCHEDULE := [
	{"at": 180.0, "type": 9},
	{"at": 420.0, "type": 10},
	{"at": 720.0, "type": 11},
]

# ── Enemy colors ─────────────────────────────────────────────
const ENEMY_BASE := {
	0: Color("1e2030"), 1: Color("0f2010"), 2: Color("10101e"),
	3: Color("0a1522"), 4: Color("07071a"), 5: Color("1a0808"),
	6: Color("0a0a14"), 7: Color("061418"), 8: Color("1a0618"),
	9: Color("1a0800"), 10: Color("050515"), 11: Color("0a0015"),
}
const ENEMY_ACCENT := {
	0: Color("3a3a52"), 1: Color("33dd55"), 2: Color("0000cc"),
	3: Color("1a3a5a"), 4: Color("001188"), 5: Color("cc2200"),
	6: Color("2244cc"), 7: Color("0088aa"), 8: Color("880088"),
	9: Color("cc3300"), 10: Color("1133aa"), 11: Color("880099"),
}

# ── Palette ───────────────────────────────────────────────────
const C_BG          := Color("0e0a07")
const C_GRID        := Color("141008")
const C_PLAYER      := Color(0.31, 0.55, 1.0)
const C_PLAYER_AURA := Color(0.27, 0.51, 1.0, 0.12)
const C_ORB         := Color(0.6, 0.27, 1.0, 0.75)
const C_ORB_CORE    := Color(0.87, 0.6, 1.0)
const C_BULLET      := Color(0.53, 0.73, 1.0)
const C_EBULLET     := Color(1.0, 0.27, 0.0)
const C_LIGHTNING   := Color(0.7, 0.9, 1.0)
const C_NOVA        := Color(0.8, 0.4, 1.0)
const C_CHEST       := Color(1.0, 0.87, 0.33)
const C_WRECK       := Color(0.2, 0.15, 0.1, 0.4)
const C_HUD_GOOD    := Color("00ff88")
const C_HUD_WARN    := Color("ffaa00")
const C_HUD_BAD     := Color("ff3344")
const C_HUD_TEXT    := Color("88bbdd")
const C_HUD_TITLE   := Color("5599ff")
const C_BOSS_BAR    := Color(1.0, 0.4, 0.1)

# ── Phase pool ────────────────────────────────────────────────
static func get_phase_pool(t: float) -> Array:
	var m := t / 60.0
	if m < 2:  return [[0, 8], [1, 2]]
	if m < 4:  return [[0, 5], [1, 5]]
	if m < 7:  return [[0, 3], [1, 3], [2, 3], [3, 1]]
	if m < 10: return [[1, 2], [2, 4], [3, 3], [4, 1]]
	if m < 13: return [[2, 1], [3, 1], [5, 4], [6, 2], [4, 2]]
	return [[5, 2], [6, 2], [7, 3], [8, 3]]

static func pick_pool(pool: Array) -> int:
	var tot := 0.0
	for p in pool:
		tot += p[1]
	var r := randf() * tot
	for p in pool:
		r -= p[1]
		if r <= 0:
			return p[0]
	return pool[0][0]
