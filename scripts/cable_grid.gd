extends Node2D

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const BIT_UP := 1
const BIT_RIGHT := 2
const BIT_DOWN := 4
const BIT_LEFT := 8

@export var grid_size: int = 8

var cable_segment_scene: PackedScene = preload("res://scenes/cable_segment.tscn")

var node_colors: Dictionary = {}
var edges: Dictionary = {}
var server_cells_by_color: Dictionary = {}
var pc_port_cells_by_color: Dictionary = {}
var segment_nodes: Dictionary = {}
var office_tilemaps: Array = []
var blocked_tile_signatures: Dictionary = {}
var blocked_pc_cells: Dictionary = {}
var blocked_server_cells: Dictionary = {}
var allowed_endpoint_cells: Dictionary = {}

var atlas_texture: Texture2D = preload("res://sprites/Network_Overflow_Sprites.png")

var cable_variant_rects := {
	"red": {
		"straight": Rect2(32, 0, 8, 8),
		"end": Rect2(24, 16, 8, 8),
		"end_bent": Rect2(40, 24, 8, 8),
		"corner": Rect2(24, 0, 8, 8),
		"t": Rect2(0, 16, 8, 8),
		"cross": Rect2(16, 16, 8, 8),
		"port": Rect2(56, 16, 8, 8)
	},
	"blue": {
		"straight": Rect2(112, 0, 8, 8),
		"end": Rect2(104, 16, 8, 8),
		"end_bent": Rect2(120, 24, 8, 8),
		"corner": Rect2(104, 0, 8, 8),
		"t": Rect2(80, 16, 8, 8),
		"cross": Rect2(96, 16, 8, 8),
		"port": Rect2(136, 16, 8, 8)
	},
	"green": {
		"straight": Rect2(32, 40, 8, 8),
		"end": Rect2(24, 56, 8, 8),
		"end_bent": Rect2(40, 64, 8, 8),
		"corner": Rect2(24, 40, 8, 8),
		"t": Rect2(0, 56, 8, 8),
		"cross": Rect2(16, 56, 8, 8),
		"port": Rect2(56, 56, 8, 8)
	},
	"purple": {
		"straight": Rect2(112, 40, 8, 8),
		"end": Rect2(104, 56, 8, 8),
		"end_bent": Rect2(120, 64, 8, 8),
		"corner": Rect2(104, 40, 8, 8),
		"t": Rect2(80, 56, 8, 8),
		"cross": Rect2(96, 56, 8, 8),
		"port": Rect2(136, 56, 8, 8)
	}
}

func _ready() -> void:
	_init_default_blocked_tiles()

func set_endpoint_cells(new_server_cells_by_color: Dictionary, new_pc_port_cells_by_color: Dictionary) -> void:
	server_cells_by_color = new_server_cells_by_color
	pc_port_cells_by_color = new_pc_port_cells_by_color
	_refresh_segments()

func set_blocked_entity_cells(new_pc_cells: Dictionary, new_server_cells: Dictionary, new_allowed_endpoints: Dictionary) -> void:
	blocked_pc_cells = new_pc_cells
	blocked_server_cells = new_server_cells
	allowed_endpoint_cells = new_allowed_endpoints

func register_office_tilemap(tilemap) -> void:
	if tilemap == null:
		return
	if tilemap in office_tilemaps:
		return
	office_tilemaps.append(tilemap)

func get_endpoint_connected_start_cells(endpoint_cell: Vector2i, color_name: String) -> Array[Vector2i]:
	var starts: Array[Vector2i] = []
	for dir in DIRS:
		var cable_cell := endpoint_cell + dir
		if not node_colors.has(cable_cell):
			continue
		if node_colors[cable_cell] != color_name:
			continue
		if _cell_connects_to_endpoint(cable_cell, endpoint_cell, color_name):
			starts.append(cable_cell)
	return starts

func is_endpoint_powered(endpoint_cell: Vector2i, color_name: String, connected_cells: Dictionary) -> bool:
	if connected_cells.has(endpoint_cell):
		return true

	for dir in DIRS:
		var cable_cell := endpoint_cell + dir
		if not connected_cells.has(cable_cell):
			continue
		if not node_colors.has(cable_cell):
			continue
		if node_colors[cable_cell] != color_name:
			continue
		if _cell_connects_to_endpoint(cable_cell, endpoint_cell, color_name):
			return true

	return false

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(grid_size)), floori(world_pos.y / float(grid_size)))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * grid_size, cell.y * grid_size)

func cell_to_world_center(cell: Vector2i) -> Vector2:
	return cell_to_world(cell) + Vector2(grid_size / 2.0, grid_size / 2.0)

