extends Node2D

## Скрипт для управления основной логикой уровня.

# Экспортируемая переменная для легкой настройки размера тайла из редактора.
@export var tile_size: int = 32
# Экспортируемая переменная для ссылки на сцену следующего уровня.
# @export var next_level_scene: PackedScene = null

# --- Ссылки на узлы (теперь через @export) ---
@export var ground_layer: TileMap = null # <-- Изменено на @export
@export var carrots_container: Node2D = null # <-- Изменено на @export
@export var rabbit: Rabbit = null # <-- Изменено на @export и тип Rabbit
@export var hud_scene: PackedScene = null # <-- ДОБАВЛЕНО: Ссылка на сцену HUD

# --- Ресурсы ---
@export var level_complete_sound_path: String = "" # <-- ВОССТАНОВЛЕНО

# --- Сигналы ---
# Отправляется при изменении количества морковок
signal carrots_updated(count: int) # <-- ДОБАВЛЕНО

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

# --- Внутренние переменные ---
var _level_complete_player: AudioStreamPlayer = null # <-- ВОССТАНОВЛЕНО


# --- Инициализация уровня --- 
func _ready() -> void:
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
	
	# --- ДОБАВЛЕНО: Проверка и настройка Camera2D ---
	var camera: Camera2D = find_child("*Camera2D", true, false) as Camera2D # Ищем существующую камеру
	if not is_instance_valid(camera):
		print("Camera2D не найдена, создаем программно.")
		camera = Camera2D.new()
		camera.name = "ProgrammaticCamera"
		add_child(camera)
		# Центрируем камеру по тайлмапу
		var map_rect = ground_layer.get_used_rect()
		var map_center_local = map_rect.get_center()
		camera.position = ground_layer.map_to_local(map_center_local)
		camera.zoom = Vector2(2.0, 2.0) # <-- Устанавливаем зум 2.0 для увеличения масштаба (компенсация уменьшенных тайлов)
	else:
		print("Найдена существующая Camera2D.")
	# Если камера уже есть, принудительно устанавливаем зум
	camera.zoom = Vector2(2.0, 2.0) # Увеличиваем масштаб вдвое
	
	# Активируем камеру (делаем текущей)
	camera.enabled = true 
	# ------------------------------------------------

	# 2. Инстанцирование и подключение HUD
	if hud_scene:
		var hud_instance: CanvasLayer = hud_scene.instantiate() as CanvasLayer
		if hud_instance:
			add_child(hud_instance)
			# Подключаем сигнал этого уровня к функции обновления HUD
			if hud_instance.has_method("update_carrot_count"):
				# Используем Callable для более надежного подключения
				var callable_update = Callable(hud_instance, "update_carrot_count")
				if not carrots_updated.is_connected(callable_update):
					carrots_updated.connect(callable_update)
			else:
				printerr("Ошибка: Экземпляр HUD не имеет метода update_carrot_count!")
		else:
			printerr("Ошибка: Не удалось инстанциировать HUD как CanvasLayer!")
	else:
		print("Предупреждение: Сцена HUD не установлена в Level.gd")
	# --------------------------------------------------

	# 3. Инициализация Кролика
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
	var callable_rabbit_finished = Callable(self, "_on_rabbit_move_finished")
	if not rabbit.move_finished.is_connected(callable_rabbit_finished):
		rabbit.move_finished.connect(callable_rabbit_finished)
	else:
		print("Сигнал rabbit.move_finished уже был подключен.")

	# 4. Инициализация Морковок
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
			var callable_carrot_finished = Callable(self, "_on_carrot_move_finished")
			if not carrot_node.move_finished.is_connected(callable_carrot_finished):
				carrot_node.move_finished.connect(callable_carrot_finished)
			else:
				# Если метод initialize или set_grid_position отсутствует
				printerr("Ошибка инициализации узла '%s'. Проверьте скрипт и тип узла." % carrot_node.name)
	
	carrots_remaining = active_carrots.size()
	print("Уровень начат. Морковок: ", carrots_remaining)
	carrots_updated.emit(carrots_remaining) # <-- ДОБАВЛЕНО: Отправляем начальное значение в HUD

	# 5. Создание плеера для звука завершения
	if not level_complete_sound_path.is_empty():
		var sound = load(level_complete_sound_path)
		if sound is AudioStream:
			_level_complete_player = AudioStreamPlayer.new()
			_level_complete_player.stream = sound
			_level_complete_player.name = "LevelCompleteSoundPlayer"
			# _level_complete_player.bus = &"SFX" # Можно раскомментировать
			add_child(_level_complete_player)
		else:
			printerr("Level.gd: Не удалось загрузить звук завершения уровня: ", level_complete_sound_path)
	# ----------------------------------------

	# 6. Установка начального состояния
	current_state = State.PLAYER_TURN


