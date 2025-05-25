extends Control

## Меню выбора уровней

@onready var levels_grid: GridContainer = $VBoxContainer/ScrollContainer/LevelsGrid
@onready var back_button: Button = $VBoxContainer/BackButton

# Список путей к уровням (получаем из GameManager)
var level_paths: Array[String] = []

func _ready() -> void:
	# Получаем список уровней из GameManager
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("get_level_paths"):
		level_paths = game_manager.get_level_paths()
	else:
		# Fallback - используем стандартные пути
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
	
	# Создаем кнопки для каждого уровня
	_create_level_buttons()
	
	# Подключаем кнопку "Назад"
	back_button.pressed.connect(_on_back_button_pressed)

func _create_level_buttons() -> void:
	# Очищаем существующие кнопки
	for child in levels_grid.get_children():
		child.queue_free()
	
	# Создаем кнопку для каждого уровня
	for i in range(level_paths.size()):
		var level_number = i + 1
		var button = Button.new()
		button.text = str(level_number)
		button.custom_minimum_size = Vector2(60, 60)
		
		# Проверяем, существует ли файл уровня
		if ResourceLoader.exists(level_paths[i]):
			button.pressed.connect(_on_level_button_pressed.bind(i))
		else:
			button.disabled = true
			button.text += "\n(нет)"
		
		levels_grid.add_child(button)
	
	# Добавляем кнопки для тестовых уровней
	_add_test_level_button("Тест лис", "res://scenes/test_fox_level.tscn")
	_add_test_level_button("Тест атаки", "res://scenes/test_fox_attack.tscn")

func _add_test_level_button(button_text: String, level_path: String) -> void:
	if ResourceLoader.exists(level_path):
		var button = Button.new()
		button.text = button_text
		button.custom_minimum_size = Vector2(60, 60)
		button.pressed.connect(_on_test_level_button_pressed.bind(level_path))
		levels_grid.add_child(button)

func _on_level_button_pressed(level_index: int) -> void:
	print("Выбран уровень: ", level_index + 1)
	
	# Устанавливаем текущий уровень в GameManager
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("set_current_level"):
		game_manager.set_current_level(level_index)
	
	# Загружаем выбранный уровень
	if level_index < level_paths.size():
		get_tree().change_scene_to_file(level_paths[level_index])
	else:
		printerr("Неверный индекс уровня: ", level_index)

func _on_test_level_button_pressed(level_path: String) -> void:
	print("Выбран тестовый уровень: ", level_path)
	get_tree().change_scene_to_file(level_path)

func _on_back_button_pressed() -> void:
	# Возвращаемся в главное меню
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn") 