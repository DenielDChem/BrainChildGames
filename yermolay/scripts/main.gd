extends Node2D

# ── Game states ───────────────────────────────────────────────
enum GS { START, PLAY, OVER, WIN }
var _state := GS.START

# ── Player ────────────────────────────────────────────────────
var _p := {}

# ── World objects ─────────────────────────────────────────────
var _enemies:     Array = []
var _bullets:     Array = []
var _ebullets:    Array = []
var _particles:   Array = []
var _chests:      Array = []
var _wrecks:      Array = []
var _nova_pulses: Array = []
var _lfx:         Array = []  # lightning fx

# ── Timing ────────────────────────────────────────────────────
var _wave_time:      float = 0.0
var _spawn_clock:    float = 0.0
var _bosses_spawned: Array = []
var _active_boss             = null

# ── Phase label ───────────────────────────────────────────────
var _phase_lbl:   String = ""
var _phase_sub:   String = ""
var _phase_timer: float  = 0.0

const W: int = 1100
const H: int = 720

var _font: Font

# ── Virtual joystick (touch) ───────────────────────────────────
const JOY_R    := 72.0    # outer ring radius
const JOY_DEAD := 12.0    # dead zone pixels
var _joy_vec    := Vector2.ZERO
var _joy_origin := Vector2.ZERO
var _joy_cur    := Vector2.ZERO
var _joy_tid    := -1

# ── Init ──────────────────────────────────────────────────────
func _ready() -> void:
	_font = ThemeDB.fallback_font
	_state = GS.START

func _init_game() -> void:
	_p = {
		"x": 0.0, "y": 0.0, "r": 20.0, "speed": 190.0,
		"hp": 100.0, "max_hp": 100.0, "iframes": 0.0, "score": 0,
		"regen_clock": 3.0,
		"weapons": ["single"],
		"single_clock": 0.0, "single_rate": 1.0,
		"sg_clock": 0.0,     "sg_rate": 1.7,  "sg_count": 5, "sg_dmg": 1.0, "sg_pierce": false,
		"light_clock": 0.0,  "light_rate": 2.6, "light_chain": 3,
		"nova_clock": 0.0,   "nova_rate": 4.0,  "nova_radius": 110.0,
		"orb_angle": 0.0,    "orb_count": 3,    "orb_radius": 82.0, "orb_dmg": 1.0, "orb_cd": {},
		"bullet_dmg": 0.95,  "fire_rate": 1.0,  "life_steal": 0.0,
		"taken": [],
	}
	_enemies.clear(); _bullets.clear(); _ebullets.clear()
	_particles.clear(); _chests.clear(); _wrecks.clear()
	_nova_pulses.clear(); _lfx.clear()
	_wave_time = 0.0; _spawn_clock = 0.0
	_bosses_spawned.clear(); _active_boss = null; _phase_timer = 0.0
	_spawn_chest(); _spawn_chest()
	_state = GS.PLAY
	_show_msg("Фаза I", "Начало...")

# ── Main loop ─────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _state == GS.PLAY:
		_update(delta)
	queue_redraw()

