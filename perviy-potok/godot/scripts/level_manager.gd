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
# REDESIGN NOTES (vs original):
#   - Reduced from 21 platforms → 14 (11 visible + 3 secret)
#   - False path: single narrow platform + hazard on top (was 3-platform branch)
#     Both fork options share x=1060 — player reads height difference, not position
#   - True path: single wider platform B1 (was 4 platforms to Fox)
#   - Fox gap 280px gives first real "air time" moment (was 90px hops)
#   - Mid-game compressed to 2 platforms D1+E1 (was 7 steps)
#   - Cat gate: rise=230px > max single jump 204px; Cat double=363px — clean hard gate
#   - Orb placement: 1 on false path (temptation), 1 Fox-gated on S3, 1 post-Cat on F1

func _build_walk() -> void:
	# Ground: extends from off-screen left to x=560
	_plat(-200, 750, 760, 200, "ground")

	# ── ACT 1: ENTRY (x=580–960) ──────────────────────────────────────────
	# Two gentle steps teach ground-level platforming before any real gap.
	# Wide platforms, modest rises — establishes comfort zone before the fork.
	_plat(580, 700, 130, 22, "earth")   # A1 — first step from ground; gap=20px, rise=50px
	_plat(820, 665, 140, 22, "earth")   # A2 — Bear lives here; gap=110px, rise=35px

	_animal(858, 633, "bear", "Медведь", "Медведь даёт 1 щит.", 1)
	_record(858, 633, "Медведь-Основа",
		"Медведь держит рубеж. Щит — не броня: это умение остановиться.")

	# ── FORK: FALSE PATH vs TRUE PATH ─────────────────────────────────────
	# Both options start at the same x (1060) from A2's right edge (960).
	# FALSE PATH: 70px HIGHER than A2 — player sees it first (higher = more visible).
	#   Narrow width (80px) signals instability. Hazard tile crowns the surface.
	#   No exit platform beyond. Player learns: narrow+high+red = danger.
	# TRUE PATH: 35px LOWER than A2 — player must deliberately look downward.
	#   Wider width (140px) signals safety. Leads to the 280px gap toward Fox.
	_plat(1060, 595, 80, 22, "earth")   # FALSE — narrow, high, hazard on top
	_plat(1060, 700, 140, 22, "earth")  # TRUE  — wider, lower, same x as false

	_hazard(1060, 573, 80, 22, "holder")  # crowns false platform — visible red signal
	_orb(1085, 539)                        # Orb 1 — tempts player onto false path

	# ── ACT 1 RESOLUTION: FOX ─────────────────────────────────────────────
	# True path's first committed gap: 280px. Player is airborne ~0.45 seconds.
	# Fox platform is wider (160px) — visual reward for navigating to it.
	_plat(1480, 665, 160, 22, "earth")  # C1 — Fox; gap=280px from B1 right=1200

	_animal(1540, 633, "fox", "Лиса", "Лиса открывает тайные тропы.", 0)
	_record(1540, 633, "Лисий обход",
		"Лиса открывает скрытую тропу. Верхний путь был закрыт — теперь нет.", "fox")

	# ── ACT 2: FOX SECRETS — UPPER EXPRESS LANE ───────────────────────────
	# Secrets appear directly above Fox's platform the moment Fox is met.
	# S1 is visible immediately (135px above C1 surface) — dramatic reveal.
	# Three platforms form a faster elevated route across Act 2.
	# Orb 2 lives only on S3 — Fox route is the sole collection path.
	_plat(1490, 530, 120, 22, "secret", true)  # S1 — 135px above C1, appears at Fox
	_plat(1830, 478, 120, 22, "secret", true)  # S2 — gap=220px from S1, rise=52px
	_plat(2170, 426, 120, 22, "secret", true)  # S3 — gap=220px from S2, rise=52px

	_orb(2195, 370)   # Orb 2 — Fox-gated, on S3

	# ── ACT 2: TRUE GROUND PATH — TOWARD CAT ──────────────────────────────
	# D1 gives breathing room after Fox (190px gap).
	# E1 clusters with D1 to feel like a "room" — Cat encounter here.
	_plat(1830, 640, 140, 22, "earth")  # D1 — gap=190px from C1 right=1640, rise=25px
	_plat(2120, 618, 160, 22, "earth")  # E1 — Cat here; gap=150px from D1 right=1970

	_animal(2172, 586, "cat", "Кот", "Кот даёт второй прыжок.", 0)
	_record(2172, 586, "Кот в Вышине",
		"Кот прыгает туда, где нет правил. Второй прыжок — решение.", "cat")

	# ── ACT 3: ENDGAME ASCENT ─────────────────────────────────────────────
	# Two gaps widen post-Cat: 260px then 240px. Player uses Cat casually —
	# building muscle memory before the deliberate Cat-gated KeyLedge.
	_plat(2540, 575, 120, 22, "earth")  # F1 — gap=260px from E1 right=2280, rise=43px
	_plat(2900, 525, 120, 22, "earth")  # G1 — gap=240px from F1 right=2660, rise=50px

	_orb(2560, 519)   # Orb 3 — floats above F1; reward for the first wide gap

	# KEY LEDGE: hard Cat gate — rise=230px, single jump max=204px (FAIL), Cat=363px (PASS)
	# Horizontal gap from G1 right edge (3020) is only 130px — gate is purely vertical.
	# Player who jumps without Cat hits wall 100px short and falls. Gate reads immediately.
	_plat(3150, 295, 100, 22, "earth")  # KeyLedge — Cat double jump required
	_plat(3390, 240, 100, 22, "earth")  # PortalLedge — stepping stone to portal

	_key(3168, 253)

	_portal(3890, 50, 220, 720, 1)

