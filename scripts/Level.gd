extends Node2D

## Скрипт для управления основной логикой уровня.

# Экспортируемая переменная для легкой настройки размера тайла из редактора.
@export var tile_size: int = 64
# Экспортируемая переменная для ссылки на сцену следующего уровня.
# @export var next_level_scene: PackedScene = null

# --- Ссылки на узлы (теперь через @export) ---
@export var ground_layer: TileMap = null # <-- Изменено на @export
@export var carrots_container: Node2D = null # <-- Изменено на @export
@export var rabbit: Rabbit = null # <-- Изменено на @export и тип Rabbit

# --- Состояние игры --- 
enum State { PLAYER_TURN, PROCESSING_MOVE }
var current_state: State = State.PLAYER_TURN

# --- Отслеживание морковок --- 
# Словарь для быстрого доступа к морковкам по их координатам сетки.
# Ключ: Vector2i (позиция), Значение: Node (узел Carrot)
var active_carrots: Dictionary = {}
var carrots_remaining: int = 0
var moving_carrots_count: int = 0 # Счетчик морковок, которые сейчас анимируются
var last_rabbit_direction: Vector2i = Vector2i.ZERO # Запоминаем последнее направление кролика
var last_move_calculation_result: Dictionary = {} # <-- ДОБАВЛЕНО: Сохраняем результат расчета хода


# --- Инициализация уровня --- 
func _ready():
	# 1. Проверка ссылок на узлы
	if not ground_layer:
		printerr("Level.gd: Узел GroundLayer не найден!")
		return
	if not rabbit:
		printerr("Level.gd: Узел Rabbit не найден!")
		return
	if not carrots_container:
		printerr("Level.gd: Узел CarrotsContainer не найден!")
		return
	
	# 2. Инициализация Кролика
	# Получаем стартовую позицию кролика из его положения в редакторе
	var rabbit_start_grid_pos = world_to_grid(rabbit.global_position) # Используем global_position
	# Передаем размер тайла и устанавливаем позицию
	if rabbit.has_method("initialize"):
		rabbit.initialize(tile_size)
	else:
		printerr("У кролика нет метода initialize!")
	if rabbit.has_method("set_grid_position"):
		rabbit.set_grid_position(rabbit_start_grid_pos)
	else:
		printerr("У кролика нет метода set_grid_position!")
	
	print("Стартовая позиция кролика (grid): ", rabbit_start_grid_pos)
	# Подписываемся на сигнал окончания его движения
	if not rabbit.is_connected("move_finished", Callable(self, "_on_rabbit_move_finished")):
		rabbit.move_finished.connect(_on_rabbit_move_finished)
	else:
		print("Сигнал rabbit.move_finished уже был подключен.")

	# 3. Инициализация Морковок
	active_carrots.clear()
	# --- DEBUG START ---
	if not carrots_container:
		printerr("Level.gd _ready: Узел CarrotsContainer НЕ НАЙДЕН! Проверьте имя '$CarrotsContainer' в сцене.")
		return # Дальше нет смысла идти
	print(">>> DEBUG: Начинаем поиск морковок в '%s'. Количество детей: %d" % [carrots_container.name, carrots_container.get_child_count()])
	# --- DEBUG END ---
	for carrot_node in carrots_container.get_children():
		# --- DEBUG START ---
		print(">>> DEBUG: Проверяем узел: '%s', Тип: %s, Имеет set_grid_position?: %s" % [carrot_node.name, carrot_node.get_class(), carrot_node.has_method("set_grid_position")])
		# --- DEBUG END ---
		if carrot_node is Node2D and carrot_node.has_method("set_grid_position") and carrot_node.has_method("initialize"):
			# Используем global_position для корректного расчета изначальной клетки
			var carrot_grid_pos = world_to_grid(carrot_node.global_position) # <-- Используем global_position
			# Передаем размер тайла и устанавливаем позицию
			carrot_node.initialize(tile_size)
			carrot_node.set_grid_position(carrot_grid_pos)
			active_carrots[carrot_grid_pos] = carrot_node
			# Подписываемся на сигнал окончания движения морковки (если еще не подписаны)
			if not carrot_node.is_connected("move_finished", Callable(self, "_on_carrot_move_finished")):
				carrot_node.move_finished.connect(_on_carrot_move_finished)
			else:
				# Если метод initialize или set_grid_position отсутствует
				printerr("Ошибка инициализации узла '%s'. Проверьте скрипт и тип узла." % carrot_node.name)
	
	carrots_remaining = active_carrots.size()
	print("Уровень начат. Морковок: ", carrots_remaining)

	# 4. Установка начального состояния
	current_state = State.PLAYER_TURN