func _update(dt: float) -> void:
	# Player movement — keyboard + virtual joystick
	var mv := _joy_vec   # joystick already normalized (or zero)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    mv.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  mv.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1.0
	if mv.length_squared() > 0.0:
		mv = mv.normalized() * _p["speed"] * dt
		_p["x"] += mv.x; _p["y"] += mv.y

	_p["iframes"] = maxf(0.0, _p["iframes"] - dt)
	_p["regen_clock"] -= dt
	if _p["regen_clock"] <= 0.0:
		_p["hp"] = minf(_p["max_hp"], _p["hp"] + 1.0)
		_p["regen_clock"] = 3.0

	_wave_time += dt
	_phase_timer = maxf(0.0, _phase_timer - dt)

	# Boss schedule
	for sched in Config.BOSS_SCHEDULE:
		if not _bosses_spawned.has(sched["type"]) and _wave_time >= sched["at"]:
			_bosses_spawned.append(sched["type"])
			var a := randf() * TAU
			_spawn_enemy_at(sched["type"], _p["x"] + cos(a) * 700.0, _p["y"] + sin(a) * 700.0)

	# Enemy spawn
	_spawn_clock -= dt
	if _spawn_clock <= 0.0:
		var base := 3 if _wave_time > 420 else (2 if _wave_time > 180 else 1)
		for _i in mini(base + int(_wave_time / 180.0), 5):
			_spawn_enemy()
		_spawn_clock = maxf(0.3, 2.0 - _wave_time * 0.012)

	# Update enemies
	for e in _enemies:
		if not e.get("dead", false):
			_update_enemy(e, dt)

	# Player bullets
	for i in range(_bullets.size() - 1, -1, -1):
		var b: Dictionary = _bullets[i]
		b["x"] += b["vx"] * dt; b["y"] += b["vy"] * dt; b["life"] -= dt
		if b["life"] <= 0.0: _bullets.remove_at(i); continue
		var hit := false
		for e in _enemies:
			if e.get("dead", false): continue
			if _hits(b, e):
				e["hp"] -= b["dmg"]; e["hit_flash"] = 0.12
				_emit_particles(b["x"], b["y"], Config.C_BULLET, 4, 90.0)
				if e["hp"] <= 0.0: _kill_enemy(e)
				if not b.get("pierce", false):
					hit = true; break
				else:
					b["hits"] = b.get("hits", 0) + 1
					if b["hits"] >= 3: hit = true; break
		if hit: _bullets.remove_at(i)

	# Enemy bullets
	for i in range(_ebullets.size() - 1, -1, -1):
		var b: Dictionary = _ebullets[i]
		b["x"] += b["vx"] * dt; b["y"] += b["vy"] * dt; b["life"] -= dt
		if b["life"] <= 0.0: _ebullets.remove_at(i); continue
		if _p["iframes"] <= 0.0 and _hits(b, _p):
			if b.get("insta_kill", false):
				_kill_player()
			else:
				_p["hp"] = maxf(0.0, _p["hp"] - b["dmg"])
				_p["iframes"] = 0.8
				_emit_particles(_p["x"], _p["y"], Color(1, 0.2, 0.2), 8, 100.0)
				if _p["hp"] <= 0.0: _kill_player()
			_ebullets.remove_at(i)

	# Chests
	for i in range(_chests.size() - 1, -1, -1):
		if _hits(_p, _chests[i]):
			_pick_chest(); _chests.remove_at(i)

	if int(_wave_time) % 25 == 0 and int(_wave_time) != int(_wave_time - dt) and _chests.size() < 8:
		_spawn_chest()

	# Weapons (auto-aim)
	var tgt := _nearest_enemy()
	var fr  := _p["fire_rate"]

	if _p["weapons"].has("single"):
		_p["single_clock"] -= dt
		if _p["single_clock"] <= 0.0 and tgt:
			_fire_single(tgt); _p["single_clock"] = _p["single_rate"] * fr

	if _p["weapons"].has("shotgun"):
		_p["sg_clock"] -= dt
		if _p["sg_clock"] <= 0.0 and tgt:
			_fire_shotgun(tgt); _p["sg_clock"] = _p["sg_rate"] * fr

	if _p["weapons"].has("lightning"):
		_p["light_clock"] -= dt
		if _p["light_clock"] <= 0.0 and tgt:
			_fire_lightning(tgt); _p["light_clock"] = _p["light_rate"] * fr

	if _p["weapons"].has("nova"):
		_p["nova_clock"] -= dt
		if _p["nova_clock"] <= 0.0:
			_fire_nova(); _p["nova_clock"] = _p["nova_rate"] * fr

	if _p["weapons"].has("orbit"):
		_p["orb_angle"] += dt * 1.6
		for oi in _p["orb_count"]:
			var ag := _p["orb_angle"] + oi * (TAU / _p["orb_count"])
			var orb := {"x": _p["x"] + cos(ag) * _p["orb_radius"],
						"y": _p["y"] + sin(ag) * _p["orb_radius"], "r": 11.0}
			for e in _enemies:
				if e.get("dead", false): continue
				var key := "%d_%d_%d" % [oi, int(e["x"]), int(e["y"])]
				var cd: float = _p["orb_cd"].get(key, 0.0)
				if cd > 0.0: _p["orb_cd"][key] = cd - dt; continue
				if _hits(orb, e):
					e["hp"] -= _p["bullet_dmg"] * _p["orb_dmg"]
					e["hit_flash"] = 0.1
					_p["orb_cd"][key] = 0.45
					_emit_particles(orb["x"], orb["y"], Config.C_ORB, 4, 80.0)
					if e["hp"] <= 0.0: _kill_enemy(e)

	# Nova pulses
	for i in range(_nova_pulses.size() - 1, -1, -1):
		var n: Dictionary = _nova_pulses[i]
		n["life"] -= dt
		n["r"] = n["max_r"] * (1.0 - n["life"] / n["max_life"])
		if n["life"] <= 0.0: _nova_pulses.remove_at(i); continue
		for e in _enemies:
			if e.get("dead", false): continue
			if _hits(n, e):
				e["hp"] -= _p["bullet_dmg"] * 0.8; e["hit_flash"] = 0.1
				if e["hp"] <= 0.0: _kill_enemy(e)

	# Lightning FX decay
	for i in range(_lfx.size() - 1, -1, -1):
		_lfx[i]["life"] -= dt
		if _lfx[i]["life"] <= 0.0: _lfx.remove_at(i)

	# Particles
	for i in range(_particles.size() - 1, -1, -1):
		var pt: Dictionary = _particles[i]
		pt["x"] += pt["vx"] * dt; pt["y"] += pt["vy"] * dt
		pt["vx"] *= 0.87; pt["vy"] *= 0.87; pt["life"] -= dt
		if pt["life"] <= 0.0: _particles.remove_at(i)

	# Enemy contact damage
	for e in _enemies:
		if e.get("dead", false): continue
		if _p["iframes"] <= 0.0 and _hits(e, _p):
			_p["hp"] = maxf(0.0, _p["hp"] - e["dmg"] * dt * 2.5)
			_p["iframes"] = 1.0
			_emit_particles(_p["x"], _p["y"], Color(1, 0.2, 0.2), 14, 130.0)
			if _p["hp"] <= 0.0: _kill_player()

	# Flush dead enemies
	_enemies = _enemies.filter(func(e): return not e.get("dead", false))

