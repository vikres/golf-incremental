# UpgradeCard.gd
extends Control

@onready var background_panel: Panel = $BackgroundPanel
@onready var icon: TextureRect = $BackgroundPanel/HBoxContainer/Icon
@onready var title_label: Label = $BackgroundPanel/HBoxContainer/InfoContainer/TitleLabel
@onready var cost_label: Label = $BackgroundPanel/HBoxContainer/InfoContainer/HBoxContainer/CostLabel
@onready var level_label: Label = $BackgroundPanel/HBoxContainer/InfoContainer/HBoxContainer/LevelLabel

var upgrade_id: String
var upgrade_data: Dictionary
var original_style: StyleBox

# Category icons - add these textures to your project
var category_icons = {
	"ball": preload("res://icon.svg"),  # Replace with your actual paths
	"collectible": preload("res://miniball2.png"),
	"ladybug": preload("res://icon.svg")
}

# Signals
signal upgrade_hovered(upgrade_id: String, upgrade_data: Dictionary)
signal upgrade_unhovered()
signal upgrade_clicked(upgrade_id: String)

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func setup_card(id: String, data: Dictionary):
	upgrade_id = id
	upgrade_data = data
	update_display()

func update_display():
	if not upgrade_data:
		return
	
	var current_level = UpgradeManager.get_upgrade_level(upgrade_id)
	var max_level = upgrade_data.maxLevel
	var current_cost = UpgradeManager.get_upgrade_cost(upgrade_id)
	var can_afford = GameManager.player.money >= current_cost
	
	# Update labels
	title_label.text = upgrade_data.name
	cost_label.text = str(current_cost) + " coins"
	level_label.text = "Level: " + str(current_level) + "/" + str(max_level)
	
	# Update icon based on category
	set_category_icon()
	
	# Update colors and interactivity
	if not can_afford:
		modulate = Color.WHITE
		cost_label.modulate = Color.RED
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		modulate = Color.WHITE
		cost_label.modulate = Color.WHITE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_category_icon():
	var category = upgrade_data.get("category", "ball")
	if category_icons.has(category) and icon:
		icon.texture = category_icons[category]

func _on_mouse_entered():
	upgrade_hovered.emit(upgrade_id, upgrade_data)
	
	if UpgradeManager.can_purchase_upgrade(upgrade_id):
		original_style = background_panel.get_theme_stylebox("panel")
		var hover_style = original_style.duplicate()
		hover_style.bg_color = Color(0.6, 0.6, 0.6, 0.9)
		background_panel.add_theme_stylebox_override("panel", hover_style)

func _on_mouse_exited():
	upgrade_unhovered.emit()
	if background_panel and original_style:
		background_panel.add_theme_stylebox_override("panel", original_style)

func _on_gui_input(event: InputEvent):
	if (event is InputEventMouseButton and 
		event.button_index == MOUSE_BUTTON_LEFT and 
		event.pressed and 
		UpgradeManager.can_purchase_upgrade(upgrade_id)):
		upgrade_clicked.emit(upgrade_id)
