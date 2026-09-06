# MythicPresets Helper (EN)

Mythic+ group search presets, built from your own progress. One click switches the group
finder to the dungeons where you actually have a key level to push.

> **Unofficial.** MythicPresets Helper is not affiliated with, endorsed by, or maintained by the author
> of Premade Groups Filter. It is a separate addon that works alongside it.

---

## What it does

- **Builds presets from your progress.** For every dungeon of the current season it reads your
  best timed run and groups the dungeons by the next keystone level worth pushing. Best +12
  in three dungeons means one preset for +13 covering those three.
- **Applies a preset in one click.** The dungeon selection goes straight into Premade Groups
  Filter, so you see the checkboxes tick in its panel, and the search runs immediately.
- **Fills the rating range.** Optionally sets the M+ rating filter to your own score plus or
  minus a value you choose (100 by default).
- **Keeps your own presets.** Edit any automatic preset and it becomes yours: the addon stops
  regenerating it.

## How to use

1. Open the group finder and search for dungeons. The preset window appears beside it.
2. Click a preset. The dungeons are applied at once.
3. If the keystone level in the search box does not match, a small box pops up with the text
   ready (`13-13`), selected and focused. Press Ctrl+C, then Ctrl+V into the search box.

The search box keeps its text between searches, so you type the level once and then switch
presets freely.

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
| `/mph probe` | group finder diagnostics |
| `/mph debug` | toggle step by step logging |
| `/mph offset <n>` | extra nudge to the right, on top of the measured frames |
| `/mph reset` | reset the window position |
| `/mph help` | list the commands |

`/mythicpresets` is the long form of `/mph`.

## Requirements

World of Warcraft Retail, interface 120100 (Midnight). Premade Groups Filter is optional but
recommended: with it the dungeon selection shows up in its panel and it does the client side
filtering. Without it MythicPresets Helper drives Blizzard's own advanced filter directly.

## License and credits

Released under the MIT License; the full text is in `LICENSE`.

The addon reads Blizzard's own data at runtime and carries no code from other addons. It works
best alongside [Premade Groups Filter](https://github.com/0xbs/premade-groups-filter), which is
a separate project by Bernhard Saumweber.

## Support
Support the creator or like this post:
https://t.me/p_y_c_h/3

---

# MythicPresets Helper (RU)

Пресеты поиска групп M+, собранные из вашего прогресса. Один клик переключает поиск на те
подземелья, где вам есть что поднимать.

> **Неофициальное дополнение.** Не связано с автором Premade Groups Filter и не поддерживается им.

## Что делает

- **Собирает пресеты из прогресса.** По каждому подземелью сезона берёт лучшее прохождение в
  тайм и группирует подземелья по следующему уровню ключа. Три подземелья с лучшим +12 дадут
  один пресет на +13.
- **Применяет пресет в один клик.** Набор подземелий уходит прямо в Premade Groups Filter:
  галочки проставляются в его панели, поиск запускается сразу.
- **Подставляет диапазон рейтинга.** По желанию заполняет фильтр M+ рейтинга вашим счётом
  плюс-минус заданное значение (по умолчанию 100).
- **Не трогает ваши пресеты.** Измените любой автоматический, и он станет вашим: аддон
  перестанет его обновлять.

## Как пользоваться

1. Откройте поиск групп и перейдите к подземельям. Окно пресетов появится рядом.
2. Щёлкните пресет. Подземелья применятся сразу.
3. Если уровень ключа в строке поиска не совпадает, всплывёт окошко с готовым текстом
   (`13-13`), выделенным и в фокусе. Ctrl+C, затем Ctrl+V в строку поиска.

Строка поиска сохраняет текст между поисками, так что уровень набирается один раз.

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
| `/mph probe` | диагностика поиска групп |
| `/mph offset <n>` | дополнительный сдвиг вправо поверх измеренного |
| `/mph reset` | сбросить положение окна |
| `/mph help` | список команд |

`/mythicpresets` — полная форма команды `/mph`.

## Лицензия

Лицензия MIT, полный текст в файле `LICENSE`. Аддон читает данные Blizzard в рантайме и не
содержит кода других аддонов.

## Support
Поддержать проект или лайкнуть пост:
https://t.me/p_y_c_h/3