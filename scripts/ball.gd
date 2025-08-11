extends CharacterBody2D

signal ball_shot

# ========== CHILD SYSTEMS ==========
@onready var ball_visual: Node = $BallVisual
var surface_manager: Node
var divot_renderer: Node2D

# ========== GAMEPLAY CONFIG ==========
# These are now base values - actual values will be calculated by UpgradeManager
@export var max_power: int = 5
@export var friction: float = 0.93
@export var wall_bounce_factor: float = 0.8
@export var max_spray_angle: float = 45.0
@export var accuracy: float = 0.1
@export var sand_spray_multiplier: float = 1.5
@export var cone_opacity: float = 0.3
@export var min_drag_distance: float = 10.0
@export var base_cooldown: float = 0.0
@export var cone_visual_mode: int = 0

# Store base stats for upgrade calculations
var base_stats: Dictionary = {}

# ========== STATE ==========
var input_enabled: bool = true
var ball_velocity: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_pos: Vector2
var shoot_cooldown: float = 0.0
var just_collided: bool = false

var arrow_visible: bool = false
var arrow_direction: Vector2
var arrow_length: float
var spray_cone_angle: float = 0.0

# ========== INIT ==========
func _ready():
	# Store base stats before any upgrades are applied
	store_base_stats()
	
	await get_tree().process_frame
	
	# Register with UpgradeManager (this will apply all upgrades)
	UpgradeManager.register_object("ball", self)

	surface_manager = load("res://scripts/SurfaceManager.gd").new()
	add_child(surface_manager)

	set_physics_process(true)

func store_base_stats():
	base_stats = {
		"max_power": max_power,
		"friction": friction,
		"accuracy": accuracy,
		"max_spray_angle": max_spray_angle,
		"sand_spray_multiplier": sand_spray_multiplier
	}

func get_base_stat(property: String):
	return base_stats.get(property, 0)

func receive_input(event: InputEvent):
	if not input_enabled:
		return

	if event is InputEventMouseButton:
		var mouse_pos = get_world_mouse_position(event)
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			start_drag(mouse_pos)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_dragging:
			shoot(mouse_pos)
	elif event is InputEventMouseMotion and is_dragging:
		var mouse_pos = get_world_mouse_position(event)
		update_drag(mouse_pos)

func get_world_mouse_position(event: InputEvent) -> Vector2:
	if "position" in event:
		return event.position
	else:
		return get_viewport().get_mouse_position()

# ========== DRAG & SHOOT ==========
func start_drag(mouse_pos: Vector2):
	if ball_velocity.length() > 0.2:
		return

	is_dragging = true
	drag_start_pos = mouse_pos

func update_drag(mouse_pos: Vector2):
	if not is_dragging:
		return
		
	var pull_vector = drag_start_pos - mouse_pos
	var distance = pull_vector.length()

	if distance < min_drag_distance:
		hide_ui()
		return

	var capped_power = min(distance / 50.0, 1.0)
	arrow_direction = pull_vector.normalized()
	arrow_length = capped_power * max_power * 15.0
	spray_cone_angle = calculate_spray_angle(capped_power)

	arrow_visible = true
	queue_redraw()

func shoot(mouse_pos: Vector2):
	if not is_dragging or shoot_cooldown > 0.0:
		return

	is_dragging = false
	hide_ui()

	var pull_vector = drag_start_pos - mouse_pos
	var distance = pull_vector.length()

	if distance < min_drag_distance:
		return

	var capped_power = min(distance / 100.0, 1.0)
	var shoot_direction = pull_vector.normalized()
	var base_velocity = shoot_direction * capped_power * max_power * 100.0

	var spray_deviation = calculate_spray_deviation(capped_power)
	var final_direction = base_velocity.normalized().rotated(spray_deviation)
	ball_velocity = final_direction * base_velocity.length()

	shoot_cooldown = base_cooldown
	just_collided = false
	ball_shot.emit()

	if divot_renderer and surface_manager:
		divot_renderer.create_shot_divot(global_position, final_direction, surface_manager.get_current_surface(), ball_velocity.length())

# ========== PHYSICS ==========
func _physics_process(delta):
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta

	ball_velocity *= pow(friction, delta * 60.0)

	if ball_velocity.length() < 10:
		ball_velocity = Vector2.ZERO
		just_collided = false

	velocity = ball_velocity
	move_and_slide()

	handle_collisions()

	if surface_manager:
		surface_manager.check_and_apply_surface_effects()

	if divot_renderer:
		divot_renderer.update_divots(delta)

	if get_slide_collision_count() == 0:
		just_collided = false

