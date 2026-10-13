# Character Dossier Implementation Plan

> **For agentic workers:** Implement the independently owned tasks below and review their integration before building places.

**Goal:** Один экран персонажа и роллов на H, согласованная личность и понятный матч.

**Architecture:** Расширить существующие серверные роллы тремя категориями личности, использовать прежний атомарный кошелёк и сохранение. Переделать существующий AccessoryRollUI и владельцев оформления матча; не добавлять параллельную экономику или карту.

**Tech Stack:** Luau 0.742, Roblox APIs, Python rbxl tooling.

**Spec:** `docs/CHARACTER_DOSSIER_DESIGN.md`

## Constraints

- Использовать существующий checkout без worktree и DataStore SpyClubProfiles_v1.
- Сохранять старые балансы, предметы, оплаченные права и существующие режимы.
- Реальные результаты выбирает сервер; каждый успешный ролл списывает ровно 1.
- Национальность не имеет редкости, преимущества или модификатора удачи.
- Персонаж доступен кнопкой на touch и клавишей H с учётом ввода текста.
- Не публиковать игру Roblox; выдать два проверенных файла для Studio.

## Review focus

Повторные и устаревшие запросы, конкурентная смена национальности, открытый
чат/телефон при H, портретный телефон 360×640, приватность роли и продолжение
всех фаз матча.

## Tasks

- [x] Backend: тесты личности; CharacterIdentity, три категории, snapshot,
  атомарная миграция/списание/квитки в Economy и AccessoryRollService обеих сцен.
  Интерфейс: `profile.identity`, `accessoryRoll.categories`, `identityRolled`.
- [x] UI: заменить AccessoryRollUI обеих сцен на отзывчивое досье с preview,
  строками личности, косметикой, серверным подтверждением и наградами Rolls.
- [x] Match: согласовать MatchSpawnController/MatchRoomExperience, компактный
  MatchIntroClient/MatchHUD, контекстные turn-controls, роль и чат.
- [x] Integration: H, Esc и кнопка персонажа в обеих сценах; перенаправить
  старые косметические кейсы в досье, убрать монеты/кейсы из основного HUD.
- [x] Verification: `python3 tools/validate.py`, `python3 tools/build_places.py`,
  `python3 tools/test_rbxl_tool.py`; проверить бинарные изменения и добавить
  точный Studio checklist. Сохранить повторяемую настройку среды.
