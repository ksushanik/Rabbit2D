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
# Время бездействия, после которого кролик становится несчастным (в секундах)
@export var idle_timeout: float = 10.0

# Текущая позиция в сетке
var grid_pos: Vector2i = Vector2i.ZERO
var is_moving: bool = false
# Флаг для отслеживания столкновения
var is_colliding: bool = false
# Флаг для отслеживания состояния несчастного кролика
var is_sad: bool = false
# Таймер бездействия
var idle_timer: float = 0.0

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

# Плееры для звуков
var _move_sound_player: AudioStreamPlayer = null
var _collision_sound_player: AudioStreamPlayer = null

func _ready() -> void:
	_setup_sound_players()
	_setup_sprite()
	
	# Включаем обработку процесса для таймера бездействия
	set_process(true)

func _setup_sound_players() -> void:
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

func _setup_sprite() -> void:
	if sprite is AnimatedSprite2D:
		sprite.visible = true
		
		var required_anims = ["idle_down", "idle_up", "idle_left", "idle_right", 
			"move_down", "move_up", "move_left", "move_right",
			"collision_down", "collision_up", "collision_left", "collision_right",
			"unhappy_down", "unhappy_up", "unhappy_left", "unhappy_right"]
		var missing_anims = []
		for anim in required_anims:
			if not sprite.sprite_frames.has_animation(anim):
				missing_anims.append(anim)
		
		if missing_anims.size() > 0:
			printerr("Отсутствуют анимации: ", missing_anims)
		
		play_animation("idle_down")
		
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)

func initialize(level_tile_size: int) -> void:
	tile_size = level_tile_size

func set_grid_position(new_grid_pos: Vector2i) -> void:
	grid_pos = new_grid_pos
	position = Vector2(new_grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0

# Скрывает кролика (например, когда его съела лиса)
func hide_rabbit() -> void:
	if sprite:
		sprite.visible = false

func show_rabbit() -> void:
	if sprite:
		sprite.visible = true

func animate_move(target_world_position: Vector2, duration: float, will_collide: bool = false) -> void:
	if is_moving:
		return

	# Сбрасываем таймер бездействия и состояние несчастного кролика
	idle_timer = 0.0
	if is_sad:
		_reset_sad_state()

	var move_direction = (target_world_position - position).normalized()
	var direction_name = "down"
	
	if abs(move_direction.x) > abs(move_direction.y):
		current_direction = Vector2i.RIGHT if move_direction.x > 0 else Vector2i.LEFT
		direction_name = "right" if move_direction.x > 0 else "left"
	else:
		current_direction = Vector2i.DOWN if move_direction.y > 0 else Vector2i.UP
		direction_name = "down" if move_direction.y > 0 else "up"
	
	play_animation("move_" + direction_name)
	
	if is_instance_valid(_move_sound_player) and not _move_sound_player.playing:
		_move_sound_player.play()

	is_moving = true
	is_colliding = will_collide
	
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_world_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_tween_finished)

func play_animation(anim_name: String) -> void:
	if sprite is AnimatedSprite2D:
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
		else:
			push_error("Анимация не найдена: " + anim_name)
			if sprite.sprite_frames.has_animation("idle_down"):
				sprite.play("idle_down")
			elif sprite.sprite_frames.has_animation("move_down"):
				sprite.play("move_down")

func _on_tween_finished() -> void:
	is_moving = false
	
	if is_colliding:
		var dir_name = DIRECTION_TO_ANIMATION.get(current_direction, "down")
		var collision_anim = "collision_" + dir_name
		play_animation(collision_anim)
		
		if is_instance_valid(_collision_sound_player) and not _collision_sound_player.playing:
			_collision_sound_player.play()
	else:
		var dir_name = DIRECTION_TO_ANIMATION.get(current_direction, "down") 
		var idle_anim = "idle_" + dir_name
		play_animation(idle_anim)
		emit_signal("move_finished")

func _on_animation_finished() -> void:
	if sprite.animation.begins_with("fall_into_pit_"):
		return
		
	if sprite.animation.begins_with("collision_"):
		var direction_part = sprite.animation.split("_")[1]
		
		var idle_anim
		if direction_part == "left" or direction_part == "right":
			var dir_name = DIRECTION_TO_ANIMATION.get(current_direction, "down")
			idle_anim = "idle_" + dir_name
		else:
			idle_anim = "idle_" + direction_part
		
		play_animation(idle_anim)
		is_colliding = false
		emit_signal("move_finished")
	
	# Если анимация unhappy_ закончилась, продолжаем показывать её
	elif sprite.animation.begins_with("unhappy_") and is_sad:
		sprite.play(sprite.animation)  # Перезапускаем ту же анимацию

# Обрабатываем таймер бездействия
func _process(delta: float) -> void:
	# Если кролик движется или сталкивается, сбрасываем таймер
	if is_moving or is_colliding:
		idle_timer = 0.0
		if is_sad:
			_reset_sad_state()
		return
	
	# Увеличиваем таймер бездействия
	idle_timer += delta
	
	# Если прошло достаточно времени и кролик еще не несчастный
	if idle_timer >= idle_timeout and not is_sad:
		_set_sad_state()

# Устанавливает состояние "несчастный кролик"
func _set_sad_state() -> void:
	is_sad = true
	
	# Определяем текущее направление для анимации
	var dir_name = DIRECTION_TO_ANIMATION.get(current_direction, "down")
	
	# Проверяем, есть ли специальная анимация для несчастного кролика
	var unhappy_anim = "unhappy_" + dir_name
	if sprite and sprite.sprite_frames.has_animation(unhappy_anim):
		sprite.play(unhappy_anim)
	else:
		# Если специальной анимации нет, используем обычную idle с измененным цветом
		var idle_anim = "idle_" + dir_name
		sprite.play(idle_anim)
		sprite.modulate = Color(0.7, 0.7, 1.0)  # Голубоватый оттенок для грусти
	
	print("Кролик стал несчастным после ", idle_timeout, " секунд бездействия")

# Сбрасывает состояние "несчастный кролик"
func _reset_sad_state() -> void:
	if is_sad:
		is_sad = false
		sprite.modulate = Color.WHITE  # Возвращаем обычный цвет
		
		# Возвращаемся к обычной анимации
		var dir_name = DIRECTION_TO_ANIMATION.get(current_direction, "down")
		var idle_anim = "idle_" + dir_name
		play_animation(idle_anim)
		
		print("Кролик снова в обычном состоянии")

# Сбрасывает таймер бездействия (вызывается из Level.gd при вводе пользователя)
func reset_idle_timer() -> void:
	idle_timer = 0.0
	if is_sad:
		_reset_sad_state()