# ── Enemy AI ──────────────────────────────────────────────────
func _update_enemy(e: Dictionary, dt: float) -> void:
	e["hit_flash"] = maxf(0.0, e["hit_flash"] - dt)

	if not e.get("dashing", false):
		var dx := _p["x"] - e["x"]; var dy := _p["y"] - e["y"]
		var len := sqrt(dx * dx + dy * dy)
		if len > 1.0:
			e["x"] += dx / len * e["speed"] * dt
			e["y"] += dy / len * e["speed"] * dt

	if e["is_boss"]:
		_update_boss(e, dt)

	if e["shoot_rate"] > 0.0 and not e.get("is_aiming", false):
		e["shoot_clock"] = e.get("shoot_clock", e["shoot_rate"]) - dt
		if e["shoot_clock"] <= 0.0:
			var enraged := e["is_boss"] and e["hp"] / e["max_hp"] < 0.4
			var ang := atan2(_p["y"] - e["y"], _p["x"] - e["x"])
			var shots := 3 if (e["is_boss"] and enraged) else (2 if (not e["is_boss"] and e["hp"] / e["max_hp"] < 0.4) else 1)
			for s in shots:
				var da := (s - (shots - 1) * 0.5) * 0.28
				_ebullets.append({"x": e["x"], "y": e["y"],
					"vx": cos(ang + da) * 300.0, "vy": sin(ang + da) * 300.0,
					"r": 9.0, "life": 3.5, "dmg": e["dmg"] * 0.7, "insta_kill": false})
			e["shoot_clock"] = e["shoot_rate"] * (0.45 if enraged else 1.0)

