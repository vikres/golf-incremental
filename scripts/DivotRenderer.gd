# DivotRenderer.gd - Handles all divot marks and shot particles
extends Node2D

# ========== DIVOT MARK CLASS ==========
class DivotMark:
	var position: Vector2
	var direction: Vector2
	var surface_type: int
	var age: float = 0.0
	var shot_power: float
	var random_seed: int
	
	var main_divot_points: PackedVector2Array
	var debris_points: Array[Vector2] = []
	var debris_sizes: Array[float] = []
	var debris_velocities: Array[Vector2] = []
	var depth_intensity: float
	var divot_length: float
	var divot_width: float
	var surface_roughness: float
	
	func _init(pos: Vector2, dir: Vector2, surface: int, velocity_magnitude: float):
		position = pos
		direction = dir.normalized()
		surface_type = surface
		random_seed = randi()
		
		# Better size calculation - scales properly with velocity
		# Max velocity ~1500 -> shot_power = 1.0, Min velocity ~100 -> shot_power = 0.1
		shot_power = clamp(velocity_magnitude / 1500.0, 0.1, 1.0)
		depth_intensity = clamp(shot_power * 0.6, 0.1, 0.6)
		surface_roughness = clamp(shot_power * 0.4, 0.2, 0.6)
		
		generate_divot_shape()
	
	func generate_divot_shape():
		var rng = RandomNumberGenerator.new()
		rng.seed = random_seed
		
		# Much smaller base sizes for realistic divots
		var base_length = rng.randf_range(11.0, 16.0)  # Reduced from 8-12
		var power_multiplier = 1.0 + (shot_power * 2.0)  # 1.0 to 3.0 multiplier
		
		divot_length = base_length * power_multiplier
		divot_width = divot_length * rng.randf_range(0.15, 0.25)  # Much narrower (was 0.2-0.35)
		
		# Create elongated divot shape
		main_divot_points = PackedVector2Array()
		var num_points = rng.randi_range(6, 8)
		
		for i in range(num_points):
			var angle = (i / float(num_points)) * TAU
			var radius_variation = rng.randf_range(0.7, 1.2)
			var roughness_variation = 1.0 + (surface_roughness * rng.randf_range(-0.3, 0.3))
			var final_variation = radius_variation * roughness_variation
			
			var local_pos: Vector2
			var cos_angle = cos(angle)
			var sin_angle = sin(angle)
			
			# Create teardrop shape
			if cos_angle > 0.2:
				local_pos = Vector2(cos_angle * divot_length * final_variation * 0.9, sin_angle * divot_width * final_variation)
			elif cos_angle < -0.3:
				local_pos = Vector2(cos_angle * divot_length * final_variation * 0.4, sin_angle * divot_width * final_variation * 0.6)
			else:
				local_pos = Vector2(cos_angle * divot_length * final_variation * 0.7, sin_angle * divot_width * final_variation * 0.8)
			
			# Surface-specific irregularities
			match surface_type:
				1: local_pos *= rng.randf_range(0.9, 1.1)
				5: 
					var jaggedness = rng.randf_range(-1.0, 1.2)
					local_pos += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * jaggedness * 0.5
			
			main_divot_points.append(local_pos)
		
		# Generate debris - much fewer pieces
		var debris_count = int(clamp(shot_power * 6.0, 5, 10))  # Reduced from 2-8 to 1-4
		debris_points.clear()
		debris_sizes.clear()
		debris_velocities.clear()
		
		for i in range(debris_count):
			var debris_angle = direction.angle() + PI + rng.randf_range(-1.2, 1.2)
			var debris_distance = rng.randf_range(divot_length * 0.4, divot_length * 1.4)
			var debris_pos = Vector2(cos(debris_angle), sin(debris_angle)) * debris_distance
			debris_points.append(debris_pos)
			
			var size_factor = clamp(shot_power, 0.3, 1.0)
			debris_sizes.append(rng.randf_range(3.5, 5.5) * size_factor)
			
			var scatter_velocity = Vector2(cos(debris_angle), sin(debris_angle)) * rng.randf_range(15, 40)
			debris_velocities.append(scatter_velocity)

# ========== MAIN VARIABLES ==========
var divot_marks: Array[DivotMark] = []
var mark_fade_time: float = 48.0
var golf_ball: Node2D
var course_node: Node2D
var shot_particle_texture: Texture2D
var debug_divot_sizes: bool = false  # Toggle for size debugging

# ========== INITIALIZATION ==========
func _ready():
	course_node = get_tree().current_scene
	if course_node.has_method("get_course_node"):
		course_node = course_node.get_course_node()

	z_index = 5
	setup_particle_texture()

func clear_all_divots():
	print("efjij")
	divot_marks.clear()
	queue_redraw()

func setup(ball_node: Node2D):
	golf_ball = ball_node

