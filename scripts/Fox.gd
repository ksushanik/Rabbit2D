extends CharacterBody2D
class_name Fox

## Скрипт для лисы - врага кролика

@export var tile_size: int = 32
@export var fox_direction: Vector2i = Vector2i.LEFT

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var grid_pos: Vector2i = Vector2i.ZERO
var danger_zone_pos: Vector2i = Vector2i.ZERO

func _ready() -> void:
	grid_pos = world_to_grid(global_position)
	_calculate_danger_zone()
	_play_idle_animation()

func initialize(new_tile_size: int) -> void:
	tile_size = new_tile_size

func set_grid_position(new_grid_pos: Vector2i) -> void:
	grid_pos = new_grid_pos
	global_position = grid_to_world(grid_pos)
	_calculate_danger_zone()

func get_grid_position() -> Vector2i:
	return grid_pos

func get_danger_zone_position() -> Vector2i:
	return danger_zone_pos

func _calculate_danger_zone() -> void:
	danger_zone_pos = grid_pos + fox_direction

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / tile_size), floor(world_pos.y / tile_size))

func grid_to_world(grid_pos_param: Vector2i) -> Vector2:
	return Vector2(grid_pos_param) * tile_size + Vector2(tile_size, tile_size) / 2.0

func play_attack_animation() -> void:
	if animated_sprite:
		var direction_name = _get_direction_name()
		animated_sprite.play("attack_" + direction_name)

func play_idle_animation() -> void:
	_play_idle_animation()

func _play_idle_animation() -> void:
	if animated_sprite:
		var direction_name = _get_direction_name()
		animated_sprite.play("idle_" + direction_name)

func _get_direction_name() -> String:
	if fox_direction == Vector2i.LEFT:
		return "left"
	elif fox_direction == Vector2i.RIGHT:
		return "right"
	elif fox_direction == Vector2i.UP:
		return "up"
	elif fox_direction == Vector2i.DOWN:
		return "down"
	else:
		return "left"

func is_rabbit_in_danger_zone(rabbit_pos: Vector2i) -> bool:
	return rabbit_pos == danger_zone_pos 