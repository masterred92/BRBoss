-- BRBoss: a boss voice line when the raid break (or, optionally, the pull) ends.
-- It only listens to timers that DBM, BigWigs or the Blizzard countdown already run, and plays voice lines that are
-- already in the client. It sends no addon messages of its own and automates nothing: every timer it starts comes
-- from a slash command you typed.
local addonName, ns = ...

local BRB = {}
ns.BRB = BRB
BRBoss = BRB

local DBM_MIN_REVISION = 20261026000000 -- DBM-Core ReleaseRevision whose DBM_TimerBegin argument order we read
local BIGWIGS_MIN = 427                 -- BigWigs release with the Start/StopBreak and Start/StopPull messages we use
local DEDUPE_WINDOW = 2                 -- the same timer reported by two hosts ends within this many seconds
local COMMAND_COOLDOWN = 30

local defaults = {
  enabled = true,       -- master switch for quotes
  breakQuote = true,    -- line when a break ends
  pullQuote = false,    -- Pull Quote: line at pull 0
  quote = "random",     -- "random" or a key from Quotes.lua
  channel = "Dialog",
  subtitle = true,      -- print the line in chat when it plays
  throttle = 60,        -- seconds between two lines
  trustedOnly = false,  -- only react to timers started by you, a friend or a guild member (when the sender is known)
  announce = false,     -- /brb also posts one line to party/raid chat
}
BRB.defaults = defaults

local db
local pending = {}      -- active timers we will speak at the end of
local lastPlay, lastCommand = -math.huge, -math.huge
local warned = {}

local function say(msg) print("|cffffd200BRBoss|r: " .. msg) end
BRB.say = say

local function secret(v) return issecretvalue and issecretvalue(v) end

local function inEncounter()
  return C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress and C_InstanceEncounter.IsEncounterInProgress()
end

local function chatLocked()
  return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

-- Sender filters -------------------------------------------------------------------------------------------------
local function shortName(name)
  if type(name) ~= "string" or secret(name) then return nil end
  return (name:match("^([^%-]+)")) or name
end

function BRB.IsIgnored(name)
  name = shortName(name)
  return name ~= nil and C_FriendList and C_FriendList.IsOnIgnoredList and C_FriendList.IsOnIgnoredList(name) and true or false
end

function BRB.IsTrusted(name, guid)
  if guid and not secret(guid) then
    if guid == UnitGUID("player") then return true end
    if C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then return true end
  end
  name = shortName(name)
  if not name then return false end
  if name == UnitName("player") then return true end
  if C_FriendList and C_FriendList.GetFriendInfo and C_FriendList.GetFriendInfo(name) then return true end
  if C_GuildInfo and C_GuildInfo.MemberExistsByName and C_GuildInfo.MemberExistsByName(name) then return true end
  return false
end

