extends CanvasLayer

@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $CenterContainer/VBoxContainer/MenuButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка RestartButton не найдена!")
	
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка MenuButton не найдена!")
		
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка ExitButton не найдена!")
		
	# Устанавливаем фокус с задержкой
	call_deferred("_set_initial_focus")
		
	get_tree().paused = true

func _set_initial_focus() -> void:
	if restart_button:
		restart_button.grab_focus()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
	call_deferred("queue_free")

func _on_menu_button_pressed() -> void:
	get_tree().paused = false
	
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("show_main_menu"):
		game_manager.show_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
		
	call_deferred("queue_free")

func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit() 
