class_name AStarGrid
extends RefCounted

var _astar := AStar2D.new()
var _gw: int

func setup(map: Array, gw: int, gh: int) -> void:
	_gw = gw
	_astar.clear()

	for y in gh:
		for x in gw:
			if map[y][x] == Config.FLOOR:
				_astar.add_point(_id(x, y), Vector2(x, y))

	for y in gh:
		for x in gw:
			if map[y][x] != Config.FLOOR:
				continue
			for d in [[1, 0], [0, 1]]:
				var nx := x + d[0]; var ny := y + d[1]
				if nx < gw and ny < gh and map[ny][nx] == Config.FLOOR:
					_astar.connect_points(_id(x, y), _id(nx, ny))

func get_path(sx: int, sy: int, ex: int, ey: int) -> Array:
	var sid := _id(sx, sy); var eid := _id(ex, ey)
	if not _astar.has_point(sid) or not _astar.has_point(eid):
		return []
	var pts := _astar.get_point_path(sid, eid)
	if pts.size() <= 1:
		return []
	var result: Array = []
	for i in range(1, pts.size()):
		result.append(Vector2i(int(pts[i].x), int(pts[i].y)))
	return result

func _id(x: int, y: int) -> int:
	return y * _gw + x
