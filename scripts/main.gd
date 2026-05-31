extends Node2D

const LeaderboardStore = preload("res://scripts/leaderboard_store.gd")

@export var pc_scene = preload("res://scenes/pc.tscn")
var server_scene = preload("res://scenes/server.tscn")
var office_scenes = [
	preload("res://scenes/offices/office_01.tscn"),
	preload("res://scenes/offices/office_02.tscn"),
	preload("res://scenes/offices/office_03.tscn"),
	preload("res://scenes/offices/office_04.tscn")
]
@onready var spawn_timer: Timer = $SpawnTimer
@onready var timer_label = $CanvasLayer/TimerLabel
@onready var spawn_label = $CanvasLayer/SpawnLabel
@onready var cable_color_label = $CanvasLayer/CableColorLabel
@onready var status_label = $CanvasLayer/StatusLabel
@onready var game_over_overlay = $CanvasLayer/GameOverOverlay
@onready var cable_grid = $CableGrid

const CABLE_COLORS: Array[String] = ["red", "blue", "green", "purple"]

var offices = []
var latest_office = null
var current_server = null
var available_colors = []
var office_used_points = {}
var occupied_positions = []
const ROOM_SIZE = 160
var elapsed_time: float = 0.0

@export var pc_spawn_interval_sec: float = 8.0
@export var ratio_check_starts_at_pc_count: int = 4
@export var max_pcs_per_map: int = 10

var all_servers: Array = []
var all_pcs: Array = []
var selected_color := "red"
var spawn_countdown := 0.0
var game_over := false
var is_drawing := false
var is_erasing := false
var last_mouse_world := Vector2.ZERO
var total_pcs_spawned: int = 0

var DIRECTIONS = [
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(0, -1)
]

# Sets up the first office, starts the spawn timer and syncs the grid.
func _ready() -> void:
	cable_grid.z_index = 1000
	spawn_first_office()
	spawn_countdown = pc_spawn_interval_sec
	spawn_timer.wait_time = pc_spawn_interval_sec
	spawn_timer.start()
	_ensure_selected_color()
	_update_color_label()
	_sync_blocked_cells()

# Picks a random office that has a server and places it at the origin.
func spawn_first_office():
	var valid = []
	for scene in office_scenes:
		var temp = scene.instantiate()
		if temp.has_server:
			valid.append(scene)
		temp.queue_free()

	var scene = valid.pick_random()
	var office = scene.instantiate()
	office.global_position = Vector2(0, 0)
	add_child(office)
	cable_grid.register_office_tilemap(office.get_node("TileMap"))
	offices.append(office)
	latest_office = office
	occupied_positions.append(office.global_position)
	office_used_points[office] = []
	spawn_server_for_office(office)

# Expands the map by attaching a new office to any free adjacent slot.
func spawn_new_office():
	var possible_spots = []
	for office in offices:
		for dir in DIRECTIONS:
			var pos = office.global_position + dir * ROOM_SIZE
			if pos not in occupied_positions:
				possible_spots.append(pos)

	if possible_spots.is_empty():
		return

	var chosen_pos = possible_spots.pick_random()
	var scene = office_scenes.pick_random()
	var new_office = scene.instantiate()
	new_office.global_position = chosen_pos
	add_child(new_office)
	cable_grid.register_office_tilemap(new_office.get_node("TileMap"))
	offices.append(new_office)
	latest_office = new_office
	occupied_positions.append(chosen_pos)
	office_used_points[new_office] = []
	total_pcs_spawned = 0
	if new_office.has_server:
		spawn_server_for_office(new_office)

# Spawns a server inside the given office and assigns it a random color.
func spawn_server_for_office(office):
	var server_spawn = office.get_node("ServerSpawn")
	var server = server_scene.instantiate()
	server.global_position = server_spawn.global_position
	add_child(server)

	var color = ["red", "blue", "green", "purple"].pick_random()
	server.set_color(color)

	if color not in available_colors:
		available_colors.append(color)

	current_server = server
	all_servers.append(server)
	_sync_blocked_cells()
	_ensure_selected_color()
	_update_color_label()

# Returns true if the current office still has room and hasn't hit the per-map PC limit.
func can_spawn_pc():
	if latest_office == null:
		return false

	if total_pcs_spawned >= max_pcs_per_map:
		return false

	var points = latest_office.get_node("SpawnPoints").get_children()
	var used = office_used_points[latest_office]
	return used.size() < points.size()

