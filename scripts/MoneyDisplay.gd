extends Control
class_name MoneyDisplay

@onready var digit_container = $DigitContainer
@export var digit_template: Control

var current_money: int = 0
var active_digit_signs = []

const SIGN_WIDTH = 58
const SIGN_HEIGHT = 117
const SIGN_SCALE = 0.9
const SWING_AMPLITUDE = 2.0

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	if not digit_template:
		push_error("MoneyDisplay: digit_template not assigned!")
		return
	
	digit_template.visible = false
	await get_tree().process_frame
	
	GameManager.money_changed.connect(_on_money_changed)
	current_money = GameManager.player.money
	var new_string = "$" + str(current_money)
	create_initial_display(new_string)

func _on_money_changed(_new_amount):
	var actual_money = GameManager.player.money
	var old_string = "$" + str(current_money) if current_money > 0 else ""
	current_money = actual_money
	var new_string = "$" + str(current_money)
	
	#print("Money changed: old='", old_string, "' new='", new_string, "' actual=", actual_money)
	
	_cancel_all_animations()
	
	if active_digit_signs.is_empty():
		create_initial_display(new_string)
	else:
		update_display(old_string, new_string)

func create_initial_display(money_string: String):
	for digit_char in money_string:
		var digit_sign = create_digit_sign(digit_char)
		digit_container.add_child(digit_sign)
		active_digit_signs.append(digit_sign)

