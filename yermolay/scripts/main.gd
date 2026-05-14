extends Node2D

enum GS { START, PLAY, UPGRADE, OVER, WIN, PAUSE }
var _state := GS.START

var _p := {}
var _enemies:     Array = []
var _bullets:     Array = []
var _ebullets:    Array = []
var _particles:   Array = []
var _chests:      Array = []
var _wrecks:      Array = []
var _nova_pulses: Array = []
var _lfx:         Array = []

var _wave_time:      float = 0.0
var _spawn_clock:    float = 0.0
var _bosses_spawned: Array = []
var _active_boss             = null

var _phase_lbl:   String = ""
var _phase_sub:   String = ""
var _phase_timer: float  = 0.0

var _upgrade_choices:  Array = []
var _upgrade_selected: int   = 0

const W: int = 1100
const H: int = 720
var _font: Font

var _tex := {}
const _ENEMY_IMG := {
	0: "enemy_drone", 1: "enemy_inter", 2: "enemy_heavy", 3: "enemy_obs", 4: "enemy_node",
	5: "enemy_berserker", 6: "enemy_titan", 7: "enemy_predator", 8: "enemy_reaper",
	9: "enemy_hunter", 10: "enemy_colossus", 11: "enemy_omega",
}
const _WRECK_IMG := {9: "wreck_hunter", 10: "wreck_colossus", 11: "wreck_omega"}

const JOY_R    := 72.0
const JOY_DEAD := 12.0
var _joy_vec    := Vector2.ZERO
var _joy_origin := Vector2.ZERO
var _joy_cur    := Vector2.ZERO
var _joy_tid    := -1

# ── Init ──────────────────────────────────────────────────────
func _ready() -> void:
	_font = ThemeDB.fallback_font
	_load_textures()
	_state = GS.START

func _load_textures() -> void:
	var names := [
		"player", "bullet", "bullet_shot", "bullet_lightning", "bg_tile",
		"enemy_drone", "enemy_inter", "enemy_heavy", "enemy_obs", "enemy_node",
		"enemy_berserker", "enemy_titan", "enemy_predator", "enemy_reaper",
		"enemy_hunter", "enemy_colossus", "enemy_omega",
		"wreck_hunter", "wreck_colossus", "wreck_omega",
	]
	for n in names:
		var path := "res://assets/images/%s.png" % n
		if ResourceLoader.exists(path):
			_tex[n] = load(path) as Texture2D

func _init_game() -> void:
	_p = {
		"x": 0.0, "y": 0.0, "r": 20.0, "speed": 190.0,
		"hp": 100.0, "max_hp": 100.0, "iframes": 0.0, "upgrade_grace": 0.0, "score": 0,
		"kills": 0, "level": 0, "next_level_kills": 10,
		"contact_flash": 0.0,
		"regen_clock": 3.0, "regen_rate": 3.0,
		"weapons": ["single"],
		"single_clock": 0.0, "single_rate": 1.0,
		"sg_clock": 0.0,     "sg_rate": 1.7,  "sg_count": 5, "sg_dmg": 1.0, "sg_pierce": false,
		"light_clock": 0.0,  "light_rate": 2.6, "light_chain": 3,
		"nova_clock": 0.0,   "nova_rate": 4.0,  "nova_radius": 110.0,
		"orb_angle": 0.0,    "orb_count": 3,    "orb_radius": 82.0, "orb_dmg": 1.0, "orb_cd": {},
		"bullet_dmg": 0.95,  "fire_rate": 1.0,  "life_steal": 0.0,
		"bullet_pierce": false,
		"taken": [],
	}
	_enemies.clear(); _bullets.clear(); _ebullets.clear()
	_particles.clear(); _chests.clear(); _wrecks.clear()
	_nova_pulses.clear(); _lfx.clear()
	_wave_time = 0.0; _spawn_clock = 0.0
	_bosses_spawned.clear(); _active_boss = null; _phase_timer = 0.0
	_upgrade_choices.clear(); _upgrade_selected = 0
	_spawn_chest(); _spawn_chest()
	_state = GS.PLAY
	_show_msg("Фаза I", "Начало...")

# ── Main loop ─────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _state == GS.PLAY:
		_update(delta)
	queue_redraw()