# --- Обработка ввода игрока --- 
func _unhandled_input(event: InputEvent):
	# Принимаем ввод только если сейчас ход игрока и ничего не движется
	if current_state != State.PLAYER_TURN:
		return

	var direction = Vector2i.ZERO
	if event.is_action_pressed("move_right"): 
		direction = Vector2i.RIGHT
	elif event.is_action_pressed("move_left"): 
		direction = Vector2i.LEFT
	elif event.is_action_pressed("move_down"): 
		direction = Vector2i.DOWN
	elif event.is_action_pressed("move_up"): 
		direction = Vector2i.UP

	if direction != Vector2i.ZERO:
		start_rabbit_move(direction)


# --- Логика хода --- 
func start_rabbit_move(direction: Vector2i):
	if rabbit.is_moving: # Не позволяем двигаться, если кролик еще анимируется
		return 
		
	current_state = State.PROCESSING_MOVE # Переключаем состояние - обработка хода
	last_rabbit_direction = direction # Сохраняем направление
	print("Кролик начинает движение: ", direction)

	# Рассчитываем конечную точку скольжения кролика и СОХРАНЯЕМ РЕЗУЛЬТАТ
	var start_pos = rabbit.grid_pos
	last_move_calculation_result = calculate_slide_destination(start_pos, direction, rabbit) # <-- ИЗМЕНЕНО
	var final_pos = last_move_calculation_result["final_pos"] # <-- ИЗМЕНЕНО

	# Если кролик вообще должен сдвинуться
	if final_pos != start_pos:
		var target_world_pos = grid_to_world(final_pos)
		# Запускаем анимацию кролика. Мы не обновляем rabbit.grid_pos здесь,
		# это произойдет в _on_rabbit_move_finished после анимации.
		# Используем длительность, заданную в скрипте кролика
		if rabbit.has_method("animate_move"):
			rabbit.animate_move(target_world_pos, rabbit.move_duration)
		else:
			printerr("У кролика нет метода animate_move!")
	else:
		# Кролик не может сдвинуться (сразу уперся), возвращаем ход игроку
		print("Кролик не может сдвинуться.")
		current_state = State.PLAYER_TURN


# Вызывается, когда анимация движения Кролика завершена (сигнал от Rabbit.gd)
func _on_rabbit_move_finished():
	# 1. Обновляем логическую позицию кролика 
	var final_grid_pos = world_to_grid(rabbit.position)
	if not is_instance_valid(rabbit):
		printerr("_on_rabbit_move_finished: Экземпляр кролика недействителен!")
		return
	rabbit.grid_pos = final_grid_pos
	print("Кролик завершил движение в: ", final_grid_pos)
	
	# 2. Проверка "Поедания"
	var eaten_carrot_this_turn = false
	if last_move_calculation_result.get("will_eat_carrot", false):
		var carrot_to_eat = last_move_calculation_result.get("stopped_by_carrot", null)
		if carrot_to_eat and is_instance_valid(carrot_to_eat):
			print("Кролик съел морковку в: ", carrot_to_eat.grid_pos)
			eat_carrot(carrot_to_eat) # eat_carrot теперь только удаляет морковь и уменьшает счетчик
			eaten_carrot_this_turn = true
			# НЕ проверяем победу сразу после еды здесь
		else:
			printerr("Ошибка: will_eat_carrot=true, но stopped_by_carrot недействителен!")

	# --- ПРОВЕРКА ПОБЕДЫ --- 
	# Происходит ПОСЛЕ обновления позиции и возможного поедания
	if check_win_condition() and is_exit(final_grid_pos):
		trigger_next_level() # Вызываем переход на следующий уровень
		return # Выходим, так как уровень завершен
	# ------------------------

	# 3. Проверка "Запугивания" (ТОЛЬКО если морковка не была съедена и не победа)
	if not eaten_carrot_this_turn:
		_process_scared_carrots(final_grid_pos)
	else:
		# Если морковка была съедена, ход сразу заканчивается (не пугаем), возвращаем ход игроку
		print("Морковка съедена, ход завершен.")
		current_state = State.PLAYER_TURN


