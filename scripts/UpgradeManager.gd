extends Node

signal upgrade_purchased(upgrade_id: String)
signal stats_updated(object_name: String)

# Upgrade definitions
# Updated upgrades dictionary with categories
var upgrades = {
	"maxPowerBoost": {
		"name": "Sand your rock",
		"description": "Sand it down to increase by [color=yellow]10%[/color] your maximum velocity!",
		"maxLevel": 5,
		"baseCost": 10,
		"costMultiplier": 1.5,
		"target": "ball",
		"property": "max_power",
		"type": "multiplicative",
		"value": 1.1,
		"category": "ball",
		"requirements": []
	},
	"frictionBoost": {
		"name": "Better Ball", 
		"description": "Your ball rolls smoother, reducing friction by [color=yellow]0.01[/color]",
		"maxLevel": 8,
		"baseCost": 15,
		"costMultiplier": 1.8,
		"target": "ball",
		"property": "friction",
		"type": "additive", 
		"value": 0.01,
		"category": "ball",
		"requirements": []
	},
	"powerMultiplier": {
		"name": "Rocket Ball",
		"description": "Multiply your power by [color=yellow]50%[/color]!",
		"maxLevel": 3,
		"baseCost": 50,
		"costMultiplier": 2.0,
		"target": "ball",
		"property": "max_power",
		"type": "multiplicative",
		"value": 1.5,
		"category": "ball",
		"requirements": ["maxPowerBoost"]
	},
	"accuracyMaster": {
		"name": "Steady Aim",
		"description": "Improve accuracy by [color=yellow]0.05[/color] points",
		"maxLevel": 10,
		"baseCost": 25,
		"costMultiplier": 1.6,
		"target": "ball",
		"property": "accuracy",
		"type": "additive",
		"value": 0.05,
		"category": "ball",
		"requirements": []
	},
	"sprayReduction": {
		"name": "Precision Shot",
		"description": "Reduce maximum spray angle by [color=yellow]5 degrees[/color]",
		"maxLevel": 7,
		"baseCost": 30,
		"costMultiplier": 1.6,
		"target": "ball",
		"property": "max_spray_angle",
		"type": "additive",
		"value": -5.0,
		"category": "ball",
		"requirements": ["accuracyMaster"]
	},
	"powerMega": {
		"name": "Cannon Ball",
		"description": "Massive [color=yellow]200%[/color] power boost!",
		"maxLevel": 2,
		"baseCost": 200,
		"costMultiplier": 3.0,
		"target": "ball",
		"property": "max_power",
		"type": "multiplicative",
		"value": 2.0,
		"category": "ball",
		"requirements": ["powerMultiplier"]
	},
	"collectibleBoost": {
		"name": "Treasure Hunter",
		"description": "Increase maximum collectibles by [color=yellow]5[/color]",
		"maxLevel": 8,
		"baseCost": 75,
		"costMultiplier": 2.0,
		"target": "gamemanager",
		"property": "max_collectibles",
		"type": "additive",
		"value": 5,
		"category": "collectible",
		"requirements": []
	},
	"ladybugBoost": {
		"name": "Bug Whisperer",
		"description": "Increase maximum ladybugs by [color=yellow]1[/color]",
		"maxLevel": 5,
		"baseCost": 150,
		"costMultiplier": 2.5,
		"target": "gamemanager",
		"property": "max_ladybugs",
		"type": "additive",
		"value": 1,
		"category": "ladybug",
		"requirements": []
	},
	"superFriction": {
		"name": "Super Smooth",
		"description": "Massively reduce friction by [color=yellow]0.05[/color]",
		"maxLevel": 3,
		"baseCost": 100,
		"costMultiplier": 2.5,
		"target": "ball",
		"property": "friction",
		"type": "additive",
		"value": 0.05,
		"category": "ball",
		"requirements": ["frictionBoost"]
	},
	"ultimatePower": {
		"name": "Nuclear Ball",
		"description": "Ultimate [color=yellow]300%[/color] power multiplier!",
		"maxLevel": 1,
		"baseCost": 500,
		"costMultiplier": 1.0,
		"target": "ball",
		"property": "max_power",
		"type": "multiplicative",
		"value": 3.0,
		"category": "ball",
		"requirements": ["powerMega"]
	}
}
var registered_objects = {}

