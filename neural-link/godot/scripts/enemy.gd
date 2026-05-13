class_name Enemy
extends RefCounted

var gx: int; var gy: int
var pos: Vector2
var angle: float
var start_angle: float
var rot_dir: float       = 1.0
var alert_state: String  = "patrol"
var alert_timer: float   = 0.0
var flash_timer: float   = 0.0

var epath: Array         = []
var emove_state: String  = "idle"
var wait_timer: float    = Config.ENEMY_WAIT
var patrol_waypoints: Array = []
var patrol_index: int    = 0
var last_known_drone     = null
var chase_timer: float   = 0.0

var _astar: AStarGrid

func setup(x: int, y: int, _angle: float, waypoints: Array, astar: AStarGrid) -> void:
	gx = x; gy = y
	angle            = _angle
	start_angle      = _angle
	patrol_waypoints = waypoints
	_astar           = astar
	pos              = Config.grid_to_local(gx, gy)

func update(dt: float) -> void:
	flash_timer = max(0.0, flash_timer - dt)

	if alert_state == "alert" and last_known_drone != null:
		_update_alert(dt)
	elif alert_state == "suspicious" and last_known_drone != null:
		_update_suspicious()
	else:
		_update_patrol(dt)

	_move_along_path(dt)

	if emove_state == "moving" and epath.size() > 0:
		var tgt: Vector2i = epath[0]
		angle = rad_to_deg(Vector2(tgt.x - gx, tgt.y - gy).angle())
	elif emove_state == "idle":
		angle += Config.ENEMY_ROT * rot_dir * dt
		if abs(_angle_delta(angle, start_angle)) > Config.ENEMY_SWING:
			rot_dir *= -1.0

func _update_alert(dt: float) -> void:
	chase_timer = max(0.0, chase_timer - dt)
	if chase_timer <= 0.0:
		var p := _astar.get_path(gx, gy, last_known_drone.x, last_known_drone.y)
		if p.size() > 0:
			epath       = p
			emove_state = "moving"
		chase_timer = Config.ENEMY_CHASE_INTERVAL

func _update_suspicious() -> void:
	if emove_state == "idle" and last_known_drone != null:
		var p := _astar.get_path(gx, gy, last_known_drone.x, last_known_drone.y)
		if p.size() > 0:
			epath       = p
			emove_state = "moving"
		last_known_drone = null

func _update_patrol(dt: float) -> void:
	if emove_state != "idle":
		return
	if wait_timer > 0.0:
		wait_timer -= dt
	elif patrol_waypoints.size() > 1:
		patrol_index = (patrol_index + 1) % patrol_waypoints.size()
		var wp: Vector2i = patrol_waypoints[patrol_index]
		var p := _astar.get_path(gx, gy, wp.x, wp.y)
		if p.size() > 0:
			epath       = p
			emove_state = "moving"

func _move_along_path(dt: float) -> void:
	if emove_state != "moving" or epath.is_empty():
		return
	var tgt: Vector2i = epath[0]
	var tgt_pos := Config.grid_to_local(tgt.x, tgt.y)
	var diff    := tgt_pos - pos
	var d       := diff.length()
	var spd_mul := 1.6 if alert_state == "alert" else 1.0
	var spd     := Config.ENEMY_SPEED * spd_mul * Config.TILE * dt

	if d <= spd + 0.5:
		pos = tgt_pos
		gx  = tgt.x
		gy  = tgt.y
		epath.pop_front()
		if epath.is_empty():
			emove_state = "idle"
			wait_timer  = Config.ENEMY_WAIT
			start_angle = angle
	else:
		pos += diff.normalized() * spd

func can_see(map: Array, tx: int, ty: int) -> bool:
	var d := Vector2(gx, gy).distance_to(Vector2(tx, ty))
	if d > Config.ENEMY_RANGE:
		return false
	var a := rad_to_deg(Vector2(tx - gx, ty - gy).angle())
	if abs(_angle_delta(a, angle)) > Config.ENEMY_FOV:
		return false
	return _los(map, gx, gy, tx, ty)

static func _los(map: Array, x1: int, y1: int, x2: int, y2: int) -> bool:
	var dx := x2 - x1; var dy := y2 - y1
	var steps := int(ceil(max(abs(dx), abs(dy)) * 2.5))
	for i in range(1, steps):
		var t  := float(i) / steps
		var tx := int(round(x1 + dx * t))
		var ty := int(round(y1 + dy * t))
		if not Config.in_bounds(tx, ty):
			return false
		if map[ty][tx] == Config.WALL:
			return false
	return true

static func _angle_delta(a: float, b: float) -> float:
	var d := fmod(a - b + 360.0, 360.0)
	return d - 360.0 if d > 180.0 else d
