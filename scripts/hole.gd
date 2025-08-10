# Hole.gd - Fixed version
extends Area2D
@export var flag_hide_distance: float = 50.0
@onready var flag: Node2D = $Flag
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var is_completed: bool = false
var armed: bool = false  # NEW

func _ready():
	body_entered.connect(_on_body_entered)
	# NEW: start disarmed so it can't trigger during level load
	armed = false
	collision_shape.disabled = true

func _process(_delta):
	if flag and flag.visible and not is_completed:
		var ball = get_tree().get_first_node_in_group("ball")
		if ball:
			var distance = global_position.distance_to(ball.global_position)
			if distance <= flag_hide_distance:
				hide_flag()

func _on_body_entered(body):
	if is_completed: return
	if not armed: return  # NEW: ignore until CourseManager arms us
	if body.is_in_group("ball"):
		complete_hole(body)

func hide_flag():
	if flag and flag.visible:
		var tween = create_tween()
		tween.tween_property(flag, "modulate:a", 0.0, 0.3)
		flag.visible = false

func complete_hole(ball):
	is_completed = true
	# Use call_deferred to avoid physics query flushing issues
	collision_shape.call_deferred("set_disabled", true)
	armed= false
	# Stop ball
	ball.set_physics_process(false)
	ball.set_process_input(false)
	ball.ball_velocity = Vector2.ZERO
	ball.velocity = Vector2.ZERO
	ball.is_dragging = false
	ball.hide_ui()
	
	# Tell course manager
	CourseManager.handle_hole_completion()

func reset_hole():
	if flag:
		flag.visible = true
		flag.modulate.a = 1.0
	is_completed = false
	armed = false
	collision_shape.call_deferred("set_disabled", true)  # KEEP DISABLED HERE
func arm():
	armed = true
	collision_shape.call_deferred("set_disabled", false)