func _update(dt: float) -> void:
	var mv := _joy_vec
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    mv.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  mv.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1.0
	if mv.length_squared() > 0.0:
		mv = mv.normalized() * _p["speed"] * dt
		_p["x"] += mv.x; _p["y"] += mv.y

	_p["iframes"] = maxf(0.0, _p["iframes"] - dt)
	_p["upgrade_grace"] = maxf(0.0, _p["upgrade_grace"] - dt)
	_p["contact_flash"] = maxf(0.0, _p["contact_flash"] - dt)
	_p["regen_clock"] -= dt
	if _p["regen_clock"] <= 0.0:
		_p["hp"] = minf(_p["max_hp"], _p["hp"] + 1.0)
		_p["regen_clock"] = _p["regen_rate"]

	_wave_time += dt
	_phase_timer = maxf(0.0, _phase_timer - dt)

	for sched in Config.BOSS_SCHEDULE:
		if not _bosses_spawned.has(sched["type"]) and _wave_time >= sched["at"]:
			_bosses_spawned.append(sched["type"])
			var a := randf() * TAU
			_spawn_enemy_at(sched["type"], _p["x"] + cos(a) * 700.0, _p["y"] + sin(a) * 700.0)

	_spawn_clock -= dt
	if _spawn_clock <= 0.0:
		var base := 3 if _wave_time > 420 else (2 if _wave_time > 180 else 1)
		for _i in mini(base + int(_wave_time / 180.0), 5):
			_spawn_enemy()
		_spawn_clock = maxf(0.3, 2.0 - _wave_time * 0.012)

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

	# Enemy bullets — iframes and upgrade_grace both protect
	for i in range(_ebullets.size() - 1, -1, -1):
		var b: Dictionary = _ebullets[i]
		b["x"] += b["vx"] * dt; b["y"] += b["vy"] * dt; b["life"] -= dt
		if b["life"] <= 0.0: _ebullets.remove_at(i); continue
		if _p["iframes"] <= 0.0 and _p["upgrade_grace"] <= 0.0 and _hits(b, _p):
			if b.get("insta_kill", false):
				_kill_player()
			else:
				_p["hp"] = maxf(0.0, _p["hp"] - b["dmg"])
				_p["iframes"] = 0.8
				_emit_particles(_p["x"], _p["y"], Color(1, 0.2, 0.2), 8, 100.0)
				if _p["hp"] <= 0.0: _kill_player()
			_ebullets.remove_at(i)

	# Chests — heal on pickup
	for i in range(_chests.size() - 1, -1, -1):
		if _hits(_p, _chests[i]):
			_pick_chest(); _chests.remove_at(i)

	if int(_wave_time) % 25 == 0 and int(_wave_time) != int(_wave_time - dt) and _chests.size() < 8:
		_spawn_chest()

	# Weapons — each fires only within its range
	var fr: float = _p["fire_rate"]

	if _p["weapons"].has("single"):
		_p["single_clock"] -= dt
		var tgt_pistol = _nearest_enemy_in_range(420.0)
		if _p["single_clock"] <= 0.0 and tgt_pistol:
			_fire_single(tgt_pistol); _p["single_clock"] = _p["single_rate"] * fr

	if _p["weapons"].has("shotgun"):
		_p["sg_clock"] -= dt
		var tgt_sg = _nearest_enemy_in_range(200.0)
		if _p["sg_clock"] <= 0.0 and tgt_sg:
			_fire_shotgun(tgt_sg); _p["sg_clock"] = _p["sg_rate"] * fr

	if _p["weapons"].has("lightning"):
		_p["light_clock"] -= dt
		var tgt_light = _nearest_enemy_in_range(300.0)
		if _p["light_clock"] <= 0.0 and tgt_light:
			_fire_lightning(tgt_light); _p["light_clock"] = _p["light_rate"] * fr

	if _p["weapons"].has("nova"):
		_p["nova_clock"] -= dt
		if _p["nova_clock"] <= 0.0:
			if _nearest_enemy_in_range(_p["nova_radius"] * 1.3):
				_fire_nova()
			_p["nova_clock"] = _p["nova_rate"] * fr

	if _p["weapons"].has("orbit"):
		_p["orb_angle"] += dt * 1.6
		for oi in _p["orb_count"]:
			var ag: float = float(_p["orb_angle"]) + oi * (TAU / float(_p["orb_count"]))
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

	for i in range(_lfx.size() - 1, -1, -1):
		_lfx[i]["life"] -= dt
		if _lfx[i]["life"] <= 0.0: _lfx.remove_at(i)

	for i in range(_particles.size() - 1, -1, -1):
		var pt: Dictionary = _particles[i]
		pt["x"] += pt["vx"] * dt; pt["y"] += pt["vy"] * dt
		pt["vx"] *= 0.87; pt["vy"] *= 0.87; pt["life"] -= dt
		if pt["life"] <= 0.0: _particles.remove_at(i)

	# Contact damage — continuous per-frame, no iframes (contact_flash = VFX only)
	for e in _enemies:
		if e.get("dead", false): continue
		if _hits(e, _p):
			_p["hp"] = maxf(0.0, _p["hp"] - e["dmg"] * dt * 2.5)
			if _p["contact_flash"] <= 0.0:
				_emit_particles(_p["x"], _p["y"], Color(1, 0.2, 0.2), 6, 80.0)
				_p["contact_flash"] = 0.15
			if _p["hp"] <= 0.0:
				_kill_player(); break

	_enemies = _enemies.filter(func(e): return not e.get("dead", false))

# ── Enemy AI ──────────────────────────────────────────────────
func _update_enemy(e: Dictionary, dt: float) -> void:
	e["hit_flash"] = maxf(0.0, e["hit_flash"] - dt)

	if not e.get("dashing", false):
		var dx: float = float(_p["x"]) - float(e["x"]); var dy: float = float(_p["y"]) - float(e["y"])
		var len := sqrt(dx * dx + dy * dy)
		if len > 1.0:
			e["x"] += dx / len * e["speed"] * dt
			e["y"] += dy / len * e["speed"] * dt

	if e["is_boss"]:
		_update_boss(e, dt)

	if e["shoot_rate"] > 0.0 and not e.get("is_aiming", false):
		e["shoot_clock"] = e.get("shoot_clock", e["shoot_rate"]) - dt
		if e["shoot_clock"] <= 0.0:
			var enraged: bool = bool(e["is_boss"]) and float(e["hp"]) / float(e["max_hp"]) < 0.4
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
		9:
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
		10:
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
		11:
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
		"r": 6.0, "life": 2.0, "dmg": _p["bullet_dmg"] * 18.0,
		"pierce": _p["bullet_pierce"]})

