extends Control

## Меню выбора уровней

@onready var levels_grid: GridContainer = $CenterContainer/MenuPanel/VBoxContainer/ScrollContainer/LevelsGrid
@onready var back_button: Button = $CenterContainer/MenuPanel/VBoxContainer/BackButton

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

func _create_level_buttons() -> void:
	for child in levels_grid.get_children():
		child.queue_free()
	
	for i in range(level_paths.size()):
		var level_number = i + 1
		var button = Button.new()
		button.text = str(level_number)
		button.custom_minimum_size = Vector2(80, 80)
		button.add_theme_font_size_override("font_size", 20)
		
		if ResourceLoader.exists(level_paths[i]):
			button.pressed.connect(_on_level_button_pressed.bind(i))
		else:
			button.disabled = true
			button.text = str(level_number) + "\n❌"
			button.add_theme_font_size_override("font_size", 14)
		
		levels_grid.add_child(button)
	
	_add_test_level_button("Тест лис", "res://scenes/test_fox_level.tscn")
	_add_test_level_button("Тест атаки", "res://scenes/test_fox_attack.tscn")

func _add_test_level_button(button_text: String, level_path: String) -> void:
	if ResourceLoader.exists(level_path):
		var button = Button.new()
		button.text = button_text
		button.custom_minimum_size = Vector2(80, 80)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_test_level_button_pressed.bind(level_path))
		levels_grid.add_child(button)

func _on_level_button_pressed(level_index: int) -> void:
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("set_current_level"):
		game_manager.set_current_level(level_index)
	
	if level_index < level_paths.size():
		get_tree().change_scene_to_file(level_paths[level_index])
	else:
		printerr("Неверный индекс уровня: ", level_index)

func _on_test_level_button_pressed(level_path: String) -> void:
	get_tree().change_scene_to_file(level_path)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn") 
