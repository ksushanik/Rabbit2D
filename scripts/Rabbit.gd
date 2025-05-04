class_name Rabbit
extends Node2D

## Скрипт для управления поведением и анимацией Кролика.

# Сигнал, информирующий Level об окончании анимации движения кролика.
signal move_finished

# Экспортируемая переменная для легкой настройки размера тайла.
# Должна устанавливаться из Level.gd при инициализации.
# @export var tile_size: int = 64 
var tile_size: int = 64 # Теперь устанавливается через initialize

# Длительность анимации скольжения кролика.
@export var move_duration: float = 0.3

# Текущая позиция кролика в координатах сетки.
var grid_pos: Vector2i = Vector2i.ZERO
# Флаг, указывающий, движется ли кролик в данный момент (анимируется).
var is_moving: bool = false

# Ссылка на узел спрайта для удобства.
# Убедись, что узел спрайта в сцене Rabbit.tscn называется Sprite2D
@onready var sprite: Sprite2D = $Sprite2D


# Инициализация объекта из Level.gd
func initialize(level_tile_size: int):
	tile_size = level_tile_size


# Мгновенно устанавливает позицию кролика на указанную клетку сетки.
func set_grid_position(new_grid_pos: Vector2i):
	grid_pos = new_grid_pos
	position = Vector2(new_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0


# Анимирует плавное перемещение кролика в указанную мировую позицию.
func animate_move(target_world_position: Vector2, duration: float):
	if is_moving:
		return

	is_moving = true
	var tween = create_tween()
	# Используем easing для более приятного движения
	tween.tween_property(self, "position", target_world_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_tween_finished)


# Вызывается автоматически по завершении анимации Tween.
func _on_tween_finished():
	is_moving = false
	emit_signal("move_finished")


# Инициализация (если потребуется в будущем)
# func _ready():
# 	pass
