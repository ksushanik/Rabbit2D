extends Node

# Список путей ко всем сценам уровней в игре
var level_paths: Array[String] = [
	"res://scenes/level_1.tscn",
	"res://scenes/level_2.tscn",
	"res://scenes/level_3.tscn",
	"res://scenes/level_4.tscn",
	"res://scenes/level_5.tscn",
	"res://scenes/level_6.tscn"
]

var current_level_index: int = -1


func _ready() -> void:
	# Начать с первого уровня при запуске игры (или с другого, если нужно)
	if current_level_index == -1:
		load_level_by_index(0)


func load_level_by_index(index: int) -> void:
	# Проверяем, является ли индекс допустимым
	if index < 0:
		printerr("Error: Invalid level index (negative): ", index)
		get_tree().quit()
		return
	
	# Проверяем, есть ли еще уровни
	if index >= level_paths.size():
		print("--- GAME COMPLETED! All levels finished. ---")
		# Здесь можно будет добавить переход на экран победы или в главное меню
		get_tree().quit() # Пока просто выходим из игры
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

# Можно добавить другие функции, например, для возврата в главное меню,
# сохранения/загрузки прогресса и т.д. 