func _fire_shotgun(t: Dictionary) -> void:
	var ang := atan2(t["y"] - _p["y"], t["x"] - _p["x"])
	for s in _p["sg_count"]:
		var da: float = (s - (float(_p["sg_count"]) - 1.0) * 0.5) * 0.18
		_bullets.append({"x": _p["x"], "y": _p["y"],
			"vx": cos(ang + da) * 420.0, "vy": sin(ang + da) * 420.0,
			"r": 5.0, "life": 1.2, "dmg": _p["bullet_dmg"] * 10.0 * _p["sg_dmg"],
			"pierce": _p["sg_pierce"]})

func _fire_lightning(t: Dictionary) -> void:
	var cur := t
	var sx: float = _p["x"]; var sy: float = _p["y"]
	for _k in _p["light_chain"]:
		cur["hp"] -= _p["bullet_dmg"] * 25.0
		cur["hit_flash"] = 0.15
		_lfx.append({"x1": sx, "y1": sy, "x2": cur["x"], "y2": cur["y"], "life": 0.18})
		_emit_particles(cur["x"], cur["y"], Config.C_LIGHTNING, 6, 100.0)
		if cur["hp"] <= 0.0: _kill_enemy(cur); break
		sx = cur["x"]; sy = cur["y"]
		var nxt = _nearest_to(cur, 160.0)
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
	_p["kills"] += 5 if e["is_boss"] else 1
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
		return
	if _p["kills"] >= _p["next_level_kills"] and _state == GS.PLAY:
		_level_up()

func _kill_player() -> void:
	if _state == GS.OVER or _state == GS.WIN: return
	_p["hp"] = 0.0
	_state = GS.OVER

func _pick_chest() -> void:
	_emit_particles(_p["x"], _p["y"], Config.C_CHEST, 22, 190.0)
	match randi() % 4:
		0:
			_p["bullet_dmg"] *= 1.3
			_show_msg("Урон +30%!", "Пули наносят больше урона")
		1:
			_p["fire_rate"] *= 0.85
			_show_msg("Огонь +15%!", "Стреляешь быстрее")
		2:
			_p["speed"] *= 1.2
			_show_msg("Скорость +20%!", "Двигаешься быстрее")
		3:
			_p["max_hp"] += 40.0
			_p["hp"] = minf(_p["hp"] + 40.0, _p["max_hp"])
			_show_msg("+40 HP!", "Максимальное здоровье растёт")

# ── Upgrade system ────────────────────────────────────────────
func _get_upgrade_pool() -> Array:
	var pool: Array = []
	pool.append({"id": "dmg",         "name": "Патроны",     "desc": "Урон +25%"})
	pool.append({"id": "firerate",    "name": "Темп огня",   "desc": "Скор. стрельбы +15%"})
	pool.append({"id": "speed",       "name": "Ускорение",   "desc": "Движение +20%"})
	pool.append({"id": "hp",          "name": "Броня",       "desc": "+50 Макс. HP"})
	pool.append({"id": "regen",       "name": "Регенерация", "desc": "HP восстан. быстрее"})
	if not _p["weapons"].has("shotgun"):
		pool.append({"id": "shotgun",   "name": "Дробовик",  "desc": "Авто-дробовик (5)"})
	if not _p["weapons"].has("lightning"):
		pool.append({"id": "lightning", "name": "Молния",    "desc": "Цепная (3 врага)"})
	if not _p["weapons"].has("nova"):
		pool.append({"id": "nova",      "name": "Нова",      "desc": "Взрывная волна"})
	if not _p["weapons"].has("orbit"):
		pool.append({"id": "orbit",     "name": "Орбита",    "desc": "3 орбитальных шара"})
	if _p["weapons"].has("shotgun"):
		pool.append({"id": "sg_pellets","name": "Дробь+",    "desc": "Дробовик: дробь +1"})
	if _p["weapons"].has("lightning"):
		pool.append({"id": "light_chain","name": "Молния+",  "desc": "Молния: цепочка +1"})
	if _p["weapons"].has("nova"):
		pool.append({"id": "nova_r",    "name": "Нова+",     "desc": "Нова: радиус +30%"})
	if _p["weapons"].has("orbit"):
		pool.append({"id": "orb_add",   "name": "Орбита+",   "desc": "Орбита: шар +1"})
	if _p["life_steal"] < 0.45:
		pool.append({"id": "lifesteal", "name": "Вампиризм", "desc": "15%: +5HP за убийство"})
	if not _p["bullet_pierce"]:
		pool.append({"id": "pierce",    "name": "Пробитие",  "desc": "Пули бьют 3 врагов"})
	return pool

func _level_up() -> void:
	_p["level"] += 1
	_p["next_level_kills"] += (_p["level"] + 1) * 10
	var pool := _get_upgrade_pool()
	pool.shuffle()
	_upgrade_choices = pool.slice(0, mini(3, pool.size()))
	_upgrade_selected = 0
	_state = GS.UPGRADE

func _apply_upgrade(choice: Dictionary) -> void:
	match choice["id"]:
		"dmg":          _p["bullet_dmg"] *= 1.25
		"firerate":     _p["fire_rate"]  *= 0.85
		"speed":        _p["speed"]      *= 1.2
		"hp":
			_p["max_hp"] += 50.0
			_p["hp"] = minf(_p["hp"] + 50.0, _p["max_hp"])
		"regen":        _p["regen_rate"] = maxf(1.0, _p["regen_rate"] - 0.75)
		"shotgun":      _p["weapons"].append("shotgun")
		"lightning":    _p["weapons"].append("lightning")
		"nova":         _p["weapons"].append("nova")
		"orbit":        _p["weapons"].append("orbit")
		"sg_pellets":   _p["sg_count"] += 1
		"light_chain":  _p["light_chain"] += 1
		"nova_r":       _p["nova_radius"] *= 1.3
		"orb_add":      _p["orb_count"] += 1
		"lifesteal":    _p["life_steal"] = minf(0.6, _p["life_steal"] + 0.15)
		"pierce":       _p["bullet_pierce"] = true
	_show_msg(choice["name"] + "!", choice["desc"])
	_p["upgrade_grace"] = 2.0
	_state = GS.PLAY

