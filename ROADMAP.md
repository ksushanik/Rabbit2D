# Roadmap Улучшений Rabbit2D

- [x] **Надежная передача `tile_size`**: Передавать `tile_size` из `Level.gd` в `Rabbit.gd` и `Carrot.gd` через метод `initialize`.
- [x] **Гибкие ссылки на узлы в `Level.gd`**: Заменить `@onready` на `@export` для `rabbit` и `carrots_container`.
- [x] **Переход на тайлсет 32x32**: Заменить все тайлмапы с 64x64 на 32x32 с настройкой зума камеры.
- [x] **Реализация 2.5D элементов с заборами**:
  - [x] Создать дополнительный слой в TileMap для заборов с повышенным Z-индексом.
  - [x] Настроить Custom Data Layers для меток направлений блокирования.
  - [x] Реализовать функцию `is_blocked_by_fence(from_pos, to_pos)` для проверки возможности движения.
  - [x] Обновить логику расчёта перемещения кролика и морковки с учетом частичных блокировок.
  - [x] Создать тестовый уровень с заборами для проверки механики.
- [x] **Система ям с диалогом выбора**:
  - [x] Добавить новые спрайты для анимации падения во всех направлениях.
  - [x] Добавить функцию `is_pit` для проверки типа тайла.
  - [x] Обновить функцию `calculate_slide_destination` для обработки падения в яму.
  - [x] Реализовать воспроизведение соответствующей анимации при падении.
  - [x] Добавить диалог выбора: перезапуск уровня или выход из игры.
  - [x] Интегрировать ямы в тайлсет и добавить тестовый уровень.
- [x] **Система управления уровнями**: Создать Autoload `GameManager` для хранения списка уровней и управления переходами. *(Расширено до 12 уровней)*
- [ ] **Пользовательский интерфейс (UI)**: Добавить `CanvasLayer` с `Label` для счета морковок и, возможно, кнопку перезапуска.
- [ ] **Обработка ввода**: Добавить действие "Restart" (клавиша R).
- [ ] **Улучшения кода**: Добавить недостающие хинты типов, убрать неиспользуемый код/комментарии.
- [ ] **Визуальное и звуковое оформление**: Добавить звуки и эффекты. 
- [ ] **Дополнительные игровые механики**: Новые препятствия, бонусы или особые плитки с уникальными свойствами. 