class_name BSPGen
extends RefCounted

class BSPNode:
	var x: int; var y: int; var w: int; var h: int
	var left: BSPNode; var right: BSPNode
	var room: Dictionary

	func _init(_x: int, _y: int, _w: int, _h: int) -> void:
		x = _x; y = _y; w = _w; h = _h

static func generate(gw: int, gh: int) -> Dictionary:
	var map: Array = []
	for _y in gh:
		var row: Array = []
		row.resize(gw)
		row.fill(Config.WALL)
		map.append(row)

	var root := BSPNode.new(1, 1, gw - 2, gh - 2)
	_split(root, 9, 0)
	_carve(root, map, gw, gh)
	_connect(root, map, gw, gh)

	var rooms: Array = []
	_collect(root, rooms)

	return {"map": map, "rooms": rooms}

static func _split(node: BSPNode, min_sz: int, depth: int) -> void:
	if depth > 4:
		return
	if node.w < min_sz * 2 and node.h < min_sz * 2:
		return

	var horiz := randf() < 0.5
	if float(node.w) >= float(node.h) * 1.3:
		horiz = false
	if float(node.h) >= float(node.w) * 1.3:
		horiz = true

	var span := node.h if horiz else node.w
	if span < min_sz * 2:
		return

	var split := randi_range(min_sz, span - min_sz)
	if horiz:
		node.left  = BSPNode.new(node.x, node.y,         node.w, split)
		node.right = BSPNode.new(node.x, node.y + split, node.w, node.h - split)
	else:
		node.left  = BSPNode.new(node.x,         node.y, split,          node.h)
		node.right = BSPNode.new(node.x + split, node.y, node.w - split, node.h)

	_split(node.left, min_sz, depth + 1)
	_split(node.right, min_sz, depth + 1)

static func _carve(node: BSPNode, map: Array, gw: int, gh: int) -> void:
	if not node.left and not node.right:
		var m := 2
		var mx_w := node.w - m * 2
		var mx_h := node.h - m * 2
		if mx_w < 3 or mx_h < 3:
			return
		var rw := randi_range(max(3, mx_w - 2), mx_w)
		var rh := randi_range(max(3, mx_h - 2), mx_h)
		var rx := node.x + randi_range(m, max(m, node.w - rw - m))
		var ry := node.y + randi_range(m, max(m, node.h - rh - m))
		node.room = {
			"x": rx, "y": ry, "w": rw, "h": rh,
			"cx": rx + rw / 2, "cy": ry + rh / 2
		}
		for cy in range(ry, ry + rh):
			for cx in range(rx, rx + rw):
				if cx >= 0 and cx < gw and cy >= 0 and cy < gh:
					map[cy][cx] = Config.FLOOR
		return
	if node.left:
		_carve(node.left, map, gw, gh)
	if node.right:
		_carve(node.right, map, gw, gh)

static func _get_room(node: BSPNode) -> Dictionary:
	if not node.room.is_empty():
		return node.room
	var l := _get_room(node.left) if node.left else {}
	var r := _get_room(node.right) if node.right else {}
	if l.is_empty(): return r
	if r.is_empty(): return l
	return l if randf() < 0.5 else r

static func _connect(node: BSPNode, map: Array, gw: int, gh: int) -> void:
	if not node.left or not node.right:
		return
	_connect(node.left, map, gw, gh)
	_connect(node.right, map, gw, gh)
	var ra := _get_room(node.left)
	var rb := _get_room(node.right)
	if not ra.is_empty() and not rb.is_empty():
		_carve_corridor(map, ra["cx"], ra["cy"], rb["cx"], rb["cy"], gw, gh)

static func _carve_corridor(map: Array, x1: int, y1: int, x2: int, y2: int, gw: int, gh: int) -> void:
	var x := x1; var y := y1
	if randf() < 0.5:
		while x != x2:
			_stamp(map, x, y, gw, gh)
			x += 1 if x < x2 else -1
		while y != y2:
			_stamp(map, x, y, gw, gh)
			y += 1 if y < y2 else -1
	else:
		while y != y2:
			_stamp(map, x, y, gw, gh)
			y += 1 if y < y2 else -1
		while x != x2:
			_stamp(map, x, y, gw, gh)
			x += 1 if x < x2 else -1
	_stamp(map, x, y, gw, gh)

static func _stamp(map: Array, cx: int, cy: int, gw: int, gh: int) -> void:
	for dy in 2:
		for dx in 2:
			var nx := cx + dx; var ny := cy + dy
			if nx >= 0 and nx < gw and ny >= 0 and ny < gh:
				map[ny][nx] = Config.FLOOR

static func _collect(node: BSPNode, arr: Array) -> void:
	if not node.room.is_empty():
		arr.append(node.room)
		return
	if node.left:
		_collect(node.left, arr)
	if node.right:
		_collect(node.right, arr)
