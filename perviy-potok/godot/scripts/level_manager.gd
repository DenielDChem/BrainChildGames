extends Node2D

var platforms: Array[Dictionary] = []
var orbs: Array[Dictionary] = []
var records: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var portals: Array[Dictionary] = []
var swarm_nodes: Array[Dictionary] = []
var drones: Array[Dictionary] = []

var secret_opened: bool = false
var portal_phase: float = 0.0
var _time: float = 0.0
var _hit_timer: float = 0.0

var _platform_bodies: Array = []

signal portal_entered(to_level: int)

func _ready() -> void:
	_build_level(GameState.current_level)

func _build_level(lvl: int) -> void:
	for body in _platform_bodies:
		body.queue_free()
	_platform_bodies.clear()
	for d in drones:
		var body: AnimatableBody2D = d.get("body") as AnimatableBody2D
		if body:
			body.queue_free()
	platforms.clear(); orbs.clear(); records.clear()
	animals.clear(); hazards.clear(); portals.clear()
	swarm_nodes.clear(); drones.clear()
	secret_opened = false
	_hit_timer = 0.0
	match lvl:
		0: _build_walk()
		1: _build_jump()
		2: _build_flight()
	for p in platforms:
		if not (p["secret"] and not p["open"]):
			_create_platform_body(p)
	for d in drones:
		if d["type"] == "platform":
			_create_drone_body(d)

func _physics_process(delta: float) -> void:
	_time += delta
	_hit_timer = maxf(0.0, _hit_timer - delta)
	for d in drones:
		var offset: float = sin(_time * float(d["speed"]) + float(d["phase"])) * float(d["amplitude"])
		var nx: float = float(d["bx"]) + (offset if d["axis"] == "x" else 0.0)
		var ny: float = float(d["by"]) + (offset if d["axis"] == "y" else 0.0)
		d["cx"] = nx
		d["cy"] = ny
		if d["type"] == "platform":
			var body: AnimatableBody2D = d.get("body") as AnimatableBody2D
			if body:
				var _c := body.move_and_collide(Vector2(nx, ny) - body.position)

func _process(delta: float) -> void:
	portal_phase += delta
	for po in portals:
		po["phase"] = portal_phase

# ── Level 0: Walk / Metroidvania ────────────────────────────────
# Bear (shield) → fork: false upper path vs true lower route
# Fox → secret platforms bridge false path, unlock Orb2
# Cat → double jump needed to reach Key ledge

func _build_walk() -> void:
	_plat(-200, 750, 760, 200, "ground")

	# Start ramp — Bear sits here before the fork
	_plat(580, 695, 130, 22, "earth")
	_plat(770, 668, 140, 22, "earth")   # Bear

	# FALSE upper branch: visually tempting, hazard at dead end
	_plat(960, 622, 100, 22, "earth")
	_plat(1115, 572, 90, 22, "earth")
	_plat(1255, 518, 80, 22, "earth")   # dead end — hazard blocks

	# TRUE lower route: less obvious, eventually finds Fox
	_plat(940, 658, 120, 22, "earth")
	_plat(1140, 638, 125, 22, "earth")
	_plat(1360, 615, 135, 22, "earth")
	_plat(1580, 588, 145, 22, "earth")  # Fox

	# SECRET platforms (Fox unlocks): bridge across false-path dead end
	_plat(1260, 530, 115, 22, "secret", true)
	_plat(1495, 486, 115, 22, "secret", true)
	_plat(1730, 442, 115, 22, "secret", true)

	# Mid-game ascent
	_plat(1820, 560, 140, 22, "earth")
	_plat(2060, 522, 130, 22, "earth")  # Cat
	_plat(2315, 480, 120, 22, "earth")
	_plat(2560, 432, 110, 22, "earth")
	_plat(2800, 378, 100, 22, "earth")
	_plat(3035, 322, 100, 22, "earth")
	_plat(3260, 264, 100, 22, "earth")

	# Key ledge — Cat double-jump required to clear the last gap
	_plat(3475, 202, 100, 22, "earth")

	_plat(3700, 158, 120, 22, "earth")

	# Hazard at false-path dead end
	_hazard(1255, 496, 80, 22, "holder")

	# Orbs — 3 needed; Orb2 is Fox-gated via secret platforms
	_orb(960, 620)
	_orb(1745, 415)   # on Sec3 — Fox route only
	_orb(2570, 402)

	_key(3488, 160)

	_record(800, 638, "Медведь-Основа",
		"Медведь держит рубеж. Щит — не броня: это умение остановиться.")
	_record(980, 628, "Первый Предел",
		"Земля поднимает тех, кто не торопится наверх.", "bear")
	_record(1600, 558, "Лисий обход",
		"Лиса открывает скрытую тропу. Верхний путь был закрыт — теперь нет.", "fox")
	_record(2330, 450, "Кот в Вышине",
		"Кот прыгает туда, где нет правил. Второй прыжок — решение.", "cat")

	_animal(810, 636, "bear", "Медведь", "Медведь даёт 1 щит.", 1)
	_animal(1615, 555, "fox", "Лиса", "Лиса открывает тайные тропы.", 0)
	_animal(2095, 490, "cat", "Кот", "Кот даёт второй прыжок.", 0)

	_portal(3890, 50, 220, 720, 1)

