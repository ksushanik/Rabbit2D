extends Node2D

## Скрипт для управления основной логикой уровня.

@export var tile_size: int = 32
@export var ground_layer: TileMap = null
@export var rabbit: Rabbit = null
@export var hud_scene: PackedScene = null
@export var level_complete_sound_path: String = ""

signal carrots_updated(count: int)

enum State { PLAYER_TURN, PROCESSING_MOVE }
var current_state: State = State.PLAYER_TURN

var active_carrots: Dictionary = {}
var carrots_remaining: int = 0
var moving_carrots_count: int = 0
var last_rabbit_direction: Vector2i = Vector2i.ZERO
var last_move_calculation_result: Dictionary = {}

var active_foxes: Array[Fox] = []

var _level_complete_player: AudioStreamPlayer = null
var _pause_menu_instance: CanvasLayer = null

func _ready() -> void:
	if not ground_layer:
		printerr("Level.gd: Узел GroundLayer не найден!")
		return
	if not rabbit:
		printerr("Level.gd: Узел Rabbit не найден!")
		return
	
	_setup_camera()
	_setup_hud()
	_initialize_rabbit()
	_initialize_carrots()
	_initialize_foxes()
	_setup_level_complete_sound()
	
	current_state = State.PLAYER_TURN

func _setup_camera() -> void:
	var camera: Camera2D = find_child("*Camera2D", true, false) as Camera2D
	if not is_instance_valid(camera):
		camera = Camera2D.new()
		camera.name = "ProgrammaticCamera"
		add_child(camera)
		var map_rect = ground_layer.get_used_rect()
		var map_center_local = map_rect.get_center()
		camera.position = ground_layer.map_to_local(map_center_local)
		camera.zoom = Vector2(2.0, 2.0)
	else:
		camera.zoom = Vector2(2.0, 2.0)
	
	camera.enabled = true

func _setup_hud() -> void:
	if hud_scene:
		var hud_instance: CanvasLayer = hud_scene.instantiate() as CanvasLayer
		if hud_instance:
			add_child(hud_instance)
			if hud_instance.has_method("update_carrot_count"):
				var callable_update = Callable(hud_instance, "update_carrot_count")
				if not carrots_updated.is_connected(callable_update):
					carrots_updated.connect(callable_update)
			else:
				printerr("Ошибка: Экземпляр HUD не имеет метода update_carrot_count!")
		else:
			printerr("Ошибка: Не удалось инстанциировать HUD как CanvasLayer!")

func _initialize_rabbit() -> void:
	var rabbit_start_grid_pos = world_to_grid(rabbit.global_position)
	if rabbit.has_method("initialize"):
		rabbit.initialize(tile_size)
	else:
		printerr("У кролика нет метода initialize!")
	if rabbit.has_method("set_grid_position"):
		rabbit.set_grid_position(rabbit_start_grid_pos)
	else:
		printerr("У кролика нет метода set_grid_position!")
	
	if rabbit.has_method("show_rabbit"):
		rabbit.show_rabbit()
	elif rabbit.sprite:
		rabbit.sprite.visible = true
	
	var callable_rabbit_finished = Callable(self, "_on_rabbit_move_finished")
	if not rabbit.move_finished.is_connected(callable_rabbit_finished):
		rabbit.move_finished.connect(callable_rabbit_finished)

func _initialize_carrots() -> void:
	active_carrots.clear()
	for carrot_node in get_children():
		if (carrot_node is Node2D and 
			carrot_node.has_method("set_grid_position") and 
			carrot_node.has_method("initialize") and
			carrot_node != ground_layer and 
			carrot_node != rabbit and
			not carrot_node is Fox):
			var carrot_grid_pos = world_to_grid(carrot_node.global_position)
			carrot_node.initialize(tile_size)
			carrot_node.set_grid_position(carrot_grid_pos)
			active_carrots[carrot_grid_pos] = carrot_node
			var callable_carrot_finished = Callable(self, "_on_carrot_move_finished")
			if not carrot_node.move_finished.is_connected(callable_carrot_finished):
				carrot_node.move_finished.connect(callable_carrot_finished)
	
	carrots_remaining = active_carrots.size()
	carrots_updated.emit(carrots_remaining)