# Picks a random free spawn point in the current office and places a PC there.
func spawn_pc():
	if latest_office == null:
		return

	var points = latest_office.get_node("SpawnPoints").get_children()
	var used = office_used_points[latest_office]
	var available = []

	for p in points:
		if p not in used:
			if not cable_grid.is_port_cell_usable(p.global_position, p.facing):
				continue
			available.append(p)

	if available.is_empty():
		return

	var chosen = available.pick_random()
	used.append(chosen)

	var pc = pc_scene.instantiate()
	pc.global_position = chosen.global_position
	add_child(pc)

	var random_color = available_colors.pick_random()
	pc.set_state(random_color, chosen.facing, false)
	all_pcs.append(pc)
	total_pcs_spawned += 1
	_sync_blocked_cells()
	_update_pc_connections()

# Runs every spawn interval: checks game-over, spawns a PC or a new office.
func _on_spawn_timer_timeout():
	if game_over:
		return

	if latest_office == null:
		return

	_update_pc_connections()
	if _is_game_over_by_ratio():
		_set_game_over()
		return

	if can_spawn_pc():
		spawn_pc()
	else:
		spawn_new_office()

	spawn_countdown = pc_spawn_interval_sec
	spawn_timer.wait_time = pc_spawn_interval_sec
	spawn_timer.start()

func _process(_delta):
	if game_over:
		return

	elapsed_time += _delta
	spawn_countdown = maxf(spawn_countdown - _delta, 0.0)

	var total_seconds = int(elapsed_time)
	var play_hours = int(total_seconds / 3600.0)
	var play_minutes = int((total_seconds % 3600) / 60.0)
	var play_seconds = total_seconds % 60

	timer_label.text = "Time: %02d:%02d:%02d" % [play_hours, play_minutes, play_seconds]
	spawn_label.text = "Next PC: %.1fs" % spawn_countdown
	_update_status_label()

func _input(event):
	if game_over:
		if event.is_action_pressed("ui_cancel"):
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
		return

	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_1:
			_select_color_by_index(0)
		elif key_event.keycode == KEY_2:
			_select_color_by_index(1)
		elif key_event.keycode == KEY_3:
			_select_color_by_index(2)
		elif key_event.keycode == KEY_4:
			_select_color_by_index(3)
		elif key_event.keycode == KEY_Q:
			_cycle_color(-1)
		elif key_event.keycode == KEY_E:
			_cycle_color(1)

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			is_drawing = mb.pressed
			if mb.pressed:
				last_mouse_world = get_global_mouse_position()
				_apply_drag(last_mouse_world)
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			is_erasing = mb.pressed
			if mb.pressed:
				last_mouse_world = get_global_mouse_position()
				_apply_drag(last_mouse_world)

	if event is InputEventMouseMotion and (is_drawing or is_erasing):
		_apply_drag(get_global_mouse_position())

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

# Places or erases cable along the dragged mouse path.
func _apply_drag(current_world: Vector2) -> void:
	_ensure_selected_color()
	_sync_blocked_cells()
	if is_drawing:
		if cable_grid.try_place_line(last_mouse_world, current_world, selected_color):
			_update_pc_connections()
	elif is_erasing:
		if cable_grid.try_erase_line(last_mouse_world, current_world, selected_color):
			_update_pc_connections()
	last_mouse_world = current_world

# Rebuilds the blocked-cell sets from all active PCs and servers.
func _sync_blocked_cells() -> void:
	var pc_cells := {}
	var server_cells := {}
	var endpoint_cells := {}

	for server in all_servers:
		if not is_instance_valid(server):
			continue
		var body: Array[Vector2i] = cable_grid.get_server_body_cells(server.global_position)
		for bc in body:
			server_cells[bc] = true
		var ports: Array[Vector2i] = cable_grid.get_server_port_cells(server.global_position)
		for pc_port in ports:
			endpoint_cells[pc_port] = true

	for pc in all_pcs:
		if not is_instance_valid(pc):
			continue
		var pc_body_cell: Vector2i = _get_pc_body_cell(pc)
		pc_cells[pc_body_cell] = true
		var port_cell: Vector2i = _get_pc_port_cell(pc)
		endpoint_cells[port_cell] = true

	cable_grid.set_blocked_entity_cells(pc_cells, server_cells, endpoint_cells)

