extends Node

enum SurfaceType { GRASS, SAND, ICE, WATER, DEEP_ROUGH, ROUGH, GREEN }

var current_surface: SurfaceType = SurfaceType.GRASS
var last_surface: SurfaceType = SurfaceType.GRASS
var golf_ball: Node2D

# Store base values and current upgrade-modified values
var base_friction: float
var base_max_power: int
var upgraded_friction: float
var upgraded_max_power: int

func _ready():
	golf_ball = get_parent()
	call_deferred("store_base_values")
	# Listen for upgrade stat updates
	UpgradeManager.stats_updated.connect(_on_stats_updated)

func store_base_values():
	base_friction = golf_ball.get_base_stat("friction")
	base_max_power = golf_ball.get_base_stat("max_power")
	upgraded_friction = golf_ball.friction
	upgraded_max_power = golf_ball.max_power

func _on_stats_updated(object_name: String):
	if object_name == "ball":
		# Store the new upgraded values
		upgraded_friction = golf_ball.friction
		upgraded_max_power = golf_ball.max_power
		# Reapply surface effects if we're not on grass
		if current_surface != SurfaceType.GRASS:
			apply_surface_effects()

func check_and_apply_surface_effects():
	detect_current_surface()
	if current_surface != last_surface:
		apply_surface_effects()
		last_surface = current_surface

func detect_current_surface():
	var loaded_level = CourseManager.loaded_level_scene
	if not loaded_level:
		current_surface = SurfaceType.GRASS
		return
	
	# Check WaterLayer for custom data (water/sand/ice)
	var water_layer = loaded_level.get_node_or_null("WaterLayer")
	if water_layer:
		var tile_pos = water_layer.local_to_map(water_layer.to_local(golf_ball.global_position))
		var tile_data = water_layer.get_cell_tile_data(tile_pos)
		
		if tile_data:
			var identifier = tile_data.get_custom_data("identifiers")
			match identifier:
				"water":
					current_surface = SurfaceType.WATER
					CourseManager.restart_level_player_lost()
					return
				"sand":
					current_surface = SurfaceType.SAND
					return
				"ice":
					current_surface = SurfaceType.ICE
					return
	
	# Check grass type layers
	check_grass_layers(loaded_level)

func check_grass_layers(loaded_level: Node):
	# Check in order: DeepRough -> Rough -> Green -> default Grass
	var layer_map = {
		"DeepRough": SurfaceType.DEEP_ROUGH,
		"Rough": SurfaceType.ROUGH,
		"Green": SurfaceType.GREEN
	}
	
	for layer_name in layer_map.keys():
		var layer = loaded_level.get_node_or_null(layer_name)
		if layer:
			var tile_pos = layer.local_to_map(layer.to_local(golf_ball.global_position))
			var tile_data = layer.get_cell_tile_data(tile_pos)
			if tile_data:
				current_surface = layer_map[layer_name]
				return
	
	current_surface = SurfaceType.GRASS

func apply_surface_effects():
	# Reset to upgraded values first
	reset_surface_effects()
	
	# Apply surface modifications to the upgrade-modified values
	match current_surface:
		SurfaceType.SAND:
			golf_ball.friction = 0.8
			golf_ball.max_power = max(upgraded_max_power * 0.7, 2)
		SurfaceType.ICE:
			golf_ball.friction = 0.96
			golf_ball.max_power = int(upgraded_max_power * 1.3)
		SurfaceType.DEEP_ROUGH:
			golf_ball.friction = 0.86
			golf_ball.max_power = max(upgraded_max_power * 0.82, 3)
		SurfaceType.ROUGH:
			golf_ball.friction = 0.9
			golf_ball.max_power = max(upgraded_max_power * 0.93, 3)
		SurfaceType.GREEN:
			pass

func reset_surface_effects():
	# Reset to the current upgraded values (not base values)
	golf_ball.friction = upgraded_friction
	golf_ball.max_power = upgraded_max_power

func reset_surface():
	current_surface = SurfaceType.GRASS
	last_surface = SurfaceType.GRASS
	reset_surface_effects()

func get_current_surface() -> SurfaceType:
	return current_surface
