extends Node

# Настройки игры
var game_settings: Dictionary = {}

# Глобальный фон
var background_canvas: CanvasLayer = null
var background_texture: TextureRect = null

# Фоновая музыка
var background_music_player: AudioStreamPlayer = null
var current_music_track: String = ""
var summer_music_path: String = "res://assets/Sounds/summer.mp3"
var autumn_music_path: String = "res://assets/Sounds/autumn.mp3"

# Список путей ко всем сценам уровней в игре
var level_paths: Array[String] = [
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
# Ссылка на сцену экрана завершения игры
var game_over_scene: PackedScene = load("res://scenes/UI/GameOverScreen.tscn")

var current_level_index: int = -1


func _ready() -> void:
	# Загружаем настройки игры
	load_game_settings()
	
	# Настраиваем глобальный фон
	_setup_global_background()
	
	# Инициализируем фоновую музыку
	_setup_background_music()
	
	# Показываем главное меню при запуске игры
	if current_level_index == -1:
		await get_tree().process_frame
		show_main_menu()


func load_level_by_index(index: int) -> void:
	# Проверяем, является ли индекс допустимым
	if index < 0:
		printerr("Error: Invalid level index (negative): ", index)
		get_tree().quit()
		return
	
	# Проверяем, есть ли еще уровни
	if index >= level_paths.size():
		print("--- GAME COMPLETED! All levels finished. ---")
		# Скрываем HUD перед показом экрана победы
		hide_hud()
		# Показываем экран завершения игры с режимом победы
		if game_over_scene:
			var game_over_instance = game_over_scene.instantiate()
			# Устанавливаем режим победы
			if game_over_instance.has_method("set_victory_mode"):
				game_over_instance.set_victory_mode(true)
			get_tree().root.add_child(game_over_instance)
		else:
			printerr("GameManager: Сцена game_over_scene не установлена!")
			get_tree().quit() # Выходим, если экрана победы нет
		return

	current_level_index = index
	
	# Запускаем подходящую фоновую музыку для этого уровня
	play_background_music_for_level(current_level_index)
	
	# Загружаем сцену уровня
	var error = get_tree().change_scene_to_file(level_paths[current_level_index])
	if error != OK:
		printerr("Error loading level scene: %s. Error code: %d" % [level_paths[current_level_index], error])


func load_next_level() -> void:
	load_level_by_index(current_level_index + 1)


func restart_current_level() -> void:
	load_level_by_index(current_level_index)

# Обработка глобального ввода (например, для перезапуска)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Перезапускаем текущий уровень по нажатию пользовательской клавиши
		if event.keycode == game_settings.get("restart_key", KEY_R):
			# Проверяем, что мы находимся в игре, а не в меню
			if current_level_index >= 0 and current_level_index < level_paths.size():
				print("Restart key pressed, reloading level...")
				restart_current_level()
				get_tree().root.set_input_as_handled()
			else:
				print("Restart key pressed, but not in a level (current_level_index: %d)" % current_level_index)

# Загружает настройки игры
func load_game_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err != OK:
		# Используем настройки по умолчанию
		game_settings = {
			"pause_key": KEY_ESCAPE,
			"restart_key": KEY_R,
			"sound_enabled": true,
			"master_volume": 1.0
		}
	else:
		game_settings = {
			"pause_key": config.get_value("controls", "pause_key", KEY_ESCAPE),
			"restart_key": config.get_value("controls", "restart_key", KEY_R),
			"sound_enabled": config.get_value("audio", "sound_enabled", true),
			"master_volume": config.get_value("audio", "master_volume", 1.0)
		}
	
	# Применяем аудио настройки
	apply_audio_settings()

# Применяет аудио настройки
func apply_audio_settings() -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	if game_settings["sound_enabled"]:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(game_settings["master_volume"]))
	else:
		AudioServer.set_bus_volume_db(master_bus, -80.0)

# Перезагружает настройки игры из файла (для применения изменений без перезапуска)
func reload_game_settings() -> void:
	load_game_settings()
	print("GameManager: Настройки игры перезагружены")

# Инициализирует фоновый музыкальный плеер
func _setup_background_music() -> void:
	background_music_player = AudioStreamPlayer.new()
	background_music_player.name = "BackgroundMusicPlayer"
	background_music_player.volume_db = -15.0  # Фоновая музыка должна быть тише
	background_music_player.bus = "Master"
	add_child(background_music_player)
	print("GameManager: Фоновый музыкальный плеер инициализирован")

# Настраивает глобальный фон для всей игры
func _setup_global_background() -> void:
	# Создаем CanvasLayer для фона (он будет отображаться позади всего)
	background_canvas = CanvasLayer.new()
	background_canvas.name = "GlobalBackgroundCanvas"
	background_canvas.layer = -100  # Очень далеко назад, чтобы быть позади всего
	add_child(background_canvas)
	
	# Создаем TextureRect для отображения фоновой картинки
	background_texture = TextureRect.new()
	background_texture.name = "GlobalBackgroundTexture"
	
	# Загружаем фоновую картинку
	var bg_image = load("res://assets/Sprites/UI/background.png") as Texture2D
	if bg_image:
		background_texture.texture = bg_image
		
		# Устанавливаем якоря и margin для покрытия всего экрана
		background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background_texture.anchor_left = 0.0
		background_texture.anchor_top = 0.0
		background_texture.anchor_right = 1.0
		background_texture.anchor_bottom = 1.0
		background_texture.offset_left = 0.0
		background_texture.offset_top = 0.0
		background_texture.offset_right = 0.0
		background_texture.offset_bottom = 0.0
		
		# Настраиваем масштабирование фона на весь экран
		background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		
		# Приглушаем фон, чтобы он не перебивал игру (делаем полупрозрачным и темным)
		background_texture.modulate = Color(0.7, 0.7, 0.7, 0.6)  # Приглушенный и полупрозрачный
		
		background_canvas.add_child(background_texture)
		
		# Подключаемся к сигналу изменения размера окна
		get_tree().get_root().size_changed.connect(_on_window_size_changed)
		
		# Принудительно обновляем размер фона
		_update_background_size()
		
		print("GameManager: Глобальный фон настроен и применен")
	else:
		printerr("GameManager: Не удалось загрузить фоновую картинку")