# --- Обработка ввода игрока --- 
func _unhandled_input(event: InputEvent) -> void:
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
		get_tree().root.set_input_as_handled() # Помечаем ввод как обработанный здесь


# --- Логика хода --- 
func start_rabbit_move(direction: Vector2i) -> void:
	if rabbit.is_moving: # Не позволяем двигаться, если кролик еще анимируется
		return 
		
	current_state = State.PROCESSING_MOVE # Переключаем состояние - обработка хода
	last_rabbit_direction = direction # Сохраняем направление
	print("Кролик начинает движение: ", direction)

	# Рассчитываем конечную точку скольжения кролика и СОХРАНЯЕМ РЕЗУЛЬТАТ
	var start_pos = rabbit.grid_pos
	last_move_calculation_result = calculate_slide_destination(start_pos, direction, rabbit) # <-- ИЗМЕНЕНО
	var final_pos = last_move_calculation_result["final_position"] # <-- ИЗМЕНЕНО

	# Если кролик вообще должен сдвинуться
	if final_pos != start_pos:
		var target_world_pos = grid_to_world(final_pos)
		# Определяем, будет ли столкновение со стеной или другим препятствием
		var will_collide = last_move_calculation_result.get("will_collide", false)
		# Запускаем анимацию, передавая флаг столкновения
		rabbit.animate_move(target_world_pos, rabbit.move_duration, will_collide)
	else:
		# Кролик не может сдвинуться (сразу уперся), возвращаем ход игроку
		print("Кролик не может сдвинуться.")
		current_state = State.PLAYER_TURN


# Вызывается, когда анимация движения Кролика завершена
func _on_rabbit_move_finished() -> void:
	if not is_instance_valid(rabbit):
		printerr("_on_rabbit_move_finished: Экземпляр кролика недействителен!")
		return
		
	var final_grid_pos: Vector2i = world_to_grid(rabbit.position)
	rabbit.grid_pos = final_grid_pos
	
	var eaten_carrot_this_turn: bool = false
	var adjacent_scared_by_eating: bool = false # Флаг для испуганных соседей

	if last_move_calculation_result.get("will_eat_carrot", false):
		var carrot_to_eat: Node = last_move_calculation_result.get("carrot", null)
		if is_instance_valid(carrot_to_eat):
			# Вызываем eat_carrot и сохраняем результат (были ли напуганы соседи)
			adjacent_scared_by_eating = eat_carrot(carrot_to_eat) 
			eaten_carrot_this_turn = true # Сам факт поедания произошел
		else:
			printerr("Ошибка: will_eat_carrot=true, но carrot недействителен!")

	# Проверка победы
	if check_win_condition() and is_exit(final_grid_pos):
		trigger_next_level()
		return

	# Запугивание морковок (если кролик НЕ ел) 
	# ИЛИ Завершение хода (если кролик ел, но соседи НЕ испугались)
	if not eaten_carrot_this_turn:
		# Кролик не ел, пугаем морковки рядом с КРОЛИКОМ
		_process_scared_carrots(final_grid_pos)
	else:
		# Кролик СЪЕЛ морковку
		if not adjacent_scared_by_eating:
			# Кролик съел, но соседи НЕ были напуганы -> завершаем ход
			print("Морковка съедена (без испуга соседей), ход завершен.")
			current_state = State.PLAYER_TURN
		# else: 
			# Кролик съел И соседи БЫЛИ напуганы.
			# Ничего не делаем здесь, current_state остается PROCESSING_MOVE.
			# _on_carrot_move_finished обработает завершение их движения.
			# print("Морковка съедена, ждем движения испуганных соседей...")


