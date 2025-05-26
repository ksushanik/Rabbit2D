extends CanvasLayer

@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $CenterContainer/VBoxContainer/MenuButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/Title
@onready var message_label: Label = $CenterContainer/VBoxContainer/Message
@onready var background: TextureRect = $Background

# Режим экрана: true - игра пройдена успешно, false - игра проиграна
var victory_mode: bool = false
var victory_sound_player: AudioStreamPlayer = null
var game_over_sound_player: AudioStreamPlayer = null

func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка RestartButton не найдена!")
	
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	else:
		printerr("GameOverScreen: Кнопка MenuButton не найдена!")
	
	# Настраиваем текст в зависимости от режима
	_setup_screen_text()
	
	# Если это экран победы, добавляем праздничные эффекты
	if victory_mode:
		_setup_victory_effects()
		_play_victory_sound()
	else:
		_play_game_over_sound()
		
	# Устанавливаем фокус с задержкой
	call_deferred("_set_initial_focus")
		
	get_tree().paused = true

# Добавляет праздничные эффекты для экрана победы
func _setup_victory_effects() -> void:
	# Делаем фон ярче
	if background:
		background.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Полная яркость
	
	# Используем золотистый цвет для заголовка VICTORY
	if title_label:
		title_label.modulate = Color(1.0, 0.8, 0.2, 1.0)  # Золотистый цвет

# Настраивает текст экрана в зависимости от режима
func _setup_screen_text() -> void:
	if title_label:
		if victory_mode:
			title_label.text = "VICTORY!"
		else:
			title_label.text = "GAME OVER"
	
	# Скрываем сообщение с поздравлением в любом случае
	if message_label:
		message_label.visible = false

# Устанавливает режим экрана (победа/поражение)
func set_victory_mode(is_victory: bool) -> void:
	victory_mode = is_victory
	if is_inside_tree():
		_setup_screen_text()

func _set_initial_focus() -> void:
	if restart_button:
		restart_button.grab_focus()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
	call_deferred("queue_free")

func _on_menu_button_pressed() -> void:
	get_tree().paused = false
	
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("show_main_menu"):
		game_manager.show_main_menu()
	else:
		if game_manager and game_manager.has_method("hide_hud"):
			game_manager.hide_hud()
		get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
		
	call_deferred("queue_free")

# Воспроизводит звук победы
func _play_victory_sound() -> void:
	victory_sound_player = AudioStreamPlayer.new()
	victory_sound_player.name = "VictorySoundPlayer"
	
	var sound = load("res://assets/Sounds/game-win.wav") as AudioStream
	if sound:
		victory_sound_player.stream = sound
		victory_sound_player.volume_db = -5.0
		add_child(victory_sound_player)
		victory_sound_player.play()
	else:
		printerr("GameOverScreen: Не удалось загрузить звук победы")

# Воспроизводит звук проигрыша
func _play_game_over_sound() -> void:
	game_over_sound_player = AudioStreamPlayer.new()
	game_over_sound_player.name = "GameOverSoundPlayer"
	
	var sound = load("res://assets/Sounds/gameover.mp3") as AudioStream
	if sound:
		game_over_sound_player.stream = sound
		game_over_sound_player.volume_db = -8.0
		add_child(game_over_sound_player)
		game_over_sound_player.play()
	else:
		printerr("GameOverScreen: Не удалось загрузить звук проигрыша") 
