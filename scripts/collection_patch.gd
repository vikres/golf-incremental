extends Node2D

# Collection patch that appears where a collectible ball was collected
# Serves as a visual indicator and prevents new collectibles from spawning too close

@export var patch_lifetime: float = 30.0  # How long the patch stays (0 = permanent)
@export var fade_duration: float = 2.0    # Time to fade out before removal

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D  # Optional area for interactions

# Patch properties
var creation_time: float
var is_fading: bool = false

func _ready():
	# Wait for GameManager to set our position first
	await get_tree().process_frame
	
	creation_time = Time.get_unix_time_from_system()
	
	# Add to collection patches group for spawn avoidance
	add_to_group("collection_patches")
	
	# Connect area signal for step effect
	if area and area.has_signal("body_entered"):
		area.body_entered.connect(_on_area_2d_body_entered)
	
	# Start with slight transparency to show it's a "mark"
	modulate.a = 0.7
	
	# Optional: Scale animation when spawning
	play_spawn_animation()
	
	# Set up lifetime management
	if patch_lifetime > 0:
		setup_lifetime_management()
	
func play_spawn_animation():
	# Start small and grow to normal size
	scale = Vector2.ZERO
	var spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	spawn_tween.tween_property(self, "scale", Vector2.ONE, 0.5)
	spawn_tween.tween_property(self, "modulate:a", 0.7, 0.5)

func setup_lifetime_management():
	# Wait for the lifetime duration, then start fading
	await get_tree().create_timer(patch_lifetime - fade_duration).timeout
	start_fade_out()

func start_fade_out():
	if is_fading:
		return
	
	is_fading = true
	
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Fade out and shrink
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	fade_tween.tween_property(self, "scale", Vector2(0.5, 0.5), fade_duration)
	
	await fade_tween.finished
	queue_free()

# Add interaction when golf ball rolls over
func _on_area_2d_body_entered(body):
	if body.name == "GolfBall":
		# Could add a small visual effect or sound
		play_step_effect()

func play_step_effect():
	# Small "step" animation when ball rolls over
	if is_fading:
		return  # Don't play effect if already fading
		
	var step_tween = create_tween()
	step_tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.15)
	step_tween.tween_property(self, "scale", Vector2.ONE, 0.15)

# Public function to remove patch immediately if needed
func remove_patch():
	if not is_fading:
		start_fade_out()

# Function to check if patch is old enough to allow new spawns nearby
func is_mature() -> bool:
	var current_time = Time.get_unix_time_from_system()
	return (current_time - creation_time) > 5.0  # Mature after 5 seconds
