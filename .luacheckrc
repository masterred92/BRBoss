std = "lua51"
max_line_length = false
exclude_files = { "tests/**", "tools/**", ".release/**", ".lua/**", ".luarocks/**", "wow-ui/**", "index/**", "hosts/**" }
-- Our own globals.
globals = { "BRBoss", "BRBossDB", "SLASH_BRBOSS1", "SLASH_BRBOSS2", "SlashCmdList" }
-- WoW API (checked against Blizzard's UI source by tools/verify_api.py) and host-addon globals (tools/host_api.py).
read_globals = { "C_Timer", "C_ChatInfo", "C_InstanceEncounter", "C_FriendList", "C_GuildInfo", "C_PartyInfo", "CreateFrame", "Settings", "GetTime", "InCombatLockdown", "IsInGroup", "IsInRaid", "UnitIsGroupLeader", "UnitIsGroupAssistant", "UnitGUID", "UnitName", "PlaySoundFile", "issecretvalue", "strtrim", "time", "date", "DBM", "BigWigsLoader", "BigWigsAPI", "LibStub",
  -- used by the shared KennyShared library (Libs/KennyShared)
  "C_AddOns", "C_AuctionHouse", "C_Container", "C_Item", "C_RestrictedActions", "Enum", "GameTooltip", "GetBuildInfo", "GetLocale", "GetMoney", "GetMoneyString", "GetRealZoneText", "GetRealmName", "GetSubZoneText", "ItemRefTooltip", "NUM_BAG_SLOTS", "NUM_TOTAL_EQUIPPED_BAG_SLOTS", "TooltipDataProcessor", "UIParent", "UnitAffectingCombat", "UnitFactionGroup" }
