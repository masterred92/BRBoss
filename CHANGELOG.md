# Changelog

## 1.1.1
- Dropped `/brb` because it is the game's built-in "be right back" emote. Every command now uses `/brboss` (`/brboss 5`, `/brboss 0`, `/brboss pull`, `/brboss test`, `/brboss mute`, `/brboss options`, `/brboss debug`).

## 1.1.0
- Never plays a quote over another of Kenny's voice addons, DBM's victory sound or a BigWigs countdown.
- One shared display-bar entry.
- `/brboss debug` checks your setup: client version, every game API the addon needs, and which of Kenny's other addons it is working with.
- A loud chat warning if this client is missing an API the addon needs, instead of failing silently.
- English text now lives in `Locales/enUS.lua`, ready for translations.
- Shared code (KennyShared) is identical in every addon of the family and checked in CI, along with every Blizzard API call (against the Forever UI source) and every DBM/BigWigs/Questie API call (against their source).

## 1.0.0 (first release)
- First release. Break Quote (default on) and Pull Quote (option) for DBM, BigWigs and Blizzard's countdown, de-duplicated, with cancel handling.
- `/brboss N` starts a group break with rank or a personal bar without it. Optional party/raid announce line.
- Nine vanilla boss/NPC lines played by sound ID, a subtitle, a 60 s throttle, no sound in combat or encounters, ignore-list and trusted-only filters.
- Settings panel and LDB launcher. Game version: WoW: Forever 1.60.1 (Interface 16001).
