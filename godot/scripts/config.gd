extends Node

# Grid / world
const TILE : int   = 32
const GW   : int   = 30
const GH   : int   = 20
const MAP_OFFSET := Vector2(160, 40)  # centered in 1280x720 viewport

# Tile types
const FLOOR := 1
const WALL  := 0

# Drone
const DRONE_SPEED    := 5.0
const DRONE_VISION   := 5

# Energy
const ENERGY_MAX     := 100.0
const ENERGY_REGEN   := 4.0
const ENERGY_MOVE    := 0.35
const ENERGY_STEALTH := 9.0

# Compute (pause resource)
const COMPUTE_MAX    := 100.0
const COMPUTE_REGEN  := 14.0
const COMPUTE_DRAIN  := 28.0
const PAUSE_TSCALE   := 0.12

# Enemy
const ENEMY_RANGE          := 7
const ENEMY_FOV            := 65.0
const ENEMY_ROT            := 22.0
const ENEMY_SWING          := 50.0
const ENEMY_SPEED          := 2.0
const ENEMY_WAIT           := 1.2
const ENEMY_CHASE_INTERVAL := 0.5

# Detection
const DETECT_RATE  := 32.0
const DETECT_DECAY := 16.0

# Gameplay
const HACK_RANGE    := 1.8
const HACK_TIME     := 4.0
const BEACON_RADIUS := 7
const MISSION_TIME  := 240.0

# Palette
const C_BG            := Color("05080f")
const C_WALL          := Color("080c18")
const C_WALL_LIT      := Color("0d1530")
const C_FLOOR         := Color("0b1225")
const C_FLOOR_LIT     := Color("0e1a35")
const C_DRONE         := Color("00e0ff")
const C_DRONE_GLOW    := Color(0, 0.878, 1, 0.35)
const C_DRONE_STEALTH := Color(0, 0.627, 0.784, 0.5)
const C_PATH          := Color(0, 0.706, 0.863, 0.45)
const C_ENEMY         := Color("ff2040")
const C_ENEMY_ALERT   := Color("ff8800")
const C_ENEMY_SUSP    := Color("ffdd00")
const C_CONE          := Color(1, 0.11, 0.188, 0.22)
const C_CONE_ALERT    := Color(1, 0.47, 0.078, 0.38)
const C_CONE_SUSP     := Color(1, 0.863, 0.0, 0.28)
const C_TERMINAL      := Color("00ff88")
const C_TERM_HACKED   := Color("003322")
const C_EXTRACTION    := Color("ffd700")
const C_HUD_GOOD      := Color("00ff88")
const C_HUD_WARN      := Color("ffaa00")
const C_HUD_BAD       := Color("ff3344")
const C_HUD_TEXT      := Color("88bbdd")
const C_HUD_TITLE     := Color("00e0ff")
const C_FOG_PERM      := Color(0, 0, 0, 0.55)
const C_FOG_DARK      := Color(0, 0, 0, 0.92)

static func grid_to_local(gx: int, gy: int) -> Vector2:
	return Vector2(gx * TILE + TILE / 2.0, gy * TILE + TILE / 2.0)

static func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local = screen_pos - MAP_OFFSET
	return Vector2i(int(local.x / TILE), int(local.y / TILE))

static func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < GW and y >= 0 and y < GH
