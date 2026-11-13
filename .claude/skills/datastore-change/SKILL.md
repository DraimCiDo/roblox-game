---
name: datastore-change
description: Изменение структуры сохраняемых данных игрока (PlayerData) — добавление, переименование или удаление полей, миграции. Использовать при любом изменении Types.PlayerData, GameConfig.DefaultData или PlayerDataService.
---

# Изменение данных игрока

Ошибка здесь = потерянный прогресс реальных игроков. Действуй консервативно.

## Добавить поле (безопасно)
1. Добавить поле в `export type PlayerData` (`src/shared/Types.luau`).
2. Добавить значение по умолчанию в `DEFAULT_DATA` (`src/shared/Config/GameConfig.luau`).
3. Всё. `TableUtil.reconcile` сам допишет поле старым сохранениям.

## Переименовать / удалить / сменить тип поля (опасно)
1. Увеличить `DataSchemaVersion` в GameConfig и `Version` в DEFAULT_DATA.
2. Написать миграцию в `PlayerDataService` (функция `migrate(data)`, вызывается после `GetAsync` до `reconcile`): шаги `if data.Version < N then ... data.Version = N end` — последовательно, никогда не удалять старые шаги.
3. Старое поле удалять только после миграции его значения.
4. **Не менять** `DataStoreName` без явного решения команды — это обнулит прогресс всех игроков.

## Запрещено
- Менять данные напрямую в обход `PlayerDataService:Update`.
- Хранить в DataStore инстансы, функции, Vector3/CFrame (сериализуй в таблицы чисел).
- Ключи-строки длиннее 50 символов, значения больше 4 МБ на ключ.

## Проверка
- Studio: Game Settings → Security → Enable Studio Access to API Services.
- Зайти, изменить данные, выйти (Stop), зайти снова — данные на месте.
- Для миграции: вручную сохранить старую версию через командную строку Studio и проверить, что она мигрирует.
- В описании PR явно написать: «Меняет схему данных: vX → vY».
