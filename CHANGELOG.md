# Changelog

## 0.2.2

- Loot tab: Ctrl+click tries an item on, Shift+click links it in chat.
- Hearthstone on the teleport tab: while your toys load it shows the regular Hearthstone dimmed
  with a "Looking for a hearthstone" note, then fades into the stone it picked. Picking another
  stone with right-click fades between the icons too.
- Debug log: `/mph debug` now writes to the addon SavedVariables instead of the chat, `/mph probe`
  goes there as well and `/mph clearlog` empties it. While debugging, the window title has
  buttons to stop, probe and clear.

## 0.2.1

- Loot that can't be traded is listed separately and grayed out.
- Warbound loot is listed too.
- Item level is shown only for gear.

## 0.2.0

- Square side tabs on the preset window: help, presets, teleport, party chat presets,
  abbreviations and Rapport.
  The help page opens on the very first launch and starts with a short list of features, each
  with a gray hint on when it opens or what it does for you.
- Teleport tab: one click to the dungeon of the group you joined or listed, and to the dungeon
  of your own keystone. Shows the shared cooldown; the tooltip reminds that timing any key
  resets it.
- The teleport tab opens by itself when you join or list a Mythic+ or Mythic 0 group and when
  the group fills up, even with the group finder closed. It closes on entering the dungeon,
  leaving the group, teleporting or with the close button.
- Personal Key to the Arcantina on the teleport tab, with its cooldown and destination.
- Random hearthstone on the teleport tab: cycles through your hearthstone toys without
  repeats, right-click swaps to another one, and shows where it takes you. Hearthstone toys
  are recognised by their description, so new ones work without an addon update. Falls back
  to the regular Hearthstone.
- Abbreviations tab: class and ability slang, in English, Russian and the European languages.
- Rapport tab: placeholder for upcoming notes on players.
- Optional thank-you to the group after a timed key: one message in party chat, off by
  default. The text is set per character on the party chat presets tab and defaults to
  `ty bb <3 (auto-sent by MPH addon)`.
- Party chat presets tab: opens by itself when a key ends and lists the loot of the whole group.
  A click on another player's item asks them in party chat whether they need it
  (`Name, you need gloves [item]?`); hovering an item shows it together with that message, and
  your own items are shown grayed out. The thank-you phrase is sent from the same tab with one
  click.
- Own group finder filter: raid presets cap the group size and the players in your armor type,
  and the rating range now has an upper bound too. No other addon is needed for any of it.
- Your own raid presets: the New button on the raid tab sets the minimum number of players, an
  armor type and the most players allowed in that armor.
- Automatic presets, Mythic+ and raid, can no longer be edited or deleted. A copy button next to
  each one adds a manual copy you can change, and the addon never regenerates copies.
- Group fit checkbox for Mythic+ presets: keeps groups with room for your party's roles and with
  Bloodlust present or still possible.
- The Reset button shows how many groups the active preset hides.
- Middle-click on the hearthstone switches between random and standard mode.
- `MPH` tab at the bottom right of the group finder replaces the checkbox.
- Settings page: open the addon window on the Teleport tab together with the Dungeons & Raids
  page of the group finder (unless the window is already open), open the teleport tab and the
  party chat presets tab automatically.
- Lua errors stay out of the way during a Mythic+ key and a raid boss fight: the error window
  of any addon opens only once the key or the boss fight ends, and chat tells how many errors
  were hidden. On by default, can be turned off in Settings.
- Shift + right-click on the window title pins it back beside the group finder.
- Move icon on the pin button instead of circular arrows.
- The Mythic+ and raid preset tabs open the matching group finder search, wherever the
  preset window was opened from.
- The rating checkbox and spread field re-apply the active Mythic+ preset right away; the
  field applies on Enter or when it loses focus.
- EllesmereUI support: with EllesmereUI installed, the preset window, editor, copy window,
  side tabs and the `MPH` tab follow its style. It can be turned off for this addon in
  EllesmereUI options.
- Thinner modern scroll bars in the preset list, help and abbreviations pages.
- Everything new in this version is translated into all 11 languages. The Abbreviations tab
  is not available in Korean and Chinese yet; the help page marks it as in development there.

## 0.1.1

- A `MPH` checkbox above the group finder search: it shows and hides the preset window, and
  a right-click pins the window back beside the group finder.
- Presets refresh themselves right after a finished key, as soon as the season data arrives,
  instead of waiting for the window to be opened. Switching character or any other change to
  your rating triggers the same check.

## 0.1.0

First release.

- Presets built automatically from your Mythic+ progress: dungeons grouped by the next
  keystone level, based on your best timed run in each.
- Dungeons ever untimed this season go into their own preset.
- One click applies a preset: the dungeon checkboxes are ticked in Premade Groups Filter and
  the search runs immediately. Without PGF the Blizzard advanced filter is driven directly.
- Optional M+ rating range around your own score, with a configurable spread.
- Copy box with the keystone level ready as `13-13`, closing itself on Ctrl+C. Blizzard does
  not allow addons to write into the search box, so this is as close as it gets.
- Manual presets: create your own, or edit an automatic one to take ownership of it.
- Reset button clears an applied preset without deleting it.
- The window places itself to the right of the group finder, Premade Groups Filter and the
  RaiderIO panel, and remembers where you drag it.
- Raid presets for the three common compositions (2-2-6, 2-3-9, 2-4-14), capping how many
  players already share your armor type: 2, 3 and 4 respectively.
- The window shows Mythic+ or raid presets depending on which group finder tab is open.
- Copy box has a "keys above" field, so a +14 preset can search 14-15.
- English and Russian.
