extends Node2D

# ── State ──────────────────────────────────────────────────────
var _map:       Array = []
var _rooms:     Array = []
var _fog:       Array = []
var _fog_perm:  Array = []
var _drone:     Drone
var _enemies:   Array = []
var _terminals: Array = []
var _extraction: Dictionary = {}
var _astar:     AStarGrid
var _hud:       GameHUD

var _alert_level:     float  = 0.0
var _compute:         float  = Config.COMPUTE_MAX
var _timer:           float  = Config.MISSION_TIME
var _phase:           String = "active"
var _paused:          bool   = false
var _sonar_timer:     float  = 0.0
var _total_terminals: int    = 0

const SONAR_DURATION := 3.0

func _ready() -> void:
	position = Config.MAP_OFFSET
	_hud = GameHUD.new()
	add_child(_hud)
	_hud.stealth_pressed.connect(_on_stealth)
	_hud.hack_pressed.connect(_on_hack)
	_hud.sonar_pressed.connect(_on_sonar)
	_hud.pause_pressed.connect(_on_pause)
	_hud.restart_pressed.connect(_init_world)
	_init_world()

func _init_world() -> void:
	_phase       = "active"
	_paused      = false
	_alert_level = 0.0
	_compute     = Config.COMPUTE_MAX
	_timer       = Config.MISSION_TIME
	_sonar_timer = 0.0

	var result := BSPGen.generate(Config.GW, Config.GH)
	var attempt := 0
	while (result["rooms"] as Array).size() < 3 and attempt < 10:
		result = BSPGen.generate(Config.GW, Config.GH)
		attempt += 1

	_map   = result["map"]
	_rooms = result["rooms"]

	_fog      = []
	_fog_perm = []
	for _y in Config.GH:
		_fog.append([])
		_fog_perm.append([])
		for _x in Config.GW:
			_fog[-1].append(false)
			_fog_perm[-1].append(false)

	_astar = AStarGrid.new()
	_astar.setup(_map, Config.GW, Config.GH)

	var cx := Config.GW / 2.0; var cy := Config.GH / 2.0
	_rooms.sort_custom(func(a, b):
		return Vector2(a["cx"], a["cy"]).distance_to(Vector2(cx, cy)) < Vector2(b["cx"], b["cy"]).distance_to(Vector2(cx, cy))
	)

	var start_room: Dictionary = _rooms[0]
	var ext_room:   Dictionary = _rooms[-1]

	_drone = Drone.new()
	_drone.setup(start_room["cx"], start_room["cy"])
	_drone.connect("hacked",         _on_terminal_hacked)
	_drone.connect("stealth_failed", _on_stealth_failed)

	_extraction = {"x": ext_room["cx"], "y": ext_room["cy"], "active": false}

	var mid_rooms := (_rooms as Array).filter(func(r): return r != start_room and r != ext_room).slice(0, 3)
	_terminals = mid_rooms.map(func(r):
		return {
			"x":      clampi(r["cx"] + randi_range(-1, 1), r["x"] + 1, r["x"] + r["w"] - 2),
			"y":      clampi(r["cy"] + randi_range(-1, 1), r["y"] + 1, r["y"] + r["h"] - 2),
			"hacked": false
		}
	)
	_total_terminals = _terminals.size()

	var enemy_rooms := (_rooms as Array).filter(func(r): return r != start_room).slice(0, 5)
	_enemies = enemy_rooms.map(func(r):
		var ex := clampi(r["cx"] + randi_range(-1, 1), r["x"] + 1, r["x"] + r["w"] - 2)
		var ey := clampi(r["cy"] + randi_range(-1, 1), r["y"] + 1, r["y"] + r["h"] - 2)
		var wp1 := Vector2i(
			clampi(r["x"] + randi_range(1, max(1, r["w"] - 2)), r["x"] + 1, r["x"] + r["w"] - 2),
			clampi(r["y"] + randi_range(1, max(1, r["h"] - 2)), r["y"] + 1, r["y"] + r["h"] - 2)
		)
		var wp2 := Vector2i(
			clampi(r["x"] + randi_range(1, max(1, r["w"] - 2)), r["x"] + 1, r["x"] + r["w"] - 2),
			clampi(r["y"] + randi_range(1, max(1, r["h"] - 2)), r["y"] + 1, r["y"] + r["h"] - 2)
		)
		var e := Enemy.new()
		e.setup(ex, ey, randf_range(0.0, 360.0), [Vector2i(ex, ey), wp1, wp2], _astar)
		return e
	)

	_hud.hide_overlay()
	_hud.update_terminals(0, _total_terminals)