# Обрабатывает логику запугивания морковок после хода кролика
func _process_scared_carrots(rabbit_final_pos: Vector2i):
	var scared_carrots_list: Array[Node] = []
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var check_pos = rabbit_final_pos + offset
		var scared_carrot = get_carrot_at(check_pos)

		# Проверяем, что морковка существует, валидна и не движется
		if scared_carrot and is_instance_valid(scared_carrot) and not scared_carrot.is_moving:
			# Проверяем на блокировку запугивания частичной стеной
			if not _is_move_blocked_by_partial_wall(rabbit_final_pos, check_pos):
				scared_carrots_list.append(scared_carrot)
			#else:
				# print("Scaring морковки в %s заблокировано стеной." % check_pos) # DEBUG
		
	# Запуск движения напуганных морковок
	moving_carrots_count = scared_carrots_list.size()
	print("Напугано морковок: ", moving_carrots_count)

	if moving_carrots_count > 0:
		for carrot_node in scared_carrots_list:
			var direction_away = (carrot_node.grid_pos - rabbit_final_pos)
			print("Морковка в ", carrot_node.grid_pos, " пугается и движется в ", direction_away)
			
			# Рассчитываем конечную точку скольжения ЗДЕСЬ
			var calc_result = calculate_slide_destination(carrot_node.grid_pos, direction_away, carrot_node)
			var final_carrot_pos = calc_result["final_pos"]
			
			if carrot_node.has_method("scare_and_slide"):
				# Передаем конечную точку в морковку
				carrot_node.scare_and_slide(final_carrot_pos, self)
			else:
				printerr("Ошибка: У узла морковки %s отсутствует метод scare_and_slide!" % carrot_node.name)
	else:
		# Никто не напуган, можно сразу вернуть ход игроку (победа уже проверена ранее)
		current_state = State.PLAYER_TURN


# Вызывается, когда анимация движения Морковки завершена (сигнал от Carrot.gd)
func _on_carrot_move_finished():
	if current_state == State.PROCESSING_MOVE:
		moving_carrots_count -= 1
		print("Морковка завершила движение. Осталось движущихся: ", moving_carrots_count)
		if moving_carrots_count <= 0:
			# Все напуганные морковки остановились
			print("Все напуганные морковки остановились.")
			# НЕ ПРОВЕРЯЕМ ПОБЕДУ ЗДЕСЬ. Победа проверяется только в _on_rabbit_move_finished.
			# Возвращаем ход игроку
			current_state = State.PLAYER_TURN


# --- Вспомогательные функции --- 

# Преобразует мировые координаты в координаты сетки
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / tile_size), floor(world_pos.y / tile_size))

# Преобразует координаты сетки в мировые координаты (центр клетки)
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0

# Получает данные тайла по координатам сетки
func get_tile_data(grid_pos: Vector2i) -> TileData:
	# Используем get_cell_tile_data для получения данных тайла на указанных координатах.
	# Уровень 0 - стандартный для TileMap.
	return ground_layer.get_cell_tile_data(0, grid_pos)