# Draws cable edges along a straight path between two world positions.
func try_place_line(world_from: Vector2, world_to: Vector2, color_name: String) -> bool:
	var cell_from := world_to_cell(world_from)
	var cell_to := world_to_cell(world_to)
	var cells := _cells_between(cell_from, cell_to)
	var changed := false

	for i in range(cells.size() - 1):
		if _try_place_edge(cells[i], cells[i + 1], color_name):
			changed = true

	if changed:
		_refresh_segments()

	return changed

# Removes cable edges of the given color along a path between two world positions.
func try_erase_line(world_from: Vector2, world_to: Vector2, color_name: String) -> bool:
	var cell_from := world_to_cell(world_from)
	var cell_to := world_to_cell(world_to)
	var cells := _cells_between(cell_from, cell_to)
	var changed := false

	for i in range(cells.size() - 1):
		if _try_erase_edge(cells[i], cells[i + 1], color_name):
			changed = true

	if changed:
		_refresh_segments()

	return changed

# BFS from the given start cells, returns all reachable cells of that color.
func get_connected_cells(starts: Array[Vector2i], color_name: String) -> Dictionary:
	var visited := {}
	var queue: Array[Vector2i] = []

	for start in starts:
		if node_colors.get(start, "") == color_name:
			visited[start] = true
			queue.append(start)

	var index := 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1

		for dir in DIRS:
			var next_cell: Vector2i = current + dir
			var key := _edge_key(current, next_cell)
			if not edges.has(key):
				continue

			var edge: Dictionary = edges[key]
			if edge["color"] != color_name:
				continue

			if not visited.has(next_cell):
				visited[next_cell] = true
				queue.append(next_cell)

	return visited

func get_port_cell(world_pos: Vector2, facing: String) -> Vector2i:
	var body_cell := world_to_cell(world_pos)
	return body_cell + _facing_to_dir(facing)

func get_port_cell_offset(world_pos: Vector2, facing: String, _offset_cells: float) -> Vector2i:
	return get_port_cell(world_pos, facing)

# Returns the 4 grid cells occupied by a 2x2 server centered at world_pos.
func get_server_body_cells(world_pos: Vector2) -> Array[Vector2i]:
	var tl := world_to_cell(world_pos - Vector2(grid_size / 2.0, grid_size / 2.0))
	return [
		tl,
		tl + Vector2i(1, 0),
		tl + Vector2i(0, 1),
		tl + Vector2i(1, 1)
	]

# Returns the 8 cells around the server footprint where cables can connect.
func get_server_port_cells(world_pos: Vector2) -> Array[Vector2i]:
	var tl := world_to_cell(world_pos - Vector2(grid_size / 2.0, grid_size / 2.0))
	var port: Array[Vector2i] = []
	port.append(tl + Vector2i(0, -1))
	port.append(tl + Vector2i(1, -1))
	port.append(tl + Vector2i(0, 2))
	port.append(tl + Vector2i(1, 2))
	port.append(tl + Vector2i(-1, 0))
	port.append(tl + Vector2i(-1, 1))
	port.append(tl + Vector2i(2, 0))
	port.append(tl + Vector2i(2, 1))
	return port

func get_server_anchor_cells(world_pos: Vector2) -> Array[Vector2i]:
	return get_server_port_cells(world_pos)

# Returns true if the PC port cell is walkable and inside a valid office area.
func is_port_cell_usable(world_pos: Vector2, facing: String) -> bool:
	var body_cell := world_to_cell(world_pos)
	var port_cell := body_cell + _facing_to_dir(facing)
	if _is_wall_cell(port_cell):
		return false
	if not _is_cell_in_any_office(port_cell) and not allowed_endpoint_cells.has(port_cell):
		return false
	return true

func world_to_cell_public(world_pos: Vector2) -> Vector2i:
	return world_to_cell(world_pos)

func _facing_to_dir(facing: String) -> Vector2i:
	match facing:
		"up":
			return Vector2i.UP
		"down":
			return Vector2i.DOWN
		"left":
			return Vector2i.LEFT
		"right":
			return Vector2i.RIGHT
		_:
			return Vector2i.ZERO

func _try_place_edge(a: Vector2i, b: Vector2i, color_name: String) -> bool:
	if a == b:
		return false

	if abs(a.x - b.x) + abs(a.y - b.y) != 1:
		return false

	if not _is_cell_placeable(a):
		return false
	if not _is_cell_placeable(b):
		return false

	for node in [a, b]:
		if node_colors.has(node) and node_colors[node] != color_name:
			return false

	var key := _edge_key(a, b)
	if edges.has(key):
		return edges[key]["color"] == color_name

	edges[key] = {"a": a, "b": b, "color": color_name}
	node_colors[a] = color_name
	node_colors[b] = color_name
	return true

