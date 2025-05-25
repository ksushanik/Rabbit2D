# Система ям через Custom Data Layers

## Преимущества нового подхода

✅ **Интеграция в основной тайлсет** - нет необходимости в отдельных источниках тайлов
✅ **Гибкость размещения** - ямы можно размещать на любом слое
✅ **Простота управления** - все тайлы в одном месте
✅ **Расширяемость** - легко добавлять новые типы специальных тайлов

## Как добавлять ямы

### 1. В редакторе Godot

1. **Откройте сцену уровня** (например, `level_9.tscn`)
2. **Выберите узел `Ground`** (TileMap)
3. **Выберите любой слой** (Ground, Obstacles, или FenceLayer)
4. **Найдите тайл (7,8)** в основном тайлсете
5. **Выберите альтернативный тайл 1 или 2** (они помечены как "pit")
6. **Разместите яму** в нужной позиции

### 2. Программно

Добавьте в `layer_X/tile_data`:
```gdscript
# Одна яма в позиции (4,3) - альтернативный тайл 1
layer_1/tile_data = PackedInt32Array(196612, 458752, 1)

# Две ямы - альтернативные тайлы 1 и 2
layer_1/tile_data = PackedInt32Array(196612, 458752, 1, 262147, 458752, 2)
```

### 3. Расчет координат

Формула: `позиция = y * 65536 + x`

Примеры:
- (2,2) = `2 * 65536 + 2 = 131074`
- (4,3) = `3 * 65536 + 4 = 196612`
- (3,4) = `4 * 65536 + 3 = 262147`

## Структура тайлсета

### Основной источник (TileSetAtlasSource_hd8yg)
- **Позиция (7,8)**: Специальные тайлы
  - `alternative_tile = 0`: Обычный тайл
  - `alternative_tile = 1`: Яма (тип 1) с `custom_data_0 = "pit"`
  - `alternative_tile = 2`: Яма (тип 2) с `custom_data_0 = "pit"`

### Custom Data Layers
- **Layer 0 "type"**: Тип тайла (String)
  - `"exit"` - выход
  - `"pit"` - яма
- **Layer 1 "blocks"**: Блокировки движения (Dictionary)
- **Layer 2 "fence_blocks"**: Блокировки заборов (Dictionary)

## Логика обнаружения

```gdscript
func is_pit(grid_pos: Vector2i) -> bool:
    # Проверяем ямы на любом слое через Custom Data
    for layer_index in range(ground_layer.get_layers_count()):
        var tile_data = get_tile_data(grid_pos, layer_index)
        if tile_data:
            var tile_type = tile_data.get_custom_data("type")
            if tile_type == "pit":
                return true
    return false
```

## Примеры использования

### Простая яма
```gdscript
# В level_8.tscn - яма в позиции (4,3)
layer_1/tile_data = PackedInt32Array(196612, 458752, 1)
```

### Множественные ямы
```gdscript
# В level_12.tscn - две ямы разных типов
layer_1/tile_data = PackedInt32Array(262147, 458752, 1, 327683, 458752, 2)
```

### Ямы на разных слоях
```gdscript
# Яма на слое Ground
layer_0/tile_data = PackedInt32Array(131074, 458752, 1)

# Яма на слое Obstacles  
layer_1/tile_data = PackedInt32Array(196612, 458752, 2)
```

## Совместимость

- ✅ **Обратная совместимость**: Все существующие уровни обновлены
- ✅ **Производительность**: Нет дополнительных источников тайлов
- ✅ **Расширяемость**: Легко добавлять новые типы через Custom Data

## Добавление новых типов тайлов

Для добавления новых специальных тайлов:

1. **Создайте альтернативный тайл** в позиции (7,8)
2. **Установите custom_data_0** с нужным типом
3. **Обновите логику** в `Level.gd` для обработки нового типа

Пример:
```gdscript
# Добавить телепорт
7:8/3 = 3
7:8/3/custom_data_0 = "teleport"

# Обновить логику
func is_teleport(grid_pos: Vector2i) -> bool:
    for layer_index in range(ground_layer.get_layers_count()):
        var tile_data = get_tile_data(grid_pos, layer_index)
        if tile_data and tile_data.get_custom_data("type") == "teleport":
            return true
    return false
```

---

**Статус**: ✅ Реализовано и протестировано
**Версия**: Custom Data Layers v2.0 