func _update_boss(e: Dictionary, dt: float) -> void:
	match e["type"]:
		9:  # Hunter — speed aura + spread burst
			e["abil_a1"] = e.get("abil_a1", 15.0) - dt
			if e["abil_a1"] <= 0.0:
				for en in _enemies:
					if not en.get("dead", false) and not en["is_boss"]:
						en["speed"] = en.get("base_speed", en["speed"]) * 1.05
				_show_msg("Рывок!", "Скорость врагов +5%!")
				_emit_particles(e["x"], e["y"], Color(1, 0.55, 0), 18, 160.0)
				e["abil_a1"] = 15.0
			e["abil_a2"] = e.get("abil_a2", 20.0) - dt
			if e["abil_a2"] <= 0.0:
				var ang := atan2(_p["y"] - e["y"], _p["x"] - e["x"])
				for s in 4:
					var da := (s - 1.5) * 0.28
					_ebullets.append({"x": e["x"], "y": e["y"],
						"vx": cos(ang + da) * 350.0, "vy": sin(ang + da) * 350.0,
						"r": 10.0, "life": 3.5, "dmg": e["dmg"] * 0.85, "insta_kill": false})
				e["abil_a2"] = 20.0

		10: # Colossus — dash charge
			e["abil_a2"] = e.get("abil_a2", 20.0) - dt
			if e["abil_a2"] <= 0.0 and not e.get("dashing", false):
				e["dashing"] = true; e["dash_timer"] = 0.45
				var ang := atan2(_p["y"] - e["y"], _p["x"] - e["x"])
				e["dash_vx"] = cos(ang) * 550.0; e["dash_vy"] = sin(ang) * 550.0
				e["abil_a2"] = 20.0
			if e.get("dashing", false):
				e["dash_timer"] = e.get("dash_timer", 0.0) - dt
				if e["dash_timer"] <= 0.0:
					e["dashing"] = false
				else:
					e["x"] += e.get("dash_vx", 0.0) * dt
					e["y"] += e.get("dash_vy", 0.0) * dt

		11: # Omega — aim-lock shot
			e["abil_a1"] = e.get("abil_a1", 10.0) - dt
			if e["abil_a1"] <= 0.0 and not e.get("is_aiming", false):
				e["is_aiming"] = true
				e["aim_pos"] = {"x": _p["x"], "y": _p["y"]}
				e["aim_timer"] = 3.5; e["aim_locked"] = false; e["aim_shot_delay"] = 0.0
				e["abil_a1"] = 35.0
			if e.get("is_aiming", false):
				e["aim_timer"] = e.get("aim_timer", 0.0) - dt
				if not e.get("aim_locked", false) and e["aim_timer"] < 1.5:
					e["aim_locked"] = true; e["aim_shot_delay"] = 0.4
				if e.get("aim_locked", false):
					e["aim_shot_delay"] = e.get("aim_shot_delay", 0.0) - dt
					if e["aim_shot_delay"] <= 0.0:
						var ap: Dictionary = e["aim_pos"]
						var ang := atan2(ap["y"] - e["y"], ap["x"] - e["x"])
						_ebullets.append({"x": e["x"], "y": e["y"],
							"vx": cos(ang) * 700.0, "vy": sin(ang) * 700.0,
							"r": 14.0, "life": 5.0, "dmg": e["dmg"] * 1.5, "insta_kill": false})
						e["is_aiming"] = false

# ── Weapons ───────────────────────────────────────────────────
func _fire_single(t: Dictionary) -> void:
	var ang := atan2(t["y"] - _p["y"], t["x"] - _p["x"])
	_bullets.append({"x": _p["x"], "y": _p["y"],
		"vx": cos(ang) * 480.0, "vy": sin(ang) * 480.0,
		"r": 6.0, "life": 2.0, "dmg": _p["bullet_dmg"] * 18.0, "pierce": false})

func _fire_shotgun(t: Dictionary) -> void:
	var ang := atan2(t["y"] - _p["y"], t["x"] - _p["x"])
	for s in _p["sg_count"]:
		var da := (s - (_p["sg_count"] - 1) * 0.5) * 0.18
		_bullets.append({"x": _p["x"], "y": _p["y"],
			"vx": cos(ang + da) * 420.0, "vy": sin(ang + da) * 420.0,
			"r": 5.0, "life": 1.2, "dmg": _p["bullet_dmg"] * 10.0 * _p["sg_dmg"],
			"pierce": _p["sg_pierce"]})

func _fire_lightning(t: Dictionary) -> void:
	var cur := t
	var sx := _p["x"]; var sy := _p["y"]
	for _k in _p["light_chain"]:
		cur["hp"] -= _p["bullet_dmg"] * 25.0
		cur["hit_flash"] = 0.15
		_lfx.append({"x1": sx, "y1": sy, "x2": cur["x"], "y2": cur["y"], "life": 0.18})
		_emit_particles(cur["x"], cur["y"], Config.C_LIGHTNING, 6, 100.0)
		if cur["hp"] <= 0.0: _kill_enemy(cur); break
		sx = cur["x"]; sy = cur["y"]
		var nxt := _nearest_to(cur, 160.0)
		if not nxt: break
		cur = nxt

func _fire_nova() -> void:
	_nova_pulses.append({"x": _p["x"], "y": _p["y"],
		"r": 0.0, "max_r": _p["nova_radius"], "life": 0.5, "max_life": 0.5})
	_emit_particles(_p["x"], _p["y"], Config.C_NOVA, 10, 150.0)