# ── Game Loop ──────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _phase != "active":
		queue_redraw()
		return

	var dt := delta * (Config.PAUSE_TSCALE if _paused else 1.0)

	if _paused:
		_compute = max(0.0, _compute - Config.COMPUTE_DRAIN * delta)
		if _compute <= 0.0:
			_paused = false
			_hud.set_paused(false)
	else:
		_compute = min(Config.COMPUTE_MAX, _compute + Config.COMPUTE_REGEN * delta)

	_timer       = max(0.0, _timer - dt)
	_sonar_timer = max(0.0, _sonar_timer - dt)

	_drone.update(dt)
	for e in _enemies:
		(e as Enemy).update(dt)

	_update_fog()
	_check_detection(dt)
	_alert_level = max(0.0, _alert_level - 4.0 * dt)
	_check_win_loss()

	_hud.update_bars(_alert_level, _drone.energy, _compute, _drone.detected)
	_hud.update_timer(_timer)
	queue_redraw()

# ── Fog ────────────────────────────────────────────────────────
func _update_fog() -> void:
	for y in Config.GH:
		for x in Config.GW:
			_fog[y][x] = false

	if not _drone.alive:
		return

	for dy in range(-Config.DRONE_VISION, Config.DRONE_VISION + 1):
		for dx in range(-Config.DRONE_VISION, Config.DRONE_VISION + 1):
			var nx := _drone.gx + dx; var ny := _drone.gy + dy
			if not Config.in_bounds(nx, ny):
				continue
			if Vector2(dx, dy).length() > Config.DRONE_VISION:
				continue
			if not _los(_drone.gx, _drone.gy, nx, ny):
				continue
			_fog[ny][nx]      = true
			_fog_perm[ny][nx] = true

# ── Detection ──────────────────────────────────────────────────
func _check_detection(dt: float) -> void:
	if not _drone.alive:
		return

	var in_view := false
	for e in _enemies:
		var en := e as Enemy
		if en.can_see(_map, _drone.gx, _drone.gy):
			if not _drone.stealth_on:
				in_view             = true
				en.alert_state      = "alert" if _drone.detected > 45.0 else "suspicious"
				en.alert_timer      = 2.5
				en.flash_timer      = 0.4
				en.last_known_drone = Vector2i(_drone.gx, _drone.gy)
		else:
			if en.alert_timer > 0.0:
				en.alert_timer -= dt
			else:
				en.alert_state = "patrol"

	if in_view and not _drone.stealth_on:
		_drone.detected = min(100.0, _drone.detected + Config.DETECT_RATE * dt)
		_alert_level    = min(100.0, _alert_level + 8.0 * dt)
	else:
		_drone.detected = max(0.0, _drone.detected - Config.DETECT_DECAY * dt)

# ── Win / Loss ─────────────────────────────────────────────────
func _check_win_loss() -> void:
	if _alert_level >= 100.0:
		_end_phase("failure", "LOCKDOWN\nMaximum alert reached"); return
	if _drone.detected >= 100.0:
		_drone.alive = false
		_end_phase("failure", "DRONE DESTROYED\nSecurity eliminated you"); return
	if _timer <= 0.0:
		_end_phase("failure", "MISSION FAILED\nTimer expired"); return

	var hacked := (_terminals as Array).filter(func(t): return t["hacked"]).size()
	if hacked == _total_terminals and _total_terminals > 0:
		_extraction["active"] = true

	if _extraction.get("active", false):
		if Vector2(_drone.gx, _drone.gy).distance_to(Vector2(_extraction["x"], _extraction["y"])) < 1.5:
			_end_phase("success", "MISSION COMPLETE\nData extracted!")

	_hud.update_terminals(hacked, _total_terminals)