# ── Utilities ─────────────────────────────────────────────────
func _nearest_enemy() -> Variant:
	var best = null; var bd := INF
	for e in _enemies:
		if e.get("dead", false): continue
		var d2: float = (float(_p["x"]) - float(e["x"])) ** 2.0 + (float(_p["y"]) - float(e["y"])) ** 2.0
		if d2 < bd: bd = d2; best = e
	return best

func _nearest_enemy_in_range(max_dist: float) -> Variant:
	var best = null; var bd := INF
	var md2 := max_dist * max_dist
	for e in _enemies:
		if e.get("dead", false): continue
		var d2: float = (float(_p["x"]) - float(e["x"])) ** 2.0 + (float(_p["y"]) - float(e["y"])) ** 2.0
		if d2 < md2 and d2 < bd: bd = d2; best = e
	return best

func _nearest_to(src: Dictionary, max_d: float) -> Variant:
	var best = null; var bd := INF
	for e in _enemies:
		if e == src or e.get("dead", false): continue
		var d := sqrt((src["x"] - e["x"]) ** 2 + (src["y"] - e["y"]) ** 2)
		if d < max_d and d < bd: bd = d; best = e
	return best

func _hits(a: Dictionary, b: Dictionary) -> bool:
	var dx: float = float(a["x"]) - float(b["x"]); var dy: float = float(a["y"]) - float(b["y"])
	var sr: float = float(a["r"]) + float(b["r"])
	return dx * dx + dy * dy < sr * sr

func _emit_particles(x: float, y: float, col: Color, n: int, spd: float = 120.0) -> void:
	for _i in n:
		var a := randf() * TAU; var v := spd * (0.4 + randf() * 0.8); var l := 0.25 + randf() * 0.5
		_particles.append({"x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v,
			"r": 2.0 + randf() * 3.0, "life": l, "max_life": l, "color": col})

func _show_msg(title: String, sub: String = "") -> void:
	_phase_lbl = title; _phase_sub = sub; _phase_timer = 3.0

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
		var ghost := Vector2(110.0, H - 110.0)
		draw_arc(ghost, JOY_R, 0.0, TAU, 32, Color(1, 1, 1, 0.10), 2.0)
		draw_circle(ghost, 20.0, Color(1, 1, 1, 0.07))
		return
	draw_arc(_joy_origin, JOY_R, 0.0, TAU, 32, Color(1, 1, 1, 0.22), 2.0)
	var knob := _joy_origin + (_joy_cur - _joy_origin).limit_length(JOY_R)
	draw_circle(_joy_origin, 6.0, Color(1, 1, 1, 0.18))
	draw_circle(knob, 26.0, Color(1, 1, 1, 0.32))

func _draw_bg() -> void:
	if _tex.has("bg_tile"):
		var TW := 1024.0
		var cam_x: float = _p.get("x", 0.0)
		var cam_y: float = _p.get("y", 0.0)
		var tx0 := int(floor((cam_x - W * 0.5) / TW))
		var ty0 := int(floor((cam_y - H * 0.5) / TW))
		var tx1 := int(ceil((cam_x + W * 0.5) / TW))
		var ty1 := int(ceil((cam_y + H * 0.5) / TW))
		for tx in range(tx0, tx1 + 1):
			for ty in range(ty0, ty1 + 1):
				var sx := tx * TW - cam_x + W * 0.5
				var sy := ty * TW - cam_y + H * 0.5
				draw_texture_rect(_tex["bg_tile"], Rect2(sx, sy, TW, TW), false)
	else:
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
	if _p.get("contact_flash", 0.0) > 0.0:
		draw_circle(sp, 24.0, Color(1, 0.15, 0.1, 0.55))
	# Blink only on hit iframes, not upgrade_grace
	if _p["iframes"] > 0.0 and int(_p["iframes"] * 8) % 2 == 1:
		return
	var sz: float = float(_p["r"]) * 3.2
	if _tex.has("player"):
		var flash_mod := Color(2.5, 2.5, 2.5, 1.0) if _p.get("contact_flash", 0.0) > 0.0 else Color.WHITE
		draw_texture_rect(_tex["player"], Rect2(sp.x - sz * 0.5, sp.y - sz * 0.5, sz, sz), false, flash_mod)
	else:
		draw_circle(sp, 18.0, Config.C_PLAYER)
		draw_arc(sp, 23.0, 0.0, TAU, 32, Color(Config.C_PLAYER, 0.5), 1.5)

func _draw_orbs() -> void:
	if _p.is_empty() or not _p["weapons"].has("orbit"): return
	var sp := _s(_p["x"], _p["y"])
	for oi in _p["orb_count"]:
		var ag: float = float(_p["orb_angle"]) + oi * (TAU / float(_p["orb_count"]))
		var op: Vector2 = sp + Vector2(cos(ag), sin(ag)) * float(_p["orb_radius"])
		draw_circle(op, 11.0, Config.C_ORB)
		draw_circle(op, 5.5,  Config.C_ORB_CORE)