# ── Spawning ──────────────────────────────────────────────────
func _spawn_enemy() -> void:
	var a := randf() * TAU
	var d := sqrt(float(W * W + H * H)) * 0.6 + 120.0
	_spawn_enemy_at(Config.pick_pool(Config.get_phase_pool(_wave_time)),
		_p["x"] + cos(a) * d, _p["y"] + sin(a) * d)

func _spawn_enemy_at(type: int, x: float, y: float) -> void:
	var cfg: Dictionary = Config.ECFG[type]
	var m := _wave_time / 60.0
	var hp_mul  := 1.0 if type >= 9 else maxf(1.0, (m - 4.0) * 0.18 + 1.0)
	var dmg_mul := 1.0 if type >= 9 else maxf(1.0, (m - 4.0) * 0.12 + 1.0)
	var e := {
		"type": type, "x": x, "y": y,
		"r": float(cfg["r"]), "speed": float(cfg["speed"]), "base_speed": float(cfg["speed"]),
		"hp": cfg["hp"] * hp_mul, "max_hp": cfg["hp"] * hp_mul,
		"dmg": cfg["dmg"] * dmg_mul, "score": cfg["score"],
		"is_boss": cfg["is_boss"], "is_final": cfg.get("is_final", false),
		"shoot_rate": float(cfg["shoot_rate"]),
		"shoot_clock": float(cfg["shoot_rate"]) * randf_range(0.8, 1.4) if cfg["shoot_rate"] > 0.0 else 0.0,
		"hit_flash": 0.0, "dead": false, "dashing": false,
	}
	if cfg["is_boss"]:
		_active_boss = e
		_show_msg("БОСС: " + cfg.get("boss_name", "БОСС"), "Внимание!")
	_enemies.append(e)

func _spawn_chest() -> void:
	var a := randf() * TAU; var d := randf_range(100.0, 280.0)
	_chests.append({"x": _p["x"] + cos(a) * d, "y": _p["y"] + sin(a) * d, "r": 14.0})

# ── Kill / pickup ─────────────────────────────────────────────
func _kill_enemy(e: Dictionary) -> void:
	if e.get("dead", false): return
	e["dead"] = true
	_p["score"] += e["score"]
	if _p["life_steal"] > 0.0 and randf() < _p["life_steal"]:
		_p["hp"] = minf(_p["max_hp"], _p["hp"] + 5.0)
	_emit_particles(e["x"], e["y"],
		Color(1, 0.4, 0.2) if e["is_boss"] else Color(0.2, 0.27, 0.4),
		25 if e["is_boss"] else 10, 220.0 if e["is_boss"] else 150.0)
	if e["is_boss"]:
		_wrecks.append({"x": e["x"], "y": e["y"], "r": e["r"], "type": e["type"]})
		_spawn_chest()
		if e == _active_boss: _active_boss = null
		_show_msg("Босс повержен!", "+%d очков" % e["score"])
	if e.get("is_final", false):
		_state = GS.WIN

func _kill_player() -> void:
	if _state == GS.OVER or _state == GS.WIN: return
	_p["hp"] = 0.0
	_state = GS.OVER

func _pick_chest() -> void:
	_emit_particles(_p["x"], _p["y"], Config.C_CHEST, 22, 190.0)
	match randi() % 4:
		0: _p["bullet_dmg"] *= 1.3;  _show_msg("Урон +30%!")
		1: _p["fire_rate"]  *= 0.85; _show_msg("Перезарядка -15%!")
		2: _p["speed"]      *= 1.2;  _show_msg("Скорость +20%!")
		3:
			_p["max_hp"] += 40.0
			_p["hp"] = minf(_p["hp"] + 40.0, _p["max_hp"])
			_show_msg("+40 HP!")

# ── Utilities ─────────────────────────────────────────────────
func _nearest_enemy() -> Variant:
	var best = null; var bd := INF
	for e in _enemies:
		if e.get("dead", false): continue
		var d2 := (_p["x"] - e["x"]) ** 2 + (_p["y"] - e["y"]) ** 2
		if d2 < bd: bd = d2; best = e
	return best

func _nearest_to(src: Dictionary, max_d: float) -> Variant:
	var best = null; var bd := INF
	for e in _enemies:
		if e == src or e.get("dead", false): continue
		var d := sqrt((src["x"] - e["x"]) ** 2 + (src["y"] - e["y"]) ** 2)
		if d < max_d and d < bd: bd = d; best = e
	return best

