extends Control

## Главное меню игры

@onready var start_game_button: Button = $VBoxContainer/StartGameButton
@onready var level_select_button: Button = $VBoxContainer/LevelSelectButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	# Подключаем сигналы кнопок
	start_game_button.pressed.connect(_on_start_game_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_game_pressed() -> void:
	print("Начинаем игру с первого уровня")
	# Сбрасываем GameManager на первый уровень
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.load_level_by_index(0)
	else:
		# Fallback - загружаем первый уровень напрямую
		get_tree().change_scene_to_file("res://scenes/level_1.tscn")

func _on_level_select_pressed() -> void:
	print("Открываем меню выбора уровней")
	get_tree().change_scene_to_file("res://scenes/UI/LevelSelectMenu.tscn")

func _on_quit_pressed() -> void:
	print("Выход из игры")
	get_tree().quit() 