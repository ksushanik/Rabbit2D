extends CanvasLayer

# Ссылка на узел Label для отображения счета
@onready var carrot_count_label: Label = $CarrotCountLabel
@onready var pause_button: Button = $PauseButton

func _ready() -> void:
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
	else:
		printerr("HUD.gd: Кнопка PauseButton не найдена!")

# Функция для обновления текста в Label
# Вызывается через сигнал из Level.gd
func update_carrot_count(count: int) -> void:
	if carrot_count_label:
		carrot_count_label.text = "Морковки: %d" % count
	else:
		printerr("HUD.gd: Ссылка на CarrotCountLabel не найдена!")

func _on_pause_button_pressed() -> void:
	# Найдем Level и вызовем функцию показа меню паузы
	var level = get_tree().current_scene
	if level and level.has_method("_show_pause_menu"):
		level._show_pause_menu()
	else:
		printerr("HUD.gd: Не удалось найти Level или метод _show_pause_menu!") 