# MythicPresets Helper (EN)

Mythic+ group search presets, built from your own progress. One click switches the group
finder to the dungeons where you actually have a key level to push.

---

## What it does

- **Builds presets from your progress.** For every dungeon of the current season it reads your
  best timed run and groups the dungeons by the next keystone level worth pushing. Best +12
  in three dungeons means one preset for +13 covering those three.
- **Applies a preset in one click.** The dungeons go straight into the group finder filter and
  the search runs immediately.
- **Fills the rating range.** Optionally narrows the search to an M+ rating range around your
  own score, plus or minus a value you choose (100 by default). Both bounds work.
- **Raid presets by composition.** Three presets for 2-2-6, 2-3-9 and 2-4-14 keep groups that
  already have enough players and no more than 2, 3 or 4 players in your armor type.
- **Finds a group that fits.** The Group fit checkbox keeps Mythic+ groups with room for your
  party's roles and with Bloodlust present or still possible. The Reset button shows how many
  groups the active preset hides.
- **Keeps your own presets.** Automatic presets cannot be edited or deleted, but a copy button
  turns any of them into a manual preset you can change, and the addon never regenerates it.
  The New button also works on the raid tab: minimum players, armor type and the most players
  allowed in that armor.
- **Teleports you to the dungeon.** The Teleport tab offers, one click each, the dungeon of the
  group you joined or listed and the dungeon of your own keystone, with the shared cooldown.
  Below them are a teleport row and a hearthstone row: the mouse wheel cycles through them and
  right-click switches the mode. The teleport row starts on a fixed list (Personal Key to the
  Arcantina, Dandan, Dalaran, racial and class teleports) or picks a random teleport toy. A
  number in the row header shows how many teleport or hearthstone toys you don't own yet, hover
  it for the list.
- **Opens by itself when it matters.** The window switches to the Teleport tab when you join or
  list a Mythic+ or Mythic 0 group and when the group fills up, and closes once you enter the
  dungeon, leave the group or teleport.
- **Explains group slang.** The Abbreviations tab lists class, ability and Mythic+ slang, in
  English, Russian and the European languages.
- **Chat and loot presets after a key.** Once a key ends, the tab gathers the loot of the whole
  group. Clicking another player's item asks in party chat whether they need it. Right-click
  opens a whisper to the owner with the same question, even after the group is gone. Ctrl+click
  tries an item on, Shift+click links it in chat. Items that can't be traded, like crafting
  reagents, are listed separately and grayed out. Above the list is a thank-you button for the
  group, with its own text on each character. After a timed key the thank-you can also go out
  by itself, turn that on in the settings.
- **Remembers who you played with.** When a key starts, the Rapport tab records the party: name,
  role, class, spec and each player's M+ score at that moment. The mouse wheel over the role icon
  rates the role, over the rest of the row it rates their play, three levels each, with your own
  wording set in the rating preset. Finished keys go to the key history, where any run can be
  unfolded, and on your next key together the row also shows the score from the previous one.
  Ratings show up in the player tooltip in game.
- **Keeps Lua errors out of the way.** While a Mythic+ key or a raid boss fight is in progress,
  the Lua error window of any addon does not pop up. It opens once the key or the fight ends,
  and chat tells how many errors were hidden. On by default.

## How to use

1. Open the group finder (I). The addon window appears beside it, and the presets side tab
   opens the dungeon search for you.
2. Click a preset. The dungeons are applied at once.
3. If the keystone level in the search box does not match, a small box pops up with the text
   ready (`13-13`), selected and focused. Press Ctrl+C, then Ctrl+V into the search box.

The search box keeps its text between searches, so you type the level once and then switch
presets freely.

The `MPH` tab at the bottom right of the group finder hides and shows the window, and a
right-click on it pins the window back beside the group finder. The window opens by itself on
the Teleport tab together with the Dungeons & Raids page, unless it is already open; this can be
turned off in Settings → AddOns → MythicPresets Helper.

The window has side tabs: help, presets, teleport, chat and loot presets, abbreviations and Rapport (your notes on
the players you meet). The help page opens on the very first launch. Drag the window by
its title with the left mouse button and it stays where you leave it; Shift + right-click on the
title puts it back beside the group finder, where it moves along when your Raider.IO profile
changes width.

Settings → AddOns → MythicPresets Helper has a button for the help page, auto-opening of the
addon window, of the Teleport tab and of the Chat and loot presets tab, the automatic thank-you and
hiding Lua errors during keys and raid boss fights.

## Why you type the keystone level yourself