func _initialize_foxes() -> void:
	active_foxes.clear()
	for fox_node in get_children():
		if (fox_node is Fox and 
			fox_node.has_method("set_grid_position") and 
			fox_node.has_method("initialize")):
			var fox_grid_pos = world_to_grid(fox_node.global_position)
			fox_node.initialize(tile_size)
			fox_node.set_grid_position(fox_grid_pos)
			active_foxes.append(fox_node)

func _setup_level_complete_sound() -> void:
	if not level_complete_sound_path.is_empty():
		var sound = load(level_complete_sound_path)
		if sound is AudioStream:
			_level_complete_player = AudioStreamPlayer.new()
			_level_complete_player.stream = sound
			_level_complete_player.name = "LevelCompleteSoundPlayer"
			add_child(_level_complete_player)
		else:
			printerr("Level.gd: Не удалось загрузить звук завершения уровня: ", level_complete_sound_path)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_show_pause_menu()
		get_tree().root.set_input_as_handled()
		return
		
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
		get_tree().root.set_input_as_handled()

func start_rabbit_move(direction: Vector2i) -> void:
	if rabbit.is_moving:
		return 
		
	current_state = State.PROCESSING_MOVE
	last_rabbit_direction = direction

	var start_pos = rabbit.grid_pos
	last_move_calculation_result = calculate_slide_destination(start_pos, direction, rabbit)
	var final_pos = last_move_calculation_result["final_position"]

	if final_pos != start_pos:
		var target_world_pos = grid_to_world(final_pos)
		var will_collide = last_move_calculation_result.get("will_collide", false)
		rabbit.animate_move(target_world_pos, rabbit.move_duration, will_collide)
	else:
		current_state = State.PLAYER_TURN

func _on_rabbit_move_finished() -> void:
	if not is_instance_valid(rabbit):
		printerr("_on_rabbit_move_finished: Экземпляр кролика недействителен!")
		return
		
	var final_grid_pos: Vector2i = world_to_grid(rabbit.position)
	rabbit.grid_pos = final_grid_pos
	
	if last_move_calculation_result.get("hit_pit", false):
		var dir_name = "down"
		if last_rabbit_direction == Vector2i.RIGHT:
			dir_name = "right"
		elif last_rabbit_direction == Vector2i.LEFT:
			dir_name = "left"
		elif last_rabbit_direction == Vector2i.DOWN:
			dir_name = "down"
		elif last_rabbit_direction == Vector2i.UP:
			dir_name = "up"
			
		rabbit.play_animation("fall_into_pit_" + dir_name)
		_wait_for_pit_fall_animation()
		return
	
	for fox in active_foxes:
		if fox.is_rabbit_in_danger_zone(final_grid_pos):
			fox.play_attack_animation()
			
			if rabbit and rabbit.has_method("hide_rabbit"):
				rabbit.hide_rabbit()
			elif rabbit and rabbit.sprite:
				rabbit.sprite.visible = false
			
			if rabbit.has_method("play_animation"):
				rabbit.play_animation("eaten_by_fox")
			
			_wait_for_fox_attack_animations(fox)
			return
	
	var eaten_carrot_this_turn: bool = false
	var adjacent_scared_by_eating: bool = false

	if last_move_calculation_result.get("will_eat_carrot", false):
		var carrot_to_eat: Node = last_move_calculation_result.get("carrot", null)
		if is_instance_valid(carrot_to_eat):
			adjacent_scared_by_eating = eat_carrot(carrot_to_eat) 
			eaten_carrot_this_turn = true
		else:
			printerr("Ошибка: will_eat_carrot=true, но carrot недействителен!")

	if check_win_condition() and is_exit(final_grid_pos):
		trigger_next_level()
		return

	if not eaten_carrot_this_turn:
		_process_scared_carrots(final_grid_pos)
	else:
		if not adjacent_scared_by_eating:
			current_state = State.PLAYER_TURN

