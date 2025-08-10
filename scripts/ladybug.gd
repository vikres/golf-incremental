extends CharacterBody2D
@export var speed: float = 50.0
@export var rotation_speed: float = 8.0
@export var detection_range: float = 150.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var target_collectible: Node2D = null
var last_position: Vector2
var stuck_timer: float = 0.0
var was_idle: bool = false  # Track if we were idle before getting stuck
# New bounce state system
enum BounceState { NONE, SPINNING, RUNNING }
var bounce_state: BounceState = BounceState.NONE
var bounce_timer: float = 0.0
var bounce_direction: Vector2
var spin_speed: float = 1080.0  # degrees per second (2 full rotations per second)
var run_speed_multiplier: float = 2.5

func _ready():
	play_spawn_animation()
	# Delay targeting to avoid invalid collectibles at spawn
	await get_tree().create_timer(0.2).timeout
	find_nearest_collectible()

func play_spawn_animation():
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _physics_process(delta):
	# Handle bounce states first
	if bounce_state != BounceState.NONE:
		handle_bounce_behavior(delta)
		return
	
	# Stuck detection (only when not bouncing)
	if global_position.distance_to(last_position) < 0.3:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	last_position = global_position
	
	# Find new target if needed
	if not target_collectible or not is_instance_valid(target_collectible) or target_collectible.collected:
		was_idle = true  # Mark that we were idle
		find_nearest_collectible()
	
	# Move towards target or handle stuck situation
	if target_collectible:
		move_towards_target(delta)
	else:
		stop_moving()

func handle_bounce_behavior(delta):
	bounce_timer -= delta
	
	match bounce_state:
		BounceState.SPINNING:
			# Spin in place super fast
			rotation += deg_to_rad(spin_speed) * delta
			velocity = Vector2.ZERO
			animated_sprite.play("default")
			
			# Switch to running after 0.5s
			if bounce_timer <= 0.0:
				bounce_state = BounceState.RUNNING
				bounce_timer = 0.3
				if was_idle:
					# Coming back from idle - go toward target
					bounce_direction = global_position.direction_to(target_collectible.global_position)
				else:
					# Truly stuck - try random direction
					bounce_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		BounceState.RUNNING:
			# Run in random direction at higher speed
			velocity = bounce_direction * speed * run_speed_multiplier
			# Face the direction we're running
			rotation = lerp_angle(rotation, bounce_direction.angle(), rotation_speed * delta)
			animated_sprite.play("default")
			
			# End bounce behavior after 0.5s
			if bounce_timer <= 0.0:
				bounce_state = BounceState.NONE
				stuck_timer = 0.0
				was_idle = false  # Clear idle flag
	
	move_and_slide()

func find_nearest_collectible():
	var collectibles = get_tree().get_nodes_in_group("collectibles")
	target_collectible = null
	var nearest_distance = INF
	
	for collectible in collectibles:
		if not is_instance_valid(collectible) or collectible.collected:
			continue
			
		var distance = global_position.distance_to(collectible.global_position)
		
		if distance < detection_range and distance < nearest_distance:
			nearest_distance = distance
			target_collectible = collectible

func move_towards_target(delta):
	animated_sprite.play("default")
	var direction = global_position.direction_to(target_collectible.global_position)
	var distance = global_position.distance_to(target_collectible.global_position)
	direction = direction.rotated(randf_range(-0.3, 0.3))  # ±17 degrees wobble
	# Stop if reached target
	if distance < 8.0:
		target_collectible = null
		return
	
	# Handle stuck situation - start spinning phase
	if stuck_timer > 1.0:
		bounce_state = BounceState.SPINNING
		bounce_timer = 0.5
		stuck_timer = 0.0
		return
	
	# Normal movement - face the direction we're moving
	rotation = lerp_angle(rotation, direction.angle(), rotation_speed * delta)
	velocity = direction * speed
	move_and_slide()

func stop_moving():
	velocity = Vector2.ZERO
	animated_sprite.play("idle")