The keystone level of a listed group exists only in the group title, and Blizzard protects it:
titles are censored strings that addons can render but not read, `C_LFGList.Search` has taken
no search text since Battle for Azeroth, and the search box refuses `SetText` from addon code.

No addon can filter or fill the keystone level. MythicPresets Helper does the next best thing: it hands
you the exact text, one Ctrl+C away. Everything else, the dungeons and the rating range, is
applied automatically.

## Commands

| Command | Action |
|---|---|
| `/mph` | show or hide the preset window |
| `/mph probe` | write group finder diagnostics to the debug log |
| `/mph debug` | toggle the debug log, saved in the addon SavedVariables on /reload or logout |
| `/mph clearlog` | clear the debug log |
| `/mph offset <n>` | extra nudge to the right, on top of the measured frames |
| `/mph reset` | reset the window position |
| `/mph help` | list the commands |

`/mythicpresets` is the long form of `/mph`.

## Requirements

World of Warcraft Retail, interface 120100 (Midnight). No other addons are required.

EllesmereUI is optional too: when it is installed, the addon's windows and tabs follow its
style. The skin can be turned off for this addon in EllesmereUI options under Blizz UI Enhanced,
Blizzard Window Skins, Third-Party Addons.

Languages: English, Russian, German, Spanish (Spain and Mexico), French, Italian, Portuguese
(Brazil), Korean, Simplified and Traditional Chinese. The Abbreviations tab is not available in
Korean and Chinese yet.

## License and credits

Released under the MIT License; the full text is in `LICENSE`.

The addon reads Blizzard's own data at runtime and carries no code from other addons.

## Support
Support the creator or like this post:
https://t.me/p_y_c_h/3

---

# MythicPresets Helper (RU)

Пресеты поиска групп M+, собранные из вашего прогресса. Один клик переключает поиск на те
подземелья, где вам есть что поднимать.

## Что делает

- **Собирает пресеты из прогресса.** По каждому подземелью сезона берёт лучшее прохождение в
  тайм и группирует подземелья по следующему уровню ключа. Три подземелья с лучшим +12 дадут
  один пресет на +13.
- **Применяет пресет в один клик.** Подземелья сразу уходят в фильтр поиска групп, поиск
  запускается сам.
- **Подставляет диапазон рейтинга.** По желанию сужает поиск до диапазона M+ рейтинга вокруг
  вашего, плюс-минус заданное значение (по умолчанию 100). Работают обе границы.
- **Рейдовые пресеты по составу.** Три пресета на 2-2-6, 2-3-9 и 2-4-14 оставляют группы, где уже
  набрано достаточно игроков и в вашем типе брони не больше 2, 3 или 4.
- **Ищет подходящую группу.** Галочка «Подходящая группа» оставляет группы M+, где есть места под
  роли вашей группы и уже есть или ещё может появиться БЛ. Кнопка «Сброс» показывает, сколько
  групп скрыл активный пресет.
- **Не трогает ваши пресеты.** Автоматические пресеты нельзя изменить или удалить, но кнопка
  копирования превращает любой из них в ручной: его можно менять, и аддон его не обновляет.
  Кнопка «Новый» работает и на вкладке рейдов: минимум игроков, тип брони и сколько игроков в
  этой броне допускается.
- **Телепортирует в подземелье.** На вкладке «Телепорт» в один клик: подземелье группы, в
  которую вы вступили или которую выставили, и подземелье вашего ключа, с общей перезарядкой.
  Ниже строки телепорта и камня возвращения: колесо мыши листает варианты, правый клик
  переключает режим. Строка телепорта начинает с фиксированного списка (ключ в Аркантину,
  Дандан, Даларан, расовые и классовые телепорты) или берёт случайную игрушку-телепорт. Число в
  заголовке строки показывает, сколько таких игрушек или камней у вас ещё нет, при наведении
  открывается список.
- **Открывается само, когда нужно.** Окно переходит на вкладку «Телепорт», когда вы вступаете
  в группу M+ или M0 или выставляете её и когда группа набрана, и закрывается при входе в
  подземелье, выходе из группы или после телепорта.
- **Расшифровывает сленг.** Вкладка «Сокращения»: сленг классов, умений и M+ на русском,
  английском и европейских языках.
- **Пресеты чата и лута после ключа.** Когда ключ завершён, вкладка собирает добычу всей
  группы. Клик по чужому предмету спрашивает в чате группы, нужен ли он владельцу. Правый клик
  открывает личку владельцу с тем же вопросом, даже если группы уже нет. Ctrl+клик
  примеряет предмет, Shift+клик вставляет ссылку в чат. Предметы, которые нельзя передать,
  например материалы для ремесла, идут отдельным списком и показаны серым. Над списком кнопка
  благодарности группе, текст у каждого персонажа свой. После ключа в тайм благодарность может
  уходить сама, это включается в настройках.