func handle_collisions():
	if just_collided or ball_velocity.length() < 10:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		
		if collider.has_method("collect"):
			collider.collect()

		if collider is StaticBody2D:
			var parent = collider.get_parent()
			if parent.has_method("hide_temporarily"):
				var bounce_dir = ball_velocity.bounce(normal).normalized().rotated(deg_to_rad(randf_range(-5.0, 5.0)))
				ball_velocity = bounce_dir * ball_velocity.length() * randf_range(0.4, 0.6)
				parent.hide_temporarily()
				just_collided = true
				return

		elif collider is TileMapLayer and collider.name == "WallLayer":
			ball_velocity = ball_velocity.bounce(normal) * wall_bounce_factor
			just_collided = true
			return

# ========== VISUAL DRAWING ==========
func _draw():
	if not arrow_visible:
		return

	draw_spray_cone()
	draw_arrow()

func draw_arrow():
	var arrow_color = Color.WHITE
	arrow_color.a = 0.8
	var rect_width = 4.0
	var tip_size = 8.0
	
	var rect_length = arrow_length - tip_size
	if rect_length > 0:
		var rect_end = arrow_direction * rect_length
		var perpendicular = Vector2(-arrow_direction.y, arrow_direction.x) * (rect_width / 2.0)
		
		var rect_points = PackedVector2Array([
			perpendicular,
			-perpendicular,
			rect_end - perpendicular,
			rect_end + perpendicular
		])
		draw_colored_polygon(rect_points, arrow_color)
	
	var tip_start = arrow_direction * rect_length
	var tip_end = arrow_direction * arrow_length
	var angle = arrow_direction.angle()
	var tip_base1 = tip_start + Vector2(cos(angle + PI/2), sin(angle + PI/2)) * (rect_width / 2.0)
	var tip_base2 = tip_start + Vector2(cos(angle - PI/2), sin(angle - PI/2)) * (rect_width / 2.0)
	
	var tip_points = PackedVector2Array([tip_base1, tip_base2, tip_end])
	draw_colored_polygon(tip_points, arrow_color)

func draw_spray_cone():
	if spray_cone_angle <= 0.0:
		return

	var cone_length = arrow_length
	var half_angle_rad = deg_to_rad(spray_cone_angle / 2.0)
	var arrow_angle = arrow_direction.angle()

	var left = Vector2(cos(arrow_angle - half_angle_rad), sin(arrow_angle - half_angle_rad)) * cone_length
	var right = Vector2(cos(arrow_angle + half_angle_rad), sin(arrow_angle + half_angle_rad)) * cone_length

	var cone_color = Color.WHITE
	cone_color.a = cone_opacity

	if cone_visual_mode == 0:
		draw_line(Vector2.ZERO, left, cone_color, 2.0)
		draw_line(Vector2.ZERO, right, cone_color, 2.0)
		draw_line(left, right, cone_color, 2.0)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, left, right]), cone_color)

func hide_ui():
	arrow_visible = false
	queue_redraw()

func set_divot_renderer(renderer: Node2D):
	divot_renderer = renderer

func calculate_spray_angle(capped_power: float) -> float:
	var base_angle = max_spray_angle * capped_power * (1.0 - accuracy)
	var surface_multiplier = (sand_spray_multiplier if surface_manager and surface_manager.get_current_surface() == 1 else 1.0)
	return base_angle * surface_multiplier

func calculate_spray_deviation(capped_power: float) -> float:
	if spray_cone_angle <= 0.0:
		return 0.0
	
	var max_rad = deg_to_rad(spray_cone_angle / 2.0)
	var center_bias = accuracy * 3.0
	
	var u1 = randf()
	var u2 = randf()
	
	var triangular_sample = (u1 + u2 * center_bias) / (1.0 + center_bias)
	triangular_sample = clamp(triangular_sample, 0.0, 1.0)
	
	var angle_magnitude = triangular_sample * max_rad
	var direction = 1.0 if randf() > 0.5 else -1.0
	
	return angle_magnitude * direction

# ========== RESET & UPGRADE API ==========
func reset_ball():
	global_position = CourseManager.get_spawn_position()
	ball_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	is_dragging = false
	just_collided = false
	shoot_cooldown = 0.0
	input_enabled = true
	hide_ui()
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE

	await get_tree().process_frame
	set_physics_process(true)

func change_ball_skin(skin_type: BallVisual.BallSkin):
	if ball_visual:
		ball_visual.set_ball_skin(skin_type)

func get_current_surface():
	return surface_manager.get_current_surface() if surface_manager else 0
