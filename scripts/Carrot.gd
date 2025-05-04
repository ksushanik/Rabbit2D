class_name Carrot
extends Node2D

## Скрипт для управления поведением и анимацией Морковки.

# Сигнал, информирующий Level об окончании анимации движения морковки.
signal move_finished

# Размер тайла, устанавливается из Level.gd при инициализации.
var tile_size: int = 64

# Длительность анимации скольжения при запугивании
@export var scare_move_duration: float = 0.25 
# Длительность анимации поедания
@export var eat_duration: float = 0.15

# Текущая позиция морковки в координатах сетки.
var grid_pos: Vector2i = Vector2i.ZERO
# Флаг, указывающий, движется ли морковка в данный момент (анимируется).
var is_moving: bool = false

# Ссылка на узел спрайта для удобства.
@onready var sprite: Sprite2D = $Sprite2D


# Инициализация объекта из Level.gd
func initialize(level_tile_size: int) -> void:
	tile_size = level_tile_size


# Мгновенно устанавливает позицию морковки на указанную клетку сетки.
func set_grid_position(new_grid_pos: Vector2i) -> void:
	grid_pos = new_grid_pos
	position = Vector2(new_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0

# Возвращает текущую позицию в сетке
func get_grid_position() -> Vector2i:
	return grid_pos


# Анимирует плавное перемещение морковки в указанную мировую позицию.
# level - ссылка на Level.gd для вызова update_carrot_position
func animate_move(target_world_position: Vector2, duration: float, level: Node) -> void:
	if is_moving:
		return

	is_moving = true
	var old_grid_pos: Vector2i = grid_pos # Запоминаем старую позицию перед анимацией
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_world_position, duration).set_trans(Tween.TRANS_LINEAR)
	# Используем bind для передачи дополнительных аргументов в колбэк
	tween.finished.connect(_on_tween_finished.bind(old_grid_pos, level))


# Вызывается автоматически по завершении анимации Tween.
func _on_tween_finished(old_pos: Vector2i, level: Node) -> void:
	is_moving = false
	# Обновляем логическую позицию ПОСЛЕ завершения анимации
	var new_grid_pos: Vector2i = Vector2i(floor(position.x / tile_size), floor(position.y / tile_size))
	if new_grid_pos != old_pos:
		grid_pos = new_grid_pos # Обновляем позицию в самой морковке
		# Сообщаем уровню о смене позиции
		if is_instance_valid(level) and level.has_method("update_carrot_position"):
			level.update_carrot_position(self, old_pos, new_grid_pos)
		else:
			printerr("Level или метод update_carrot_position не найдены из _on_tween_finished!")

	emit_signal("move_finished") # Сообщаем Level, что движение завершено


# Функция запускает скольжение напуганной морковки.
# final_grid_pos - конечная точка, рассчитанная в Level.gd
# level - ссылка на Level.gd для вызова animate_move
func scare_and_slide(final_grid_pos: Vector2i, level: Node) -> void:
	if is_moving: # Нельзя напугать уже скользящую морковку
		return

	# Если морковка вообще должна сдвинуться (сравниваем с текущей позицией)
	if final_grid_pos != grid_pos:
		print("Морковка %s скользит из %s в %s" % [name, grid_pos, final_grid_pos])
		var target_world_pos: Vector2 = Vector2(final_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0
		animate_move(target_world_pos, scare_move_duration, level) # Передаем level для колбэка
	else:
		# Если морковка не может сдвинуться (конечная точка совпадает с текущей), 
		# все равно нужно сообщить Level, что ее "обработка" завершена.
		# print("Морковка %s не может сдвинуться (уже в конечной точке %s)" % [name, grid_pos]) # DEBUG
		emit_signal("move_finished")


# Функция "поедания" морковки.
func eat() -> void:
	# Можно добавить анимацию исчезновения (например, scale или modulate alpha)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ZERO, eat_duration).set_trans(Tween.TRANS_QUAD)
	# После анимации удаляем морковку со сцены
	tween.finished.connect(queue_free)


func _ready() -> void:
	pass # Инициализация tile_size и grid_pos происходит из Level.gd