func _hits(a: Dictionary, b: Dictionary) -> bool:
	var dx := a["x"] - b["x"]; var dy := a["y"] - b["y"]
	var sr := a["r"] + b["r"]
	return dx * dx + dy * dy < sr * sr

func _emit_particles(x: float, y: float, col: Color, n: int, spd: float = 120.0) -> void:
	for _i in n:
		var a := randf() * TAU; var v := spd * (0.4 + randf() * 0.8); var l := 0.25 + randf() * 0.5
		_particles.append({"x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v,
			"r": 2.0 + randf() * 3.0, "life": l, "max_life": l, "color": col})

func _show_msg(title: String, sub: String = "") -> void:
	_phase_lbl = title; _phase_sub = sub; _phase_timer = 3.0

# World → screen (manual camera — no Camera2D needed)
func _s(wx: float, wy: float) -> Vector2:
	return Vector2(wx - _p["x"] + W * 0.5, wy - _p["y"] + H * 0.5)

# ── Draw ──────────────────────────────────────────────────────
func _draw() -> void:
	_draw_bg()
	_draw_wrecks()
	_draw_nova()
	_draw_chests()
	_draw_enemies()
	_draw_ebullets()
	_draw_lightning()
	_draw_bullets()
	_draw_orbs()
	_draw_emit_particles()
	_draw_player()
	_draw_hud()
	if _state == GS.PLAY:
		_draw_joystick()
	if _state != GS.PLAY:
		_draw_overlay()

func _draw_joystick() -> void:
	if _joy_tid == -1:
		# Ghost ring at fixed bottom-left position when not active
		var ghost := Vector2(110.0, H - 110.0)
		draw_arc(ghost, JOY_R, 0.0, TAU, 32, Color(1, 1, 1, 0.10), 2.0)
		draw_circle(ghost, 20.0, Color(1, 1, 1, 0.07))
		return
	# Active: draw at anchor position
	draw_arc(_joy_origin, JOY_R, 0.0, TAU, 32, Color(1, 1, 1, 0.22), 2.0)
	var knob := _joy_origin + (_joy_cur - _joy_origin).limit_length(JOY_R)
	draw_circle(_joy_origin, 6.0, Color(1, 1, 1, 0.18))
	draw_circle(knob, 26.0, Color(1, 1, 1, 0.32))

func _draw_bg() -> void:
	draw_rect(Rect2(0, 0, W, H), Config.C_BG)
	var gs := 80.0
	var ox := fmod(-_p.get("x", 0.0), gs); if ox < 0.0: ox += gs
	var oy := fmod(-_p.get("y", 0.0), gs); if oy < 0.0: oy += gs
	var x := ox - gs
	while x < W + gs:
		draw_line(Vector2(x, 0), Vector2(x, H), Config.C_GRID, 1.0)
		x += gs
	var y := oy - gs
	while y < H + gs:
		draw_line(Vector2(0, y), Vector2(W, y), Config.C_GRID, 1.0)
		y += gs

func _draw_player() -> void:
	if _state == GS.OVER or _p.is_empty(): return
	var sp := _s(_p["x"], _p["y"])
	draw_circle(sp, 54.0, Config.C_PLAYER_AURA)
	if _p["iframes"] > 0.0 and int(_p["iframes"] * 8) % 2 == 1:
		return
	draw_circle(sp, 18.0, Config.C_PLAYER)
	draw_arc(sp, 23.0, 0.0, TAU, 32, Color(Config.C_PLAYER, 0.5), 1.5)

func _draw_orbs() -> void:
	if _p.is_empty() or not _p["weapons"].has("orbit"): return
	var sp := _s(_p["x"], _p["y"])
	for oi in _p["orb_count"]:
		var ag := _p["orb_angle"] + oi * (TAU / _p["orb_count"])
		var op := sp + Vector2(cos(ag), sin(ag)) * _p["orb_radius"]
		draw_circle(op, 11.0, Config.C_ORB)
		draw_circle(op, 5.5,  Config.C_ORB_CORE)

