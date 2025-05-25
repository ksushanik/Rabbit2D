extends Node

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
		# Показываем экран завершения игры
		if game_over_scene:
			var game_over_instance = game_over_scene.instantiate()
			get_tree().root.add_child(game_over_instance)
		else:
			printerr("GameManager: Сцена game_over_scene не установлена!")
			get_tree().quit() # Выходим, если экрана победы нет
		return

	current_level_index = index
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
	# Перезапускаем текущий уровень по нажатию R
	if event.is_action_pressed("restart"):
		print("Restart action pressed, reloading level...")
		restart_current_level()
		# Помечаем событие как обработанное, чтобы другие узлы его не получили
		get_tree().root.set_input_as_handled()

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
	set_current_level(index)
	load_level_by_index(index)

# Возвращает номер текущего уровня (1-based)
func get_current_level_number() -> int:
	return current_level_index + 1

# Показывает главное меню
func show_main_menu() -> void:
	print("GameManager: Попытка загрузки главного меню...")
	var error = get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
	if error != OK:
		printerr("Ошибка загрузки главного меню. Код ошибки: ", error)
		print("GameManager: Fallback - загружаем первый уровень...")
		# Fallback - загружаем первый уровень
		load_level_by_index(0)
	else:
		print("GameManager: Главное меню загружено успешно!")

# Можно добавить другие функции, например, для возврата в главное меню,
# сохранения/загрузки прогресса и т.д. 
