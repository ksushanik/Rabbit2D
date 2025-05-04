class_name Carrot
extends Node2D

## Скрипт для управления поведением и анимацией Морковки.

# Сигнал, информирующий Level об окончании анимации движения морковки.
signal move_finished

# Экспортируемая переменная для легкой настройки размера тайла из редактора.
# @export var tile_size: int = 64
var tile_size: int = 64 # Теперь устанавливается через initialize

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

# Ссылка на скрипт уровня (устанавливается при необходимости)
var level_script = null # Возможно, стоит убрать, если не нужна глобально


# Инициализация объекта из Level.gd
func initialize(level_tile_size: int):
	tile_size = level_tile_size


# Мгновенно устанавливает позицию морковки на указанную клетку сетки.
func set_grid_position(new_grid_pos: Vector2i):
	grid_pos = new_grid_pos
	position = Vector2(new_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0


# Анимирует плавное перемещение морковки в указанную мировую позицию.
# level - ссылка на Level.gd для вызова update_carrot_position
func animate_move(target_world_position: Vector2, duration: float, level):
	if is_moving:
		return

	is_moving = true
	var old_grid_pos = grid_pos # Запоминаем старую позицию перед анимацией
	var tween = create_tween()
	tween.tween_property(self, "position", target_world_position, duration).set_trans(Tween.TRANS_LINEAR)
	# Используем bind для передачи дополнительных аргументов в колбэк
	tween.finished.connect(_on_tween_finished.bind(old_grid_pos, level))


# Вызывается автоматически по завершении анимации Tween.
func _on_tween_finished(old_pos: Vector2i, level):
	is_moving = false
	# Обновляем логическую позицию ПОСЛЕ завершения анимации
	var new_grid_pos = Vector2i(floor(position.x / tile_size), floor(position.y / tile_size))
	if new_grid_pos != old_pos:
		grid_pos = new_grid_pos # Обновляем позицию в самой морковке
		# Сообщаем уровню о смене позиции
		if level and level.has_method("update_carrot_position"):
			level.update_carrot_position(self, old_pos, new_grid_pos)
		else:
			printerr("Level или метод update_carrot_position не найдены из _on_tween_finished!")

	emit_signal("move_finished") # Сообщаем Level, что движение завершено


# Функция запускает скольжение напуганной морковки.
# final_grid_pos - конечная точка, рассчитанная в Level.gd
# level - ссылка на Level.gd для вызова animate_move
func scare_and_slide(final_grid_pos: Vector2i, level):
	if is_moving: # Нельзя напугать уже скользящую морковку
		return

	# Ссылка на level больше не нужна для расчета, но нужна для animate_move
	# level_script = level # Можно убрать, если не используется больше нигде

	# Если морковка вообще должна сдвинуться (сравниваем с текущей позицией)
	if final_grid_pos != grid_pos:
		print("Морковка %s скользит из %s в %s" % [name, grid_pos, final_grid_pos])
		var target_world_pos = Vector2(final_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0
		animate_move(target_world_pos, scare_move_duration, level) # Передаем level для колбэка
	else:
		# Если морковка не может сдвинуться (конечная точка совпадает с текущей), 
		# все равно нужно сообщить Level, что ее "обработка" завершена.
		print("Морковка %s не может сдвинуться (уже в конечной точке %s)" % [name, grid_pos]) # DEBUG
		emit_signal("move_finished")


# Функция "поедания" морковки.
func eat():
	# Можно добавить анимацию исчезновения (например, scale или modulate alpha)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ZERO, eat_duration).set_trans(Tween.TRANS_QUAD) # Используем константу
	# После анимации удаляем морковку со сцены
	tween.finished.connect(queue_free)

# --- Вспомогательные функции (пока не используются) ---

# Пример: проверка, можно ли войти в клетку (используется level_script.is_cell_vacant_for_carrot)
# func can_move_to(target_pos: Vector2i):
# 	if level_script:
# 		return level_script.is_cell_vacant_for_carrot(target_pos)
# 	return false # Не можем проверить без ссылки на уровень 

func _ready():
	# Попытка получить размер тайла из родительского Level, если возможно
	# Это не очень надежно, лучше передавать явно.
	var level_node = get_parent().get_parent() # Предполагаем Carrot -> CarrotsContainer -> Level
	if level_node and level_node.has_meta("tile_size"):
		tile_size = level_node.get_meta("tile_size", 64)
	elif owner and owner.has_method("get_tile_size"): # Если сцена Carrot инстанциирована через скрипт
		tile_size = owner.get_tile_size()
	# else используем значение по умолчанию
	
	# Начальная установка позиции через set_grid_position теперь выполняется только из Level.gd
	# Этот блок УДАЛЕН, так как начальная позиция устанавливается из Level.gd
	# if not Engine.is_editor_hint(): # Не делаем в редакторе
	# 	set_grid_position(Vector2i(floor(position.x / tile_size), floor(position.y / tile_size)))