func _end_phase(phase: String, msg: String) -> void:
	_phase = phase
	_hud.show_overlay(msg + "\n\nTap RESTART to play again")

# ── Input ──────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if _phase != "active":
		return

	var pressed    := false
	var screen_pos := Vector2.ZERO

	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed    = true
		screen_pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed    = true
			screen_pos = mb.position

	if not pressed:
		return

	var grid := Config.screen_to_grid(screen_pos)
	if not Config.in_bounds(grid.x, grid.y):
		return
	if _map[grid.y][grid.x] != Config.FLOOR:
		return

	# Tap on reachable terminal → hack
	for t in _terminals:
		var td := t as Dictionary
		if not td["hacked"] and grid == Vector2i(td["x"], td["y"]) and _drone.can_reach_terminal(td):
			_drone.start_hack(td)
			return

	_drone.move_to(_astar, grid.x, grid.y)

# ── HUD Buttons ────────────────────────────────────────────────
func _on_stealth() -> void:
	if _drone.energy < 10.0: return
	_drone.stealth_on = not _drone.stealth_on
	_hud.set_stealth_active(_drone.stealth_on)

func _on_hack() -> void:
	for t in _terminals:
		var td := t as Dictionary
		if not td["hacked"] and _drone.can_reach_terminal(td):
			_drone.start_hack(td)
			return

func _on_sonar() -> void:
	if _compute < 20.0: return
	_sonar_timer = SONAR_DURATION
	_compute -= 20.0

func _on_pause() -> void:
	_paused = not _paused
	_hud.set_paused(_paused)

func _on_terminal_hacked(_t) -> void:
	_hud.show_message("Terminal hacked!", 3.0)

func _on_stealth_failed() -> void:
	_drone.stealth_on = false
	_hud.set_stealth_active(false)
	_hud.show_message("Stealth offline — power depleted", 2.5)

# ── Drawing ────────────────────────────────────────────────────
func _draw() -> void:
	_draw_background()
	_draw_map()
	_draw_terminals()
	_draw_extraction()
	_draw_cones()
	_draw_enemies()
	_draw_drone_trail()
	_draw_drone()
	_draw_drone_path()
	_draw_fog()

func _draw_background() -> void:
	draw_rect(Rect2(-Config.MAP_OFFSET, Vector2(1280, 720)), Config.C_BG)

func _draw_map() -> void:
	for y in Config.GH:
		for x in Config.GW:
			if not _fog_perm[y][x]: continue
			var lit := _fog[y][x]
			if _map[y][x] == Config.WALL:
				draw_rect(_tile_rect(x, y), Config.C_WALL_LIT if lit else Config.C_WALL)
			else:
				draw_rect(_tile_rect(x, y), Config.C_FLOOR_LIT if lit else Config.C_FLOOR)

func _draw_terminals() -> void:
	for t in _terminals:
		var td := t as Dictionary
		if not _fog_perm[td["y"]][td["x"]]: continue
		var col := Config.C_TERM_HACKED if td["hacked"] else Config.C_TERMINAL
		var p   := Config.grid_to_local(td["x"], td["y"])
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col)
		if not td["hacked"] and _fog[td["y"]][td["x"]]:
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col, false, 1.5)

func _draw_extraction() -> void:
	var ex: int = _extraction["x"]; var ey: int = _extraction["y"]
	if not _fog_perm[ey][ex]: return
	var p   := Config.grid_to_local(ex, ey)
	var col := Config.C_EXTRACTION
	if _extraction.get("active", false):
		col = col.lightened(absf(sin(Time.get_ticks_msec() * 0.005)) * 0.4)
	draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), col, false, 2.0)
	draw_line(p - Vector2(7, 0), p + Vector2(7, 0), col, 1.5)
	draw_line(p - Vector2(0, 7), p + Vector2(0, 7), col, 1.5)

