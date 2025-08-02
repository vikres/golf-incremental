extends Node2D
@onready var collision_body = $StaticBody2D
@onready var rock_sprites = []
@onready var shadow = $shadow
@onready var rubble = $rubble  # Assuming you have a rubble sprite for broken state

var active_rock_sprite: Sprite2D
var regrow_timer: SceneTreeTimer = null
var is_animating = false
var hole: Area2D

func _ready():
	hole = %Hole
	_collect_rock_sprites()
	_setup_random_rock()

func _collect_rock_sprites():
	var i = 1
	while true:
		var rock = get_node_or_null("rock" + str(i))
		if rock == null:
			break
		rock_sprites.append(rock)
		i += 1
		
func _setup_random_rock():
	# Hide all rock sprites first
	for rock in rock_sprites:
		rock.visible = false
	
	# Pick and show one random rock
	var random_index = randi() % rock_sprites.size()
	active_rock_sprite = rock_sprites[random_index]
	active_rock_sprite.visible = true

func _on_hole_completed(_money_earned):
	regrow_timer = null
	_regrow_rock()
	
func hide_temporarily():
	if is_animating:
		return
	is_animating = true
	
	# Disable collision immediately
	collision_body.set_collision_layer_value(1, false)
	
	# Create animation sequence
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Randomize animation parameters
	var shake_intensity = randf_range(0.4, 0.8)  # Rocks shake more than trees
	var crack_scale = randf_range(0.6, 0.8)
	
	# Step 1: Intense shake (rock cracking)
	tween.tween_method(_shake_rock, 0.0, shake_intensity, 0.2)
	tween.tween_callback(_stop_shake).set_delay(0.2)
	
	# Step 2: Rock "cracks" - slight scale down and subtle rotation
	tween.tween_property(active_rock_sprite, "scale", Vector2(crack_scale, crack_scale), 0.25).set_delay(0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_property(active_rock_sprite, "rotation_degrees", randf_range(-5, 5), 0.25).set_delay(0.15)
	
	# Step 3: Shadow reduces as rock breaks
	tween.tween_property(shadow, "modulate:a", 0, 0.2).set_delay(0.2)
	
	# Step 4: Rock fades out
	tween.tween_property(active_rock_sprite, "modulate:a", 0.0, 0.15).set_delay(0.3)
	
	# Step 5: Show rubble with pop effect
	tween.tween_callback(_show_rubble).set_delay(0.4)
	tween.tween_property(rubble, "scale", Vector2(1.3, 1.3), 0.08).set_delay(0.4)
	tween.tween_property(rubble, "scale", Vector2(1.0, 1.0), 0.12).set_delay(0.48).set_trans(Tween.TRANS_BACK)
	
	# Create rock destruction particles
	_create_rock_particles()
	
	# Wait for regrowth (rocks take longer to "regrow" than trees)
	regrow_timer = get_tree().create_timer(20.0)
	await regrow_timer.timeout
	if regrow_timer and regrow_timer.time_left == 0:
		regrow_timer = null
		_regrow_rock()

func _shake_rock(intensity: float):
	var shake_offset = Vector2(
		randf_range(-intensity, intensity) * 8,
		randf_range(-intensity * 0.3, intensity * 0.3) * 8  # Rocks shake less vertically
	)
	active_rock_sprite.position = shake_offset
	shadow.position = shake_offset * 0.5

func _stop_shake():
	active_rock_sprite.position = Vector2.ZERO
	shadow.position = Vector2.ZERO

func _show_rubble():
	rubble.visible = true
	rubble.modulate.a = 1.0
	rubble.scale = Vector2(0.9, 0.9)

func _create_rock_particles():
	# Create rock debris particles
	for i in range(8):  # More particles for rock breaking
		var particle = Sprite2D.new()
		add_child(particle)
		
		# Create small rock debris texture
		var texture = ImageTexture.new()
		var image = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		var rock_colors = [Color.GRAY, Color.DIM_GRAY, Color.LIGHT_GRAY, Color.WEB_GRAY]
		image.fill(rock_colors.pick_random())
		texture.set_image(image)
		particle.texture = texture
		
		# Random starting position around rock
		particle.position = Vector2(
			randf_range(-15, 15),
			randf_range(-20, 5)
		)
		
		# Animate particle
		var particle_tween = create_tween()
		particle_tween.set_parallel(true)
		
		# Rock debris falls more than flies
		var end_pos = particle.position + Vector2(
			randf_range(-25, 25),
			randf_range(30, 70)  # More downward motion
		)
		
		particle_tween.tween_property(particle, "position", end_pos, randf_range(0.6, 1.0))
		particle_tween.tween_property(particle, "rotation", randf_range(-PI*2, PI*2), randf_range(0.6, 1.0))
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.4).set_delay(0.4)
		particle_tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.8)
		
		# Clean up particle
		particle_tween.tween_callback(particle.queue_free).set_delay(1.0)

func _regrow_rock():
	var regrow_tween = create_tween()
	regrow_tween.set_parallel(true)
	
	# Hide rubble
	regrow_tween.tween_property(rubble, "scale", Vector2(0.7, 0.7), 0.1)
	regrow_tween.tween_property(rubble, "modulate:a", 0.0, 0.2)
	regrow_tween.tween_callback(func(): rubble.visible = false).set_delay(0.2)
	
	# Pick a new random rock variation for regrowth
	_setup_random_rock()
	
	# Reset active rock properties
	active_rock_sprite.scale = Vector2(0.3, 0.1)  # Start very small and flat
	active_rock_sprite.rotation_degrees = 0
	active_rock_sprite.modulate.a = 1.0
	active_rock_sprite.visible = true
	
	shadow.modulate.a = 0.0
	shadow.visible = true
	
	# Rock "grows" back (maybe it's a magical golf course!)
	regrow_tween.tween_property(active_rock_sprite, "scale", Vector2(1.0, 1.0), 0.5).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	regrow_tween.tween_property(shadow, "modulate:a", 1.0, 0.4).set_delay(0.4)
	
	# Re-enable collision and reset state
	regrow_tween.tween_callback(_reset_rock_state).set_delay(0.8)

func _reset_rock_state():
	collision_body.set_collision_layer_value(1, true)
	is_animating = false