func _ready():
	print("UpgradeManager ready")

func register_object(object_name: String, object: Node):
	registered_objects[object_name] = object
	print("Registered object: ", object_name)
	update_object_stats(object_name)

func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_purchase_upgrade(upgrade_id):
		return false
		
	var cost = get_upgrade_cost(upgrade_id)
	if not GameManager.spend_money(cost):
		return false
	
	# Increase upgrade level
	GameManager.player.upgrades[upgrade_id] = get_upgrade_level(upgrade_id) + 1
	
	# Update stats for affected object
	update_object_stats(upgrades[upgrade_id].target)
	
	upgrade_purchased.emit(upgrade_id)
	GameManager.save_progress()
	return true

func update_object_stats(object_name: String):
	if not registered_objects.has(object_name):
		return
		
	var object = registered_objects[object_name]
	var affected_properties = get_affected_properties(object_name)
	
	for property in affected_properties:
		var base_value = get_base_value(object, property)
		var final_value = calculate_final_stat(object_name, property, base_value)
		object.set(property, final_value)
		print(property, "upgraded to ", final_value)
	
	stats_updated.emit(object_name)

func get_affected_properties(object_name: String) -> Array:
	var properties = []
	for upgrade_id in GameManager.player.upgrades:
		if upgrades.has(upgrade_id) and upgrades[upgrade_id].target == object_name:
			var property = upgrades[upgrade_id].property
			if not properties.has(property):
				properties.append(property)
	return properties

func get_base_value(object: Node, property: String):
	if object.has_method("get_base_stat"):
		return object.get_base_stat(property)
	if "base_stats" in object:
		return object.base_stats.get(property, object.get(property))
	return object.get(property)

func calculate_final_stat(object_name: String, stat_name: String, base_value) -> float:
	var final_value = float(base_value)
	
	for upgrade_id in GameManager.player.upgrades:
		if not upgrades.has(upgrade_id):
			continue
			
		var upgrade = upgrades[upgrade_id]
		if upgrade.target == object_name and upgrade.property == stat_name:
			var level = GameManager.player.upgrades[upgrade_id]
			match upgrade.type:
				"additive":
					final_value += upgrade.value * level
				"multiplicative": 
					final_value *= pow(upgrade.value, level)
	
	return final_value

# CORE FUNCTIONS FOR SHOP
func get_all_showable_upgrades() -> Array:
	"""Returns ALL upgrades that could potentially be shown (not just currently available)"""
	var showable = []
	for upgrade_id in upgrades:
		if not is_upgrade_maxed(upgrade_id):
			showable.append(upgrade_id)
	return showable

func can_purchase_upgrade(upgrade_id: String) -> bool:
	if not upgrades.has(upgrade_id) or is_upgrade_maxed(upgrade_id):
		return false
	
	return (check_requirements(upgrade_id) and 
			GameManager.player.money >= get_upgrade_cost(upgrade_id))

func check_requirements(upgrade_id: String) -> bool:
	if not upgrades.has(upgrade_id):
		return false
	
	var requirements = upgrades[upgrade_id].get("requirements", [])
	for required_upgrade in requirements:
		if not is_upgrade_maxed(required_upgrade):
			return false
	return true

# HELPER FUNCTIONS
func get_upgrade_cost(upgrade_id: String) -> int:
	var upgrade_data = upgrades[upgrade_id]
	var current_level = get_upgrade_level(upgrade_id)
	return int(upgrade_data.baseCost * pow(upgrade_data.costMultiplier, current_level))

func get_upgrade_level(upgrade_id: String) -> int:
	return GameManager.player.upgrades.get(upgrade_id, 0)

func is_upgrade_maxed(upgrade_id: String) -> bool:
	return get_upgrade_level(upgrade_id) >= upgrades[upgrade_id].maxLevel