# ── Level 1: Jump / Drones ──────────────────────────────────────
# REDESIGN NOTES (vs original):
#   - Reduced from 20 platforms → 15 (12 visible + 3 secret)
#   - Drones: 2 platform + 2 hazard (was 2 platform + 3 hazard)
#   - Each drone pair (platform+hazard) creates a clear risk/reward choice:
#     • Brave it directly (hazard threat) or use the platform drone (safe)
#   - Fox encounter earlier (platform D at x=1100) — secrets reveal mid-level
#   - Cat+Wolf now clearly separate encounters, not stacked
#   - Endgame: 3 clean steps I→J→K (no redundant micro-steps from original)
#   - Orbs: 1 at Raven (entry), 1 Fox-gated on S3, 1 near Cat on F, 1 near Key on K

func _build_jump() -> void:
	_plat(-200, 778, 380, 200, "ground")

	# ── ENTRY: RAVEN ───────────────────────────────────────────────────────
	# Raven on first platform — buff (lit orbs/records) active from the start.
	# Orb 1 placed on/near the platform so player collects it meeting Raven.
	_plat(180, 718, 110, 24, "cloud")    # A — Raven; gap=0 (ground ledge)

	_animal(218, 686, "raven", "Ворон", "Зрение Ворона: орбы и записи светятся линиями.", 0)
	_record(218, 686, "Поток",
		"Прыжок — переговоры со средой. Тело знает дальше, чем глаза.")
	_orb(205, 662)   # Orb 1 — floats above Raven platform

	# ── FIRST HAZARD ZONE: B → C ──────────────────────────────────────────
	# B is a calm ledge. Between B (right edge x=520) and C (left x=860)
	# is a 340px gap occupied by a hazard drone (vertical patrol).
	# Platform drone oscillates horizontally across the gap — safe stepping stone.
	# Direct jump is physically possible but hazard drone punishes careless flight.
	_plat(430, 680, 90, 24, "cloud")     # B — gap=120px from A right=290, rise=38px

	_drone(680, 656, "platform", "x", 85.0, 0.9)   # platform drone 1: slow+steady = safe
	_drone(690, 610, "hazard", "y", 46.0, 2.6)     # hazard drone 1: fast+erratic = danger

	_plat(860, 636, 90, 24, "cloud")     # C — reachable via drone; gap=340px from B direct

	# ── FOX ENCOUNTER ─────────────────────────────────────────────────────
	_plat(1100, 594, 100, 24, "cloud")   # D — Fox; gap=150px from C right=950, rise=42px

	_animal(1138, 562, "fox", "Лиса", "Лиса открывает скрытый верхний путь.", 0)
	_record(1138, 562, "Ворон-Следопыт",
		"Ворон видит не предмет, а траекторию.", "raven")

	# Secrets appear above D the moment Fox is met.
	# S1 hovers 116px above D's surface — immediately visible.
	# S3 carries Orb 2 — Fox route is the only way to collect it.
	_plat(1100, 478, 100, 22, "secret", true)   # S1 — directly above Fox, 116px up
	_plat(1480, 418, 100, 22, "secret", true)   # S2 — gap=280px from S1, rise=60px
	_plat(1860, 358, 100, 22, "secret", true)   # S3 — gap=280px from S2, rise=60px

	_orb(1885, 302)   # Orb 2 — Fox-gated, floats above S3

	# ── ACT 2: POST-FOX TO CAT ────────────────────────────────────────────
	# Widening rhythm: 180px → 230px. Player gains rhythm confidence.
	_plat(1380, 550, 90, 24, "cloud")    # E — gap=180px from D right=1200, rise=44px
	_plat(1700, 506, 100, 24, "cloud")   # F — Cat+2shields; gap=230px from E right=1470

	_orb(1718, 450)   # Orb 3 — floats above F, near Cat
	_animal(1738, 474, "cat", "Кот", "Кот даёт второй прыжок и 2 щита.", 2)
	_record(1738, 474, "Кот и Щит",
		"Кот прыгает. Два щита — чтобы было место для ошибки.", "cat")

	# ── SECOND HAZARD ZONE: G → H ─────────────────────────────────────────
	# Same structure as B→C but gap is wider (290px) and hazard amplitude larger.
	# Wolf's swarm-immunity buff does NOT remove hazard drones — player must still
	# time the platform drone correctly. Consequence feels earned.
	_plat(2060, 462, 90, 24, "cloud")    # G — gap=260px from F right=1800, rise=44px

	_drone(2275, 440, "platform", "x", 90.0, 0.9)  # platform drone 2: slow+steady = safe
	_drone(2285, 398, "hazard", "y", 52.0, 2.8)    # hazard drone 2: fast+erratic = danger

	_plat(2440, 414, 100, 24, "cloud")   # H — Wolf+2shields; gap=290px from G via drone

	_animal(2478, 382, "wolf", "Волк", "Волк даёт 2 щита и глушит опасные дроны.", 2)
	_record(2478, 382, "Волчья Сеть",
		"Волк различает, что движется, а что только кажется опасным.", "wolf")

	# ── ENDGAME ASCENT ────────────────────────────────────────────────────
	# Post-Wolf: hazard drones silenced, clean rhythm to Key and Portal.
	# Three steps with 210–260px gaps — player in full flow state.
	_plat(2800, 370, 90, 24, "cloud")    # I — gap=260px from H right=2540, rise=44px
	_plat(3100, 322, 90, 24, "cloud")    # J — gap=210px from I right=2890, rise=48px
	_plat(3420, 272, 90, 24, "cloud")    # K — Key here; gap=230px from J right=3190

	_orb(3438, 216)   # Orb 4 — floats above K, near Key
	_key(3438, 230)

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