- **Помнит, с кем вы играли.** На старте ключа вкладка Rapport записывает состав: ник, роль,
  класс, специализацию и рейтинг M+ каждого на тот момент. Колесико над иконкой роли меняет
  оценку роли, над остальной строкой общую оценку, по три ступени, а тексты оценок задаются в
  пресете. Завершённые ключи попадают в историю, где любой из них раскрывается по клику, и при
  следующей встрече в строке виден рейтинг с прошлого ключа. Оценка видна и в тултипе
  персонажа в игре.
- **Не отвлекает ошибками Lua.** Пока идёт ключ M+ или бой с рейдовым боссом, окно ошибок Lua
  от любых аддонов не всплывает. Оно откроется после завершения ключа или боя, а в чате будет
  число скрытых ошибок. Включено по умолчанию.

## Как пользоваться

1. Откройте поиск групп (I). Окно аддона появится рядом, а боковая вкладка пресетов сама
   откроет поиск подземелий.
2. Щёлкните пресет. Подземелья применятся сразу.
3. Если уровень ключа в строке поиска не совпадает, всплывёт окошко с готовым текстом
   (`13-13`), выделенным и в фокусе. Ctrl+C, затем Ctrl+V в строку поиска.

Строка поиска сохраняет текст между поисками, так что уровень набирается один раз.

Вкладка `MPH` в правом нижнем углу поиска групп скрывает и показывает окно, правый клик по
ней возвращает окно на место рядом с поиском. Само окно открывается автоматически на вкладке
«Телепорт» вместе со страницей «Подземелья и рейды», если оно ещё не открыто, это отключается в
«Настройки → AddOns → MythicPresets Helper».

У окна боковые вкладки: «Как пользоваться», пресеты, «Телепорт», «Пресеты чата и лута», «Сокращения» и Rapport
(ваши заметки по игрокам). Инструкция открывается при самом первом запуске. Окно
перетаскивается левой кнопкой мыши за заголовок и остаётся на новом месте. Shift + правый клик
по заголовку возвращает его рядом с поиском групп, и там оно сдвигается, когда меняется ширина
вашего профиля Raider.IO.

В «Настройки → AddOns → MythicPresets Helper» есть кнопка инструкции, автооткрытие окна
аддона, вкладок «Телепорт» и «Пресеты чата и лута», автоматическая благодарность группе и
скрытие ошибок Lua в ключе и в бою с рейдовым боссом.

С EllesmereUI окна и вкладки аддона выглядят в его стиле. Скин отключается для этого аддона в
настройках EllesmereUI: Blizz UI Enhanced, Blizzard Window Skins, Third-Party Addons.

## Почему уровень ключа вводится вручную

Уровень ключа есть только в названии группы, а Blizzard его закрыла: название это защищённая
строка, которую аддон может отрисовать, но не прочитать; у `C_LFGList.Search` нет аргумента с
текстом поиска с самого Battle for Azeroth; а строка поиска отклоняет `SetText` из кода аддона.

Ни один аддон не может фильтровать или подставлять уровень ключа. MythicPresets Helper делает
максимально близкое: отдаёт готовый текст в одно нажатие Ctrl+C. Всё остальное, подземелья и
диапазон рейтинга, применяется само.

## Команды

| Команда | Действие |
|---|---|
| `/mph` | показать или скрыть окно пресетов |
| `/mph probe` | записать диагностику поиска групп в журнал отладки |
| `/mph debug` | включить или выключить журнал отладки, он сохраняется в SavedVariables аддона после /reload или выхода |
| `/mph clearlog` | очистить журнал отладки |
| `/mph offset <n>` | дополнительный сдвиг вправо поверх измеренного |
| `/mph reset` | сбросить положение окна |
| `/mph help` | список команд |

`/mythicpresets` — полная форма команды `/mph`.

## Языки

Английский, русский, немецкий, испанский (Испания и Мексика), французский, итальянский,
португальский (Бразилия), корейский, упрощённый и традиционный китайский. Вкладки
«Сокращения» на корейском и китайском пока нет.

## Лицензия

Лицензия MIT, полный текст в файле `LICENSE`. Аддон читает данные Blizzard в рантайме и не
содержит кода других аддонов.

## Support
Поддержать проект или лайкнуть пост:
https://t.me/p_y_c_h/3