-- Quotes ---------------------------------------------------------------------------------------------------------
function BRB.PickQuote(kind)
  if db.quote ~= "random" and ns.QuoteByKey[db.quote] then return ns.QuoteByKey[db.quote] end
  local pool = {}
  for _, q in ipairs(ns.Quotes) do if q.kinds[kind] then pool[#pool + 1] = q end end
  if #pool == 0 then pool = ns.Quotes end
  return pool[math.random(#pool)]
end

-- force = the /brb test button: skips the throttle, still never plays in combat or during an encounter.
function BRB.PlayQuote(kind, force, quote)
  if not force and not db.enabled then return false, "off" end
  if InCombatLockdown() or inEncounter() then return false, "combat" end
  local now = GetTime()
  if not force and now - lastPlay < db.throttle then return false, "throttled" end
  local q = quote or BRB.PickQuote(kind)
  local ok, willPlay = pcall(PlaySoundFile, q.id, db.channel)
  if not ok or not willPlay then return false, "sound" end
  lastPlay = now
  if db.subtitle then say(("%s: \"%s\""):format(q.who, q.line)) end
  return true, q
end

-- Timer bookkeeping ----------------------------------------------------------------------------------------------
local function cancelEntry(i)
  local e = table.remove(pending, i)
  if e and e.handle then e.handle:Cancel() end
end

function BRB.Cancel(kind, id)
  for i = #pending, 1, -1 do
    local e = pending[i]
    if e.kind == kind and (id == nil or e.ids[id]) then cancelEntry(i) end
  end
end

function BRB.Pending() return pending end

-- A host told us a break/pull of `seconds` started. sender/guid are only known for some hosts.
function BRB.Track(kind, seconds, source, id, sender, guid)
  seconds = tonumber(seconds)
  if not seconds or secret(seconds) then return end
  if seconds <= 0 then BRB.Cancel(kind) return end
  if kind == "break" and not db.breakQuote then return end
  if kind == "pull" and not db.pullQuote then return end
  if sender and BRB.IsIgnored(sender) then return end
  if db.trustedOnly and (sender or guid) and not BRB.IsTrusted(sender, guid) then return end
  local endsAt = GetTime() + seconds
  for _, e in ipairs(pending) do
    if e.kind == kind and math.abs(e.endsAt - endsAt) <= DEDUPE_WINDOW then
      if id then e.ids[id] = true end
      e.sources[source] = true
      return e
    end
  end
  -- a new timer of the same kind replaces the old one (a re-sent break, a restarted pull)
  BRB.Cancel(kind)
  local e = { kind = kind, endsAt = endsAt, ids = {}, sources = { [source] = true } }
  if id then e.ids[id] = true end
  e.handle = C_Timer.NewTimer(seconds, function()
    for i, x in ipairs(pending) do if x == e then table.remove(pending, i) break end end
    BRB.PlayQuote(kind)
  end)
  pending[#pending + 1] = e
  return e
end

-- Host: DBM ------------------------------------------------------------------------------------------------------
-- DBM_TimerBegin(event, id, msg, timer, icon, simpType, spellId, colorId, modId, keep, fade, name, guid, timerCount,
--                isPriority, type, ...) from DBM-Core/modules/objects/Timer.lua; the break/pull dummy mods are a second check.
function BRB.OnDBMTimerBegin(_, id, _, timer, _, _, _, _, modId, _, _, _, _, _, _, timerType)
  local kind
  if timerType == "break" or modId == "BreakTimerCountdownDummy" then kind = "break"
  elseif timerType == "pull" or modId == "PullTimerCountdownDummy" then kind = "pull" end
  if kind then BRB.Track(kind, timer, "DBM", id) end
end

function BRB.OnDBMTimerStop(_, id)
  if id == nil then return end
  for i = #pending, 1, -1 do if pending[i].ids[id] then cancelEntry(i) end end
end

local function hookDBM()
  if BRB.dbmHooked or type(DBM) ~= "table" or type(DBM.RegisterCallback) ~= "function" then return end
  local rev = tonumber(DBM.ReleaseRevision) or 0
  if rev < DBM_MIN_REVISION then
    if not warned.dbm then warned.dbm = true; say("DBM is older than this version supports; update DBM. BigWigs and Blizzard countdowns still work.") end
    return
  end
  local ok = pcall(DBM.RegisterCallback, DBM, "DBM_TimerBegin", BRB.OnDBMTimerBegin)
  if ok then pcall(DBM.RegisterCallback, DBM, "DBM_TimerStop", BRB.OnDBMTimerStop); BRB.dbmHooked = true end
end

-- Host: BigWigs --------------------------------------------------------------------------------------------------
-- Messages from BigWigs Plugins/Break.lua and Plugins/Pull.lua; the callback gets (event, plugin, ...).
local bwOwner = {}
function BRB.BigWigsVersion()
  if type(BigWigsLoader) ~= "table" or type(BigWigsLoader.GetReleaseString) ~= "function" then return nil end
  local ok, s = pcall(BigWigsLoader.GetReleaseString, BigWigsLoader)
  return ok and type(s) == "string" and tonumber(s:match("(%d%d%d+)")) or nil
end

local function hookBigWigs()
  if BRB.bwHooked or type(BigWigsLoader) ~= "table" or type(BigWigsLoader.RegisterMessage) ~= "function" then return end
  local v = BRB.BigWigsVersion()
  if v and v < BIGWIGS_MIN then
    if not warned.bw then warned.bw = true; say("BigWigs is older than this version supports; update BigWigs.") end
    return
  end
  local R = BigWigsLoader.RegisterMessage
  pcall(R, bwOwner, "BigWigs_StartBreak", function(_, _, seconds, nick) BRB.Track("break", seconds, "BigWigs", nil, nick) end)
  pcall(R, bwOwner, "BigWigs_StopBreak", function() BRB.Cancel("break") end)
  pcall(R, bwOwner, "BigWigs_StartPull", function(_, _, seconds, nick) BRB.Track("pull", seconds, "BigWigs", nil, nick) end)
  pcall(R, bwOwner, "BigWigs_StopPull", function() BRB.Cancel("pull") end)
  BRB.bwHooked = true
end

-- Host: Blizzard countdown (C_PartyInfo.DoCountdown; BigWigs and DBM pulls use it too, the de-dupe merges them) --
local function onCountdown(initiatedBy, timeRemaining, _, _, initiatedByName)
  if secret(timeRemaining) then return end
  BRB.Track("pull", timeRemaining, "Blizzard", nil, initiatedByName, initiatedBy)
end

-- Commands -------------------------------------------------------------------------------------------------------
local function hasRank()
  return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function announce(text)
  if not db.announce or not IsInGroup() or chatLocked() then return end
  C_ChatInfo.SendChatMessage(text, IsInRaid() and "RAID" or "PARTY")
end

function BRB.StartBreak(minutes)
  minutes = tonumber(minutes)
  if not minutes or minutes ~= math.floor(minutes) or minutes < 1 or minutes > 60 then say("usage: /brb 1-60 (minutes)") return end
  if InCombatLockdown() or inEncounter() then say("not in combat or during an encounter.") return end
  local now = GetTime()
  if now - lastCommand < COMMAND_COOLDOWN then say(("wait %d s before starting another break."):format(math.ceil(COMMAND_COOLDOWN - (now - lastCommand)))) return end
  lastCommand = now
  local path
  if hasRank() and type(DBM) == "table" and type(DBM.CreateBreakTimer) == "function" then
    if pcall(DBM.CreateBreakTimer, DBM, minutes) then path = "DBM" end
  end
  if not path and hasRank() and SlashCmdList["break"] then
    if pcall(SlashCmdList["break"], tostring(minutes)) then path = "BigWigs" end
  end
  if not path then
    -- personal timer: only you see it, so we track it ourselves
    local seconds = minutes * 60
    if type(BigWigsAPI) == "table" and type(BigWigsAPI.CreateBarFromAddon) == "function"
      and pcall(BigWigsAPI.CreateBarFromAddon, addonName, "Break", 134062, seconds) then
      path = "BigWigs bar"
    elseif type(DBM) == "table" and type(DBM.CreatePizzaTimer) == "function" and pcall(DBM.CreatePizzaTimer, DBM, seconds, "Break", false) then
      path = "DBM bar"
    else
      path = "chat"
      say(("personal break: %d min, back at %s."):format(minutes, date("%H:%M", time() + seconds)))
    end
    BRB.Track("break", seconds, "BRBoss")
  end
  announce(("BRB: %d min break, back at %s"):format(minutes, date("%H:%M", time() + minutes * 60)))
  return path
end

function BRB.CancelBreak()
  if hasRank() and type(DBM) == "table" and type(DBM.CreateBreakTimer) == "function" then pcall(DBM.CreateBreakTimer, DBM, 0)
  elseif hasRank() and SlashCmdList["break"] then pcall(SlashCmdList["break"], "0") end
  BRB.Cancel("break")
  say("break cancelled.")
end

function BRB.StartPull(seconds)
  seconds = tonumber(seconds) or 10
  if seconds < 3 or seconds > 60 then say("usage: /brb pull 3-60 (seconds)") return end
  if InCombatLockdown() or inEncounter() then say("not in combat or during an encounter.") return end
  if SlashCmdList["pull"] and pcall(SlashCmdList["pull"], tostring(seconds)) then return "BigWigs" end
  if type(DBM) == "table" and type(DBM.CreatePullTimer) == "function" and pcall(DBM.CreatePullTimer, DBM, seconds) then return "DBM" end
  if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown(seconds) return "Blizzard" end
end

local HELP = {
  "/brb <1-60> - start a raid break (DBM or BigWigs if you lead or assist, otherwise a personal timer)",
  "/brb 0 - cancel the break",
  "/brb pull <3-60> - start a pull countdown",
  "/brb test - hear a line now",
  "/brb mute - turn the lines on or off",
  "/brb options - open the settings",
}

function BRB.Slash(msg)
  msg = strtrim((msg or ""):lower())
  local a, b = msg:match("^(%S*)%s*(.-)$")
  if a == "" or a == "help" then for _, l in ipairs(HELP) do say(l) end
  elseif a == "0" or a == "cancel" or a == "stop" then BRB.CancelBreak()
  elseif tonumber(a) then BRB.StartBreak(a)
  elseif a == "pull" then BRB.StartPull(b ~= "" and b or 10)
  elseif a == "test" then
    local ok, why = BRB.PlayQuote(b == "pull" and "pull" or "break", true)
    if not ok then say(why == "combat" and "not in combat." or "that line didn't play.") end
  elseif a == "mute" then db.enabled = not db.enabled; say(db.enabled and "lines on." or "lines muted.")
  elseif a == "options" or a == "config" then if ns.OpenOptions then ns.OpenOptions() end
  else say("unknown command; /brb help") end
end

SLASH_BRBOSS1 = "/brb"
SLASH_BRBOSS2 = "/brboss"
SlashCmdList.BRBOSS = function(msg) BRB.Slash(msg) end

-- Boot -----------------------------------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "START_PLAYER_COUNTDOWN", "CANCEL_PLAYER_COUNTDOWN" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == addonName then
      BRBossDB = BRBossDB or {}
      db = BRBossDB
      for k, v in pairs(defaults) do if db[k] == nil then db[k] = v end end
      BRB.db = db
      if ns.BuildOptions then ns.BuildOptions() end
    end
    if db then hookDBM(); hookBigWigs() end -- DBM/BigWigs may load after us (load on demand)
  elseif event == "PLAYER_LOGIN" then
    hookDBM(); hookBigWigs()
    if ns.BuildLauncher then ns.BuildLauncher() end
  elseif event == "START_PLAYER_COUNTDOWN" then
    if db then onCountdown(...) end
  elseif event == "CANCEL_PLAYER_COUNTDOWN" then
    if db then BRB.Cancel("pull") end
  end
end)