func _draw_enemies() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for e in _enemies:
		if e.get("dead", false): continue
		var sp := _s(e["x"], e["y"])
		if sp.x < -300 or sp.x > W + 300 or sp.y < -300 or sp.y > H + 300: continue
		var fl    := e["hit_flash"] > 0.0
		var base  := Color.WHITE if fl else Config.ENEMY_BASE.get(e["type"],  Color(0.15, 0.15, 0.15))
		var accent := Color.WHITE if fl else Config.ENEMY_ACCENT.get(e["type"], Color(0.4, 0.4, 0.5))
		draw_circle(sp, e["r"], base)
		draw_arc(sp, e["r"], 0.0, TAU, 24, accent, 2.0 if e["is_boss"] else 1.5)
		if e["is_boss"]:
			draw_arc(sp, e["r"] + 8.0, t * 1.2, t * 1.2 + TAU * 0.6, 16, Color(accent, 0.45), 3.0)
			if e.get("is_aiming", false) and e.get("aim_pos"):
				var ap: Dictionary = e["aim_pos"]
				var asp := _s(ap["x"], ap["y"])
				var a_col := Color(1, 0, 0, 0.8) if e.get("aim_locked", false) else Color(1, 0.5, 0, 0.5)
				draw_line(sp, asp, a_col, 2.0)
				draw_arc(asp, 18.0, 0.0, TAU, 16, Color(1, 0, 0, 0.7), 2.0)
		if e["is_boss"] or e["hp"] < e["max_hp"]:
			var bw := (e["r"] + 2.0) * 2.0
			var bx := sp.x - bw * 0.5; var by := sp.y + e["r"] + 6.0
			draw_rect(Rect2(bx, by, bw, 6), Color(0.08, 0.08, 0.08, 0.9))
			draw_rect(Rect2(bx, by, bw * (e["hp"] / e["max_hp"]), 6),
				Config.C_BOSS_BAR if e["is_boss"] else Color(0.27, 0.47, 1.0))

func _draw_bullets() -> void:
	for b in _bullets:
		draw_circle(_s(b["x"], b["y"]), b["r"], Config.C_BULLET)

func _draw_ebullets() -> void:
	for b in _ebullets:
		draw_circle(_s(b["x"], b["y"]), b["r"], Config.C_EBULLET)

func _draw_lightning() -> void:
	for fx in _lfx:
		draw_line(_s(fx["x1"], fx["y1"]), _s(fx["x2"], fx["y2"]),
			Color(Config.C_LIGHTNING, fx["life"] / 0.18), 2.0)

func _draw_nova() -> void:
	for n in _nova_pulses:
		draw_arc(_s(n["x"], n["y"]), n["r"], 0.0, TAU, 32,
			Color(Config.C_NOVA, n["life"] / n["max_life"] * 0.7), 3.0)

func _draw_chests() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for ch in _chests:
		var sp := _s(ch["x"], ch["y"])
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		draw_rect(Rect2(sp - Vector2(12, 12), Vector2(24, 24)), Color(Config.C_CHEST, 0.15 + pulse * 0.1))
		draw_rect(Rect2(sp - Vector2(12, 12), Vector2(24, 24)), Color(Config.C_CHEST, 0.4 + pulse * 0.5), false, 2.0)
		draw_line(sp - Vector2(12, 0), sp + Vector2(12, 0), Color(Config.C_CHEST, 0.6), 1.5)

func _draw_wrecks() -> void:
	for w in _wrecks:
		var sp := _s(w["x"], w["y"])
		draw_circle(sp, w["r"], Config.C_WRECK)
		draw_arc(sp, w["r"], 0.0, TAU, 16, Color(0.4, 0.3, 0.2, 0.5), 2.0)

func _draw_emit_particles() -> void:
	for pt in _particles:
		var sp := _s(pt["x"], pt["y"])
		if sp.x < -60 or sp.x > W + 60 or sp.y < -60 or sp.y > H + 60: continue
		draw_circle(sp, pt["r"], Color(pt["color"].r, pt["color"].g, pt["color"].b, pt["life"] / pt["max_life"]))

