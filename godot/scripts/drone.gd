class_name Drone
extends RefCounted

var gx: int
var gy: int
var pos: Vector2

var energy: float        = Config.ENERGY_MAX
var path: Array          = []
var state: String        = "idle"
var hack_target          = null
var hack_progress: float = 0.0
var detected: float      = 0.0
var alive: bool          = true
var stealth_on: bool     = false
var trail: Array         = []

signal hacked(terminal)
signal stealth_failed

func setup(start_x: int, start_y: int) -> void:
	gx  = start_x
	gy  = start_y
	pos = Config.grid_to_local(gx, gy)

func move_to(astar: AStarGrid, ex: int, ey: int) -> void:
	if not alive:
		return
	var p := astar.get_path(gx, gy, ex, ey)
	if p.size() > 0:
		path          = p
		state         = "moving"
		hack_target   = null
		hack_progress = 0.0

func update(dt: float) -> void:
	if not alive:
		return

	if state == "moving" and path.size() > 0:
		var tgt: Vector2i = path[0]
		var tgt_pos := Config.grid_to_local(tgt.x, tgt.y)
		var diff    := tgt_pos - pos
		var d       := diff.length()
		var spd     := Config.DRONE_SPEED * Config.TILE * dt

		if d <= spd + 0.5:
			pos = tgt_pos
			gx  = tgt.x
			gy  = tgt.y
			path.pop_front()
			energy = max(0.0, energy - Config.ENERGY_MOVE)
			if path.is_empty():
				state = "idle"
		else:
			pos += diff.normalized() * spd

		trail.append(pos)
		if trail.size() > 18:
			trail.pop_front()

	if state == "hacking" and hack_target != null:
		hack_progress += dt / Config.HACK_TIME
		if hack_progress >= 1.0:
			hack_target["hacked"] = true
			emit_signal("hacked", hack_target)
			hack_target   = null
			hack_progress = 0.0
			state         = "idle"

	if state == "idle":
		energy = min(Config.ENERGY_MAX, energy + Config.ENERGY_REGEN * dt)

	if stealth_on:
		energy = max(0.0, energy - Config.ENERGY_STEALTH * dt)
		if energy <= 0.0:
			stealth_on = false
			emit_signal("stealth_failed")

func start_hack(terminal: Dictionary) -> void:
	if state == "moving":
		path.clear()
	state         = "hacking"
	hack_target   = terminal
	hack_progress = 0.0

func can_reach_terminal(terminal: Dictionary) -> bool:
	return Vector2(gx, gy).distance_to(Vector2(terminal["x"], terminal["y"])) <= Config.HACK_RANGE
