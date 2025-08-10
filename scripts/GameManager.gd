extends Node

# Core game data
signal money_changed(new_amount: int)
var collectible_gain = 2
var base_hole_gain = 5
var under_par_bonus = 15
@export var max_collectibles: int = 40
@export var max_ladybugs: int = 2
@export var collectible_spawn_interval: float = 1.5  # Upgradeable

var base_stats: Dictionary = {
	"max_collectibles": max_collectibles,
	"max_ladybugs": max_ladybugs
}

var player = {
	"money": 10000,
	"unlocks": {
		"upgrades": true,
		"arrow": false,
		"freeze": false
	},
	"upgrades": {},
	"stats": {},
	"settings": {
		"hide_complete_upgrades": false
	}
}

# Spawning
var active_collectibles: int = 0
var active_ladybugs: int = 0
var collectible_scene = preload("res://scenes/collectible_ball.tscn")
var ladybug_scene = preload("res://scenes/ladybug.tscn")

# Spawning data
var tilemap: TileMapLayer = null
var decorations: TileMapLayer = null
var water: TileMapLayer = null
var spawn_tiles: Array[Vector2i] = []
var game_root: Node2D = null

# Timer
var spawn_timer: Timer

func _ready():
	load_progress()
	await get_tree().process_frame
	money_changed.emit(player.money)
	UpgradeManager.register_object("gamemanager", self)
	
	# Connect to upgrade system
	UpgradeManager.stats_updated.connect(_on_stats_updated)
	
	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)

func _on_stats_updated(object_name: String):
	if object_name == "gamemanager":
		# Check if max_ladybugs increased
		var current_ladybugs = get_tree().get_nodes_in_group("ladybugs").size()
		if current_ladybugs < max_ladybugs:
			# Spawn the difference
			for i in range(max_ladybugs - current_ladybugs):
				spawn_additional_ladybug()

func _on_spawn_timer():
	attempt_spawn_collectible()
	
	# Restart with random interval
	spawn_timer.wait_time = randf_range(0.5, collectible_spawn_interval)
	spawn_timer.start()

func get_base_stat(property: String):
	return base_stats.get(property, 0)

func set_game_root(root: Node2D):
	game_root = root

# SAVE/LOAD SYSTEM
func save_progress():
	var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(player))
		file.close()

func load_progress():
	var file = FileAccess.open("user://save_data.json", FileAccess.READ)
	file = null
	if file == null:
		return
	
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()
	
	if result == OK:
		player = json.data

# MONEY SYSTEM
func spend_money(amount: int) -> bool:
	if player.money >= amount:
		player.money -= amount
		money_changed.emit(player.money)
		return true
	return false

func add_money(amount: int):
	player.money += amount
	money_changed.emit(player.money)

# UPGRADE SYSTEM
func apply_all_upgrades(ball: Node):
	for upgrade_id in player.upgrades:
		var level = player.upgrades[upgrade_id]
		for i in level:
			UpgradeManager.apply_upgrade_effect(upgrade_id, ball)

# CLEANUP
func cleanup_items():
	if spawn_timer:
		spawn_timer.stop()
	
	var collectibles = get_tree().get_nodes_in_group("collectibles")
	for collectible in collectibles:
		if is_instance_valid(collectible):
			collectible.queue_free()
	
	var ladybugs = get_tree().get_nodes_in_group("ladybugs")
	for ladybug in ladybugs:
		if is_instance_valid(ladybug):
			ladybug.queue_free()
	
	var patches = get_tree().get_nodes_in_group("collection_patches")
	for patch in patches:
		if is_instance_valid(patch):
			patch.queue_free()
	
	active_collectibles = 0
	active_ladybugs = 0

# TILEMAP SETUP
func set_tilemap_spawning(tilemap_layer: TileMapLayer, decorations_layer: TileMapLayer, water_layer: TileMapLayer):
	tilemap = tilemap_layer
	decorations = decorations_layer
	water = water_layer
	cache_spawn_tiles()
	active_collectibles = 0
	active_ladybugs = 0

func cache_spawn_tiles():
	spawn_tiles.clear()
	if not tilemap:
		return
	
	var used_cells = tilemap.get_used_cells()
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	
	for cell in used_cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	
	var margin = 3
	min_x += margin
	max_x -= margin
	min_y += margin
	max_y -= margin
	
	var spawn_candidates = 0
	var blocked_by_decoration = 0
	var blocked_by_water = 0
	var no_spawn_data = 0
	
	for tile_coord in used_cells:
		if tile_coord.x < min_x or tile_coord.x > max_x or tile_coord.y < min_y or tile_coord.y > max_y:
			continue
		
		spawn_candidates += 1
		var tile_data = tilemap.get_cell_tile_data(tile_coord)
		
		if not tile_data or tile_data.get_custom_data("spawn") != true:
			no_spawn_data += 1
			continue
		
		var world_pos = tilemap.map_to_local(tile_coord)
		var is_blocked = false
		
		if decorations:
			for decoration in decorations.get_children():
				if decoration.global_position.distance_to(world_pos) < 60:
					is_blocked = true
					blocked_by_decoration += 1
					break
		
		if water and water.get_cell_source_id(tile_coord) != -1:
			is_blocked = true
			blocked_by_water += 1
		
		if not is_blocked:
			spawn_tiles.append(tile_coord)
	
	print("Spawn tiles: %d total, blocked by decoration: %d, water: %d, no spawn data: %d" % [spawn_tiles.size(), blocked_by_decoration, blocked_by_water, no_spawn_data])