# Обрабатывает логику запугивания морковок ПОСЛЕ ХОДА КРОЛИКА (если он не ел)
func _process_scared_carrots(rabbit_final_pos: Vector2i) -> void:
	var scared_carrots_list: Array[Carrot] = []
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
	# ВАЖНО: Устанавливаем счетчик, а не добавляем, т.к. этот тип испуга происходит только если не было поедания
	moving_carrots_count = scared_carrots_list.size() 
	print("Напугано %d морковок кроликом." % moving_carrots_count) # Уточнил сообщение

	if moving_carrots_count > 0:
		for carrot_node in scared_carrots_list:
			var direction_away = (carrot_node.grid_pos - rabbit_final_pos)
			print("Морковка в ", carrot_node.grid_pos, " пугается и движется в ", direction_away)
			
			# Рассчитываем конечную точку скольжения ЗДЕСЬ
			var calc_result = calculate_slide_destination(carrot_node.grid_pos, direction_away, carrot_node)
			var final_carrot_pos = calc_result["final_position"]
			
			if carrot_node.has_method("scare_and_slide"):
				# Передаем конечную точку в морковку
				carrot_node.scare_and_slide(final_carrot_pos, self)
			else:
				printerr("Ошибка: У узла морковки %s отсутствует метод scare_and_slide!" % carrot_node.name)
	else:
		# Никто не напуган кроликом, можно сразу вернуть ход игроку
		current_state = State.PLAYER_TURN


# Вызывается, когда анимация движения Морковки завершена (сигнал от Carrot.gd)
func _on_carrot_move_finished() -> void:
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

# Вспомогательная функция для получения TileData из указанной позиции
func get_tile_data(grid_pos: Vector2i, layer: int = 0) -> TileData:
	var source_id = ground_layer.get_cell_source_id(layer, grid_pos)
	
	if source_id == -1:
		return null # Нет тайла в этой позиции
	
	var atlas_coords = ground_layer.get_cell_atlas_coords(layer, grid_pos)
	var alternative_tile = ground_layer.get_cell_alternative_tile(layer, grid_pos)
	
	return ground_layer.tile_set.get_source(source_id).get_tile_data(atlas_coords, alternative_tile)

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

# Проверяет, является ли клетка полноценной стеной
func is_full_wall(grid_pos: Vector2i) -> bool:
	var tile_data = get_tile_data(grid_pos)
	if not tile_data:
		return false
		
	return tile_data.get_collision_polygons_count(0) > 0

# Проверяет, является ли клетка выходом
func is_exit(grid_pos: Vector2i) -> bool:
	var tile_data = get_tile_data(grid_pos)
	if not tile_data:
		return false
		
	var exit_property = tile_data.get_custom_data("type")
	return exit_property == "exit"

# Получает данные о блокировках частичной стены из Custom Data
func get_partial_wall_blocks(grid_pos: Vector2i) -> Dictionary:
	var tile_data: TileData = get_tile_data(grid_pos)
	if tile_data:
		var blocks = tile_data.get_custom_data("blocks")
		if blocks is Dictionary:
			return blocks
	return {} # Возвращаем пустой словарь, если данных нет или тайл не найден

# Возвращает узел морковки в указанной клетке, если он есть
func get_carrot_at(grid_pos: Vector2i) -> Carrot:
	return active_carrots.get(grid_pos, null) as Carrot

