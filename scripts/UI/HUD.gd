extends CanvasLayer

# Ссылка на узел Label для отображения счета
@onready var carrot_count_label: Label = $CarrotCountLabel 


# Функция для обновления текста в Label
# Вызывается через сигнал из Level.gd
func update_carrot_count(count: int):
	if carrot_count_label:
		carrot_count_label.text = "Морковки: %d" % count
	else:
		printerr("HUD.gd: Ссылка на CarrotCountLabel не найдена!") 