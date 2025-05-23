class_name Rabbit
extends Node2D

## Скрипт для управления поведением и анимацией Кролика.

# Сигналы
signal move_finished

# Размер тайла
var tile_size: int = 64

# Длительность анимации скольжения кролика.
@export var move_duration: float = 0.3
# Длительность анимации столкновения
@export var collision_duration: float = 0.3

# Текущая позиция в сетке
var grid_pos: Vector2i = Vector2i.ZERO
var is_moving: bool = false
# Флаг для отслеживания столкновения
var is_colliding: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite2D

# Текущее направление
var current_direction: Vector2i = Vector2i.DOWN

# Константы для направлений
const DIRECTION_TO_ANIMATION = {
	Vector2i.RIGHT: "right",
	Vector2i.LEFT: "left", 
	Vector2i.DOWN: "down",
	Vector2i.UP: "up"
}

# Звук движения
@export var move_sound_path: String = ""
# Звук столкновения
@export var collision_sound_path: String = ""
# Звук падения в яму
@export var pit_fall_sound_path: String = ""

# Плееры для звуков
var _move_sound_player: AudioStreamPlayer = null
var _collision_sound_player: AudioStreamPlayer = null
var _pit_fall_sound_player: AudioStreamPlayer = null


func _ready() -> void:
	# Создаем плеер для звука движения
	if not move_sound_path.is_empty():
		var sound = load(move_sound_path)
		if sound is AudioStream:
			_move_sound_player = AudioStreamPlayer.new()
			_move_sound_player.stream = sound
			_move_sound_player.name = "MoveSoundPlayer"
			_move_sound_player.volume_db = -6.0
			add_child(_move_sound_player)
		else:
			printerr("Rabbit.gd: Не удалось загрузить звук движения: ", move_sound_path)

	# Создаем плеер для звука столкновения
	if not collision_sound_path.is_empty():
		var sound = load(collision_sound_path)
		if sound is AudioStream:
			_collision_sound_player = AudioStreamPlayer.new()
			_collision_sound_player.stream = sound
			_collision_sound_player.name = "CollisionSoundPlayer"
			_collision_sound_player.volume_db = -3.0
			add_child(_collision_sound_player)
		else:
			printerr("Rabbit.gd: Не удалось загрузить звук столкновения: ", collision_sound_path)

	# Создаем плеер для звука падения в яму
	if not pit_fall_sound_path.is_empty():
		var sound = load(pit_fall_sound_path)
		if sound is AudioStream:
			_pit_fall_sound_player = AudioStreamPlayer.new()
			_pit_fall_sound_player.stream = sound
			_pit_fall_sound_player.name = "PitFallSoundPlayer"
			_pit_fall_sound_player.volume_db = -3.0
			add_child(_pit_fall_sound_player)
		else:
			printerr("Rabbit.gd: Не удалось загрузить звук падения в яму: ", pit_fall_sound_path)

	# Начальная анимация
	if sprite is AnimatedSprite2D:
		# Перечисляем все доступные анимации для отладки
		print("Доступные анимации: ", sprite.sprite_frames.get_animation_names())
		# Проверяем, есть ли нужные анимации
		var required_anims = ["idle_down", "idle_up", "idle_left", "idle_right", 
			"move_down", "move_up", "move_left", "move_right",
			"collision_down", "collision_up", "collision_left", "collision_right"]
		var missing_anims = []
		for anim in required_anims:
			if not sprite.sprite_frames.has_animation(anim):
				missing_anims.append(anim)
		
		if missing_anims.size() > 0:
			printerr("Отсутствуют анимации: ", missing_anims)
		
		# Запускаем начальную анимацию
		play_animation("idle_down")
		
		# Подключаем сигнал завершения анимации
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			print("Подключаем сигнал animation_finished")
			sprite.animation_finished.connect(_on_animation_finished)
		else:
			print("Сигнал animation_finished уже подключен")


func initialize(level_tile_size: int) -> void:
	tile_size = level_tile_size


