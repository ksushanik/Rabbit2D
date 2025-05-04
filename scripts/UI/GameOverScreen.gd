extends CanvasLayer

# Ссылки на кнопки
@onready var play_again_button: Button = $CenterContainer/VBoxContainer/PlayAgainButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	# Устанавливаем режим обработки, чтобы UI работал на паузе
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Подключаем сигналы кнопок при готовности узла
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка PlayAgainButton не найдена!")
		
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка QuitButton не найдена!")
		
	# Ставим фокус на одну из кнопок для управления с клавиатуры/геймпада
	if play_again_button:
		play_again_button.grab_focus()
		
	# Паузим игру под экраном победы
	get_tree().paused = true

# Вызывается при нажатии кнопки "Играть снова"
func _on_play_again_button_pressed() -> void:
	# Снимаем паузу перед перезапуском
	get_tree().paused = false
	
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		# Убедимся, что метод существует, на всякий случай
		if game_manager.has_method("load_level_by_index"):
			game_manager.load_level_by_index(0)
		else:
			printerr("GameOverScreen: Метод load_level_by_index отсутствует в GameManager!")
	else:
		printerr("GameOverScreen: Не удалось найти GameManager!")
		
	# Удаляем сам экран победы (отложенный вызов)
	call_deferred("queue_free")

# Вызывается при нажатии кнопки "Выйти"
func _on_quit_button_pressed() -> void:
	# Снимаем паузу перед выходом
	get_tree().paused = false
	get_tree().quit() 