func _draw_enemies() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for e in _enemies:
		if e.get("dead", false): continue
		var sp := _s(e["x"], e["y"])
		if sp.x < -300 or sp.x > W + 300 or sp.y < -300 or sp.y > H + 300: continue
		var fl: bool = float(e["hit_flash"]) > 0.0
		var img_key: String = _ENEMY_IMG.get(e["type"], "")
		var accent: Color = Color.WHITE if fl else (Config.ENEMY_ACCENT.get(e["type"], Color(0.4, 0.4, 0.5)) as Color)
		if img_key != "" and _tex.has(img_key):
			var sz: float = float(e["r"]) * 2.8
			var mod := Color(3.0, 3.0, 3.0, 1.0) if fl else Color.WHITE
			draw_texture_rect(_tex[img_key], Rect2(sp.x - sz * 0.5, sp.y - sz * 0.5, sz, sz), false, mod)
		else:
			var base: Color = Color.WHITE if fl else (Config.ENEMY_BASE.get(e["type"], Color(0.15, 0.15, 0.15)) as Color)
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
			var bw: float = (float(e["r"]) + 2.0) * 2.0
			var bx: float = sp.x - bw * 0.5; var by: float = sp.y + float(e["r"]) + 6.0
			draw_rect(Rect2(bx, by, bw, 6), Color(0.08, 0.08, 0.08, 0.9))
			draw_rect(Rect2(bx, by, bw * (e["hp"] / e["max_hp"]), 6),
				Config.C_BOSS_BAR if e["is_boss"] else Color(0.27, 0.47, 1.0))

func _draw_bullets() -> void:
	for b in _bullets:
		var sp := _s(b["x"], b["y"])
		if _tex.has("bullet"):
			var sz: float = float(b["r"]) * 3.2
			draw_texture_rect(_tex["bullet"], Rect2(sp.x - sz * 0.5, sp.y - sz * 0.5, sz, sz), false)
		else:
			draw_circle(sp, b["r"], Config.C_BULLET)

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
		var c := Color(Config.C_CHEST, 0.15 + pulse * 0.1)
		var ce := Color(Config.C_CHEST, 0.45 + pulse * 0.5)
		# Body
		draw_rect(Rect2(sp - Vector2(14, 10), Vector2(28, 20)), c)
		draw_rect(Rect2(sp - Vector2(14, 10), Vector2(28, 20)), ce, false, 2.0)
		# Lid
		draw_rect(Rect2(sp - Vector2(14, 14), Vector2(28, 8)), Color(c, c.a * 1.3))
		draw_rect(Rect2(sp - Vector2(14, 14), Vector2(28, 8)), ce, false, 2.0)
		# Horizontal stripe
		draw_line(sp - Vector2(12, 2), sp + Vector2(12, -2), Color(Config.C_CHEST, 0.6 + pulse * 0.3), 1.5)
		# Lock
		draw_circle(sp + Vector2(0, 2), 3.5, Color(Config.C_CHEST, 0.9))
		# Corner rivets
		for rv in [Vector2(-11, -9), Vector2(11, -9), Vector2(-11, 8), Vector2(11, 8)]:
			draw_circle(sp + rv, 2.0, Color(Config.C_CHEST, 0.7))

func _draw_wrecks() -> void:
	for w in _wrecks:
		var sp := _s(w["x"], w["y"])
		var wkey: String = _WRECK_IMG.get(w["type"], "")
		if wkey != "" and _tex.has(wkey):
			var sz := float(w["r"]) * 2.8
			draw_texture_rect(_tex[wkey], Rect2(sp.x - sz * 0.5, sp.y - sz * 0.5, sz, sz), false, Color(1, 1, 1, 0.5))
		else:
			draw_circle(sp, w["r"], Config.C_WRECK)
			draw_arc(sp, w["r"], 0.0, TAU, 16, Color(0.4, 0.3, 0.2, 0.5), 2.0)

func _draw_emit_particles() -> void:
	for pt in _particles:
		var sp := _s(pt["x"], pt["y"])
		if sp.x < -60 or sp.x > W + 60 or sp.y < -60 or sp.y > H + 60: continue
		draw_circle(sp, pt["r"], Color(pt["color"].r, pt["color"].g, pt["color"].b, pt["life"] / pt["max_life"]))