func _draw_cones() -> void:
	for e in _enemies:
		var en := e as Enemy
		if not _fog_perm[en.gy][en.gx]: continue
		var cone_col := Config.C_CONE_ALERT if en.alert_state == "alert" else (Config.C_CONE_SUSP if en.alert_state == "suspicious" else Config.C_CONE)
		var pts := _build_cone(en)
		if pts.size() >= 3:
			draw_colored_polygon(pts, cone_col)

func _draw_enemies() -> void:
	for e in _enemies:
		var en := e as Enemy
		if not _fog_perm[en.gy][en.gx]: continue
		var col := Config.C_ENEMY_ALERT if en.alert_state == "alert" else (Config.C_ENEMY_SUSP if en.alert_state == "suspicious" else Config.C_ENEMY)
		draw_circle(en.pos, 7.0, col)
		var dir := Vector2.from_angle(deg_to_rad(en.angle)) * 11.0
		draw_line(en.pos, en.pos + dir, col.lightened(0.3), 2.0)
		if en.flash_timer > 0.0:
			draw_arc(en.pos, 14.0, 0.0, TAU, 20, Color(1, 0.8, 0, en.flash_timer * 1.8), 2.5)

func _draw_drone_trail() -> void:
	if _drone.trail.size() < 2: return
	for i in range(1, _drone.trail.size()):
		var alpha := float(i) / _drone.trail.size() * 0.45
		draw_line(_drone.trail[i - 1], _drone.trail[i], Color(0, 0.878, 1, alpha), 2.0)

func _draw_drone() -> void:
	if not _drone.alive: return
	var col := Config.C_DRONE_STEALTH if _drone.stealth_on else Config.C_DRONE
	draw_circle(_drone.pos, 10.0, Config.C_DRONE_GLOW)
	draw_circle(_drone.pos, 6.0, col)
	draw_arc(_drone.pos, 9.0, 0.0, TAU, 24, col, 1.0)
	if _drone.state == "hacking":
		draw_arc(_drone.pos, 12.0, 0.0, _drone.hack_progress * TAU, 24, Config.C_TERMINAL, 2.5)

func _draw_drone_path() -> void:
	if _drone.path.is_empty(): return
	var pts := PackedVector2Array([_drone.pos])
	for step in _drone.path:
		pts.append(Config.grid_to_local((step as Vector2i).x, (step as Vector2i).y))
	draw_polyline(pts, Config.C_PATH, 1.5)
	draw_circle(pts[-1], 4.0, Config.C_PATH)

func _draw_fog() -> void:
	var sonar_active := _sonar_timer > 0.0
	for y in Config.GH:
		for x in Config.GW:
			if not _fog_perm[y][x]:
				draw_rect(_tile_rect(x, y), Config.C_FOG_DARK)
			elif not _fog[y][x] and not sonar_active:
				draw_rect(_tile_rect(x, y), Config.C_FOG_PERM)

# ── Utilities ──────────────────────────────────────────────────
func _tile_rect(x: int, y: int) -> Rect2:
	return Rect2(x * Config.TILE, y * Config.TILE, Config.TILE, Config.TILE)

func _build_cone(e: Enemy) -> PackedVector2Array:
	var pts        := PackedVector2Array([e.pos])
	var cone_range := float(Config.ENEMY_RANGE * Config.TILE)
	var steps      := 14
	for s in range(steps + 1):
		var a  := deg_to_rad(e.angle - Config.ENEMY_FOV + (2.0 * Config.ENEMY_FOV * s / steps))
		var dx := cos(a); var dy := sin(a)
		var hit := e.pos + Vector2(dx, dy) * cone_range
		var t   := 0.0
		while t <= cone_range:
			var wx := int(round((e.pos.x + dx * t) / Config.TILE))
			var wy := int(round((e.pos.y + dy * t) / Config.TILE))
			if not Config.in_bounds(wx, wy): break
			if _map[wy][wx] == Config.WALL:
				hit = e.pos + Vector2(dx, dy) * max(0.0, t - Config.TILE / 2.0)
				break
			t += Config.TILE / 2.0
		pts.append(hit)
	return pts

func _los(x1: int, y1: int, x2: int, y2: int) -> bool:
	return Enemy._los(_map, x1, y1, x2, y2)
