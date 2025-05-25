extends CharacterBody2D
class_name Fox

## Скрипт для лисы - врага кролика

# --- Экспортируемые переменные ---
@export var tile_size: int = 32
@export var fox_direction: Vector2i = Vector2i.LEFT # Направление, куда смотрит лиса

# --- Ссылки на узлы ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Состояние лисы ---
var grid_pos: Vector2i = Vector2i.ZERO
var danger_zone_pos: Vector2i = Vector2i.ZERO # Позиция опасной клетки перед лисой

# --- Инициализация ---
func _ready() -> void:
	# Устанавливаем начальную позицию
	grid_pos = world_to_grid(global_position)
	_calculate_danger_zone()
	
	# Запускаем анимацию ожидания в правильном направлении
	_play_idle_animation()

# Инициализация лисы (вызывается из Level.gd)
func initialize(new_tile_size: int) -> void:
	tile_size = new_tile_size

# Устанавливает позицию лисы в сетке
func set_grid_position(new_grid_pos: Vector2i) -> void:
	grid_pos = new_grid_pos
	global_position = grid_to_world(grid_pos)
	_calculate_danger_zone()

# Получает текущую позицию лисы в сетке
func get_grid_position() -> Vector2i:
	return grid_pos

# Получает позицию опасной зоны
func get_danger_zone_position() -> Vector2i:
	return danger_zone_pos

# Вычисляет позицию опасной клетки перед лисой
func _calculate_danger_zone() -> void:
	# Опасная зона находится в направлении, куда смотрит лиса
	danger_zone_pos = grid_pos + fox_direction

# Преобразует мировые координаты в координаты сетки
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / tile_size), floor(world_pos.y / tile_size))

# Преобразует координаты сетки в мировые координаты (центр клетки)
func grid_to_world(grid_pos_param: Vector2i) -> Vector2:
	return Vector2(grid_pos_param) * tile_size + Vector2(tile_size, tile_size) / 2.0

# Воспроизводит анимацию атаки
func play_attack_animation() -> void:
	if animated_sprite:
		var direction_name = _get_direction_name()
		animated_sprite.play("attack_" + direction_name)

# Воспроизводит анимацию ожидания
func play_idle_animation() -> void:
	_play_idle_animation()

# Внутренняя функция для воспроизведения анимации ожидания
func _play_idle_animation() -> void:
	if animated_sprite:
		var direction_name = _get_direction_name()
		animated_sprite.play("idle_" + direction_name)

# Получает название направления для анимаций
func _get_direction_name() -> String:
	if fox_direction == Vector2i.LEFT:
		return "left"
	elif fox_direction == Vector2i.RIGHT:
		return "right"
	elif fox_direction == Vector2i.UP:
		return "up"
	elif fox_direction == Vector2i.DOWN:
		return "down"
	else:
		return "left" # По умолчанию

# Проверяет, находится ли кролик в опасной зоне
func is_rabbit_in_danger_zone(rabbit_pos: Vector2i) -> bool:
	return rabbit_pos == danger_zone_pos 