# Returns true if a cable can be placed on this cell (not a wall, body, or outside map).
func _is_cell_placeable(cell: Vector2i) -> bool:
	if allowed_endpoint_cells.has(cell):
		return true
	if blocked_pc_cells.has(cell):
		return false
	if blocked_server_cells.has(cell):
		return false
	if not _is_cell_in_any_office(cell):
		return false
	if _is_wall_cell(cell):
		return false
	return true

func _is_cell_in_any_office(cell: Vector2i) -> bool:
	var world_pos := cell_to_world_center(cell)
	for tilemap in office_tilemaps:
		if not is_instance_valid(tilemap):
			continue
		var local: Vector2 = tilemap.to_local(world_pos)
		var map_cell: Vector2i = tilemap.local_to_map(local)
		var source_id: int = tilemap.get_cell_source_id(0, map_cell)
		if source_id != -1:
			return true
	return false

func _is_wall_cell(cell: Vector2i) -> bool:
	var world_pos := cell_to_world_center(cell)
	for tilemap in office_tilemaps:
		if not is_instance_valid(tilemap):
			continue
		var local: Vector2 = tilemap.to_local(world_pos)
		var map_cell: Vector2i = tilemap.local_to_map(local)
		var source_id: int = tilemap.get_cell_source_id(0, map_cell)
		if source_id == -1:
			continue
		var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(0, map_cell)
		var key := _tile_signature(source_id, atlas_coords)
		if blocked_tile_signatures.has(key):
			return true
	return false

func _tile_signature(source_id: int, atlas_coords: Vector2i) -> String:
	return "%d:%d,%d" % [source_id, atlas_coords.x, atlas_coords.y]

func _add_blocked_tile(source_id: int, atlas_coords: Vector2i) -> void:
	blocked_tile_signatures[_tile_signature(source_id, atlas_coords)] = true

func _init_default_blocked_tiles() -> void:
	for y in [11, 12]:
		for x in range(2, 9):
			_add_blocked_tile(1, Vector2i(x, y))

func _try_erase_edge(a: Vector2i, b: Vector2i, color_name: String) -> bool:
	var key := _edge_key(a, b)
	if not edges.has(key):
		return false

	if edges[key]["color"] != color_name:
		return false

	var edge: Dictionary = edges[key]
	edges.erase(key)
	_cleanup_node(edge["a"])
	_cleanup_node(edge["b"])
	return true

func _cleanup_node(cell: Vector2i) -> void:
	for dir in DIRS:
		var key := _edge_key(cell, cell + dir)
		if edges.has(key):
			return
	node_colors.erase(cell)

func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var first := a
	var second := b
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		first = b
		second = a
	return "%d,%d|%d,%d" % [first.x, first.y, second.x, second.y]

func _cells_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [a]
	var current := a

	while current.x != b.x:
		current.x += signi(b.x - current.x)
		result.append(current)

	while current.y != b.y:
		current.y += signi(b.y - current.y)
		result.append(current)

	return result

func _get_cell_mask(cell: Vector2i, color_name: String) -> int:
	var mask := 0
	for dir in DIRS:
		var key := _edge_key(cell, cell + dir)
		if not edges.has(key):
			continue
		if edges[key]["color"] != color_name:
			continue
		if dir == Vector2i.UP:
			mask |= BIT_UP
		elif dir == Vector2i.RIGHT:
			mask |= BIT_RIGHT
		elif dir == Vector2i.DOWN:
			mask |= BIT_DOWN
		elif dir == Vector2i.LEFT:
			mask |= BIT_LEFT
	return mask

# Rebuilds all visible cable segment nodes to match the current edge graph.
func _refresh_segments() -> void:
	var alive_keys := {}

	for cell in node_colors.keys():
		var color_name: String = node_colors[cell]
		var mask := _get_cell_mask(cell, color_name)
		if mask == 0:
			continue
		if not cable_variant_rects.has(color_name):
			continue

		var variant := _resolve_variant_with_context(cell, mask, color_name)
		if variant.is_empty():
			continue

		var map_for_color: Dictionary = cable_variant_rects[color_name]
		if not map_for_color.has(variant["type"]):
			continue

		var region: Rect2 = map_for_color[variant["type"]]
		var key := _cell_key(cell)
		alive_keys[key] = true
		var segment = _get_or_create_segment(key)
		segment.position = cell_to_world_center(cell)
		var flip: bool = variant.get("flip", false)
		segment.set_visual(region, int(variant["rot"]), flip)

	var to_remove: Array = []
	for key in segment_nodes.keys():
		if alive_keys.has(key):
			continue
		var stale = segment_nodes[key]
		if is_instance_valid(stale):
			stale.queue_free()
		to_remove.append(key)

	for key in to_remove:
		segment_nodes.erase(key)

