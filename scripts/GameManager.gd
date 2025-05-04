extends Node

# Список путей ко всем сценам уровней в игре
var level_paths = [
	"res://scenes/level_1.tscn",
	"res://scenes/level_2.tscn",
	"res://scenes/level_3.tscn",
	"res://scenes/level_4.tscn",
	"res://scenes/level_5.tscn",
	"res://scenes/level_6.tscn"
]

var current_level_index = -1


func _ready():
	# Начать с первого уровня при запуске игры (или с другого, если нужно)
	if current_level_index == -1:
		load_level_by_index(0)


func load_level_by_index(index: int):
	if index < 0 or index >= level_paths.size():
		print("Error: Invalid level index: ", index)
		# Возможно, здесь стоит загрузить главное меню или экран победы
		get_tree().quit() # Пока просто выйдем из игры
		return

	current_level_index = index
	# Загружаем сцену уровня
	get_tree().change_scene_to_file(level_paths[current_level_index])


func load_next_level():
	load_level_by_index(current_level_index + 1)


func restart_current_level():
	load_level_by_index(current_level_index)

# Можно добавить другие функции, например, для возврата в главное меню,
# сохранения/загрузки прогресса и т.д. 