# Обновляет позицию морковки в словаре active_carrots.
# Вызывается из Carrot.gd ПОСЛЕ завершения анимации движения.
func update_carrot_position(carrot_node: Node, old_grid_pos: Vector2i, new_grid_pos: Vector2i) -> void:
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
#   "final_position": Vector2i,           # Конечная позиция объекта
#   "steps": int,                        # Количество шагов до столкновения
#   "will_collide": bool,                 # True, если столкновение произошло
#   "hit_wall": bool,                     # True, если столкновение произошло со стеной
#   "hit_carrot": bool,                   # True, если столкновение произошло с морковкой
#   "hit_map_edge": bool,                  # True, если столкновение произошло с краем карты
#   "carrot": Node                        # Узел морковки, с которой столкнулся объект
# }
func calculate_slide_destination(start_pos: Vector2i, direction: Vector2i, entity: Node = null) -> Dictionary:
	var current_pos = start_pos
	var next_pos = current_pos + direction
	var steps = 0
	var hit_wall = false
	var hit_carrot = false
	var hit_map_edge = false
	var collided_with: Node = null

	while steps < 100: # Предотвращение бесконечного цикла
		if not ground_layer.get_used_rect().has_point(next_pos):
			hit_map_edge = true
			break

		# Проверяем блокировку забором
		if is_blocked_by_fence(current_pos, next_pos):
			hit_wall = true
			break

		# Проверяем блокировку частичными стенами
		if _is_move_blocked_by_partial_wall(current_pos, next_pos):
			hit_wall = true
			break

		# Проверяем полную стену
		if is_full_wall(next_pos):
			hit_wall = true
			break

		# Проверяем коллизию с морковками
		var carrot_at_next = get_carrot_at(next_pos)
		if carrot_at_next != null and carrot_at_next != entity:
			hit_carrot = true
			collided_with = carrot_at_next
			break

		# Если нет коллизий, двигаемся дальше
		current_pos = next_pos
		next_pos = current_pos + direction
		steps += 1

		# Для отладки
		if steps >= 99:
			printerr("Возможен бесконечный цикл в calculate_slide_destination?")
			break
	
	return {
		"final_position": current_pos,
		"steps": steps,
		"will_collide": (hit_wall or hit_carrot or hit_map_edge),
		"hit_wall": hit_wall,
		"hit_carrot": hit_carrot,
		"hit_map_edge": hit_map_edge,
		"carrot": collided_with
	}


# Обработка поедания морковки
# Возвращает true, если были напуганы соседние морковки, иначе false.
func eat_carrot(carrot_node: Node) -> bool:
	if not is_instance_valid(carrot_node) or not carrot_node is Carrot:
		printerr("eat_carrot: Попытка съесть невалидный узел или узел не типа Carrot!")
		return false
	
	var carrot_obj: Carrot = carrot_node as Carrot
	var carrot_pos: Vector2i = carrot_obj.get_grid_position()

	var adjacent_carrots_scared_count: int = 0
	var scared_by_eating_list: Array[Dictionary] = []

	if active_carrots.has(carrot_pos):
		# --- ПРОВЕРКА И СБОР СОСЕДЕЙ ДЛЯ ИСПУГА --- 
		# Делаем это ДО удаления съеденной морковки из active_carrots
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var check_pos: Vector2i = carrot_pos + offset
			var adjacent_carrot: Carrot = get_carrot_at(check_pos)

			# Проверяем, что это другая морковка, она валидна и не движется
			if is_instance_valid(adjacent_carrot) and adjacent_carrot != carrot_obj and not adjacent_carrot.is_moving:
				# Проверяем стену МЕЖДУ съеденной и соседней
				if not _is_move_blocked_by_partial_wall(carrot_pos, check_pos):
					var direction_away: Vector2i = offset # Направление от съеденной морковки
					# Рассчитываем, может ли она вообще сдвинуться
					var calc_result: Dictionary = calculate_slide_destination(adjacent_carrot.grid_pos, direction_away, adjacent_carrot)
					var final_carrot_pos: Vector2i = calc_result["final_position"]
					# Если может сдвинуться, добавляем в список для испуга
					if final_carrot_pos != adjacent_carrot.grid_pos:
						scared_by_eating_list.append({"carrot": adjacent_carrot, "direction": direction_away, "final_pos": final_carrot_pos})
						adjacent_carrots_scared_count += 1
						
		# --- ОБРАБОТКА СЪЕДЕННОЙ МОРКОВКИ --- 
		active_carrots.erase(carrot_pos) # Удаляем из словаря
		carrots_remaining -= 1
		carrots_updated.emit(carrots_remaining)
		carrot_obj.eat() # Запускаем анимацию/звук поедания
		print("Морковка съедена. Осталось: ", carrots_remaining)

		# --- ЗАПУСК ИСПУГА СОСЕДЕЙ --- 
		if adjacent_carrots_scared_count > 0:
			moving_carrots_count += adjacent_carrots_scared_count # Увеличиваем счетчик движущихся
			print("Испугано %d соседних морковок поеданием." % adjacent_carrots_scared_count)
			for scare_info in scared_by_eating_list:
				var carrot_to_scare: Carrot = scare_info["carrot"]
				var final_pos: Vector2i = scare_info["final_pos"]
				carrot_to_scare.scare_and_slide(final_pos, self)
			return true # Сигнализируем, что соседи были напуганы
		else:
			return false # Соседи не были напуганы
	else:
		printerr("Попытка съесть морковку, которой нет в active_carrots по позиции %s: %s" % [carrot_pos, carrot_node.name])
		return false