# Обновляет размер фона при изменении размера окна
func _update_background_size() -> void:
	if background_texture:
		var window_size = get_tree().get_root().get_visible_rect().size
		background_texture.size = window_size
		print("GameManager: Обновлен размер фона: ", window_size)

# Обрабатывает изменение размера окна
func _on_window_size_changed() -> void:
	_update_background_size()

# Воспроизводит подходящую фоновую музыку для текущего уровня
func play_background_music_for_level(level_index: int) -> void:
	print("GameManager: Попытка запуска музыки для уровня ", level_index + 1)
	
	var music_path: String = ""
	
	# Определяем какую музыку играть (уровни 1-6 = summer, 7-12 = autumn)
	if level_index >= 0 and level_index < 6:  # Уровни 1-6 (индексы 0-5)
		music_path = summer_music_path
		print("GameManager: Выбрана летняя музыка")
	elif level_index >= 6 and level_index < 12:  # Уровни 7-12 (индексы 6-11)
		music_path = autumn_music_path
		print("GameManager: Выбрана осенняя музыка")
	else:
		print("GameManager: Нет музыки для уровня с индексом ", level_index)
		return
	
	# Если уже играет нужная музыка, не перезапускаем
	if current_music_track == music_path and background_music_player.playing:
		print("GameManager: Нужная музыка уже играет, не перезапускаем")
		return
	
	# Остановим текущую музыку если что-то играет
	if background_music_player.playing:
		print("GameManager: Останавливаем текущую музыку")
		background_music_player.stop()
	
	# Загружаем и воспроизводим новую музыку
	var music_stream = load(music_path)
	if music_stream is AudioStream:
		background_music_player.stream = music_stream
		
		# Подключаем сигнал для зацикливания музыки
		if not background_music_player.finished.is_connected(_on_background_music_finished):
			background_music_player.finished.connect(_on_background_music_finished)
		
		background_music_player.play()
		current_music_track = music_path
		print("GameManager: Запущена фоновая музыка: ", music_path)
	else:
		printerr("GameManager: Не удалось загрузить музыку: ", music_path)

# Останавливает фоновую музыку
func stop_background_music() -> void:
	if background_music_player and background_music_player.playing:
		background_music_player.stop()
		current_music_track = ""
		print("GameManager: Фоновая музыка остановлена")

# Обрабатывает окончание фоновой музыки и перезапускает её
func _on_background_music_finished() -> void:
	if background_music_player and not current_music_track.is_empty():
		print("GameManager: Перезапуск фоновой музыки")
		background_music_player.play()

# Возвращает список путей к уровням для меню выбора
func get_level_paths() -> Array[String]:
	return level_paths

# Устанавливает текущий уровень (для выбора конкретного уровня)
func set_current_level(index: int) -> void:
	if index >= 0 and index < level_paths.size():
		current_level_index = index
		print("Установлен текущий уровень: ", index + 1)
	else:
		printerr("Неверный индекс уровня: ", index)

# Загружает конкретный уровень по индексу (для меню выбора)
func load_specific_level(index: int) -> void:
	print("GameManager: Загрузка конкретного уровня %d" % (index + 1))
	load_level_by_index(index)

# Возвращает номер текущего уровня (1-based)
func get_current_level_number() -> int:
	return current_level_index + 1

# Показывает главное меню
func show_main_menu() -> void:
	# Останавливаем фоновую музыку
	if background_music_player and background_music_player.playing:
		background_music_player.stop()
		print("GameManager: Фоновая музыка остановлена")
	
	# Сбрасываем индекс текущего уровня
	current_level_index = -1
	
	# Скрываем HUD если он есть
	hide_hud()
	
	# Загружаем сцену главного меню
	print("GameManager: Попытка загрузки главного меню...")
	var error = get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
	if error == OK:
		print("GameManager: Главное меню загружено успешно!")
	else:
		printerr("GameManager: Ошибка при загрузке главного меню! Код ошибки: ", error)

# Скрывает HUD если он присутствует на сцене
func hide_hud() -> void:
	# Найдем все узлы HUD в текущей сцене
	var huds = get_tree().get_nodes_in_group("HUD")
	for hud in huds:
		if hud is CanvasLayer:
			hud.visible = false
			print("GameManager: HUD скрыт")
	
	# Дополнительно поищем по имени, если HUD не в группе
	var hud_node = get_tree().current_scene.find_child("HUD", true, false)
	if hud_node and hud_node is CanvasLayer:
		hud_node.visible = false
		print("GameManager: HUD скрыт по имени")

# Можно добавить другие функции, например, для возврата в главное меню,
# сохранения/загрузки прогресса и т.д. 
