extends Node2D
class_name BallVisual

# References
@onready var ball_sprite: Sprite2D = $BallSprite
@onready var shadow_sprite: Sprite2D = $ShadowSprite

# Visual properties
@export var ball_radius: float = 10.0
@export var shadow_offset: Vector2 = Vector2(2, 3)
@export var shadow_scale_base: float = 0.8

# Rotation tracking
var rotation_x: float = 0.0
var rotation_y: float = 0.0
var last_position: Vector2 = Vector2.ZERO

# Debug mode
@export var debug_mode: bool = false

# Ball skins
enum BallSkin {
	CLASSIC_WHITE,
	BLUE_STEEL,
	GOLDEN,
	RAINBOW,
	CHROME,
	WOOD_GRAIN
}

var current_skin: BallSkin = BallSkin.CLASSIC_WHITE

# Shader material
var shader_material: ShaderMaterial

func _ready():
	setup_shader()
	create_shadow_texture()
	last_position = global_position
	print("BallVisual (Shader) ready - radius: ", ball_radius)

func setup_shader():
	# Create shader material
	shader_material = ShaderMaterial.new()
	
	# Load the shader (you'll need to save the shader as ball_3d.gdshader)
	var shader = load("res://scripts/ball_3d.gdshader") # Adjust path as needed
	shader_material.shader = shader
	
	# Set initial parameters
	shader_material.set_shader_parameter("rotation_x", 0.0)
	shader_material.set_shader_parameter("rotation_y", 0.0)
	shader_material.set_shader_parameter("ball_skin", current_skin)
	shader_material.set_shader_parameter("ball_radius", ball_radius)
	shader_material.set_shader_parameter("debug_mode", debug_mode)
	
	# Create a white texture for the sprite (shader will handle the visuals)
	var image = Image.create(int(ball_radius * 2), int(ball_radius * 2), false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	# Apply shader material to sprite
	ball_sprite.texture = texture
	ball_sprite.material = shader_material
	ball_sprite.position = Vector2.ZERO

func _process(_delta):
	update_ball_rotation()
	update_shadow()

func update_ball_rotation():
	var parent_body = get_parent() as CharacterBody2D
	if not parent_body:
		return
	
	var velocity = parent_body.ball_velocity
	var speed = velocity.length()
	
	# Only rotate if moving fast enough
	if speed < 5.0:
		return
	
	var current_position = global_position
	var movement_delta = current_position - last_position
	var distance_moved = movement_delta.length()
	
	if distance_moved < 0.1:
		return
	
	# Calculate rotation based on movement
	var movement_direction = movement_delta.normalized()
	var rotation_amount = distance_moved / ball_radius
	
	# Update rotations
	rotation_x += rotation_amount * movement_direction.y
	rotation_y += rotation_amount * -movement_direction.x
	
	# Update shader parameters - this is all we need to do!
	shader_material.set_shader_parameter("rotation_x", rotation_x)
	shader_material.set_shader_parameter("rotation_y", rotation_y)
	
	last_position = current_position
	
	# Debug output (much less frequent)
	if debug_mode and randf() < 0.01:  # Only 1% of frames
		print("Shader rotation - X: %.2f, Y: %.2f" % [rotation_x, rotation_y])

func update_shadow():
	shadow_sprite.position = shadow_offset
	
	var parent_body = get_parent() as CharacterBody2D
	if parent_body:
		var speed = parent_body.ball_velocity.length()
		var height_factor = clamp(speed / 200.0, 0.0, 0.3)
		shadow_sprite.modulate.a = 0.6 - height_factor
		shadow_sprite.scale = Vector2.ONE * (shadow_scale_base - height_factor * 0.1)

func create_shadow_texture():
	var shadow_size = ball_radius * 2.2
	var image = Image.create(int(shadow_size), int(shadow_size * 0.6), false, Image.FORMAT_RGBA8)
	var center = Vector2(shadow_size * 0.5, shadow_size * 0.3)
	
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			var max_distance = shadow_size * 0.4
			
			if distance <= max_distance:
				var normalized_dist = distance / max_distance
				var alpha = (1.0 - normalized_dist) * 0.4
				var shadow_color = Color(0, 0, 0, alpha)
				image.set_pixel(x, y, shadow_color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	shadow_sprite.texture = texture

# Public functions
func set_ball_skin(new_skin: BallSkin):
	current_skin = new_skin
	if shader_material:
		shader_material.set_shader_parameter("ball_skin", current_skin)

#func cycle_skin():
	#var skin_count = BallSkin.size()
	#current_skin = (current_skin + 1) % skin_count
	#set_ball_skin(current_skin)
	#print("Switched to skin: ", BallSkin.keys()[current_skin])

func set_debug_mode(enabled: bool):
	debug_mode = enabled
	debug_mode = false
	if shader_material:
		shader_material.set_shader_parameter("debug_mode", debug_mode)

func test_callaway_logo():
	print("Testing Callaway logo visibility...")
	rotation_x = 0.0
	rotation_y = 0.0
	shader_material.set_shader_parameter("rotation_x", rotation_x)
	shader_material.set_shader_parameter("rotation_y", rotation_y)
	print("Logo should be visible at rotation (0,0)")

func reset_rotation():
	rotation_x = 0.0
	rotation_y = 0.0
	shader_material.set_shader_parameter("rotation_x", rotation_x)
	shader_material.set_shader_parameter("rotation_y", rotation_y)
	print("Rotation reset - logo should be visible")

# Convenience function to rotate ball manually (for testing)
func manual_rotate(x_delta: float, y_delta: float):
	rotation_x += x_delta
	rotation_y += y_delta
	shader_material.set_shader_parameter("rotation_x", rotation_x)
	shader_material.set_shader_parameter("rotation_y", rotation_y)