# --- Условия победы и управление уровнем --- 

# Проверяет, все ли морковки съедены.
# Возвращает true, если морковок не осталось, иначе false.
func check_win_condition() -> bool:
	return carrots_remaining <= 0

# Переход на следующий уровень (вызывается из _on_rabbit_move_finished, когда условия выполнены)
func trigger_next_level() -> void:
	print("ПОБЕДА! Кролик на выходе, все морковки собраны.")
	
	# Воспроизводим звук завершения, если он есть
	if is_instance_valid(_level_complete_player) and not _level_complete_player.playing:
		_level_complete_player.play()
		# Можно добавить yield, если нужно дождаться звука
		# yield(_level_complete_player, "finished")
	
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.load_next_level()
	else:
		printerr("Не удалось найти GameManager в Autoload!")
		get_tree().quit() # Аварийный выход

# Перезапуск текущего уровня
func restart_level() -> void:
	get_tree().reload_current_scene()

# Можно добавить обработку нажатия R для перезапуска
# func _process(delta):
# 	if Input.is_action_just_pressed("restart"): # Нужно добавить действие "restart" в Input Map
# 		restart_level() 

# Проверяет, блокирует ли забор движение из from_pos в to_pos
func is_blocked_by_fence(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	var direction = to_pos - from_pos
	if direction.length_squared() != 1: # Убедимся, что это соседние клетки
		printerr("Ошибка в is_blocked_by_fence: Позиции не соседние!")
		return true # Считаем заблокированным на всякий случай
	
	# Проверяем блокировку по направлению
	var tile_data: TileData = get_tile_data(from_pos)
	if tile_data:
		var blocks = tile_data.get_custom_data("fence_blocks")
		if blocks is Dictionary:
			# Проверяем блокировку в направлении движения
			if direction == Vector2i.RIGHT and blocks.get("east", false): return true
			if direction == Vector2i.LEFT and blocks.get("west", false): return true
			if direction == Vector2i.DOWN and blocks.get("south", false): return true
			if direction == Vector2i.UP and blocks.get("north", false): return true
	
	# Проверяем блокировку с обратной стороны
	tile_data = get_tile_data(to_pos)
	if tile_data:
		var blocks = tile_data.get_custom_data("fence_blocks")
		if blocks is Dictionary:
			# Проверяем блокировку с обратной стороны
			if direction == Vector2i.RIGHT and blocks.get("west", false): return true
			if direction == Vector2i.LEFT and blocks.get("east", false): return true
			if direction == Vector2i.DOWN and blocks.get("north", false): return true
			if direction == Vector2i.UP and blocks.get("south", false): return true
	
	return false # Если не нашли блокировок - движение разрешено

func _handle_rabbit_move_finished(rabbit_final_pos: Vector2i) -> void:
	# Изменяем grid_pos кролика в соответствии с финальной позицией
	rabbit.grid_pos = rabbit_final_pos

	# Проверка на поедание морковки, если кролик столкнулся с ней
	var adjacent_scared_by_eating = []
	var eaten_carrot_this_turn = false
	
	if last_move_calculation_result.get("hit_carrot", false):
		var carrot_to_eat: Node = last_move_calculation_result.get("carrot", null)
		if is_instance_valid(carrot_to_eat):
			# Вызываем eat_carrot и сохраняем результат (были ли напуганы соседи)
			adjacent_scared_by_eating = eat_carrot(carrot_to_eat) 
			eaten_carrot_this_turn = true # Сам факт поедания произошел
		else:
			printerr("Ошибка: hit_carrot=true, но carrot недействителен!")
