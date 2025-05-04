class_name Rabbit
extends Node2D

## Скрипт для управления поведением и анимацией Кролика.

# Сигнал, информирующий Level об окончании анимации движения кролика.
signal move_finished

# Размер тайла, устанавливается из Level.gd при инициализации.
var tile_size: int = 64

# Длительность анимации скольжения кролика.
@export var move_duration: float = 0.3

# Текущая позиция кролика в координатах сетки.
var grid_pos: Vector2i = Vector2i.ZERO
# Флаг, указывающий, движется ли кролик в данный момент (анимируется).
var is_moving: bool = false

# Ссылка на узел спрайта для удобства.
# Убедись, что узел спрайта в сцене Rabbit.tscn называется Sprite2D
@onready var sprite: Sprite2D = $Sprite2D

# Путь к звуку движения
@export var move_sound_path: String = ""

# Ссылка на программно созданный плеер
var _move_sound_player: AudioStreamPlayer = null


func _ready() -> void:
	# Создаем плеер для звука движения
	if not move_sound_path.is_empty():
		var sound = load(move_sound_path)
		if sound is AudioStream:
			_move_sound_player = AudioStreamPlayer.new()
			_move_sound_player.stream = sound
			_move_sound_player.name = "MoveSoundPlayer"
			_move_sound_player.volume_db = -6.0 # Можно настроить громкость здесь
			# _move_sound_player.bus = &"SFX" # Можно раскомментировать, если шина SFX создана
			add_child(_move_sound_player)
		else:
			printerr("Rabbit.gd: Не удалось загрузить звук движения: ", move_sound_path)


# Инициализация объекта из Level.gd
func initialize(level_tile_size: int) -> void:
	tile_size = level_tile_size


# Мгновенно устанавливает позицию кролика на указанную клетку сетки.
func set_grid_position(new_grid_pos: Vector2i) -> void:
	grid_pos = new_grid_pos
	# Устанавливаем мировую позицию в центр клетки
	position = Vector2(new_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0


# Анимирует плавное перемещение кролика в указанную мировую позицию.
func animate_move(target_world_position: Vector2, duration: float) -> void:
	if is_moving:
		return

	# Воспроизводим звук движения
	if is_instance_valid(_move_sound_player) and not _move_sound_player.playing:
		_move_sound_player.play()
	
	is_moving = true
	var tween: Tween = create_tween()
	# Используем easing для более приятного движения
	tween.tween_property(self, "position", target_world_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Подписываемся на завершение анимации
	tween.finished.connect(_on_tween_finished)


# Вызывается автоматически по завершении анимации Tween.
func _on_tween_finished() -> void:
	is_moving = false
	emit_signal("move_finished")


# Инициализация (если потребуется в будущем)
# func _ready():
# 	pass
