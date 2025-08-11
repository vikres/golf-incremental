extends Node

# -------- CONFIG --------
@export var current_level: int = 1
@export var max_levels: int = 5

# Cover behavior (local to SubViewport)
@export var cover_in_speed: float = 1.6
@export var cover_out_speed: float = 1.4
@export var cover_hold_seconds: float = 6.0
@export var cover_color: Color = Color("#ead4b4")
@export var cover_edge_softness: float = 0.12
@export var debug_enabled: bool = false

# -------- STATE --------
var loaded_level_scene: Node2D
var par: int = 3
var current_shots: int = 0
var input_enabled: bool = true
var processing_completion: bool = false

# -------- REFS ---------
var main_scene: Node
var level_viewport_container: SubViewportContainer
var level_viewport: SubViewport
var game_root: Node2D

var spawn_point: Marker2D
var hole: Area2D
var ball                        # leave untyped to avoid static type noise
var divot_renderer: Node2D
var ball_display: Node

var cover                       # LocalViewportCover (don't rely on class_name)
var completion_board: Control

# UI elements to hide during transitions
var terraintab: Control
var hover_tooltip: Control

signal shot_taken(shot_number: int)

func _ready() -> void:
	main_scene = get_tree().current_scene

	level_viewport_container = main_scene.get_node("LevelViewportContainer") as SubViewportContainer
	level_viewport = level_viewport_container.get_node("LevelViewport") as SubViewport
	game_root = level_viewport.get_node("GameRoot") as Node2D

	level_viewport_container.clip_contents = true

	# Local overlay & board live INSIDE the SubViewport
	cover = level_viewport.get_node_or_null("ViewportCover")
	if cover == null:
		_dbg("WARN: ViewportCover not found under LevelViewport; trying recursive search")
		cover = level_viewport.find_child("ViewportCover", true, false)

	# Optional board (suggested path: LevelViewport/BoardLayer/CompletionBoard)
	completion_board = level_viewport.get_node_or_null("BoardLayer/CompletionBoard") as Control
	if completion_board == null:
		completion_board = level_viewport.get_node_or_null("CompletionBoard") as Control

	# UI elements to hide during transitions
	terraintab = main_scene.get_node_or_null("UI/TerrainTab") as Control
	hover_tooltip = main_scene.get_node_or_null("UI/HoverTooltip") as Control

	# Give the cover a frame to build its internal ColorRect (if it does)
	await get_tree().process_frame
	if cover:
		if cover.has_method("set_color"):
			cover.call("set_color", cover_color)
		if cover.has_method("set_edge_softness"):
			cover.call("set_edge_softness", cover_edge_softness)
		if cover.has_method("use_scribbles_from_plugin"):
			cover.call("use_scribbles_from_plugin", false)

	if completion_board:
		completion_board.set_anchors_preset(Control.PRESET_FULL_RECT)
		completion_board.visible = false

	# Optional UI
	ball_display = main_scene.get_node_or_null("UI/TerrainTab/Control2")

	_setup_ball()
	_setup_divots()

	GameManager.set_game_root(game_root)
	load_level(current_level)

# -------- INPUT --------
func _input(event: InputEvent) -> void:
	if not input_enabled or ball == null:
		return

	if event is InputEventMouse:
		var me := event as InputEventMouse
		var rect: Rect2 = level_viewport_container.get_rect()
		var gpos: Vector2 = me.global_position
		var in_box: bool = rect.has_point(gpos - level_viewport_container.global_position)

		if me is InputEventMouseButton and me.pressed and me.button_index == MOUSE_BUTTON_LEFT:
			if not in_box:
				return

		var local_pos: Vector2 = gpos - level_viewport_container.global_position - rect.position
		var dup := me.duplicate() as InputEventMouse
		if dup and ball and ball.has_method("receive_input"):
			dup.position = local_pos
			ball.call("receive_input", dup)

	elif event is InputEventKey:
		if ball and ball.has_method("receive_input"):
			ball.call("receive_input", event)