# ── Level 1: Jump / Drones ──────────────────────────────────────
# Narrower platforms, wider gaps; platform drones bridge two gaps
# Hazard drones patrol three danger zones
# Raven → orb lines; Fox → secrets; Cat → 2 shields; Wolf → 2 shields

func _build_jump() -> void:
	_plat(-200, 778, 380, 200, "ground")

	_plat(180, 718, 110, 24, "cloud")   # Raven
	_plat(370, 682, 100, 24, "cloud")
	_plat(568, 644, 90, 24, "cloud")
	# gap — platform drone 1 bridges here
	_plat(790, 605, 90, 24, "cloud")
	_plat(988, 564, 90, 24, "cloud")    # Fox
	_plat(1182, 523, 85, 24, "cloud")

	# Secret platforms (Fox-gated)
	_plat(1108, 443, 100, 22, "secret", true)
	_plat(1348, 400, 100, 22, "secret", true)
	_plat(1588, 357, 100, 22, "secret", true)

	_plat(1398, 480, 85, 24, "cloud")
	_plat(1596, 438, 85, 24, "cloud")   # Cat
	_plat(1806, 396, 80, 24, "cloud")
	_plat(2028, 355, 80, 24, "cloud")
	# gap — platform drone 2 bridges here
	_plat(2308, 315, 85, 24, "cloud")   # Wolf
	_plat(2506, 274, 80, 24, "cloud")
	_plat(2704, 233, 80, 24, "cloud")
	_plat(2914, 192, 80, 24, "cloud")
	_plat(3132, 151, 80, 24, "cloud")
	_plat(3352, 114, 80, 24, "cloud")
	_plat(3578, 80, 100, 24, "cloud")

	# Static hazard tile on N platform (punishes careless landing)
	_hazard(2704, 211, 80, 22, "break")

	# Orbs — 4 needed
	_orb(180, 680)
	_orb(568, 606)
	_orb(1840, 360)
	_orb(3148, 116)

	_key(3594, 38)

	_record(205, 690, "Поток",
		"Прыжок — переговоры со средой. Тело знает дальше, чем глаза.")
	_record(848, 572, "Ворон-Следопыт",
		"Ворон видит не предмет, а траекторию.", "raven")
	_record(1414, 448, "Кот и Щит",
		"Кот прыгает. Два щита — чтобы было место для ошибки.", "cat")
	_record(2720, 200, "Волчья Сеть",
		"Волк различает, что движется, а что только кажется опасным.", "wolf")

	_animal(218, 685, "raven", "Ворон", "Зрение Ворона: орбы и записи светятся линиями.", 0)
	_animal(1026, 531, "fox", "Лиса", "Лиса открывает скрытый верхний путь.", 0)
	_animal(1634, 404, "cat", "Кот", "Кот даёт второй прыжок и 2 щита.", 2)
	_animal(2346, 281, "wolf", "Волк", "Волк даёт 2 щита и глушит опасные дроны.", 2)

	# Platform drones (helper — AnimatableBody2D)
	_drone(679, 622, "platform", "x", 82.0, 1.2)    # bridges C→D gap
	_drone(2168, 333, "platform", "x", 102.0, 1.4)  # bridges J→K gap

	# Hazard drones
	_drone(1182, 468, "hazard", "y", 56.0, 1.9)     # vertical at F zone
	_drone(2506, 240, "hazard", "y", 66.0, 2.1)     # vertical at L zone
	_drone(2914, 158, "hazard", "x", 88.0, 1.7)     # horizontal at N zone

	_portal(3870, -20, 220, 700, 2)