func _get_or_create_segment(key: String):
	if segment_nodes.has(key):
		var existing = segment_nodes[key]
		if is_instance_valid(existing):
			return existing

	var instance = cable_segment_scene.instantiate()
	add_child(instance)
	segment_nodes[key] = instance
	return instance

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _resolve_variant(mask: int) -> Dictionary:
	if mask == (BIT_UP | BIT_RIGHT | BIT_DOWN | BIT_LEFT):
		return {"type": "cross", "rot": 0}

	if _bit_count(mask) == 3:
		if (mask & BIT_RIGHT) == 0:
			return {"type": "t", "rot": 0}
		if (mask & BIT_DOWN) == 0:
			return {"type": "t", "rot": 1}
		if (mask & BIT_LEFT) == 0:
			return {"type": "t", "rot": 2}
		return {"type": "t", "rot": 3}

	if _bit_count(mask) == 2:
		if mask == (BIT_LEFT | BIT_RIGHT):
			return {"type": "straight", "rot": 0}
		if mask == (BIT_UP | BIT_DOWN):
			return {"type": "straight", "rot": 1}
		if mask == (BIT_LEFT | BIT_DOWN):
			return {"type": "corner", "rot": 0}
		if mask == (BIT_UP | BIT_LEFT):
			return {"type": "corner", "rot": 1}
		if mask == (BIT_RIGHT | BIT_UP):
			return {"type": "corner", "rot": 2}
		return {"type": "corner", "rot": 3}

	if _bit_count(mask) == 1:
		# Base end sprite (rot=0): cable from RIGHT, cap on LEFT
		if mask == BIT_RIGHT: return {"type": "end", "rot": 0}
		if mask == BIT_DOWN:  return {"type": "end", "rot": 1}
		if mask == BIT_LEFT:  return {"type": "end", "rot": 2}
		return {"type": "end", "rot": 3}  # BIT_UP

	return {}

# Picks the correct sprite variant for a cell, including end_bent and port overrides.
func _resolve_variant_with_context(cell: Vector2i, mask: int, color_name: String) -> Dictionary:
	var base_variant := _resolve_variant(mask)
	if base_variant.is_empty():
		return base_variant

	# end_bent has priority — check before port for single-bit masks.
	if base_variant["type"] == "end":
		var cable_dir := _dir_from_single_bit(mask)
		if cable_dir != Vector2i.ZERO:
			var endpoint_dir := _get_bent_endpoint_dir(cell, cable_dir, color_name)
			if endpoint_dir != Vector2i.ZERO:
				var bent_result := _rotation_for_end_bent(cable_dir, endpoint_dir)
				if bent_result["rot"] != -1:
					return {"type": "end_bent", "rot": bent_result["rot"], "flip": bent_result["flip"]}
		return base_variant

	# Show port sprite when cable passes through a PC port cell.
	if _bit_count(mask) >= 2:
		var body_dir := _get_pc_body_dir_from_port(cell, color_name)
		if body_dir != Vector2i.ZERO:
			var bit := _dir_to_bit(body_dir)
			if (mask & bit) == 0:
				var rot := _port_rot(body_dir, mask)
				if rot >= 0:
					return {"type": "port", "rot": rot}

	return base_variant

func _get_pc_body_dir_from_port(cell: Vector2i, color_name: String) -> Vector2i:
	var pc_ports: Dictionary = pc_port_cells_by_color.get(color_name, {})
	if not pc_ports.has(cell):
		return Vector2i.ZERO
	for dir in DIRS:
		if blocked_pc_cells.has(cell + dir):
			return dir
	return Vector2i.ZERO

func _get_adjacent_pc_port_dir(cell: Vector2i, mask: int, color_name: String) -> Vector2i:
	var pc_ports: Dictionary = pc_port_cells_by_color.get(color_name, {})
	for dir in DIRS:
		var neighbor := cell + dir
		if not pc_ports.has(neighbor):
			continue
		var bit := _dir_to_bit(dir)
		if (mask & bit) != 0:
			continue
		return dir
	return Vector2i.ZERO

