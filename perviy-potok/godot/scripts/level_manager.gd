extends Node2D

var platforms: Array[Dictionary] = []
var orbs: Array[Dictionary] = []
var records: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var portals: Array[Dictionary] = []
var swarm_nodes: Array[Dictionary] = []

var secret_opened: bool = false
var portal_phase: float = 0.0

var _platform_bodies: Array = []

signal portal_entered(to_level: int)

func _ready() -> void:
	_build_level(GameState.current_level)

func _build_level(lvl: int) -> void:
	for body in _platform_bodies:
		body.queue_free()
	_platform_bodies.clear()
	platforms.clear(); orbs.clear(); records.clear()
	animals.clear(); hazards.clear(); portals.clear(); swarm_nodes.clear()
	secret_opened = false
	match lvl:
		0: _build_walk()
		1: _build_jump()
		2: _build_flight()
	for p in platforms:
		if not (p["secret"] and not p["open"]):
			_create_platform_body(p)

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

func _build_walk() -> void:
	_plat(-200, 750, 760, 200, "ground")
	_plat(420, 660, 260, 28, "earth")
	_plat(740, 625, 260, 28, "earth")
	_plat(1060, 590, 280, 28, "earth")
	_plat(1400, 555, 280, 28, "earth")
	_plat(1750, 520, 300, 28, "earth")
	_plat(2110, 490, 300, 28, "earth")
	_plat(2470, 460, 310, 28, "earth")
	_plat(2840, 430, 320, 28, "earth")
	_plat(3210, 400, 320, 28, "earth")
	_plat(3560, 380, 260, 28, "earth")
	_plat(3880, 360, 120, 28, "earth")
	_plat(1670, 480, 250, 22, "secret", true)
	_plat(1970, 450, 250, 22, "secret", true)
	_plat(2270, 420, 250, 22, "secret", true)
	_orb(500, 600); _orb(1140, 530); _orb(1775, 430); _orb(2890, 370); _orb(3620, 320)
	_key(3910, 300)
	_record(790, 525, "Первый слух", "Земля ещё держит тебя, но небо уже перестало быть фоном.")
	_record(1500, 455, "Держатели", "Они называют безопасность неподвижностью.")
	_record(2310, 350, "Лисий обход", "Короткий путь возникает только после выбора обхода.", "fox")
	_record(3260, 340, "Медведь-Предел", "Опора — тоже часть восхождения.", "bear")
	_animal(1110, 508, "bear", "Медведь", "Щит Медведя: Центр получает меньше урона.")
	_animal(1490, 473, "fox", "Лиса", "Лиса открывает верхний обход: скрытые платформы появляются впереди.")
	_hazard(2710, 428, 54, 22, "holder")
	_hazard(3310, 368, 72, 22, "holder")
	_portal(4010, 145, 220, 520, 1)

func _build_jump() -> void:
	_plat(-200, 770, 560, 200, "ground")
	_plat(420, 700, 240, 24, "cloud")
	_plat(720, 660, 250, 24, "cloud")
	_plat(1030, 620, 260, 24, "cloud")
	_plat(1340, 580, 270, 24, "cloud")
	_plat(1670, 540, 280, 24, "cloud")
	_plat(2010, 500, 300, 24, "cloud")
	_plat(2360, 460, 300, 24, "cloud")
	_plat(2710, 425, 320, 24, "cloud")
	_plat(3070, 390, 320, 24, "cloud")
	_plat(3430, 360, 290, 24, "cloud")
	_plat(3780, 340, 120, 24, "cloud")
	_plat(1860, 485, 210, 22, "secret", true)
	_plat(2120, 450, 210, 22, "secret", true)
	_plat(2380, 415, 210, 22, "secret", true)
	_orb(495, 642); _orb(804, 602); _orb(1115, 562); _orb(2200, 392); _orb(3480, 300)
	_key(3805, 278)
	_record(610, 640, "Поток", "Прыжок больше не только мышца. Это переговоры со средой.")
	_record(1180, 528, "Ворон", "Ворон видит не предмет, а траекторию.", "raven")
	_record(2230, 360, "Лиса", "Скрытый ход теперь находится выше основного маршрута.", "fox")
	_record(3475, 280, "Кот", "Кот прыгает туда, где правил ещё нет.", "cat")
	_animal(1210, 538, "raven", "Ворон", "Зрение Ворона: орбы и записи получают лучи.")
	_animal(1510, 498, "fox", "Лиса", "Скрытый ход: впереди открывается верхний набор платформ.")
	_animal(3250, 278, "cat", "Кот", "Кошачий след: открывается второй прыжок.")
	_hazard(2450, 434, 70, 20, "break")
	_hazard(3185, 364, 72, 20, "break")
	_portal(3920, 140, 220, 500, 2)