# Runs BFS from each server and marks PCs as connected or disconnected.
func _update_pc_connections() -> void:
	var connected_cells_by_color := {}
	var server_cells_by_color := {}
	var pc_port_cells_by_color := {}

	for color_name in CABLE_COLORS:
		server_cells_by_color[color_name] = {}
		pc_port_cells_by_color[color_name] = {}

	for server in all_servers:
		if not is_instance_valid(server):
			continue
		if not server_cells_by_color.has(server.current_color):
			server_cells_by_color[server.current_color] = {}
		var ports: Array[Vector2i] = cable_grid.get_server_port_cells(server.global_position)
		for port in ports:
			server_cells_by_color[server.current_color][port] = true

	for pc in all_pcs:
		if not is_instance_valid(pc):
			continue
		if not pc_port_cells_by_color.has(pc.color):
			pc_port_cells_by_color[pc.color] = {}
		var port_cell: Vector2i = _get_pc_port_cell(pc)
		pc_port_cells_by_color[pc.color][port_cell] = true

	cable_grid.set_endpoint_cells(server_cells_by_color, pc_port_cells_by_color)

	for color_name in available_colors:
		var starts: Array[Vector2i] = []
		var server_ports: Dictionary = server_cells_by_color.get(color_name, {})
		for port_cell in server_ports.keys():
			if cable_grid.node_colors.get(port_cell, "") == color_name:
				if port_cell not in starts:
					starts.append(port_cell)
			for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var neighbor: Vector2i = port_cell + dir
				if cable_grid.node_colors.get(neighbor, "") != color_name:
					continue
				var key: String = cable_grid._edge_key(port_cell, neighbor)
				if cable_grid.edges.has(key) and cable_grid.edges[key]["color"] == color_name:
					if neighbor not in starts:
						starts.append(neighbor)
		connected_cells_by_color[color_name] = cable_grid.get_connected_cells(starts, color_name)

	for pc in all_pcs:
		if not is_instance_valid(pc):
			continue
		var connected_set: Dictionary = connected_cells_by_color.get(pc.color, {})
		var port_cell: Vector2i = _get_pc_port_cell(pc)
		var is_connected: bool = connected_set.has(port_cell)
		pc.set_connected(is_connected)

func _get_pc_body_cell(pc) -> Vector2i:
	return cable_grid.world_to_cell(pc.global_position)

func _get_pc_port_cell(pc) -> Vector2i:
	return cable_grid.get_port_cell(pc.global_position, pc.facing)

# Returns true if any color has >= 4 PCs and fewer than half are connected.
func _is_game_over_by_ratio() -> bool:
	var total := {}
	var connected := {}

	for pc in all_pcs:
		if not is_instance_valid(pc):
			continue
		total[pc.color] = int(total.get(pc.color, 0)) + 1
		if pc.linked:
			connected[pc.color] = int(connected.get(pc.color, 0)) + 1

	for color_name in total.keys():
		var color_total: int = total[color_name]
		if color_total < ratio_check_starts_at_pc_count:
			continue
		var color_connected: int = int(connected.get(color_name, 0))
		var ratio := float(color_connected) / float(color_total)
		if ratio < 0.5:
			return true

	return false

func _set_game_over() -> void:
	game_over = true
	spawn_timer.stop()
	LeaderboardStore.add_result(_format_game_over_date(), _get_connected_pc_count(), _format_elapsed_time())
	timer_label.visible = false
	spawn_label.visible = false
	cable_color_label.visible = false
	status_label.visible = false
	game_over_overlay.visible = true

func _get_connected_pc_count() -> int:
	var connected := 0
	for pc in all_pcs:
		if not is_instance_valid(pc):
			continue
		if pc.linked:
			connected += 1
	return connected

func _format_elapsed_time() -> String:
	var total_seconds := int(elapsed_time)
	var hh := int(total_seconds / 3600.0)
	var mm := int((total_seconds % 3600) / 60.0)
	var ss := total_seconds % 60
	return "%02d:%02d:%02d" % [hh, mm, ss]

func _format_game_over_date() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var day := int(dt.get("day", 1))
	var month := int(dt.get("month", 1))
	var year := int(dt.get("year", 1970))
	var hour := int(dt.get("hour", 0))
	var minute := int(dt.get("minute", 0))
	return "%02d.%02d.%04d %02d:%02d" % [day, month, year, hour, minute]

func _ensure_selected_color() -> void:
	if selected_color not in CABLE_COLORS:
		selected_color = CABLE_COLORS[0]
	_update_color_label()

func _select_color_by_index(index: int) -> void:
	if index >= 0 and index < CABLE_COLORS.size():
		selected_color = CABLE_COLORS[index]
		_update_color_label()

func _cycle_color(delta: int) -> void:
	var idx := CABLE_COLORS.find(selected_color)
	if idx == -1:
		selected_color = CABLE_COLORS[0]
	else:
		selected_color = CABLE_COLORS[(idx + delta + CABLE_COLORS.size()) % CABLE_COLORS.size()]
	_update_color_label()

func _update_color_label() -> void:
	cable_color_label.text = "Cable: %s" % selected_color.capitalize()

func _update_status_label() -> void:
	var total := 0
	var connected := 0
	for pc in all_pcs:
		if not is_instance_valid(pc):
			continue
		total += 1
		if pc.linked:
			connected += 1
	status_label.text = "Connected: %d/%d" % [connected, total]
