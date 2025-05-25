extends CanvasLayer

@onready var play_again_button: Button = $CenterContainer/WinPanel/VBoxContainer/PlayAgainButton
@onready var main_menu_button: Button = $CenterContainer/WinPanel/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $CenterContainer/WinPanel/VBoxContainer/QuitButton

func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка PlayAgainButton не найдена!")
	
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка MainMenuButton не найдена!")
		
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка QuitButton не найдена!")
		
	if play_again_button:
		play_again_button.grab_focus()
		
	get_tree().paused = true

func _on_play_again_button_pressed() -> void:
	get_tree().paused = false
	
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		if game_manager.has_method("load_level_by_index"):
			game_manager.load_level_by_index(0)
		else:
			printerr("GameOverScreen: Метод load_level_by_index отсутствует в GameManager!")
	else:
		printerr("GameOverScreen: Не удалось найти GameManager!")
		
	call_deferred("queue_free")

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("show_main_menu"):
		game_manager.show_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
		
	call_deferred("queue_free")

func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit() 