func _build_flight() -> void:
	_orb(520, 420); _orb(1030, 330); _orb(1550, 470)
	_orb(2130, 360); _orb(2770, 450); _orb(3380, 340)
	_key(3650, 430)
	_record(740, 540, "Лик Роя", "Он красивый, связный и без выхода.")
	_record(1320, 250, "Волк", "Волк слышит сеть и знает цену растворения.", "wolf")
	_record(2360, 530, "Центр", "Центр — это способность остаться отдельной.")
	_record(3180, 260, "Горизонт", "За 46-й ступенью архив молчит.")
	_animal(1360, 395, "wolf", "Волк", "Волк отгоняет Рой и делает опасные зоны читаемыми.")
	_animal(3150, 520, "raven", "Ворон", "Последнее зрение: выход подсвечивается.")
	_swarm(850, 585, 36, 0.45); _swarm(1230, 605, 34, 0.44); _swarm(1700, 610, 42, 0.55)
	_swarm(2050, 585, 34, 0.45); _swarm(2480, 610, 45, 0.58)
	_swarm(2920, 590, 38, 0.48); _swarm(3300, 610, 42, 0.55)
	_portal(3890, 170, 260, 560, 3)

# ── Factories ──────────────────────────────────────────────────

func _plat(x: float, y: float, w: float, h: float, type: String, secret: bool = false) -> void:
	platforms.append({"x": x, "y": y, "w": w, "h": h, "type": type, "secret": secret, "open": not secret})

func _orb(x: float, y: float) -> void:
	orbs.append({"x": x, "y": y, "w": 32.0, "h": 32.0, "taken": false})

func _key(x: float, y: float) -> void:
	records.append({"x": x, "y": y, "w": 42.0, "h": 42.0, "type": "key", "taken": false, "title": "Ключ", "text": "Переход услышал тебя."})

func _record(x: float, y: float, title: String, text: String, animal_kind: String = "") -> void:
	records.append({"x": x, "y": y, "w": 42.0, "h": 42.0, "type": "record", "taken": false, "title": title, "text": text, "animal": animal_kind})

func _animal(x: float, y: float, kind: String, anim_name: String, desc: String) -> void:
	animals.append({"x": x, "y": y, "kind": kind, "name": anim_name, "desc": desc, "met": false})

func _hazard(x: float, y: float, w: float, h: float, kind: String) -> void:
	hazards.append({"x": x, "y": y, "w": w, "h": h, "kind": kind})

func _portal(x: float, y: float, w: float, h: float, to: int) -> void:
	portals.append({"x": x, "y": y, "w": w, "h": h, "to": to, "phase": 0.0})

func _swarm(x: float, y: float, r: float, danger: float) -> void:
	swarm_nodes.append({"x": x, "y": y, "r": r, "danger": danger, "orbit": randf_range(10.0, 30.0), "phase": randf_range(0.0, 100.0)})

# ── Queries ────────────────────────────────────────────────────

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

func check_portal(player_pos: Vector2, player_size: Vector2) -> void:
	if not GameState.portal_unlocked(): return
	var pr := Rect2(player_pos, player_size)
	for po in portals:
		if pr.intersects(Rect2(Vector2(po["x"], po["y"]), Vector2(po["w"], po["h"]))):
			portal_entered.emit(po["to"])
			break

func check_swarm_damage(player_pos: Vector2, delta: float) -> void:
	if GameState.buff_wolf: return
	var px := player_pos.x + 16.0
	var py := player_pos.y + 16.0
	for s in swarm_nodes:
		if Vector2(px - s["x"], py - s["y"]).length() < s["r"]:
			GameState.damage_center(s["danger"] * delta * 60.0)

func _process(delta: float) -> void:
	portal_phase += delta
	for po in portals:
		po["phase"] = portal_phase
