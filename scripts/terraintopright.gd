# BallDisplay.gd - Put this script directly on Control2
extends Control

@export var ball_texture: Texture2D
var ball_containers: Array[TextureRect] = []
var current_balls_left: int
var current_par: int = 3

# References to UI elements
var curr_level_label: Label
var curr_par_label: Label

signal balls_depleted

func _ready():
	# Get references to child labels
	curr_level_label = get_node("TextureRect/currLevel") # Adjust path if needed
	curr_par_label = get_node("TextureRect/currPar")     # Adjust path if needed
	
	setup_ball_display()

func setup_ball_display():
	# Find existing HBoxContainer child or any container for balls
	var hbox: HBoxContainer
	for child in get_children():
		if child is HBoxContainer:
			hbox = child
			break
	
	if not hbox:
		print("Error: No HBoxContainer found in Control2 children")
		return
	
	# Create TextureRect for each ball (up to max par we might see)
	var max_possible_par = 10  # Based on your level 1 par
	for i in max_possible_par:
		var ball_rect = TextureRect.new()
		if ball_texture:
			ball_rect.texture = ball_texture
		ball_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ball_rect.custom_minimum_size = Vector2(32, 32)
		ball_rect.visible = false
		hbox.add_child(ball_rect)
		ball_containers.append(ball_rect)

func set_level_info(level: int, par: int):
	current_par = par
	current_balls_left = par
	
	# Update labels
	if curr_level_label:
		curr_level_label.text = "HOLE " + str(level)
	if curr_par_label:
		curr_par_label.text = "PAR " + str(par)
	
	update_display()

func update_display():
	if ball_containers.is_empty():
		return
	
	# Show balls equal to current par, hide the rest
	for i in ball_containers.size():
		if i < current_par:
			ball_containers[i].visible = true
			# Show filled if ball is available, grayed if used
			if i < current_balls_left:
				ball_containers[i].modulate = Color.WHITE
			else:
				ball_containers[i].modulate = Color(0.3, 0.3, 0.3, 0.7)
		else:
			ball_containers[i].visible = false

func use_ball():
	if current_balls_left > 0:
		current_balls_left -= 1
		update_display()
		
		if current_balls_left <= 0:
			pass
			#balls_depleted.emit()

func get_balls_left() -> int:
	return current_balls_left