# ── Level 2: Flight / Bidirectional ─────────────────────────────
# No platforms. Tap = impulse up, hold = sustained lift, release = fall.
# Two orbs are LEFT of spawn (x<220) — player must fly back to collect.
# Swarm zones form corridors; Wolf buff removes them from view.

func _build_flight() -> void:
	# Orbs — 4 needed out of 6; Orb1-2 are left of spawn at x=220
	_orb(65, 278)       # far left — backtrack required
	_orb(168, 462)      # slightly left
	_orb(698, 258)
	_orb(1398, 492)
	_orb(2198, 302)
	_orb(3098, 456)

	_key(3678, 276)

	_record(452, 582, "Рой",
		"Рой движется как целое. Держись своего движения.")
	_record(658, 432, "Волк-Навигатор",
		"Волк знает сеть. Видеть её — уже не бояться.", "wolf")
	_record(1802, 532, "Интенсивность",
		"Не скорость — интенсивность. Частота взмахов определяет высоту.")
	_record(2582, 412, "Ворон в Небе",
		"Ворон показывает путь через Рой.", "raven")

	_animal(658, 398, "wolf", "Волк",
		"Волк отгоняет Рой и даёт 2 щита.", 2)
	_animal(2542, 368, "raven", "Ворон",
		"Ворон подсвечивает путь к выходу.", 0)

	# Swarm corridors — pairs create high/low gaps the player threads through
	_swarm(598, 538, 40, 0.4)
	_swarm(898, 198, 38, 0.35)
	_swarm(1298, 558, 45, 0.45)
	_swarm(1698, 198, 42, 0.4)
	_swarm(2098, 558, 40, 0.38)
	_swarm(2498, 248, 44, 0.42)
	_swarm(2898, 578, 38, 0.36)
	_swarm(3298, 198, 42, 0.4)

	_portal(3870, 48, 220, 700, 3)

# ── Factories ────────────────────────────────────────────────────

func _plat(x: float, y: float, w: float, h: float, type: String, secret: bool = false) -> void:
	platforms.append({"x": x, "y": y, "w": w, "h": h, "type": type, "secret": secret, "open": not secret})

func _orb(x: float, y: float) -> void:
	orbs.append({"x": x, "y": y, "w": 32.0, "h": 32.0, "taken": false})

func _key(x: float, y: float) -> void:
	records.append({"x": x, "y": y, "w": 42.0, "h": 42.0, "type": "key", "taken": false,
		"title": "Ключ", "text": "Переход услышал тебя."})

func _record(x: float, y: float, title: String, text: String, animal_kind: String = "") -> void:
	records.append({"x": x, "y": y, "w": 42.0, "h": 42.0, "type": "record", "taken": false,
		"title": title, "text": text, "animal": animal_kind})

func _animal(x: float, y: float, kind: String, anim_name: String, desc: String, shields: int = 0) -> void:
	animals.append({"x": x, "y": y, "kind": kind, "name": anim_name, "desc": desc,
		"met": false, "shields": shields})

func _hazard(x: float, y: float, w: float, h: float, kind: String) -> void:
	hazards.append({"x": x, "y": y, "w": w, "h": h, "kind": kind})

func _portal(x: float, y: float, w: float, h: float, to: int) -> void:
	portals.append({"x": x, "y": y, "w": w, "h": h, "to": to, "phase": 0.0})

func _swarm(x: float, y: float, r: float, danger: float) -> void:
	swarm_nodes.append({"x": x, "y": y, "r": r, "danger": danger,
		"orbit": randf_range(10.0, 30.0), "phase": randf_range(0.0, 100.0)})

func _drone(bx: float, by: float, type: String, axis: String, amplitude: float, speed: float) -> void:
	var w: float = 80.0 if type == "platform" else 52.0
	var h: float = 14.0 if type == "platform" else 12.0
	drones.append({"bx": bx, "by": by, "w": w, "h": h, "type": type, "axis": axis,
		"amplitude": amplitude, "speed": speed, "phase": randf_range(0.0, TAU),
		"cx": bx, "cy": by, "body": null})

# ── Physics bodies ───────────────────────────────────────────────

