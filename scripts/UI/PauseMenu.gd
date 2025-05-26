extends CanvasLayer

## Меню паузы

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $CenterContainer/VBoxContainer/MenuButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_button_pressed)
	else:
		printerr("PauseMenu: Кнопка ResumeButton не найдена!")
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	else:
		printerr("PauseMenu: Кнопка RestartButton не найдена!")
	
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	else:
		printerr("PauseMenu: Кнопка MenuButton не найдена!")
		
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
	else:
		printerr("PauseMenu: Кнопка ExitButton не найдена!")
		
	# Устанавливаем фокус с задержкой
	call_deferred("_set_initial_focus")
		
	get_tree().paused = true

func _set_initial_focus() -> void:
	if resume_button:
		resume_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_resume_button_pressed()
		get_tree().root.set_input_as_handled()

func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	call_deferred("queue_free")

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