extends Control

@onready var scroll_main: Control = $ScrollMain
@onready var scroll_texture: TextureRect = $ScrollMain/ScrollText
@onready var tooltip_label: RichTextLabel = $ScrollMain/RichTextLabel

var current_tween: Tween
var original_scroll_position: Vector2
var scroll_full_width: float
var target_scroll_position: Vector2
var hidden_scroll_position: Vector2
var is_tooltip_visible: bool = false
var is_animating: bool = false

func _ready():
	# Get the full width of the scroll texture
	scroll_full_width = scroll_texture.texture.get_width()
	
	# Store original positions
	original_scroll_position = scroll_main.position
	
	# Calculate positions once
	var reveal_distance = scroll_full_width * 1
	target_scroll_position = Vector2(original_scroll_position.x - (scroll_full_width - reveal_distance), original_scroll_position.y)
	hidden_scroll_position = Vector2(original_scroll_position.x - scroll_full_width, original_scroll_position.y)
	
	# Initially hide
	hide_tooltip_immediate()

func show_tooltip(text: String):
	# Update text immediately
	tooltip_label.text = text
	
	# If already visible, just update text and stay in place
	if is_tooltip_visible and not is_animating:
		return
	
	# Stop any current animation
	_stop_current_tween()
	
	# Set initial state
	visible = true
	is_animating = true
	
	# If tooltip was hidden, start from hidden position
	if not is_tooltip_visible:
		scroll_main.position = hidden_scroll_position
	
	# Animate to visible position
	current_tween = create_tween()
	current_tween.tween_property(scroll_main, "position", target_scroll_position, 0.35)
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Set state when animation completes
	current_tween.tween_callback(_on_show_complete)
	
	is_tooltip_visible = true

func hide_tooltip():
	if not is_tooltip_visible:
		return
	
	_stop_current_tween()
	is_animating = true
	
	
	# Animate to hidden position
	current_tween = create_tween()
	current_tween.tween_property(scroll_main, "position", hidden_scroll_position, 0.25)
	current_tween.set_ease(Tween.EASE_IN)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Hide completely when animation finishes
	current_tween.tween_callback(_on_hide_complete)

func hide_tooltip_immediate():
	_stop_current_tween()
	scroll_main.position = hidden_scroll_position
	visible = false
	is_tooltip_visible = false
	is_animating = false

# Helper functions
func _stop_current_tween():
	if current_tween:
		current_tween.kill()
		current_tween = null

func _on_show_complete():
	is_animating = false

func _on_hide_complete():
	visible = false
	is_tooltip_visible = false
	is_animating = false
