extends Control

@onready var shop_container: VBoxContainer = $ScrollContainer/ShopContainer

var upgrade_cards: Dictionary = {}
const UpgradeCardScene = preload("res://scenes/UpgradeCard.tscn")
var hide_timer: SceneTreeTimer

func _ready():
	await get_tree().process_frame
	GameManager.money_changed.connect(_on_money_changed)
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	setup_upgrade_cards()

func setup_upgrade_cards():
	if not shop_container:
		printerr("ERROR: Shop container not found!")
		return

	clear_all_upgrade_cards()
	
	# Get ALL potentially showable upgrades (not just available ones)
	var all_upgrades = UpgradeManager.get_all_showable_upgrades()
	
	for upgrade_id in all_upgrades:
		create_upgrade_card(upgrade_id)

func clear_all_upgrade_cards():
	for child in shop_container.get_children():
		child.queue_free()
	upgrade_cards.clear()
	await get_tree().process_frame

func create_upgrade_card(upgrade_id: String):
	if upgrade_cards.has(upgrade_id):
		return # Already exists
	
	var card_instance = UpgradeCardScene.instantiate()
	shop_container.add_child(card_instance)
	
	var upgrade_data = UpgradeManager.upgrades[upgrade_id]
	card_instance.setup_card(upgrade_id, upgrade_data)
	
	# Connect signals
	card_instance.upgrade_hovered.connect(_on_upgrade_hovered)
	card_instance.upgrade_unhovered.connect(_on_upgrade_unhovered)
	card_instance.upgrade_clicked.connect(_on_upgrade_clicked)
	
	upgrade_cards[upgrade_id] = card_instance

func should_show_upgrade(upgrade_id: String) -> bool:
	# Hide if maxed
	if UpgradeManager.is_upgrade_maxed(upgrade_id):
		return false
	
	# Hide if requirements not met (locked)
	if not UpgradeManager.check_requirements(upgrade_id):
		return false
	
	return true

func refresh_all_cards():
	for upgrade_id in upgrade_cards:
		var card = upgrade_cards[upgrade_id]
		if is_instance_valid(card):
			# Show/hide card based on conditions
			if should_show_upgrade(upgrade_id):
				card.visible = true
				card.update_display()
			else:
				card.visible = false

func _on_money_changed(_new_amount: int):
	refresh_all_cards()

func _on_upgrade_purchased(_upgrade_id: String):
	refresh_all_cards()

func _on_upgrade_clicked(upgrade_id: String):
	UpgradeManager.purchase_upgrade(upgrade_id)

func _on_upgrade_hovered(_upgrade_id: String, upgrade_data: Dictionary):
	if hide_timer:
		hide_timer.timeout.disconnect(_hide_tooltip_delayed)
		hide_timer = null
	
	var tooltip = get_tree().get_first_node_in_group("tooltip")
	if tooltip:
		tooltip.show_tooltip(upgrade_data.description)

func _on_upgrade_unhovered():
	hide_timer = get_tree().create_timer(0.1)
	hide_timer.timeout.connect(_hide_tooltip_delayed, CONNECT_ONE_SHOT)
		
func _hide_tooltip_delayed():
	var tooltip = get_tree().get_first_node_in_group("tooltip")
	if tooltip:
		tooltip.hide_tooltip()
	hide_timer = null
