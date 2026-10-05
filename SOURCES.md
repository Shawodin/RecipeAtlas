# Источники и лицензии

## База мира и рецептов

- CMaNGOS WotLK DB, выпуск «WoTLKDB v1.9+ 'Icecrown' for CMaNGOS-WOTLK 14092» (клиент 3.3.5a build 12340), SQLite-сборка `wotlk-sqlite-db.zip`: <https://github.com/cmangos/wotlk-db/releases>
- DBC-файлы клиента 3.3.5a (`WorldMapArea`, `WorldMapOverlay`, `Map`, `AreaTable`, `Faction`, `FactionTemplate`, `SkillLineAbility`, `Spell`): <https://github.com/Elwynsiaa/data>

`RecipeAtlasData.lua` создаётся сценарием `tools/build_catalog.py`. В него входят: рецепты от наставников (включая общие шаблоны `npc_trainer_template`), предметы-рецепты, торговцы (включая `npc_vendor_template`), добыча с существ, сундуков, контейнеров-предметов и рыбалки (с учётом вложенных ссылочных таблиц и героических версий существ), задания, открытия (`skill_discovery_template`), требования к навыку и репутации, фракция NPC, праздничные NPC и задания, координаты (включая два уровня Даларана). Исходники Ackis Recipe List не используются.

База CMaNGOS распространяется под GNU GPL версии 3, текст лицензии — в `LICENSE`.

## Astrolabe

`Libs/Astrolabe` содержит Astrolabe 0.4 и AstrolabeMapMonitor для расстановки значков на карте мира и миникарте. Библиотека распространяется по GNU LGPL 2.1, текст — в `Libs/Astrolabe/lgpl.txt`. Файлы библиотеки не изменены.

`LibStub.lua` находится в общественном достоянии, исходное уведомление — в начале файла.

## Ограничения базы

Данные описывают стандартный WotLK 3.3.5a. Сервер Sirus может использовать свои рецепты, источники и точки появления; клиентский аддон не имеет доступа к серверной базе.
