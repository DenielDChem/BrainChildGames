extends Node2D

var level_mgr: Node2D = null
var player: CharacterBody2D = null

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if level_mgr == null or player == null:
		return
	_draw_background()
	_draw_platforms()
	_draw_hazards()
	_draw_drones()
	_draw_swarm()
	_draw_orbs()
	_draw_records()
	_draw_animals()
	_draw_portals()
	_draw_player()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, Config.WORLD_W, Config.WORLD_H), Config.C_BG)

func _draw_platforms() -> void:
	for p in level_mgr.visible_platforms():
		var col := _platform_color(p["type"])
		draw_rect(Rect2(p["x"], p["y"], p["w"], p["h"]), col)
		draw_line(Vector2(p["x"], p["y"]), Vector2(p["x"] + p["w"], p["y"]), Color(1, 1, 1, 0.08), 1.5)

func _platform_color(type: String) -> Color:
	match type:
		"ground": return Config.C_GROUND
		"earth":  return Config.C_EARTH
		"cloud":  return Config.C_CLOUD
		"secret": return Color(Config.C_SECRET.r, Config.C_SECRET.g, Config.C_SECRET.b, 0.55)
		_:        return Config.C_EARTH

func _draw_hazards() -> void:
	for h in level_mgr.hazards:
		draw_rect(Rect2(h["x"], h["y"], h["w"], h["h"]), Color(Config.C_HAZARD.r, Config.C_HAZARD.g, Config.C_HAZARD.b, 0.72))

func _draw_swarm() -> void:
	for s in level_mgr.swarm_nodes:
		var alpha := 0.18 + 0.06 * sin(_time * s["orbit"] * 0.4 + s["phase"])
		var danger_alpha := 0.28 if GameState.buff_wolf else 0.18
		draw_arc(Vector2(s["x"], s["y"]), s["r"], 0.0, TAU, 32, Color(Config.C_DANGER.r, Config.C_DANGER.g, Config.C_DANGER.b, danger_alpha), 1.5)
		for i in 6:
			var angle: float = _time * float(s["orbit"]) * 0.06 + i * TAU / 6.0 + float(s["phase"])
			draw_circle(Vector2(s["x"] + cos(angle) * s["r"] * 0.7, s["y"] + sin(angle) * s["r"] * 0.7), 2.5, Color(Config.C_COPPER.r, Config.C_COPPER.g, Config.C_COPPER.b, alpha + 0.2))

func _draw_drones() -> void:
	for d in level_mgr.drones:
		var cx: float = float(d["cx"])
		var cy: float = float(d["cy"])
		var w: float = float(d["w"])
		var h: float = float(d["h"])
		if d["type"] == "platform":
			draw_rect(Rect2(cx, cy, w, h), Config.C_DRONE_HELP)
			draw_line(Vector2(cx, cy), Vector2(cx + w, cy), Color(1, 1, 1, 0.18), 1.5)
		else:
			var pulse: float = 0.6 + 0.4 * sin(_time * 3.5 + float(d["phase"]))
			draw_rect(Rect2(cx, cy, w, h),
				Color(Config.C_DRONE_HARM.r, Config.C_DRONE_HARM.g, Config.C_DRONE_HARM.b, 0.82))
			draw_line(Vector2(cx, cy), Vector2(cx + w, cy),
				Color(Config.C_DANGER.r, Config.C_DANGER.g, Config.C_DANGER.b, pulse * 0.6), 1.0)

func _draw_orbs() -> void:
	for orb in level_mgr.orbs:
		if orb["taken"]: continue
		var cx: float = float(orb["x"]) + 16.0
		var cy: float = float(orb["y"]) + 16.0
		var pulse := 0.85 + 0.15 * sin(_time * 2.2)
		draw_circle(Vector2(cx, cy), 10.0 * pulse, Color(Config.C_BLUE.r, Config.C_BLUE.g, Config.C_BLUE.b, 0.82))
		if GameState.buff_raven:
			draw_line(Vector2(cx, cy), Vector2(cx, cy - 200.0), Color(Config.C_BLUE.r, Config.C_BLUE.g, Config.C_BLUE.b, 0.18), 1.0)

func _draw_records() -> void:
	for rec in level_mgr.records:
		if rec["taken"]: continue
		var col := Config.C_COPPER if rec["type"] == "record" else Config.C_INK
		draw_circle(Vector2(rec["x"] + 21.0, rec["y"] + 21.0), 9.0, Color(col.r, col.g, col.b, 0.78))

func _draw_animals() -> void:
	for a in level_mgr.animals:
		if a["met"]: continue
		var p := 0.5 + 0.5 * sin(_time * 2.0 + float(a["x"]) * 0.01)
		var s := 0.95 + p * 0.04
		var pos := Vector2(float(a["x"]) + 24.0, float(a["y"]) + 24.0)
		_draw_animal_shape(a["kind"], pos, s)

