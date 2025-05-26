extends CanvasLayer

# Ссылка на узел Label для отображения счета
@onready var carrot_count_label: Label = $CarrotCountLabel
@onready var pause_button: Button = $PauseButton

func _ready() -> void:
	# Добавляем себя в группу HUD для легкого поиска
	add_to_group("HUD")
	
	# Применяем пиксельную тему к лейблу с морковками
	_setup_pixel_font()
	
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
	else:
		printerr("HUD.gd: Кнопка PauseButton не найдена!")

# Настраивает пиксельный шрифт для лейбла
func _setup_pixel_font() -> void:
	if carrot_count_label:
		# Загружаем пиксельный шрифт напрямую
		var pixel_font = load("res://assets/Fonts/minecraft_0.ttf") as FontFile
		if pixel_font:
			carrot_count_label.add_theme_font_override("font", pixel_font)
			carrot_count_label.add_theme_font_size_override("font_size", 16)
			carrot_count_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 1.0))  # Оранжевый цвет как на скриншоте
			print("HUD.gd: Применен пиксельный шрифт minecraft к лейблу морковок")
		else:
			printerr("HUD.gd: Не удалось загрузить пиксельный шрифт minecraft_0.ttf")

# Функция для обновления текста в Label
# Вызывается через сигнал из Level.gd
func update_carrot_count(count: int) -> void:
	if carrot_count_label:
		carrot_count_label.text = "Carrots: %d" % count
	else:
		printerr("HUD.gd: Ссылка на CarrotCountLabel не найдена!")

func _on_pause_button_pressed() -> void:
	# Найдем Level и вызовем функцию показа меню паузы
	var level = get_tree().current_scene
	if level and level.has_method("_show_pause_menu"):
		level._show_pause_menu()
	else:
		printerr("HUD.gd: Не удалось найти Level или метод _show_pause_menu!") 