func set_grid_position(new_grid_pos: Vector2i) -> void:
	grid_pos = new_grid_pos
	position = Vector2(new_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0


# Проверка для определения нужно ли играть анимацию столкновения
# Level.gd должен передавать этот флаг при вызове animate_move
func animate_move(target_world_position: Vector2, duration: float, will_collide: bool = false) -> void:
	if is_moving:
		return

	# Определяем направление движения
	var move_direction = (target_world_position - position).normalized()
	var direction_name = "down" # По умолчанию
	
	# Определяем направление по вектору движения
	if abs(move_direction.x) > abs(move_direction.y):
		# Горизонтальное движение
		current_direction = Vector2i.RIGHT if move_direction.x > 0 else Vector2i.LEFT
		direction_name = "right" if move_direction.x > 0 else "left"
	else:
		# Вертикальное движение
		current_direction = Vector2i.DOWN if move_direction.y > 0 else Vector2i.UP
		direction_name = "down" if move_direction.y > 0 else "up"
	
	# Воспроизводим анимацию движения
	play_animation("move_" + direction_name)
	
	# Воспроизводим звук движения
	if is_instance_valid(_move_sound_player) and not _move_sound_player.playing:
		_move_sound_player.play()

	is_moving = true
	# Сохраняем информацию о том, будет ли столкновение в конце движения
	is_colliding = will_collide
	
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_world_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_tween_finished)


# Метод для проигрывания анимации с улучшенной отладкой
func play_animation(anim_name: String) -> void:
	if sprite is AnimatedSprite2D:
		print("Запуск анимации: " + anim_name)
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
		else:
			push_error("Анимация не найдена: " + anim_name)
			# Аварийный вариант - используем дефолтную анимацию
			if sprite.sprite_frames.has_animation("idle_down"):
				sprite.play("idle_down")
				print("Вместо этого включена idle_down")
			elif sprite.sprite_frames.has_animation("move_down"):
				sprite.play("move_down")
				print("Вместо этого включена move_down")


# Вызывается при окончании движения (tween закончился)
func _on_tween_finished() -> void:
	is_moving = false
	
	# Если было столкновение - проигрываем анимацию столкновения
	if is_colliding:
		var dir_name = DIRECTION_TO_ANIMATION.get(current_direction, "down")
		var collision_anim = "collision_" + dir_name
		print("Запускаю анимацию столкновения: " + collision_anim)
		play_animation(collision_anim)
		
		# Воспроизводим звук столкновения
		if is_instance_valid(_collision_sound_player) and not _collision_sound_player.playing:
			_collision_sound_player.play()
	else:
		# Если не было столкновения - переходим в idle
		var dir_name = DIRECTION_TO_ANIMATION.get(current_direction, "down") 
		var idle_anim = "idle_" + dir_name
		print("Запускаю анимацию покоя: " + idle_anim)
		play_animation(idle_anim)
		emit_signal("move_finished")


# Обработчик завершения анимации
func _on_animation_finished() -> void:
	# Если закончилась анимация столкновения
	if sprite.animation.begins_with("collision_"):
		print("Завершилась анимация столкновения: ", sprite.animation)
		# Явно получаем имя направления из имени анимации
		var direction_part = sprite.animation.split("_")[1]
		
		# Проверяем направление и корректируем его, если необходимо
		# Когда кролик ударяется о стену, он должен смотреть в ту же сторону
		var idle_anim
		if direction_part == "left" or direction_part == "right":
			# Используем сохраненное направление вместо извлечения из имени анимации
			var dir_name = DIRECTION_TO_ANIMATION.get(current_direction, "down")
			idle_anim = "idle_" + dir_name
			print("Корректирую направление после столкновения, используем направление: " + dir_name)
		else:
			# Для up/down используем направление из названия анимации
			idle_anim = "idle_" + direction_part
		
		print("После столкновения играем: " + idle_anim)
		play_animation(idle_anim)
		
		# Сбрасываем флаг столкновения
		is_colliding = false
		
		# Сообщаем об окончании движения
		emit_signal("move_finished")


# Анимация падения кролика в яму
func fall_into_pit() -> void:
	print("Кролик проваливается в яму!")
	is_moving = true # Блокируем управление
	
	# Проигрываем звук падения в яму, если есть
	if is_instance_valid(_pit_fall_sound_player) and not _pit_fall_sound_player.playing:
		_pit_fall_sound_player.play()
		
	# Анимация вращения и уменьшения
	var tween = create_tween()
	tween.set_parallel(true) # Параллельные анимации
	
	# Вращение
	tween.tween_property(self, "rotation", PI * 2, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Уменьшение размера (исчезновение в яме)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Небольшое затемнение
	tween.tween_property(sprite, "modulate", Color(0.5, 0.5, 0.5), 0.5)
	
	# Небольшой сдвиг вниз (эффект проваливания)
	tween.tween_property(sprite, "position", sprite.position + Vector2(0, 15), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