func _draw_animal_shape(kind: String, pos: Vector2, s: float) -> void:
	var fill := Color(Config.C_COPPER.r, Config.C_COPPER.g, Config.C_COPPER.b, 0.16)
	var stroke := Color(Config.C_INK.r, Config.C_INK.g, Config.C_INK.b, 0.82)
	var pts: PackedVector2Array
	var detail: PackedVector2Array

	match kind:
		"fox":
			pts = _scaled_pts([Vector2(-34,20),Vector2(-14,-18),Vector2(0,-36),Vector2(14,-18),Vector2(34,20),Vector2(12,10),Vector2(0,34),Vector2(-12,10)], pos, s)
			detail = _scaled_pts([Vector2(-16,2),Vector2(0,12),Vector2(16,2)], pos, s)
		"raven":
			pts = _scaled_pts([Vector2(-42,6),Vector2(-12,-18),Vector2(2,-8),Vector2(24,-38),Vector2(48,-30),Vector2(28,-4),Vector2(42,10),Vector2(8,12),Vector2(-18,24),Vector2(-8,10)], pos, s)
			detail = _scaled_pts([Vector2(2,-8),Vector2(20,10),Vector2(-8,10)], pos, s)
		"bear":
			pts = _scaled_pts([Vector2(-30,24),Vector2(-30,-2),Vector2(-18,-26),Vector2(-6,-14),Vector2(0,-34),Vector2(6,-14),Vector2(18,-26),Vector2(30,-2),Vector2(30,24),Vector2(10,34),Vector2(-10,34)], pos, s)
			detail = _scaled_pts([Vector2(-10,8),Vector2(0,16),Vector2(10,8)], pos, s)
		"wolf":
			pts = _scaled_pts([Vector2(-36,24),Vector2(-12,-30),Vector2(8,-8),Vector2(30,-34),Vector2(36,24),Vector2(14,12),Vector2(0,34),Vector2(-14,12)], pos, s)
			detail = _scaled_pts([Vector2(-28,30),Vector2(0,4),Vector2(28,30)], pos, s)
		"cat":
			pts = _scaled_pts([Vector2(-28,28),Vector2(-32,-2),Vector2(-16,-34),Vector2(0,-12),Vector2(16,-34),Vector2(32,-2),Vector2(28,28)], pos, s)
			detail = _scaled_pts([Vector2(-10,10),Vector2(0,18),Vector2(10,10)], pos, s)

	if pts.size() > 0:
		draw_colored_polygon(pts, fill)
		var outline := PackedVector2Array(pts)
		outline.append(pts[0])
		draw_polyline(outline, stroke, 2.5, true)
		if detail.size() > 0:
			draw_polyline(detail, stroke, 2.0, true)

func _scaled_pts(offsets: Array, origin: Vector2, s: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for v: Vector2 in offsets:
		result.append(origin + v * s)
	return result

func _draw_portals() -> void:
	for po in level_mgr.portals:
		var unlocked := GameState.portal_unlocked()
		var alpha := (0.55 + 0.25 * sin(po["phase"] * 1.2)) if unlocked else 0.18
		var col := Config.C_BLUE if unlocked else Config.C_MUTED
		draw_rect(Rect2(po["x"], po["y"], po["w"], po["h"]), Color(col.r, col.g, col.b, alpha * 0.3))
		draw_rect(Rect2(po["x"], po["y"], po["w"], po["h"]), Color(col.r, col.g, col.b, alpha), false, 1.5)

func _draw_player() -> void:
	var px := player.position.x + 16.0
	var py := player.position.y + 24.0
	var f := float(player.facing)
	var shield: bool = float(player.get("bear_shield_timer")) > 0.0
	var glow_val: float = float(player.get("glow"))
	var mode := GameState.mode

	# Aura / shield ellipse
	if shield or mode == "flight" or glow_val > 0.05:
		var sa := 0.48 if shield else (0.15 + glow_val * 0.32)
		var sw := 3.0 if shield else 2.0
		var er := 44.0 + glow_val * 18.0
		draw_arc(Vector2(px, py), er, 0.0, TAU, 36, Color(Config.C_BLUE.r, Config.C_BLUE.g, Config.C_BLUE.b, sa), sw)

	# Wings in flight mode
	if mode == "flight":
		var wa := 0.38 + glow_val * 0.2
		var wc := Color(Config.C_BLUE.r, Config.C_BLUE.g, Config.C_BLUE.b, wa)
		draw_polyline(PackedVector2Array([Vector2(px - 25*f, py - 14), Vector2(px - 78*f, py - 46), Vector2(px - 94*f, py - 92)]), wc, 1.5, true)
		draw_polyline(PackedVector2Array([Vector2(px + 25*f, py - 14), Vector2(px + 78*f, py - 46), Vector2(px + 94*f, py - 92)]), wc, 1.5, true)

	# Body polygon (torso + legs)
	var body_col := Config.C_BLUE if mode == "jump" else (Config.C_DANGER if mode == "flight" else Config.C_COPPER)
	var body_alpha := 0.44 if mode == "jump" else (0.44 if mode == "flight" else 0.48)
	var body_pts := PackedVector2Array([
		Vector2(px + (-14)*f, py - 10), Vector2(px + 14*f, py - 10),
		Vector2(px + 20*f, py + 34), Vector2(px + 8*f, py + 38),
		Vector2(px, py + 8),
		Vector2(px + (-8)*f, py + 38), Vector2(px + (-20)*f, py + 34),
	])
	draw_colored_polygon(body_pts, Color(body_col.r, body_col.g, body_col.b, body_alpha))

	# Arms
	var arm_col := Color(Config.C_INK.r, Config.C_INK.g, Config.C_INK.b, 0.34)
	draw_line(Vector2(px + (-14)*f, py + 2), Vector2(px + (-30)*f, py + 20), arm_col, 2.0)
	draw_line(Vector2(px + 14*f, py + 2), Vector2(px + 30*f, py + 20), arm_col, 2.0)

	# Head
	draw_circle(Vector2(px, py - 27.0), 14.0, Color(Config.C_INK.r, Config.C_INK.g, Config.C_INK.b, 0.84))
