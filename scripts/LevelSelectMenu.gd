extends Control

## Меню выбора уровней

@onready var levels_grid: GridContainer = $CenterContainer/VBoxContainer/LevelsContainer/LevelsGrid
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

var level_paths: Array[String] = []

func _ready() -> void:
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("get_level_paths"):
		level_paths = game_manager.get_level_paths()
	else:
		level_paths = [
			"res://scenes/level_1.tscn",
			"res://scenes/level_2.tscn", 
			"res://scenes/level_3.tscn",
			"res://scenes/level_4.tscn",
			"res://scenes/level_5.tscn",
			"res://scenes/level_6.tscn",
			"res://scenes/level_7.tscn",
			"res://scenes/level_8.tscn",
			"res://scenes/level_9.tscn",
			"res://scenes/level_10.tscn",
			"res://scenes/level_11.tscn",
			"res://scenes/level_12.tscn"
		]
	
	_create_level_buttons()
	
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	else:
		printerr("LevelSelectMenu: Кнопка 'Назад' не найдена!")
	
	# Устанавливаем фокус на первую кнопку уровня после создания
	call_deferred("_set_initial_focus")

func _create_level_buttons() -> void:
	for child in levels_grid.get_children():
		child.queue_free()
	
	for i in range(level_paths.size()):
		var level_number = i + 1
		var button = Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(80, 80)
		
		# Создаем стили для кнопки уровня
		var normal_style = _create_level_button_style(level_number, "normal")
		var hover_style = _create_level_button_style(level_number, "hover") 
		var pressed_style = _create_level_button_style(level_number, "pressed")
		
		if normal_style:
			button.add_theme_stylebox_override("normal", normal_style)
		if hover_style:
			button.add_theme_stylebox_override("hover", hover_style)
		if pressed_style:
			button.add_theme_stylebox_override("pressed", pressed_style)
		
		if ResourceLoader.exists(level_paths[i]):
			button.pressed.connect(_on_level_button_pressed.bind(i))
		else:
			button.disabled = true
		
		levels_grid.add_child(button)

func _create_level_button_style(level_number: int, state: String) -> StyleBoxTexture:
	var texture_path = "res://assets/Sprites/UI/buttons/level" + str(level_number) + "_" + state + ".png"
	
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path) as Texture2D
		if texture:
			var style = StyleBoxTexture.new()
			style.texture = texture
			return style
	
	return null

func _on_level_button_pressed(level_index: int) -> void:
	print("LevelSelectMenu: Нажата кнопка уровня ", level_index + 1)
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("load_specific_level"):
		game_manager.load_specific_level(level_index)
	else:
		printerr("LevelSelectMenu: GameManager не найден или не имеет метода load_specific_level")
		# Fallback на старый способ
		if level_index < level_paths.size():
			get_tree().change_scene_to_file(level_paths[level_index])
		else:
			printerr("Неверный индекс уровня: ", level_index)

func _set_initial_focus() -> void:
	# Устанавливаем фокус на первую доступную кнопку уровня
	if levels_grid.get_child_count() > 0:
		var first_button = levels_grid.get_child(0) as Button
		if first_button and not first_button.disabled:
			first_button.grab_focus()

func _on_back_button_pressed() -> void:
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("hide_hud"):
		game_manager.hide_hud()
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn") 
