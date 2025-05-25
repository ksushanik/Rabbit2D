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
# Длительность анимации исчезновения под землю
@export var disappear_duration: float = 0.3
# Длительность анимации появления из-под земли
@export var appear_duration: float = 0.3

# Текущая позиция морковки в координатах сетки.
var grid_pos: Vector2i = Vector2i.ZERO
# Флаг, указывающий, движется ли морковка в данный момент (анимируется).
var is_moving: bool = false

# Ссылка на узел анимированного спрайта для удобства.
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Экспортируемые переменные ---
@export var move_sound_path: String = "" # <-- ДОБАВЛЕНО: Путь к звуку движения
@export var eat_sound_path: String = "" # <-- ДОБАВЛЕНО: Путь к звуку поедания

# --- Переменные ---
var _move_sound_player: AudioStreamPlayer = null # <-- ДОБАВЛЕНО
var _eat_sound_player: AudioStreamPlayer = null # <-- ДОБАВЛЕНО


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
		# Воспроизводим звук движения
		if is_instance_valid(_move_sound_player) and not _move_sound_player.playing:
			_move_sound_player.play()
		

		var target_world_pos: Vector2 = Vector2(final_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0
		animate_move(target_world_pos, scare_move_duration, level) # Передаем level для колбэка
	else:
		# Если морковка не может сдвинуться (конечная точка совпадает с текущей), 
		# все равно нужно сообщить Level, что ее "обработка" завершена.

		emit_signal("move_finished")


# Функция "поедания" морковки.
func eat() -> void:
	# Воспроизводим звук поедания
	if is_instance_valid(_eat_sound_player) and not _eat_sound_player.playing:
		_eat_sound_player.play()
		
	# Запускаем анимацию исчезновения
	var tween: Tween = create_tween()
	tween.tween_property(animated_sprite, "scale", Vector2.ZERO, eat_duration).set_trans(Tween.TRANS_QUAD)
	# После анимации удаляем морковку со сцены
	tween.finished.connect(queue_free)


# Проигрывает анимацию покоя
func play_idle_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		else:
			printerr("Анимация 'idle' не найдена в SpriteFrames")


# Проигрывает анимацию исчезновения под землю (мышка утаскивает)
func play_disappear_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("disappear"):
			animated_sprite.play("disappear")
		else:
			printerr("Анимация 'disappear' не найдена в SpriteFrames")


# Проигрывает анимацию появления из-под земли (мышка возвращает)
func play_appear_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("appear"):
			animated_sprite.play("appear")
		else:
			print("Анимация 'appear' не найдена в SpriteFrames")


# Обновленная функция запугивания с анимацией исчезновения/появления
func scare_and_slide_animated(final_grid_pos: Vector2i, level: Node) -> void:
	if is_moving: # Нельзя напугать уже скользящую морковку
		return

	# Если морковка вообще должна сдвинуться (сравниваем с текущей позицией)
	if final_grid_pos != grid_pos:
		print("Морковка %s начинает анимированное скольжение из %s в %s" % [name, grid_pos, final_grid_pos])
		
		# Воспроизводим звук движения
		if is_instance_valid(_move_sound_player) and not _move_sound_player.playing:
			_move_sound_player.play()
		
		is_moving = true
		
		# 1. Проигрываем анимацию исчезновения
		play_disappear_animation()
		
		# 2. Ждем завершения анимации исчезновения, затем телепортируемся
		if animated_sprite:
			# Подключаемся к сигналу завершения анимации
			if not animated_sprite.animation_finished.is_connected(_on_disappear_finished):
				animated_sprite.animation_finished.connect(_on_disappear_finished.bind(final_grid_pos, level))
	else:
		# Если морковка не может сдвинуться, все равно сообщаем об окончании
		emit_signal("move_finished")


# Вызывается после завершения анимации исчезновения
func _on_disappear_finished(final_grid_pos: Vector2i, level: Node) -> void:
	# Отключаем сигнал, чтобы избежать повторных вызовов
	if animated_sprite and animated_sprite.animation_finished.is_connected(_on_disappear_finished):
		animated_sprite.animation_finished.disconnect(_on_disappear_finished)
	
	# Мгновенно телепортируем морковку в конечную позицию
	var old_grid_pos: Vector2i = grid_pos
	grid_pos = final_grid_pos
	position = Vector2(final_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0
	
	# Обновляем позицию в уровне
	if is_instance_valid(level) and level.has_method("update_carrot_position"):
		level.update_carrot_position(self, old_grid_pos, final_grid_pos)
	
	# Проигрываем анимацию появления
	play_appear_animation()
	
	# Подключаемся к сигналу завершения анимации появления
	if animated_sprite and not animated_sprite.animation_finished.is_connected(_on_appear_finished):
		animated_sprite.animation_finished.connect(_on_appear_finished)


# Вызывается после завершения анимации появления
func _on_appear_finished() -> void:
	# Отключаем сигнал
	if animated_sprite and animated_sprite.animation_finished.is_connected(_on_appear_finished):
		animated_sprite.animation_finished.disconnect(_on_appear_finished)
	
	# Переходим в анимацию покоя
	play_idle_animation()
	
	# Сообщаем уровню о завершении движения
	is_moving = false
	emit_signal("move_finished")


func _ready() -> void:
	_setup_sound_players()
	call_deferred("play_idle_animation")

func _setup_sound_players() -> void:
	if not move_sound_path.is_empty():
		var sound = load(move_sound_path)
		if sound is AudioStream:
			_move_sound_player = AudioStreamPlayer.new()
			_move_sound_player.stream = sound
			_move_sound_player.name = "MoveSoundPlayer"
			_move_sound_player.volume_db = -8.0
			add_child(_move_sound_player)
		else:
			printerr("Carrot.gd: Не удалось загрузить звук движения: ", move_sound_path)
	
	if not eat_sound_path.is_empty():
		var sound = load(eat_sound_path)
		if sound is AudioStream:
			_eat_sound_player = AudioStreamPlayer.new()
			_eat_sound_player.stream = sound
			_eat_sound_player.name = "EatSoundPlayer"
			_eat_sound_player.volume_db = -3.0
			add_child(_eat_sound_player)
		else:
			printerr("Carrot.gd: Не удалось загрузить звук поедания: ", eat_sound_path)