func setup_particle_texture():
	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for x in range(4):
		for y in range(4):
			image.set_pixel(x, y, Color.WHITE)
	shot_particle_texture = ImageTexture.new()
	shot_particle_texture.set_image(image)

# ========== PUBLIC API ==========
func create_shot_divot(shot_position: Vector2, shot_direction: Vector2, surface_type: int, velocity_magnitude: float):
	if surface_type == 3 or surface_type == 2:  # WATER or ICE
		return
	
	var new_divot = DivotMark.new(shot_position, shot_direction, surface_type, velocity_magnitude)
	divot_marks.append(new_divot)
	
	# SIZE DEBUG OUTPUT
	if debug_divot_sizes:
		print("=== DIVOT SIZE DEBUG ===")
		print("Velocity: ", velocity_magnitude)
		print("Shot Power (vel/1500, clamped 0.1-1.0): ", new_divot.shot_power)
		print("Base Length Range: 4.0-8.0")
		print("Power Multiplier: 1.0 + (shot_power * 2.0) = ", 1.0 + (new_divot.shot_power * 2.0))
		print("Final Length: ", new_divot.divot_length)
		print("Final Width: ", new_divot.divot_width)
		print("Debris Count: ", int(clamp(new_divot.shot_power * 6.0, 1, 4)))
		print("Depth Intensity: ", new_divot.depth_intensity)
		print("Surface Roughness: ", new_divot.surface_roughness)
		print("Length = base_length * (1.0 + shot_power * 2.0)")
		print("Width = length * (0.15-0.25)")
		print("========================")
	
	# Only trigger particles if shot power is greater than 0.2
	if new_divot.shot_power > 0.2 and (surface_type == 5 or surface_type == 1):
		trigger_shot_particles(velocity_magnitude, shot_direction, shot_position, surface_type)
	
	queue_redraw()

func update_divots(delta: float):
	if divot_marks.is_empty():
		return
		
	for divot in divot_marks:
		divot.age += delta
		if divot.age < 0.5:
			var scatter_progress = divot.age / 0.5
			for i in range(divot.debris_points.size()):
				var velocity_factor = 1.0 - ease_out_cubic(scatter_progress)
				divot.debris_points[i] += divot.debris_velocities[i] * delta * velocity_factor
	
	var initial_count = divot_marks.size()
	for i in range(divot_marks.size() - 1, -1, -1):
		if divot_marks[i].age > mark_fade_time:
			divot_marks.remove_at(i)
	
	if divot_marks.size() != initial_count or divot_marks.size() > 0:
		queue_redraw()

func _draw():
	if divot_marks.is_empty():
		return
	
	for divot in divot_marks:
		var alpha = calculate_alpha(divot.age)
		var base_color = get_divot_base_color(divot.surface_type)
		var shadow_color = get_divot_shadow_color(divot.surface_type)
		var local_pos = to_local(divot.position)
		
		draw_divot_with_depth(divot, local_pos, base_color, shadow_color, alpha)
		draw_divot_debris(divot, local_pos, base_color, alpha)

# Enable/disable size debugging
func set_debug_divot_sizes(enabled: bool):
	debug_divot_sizes = enabled

# ========== PARTICLE EFFECTS ==========
func trigger_shot_particles(velocity_magnitude: float, shot_direction: Vector2, shot_position: Vector2, surface_type: int):
	var burst_particles = GPUParticles2D.new()
	course_node.add_child(burst_particles)
	burst_particles.global_position = shot_position
	burst_particles.z_index = 5
	
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.direction = Vector3(0, -1, 0)
	particle_mat.spread = 45.0
	particle_mat.initial_velocity_min = 150.0
	particle_mat.initial_velocity_max = 300.0
	particle_mat.gravity = Vector3(0, 800, 0)
	particle_mat.scale_min = 0.2
	particle_mat.scale_max = 0.8
	
	if surface_type == 1:
		particle_mat.color = Color(0.85, 0.75, 0.55, 1.0)
		particle_mat.color_ramp = create_sand_color_ramp()
	else:
		particle_mat.color = Color(0.4, 0.3, 0.2, 1.0)
		particle_mat.color_ramp = create_dirt_color_ramp()
	
	var power_factor = clamp(velocity_magnitude / 200.0, 0.4, 2.0)
	burst_particles.amount = int(15 * power_factor)
	particle_mat.initial_velocity_min = 100.0 * power_factor
	particle_mat.initial_velocity_max = 180.0 * power_factor
	
	var shot_angle = shot_direction.angle()
	var backwards_angle = shot_angle + PI
	var particle_direction = Vector3(cos(backwards_angle) * 0.7, sin(backwards_angle) * 0.7 - 0.6, 0)
	particle_mat.direction = particle_direction
	
	burst_particles.texture = shot_particle_texture
	burst_particles.process_material = particle_mat
	burst_particles.lifetime = 0.25
	burst_particles.one_shot = true
	burst_particles.emitting = true
	
	var cleanup_timer = get_tree().create_timer(0.4)
	cleanup_timer.timeout.connect(func(): 
		if is_instance_valid(burst_particles):
			burst_particles.queue_free()
	)
	