# -------- SETUP --------
func _setup_ball() -> void:
	ball = game_root.get_node_or_null("GolfBall")
	if ball == null:
		var found := main_scene.find_child("GolfBall", true, false)
		if found:
			found.get_parent().remove_child(found)
			game_root.add_child(found)
			ball = found

	# ✅ connect by signal NAME to avoid property access on typed base
	if ball and ball.has_signal("ball_shot"):
		var cb := Callable(self, "_on_ball_shot")
		if not ball.is_connected("ball_shot", cb):
			ball.connect("ball_shot", cb)

func _setup_divots() -> void:
	divot_renderer = load("res://scripts/DivotRenderer.gd").new()
	game_root.add_child(divot_renderer)
	if divot_renderer.has_method("setup"):
		divot_renderer.call("setup", ball)
	if ball and ball.has_method("set_divot_renderer"):
		ball.call("set_divot_renderer", divot_renderer)

# -------- UI CONTROL --------
func _hide_ui_elements() -> void:
	var tween1 = create_tween()
	tween1.tween_property(terraintab, "modulate:a", 0.0, 0.3)
	
	var tween2 = create_tween()
	tween2.tween_property(hover_tooltip, "modulate:a", 0.0, 0.3)

func _show_ui_elements() -> void:
	var tween1 = create_tween()
	tween1.tween_property(terraintab, "modulate:a", 1.0, 0.3)
	
	var tween2 = create_tween()
	tween2.tween_property(hover_tooltip, "modulate:a", 1.0, 0.3)

# -------- FLOW --------
func _on_ball_shot() -> void:
	current_shots += 1
	shot_taken.emit(current_shots)
	if ball_display and ball_display.has_method("use_ball"):
		ball_display.call("use_ball")

func load_level(level_number: int) -> void:
	var path := "res://levels/level" + str(level_number) + ".tscn"
	if not ResourceLoader.exists(path):
		path = "res://levels/level1.tscn"
		level_number = 1

	GameManager.cleanup_items()

	if loaded_level_scene:
		loaded_level_scene.queue_free()
		await loaded_level_scene.tree_exited
	await get_tree().process_frame

	var pscene := load(path) as PackedScene
	loaded_level_scene = pscene.instantiate() as Node2D
	game_root.add_child(loaded_level_scene)
	game_root.scale = Vector2.ONE
	game_root.position = Vector2.ZERO
	game_root.rotation = 0.0

	var tilemap = loaded_level_scene.get_node("GrassLayer")
	var cam = game_root.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = "Camera2D"
		game_root.add_child(cam)
	cam.make_current()
	_fit_camera_to_box(tilemap, cam, level_viewport, true)

	spawn_point = loaded_level_scene.get_node_or_null("SpawnPoint") as Marker2D
	hole = loaded_level_scene.get_node_or_null("Hole") as Area2D

	current_level = level_number
	_set_par_for_level(current_level)

	await get_tree().process_frame
	_initialize_collectibles()
	_start_level()

func _initialize_collectibles() -> void:
	var grass = loaded_level_scene.get_node_or_null("GrassLayer")
	var deco = loaded_level_scene.get_node_or_null("DecorationsLayer")
	var water = loaded_level_scene.get_node_or_null("WaterLayer")
	if grass:
		GameManager.set_tilemap_spawning(grass, deco, water)
		if GameManager.has_method("spawn_initial_ladybugs"):
			GameManager.call("spawn_initial_ladybugs")
		if GameManager.has_method("start_spawning"):
			GameManager.call("start_spawning")

func _set_par_for_level(n: int) -> void:
	if n == 1:
		par = 3
	else:
		par = 4

func _start_level() -> void:
	current_shots = 0
	input_enabled = false

	if ball and ball.has_method("reset_ball"):
		ball.call("reset_ball")
		ball.set_physics_process(true)
		ball.set_process_input(true)

	await get_tree().physics_frame
	if hole and hole.has_method("reset_hole"):
		hole.call("reset_hole")
	await get_tree().physics_frame
	if hole and hole.has_method("arm"):
		hole.call("arm")

	if divot_renderer and divot_renderer.has_method("clear_all_divots"):
		divot_renderer.call("clear_all_divots")

	input_enabled = true