# Проверяет, блокируется ли движение из from_pos в to_pos частичной стеной.
func _is_move_blocked_by_partial_wall(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	var direction = to_pos - from_pos # Определяем направление движения
	if direction.length_squared() != 1: # Убедимся, что это соседние клетки
		printerr("Ошибка в _is_move_blocked_by_partial_wall: Позиции не соседние!")
		return true # Считаем заблокированным на всякий случай

	# Проверяем стену, блокирующую ВЫХОД из from_pos
	var blocks_leaving = get_partial_wall_blocks(from_pos)
	if not blocks_leaving.is_empty():
		if direction == Vector2i.RIGHT and blocks_leaving.has("right"): return true
		if direction == Vector2i.LEFT and blocks_leaving.has("left"): return true
		if direction == Vector2i.DOWN and blocks_leaving.has("down"): return true
		if direction == Vector2i.UP and blocks_leaving.has("up"): return true

	# Проверяем стену, блокирующую ВХОД в to_pos
	var blocks_entering = get_partial_wall_blocks(to_pos)
	if not blocks_entering.is_empty():
		if direction == Vector2i.RIGHT and blocks_entering.has("left"): return true
		if direction == Vector2i.LEFT and blocks_entering.has("right"): return true
		if direction == Vector2i.DOWN and blocks_entering.has("up"): return true
		if direction == Vector2i.UP and blocks_entering.has("down"): return true
		
	return false # Движение не заблокировано частичной стеной

# Проверяет, является ли клетка "сплошной стеной" (имеет физический коллайдер)
func is_full_wall(grid_pos: Vector2i) -> bool:
	var tile_data: TileData = get_tile_data(grid_pos)
	if tile_data:
		# Проверяем наличие полигонов столкновений на физическом слое 0 у тайла
		return tile_data.get_collision_polygons_count(0) > 0
	return false # Пустая клетка - не сплошная стена

# Проверяет, является ли клетка выходом (Норой) по Custom Data
func is_exit(grid_pos: Vector2i) -> bool:
	var tile_data: TileData = get_tile_data(grid_pos)
	if tile_data:
		# Ищем данные по имени "type" (с маленькой буквы)
		var type_data = tile_data.get_custom_data("type") 
		# print("is_exit: Проверка клетки %s. Получены данные тайла. Custom data 'type' = %s" % [grid_pos, type_data]) # DEBUG
		return type_data == "exit"
	else:
		# print("is_exit: Проверка клетки %s. Данные тайла не найдены." % grid_pos) # DEBUG
		pass # Добавлено для исправления ошибки линтера
	return false

# Получает данные о блокировках частичной стены из Custom Data
func get_partial_wall_blocks(grid_pos: Vector2i) -> Dictionary:
	var tile_data: TileData = get_tile_data(grid_pos)
	if tile_data:
		var blocks = tile_data.get_custom_data("blocks")
		if blocks is Dictionary:
			return blocks
	return {} # Возвращаем пустой словарь, если данных нет или тайл не найден

# Возвращает узел морковки в указанной клетке, если он есть
func get_carrot_at(grid_pos: Vector2i) -> Node:
	return active_carrots.get(grid_pos, null)

# Обновляет позицию морковки в словаре active_carrots.
# Вызывается из Carrot.gd ПОСЛЕ завершения анимации движения.
func update_carrot_position(carrot_node: Node, old_grid_pos: Vector2i, new_grid_pos: Vector2i):
	# Удаляем морковку из старой позиции (если она там была)
	if active_carrots.has(old_grid_pos) and active_carrots[old_grid_pos] == carrot_node:
		active_carrots.erase(old_grid_pos)
	else:
		# Это может произойти, если начальная позиция была вне карты или была ошибка
		print("Предупреждение: Попытка обновить морковку %s из неверной старой позиции %s" % [carrot_node.name, old_grid_pos])
	
	# Добавляем морковку по новой позиции (даже если она совпадает со старой, на всякий случай)
	active_carrots[new_grid_pos] = carrot_node
	# print("Позиция морковки %s обновлена: %s -> %s" % [carrot_node.name, old_grid_pos, new_grid_pos]) # DEBUG


# Проверяет, свободна ли клетка для движения КРОЛИКА
# (Нет стены/выхода И нет морковки)
func is_cell_vacant_for_rabbit(grid_pos: Vector2i) -> bool:
	if is_full_wall(grid_pos):
		return false
	if active_carrots.has(grid_pos):
		return false
	return true

# Проверяет, свободна ли клетка для движения МОРКОВКИ
# (Нет стены/выхода И нет ДРУГОЙ морковки)
func is_cell_vacant_for_carrot(grid_pos: Vector2i, asking_carrot: Node) -> bool:
	if is_full_wall(grid_pos):
		return false
	var carrot_at_pos = get_carrot_at(grid_pos)
	if carrot_at_pos != null and carrot_at_pos != asking_carrot: # Если там есть морковка, и это не та, что спрашивает
		return false
	return true

# Рассчитывает конечную точку скольжения для объекта (кролика или морковки).
# Возвращает Dictionary: { 
#   "final_pos": Vector2i,           # Конечная позиция объекта
#   "stopped_by_carrot": Node,       # Узел морковки, перед которой остановились (или null)
#   "will_eat_carrot": bool          # True, если кролик остановился прямо перед морковкой для поедания
# }
func calculate_slide_destination(start_grid_pos: Vector2i, direction: Vector2i, moving_object: Node) -> Dictionary:
	var current_pos = start_grid_pos
	var is_rabbit = (moving_object == rabbit)

	while true:
		var next_pos = current_pos + direction

		# --- Шаг 1: Проверка стен МЕЖДУ current_pos и next_pos ---
		if _is_move_blocked_by_partial_wall(current_pos, next_pos):
			break

		# --- Шаг 2: Проверка СОДЕРЖИМОГО клетки next_pos ---
		# 2.1 Сплошная стена?
		if is_full_wall(next_pos):
			break

		# 2.2 Морковка?
		var carrot_in_next_pos = get_carrot_at(next_pos)
		if is_rabbit:
			if carrot_in_next_pos: # Кролик наткнулся на морковку
				return {"final_pos": current_pos, "stopped_by_carrot": carrot_in_next_pos, "will_eat_carrot": true}
		else: # Морковка наткнулась на ДРУГУЮ морковку
			if carrot_in_next_pos != null and carrot_in_next_pos != moving_object:
				break

		# --- Шаг 3: Проверка на остановку на выходе (если все морковки собраны) ---
		if is_rabbit and is_exit(next_pos) and carrots_remaining <= 0:
			# Все морковки собраны, и кролик входит в клетку выхода.
			# Останавливаемся здесь, чтобы вызвать переход уровня.
			current_pos = next_pos # Перемещаемся НА выход
			break # И завершаем скольжение

		# --- Шаг 4: Если все чисто и не выход с победой, ПЕРЕМЕЩАЕМСЯ --- 
		current_pos = next_pos
		
		# Аварийный выход
		if abs(current_pos.x) > 1000 or abs(current_pos.y) > 1000:
			printerr("Возможен бесконечный цикл в calculate_slide_destination? Позиция: ", current_pos, " Старт: ", start_grid_pos, " Направление: ", direction)
			break

	# Цикл прерван (стена, другая морковка, частичная стена) - поедания нет.
	# Возвращаем только конечную позицию и факт столкновения с морковкой (если было).
	return {"final_pos": current_pos, "stopped_by_carrot": null, "will_eat_carrot": false}


# Обработка поедания морковки
func eat_carrot(carrot_node: Node):
	if not is_instance_valid(carrot_node):
		printerr("eat_carrot: Попытка съесть невалидную морковку!")
		return
	
	# Получаем grid_pos из самого узла морковки
	var carrot_pos: Vector2i
	if carrot_node.has_method("get_grid_position"):
		carrot_pos = carrot_node.get_grid_position()
	else:
		# Пытаемся вычислить из мировой позиции как запасной вариант
		if carrot_node is Node2D:
			carrot_pos = world_to_grid(carrot_node.global_position)
			print("Предупреждение: У морковки нет get_grid_position(), позиция вычислена из global_position.")
		else:
			printerr("eat_carrot: Невозможно получить grid_pos для морковки!")
			return

	if active_carrots.has(carrot_pos):
		active_carrots.erase(carrot_pos) # Удаляем из нашего отслеживания
		carrots_remaining -= 1
		# Узел морковки сам удалит себя после анимации 'eat'
		if carrot_node.has_method("eat"):
			carrot_node.eat() # Запускаем анимацию и удаление самой морковки
		else:
			printerr("Ошибка: У морковки %s нет метода eat()!" % carrot_node.name)
			carrot_node.queue_free() # Удаляем принудительно, если нет метода
		print("Морковка съедена. Осталось: ", carrots_remaining)
	else:
		printerr("Попытка съесть морковку, которой нет в active_carrots по позиции %s: %s" % [carrot_pos, carrot_node.name])


# --- Условия победы и управление уровнем --- 

# Проверяет, все ли морковки съедены.
# Возвращает true, если морковок не осталось, иначе false.
func check_win_condition() -> bool:
	return carrots_remaining <= 0

# Переход на следующий уровень (вызывается из _on_rabbit_move_finished, когда условия выполнены)
func trigger_next_level():
	print("ПОБЕДА! Кролик на выходе, все морковки собраны.")
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.load_next_level()
	else:
		printerr("Не удалось найти GameManager в Autoload!")
		get_tree().quit() # Аварийный выход

# Перезапуск текущего уровня
func restart_level():
	get_tree().reload_current_scene()

# Можно добавить обработку нажатия R для перезапуска
# func _process(delta):
# 	if Input.is_action_just_pressed("restart"): # Нужно добавить действие "restart" в Input Map
# 		restart_level() 