func _draw_hud() -> void:
	if _state != GS.PLAY or _p.is_empty(): return
	# HP bar — top-left
	var hp_pct: float = float(_p["hp"]) / float(_p["max_hp"])
	var hp_col := Config.C_HUD_BAD if hp_pct < 0.3 else (Config.C_HUD_WARN if hp_pct < 0.6 else Config.C_HUD_GOOD)
	draw_rect(Rect2(12, 12, 160, 14), Color(0.08, 0.08, 0.08, 0.85))
	draw_rect(Rect2(12, 12, 160.0 * hp_pct, 14), hp_col)
	draw_string(_font, Vector2(12, 10), "HP  %.0f / %.0f" % [_p["hp"], _p["max_hp"]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Config.C_HUD_TEXT)
	# Timer / stats — top-right with semi-transparent backing panel
	var rx := W - 8.0
	var pw := 160.0
	draw_rect(Rect2(rx - pw - 4.0, 6.0, pw + 8.0, 76.0), Color(0.0, 0.0, 0.0, 0.65))
	var mins := int(_wave_time / 60.0); var secs := int(_wave_time) % 60
	draw_string(_font, Vector2(rx - pw, 22), "%d:%02d" % [mins, secs],
		HORIZONTAL_ALIGNMENT_RIGHT, pw, 16, Config.C_HUD_TITLE)
	draw_string(_font, Vector2(rx - pw, 40), "%d pts" % _p["score"],
		HORIZONTAL_ALIGNMENT_RIGHT, pw, 12, Config.C_HUD_TEXT)
	draw_string(_font, Vector2(rx - pw, 57), "Убито: %d   Ур.%d" % [_p["kills"], _p["level"]],
		HORIZONTAL_ALIGNMENT_RIGHT, pw, 11, Config.C_HUD_TEXT)
	var kills_left: int = _p["next_level_kills"] - _p["kills"]
	draw_string(_font, Vector2(rx - pw, 72), "До ур.: %d" % kills_left,
		HORIZONTAL_ALIGNMENT_RIGHT, pw, 10, Color(Config.C_HUD_TEXT, 0.5))
	# Boss bar — top-center
	if _active_boss and not _active_boss.get("dead", false):
		var bw := 400.0; var bx := (W - bw) * 0.5; var by := 12.0
		draw_rect(Rect2(bx, by, bw, 16), Color(0.08, 0.08, 0.08, 0.85))
		draw_rect(Rect2(bx, by, bw * (_active_boss["hp"] / _active_boss["max_hp"]), 16), Config.C_BOSS_BAR)
		draw_string(_font, Vector2(W * 0.5, by - 2.0),
			Config.ECFG[_active_boss["type"]].get("boss_name", "БОСС"),
			HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1, 0.6, 0.3))
	# Notifications — bottom-center, away from player
	if _phase_timer > 0.0:
		var a := minf(1.0, _phase_timer)
		draw_string(_font, Vector2(W * 0.5, H - 72.0), _phase_lbl,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(Config.C_CHEST, a))
		if _phase_sub.length() > 0:
			draw_string(_font, Vector2(W * 0.5, H - 44.0), _phase_sub,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(Config.C_HUD_TEXT, a * 0.8))