func _create_platform_body(p: Dictionary) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(p["w"]), float(p["h"]))
	shape.shape = rect
	shape.position = Vector2(float(p["w"]) * 0.5, float(p["h"]) * 0.5)
	body.add_child(shape)
	body.position = Vector2(float(p["x"]), float(p["y"]))
	add_child(body)
	_platform_bodies.append(body)

func _create_drone_body(d: Dictionary) -> void:
	var body := AnimatableBody2D.new()
	body.sync_to_physics = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(d["w"]), float(d["h"]))
	shape.shape = rect
	shape.position = Vector2(float(d["w"]) * 0.5, float(d["h"]) * 0.5)
	body.add_child(shape)
	body.position = Vector2(float(d["bx"]), float(d["by"]))
	add_child(body)
	d["body"] = body

# ── Queries ──────────────────────────────────────────────────────

func open_secret_platforms() -> void:
	secret_opened = true
	for p in platforms:
		if p["secret"] and not p["open"]:
			p["open"] = true
			_create_platform_body(p)

func visible_platforms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in platforms:
		if not (p["secret"] and not p["open"]):
			result.append(p)
	return result

func check_orb_collect(player_pos: Vector2, player_size: Vector2) -> void:
	var pr := Rect2(player_pos, player_size)
	for orb in orbs:
		if orb["taken"]: continue
		if pr.intersects(Rect2(Vector2(orb["x"], orb["y"]), Vector2(orb["w"], orb["h"]))):
			orb["taken"] = true
			GameState.collect_orb()

func check_record_collect(player_pos: Vector2, player_size: Vector2) -> void:
	var pr := Rect2(player_pos, player_size)
	for rec in records:
		if rec["taken"]: continue
		if pr.intersects(Rect2(Vector2(rec["x"], rec["y"]), Vector2(rec["w"], rec["h"]))):
			rec["taken"] = true
			if rec["type"] == "key":
				GameState.collect_key()
			else:
				GameState.find_record(rec["title"], rec["text"])

func check_animal_meet(player_pos: Vector2, player_size: Vector2) -> void:
	var pr := Rect2(player_pos, player_size)
	for a in animals:
		if a["met"]: continue
		var ar := Rect2(Vector2(a["x"] - 24.0, a["y"] - 48.0), Vector2(48.0, 48.0))
		if pr.intersects(ar):
			a["met"] = true
			GameState.meet_animal(a["kind"], a["name"], a["desc"])
			if a["kind"] == "fox":
				open_secret_platforms()
			var shield_amount: int = int(a.get("shields", 0))
			if shield_amount > 0:
				GameState.gain_shield(shield_amount)

func check_portal(player_pos: Vector2, player_size: Vector2) -> void:
	if not GameState.portal_unlocked(): return
	var pr := Rect2(player_pos, player_size)
	for po in portals:
		if pr.intersects(Rect2(Vector2(po["x"], po["y"]), Vector2(po["w"], po["h"]))):
			portal_entered.emit(po["to"])
			break

func check_swarm_damage(player_pos: Vector2, _delta: float) -> void:
	if GameState.buff_wolf: return
	if _hit_timer > 0.0: return
	var px: float = player_pos.x + 16.0
	var py: float = player_pos.y + 16.0
	for s in swarm_nodes:
		if Vector2(px - float(s["x"]), py - float(s["y"])).length() < float(s["r"]):
			GameState.take_damage()
			_hit_timer = 1.5
			return

func check_hazard_damage(player_pos: Vector2, player_size: Vector2) -> void:
	if _hit_timer > 0.0: return
	var pr := Rect2(player_pos, player_size)
	for h in hazards:
		var hr := Rect2(Vector2(float(h["x"]), float(h["y"])), Vector2(float(h["w"]), float(h["h"])))
		if pr.intersects(hr):
			GameState.take_damage()
			_hit_timer = 1.5
			return

func check_drone_damage(player_pos: Vector2, player_size: Vector2) -> void:
	if _hit_timer > 0.0: return
	var pr := Rect2(player_pos, player_size)
	for d in drones:
		if d["type"] != "hazard": continue
		var cx: float = float(d["cx"])
		var cy: float = float(d["cy"])
		var dr := Rect2(Vector2(cx, cy), Vector2(float(d["w"]), float(d["h"])))
		if pr.intersects(dr):
			GameState.take_damage()
			_hit_timer = 1.5
			return
