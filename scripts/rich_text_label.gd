extends RichTextLabel

func _ready():
	update_info_loop()

func update_info_loop():
	while true:
		text = build_info_text()
		await get_tree().create_timer(0.5).timeout

func build_info_text() -> String:
	var info = ""
	info += "[b][font_size=17][center]Expected gain[/center][/font_size][/b]\n"
	info += "[i]Per collectible:[/i] $" + str(GameManager.collectible_gain) + "\n"
	info += "[i]Upon scoring:[/i] $" + str(GameManager.base_hole_gain) + "\n"
	info += "[i]Under par bonus:[/i] $" + str(GameManager.under_par_bonus) + "[i] per point[/i] \n"
	info += "[b][font_size=17][center]Statistics[/center][/font_size][/b]\n"
	info += "[i]Total money gained:[/i] $" + str(GameManager.collectible_gain) + "\n"
	info += "[i]Gains upon scoring:[/i] $" + str(GameManager.base_hole_gain) + "\n"
	info += "[i]Under par bonus:[/i] $" + str(GameManager.under_par_bonus) + "[i] per point[/i] \n"
	info += "[i]Collectibles value:[/i] $" + str(GameManager.collectible_gain) + "\n"
	return info
