extends Node

# World dimensions (ported from HTML: WORLD_W=4300, WORLD_H=900)
const WORLD_W := 4300.0
const WORLD_H := 900.0
const FLIGHT_TOP := 90.0
const FLIGHT_BOTTOM := 705.0

# Player physics (exact values from HTML source)
const GRAVITY := 1450.0
const MOVE := 1420.0
const AIR_MOVE := 1180.0
const MAX_RUN := 620.0
const FRICTION := 0.89          # applied as pow(FRICTION, delta*60)
const JUMP_WALK := 770.0
const JUMP_FLOW := 835.0
const JUMP_BUF := 0.16          # jump input buffer window (seconds)
const COYOTE := 0.14            # coyote time (seconds)
const SLOW_FACTOR := 0.55

# Flight mode
const FLIGHT_BASE_VX := 225.0
const FLIGHT_SIDE := 95.0
const FLIGHT_GRAVITY := 500.0
const FLIGHT_MAX_UP := -360.0
const FLIGHT_MAX_DOWN := 320.0
const FLIGHT_FLAP := -340.0     # upward impulse on jump press

# Center (health-like resource, 0-100)
const CENTER_MAX := 100.0
const CENTER_FALL_LOSS := 10.0

# Levels
const LEVEL_MODES := ["walk", "jump", "flight"]
const LEVEL_KICKERS := ["I / Земные", "II / Летящие", "III / Восходящие"]
const LEVEL_TITLES := ["Земля / Предел", "Первый Поток", "Чёрный Рой"]
const LEVEL_INTROS := [
	"Первый уровень — ногами и простыми прыжками. Земля даёт только старт: портал стоит выше и открывается после орбов и ключа.",
	"Второй уровень — прыжки, обходы и усиления. Платформы стоят ближе, красные разрывы видны заранее, Кот даёт второй прыжок.",
	"Третий уровень — простой полёт. Нажимай Space короткими взмахами: выше — безопаснее, красные кольца Роя наносят урон только внутри себя."
]
const LEVEL_NEEDS := [3, 4, 4]   # orbs required to open portal
const LEVEL_STARTS := [Vector2(120, 676), Vector2(120, 696), Vector2(140, 420)]

# Palette (from CSS vars in HTML)
const C_BG         := Color("050607")
const C_INK        := Color("f4efe6")
const C_MUTED      := Color(0.957, 0.937, 0.902, 0.70)
const C_PAPER      := Color("efe3bd")
const C_PAPER_INK  := Color("554934")
const C_COPPER     := Color("d2a16c")
const C_BLUE       := Color("bfe8f2")
const C_DANGER     := Color("c85a4c")
const C_DARK       := Color("050607")

# Platform type colors
const C_GROUND     := Color("2a2218")
const C_EARTH      := Color("3d3020")
const C_CLOUD      := Color("1a2a35")
const C_SECRET     := Color("3a2f1a")
const C_HAZARD     := Color("8c2a1e")
