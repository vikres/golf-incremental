extends Area2D

@export var collection_patch_scene: PackedScene = preload("res://scenes/collection_patch.tscn")
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var collected: bool = false
var pulse_timer: float = 0.0
var next_pulse_time: float
var original_position: Vector2

signal ball_collected()

func _ready():
	body_entered.connect(_on_body_entered)
	add_to_group("collectibles")
	next_pulse_time = randf_range(2.0, 8.0)
	modulate.a = 0.0
	scale = Vector2.ZERO
	await get_tree().process_frame
	original_position = global_position
	play_spawn_animation()

func play_spawn_animation():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _process(delta):
	if collected:
		return
		
	pulse_timer += delta
	if pulse_timer >= next_pulse_time:
		create_combined_effect()
		pulse_timer = 0.0
		next_pulse_time = randf_range(4.0, 10.0)

func create_combined_effect():
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Glow + wiggle combo
	tween.tween_property(sprite, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.6)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.8).set_delay(0.6)
	
	var wiggle = deg_to_rad(15)
	tween.tween_property(sprite, "rotation", wiggle, 0.15)
	tween.tween_property(sprite, "rotation", -wiggle, 0.15).set_delay(0.15)
	tween.tween_property(sprite, "rotation", 0.0, 0.15).set_delay(0.30)

func _on_body_entered(body):
	if not collected and body is CharacterBody2D and (body.name == "GolfBall" or body.is_in_group("ladybugs")):
		collect()

func collect():
	if collected:
		return
	
	collected = true
	GameManager.add_money(GameManager.collectible_gain)
	call_deferred("spawn_collection_patch")
	ball_collected.emit()
	call_deferred("play_collection_effect")

func spawn_collection_patch():
	var patch = collection_patch_scene.instantiate()
	var target = CourseManager.loaded_level_scene
	
	target.add_child(patch)
	patch.global_position = global_position
	patch.add_to_group("collection_patches")

func play_collection_effect():
	collision.set_deferred("disabled", true)
	remove_from_group("collectibles")
	
	var start_pos = global_position
	var fling_height = -60.0
	var fling_sideways = randf_range(-30.0, 30.0)
	var spin_amount = randf_range(3.0, 6.0) * PI
	var start_rotation = sprite.rotation
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_method(func(t): global_position = start_pos + Vector2(fling_sideways * t, fling_height * sin(t * PI)), 0.0, 1.0, 1.2)
	tween.tween_property(sprite, "rotation", start_rotation + spin_amount, 1.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8).set_delay(0.4)
	
	await tween.finished
	queue_free()