func _draw_hud() -> void:
	if _state != GS.PLAY or _p.is_empty(): return
	# HP bar
	var hp_pct := _p["hp"] / _p["max_hp"]
	var hp_col := Config.C_HUD_BAD if hp_pct < 0.3 else (Config.C_HUD_WARN if hp_pct < 0.6 else Config.C_HUD_GOOD)
	draw_rect(Rect2(12, 12, 160, 14), Color(0.08, 0.08, 0.08, 0.85))
	draw_rect(Rect2(12, 12, 160.0 * hp_pct, 14), hp_col)
	draw_string(_font, Vector2(12, 10), "HP  %.0f / %.0f" % [_p["hp"], _p["max_hp"]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Config.C_HUD_TEXT)
	# Timer
	var mins := int(_wave_time / 60.0); var secs := int(_wave_time) % 60
	draw_string(_font, Vector2(W - 14, 22), "%d:%02d" % [mins, secs],
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, Config.C_HUD_TITLE)
	draw_string(_font, Vector2(W - 14, 40), "%d pts" % _p["score"],
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Config.C_HUD_TEXT)
	# Boss HP bar
	if _active_boss and not _active_boss.get("dead", false):
		var bw := 400.0; var bx := (W - bw) * 0.5; var by := 12.0
		draw_rect(Rect2(bx, by, bw, 16), Color(0.08, 0.08, 0.08, 0.85))
		draw_rect(Rect2(bx, by, bw * (_active_boss["hp"] / _active_boss["max_hp"]), 16), Config.C_BOSS_BAR)
		draw_string(_font, Vector2(W * 0.5, by - 2.0),
			Config.ECFG[_active_boss["type"]].get("boss_name", "БОСС"),
			HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1, 0.6, 0.3))
	# Phase label
	if _phase_timer > 0.0:
		var a := minf(1.0, _phase_timer)
		draw_string(_font, Vector2(W * 0.5, H * 0.5 - 40.0), _phase_lbl,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(Config.C_CHEST, a))
		if _phase_sub.length() > 0:
			draw_string(_font, Vector2(W * 0.5, H * 0.5 - 12.0), _phase_sub,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(Config.C_HUD_TEXT, a * 0.8))

func _draw_overlay() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.75))
	match _state:
		GS.START:
			draw_string(_font, Vector2(W * 0.5, H * 0.5 - 40.0),
				"ЕРМОЛАЙ: ЗРЯЧИЙ СЛЕПЕЦ", HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Config.C_HUD_TITLE)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 10.0),
				"WASD — движение   •   оружия — автоматически",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Config.C_HUD_TEXT)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 38.0),
				"Enter / Click — начать",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(Config.C_HUD_TEXT, 0.6))
		GS.OVER:
			draw_string(_font, Vector2(W * 0.5, H * 0.5 - 40.0),
				"ПОГИБ", HORIZONTAL_ALIGNMENT_CENTER, -1, 38, Config.C_HUD_BAD)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 10.0),
				"Счёт: %d    Время: %d:%02d" % [_p["score"], int(_wave_time / 60.0), int(_wave_time) % 60],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Config.C_HUD_TEXT)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 45.0),
				"Enter / Click — заново",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(Config.C_HUD_TEXT, 0.6))
		GS.WIN:
			draw_string(_font, Vector2(W * 0.5, H * 0.5 - 40.0),
				"ПОБЕДА!", HORIZONTAL_ALIGNMENT_CENTER, -1, 38, Config.C_HUD_GOOD)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 10.0),
				"Счёт: %d    Время: %d:%02d" % [_p["score"], int(_wave_time / 60.0), int(_wave_time) % 60],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Config.C_HUD_TEXT)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 45.0),
				"Enter / Click — заново",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(Config.C_HUD_TEXT, 0.6))

# ── Input ─────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ENTER:
			if _state != GS.PLAY:
				_init_game()
	elif event is InputEventMouseButton:
		var me := event as InputEventMouseButton
		if me.pressed and me.button_index == MOUSE_BUTTON_LEFT:
			if _state != GS.PLAY:
				_init_game()
	elif event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			if _state != GS.PLAY:
				_init_game()
				return
			# Left half of screen → joystick anchor
			if te.position.x < W * 0.5 and _joy_tid == -1:
				_joy_tid = te.index
				_joy_origin = te.position
				_joy_cur = te.position
				_joy_vec = Vector2.ZERO
		else:
			if te.index == _joy_tid:
				_joy_tid = -1
				_joy_vec = Vector2.ZERO
				_joy_cur = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		if de.index == _joy_tid:
			_joy_cur = de.position
			var delta_pos := _joy_cur - _joy_origin
			var dist := delta_pos.length()
			if dist > JOY_DEAD:
				_joy_vec = delta_pos.normalized() * minf(dist / JOY_R, 1.0)
			else:
				_joy_vec = Vector2.ZERO