func create_sand_color_ramp() -> Gradient:
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.9, 0.8, 0.6, 1.0))
	gradient.add_point(0.5, Color(0.8, 0.7, 0.5, 0.8))
	gradient.add_point(1.0, Color(0.7, 0.6, 0.4, 0.3))
	return gradient

func create_dirt_color_ramp() -> Gradient:
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.5, 0.4, 0.3, 1.0))
	gradient.add_point(0.5, Color(0.4, 0.3, 0.2, 0.7))
	gradient.add_point(1.0, Color(0.3, 0.2, 0.1, 0.2))
	return gradient

# ========== DRAWING FUNCTIONS ==========
func draw_divot_with_depth(divot: DivotMark, local_pos: Vector2, base_color: Color, shadow_color: Color, alpha: float):
	var transformed_points = PackedVector2Array()
	for point in divot.main_divot_points:
		var rotated_point = point.rotated(divot.direction.angle())
		transformed_points.append(local_pos + rotated_point)
	
	# Draw shadows
	for layer in range(2):
		var layer_offset = Vector2(0.5, 0.5) * (layer + 1) * divot.depth_intensity
		var shadow_points = PackedVector2Array()
		for point in transformed_points:
			shadow_points.append(point + layer_offset)
		
		var layer_shadow_color = shadow_color
		layer_shadow_color.a = alpha * 0.4 * divot.depth_intensity * (1.0 - layer * 0.3)
		
		if shadow_points.size() >= 3:
			draw_colored_polygon(shadow_points, layer_shadow_color)
	
	# Draw main divot
	var final_base_color = base_color
	final_base_color.a = alpha * get_surface_alpha_multiplier(divot.surface_type)
	
	if transformed_points.size() >= 3:
		draw_colored_polygon(transformed_points, final_base_color)
	
	# Draw highlight edge
	if transformed_points.size() >= 3:
		var highlight_color = final_base_color.lightened(0.3)
		highlight_color.a = alpha * 0.5
		
		for i in range(transformed_points.size()):
			var start_point = transformed_points[i]
			var end_point = transformed_points[(i + 1) % transformed_points.size()]
			draw_line(start_point, end_point, highlight_color, 1.0, true)

func draw_divot_debris(divot: DivotMark, local_pos: Vector2, base_color: Color, alpha: float):
	for i in range(divot.debris_points.size()):
		var debris_pos = local_pos + divot.debris_points[i]
		var debris_size = divot.debris_sizes[i]
		
		var debris_alpha_factor = 1.0
		if divot.age > 2.0:
			debris_alpha_factor = clamp(1.0 - (divot.age - 2.0) / 3.0, 0.2, 1.0)
		
		var debris_color = base_color.darkened(0.3)
		debris_color.a = alpha * 0.8 * debris_alpha_factor * get_surface_alpha_multiplier(divot.surface_type)
		
		var debris_points = PackedVector2Array()
		for j in range(4):
			var angle = (j / 4.0) * TAU
			var radius = debris_size * randf_range(0.8, 1.1)
			var point = debris_pos + Vector2(cos(angle), sin(angle)) * radius
			debris_points.append(point)
		
		if debris_points.size() >= 3:
			draw_colored_polygon(debris_points, debris_color)

# ========== HELPER FUNCTIONS ==========
func calculate_alpha(age: float) -> float:
	if age <= 1.0:
		return 1.0
	elif age <= 3.0:
		var fade_progress = (age - 1.0) / 2.0
		return 1.0 - (fade_progress * 0.4)
	else:
		var slow_progress = (age - 3.0) / (mark_fade_time - 3.0)
		return 0.6 * (1.0 - slow_progress)

func get_divot_base_color(surface_type: int) -> Color:
	match surface_type:
		1: return Color(0.6, 0.4, 0.2)  # SAND
		2: return Color(0.5, 0.7, 0.9)  # ICE
		5: return Color(0.501961, 0.501961, 0.184314)  # ROUGH_GRASS
		0: return Color(0.45, 0.35, 0.25)  # GRASS
		_: return Color(0.6, 0.6, 0.6)

func get_divot_shadow_color(surface_type: int) -> Color:
	match surface_type:
		1: return Color(0.3, 0.2, 0.1)  # SAND
		2: return Color(0.2, 0.4, 0.6)  # ICE
		5: return Color(0.2, 0.15, 0.1)  # ROUGH_GRASS
		0: return Color(0.22, 0.17, 0.12)  # GRASS
		_: return Color(0.3, 0.3, 0.3)

func get_surface_alpha_multiplier(surface_type: int) -> float:
	match surface_type:
		1: return 0.8  # SAND
		5: return 0.9  # ROUGH_GRASS
		_: return 0.7

func ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)