func _process_scared_carrots(rabbit_final_pos: Vector2i) -> void:
	var scared_carrots_list: Array[Carrot] = []
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var check_pos = rabbit_final_pos + offset
		var scared_carrot = get_carrot_at(check_pos)

		if scared_carrot and is_instance_valid(scared_carrot) and not scared_carrot.is_moving:
			var no_obstacle = not (is_blocked_by_fence(rabbit_final_pos, check_pos) or _is_move_blocked_by_partial_wall(rabbit_final_pos, check_pos))
			var rabbit_not_facing_carrot = (last_rabbit_direction != offset)
			
			if no_obstacle and rabbit_not_facing_carrot:
				var carrot_offset = check_pos - rabbit_final_pos
				var calc_result = calculate_slide_destination(check_pos, carrot_offset, scared_carrot)
				var can_escape = (calc_result["final_position"] != check_pos)
				
				if can_escape:
					scared_carrots_list.append(scared_carrot)
		
	moving_carrots_count = scared_carrots_list.size()

	if moving_carrots_count > 0:
		for carrot_node in scared_carrots_list:
			var carrot_offset = carrot_node.grid_pos - rabbit_final_pos
			var direction_away_int = carrot_offset
			
			var calc_result = calculate_slide_destination(carrot_node.grid_pos, direction_away_int, carrot_node)
			var final_carrot_pos = calc_result["final_position"]
			
			if carrot_node.has_method("scare_and_slide_animated"):
				carrot_node.scare_and_slide_animated(final_carrot_pos, self)
			elif carrot_node.has_method("scare_and_slide"):
				carrot_node.scare_and_slide(final_carrot_pos, self)
			else:
				printerr("Ошибка: У узла морковки %s отсутствует метод scare_and_slide!" % carrot_node.name)
	else:
		current_state = State.PLAYER_TURN

func _on_carrot_move_finished() -> void:
	if current_state == State.PROCESSING_MOVE:
		moving_carrots_count -= 1
		if moving_carrots_count <= 0:
			current_state = State.PLAYER_TURN

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / tile_size), floor(world_pos.y / tile_size))

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * tile_size + Vector2(tile_size, tile_size) / 2.0

func get_tile_data(grid_pos: Vector2i, layer: int = 0) -> TileData:
	if not ground_layer:
		return null
		
	var source_id = ground_layer.get_cell_source_id(layer, grid_pos)
	
	if source_id == -1:
		return null
	
	var atlas_coords = ground_layer.get_cell_atlas_coords(layer, grid_pos)
	var alternative_tile = ground_layer.get_cell_alternative_tile(layer, grid_pos)
	
	var tile_data = ground_layer.tile_set.get_source(source_id).get_tile_data(atlas_coords, alternative_tile)
	return tile_data