func _draw_upgrade_icon(id: String, cx: float, cy: float) -> void:
	var sz := 26.0
	match id:
		"dmg":
			draw_circle(Vector2(cx, cy), sz * 0.28, Config.C_BULLET)
			draw_line(Vector2(cx - sz * 0.55, cy), Vector2(cx + sz * 0.55, cy), Config.C_BULLET, 3.0)
		"firerate":
			draw_arc(Vector2(cx, cy), sz * 0.45, 0.0, TAU, 20, Config.C_HUD_TITLE, 2.5)
			draw_line(Vector2(cx, cy), Vector2(cx + sz * 0.3, cy - sz * 0.3), Config.C_HUD_TITLE, 2.5)
			draw_circle(Vector2(cx, cy), sz * 0.08, Config.C_HUD_TITLE)
		"speed":
			var pts := PackedVector2Array([
				Vector2(cx - sz * 0.15, cy - sz * 0.5),
				Vector2(cx + sz * 0.25, cy - sz * 0.05),
				Vector2(cx - sz * 0.08, cy - sz * 0.05),
				Vector2(cx + sz * 0.32, cy + sz * 0.5)
			])
			draw_polyline(pts, Config.C_HUD_GOOD, 3.5)
		"hp":
			var hh := sz * 0.38
			draw_rect(Rect2(cx - sz * 0.13, cy - hh, sz * 0.26, hh * 2.0), Config.C_HUD_BAD)
			draw_rect(Rect2(cx - hh, cy - sz * 0.13, hh * 2.0, sz * 0.26), Config.C_HUD_BAD)
		"regen":
			draw_arc(Vector2(cx, cy), sz * 0.45, -PI * 0.2, PI * 1.8, 20, Config.C_HUD_GOOD, 3.0)
			draw_line(Vector2(cx + sz * 0.4, cy - sz * 0.1), Vector2(cx + sz * 0.45, cy + sz * 0.2), Config.C_HUD_GOOD, 3.0)
			draw_circle(Vector2(cx, cy), sz * 0.14, Color(Config.C_HUD_GOOD, 0.5))
		"shotgun":
			for i in 5:
				var ang := -0.38 + i * 0.19
				draw_line(Vector2(cx - sz * 0.25, cy),
					Vector2(cx + cos(ang) * sz * 0.55, cy + sin(ang) * sz * 0.55), Config.C_BULLET, 2.0)
			draw_rect(Rect2(cx - sz * 0.35, cy - sz * 0.1, sz * 0.12, sz * 0.2), Config.C_HUD_TEXT)
		"lightning":
			var lpts := PackedVector2Array([
				Vector2(cx + sz * 0.15, cy - sz * 0.5),
				Vector2(cx - sz * 0.12, cy - sz * 0.04),
				Vector2(cx + sz * 0.06, cy - sz * 0.04),
				Vector2(cx - sz * 0.18, cy + sz * 0.5)
			])
			draw_polyline(lpts, Config.C_LIGHTNING, 3.5)
		"nova":
			for i in 3:
				draw_arc(Vector2(cx, cy), sz * (0.18 + i * 0.14), 0.0, TAU, 16,
					Color(Config.C_NOVA, 0.7 - i * 0.18), 2.0)
		"orbit":
			draw_arc(Vector2(cx, cy), sz * 0.48, 0.0, TAU, 24, Color(Config.C_ORB, 0.55), 2.0)
			for i in 3:
				var a := i * TAU / 3.0
				draw_circle(Vector2(cx + cos(a) * sz * 0.48, cy + sin(a) * sz * 0.48), sz * 0.12, Config.C_ORB_CORE)
		"sg_pellets":
			for i in 6:
				var a := i * TAU / 6.0
				draw_circle(Vector2(cx + cos(a) * sz * 0.38, cy + sin(a) * sz * 0.38), sz * 0.1, Config.C_BULLET)
			draw_circle(Vector2(cx, cy), sz * 0.1, Config.C_BULLET)
		"light_chain":
			for i in 3:
				draw_arc(Vector2(cx - sz * 0.32 + i * sz * 0.32, cy), sz * 0.16, 0.0, TAU, 10, Config.C_LIGHTNING, 2.5)
			for i in 2:
				draw_line(Vector2(cx - sz * 0.16 + i * sz * 0.32, cy - sz * 0.16),
					Vector2(cx - sz * 0.16 + i * sz * 0.32, cy + sz * 0.16), Config.C_LIGHTNING, 2.0)
		"nova_r":
			draw_arc(Vector2(cx, cy), sz * 0.52, 0.0, TAU, 24, Config.C_NOVA, 3.5)
			draw_arc(Vector2(cx, cy), sz * 0.28, 0.0, TAU, 16, Color(Config.C_NOVA, 0.55), 2.0)
		"orb_add":
			draw_arc(Vector2(cx, cy), sz * 0.38, 0.0, TAU, 20, Color(Config.C_ORB, 0.55), 2.0)
			for i in 3:
				var a := i * TAU / 3.0
				draw_circle(Vector2(cx + cos(a) * sz * 0.38, cy + sin(a) * sz * 0.38), sz * 0.1, Config.C_ORB_CORE)
			var px := cx + sz * 0.52
			draw_line(Vector2(px - sz * 0.14, cy), Vector2(px + sz * 0.14, cy), Config.C_ORB_CORE, 2.5)
			draw_line(Vector2(px, cy - sz * 0.14), Vector2(px, cy + sz * 0.14), Config.C_ORB_CORE, 2.5)
		"lifesteal":
			draw_arc(Vector2(cx - sz * 0.17, cy - sz * 0.1), sz * 0.24, PI, 0.0, 16, Config.C_HUD_BAD, 3.0)
			draw_arc(Vector2(cx + sz * 0.17, cy - sz * 0.1), sz * 0.24, PI, 0.0, 16, Config.C_HUD_BAD, 3.0)
			var hpts := PackedVector2Array([
				Vector2(cx - sz * 0.42, cy - sz * 0.1),
				Vector2(cx, cy + sz * 0.5),
				Vector2(cx + sz * 0.42, cy - sz * 0.1)
			])
			draw_polyline(hpts, Config.C_HUD_BAD, 3.0)
		"pierce":
			draw_line(Vector2(cx - sz * 0.55, cy), Vector2(cx + sz * 0.55, cy), Config.C_BULLET, 3.0)
			draw_line(Vector2(cx + sz * 0.3, cy - sz * 0.25), Vector2(cx + sz * 0.55, cy), Config.C_BULLET, 3.0)
			draw_line(Vector2(cx + sz * 0.3, cy + sz * 0.25), Vector2(cx + sz * 0.55, cy), Config.C_BULLET, 3.0)
			for i in 3:
				draw_circle(Vector2(cx - sz * 0.3 + i * sz * 0.28, cy), sz * 0.08, Color(Config.C_BULLET, 0.45))

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
		GS.UPGRADE:
			draw_string(_font, Vector2(W * 0.5, 110.0),
				"УРОВЕНЬ %d" % _p["level"],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 34, Config.C_HUD_TITLE)
			draw_string(_font, Vector2(W * 0.5, 152.0),
				"Выберите улучшение",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(Config.C_HUD_TEXT, 0.85))
			# 3 square cards in a horizontal row
			var card_w := 200.0
			var card_h := 210.0
			var gap    := 24.0
			var total  := _upgrade_choices.size() * card_w + (_upgrade_choices.size() - 1) * gap
			var start_x := (W - total) * 0.5
			var card_y  := 185.0
			for i in _upgrade_choices.size():
				var ch: Dictionary = _upgrade_choices[i]
				var bx := start_x + i * (card_w + gap)
				var bg := Color(0.12, 0.18, 0.38, 0.95)
				draw_rect(Rect2(bx, card_y, card_w, card_h), bg)
				draw_rect(Rect2(bx, card_y, card_w, card_h), Color(Config.C_HUD_TEXT, 0.38), false, 2.0)
				# Number badge — pos.x=bx+6, width=22 → centered in badge rect
				draw_rect(Rect2(bx + 6.0, card_y + 6.0, 22.0, 22.0), Color(0.3, 0.4, 0.7, 0.8))
				draw_string(_font, Vector2(bx + 6.0, card_y + 22.0), str(i + 1),
					HORIZONTAL_ALIGNMENT_CENTER, 22.0, 13, Color.WHITE)
				# Icon centered in upper half
				var icon_cx := bx + card_w * 0.5
				var icon_cy := card_y + 82.0
				draw_circle(Vector2(icon_cx, icon_cy), 38.0, Color(0.06, 0.1, 0.25, 0.9))
				draw_arc(Vector2(icon_cx, icon_cy), 38.0, 0.0, TAU, 24, Color(Config.C_HUD_TEXT, 0.3), 1.5)
				_draw_upgrade_icon(ch["id"], icon_cx, icon_cy)
				# Name — pos.x=bx+6 (left edge), width=card_w-12 → centered within card
				draw_string(_font, Vector2(bx + 6.0, card_y + 143.0), ch["name"],
					HORIZONTAL_ALIGNMENT_CENTER, card_w - 12.0, 15, Color.WHITE)
				# Desc
				draw_string(_font, Vector2(bx + 6.0, card_y + 166.0), ch["desc"],
					HORIZONTAL_ALIGNMENT_CENTER, card_w - 12.0, 11, Color(Config.C_HUD_TEXT, 0.75))
			draw_string(_font, Vector2(W * 0.5, card_y + card_h + 22.0),
				"Клавиши  1 / 2 / 3  или  нажмите карточку",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(Config.C_HUD_TEXT, 0.4))
		GS.PAUSE:
			draw_string(_font, Vector2(W * 0.5, H * 0.5 - 50.0),
				"ПАУЗА", HORIZONTAL_ALIGNMENT_CENTER, -1, 42, Config.C_HUD_TITLE)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 8.0),
				"Счёт: %d    Время: %d:%02d    Ур.%d" % [_p["score"], int(_wave_time / 60.0), int(_wave_time) % 60, _p["level"]],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Config.C_HUD_TEXT)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 46.0),
				"Esc — продолжить    •    Enter — в меню",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(Config.C_HUD_TEXT, 0.6))
		GS.OVER:
			draw_string(_font, Vector2(W * 0.5, H * 0.5 - 40.0),
				"ПОГИБ", HORIZONTAL_ALIGNMENT_CENTER, -1, 38, Config.C_HUD_BAD)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 10.0),
				"Счёт: %d    Время: %d:%02d    Ур.%d" % [_p["score"], int(_wave_time / 60.0), int(_wave_time) % 60, _p["level"]],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Config.C_HUD_TEXT)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 45.0),
				"Enter / Click — заново",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(Config.C_HUD_TEXT, 0.6))
		GS.WIN:
			draw_string(_font, Vector2(W * 0.5, H * 0.5 - 40.0),
				"ПОБЕДА!", HORIZONTAL_ALIGNMENT_CENTER, -1, 38, Config.C_HUD_GOOD)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 10.0),
				"Счёт: %d    Время: %d:%02d    Ур.%d" % [_p["score"], int(_wave_time / 60.0), int(_wave_time) % 60, _p["level"]],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Config.C_HUD_TEXT)
			draw_string(_font, Vector2(W * 0.5, H * 0.5 + 45.0),
				"Enter / Click — заново",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(Config.C_HUD_TEXT, 0.6))

