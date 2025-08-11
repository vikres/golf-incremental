extends Control

# UI refs
@onready var title_l  : Label = $titleL
@onready var title_r  : Label = $titleR
@onready var stat1    : Label = $stat1
@onready var answer1  : Label = $answer1
@onready var stat2    : Label = $stat2
@onready var answer2  : Label = $answer2
@onready var stat3    : Label = $stat3
@onready var answer3  : Label = $answer3
@onready var stat4    : Label = $stat4
@onready var answer4  : Label = $answer4

signal board_finished

func _ready() -> void:
	# Don't set anchors here - let the parent CourseManager handle positioning
	visible = false
	# Ensure we're above everything
	z_as_relative = false
	z_index = 100

func show_board(shots: int, par: int) -> void:
	# Set texts
	title_l.text = "HOLE COMPLETE"
	title_r.text = "PAR " + str(par)
	stat1.text = "Total Shots:"
	answer1.text = str(shots) + " shots"
	stat2.text = "Base Reward:"
	answer2.text = "$150"
	stat3.text = "Par Bonus:"
	answer3.text = "$50"
	stat4.text = "Total Earned:"
	answer4.text = "$200"
	
	# Show and fade in
	visible = true
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	# Wait
	await get_tree().create_timer(3.0).timeout
	
	# Fade out
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	visible = false
	modulate.a = 1.0
	board_finished.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed:
		# Skip to end
		get_tree().create_tween().kill()
		modulate.a = 1.0
		board_finished.emit()
