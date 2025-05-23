extends CanvasLayer

# Ссылки на кнопки
@onready var play_again_button: Button = $CenterContainer/VBoxContainer/PlayAgainButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var win_label: Label = $CenterContainer/VBoxContainer/WinLabel

# Константы для типов экрана
enum ScreenType { WIN, LOSE }
var current_screen_type: int = ScreenType.WIN

func _ready() -> void:
	# Устанавливаем режим обработки, чтобы UI работал на паузе
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Проверяем, передан ли параметр с типом экрана
	if has_meta("screen_type"):
		current_screen_type = get_meta("screen_type")
		
	# Настраиваем текст в зависимости от типа экрана
	if current_screen_type == ScreenType.LOSE:
		if win_label:
			win_label.text = "ПОРАЖЕНИЕ!"
	
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
		# В зависимости от типа экрана делаем разные действия
		if current_screen_type == ScreenType.WIN:
			# Для победы - начинаем с первого уровня
			if game_manager.has_method("load_level_by_index"):
				game_manager.load_level_by_index(0)
			else:
				printerr("GameOverScreen: Метод load_level_by_index отсутствует в GameManager!")
		else:
			# Для поражения - перезапускаем текущий уровень
			if game_manager.has_method("restart_current_level"):
				game_manager.restart_current_level()
			else:
				printerr("GameOverScreen: Метод restart_current_level отсутствует в GameManager!")
	else:
		printerr("GameOverScreen: Не удалось найти GameManager!")
		
	# Удаляем сам экран победы (отложенный вызов)
	call_deferred("queue_free")

# Вызывается при нажатии кнопки "Выйти"
func _on_quit_button_pressed() -> void:
	# Снимаем паузу перед выходом
	get_tree().paused = false
	get_tree().quit() 