func _dir_to_bit(dir: Vector2i) -> int:
	if dir == Vector2i.UP:    return BIT_UP
	if dir == Vector2i.RIGHT: return BIT_RIGHT
	if dir == Vector2i.DOWN:  return BIT_DOWN
	if dir == Vector2i.LEFT:  return BIT_LEFT
	return 0

func _port_rot(stub_dir: Vector2i, mask: int) -> int:
	var is_horiz: bool = (mask & (BIT_LEFT | BIT_RIGHT)) != 0 and (mask & (BIT_UP | BIT_DOWN)) == 0
	if is_horiz:
		if stub_dir == Vector2i.UP:   return 1
		if stub_dir == Vector2i.DOWN: return 3
	else:
		if stub_dir == Vector2i.LEFT:  return 0
		if stub_dir == Vector2i.RIGHT: return 2
	return -1

func _dir_to_rot(dir: Vector2i) -> int:
	if dir == Vector2i.LEFT:  return 0
	if dir == Vector2i.UP:    return 1
	if dir == Vector2i.RIGHT: return 2
	if dir == Vector2i.DOWN:  return 3
	return 0

func _dir_from_single_bit(mask: int) -> Vector2i:
	if mask == BIT_UP:    return Vector2i.UP
	if mask == BIT_RIGHT: return Vector2i.RIGHT
	if mask == BIT_DOWN:  return Vector2i.DOWN
	if mask == BIT_LEFT:  return Vector2i.LEFT
	return Vector2i.ZERO

# Returns the direction the end cap should bend toward (PC body or server port).
func _get_bent_endpoint_dir(cell: Vector2i, cable_dir: Vector2i, color_name: String) -> Vector2i:
	var server_ports: Dictionary = server_cells_by_color.get(color_name, {})
	var pc_ports: Dictionary = pc_port_cells_by_color.get(color_name, {})

	if server_ports.has(cell):
		return Vector2i.ZERO

	# Cable ends directly on the PC port cell — bend cap toward the PC body.
	if pc_ports.has(cell):
		for bdir in DIRS:
			if blocked_pc_cells.has(cell + bdir):
				return bdir
		return Vector2i.ZERO

	# Cable ends adjacent to a server port — bend cap toward the server.
	for dir in DIRS:
		var neighbor := cell + dir
		if server_ports.has(neighbor):
			return dir

	return Vector2i.ZERO

# Rotates a direction vector clockwise in screen-space (Y-down) by the given number of steps.
func _rotate_dir_cw(dir: Vector2i, steps: int) -> Vector2i:
	var d := dir
	for _i in range(steps % 4):
		d = Vector2i(-d.y, d.x)
	return d

# Finds the rotation (and optional flip) needed to orient the end_bent sprite.
func _rotation_for_end_bent(cable_dir: Vector2i, endpoint_dir: Vector2i) -> Dictionary:
	# Base sprite (rot=0): cable from DOWN, cap pointing RIGHT.
	var base_cable := Vector2i.DOWN
	var base_endpoint := Vector2i.RIGHT
	for rot in range(4):
		if _rotate_dir_cw(base_cable, rot) == cable_dir and _rotate_dir_cw(base_endpoint, rot) == endpoint_dir:
			return {"rot": rot, "flip": false}
	# Mirrored case: flip_h gives cable from DOWN, cap pointing LEFT.
	var base_endpoint_flip := Vector2i.LEFT
	for rot in range(4):
		if _rotate_dir_cw(base_cable, rot) == cable_dir and _rotate_dir_cw(base_endpoint_flip, rot) == endpoint_dir:
			return {"rot": rot, "flip": true}
	return {"rot": -1, "flip": false}

func _cell_connects_to_endpoint(cell: Vector2i, endpoint_cell: Vector2i, color_name: String) -> bool:
	var to_endpoint := endpoint_cell - cell
	if abs(to_endpoint.x) + abs(to_endpoint.y) != 1:
		return false

	var mask := _get_cell_mask(cell, color_name)
	if _bit_count(mask) != 1:
		return false

	var variant := _resolve_variant_with_context(cell, mask, color_name)
	if variant.is_empty():
		return false

	var variant_type: String = variant["type"]
	if variant_type != "end" and variant_type != "end_bent":
		return false

	var rot: int = int(variant["rot"])
	var base_connector := Vector2i.LEFT
	return _rotate_dir_cw(base_connector, rot) == to_endpoint

func _bit_count(mask: int) -> int:
	var count := 0
	if (mask & BIT_UP) != 0:    count += 1
	if (mask & BIT_RIGHT) != 0: count += 1
	if (mask & BIT_DOWN) != 0:  count += 1
	if (mask & BIT_LEFT) != 0:  count += 1
	return count