# ── Input ─────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if _state == GS.UPGRADE:
		_handle_upgrade_input(event)
		return

	if _state == GS.PAUSE:
		if event is InputEventKey and (event as InputEventKey).pressed:
			var ke := event as InputEventKey
			if ke.keycode == KEY_ESCAPE:
				_state = GS.PLAY
			elif ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
				_state = GS.START
		elif event is InputEventMouseButton:
			var me := event as InputEventMouseButton
			if me.pressed and me.button_index == MOUSE_BUTTON_LEFT:
				_state = GS.PLAY
		elif event is InputEventScreenTouch:
			if (event as InputEventScreenTouch).pressed:
				_state = GS.PLAY
		return

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed:
			match ke.keycode:
				KEY_ENTER, KEY_KP_ENTER:
					if _state == GS.START or _state == GS.OVER or _state == GS.WIN:
						_init_game()
				KEY_ESCAPE:
					if _state == GS.PLAY:
						_state = GS.PAUSE
	elif event is InputEventMouseButton:
		var me := event as InputEventMouseButton
		if me.pressed and me.button_index == MOUSE_BUTTON_LEFT:
			if _state == GS.START or _state == GS.OVER or _state == GS.WIN:
				_init_game()
	elif event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			if _state == GS.START or _state == GS.OVER or _state == GS.WIN:
				_init_game()
				return
			if _state == GS.PLAY and te.position.x < W * 0.5 and _joy_tid == -1:
				_joy_tid = te.index
				_joy_origin = te.position
				_joy_cur = te.position
				_joy_vec = Vector2.ZERO
		else:
			if te.index == _joy_tid:
				_joy_tid = -1; _joy_vec = Vector2.ZERO; _joy_cur = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		if de.index == _joy_tid:
			_joy_cur = de.position
			var delta_pos := _joy_cur - _joy_origin
			var dist := delta_pos.length()
			_joy_vec = delta_pos.normalized() * minf(dist / JOY_R, 1.0) if dist > JOY_DEAD else Vector2.ZERO

func _handle_upgrade_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		var ke := event as InputEventKey
		match ke.keycode:
			KEY_1:
				if _upgrade_choices.size() > 0: _apply_upgrade(_upgrade_choices[0])
			KEY_2:
				if _upgrade_choices.size() > 1: _apply_upgrade(_upgrade_choices[1])
			KEY_3:
				if _upgrade_choices.size() > 2: _apply_upgrade(_upgrade_choices[2])
	elif event is InputEventMouseButton:
		var me := event as InputEventMouseButton
		if me.pressed and me.button_index == MOUSE_BUTTON_LEFT:
			_try_tap_upgrade(me.position)
	elif event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			_try_tap_upgrade(te.position)

func _try_tap_upgrade(pos: Vector2) -> void:
	var card_w := 200.0
	var card_h := 210.0
	var gap    := 24.0
	var total  := _upgrade_choices.size() * card_w + (_upgrade_choices.size() - 1) * gap
	var start_x := (W - total) * 0.5
	var card_y  := 185.0
	for i in _upgrade_choices.size():
		var bx := start_x + i * (card_w + gap)
		if Rect2(bx, card_y, card_w, card_h).has_point(pos):
			_apply_upgrade(_upgrade_choices[i]); return
