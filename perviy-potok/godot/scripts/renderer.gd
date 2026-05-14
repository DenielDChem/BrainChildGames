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
		var pos := Vector2(a["x"], a["y"])
		draw_circle(pos, 14.0, Color(Config.C_COPPER.r, Config.C_COPPER.g, Config.C_COPPER.b, 0.55))
		draw_arc(pos, 16.0 + 2.0 * sin(_time * 1.8), 0.0, TAU, 24, Color(Config.C_COPPER.r, Config.C_COPPER.g, Config.C_COPPER.b, 0.22), 1.0)

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
	draw_arc(Vector2(px, py), 14.0, 0.0, TAU, 24, Color(Config.C_INK.r, Config.C_INK.g, Config.C_INK.b, 0.88), 2.0)
	var shield: bool = (player.get("bear_shield_timer") as float) > 0.0
	var glow_val: float = player.get("glow") as float
	if shield or GameState.mode == "flight" or glow_val > 0.05:
		var sa := 0.48 if shield else (0.15 + glow_val * 0.32)
		draw_arc(Vector2(px, py), 22.0 + glow_val * 8.0, 0.0, TAU, 32, Color(Config.C_BLUE.r, Config.C_BLUE.g, Config.C_BLUE.b, sa), 2.0)
	if GameState.mode == "flight":
		var wa := 0.38 + glow_val * 0.2
		draw_line(Vector2(px - 12, py - 7), Vector2(px - 46, py - 22), Color(Config.C_BLUE.r, Config.C_BLUE.g, Config.C_BLUE.b, wa), 1.5)
		draw_line(Vector2(px + 12, py - 7), Vector2(px + 46, py - 22), Color(Config.C_BLUE.r, Config.C_BLUE.g, Config.C_BLUE.b, wa), 1.5)
