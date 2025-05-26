extends Control

## Главное меню игры

@onready var start_game_button: Button = $CenterContainer/VBoxContainer/StartGameButton
@onready var level_select_button: Button = $CenterContainer/VBoxContainer/LevelSelectButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	if not start_game_button:
		printerr("MainMenu: Кнопка StartGameButton не найдена!")
	if not level_select_button:
		printerr("MainMenu: Кнопка LevelSelectButton не найдена!")
	if not quit_button:
		printerr("MainMenu: Кнопка QuitButton не найдена!")
	
	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
		# Устанавливаем фокус на первую кнопку при загрузке меню с задержкой
		call_deferred("_set_initial_focus")
	if level_select_button:
		level_select_button.pressed.connect(_on_level_select_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_start_game_pressed() -> void:
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.load_level_by_index(0)
	else:
		get_tree().change_scene_to_file("res://scenes/level_1.tscn")

func _on_level_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/LevelSelectMenu.tscn")

func _set_initial_focus() -> void:
	if start_game_button:
		start_game_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit() 