extends Node

const WORLD_W := 4300.0
const WORLD_H := 900.0
const FLIGHT_TOP := 90.0
const FLIGHT_BOTTOM := 720.0

const GRAVITY := 1450.0
const MOVE := 1420.0
const AIR_MOVE := 1180.0
const MAX_RUN := 620.0
const FRICTION := 0.89
const JUMP_WALK := 770.0
const JUMP_FLOW := 835.0
const JUMP_BUF := 0.16
const COYOTE := 0.14
const SLOW_FACTOR := 0.55

# Flight (level 3) — bidirectional, intensity-based
const FLIGHT_SIDE      := 300.0
const FLIGHT_GRAVITY   := 520.0
const FLIGHT_MAX_UP    := -380.0
const FLIGHT_MAX_DOWN  := 340.0
const FLIGHT_FLAP_IMP  := -160.0   # impulse per tap
const FLIGHT_FLAP_HOLD := -290.0   # sustained force while held (per sec)
const FLIGHT_FRICTION  := 0.92

# Hearts / shields
const MAX_HEARTS  := 3
const MAX_SHIELDS := 3

# Levels
const LEVEL_MODES   := ["walk", "jump", "flight"]
const LEVEL_KICKERS := ["I / Земные", "II / Летящие", "III / Восходящие"]
const LEVEL_TITLES  := ["Земля / Предел", "Первый Поток", "Чёрный Рой"]
const LEVEL_INTROS  := [
	"Земля: найди зверей — они откроют путь. Медведь даёт щит, Лиса — тайные тропы, Кот — второй прыжок.",
	"Поток: платформы дальше, площадки уже. Дроны движутся — одни помогают, другие сбивают.",
	"Рой: управляй высотой крыльями. Тапай — лети выше, отпусти — падай. Можно вернуться назад."
]
const LEVEL_NEEDS  := [3, 4, 4]
const LEVEL_STARTS := [Vector2(120, 676), Vector2(120, 696), Vector2(220, 360)]

# Palette
const C_BG         := Color("050607")
const C_INK        := Color("f4efe6")
const C_MUTED      := Color(0.957, 0.937, 0.902, 0.70)
const C_PAPER      := Color("efe3bd")
const C_PAPER_INK  := Color("554934")
const C_COPPER     := Color("d2a16c")
const C_BLUE       := Color("bfe8f2")
const C_DANGER     := Color("c85a4c")
const C_DARK       := Color("050607")
const C_GROUND     := Color("2a2218")
const C_EARTH      := Color("3d3020")
const C_CLOUD      := Color("1a2a35")
const C_SECRET     := Color("3a2f1a")
const C_HAZARD     := Color("8c2a1e")
const C_DRONE_HELP := Color("1a3040")
const C_DRONE_HARM := Color("4a1a1a")
