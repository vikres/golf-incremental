extends Node2D
@onready var collision_body = $StaticBody2D
@onready var sprite1 = $tree
@onready var sprite2 = $shadow
@onready var sprite3 = $stump

var regrow_timer: SceneTreeTimer = null  # Store timer reference
var is_animating = false
var hole: Area2D
func _ready():
	hole = %Hole
		
func _on_hole_completed(_money_earned):
	regrow_timer = null  # Store timer reference
	_regrow_tree()
	
func hide_temporarily():
	if is_animating:
		return  # Prevent multiple simultaneous animations
	is_animating = true
	
	# Disable collision immediately
	collision_body.set_collision_layer_value(1, false)
	
	# Create animation sequence
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple animations simultaneously
	
	# Randomize animation parameters for variety
	var shake_intensity = randf_range(0.3, 0.6)
	var rotation_direction = 1 if randf() > 0.5 else -1
	var fall_rotation = randf_range(15, 25) * rotation_direction
	
	# Step 1: Quick shake animation (impact feel)
	tween.tween_method(_shake_tree, 0.0, shake_intensity, 0.15)
	tween.tween_callback(_stop_shake).set_delay(0.15)
	
	# Step 2: Tree "death" - scale down and rotate slightly
	tween.tween_property(sprite1, "scale", Vector2(0.8, 0.6), 0.3).set_delay(0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite1, "rotation_degrees", fall_rotation, 0.3).set_delay(0.1).set_trans(Tween.TRANS_BACK)
	
	# Step 3: Shadow fades as tree "falls"
	tween.tween_property(sprite2, "modulate:a", 0.3, 0.25).set_delay(0.15)
	
	# Step 4: Tree fades out
	tween.tween_property(sprite1, "modulate:a", 0.0, 0.2).set_delay(0.25)
	
	# Step 5: Show stump with a little pop-in effect
	tween.tween_callback(_show_stump).set_delay(0.4)
	tween.tween_property(sprite3, "scale", Vector2(1.2, 1.2), 0.1).set_delay(0.4)
	tween.tween_property(sprite3, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.5).set_trans(Tween.TRANS_BACK)
	
	# Create particle effect (leaves/debris)
	_create_destruction_particles()
	
	# Wait for regrowth
	regrow_timer = get_tree().create_timer(15.0)
	await regrow_timer.timeout
	print(regrow_timer)
	if regrow_timer:
		if regrow_timer.time_left == 0:
			regrow_timer = null
			_regrow_tree()

func _shake_tree(intensity: float):
	var shake_offset = Vector2(
		randf_range(-intensity, intensity) * 10,
		randf_range(-intensity * 0.5, intensity * 0.5) * 10
	)
	sprite1.position = shake_offset
	sprite2.position = shake_offset * 0.7  # Shadow moves less

func _stop_shake():
	sprite1.position = Vector2.ZERO
	sprite2.position = Vector2.ZERO

func _show_stump():
	sprite3.visible = true
	sprite3.modulate.a = 1.0
	sprite3.scale = Vector2(0.8, 0.8)  # Start small for pop effect

func _create_destruction_particles():
	# Create simple particle effect using multiple small sprites
	for i in range(6):
		var particle = Sprite2D.new()
		add_child(particle)
		
		# You can replace this with a small leaf/debris texture
		# For now, creating a simple colored rectangle
		var texture = ImageTexture.new()
		var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		var colors = [Color.BROWN, Color.DARK_GREEN, Color.GREEN, Color.YELLOW]
		image.fill(colors.pick_random())
		texture.set_image(image)
		particle.texture = texture
		
		# Random starting position around tree
		particle.position = Vector2(
			randf_range(-20, 20),
			randf_range(-30, 10)
		)
		
		# Animate particle
		var particle_tween = create_tween()
		particle_tween.set_parallel(true)
		
		# Random flight path
		var end_pos = particle.position + Vector2(
			randf_range(-40, 40),
			randf_range(20, 60)
		)
		
		particle_tween.tween_property(particle, "position", end_pos, randf_range(0.5, 0.8))
		particle_tween.tween_property(particle, "rotation", randf_range(-PI, PI), randf_range(0.5, 0.8))
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.3).set_delay(0.3)
		particle_tween.tween_property(particle, "scale", Vector2(0.5, 0.5), 0.6)
		
		# Clean up particle
		particle_tween.tween_callback(particle.queue_free).set_delay(0.8)

func _regrow_tree():
	var regrow_tween = create_tween()
	regrow_tween.set_parallel(true)
	
	# Hide stump with little shrink
	regrow_tween.tween_property(sprite3, "scale", Vector2(0.8, 0.8), 0.1)
	regrow_tween.tween_property(sprite3, "modulate:a", 0.0, 0.15)
	regrow_tween.tween_callback(func(): sprite3.visible = false).set_delay(0.15)
	
	# Reset tree properties
	sprite1.scale = Vector2(0.5, 0.1)  # Start small and flat
	sprite1.rotation_degrees = 0
	sprite1.modulate.a = 1.0
	sprite1.visible = true
	
	sprite2.modulate.a = 0.0
	sprite2.visible = true
	
	# Tree grows back
	regrow_tween.tween_property(sprite1, "scale", Vector2(1.0, 1.0), 0.4).set_delay(0.2).set_trans(Tween.TRANS_BACK)
	regrow_tween.tween_property(sprite2, "modulate:a", 1.0, 0.3).set_delay(0.3)
	
	# Re-enable collision and reset state
	regrow_tween.tween_callback(_reset_tree_state).set_delay(0.6)

func _reset_tree_state():
	collision_body.set_collision_layer_value(1, true)
	is_animating = false