func create_digit_sign(digit_char: String) -> Control:
	# Create the main control with scaled sizing
	var digit_sign = Control.new()
	digit_sign.custom_minimum_size = Vector2(SIGN_WIDTH * SIGN_SCALE, SIGN_HEIGHT * SIGN_SCALE)
	digit_sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Create visual container for animations (but don't offset it)
	var visual_container = Control.new()
	visual_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	digit_sign.add_child(visual_container)
	
	# Find template elements more safely
	var template_texture_rect = null
	var template_label = null
	
	# Find TextureRect in template
	for child in digit_template.get_children():
		if child is TextureRect:
			template_texture_rect = child
			break
	
	if template_texture_rect:
		# Find Label in TextureRect
		for child in template_texture_rect.get_children():
			if child is Label:
				template_label = child
				break
	
	if not template_texture_rect or not template_label:
		push_error("MoneyDisplay: Could not find TextureRect or Label in template!")
		return digit_sign
	
	# Duplicate the entire board with its label as a child
	var board = template_texture_rect.duplicate()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.scale = Vector2(SIGN_SCALE, SIGN_SCALE)
	visual_container.add_child(board)
	
	# Find and update the label that's now a child of the duplicated board
	var label = null
	for child in board.get_children():
		if child is Label:
			label = child
			break
	
	if label:
		label.text = digit_char
		label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	_init_sign_properties(digit_sign, digit_char, visual_container)
	return digit_sign

func _init_sign_properties(digit_sign: Control, digit_char: String, visual_container: Control):
	digit_sign.set_meta("digit", digit_char)
	digit_sign.set_meta("visual_container", visual_container)
	digit_sign.set_meta("swing_timer", randf() * TAU)
	digit_sign.set_meta("swing_speed", randf_range(0.7, 0.9))
	digit_sign.set_meta("animating", false)

func update_display(old_string: String, new_string: String):
	var old_len = old_string.length()
	var new_len = new_string.length()
	
	# Handle length changes first
	if new_len > old_len:
		await _add_new_digits(old_len, new_len, new_string)
	elif new_len < old_len:
		_remove_extra_digits(new_len, old_len)
	
	# Then handle digit changes
	await _update_changed_digits(old_string, new_string, min(old_len, new_len))

func _add_new_digits(start_index: int, end_index: int, new_string: String):
	# Store current positions before adding new digits
	var existing_signs_data = []
	for i in range(active_digit_signs.size()):
		var sign = active_digit_signs[i]
		if is_instance_valid(sign):
			existing_signs_data.append({
				"sign": sign,
				"original_index": i
			})
	
	# Add new digits at the end
	for i in range(start_index, end_index):
		var digit_sign = create_digit_sign(new_string[i])
		digit_container.add_child(digit_sign)
		active_digit_signs.append(digit_sign)
		animate_slide_in(digit_sign)
		await get_tree().create_timer(0.02).timeout
	
	# Let the layout container handle repositioning automatically
	await get_tree().process_frame

func _remove_extra_digits(new_len: int, old_len: int):
	# Remove digits from the end
	var signs_to_remove = []
	for i in range(new_len, min(old_len, active_digit_signs.size())):
		if i < active_digit_signs.size():
			signs_to_remove.append(active_digit_signs[i])
	
	# Update the active list first
	active_digit_signs = active_digit_signs.slice(0, new_len)
	
	# Animate removal
	for digit_sign in signs_to_remove:
		if is_instance_valid(digit_sign):
			animate_fall(digit_sign)

func _update_changed_digits(old_string: String, new_string: String, max_index: int):
	for i in range(max_index):
		if i < active_digit_signs.size() and i < old_string.length() and old_string[i] != new_string[i]:
			animate_digit_change(active_digit_signs[i], new_string[i])
			await get_tree().create_timer(0.01).timeout

func animate_digit_change(digit_sign: Control, new_digit: String):
	if not is_instance_valid(digit_sign) or digit_sign.get_meta("animating", false):
		return
	
	digit_sign.set_meta("animating", true)
	digit_sign.set_meta("digit", new_digit)
	
	var visual_container = digit_sign.get_meta("visual_container")
	
	# Find the label within the board (it's now a child of the TextureRect)
	var label = null
	var board = null
	
	# Find the board (TextureRect) first
	for child in visual_container.get_children():
		if child is TextureRect:
			board = child
			break
	
	# Then find the label within the board
	if board:
		for child in board.get_children():
			if child is Label:
				label = child
				break
	
	if not label:
		digit_sign.set_meta("animating", false)
		return
	
	var tween = create_tween()
	tween.tween_property(visual_container, "scale:y", 0.0, 0.1)
	tween.tween_callback(func(): 
		if is_instance_valid(label):
			label.text = new_digit
	)
	tween.tween_property(visual_container, "scale:y", 1.0, 0.1)
	tween.finished.connect(func(): 
		if is_instance_valid(digit_sign):
			digit_sign.set_meta("animating", false)
	)

func animate_slide_in(digit_sign: Control):
	if not is_instance_valid(digit_sign):
		return
		
	digit_sign.set_meta("animating", true)
	var visual_container = digit_sign.get_meta("visual_container")
	var screen_width = get_viewport().get_visible_rect().size.x
	
	# Start from off-screen
	visual_container.position.x = screen_width
	visual_container.rotation = deg_to_rad(45)
	visual_container.modulate.a = 0.5
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Animate to neutral position (0,0) - let the container handle final positioning
	tween.tween_property(visual_container, "position:x", 0.0, 0.6)
	tween.tween_property(visual_container, "modulate:a", 1.0, 0.4)
	tween.tween_property(visual_container, "rotation", deg_to_rad(-8), 0.4)
	tween.tween_property(visual_container, "rotation", deg_to_rad(2), 0.1).set_delay(0.4)
	tween.tween_property(visual_container, "rotation", 0.0, 0.1).set_delay(0.5)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.finished.connect(func(): 
		if is_instance_valid(digit_sign):
			digit_sign.set_meta("animating", false)
	)

func animate_fall(digit_sign: Control):
	if not is_instance_valid(digit_sign):
		return
		
	digit_sign.set_meta("animating", true)
	var visual_container = digit_sign.get_meta("visual_container")
	
	# Remove from container but keep the sign for animation
	digit_container.remove_child(digit_sign)
	
	# Add to main display for falling animation
	add_child(digit_sign)
	
	# Get current screen position
	var current_pos = digit_sign.position
	
	# Small upward bounce first
	var initial_tween = create_tween()
	initial_tween.tween_property(digit_sign, "position:y", current_pos.y - 15, 0.15)
	initial_tween.finished.connect(func(): _start_actual_fall(digit_sign, visual_container, current_pos))

func _start_actual_fall(digit_sign: Control, visual_container: Control, start_pos: Vector2):
	if not is_instance_valid(digit_sign):
		return
		
	var tween = create_tween()
	tween.set_parallel(true)
	
	var viewport_size = get_viewport().get_visible_rect().size
	var fall_distance = viewport_size.y + 100
	var drift = randf_range(-30, 30)
	
	tween.tween_property(digit_sign, "position", Vector2(start_pos.x + drift, fall_distance), 1.2)
	tween.tween_property(visual_container, "rotation", randf_range(1.5, 3.0), 1.2)
	tween.tween_property(digit_sign, "modulate:a", 0.0, 1.0)
	tween.set_ease(Tween.EASE_IN)
	
	tween.finished.connect(func(): 
		if is_instance_valid(digit_sign):
			digit_sign.queue_free()
	)

func _cancel_all_animations():
	for digit_sign in active_digit_signs:
		if is_instance_valid(digit_sign):
			digit_sign.set_meta("animating", false)
			
			var visual_container = digit_sign.get_meta("visual_container")
			if visual_container != null:
				# Kill all tweens
				var tweens = get_tree().get_nodes_in_group("@SceneTween")
				for tween in tweens:
					if tween.is_valid():
						tween.kill()
				
				# Reset visual container to neutral state
				visual_container.position = Vector2.ZERO
				visual_container.scale = Vector2.ONE
				visual_container.rotation = 0.0
				visual_container.modulate.a = 1.0

func _process(delta):
	# Sync check
	var actual_money = GameManager.player.money
	if actual_money != current_money:
		_on_money_changed(actual_money)
	
	# Gentle swinging animation for non-animating signs
	for digit_sign in active_digit_signs:
		if not is_instance_valid(digit_sign) or digit_sign.get_meta("animating", false):
			continue
			
		var visual_container = digit_sign.get_meta("visual_container")
		var timer = digit_sign.get_meta("swing_timer", 0.0) + delta * digit_sign.get_meta("swing_speed", 0.8)
		digit_sign.set_meta("swing_timer", timer)
		
		var swing_offset = sin(timer) * deg_to_rad(SWING_AMPLITUDE)
		visual_container.rotation = swing_offset