func handle_hole_completion() -> void:
	if processing_completion:
		return
	processing_completion = true
	input_enabled = false

	if hole and hole.has_method("disarm"):
		hole.call("disarm")

	var shots_under_par: int = par - current_shots
	GameManager.add_money(GameManager.base_hole_gain)

	# 1) Hide UI elements before transition starts
	_hide_ui_elements()

	# 2) Cover only the SubViewport
	if cover and cover.has_method("fade_out"):
		await cover.call("fade_out", cover_in_speed)

	# 3) Show board WHILE covered
	if completion_board and completion_board.has_method("show_board"):
		completion_board.call("show_board", current_shots, par)

	# 4) Let it breathe
	await get_tree().create_timer(cover_hold_seconds).timeout

	# 5) Load next level under cover
	var next_level: int
	if shots_under_par >= 0 and current_level < max_levels:
		next_level = current_level + 1
	else:
		next_level = 1
	load_level(next_level)
	await get_tree().process_frame
	await get_tree().process_frame

	# 6) Reveal
	if cover and cover.has_method("fade_in"):
		await cover.call("fade_in", cover_out_speed)

	# 8) Show UI elements after transition completes
	_show_ui_elements()

	input_enabled = true
	processing_completion = false

# -------- CAMERA FIT --------
func _fit_camera_to_box(tilemap, camera: Camera2D, subvp: SubViewport, fill_exact: bool) -> void:
	if tilemap == null or camera == null or subvp == null:
		return

	var root := tilemap.get_parent() as Node2D
	if root:
		root.scale = Vector2.ONE
		root.position = Vector2.ZERO
		root.rotation = 0.0

	var used: Rect2i = tilemap.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return

	var ts: Vector2 = Vector2(tilemap.tile_set.tile_size)
	var half_local: Vector2 = ts * 0.5

	var tl_c_l: Vector2 = tilemap.map_to_local(used.position)
	var tr_c_l: Vector2 = tilemap.map_to_local(used.position + Vector2i(used.size.x, 0))
	var bl_c_l: Vector2 = tilemap.map_to_local(used.position + Vector2i(0, used.size.y))

	var tl_c_w: Vector2 = tilemap.to_global(tl_c_l)
	var tr_c_w: Vector2 = tilemap.to_global(tr_c_l)
	var bl_c_w: Vector2 = tilemap.to_global(bl_c_l)

	var half_w: Vector2 = tilemap.to_global(half_local) - tilemap.to_global(Vector2.ZERO)

	var left: float = tl_c_w.x - half_w.x
	var top: float = tl_c_w.y - half_w.y
	var right: float = tr_c_w.x - half_w.x
	var bottom: float = bl_c_w.y - half_w.y

	var level_size: Vector2 = Vector2(right - left, bottom - top)
	var level_center: Vector2 = Vector2(left, top) + level_size * 0.5

	var vp: Vector2 = subvp.size
	var zx: float
	var zy: float
	if fill_exact:
		zx = vp.x / level_size.x
		zy = vp.y / level_size.y
	else:
		var s: float = min(vp.x / level_size.x, vp.y / level_size.y)
		zx = s
		zy = s

	camera.zoom = Vector2(zx, zy)

	var halfpix := Vector2.ZERO
	if int(vp.x) % 2 == 0:
		halfpix.x = 0.5 / zx
	if int(vp.y) % 2 == 0:
		halfpix.y = 0.5 / zy

	camera.position = level_center + halfpix
	camera.position_smoothing_enabled = false
	camera.make_current()

# -------- DEBUG --------
func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[CourseManager] ", msg)

# Public API expected by other scripts (Ball, SurfaceManager, etc.)

func get_spawn_position() -> Vector2:
	# Used by Ball.reset_ball()
	if spawn_point:
		return spawn_point.global_position
	return Vector2(100, 200)  # sane fallback

func start_course() -> void:
	# Some code calls this; forward to our internal starter.
	_start_level()

func restart_level_player_lost() -> void:
	# SurfaceManager may call this (e.g., on water). Keep it simple.
	_start_level()