func _is_move_blocked_by_partial_wall(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	var direction = to_pos - from_pos
	if direction.length_squared() != 1:
		printerr("Ошибка в _is_move_blocked_by_partial_wall: Позиции не соседние!")
		return true

	var blocks_leaving = get_partial_wall_blocks(from_pos)
	if not blocks_leaving.is_empty():
		if direction == Vector2i.RIGHT and blocks_leaving.has("right"): return true
		if direction == Vector2i.LEFT and blocks_leaving.has("left"): return true
		if direction == Vector2i.DOWN and blocks_leaving.has("down"): return true
		if direction == Vector2i.UP and blocks_leaving.has("up"): return true

	var blocks_entering = get_partial_wall_blocks(to_pos)
	if not blocks_entering.is_empty():
		if direction == Vector2i.RIGHT and blocks_entering.has("left"): return true
		if direction == Vector2i.LEFT and blocks_entering.has("right"): return true
		if direction == Vector2i.DOWN and blocks_entering.has("up"): return true
		if direction == Vector2i.UP and blocks_entering.has("down"): return true
		
	return false

func is_full_wall(grid_pos: Vector2i) -> bool:
	var layers_count = ground_layer.get_layers_count()
	
	for layer_index in range(layers_count):
		var tile_data = get_tile_data(grid_pos, layer_index)
		if tile_data:
			var collision_count = tile_data.get_collision_polygons_count(0)
			if collision_count > 0:
				return true
	
	return false

func is_exit(grid_pos: Vector2i) -> bool:
	var tile_data = get_tile_data(grid_pos, 1)
	if not tile_data:
		return false
	
	var exit_property = tile_data.get_custom_data("type")
	return exit_property == "exit"

func get_partial_wall_blocks(grid_pos: Vector2i) -> Dictionary:
	var tile_data: TileData = get_tile_data(grid_pos)
	if tile_data:
		var blocks = tile_data.get_custom_data("blocks")
		if blocks is Dictionary:
			return blocks
	return {}

func get_carrot_at(grid_pos: Vector2i) -> Carrot:
	return active_carrots.get(grid_pos, null) as Carrot

func get_fox_at(grid_pos: Vector2i) -> Fox:
	for fox in active_foxes:
		if fox.get_grid_position() == grid_pos:
			return fox
	return null

func update_carrot_position(carrot_node: Node, old_grid_pos: Vector2i, new_grid_pos: Vector2i) -> void:
	if active_carrots.has(old_grid_pos) and active_carrots[old_grid_pos] == carrot_node:
		active_carrots.erase(old_grid_pos)
	
	active_carrots[new_grid_pos] = carrot_node

func is_cell_vacant_for_rabbit(grid_pos: Vector2i) -> bool:
	if is_full_wall(grid_pos):
		return false
	if active_carrots.has(grid_pos):
		return false
	if get_fox_at(grid_pos) != null:
		return false
	return true

func is_cell_vacant_for_carrot(grid_pos: Vector2i, asking_carrot: Node) -> bool:
	if is_full_wall(grid_pos):
		return false
	var carrot_at_pos = get_carrot_at(grid_pos)
	if carrot_at_pos != null and carrot_at_pos != asking_carrot:
		return false
	if get_fox_at(grid_pos) != null:
		return false
	return true

func calculate_slide_destination(start_pos: Vector2i, direction: Vector2i, entity: Node = null) -> Dictionary:
	var current_pos = start_pos
	var next_pos = current_pos + direction
	var steps = 0
	var hit_wall = false
	var hit_carrot = false
	var hit_map_edge = false
	var hit_pit = false
	var collided_with: Node = null
	var will_eat_carrot = false

	while steps < 100:
		if not ground_layer.get_used_rect().has_point(next_pos):
			hit_map_edge = true
			break

		if is_blocked_by_fence(current_pos, next_pos):
			hit_wall = true
			break

		if _is_move_blocked_by_partial_wall(current_pos, next_pos):
			hit_wall = true
			break

		if is_full_wall(next_pos):
			hit_wall = true
			break

		if is_pit(next_pos) and entity is Rabbit:
			hit_pit = true
			current_pos = next_pos
			break

		var fox_at_next = get_fox_at(next_pos)
		if fox_at_next != null:
			hit_wall = true
			break

		var carrot_at_next = get_carrot_at(next_pos)
		if carrot_at_next != null and carrot_at_next != entity:
			hit_carrot = true
			collided_with = carrot_at_next
			will_eat_carrot = entity is Rabbit
			break

		if entity is Rabbit and is_exit(next_pos) and check_win_condition():
			current_pos = next_pos
			break

		current_pos = next_pos
		next_pos = current_pos + direction
		steps += 1
		
		if steps >= 99:
			printerr("Возможен бесконечный цикл в calculate_slide_destination?")
			break

	return {
		"final_position": current_pos,
		"steps": steps,
		"will_collide": (hit_wall or hit_carrot or hit_map_edge or hit_pit),
		"hit_wall": hit_wall,
		"hit_carrot": hit_carrot,
		"hit_map_edge": hit_map_edge,
		"hit_pit": hit_pit,
		"carrot": collided_with,
		"will_eat_carrot": will_eat_carrot
	}

func eat_carrot(carrot_node: Node) -> bool:
	if not is_instance_valid(carrot_node) or not carrot_node is Carrot:
		printerr("eat_carrot: Попытка съесть невалидный узел или узел не типа Carrot!")
		return false
	
	var carrot_obj: Carrot = carrot_node as Carrot
	var carrot_pos: Vector2i = carrot_obj.get_grid_position()

	var adjacent_carrots_scared_count: int = 0
	var scared_by_eating_list: Array[Dictionary] = []

	if active_carrots.has(carrot_pos):
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var check_pos: Vector2i = carrot_pos + offset
			var adjacent_carrot: Carrot = get_carrot_at(check_pos)

			if is_instance_valid(adjacent_carrot) and adjacent_carrot != carrot_obj and not adjacent_carrot.is_moving:
				if not _is_move_blocked_by_partial_wall(carrot_pos, check_pos):
					var direction_away: Vector2i = offset
					var calc_result: Dictionary = calculate_slide_destination(adjacent_carrot.grid_pos, direction_away, adjacent_carrot)
					var final_carrot_pos: Vector2i = calc_result["final_position"]
					if final_carrot_pos != adjacent_carrot.grid_pos:
						scared_by_eating_list.append({"carrot": adjacent_carrot, "direction": direction_away, "final_pos": final_carrot_pos})
						adjacent_carrots_scared_count += 1
						
		active_carrots.erase(carrot_pos)
		carrots_remaining -= 1
		carrots_updated.emit(carrots_remaining)
		carrot_obj.eat()

		if adjacent_carrots_scared_count > 0:
			moving_carrots_count += adjacent_carrots_scared_count
			for scare_info in scared_by_eating_list:
				var carrot_to_scare: Carrot = scare_info["carrot"]
				var final_pos: Vector2i = scare_info["final_pos"]
				if carrot_to_scare.has_method("scare_and_slide_animated"):
					carrot_to_scare.scare_and_slide_animated(final_pos, self)
				else:
					carrot_to_scare.scare_and_slide(final_pos, self)
			return true
		else:
			return false
	else:
		printerr("Попытка съесть морковку, которой нет в active_carrots по позиции %s: %s" % [carrot_pos, carrot_node.name])
		return false

func check_win_condition() -> bool:
	return carrots_remaining <= 0

func trigger_next_level() -> void:
	if is_instance_valid(_level_complete_player) and not _level_complete_player.playing:
		_level_complete_player.play()
	
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.load_next_level()
	else:
		printerr("Не удалось найти GameManager в Autoload!")
		get_tree().quit()

func restart_level() -> void:
	get_tree().reload_current_scene()

func is_blocked_by_fence(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	var direction = to_pos - from_pos
	if direction.length_squared() != 1:
		printerr("Ошибка в is_blocked_by_fence: Позиции не соседние!")
		return true
	
	var tile_data: TileData = get_tile_data(from_pos)
	if tile_data:
		var blocks = tile_data.get_custom_data("fence_blocks")
		if blocks is Dictionary:
			if direction == Vector2i.RIGHT and blocks.get("east", false): return true
			if direction == Vector2i.LEFT and blocks.get("west", false): return true
			if direction == Vector2i.DOWN and blocks.get("south", false): return true
			if direction == Vector2i.UP and blocks.get("north", false): return true
	
	tile_data = get_tile_data(to_pos)
	if tile_data:
		var blocks = tile_data.get_custom_data("fence_blocks")
		if blocks is Dictionary:
			if direction == Vector2i.RIGHT and blocks.get("west", false): return true
			if direction == Vector2i.LEFT and blocks.get("east", false): return true
			if direction == Vector2i.DOWN and blocks.get("north", false): return true
			if direction == Vector2i.UP and blocks.get("south", false): return true
	
	return false

func is_pit(grid_pos: Vector2i) -> bool:
	for layer_index in range(ground_layer.get_layers_count()):
		var tile_data = get_tile_data(grid_pos, layer_index)
		if tile_data:
			var tile_type = tile_data.get_custom_data("type")
			if tile_type == "pit":
				return true
	return false

func is_danger_zone(grid_pos: Vector2i) -> bool:
	for layer_index in range(ground_layer.get_layers_count()):
		var tile_data = get_tile_data(grid_pos, layer_index)
		if tile_data:
			var tile_type = tile_data.get_custom_data("type")
			if tile_type == "danger":
				return true
	return false

func _wait_for_pit_fall_animation() -> void:
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	add_child(timer)
	
	timer.timeout.connect(_on_pit_fall_timer_finished.bind(timer))
	timer.start()

func _on_pit_fall_timer_finished(timer: Timer) -> void:
	timer.queue_free()
	_show_pit_fall_dialog()

func _show_pit_fall_dialog() -> void:
	_show_game_over_screen()

func _wait_for_fox_attack_animations(fox: Fox) -> void:
	var timer = Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	add_child(timer)
	
	timer.timeout.connect(_on_fox_attack_timer_finished.bind(timer))
	timer.start()

func _on_fox_attack_timer_finished(timer: Timer) -> void:
	timer.queue_free()
	_show_fox_attack_dialog()

func _show_fox_attack_dialog() -> void:
	_show_game_over_screen()

func _show_game_over_screen() -> void:
	var game_over_scene = preload("res://scenes/UI/GameOverScreen.tscn")
	var game_over_instance = game_over_scene.instantiate()
	get_tree().current_scene.add_child(game_over_instance)

func _show_pause_menu() -> void:
	if _pause_menu_instance != null and is_instance_valid(_pause_menu_instance):
		return
		
	var pause_scene = preload("res://scenes/UI/PauseMenu.tscn")
	_pause_menu_instance = pause_scene.instantiate()
	get_tree().current_scene.add_child(_pause_menu_instance)

func _return_to_main_menu() -> void:
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("show_main_menu"):
		game_manager.show_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/UI/MainMenu.tscn")