# START SPAWNING
func start_spawning():
	spawn_timer.wait_time = randf_range(0.5, collectible_spawn_interval)
	spawn_timer.start()

# INITIAL SPAWNING
func spawn_initial_ladybugs():
	for i in range(max_ladybugs):
		await get_tree().create_timer(1.0).timeout
		attempt_spawn_ladybug()

# When max_ladybugs gets upgraded, call this
func spawn_additional_ladybug():
	await get_tree().create_timer(1.0).timeout
	attempt_spawn_ladybug()

# COLLECTIBLES
func on_collectible_collected():
	active_collectibles -= 1

func attempt_spawn_collectible():
	if active_collectibles >= max_collectibles:
		print("Can't spawn collectible: at max limit (%d/%d)" % [active_collectibles, max_collectibles])
		return
	
	if not tilemap or not game_root:
		print("Can't spawn collectible: missing tilemap or game_root")
		return
	
	var available_tile = find_available_spawn_tile()
	if available_tile == Vector2i(-1, -1):
		print("Can't spawn collectible: no available tiles")
		return
	
	var world_pos = tilemap.map_to_local(available_tile)
	var collectible = collectible_scene.instantiate()
	game_root.add_child(collectible)
	collectible.global_position = world_pos
	collectible.add_to_group("collectibles")
	active_collectibles += 1
	
	collectible.ball_collected.connect(on_collectible_collected)

# LADYBUGS
func attempt_spawn_ladybug():
	if active_ladybugs >= max_ladybugs:
		print("Can't spawn ladybug: at max limit (%d/%d)" % [active_ladybugs, max_ladybugs])
		return
	
	if not tilemap or not game_root:
		print("Can't spawn ladybug: missing tilemap or game_root")
		return
	
	var available_tile = find_available_spawn_tile()
	if available_tile == Vector2i(-1, -1):
		print("Can't spawn ladybug: no available tiles")
		return
	
	var world_pos = tilemap.map_to_local(available_tile)
	var ladybug = ladybug_scene.instantiate()
	game_root.add_child(ladybug)
	ladybug.global_position = world_pos
	ladybug.add_to_group("ladybugs")
	active_ladybugs += 1

# SHARED SPAWN LOGIC
func find_available_spawn_tile() -> Vector2i:
	if not game_root:
		return Vector2i(-1, -1)
	
	var collectibles = game_root.get_tree().get_nodes_in_group("collectibles")
	var ladybugs = game_root.get_tree().get_nodes_in_group("ladybugs")
	var patches = game_root.get_tree().get_nodes_in_group("collection_patches")
	
	var blocked_by_collectibles = 0
	var blocked_by_ladybugs = 0
	var blocked_by_patches = 0
	var available_tiles: Array[Vector2i] = []
	
	for tile in spawn_tiles:
		var is_available = true
		
		# Check collectibles (2 tile distance)
		for collectible in collectibles:
			if is_instance_valid(collectible):
				var tile_pos = tilemap.local_to_map(collectible.global_position)
				if tile.distance_to(tile_pos) <= 2:
					is_available = false
					blocked_by_collectibles += 1
					break
		
		# Check ladybugs (2 tile distance)
		if is_available:
			for ladybug in ladybugs:
				if is_instance_valid(ladybug):
					var tile_pos = tilemap.local_to_map(ladybug.global_position)
					if tile.distance_to(tile_pos) <= 2:
						is_available = false
						blocked_by_ladybugs += 1
						break
		
		# Check patches (1 tile distance)
		if is_available:
			for patch in patches:
				if is_instance_valid(patch):
					var tile_pos = tilemap.local_to_map(patch.global_position)
					if tile.distance_to(tile_pos) <= 1:
						is_available = false
						blocked_by_patches += 1
						break
		
		if is_available:
			available_tiles.append(tile)
	
	if available_tiles.is_empty():
		print("No available spawn tiles - blocked by: collectibles %d, ladybugs %d, patches %d" % [blocked_by_collectibles, blocked_by_ladybugs, blocked_by_patches])
		return Vector2i(-1, -1)
	
	return available_tiles.pick_random()
