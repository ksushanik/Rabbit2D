extends Control

## Меню настроек игры

# Настройки управления
@onready var pause_button: Button = $CenterContainer/VBoxContainer/ControlsSection/ControlsBackground/ControlsContent/PauseContainer/PauseButton
@onready var restart_button: Button = $CenterContainer/VBoxContainer/ControlsSection/ControlsBackground/ControlsContent/RestartContainer/RestartButton

# Настройки звука
@onready var sound_toggle: CheckBox = $CenterContainer/VBoxContainer/AudioSection/AudioBackground/AudioContent/SoundToggleContainer/SoundToggleButton
@onready var volume_slider: HSlider = $CenterContainer/VBoxContainer/AudioSection/AudioBackground/AudioContent/VolumeContainer/VolumeSlider
@onready var volume_label: Label = $CenterContainer/VBoxContainer/AudioSection/AudioBackground/AudioContent/VolumeContainer/VolumeLabel

# Навигация
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

# Переменные для настройки клавиш
var is_setting_key: bool = false
var setting_key_type: String = ""
var recently_set_key: bool = false

# Настройки игры (будут сохраняться в файл)
var game_settings: Dictionary = {
	"pause_key": KEY_ESCAPE,
	"restart_key": KEY_R,
	"sound_enabled": true,
	"master_volume": 1.0
}

func _ready() -> void:
	# Загружаем настройки
	load_settings()
	
	# Подключаем сигналы
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if sound_toggle:
		sound_toggle.toggled.connect(_on_sound_toggle_changed)
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Обновляем интерфейс
	update_ui()

func _input(event: InputEvent) -> void:
	if is_setting_key and event is InputEventKey and event.pressed:
		set_key(setting_key_type, event.keycode)
		is_setting_key = false
		setting_key_type = ""
		# Блокируем обработку этого события другими узлами
		get_tree().root.set_input_as_handled()
		return
	
	# Игнорируем ввод сразу после переопределения клавиши
	if recently_set_key and event is InputEventKey and event.pressed:
		get_tree().root.set_input_as_handled()
		return

func _on_pause_button_pressed() -> void:
	start_key_setting("pause")

func _on_restart_button_pressed() -> void:
	start_key_setting("restart")

func start_key_setting(key_type: String) -> void:
	is_setting_key = true
	setting_key_type = key_type
	
	if key_type == "pause":
		pause_button.text = "Press key..."
	elif key_type == "restart":
		restart_button.text = "Press key..."

func set_key(key_type: String, keycode: Key) -> void:
	if key_type == "pause":
		game_settings["pause_key"] = keycode
		pause_button.text = OS.get_keycode_string(keycode)
	elif key_type == "restart":
		game_settings["restart_key"] = keycode
		restart_button.text = OS.get_keycode_string(keycode)
	
	save_settings()
	
	# Устанавливаем флаг и сбрасываем его через короткую задержку
	recently_set_key = true
	var timer = Timer.new()
	timer.wait_time = 0.1  # 100ms задержка
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(func(): recently_set_key = false; timer.queue_free())
	timer.start()

func _on_sound_toggle_changed(button_pressed: bool) -> void:
	game_settings["sound_enabled"] = button_pressed
	
	# Применяем настройку к аудио шине
	var master_bus = AudioServer.get_bus_index("Master")
	if button_pressed:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(game_settings["master_volume"]))
	else:
		AudioServer.set_bus_volume_db(master_bus, -80.0)  # Практически отключаем звук
	
	save_settings()

func _on_volume_changed(value: float) -> void:
	game_settings["master_volume"] = value
	volume_label.text = "Volume: " + str(int(value * 100)) + "%"
	
	# Применяем громкость только если звук включен
	if game_settings["sound_enabled"]:
		var master_bus = AudioServer.get_bus_index("Master")
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(value))
	
	save_settings()

func _on_back_pressed() -> void:
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("hide_hud"):
		game_manager.hide_hud()
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")

func update_ui() -> void:
	# Обновляем кнопки управления
	if pause_button:
		pause_button.text = OS.get_keycode_string(game_settings["pause_key"])
	if restart_button:
		restart_button.text = OS.get_keycode_string(game_settings["restart_key"])
	
	# Обновляем настройки звука
	if sound_toggle:
		sound_toggle.button_pressed = game_settings["sound_enabled"]
	if volume_slider:
		volume_slider.value = game_settings["master_volume"]
	if volume_label:
		volume_label.text = "Volume: " + str(int(game_settings["master_volume"] * 100)) + "%"

func save_settings() -> void:
	var config = ConfigFile.new()
	
	# Сохраняем настройки в конфиг
	config.set_value("controls", "pause_key", game_settings["pause_key"])
	config.set_value("controls", "restart_key", game_settings["restart_key"])
	config.set_value("audio", "sound_enabled", game_settings["sound_enabled"])
	config.set_value("audio", "master_volume", game_settings["master_volume"])
	
	# Сохраняем в файл
	config.save("user://settings.cfg")
	
	# Уведомляем GameManager об изменении настроек
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("reload_game_settings"):
		game_manager.reload_game_settings()

func load_settings() -> void:
	var config = ConfigFile.new()
	
	# Загружаем конфиг файл
	var err = config.load("user://settings.cfg")
	if err != OK:
		# Если файл не найден, используем настройки по умолчанию
		return
	
	# Загружаем настройки
	game_settings["pause_key"] = config.get_value("controls", "pause_key", KEY_ESCAPE)
	game_settings["restart_key"] = config.get_value("controls", "restart_key", KEY_R)
	game_settings["sound_enabled"] = config.get_value("audio", "sound_enabled", true)
	game_settings["master_volume"] = config.get_value("audio", "master_volume", 1.0)
	
	# Применяем настройки звука
	apply_audio_settings()

func apply_audio_settings() -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	if game_settings["sound_enabled"]:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(game_settings["master_volume"]))
	else:
		AudioServer.set_bus_volume_db(master_bus, -80.0)

# Статический метод для получения настроек из других скриптов
static func get_game_settings() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err != OK:
		# Возвращаем настройки по умолчанию
		return {
			"pause_key": KEY_ESCAPE,
			"restart_key": KEY_R,
			"sound_enabled": true,
			"master_volume": 1.0
		}
	
	return {
		"pause_key": config.get_value("controls", "pause_key", KEY_ESCAPE),
		"restart_key": config.get_value("controls", "restart_key", KEY_R),
		"sound_enabled": config.get_value("audio", "sound_enabled", true),
		"master_volume": config.get_value("audio", "master_volume", 1.0)
	} 