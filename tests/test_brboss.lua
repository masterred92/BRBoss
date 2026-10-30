package.path = "./tests/?.lua;" .. package.path
local M = require("mock_wow")
M.install()
M.installLDB()
math.randomseed(1)

-- DBM mock: callbacks fire like DBM-Core fireEvent (event, ...)
local cbs = {}
DBM = { ReleaseRevision = 20261026000000,
  RegisterCallback = function(_, e, f) cbs[e] = cbs[e] or {}; table.insert(cbs[e], f) end }
local function dbmFire(e, ...) for _, f in ipairs(cbs[e] or {}) do f(e, ...) end end
function DBM:CreateBreakTimer(minutes)
  self.lastBreak = minutes
  if minutes == 0 then dbmFire("DBM_TimerStop", "BreakTimer") return end
  dbmFire("DBM_TimerBegin", "BreakTimer", "Break time!", minutes * 60, "134062", "breaktimer", nil, 0, "BreakTimerCountdownDummy",
    nil, nil, nil, nil, nil, nil, "break")
end
-- BigWigs mock
local msgs = {}
BigWigsLoader = { RegisterMessage = function(owner, m, f) msgs[m] = f end,
  GetReleaseString = function() return "BigWigs r427 official release" end }
local function bwSend(m, ...) if msgs[m] then msgs[m](m, ...) end end

local ns = M.loadAddon(".", "BRBoss")
M.fire("PLAYER_LOGIN"); M.advance(0) -- the shared launcher is built one frame after login
local B = ns.BRB
M.check(B.dbmHooked, "DBM hooked at pinned revision")
M.check(B.bwHooked, "BigWigs hooked")
M.check(M.settingsCategory and M.settingsCategory.name == "BRBoss", "settings category registered")
M.check(M.ldbObjects.BRBoss and M.ldbObjects.BRBoss.type == "launcher", "LDB launcher")

-- 1. /brb 5 solo with DBM -> DBM break timer -> quote at the end
M.slash("/brb", "5")
M.check(DBM.lastBreak == 5, "DBM:CreateBreakTimer(5) called")
M.check(#B.Pending() == 1, "break tracked from DBM_TimerBegin")
DBM.lastBreak = nil
M.slash("/brb", "5")
M.check(M.printed("wait") and DBM.lastBreak == nil, "30 s command cooldown")
-- BigWigs also reports the same break (it hears DBM's sync): must de-dupe
bwSend("BigWigs_StartBreak", {}, 300, "Kenny")
M.check(#B.Pending() == 1, "BigWigs copy of the same break de-duped")
M.advance(299)
M.check(#M.sounds == 0, "no line before the end")
M.advance(2)
M.check(#M.sounds == 1, "one line at break end")
M.check(M.sounds[1][2] == "Dialog", "dialog channel")
M.check(M.printed("BRBoss"), "subtitle printed")


-- 3. cancel via DBM stop
M.advance(31)
M.slash("/brb", "2")
M.check(#B.Pending() == 1, "second break tracked")
M.slash("/brb", "0")
M.check(#B.Pending() == 0, "/brb 0 cancels")
M.advance(200)
M.check(#M.sounds == 1, "cancelled break stays silent")

-- 4. pull quote off by default; on -> plays at 0 (BigWigs + Blizzard countdown merged)
bwSend("BigWigs_StartPull", {}, 10, "Kenny")
M.check(#B.Pending() == 0, "pull ignored while Pull Quote is off")
B.db.pullQuote = true
bwSend("BigWigs_StartPull", {}, 10, "Kenny")
M.fire("START_PLAYER_COUNTDOWN", "Player-1-0001", 10, 10, true, "Kenny")
M.check(#B.Pending() == 1, "pull from BigWigs and Blizzard merged")
M.advance(11)
M.check(#M.sounds == 2, "pull quote at 0")
-- throttle: another pull within 60 s does not speak
bwSend("BigWigs_StartPull", {}, 5, "Kenny")
M.advance(6)
M.check(#M.sounds == 2, "60 s throttle")
M.advance(60)
-- Blizzard cancel
M.fire("START_PLAYER_COUNTDOWN", "Player-1-0001", 10, 10, true, "Kenny")
M.fire("CANCEL_PLAYER_COUNTDOWN", "Player-1-0001", true, "Kenny")
M.advance(11)
M.check(#M.sounds == 2, "cancelled countdown stays silent")
-- secret values are skipped
local s = {}; M.secret[s] = true
M.fire("START_PLAYER_COUNTDOWN", "Player-1-0001", s, 10, true, "Kenny")
M.check(#B.Pending() == 0, "secret countdown ignored")

-- 5. combat / encounter: no line
bwSend("BigWigs_StartBreak", {}, 60, "Kenny")
M.combat = true
M.advance(61)
M.check(#M.sounds == 2, "no line in combat")
M.combat = false

-- 6. ignore list and trusted-only
M.ignored = { Griefer = true }
bwSend("BigWigs_StartBreak", {}, 60, "Griefer-OtherRealm")
M.check(#B.Pending() == 0, "ignored sender skipped")
B.db.trustedOnly = true
bwSend("BigWigs_StartBreak", {}, 60, "Stranger")
M.check(#B.Pending() == 0, "stranger skipped when trusted-only")
M.guild = { Mate = true }
bwSend("BigWigs_StartBreak", {}, 60, "Mate")
M.check(#B.Pending() == 1, "guild member allowed")
bwSend("BigWigs_StopBreak", {}, 0, "Mate")
M.check(#B.Pending() == 0, "BigWigs stop cancels")
B.db.trustedOnly = false

-- 7. in a group without rank: personal timer through BigWigs bar API
M.group.inGroup = true
local bars = 0
BigWigsAPI = { CreateBarFromAddon = function(addon, text, icon, t) bars = bars + 1; assert(addon == "BRBoss" and t == 120) end }
SlashCmdList["break"] = function() error("should not be used without rank") end
M.advance(31)
local path = B.StartBreak(2)
M.check(path == "BigWigs bar" and bars == 1, "no rank -> personal BigWigs bar")
M.check(#B.Pending() == 1, "personal break tracked by BRBoss itself")
B.Cancel("break")

-- 8. announce only when on and not locked down
B.db.announce = true
M.lockdown = true
M.advance(31); B.StartBreak(1)
M.check(#M.chat == 0, "no chat during lockdown")
M.lockdown = false
M.advance(31); B.StartBreak(1)
M.check(#M.chat == 1 and M.chat[1][2] == "PARTY", "one party line when announce is on")
B.Cancel("break")

-- 9. guarded hooks: old DBM is not hooked
DBM.ReleaseRevision = 20250101000000
B.dbmHooked = nil
M.fire("PLAYER_LOGIN")
M.check(not B.dbmHooked and M.printed("older"), "DBM below the pinned revision is skipped")

-- 10. pull command falls back to the Blizzard countdown
DBM = nil; SlashCmdList["pull"] = nil
M.check(B.StartPull(10) == "Blizzard" and M.lastCountdown == 10, "/brb pull -> C_PartyInfo.DoCountdown")

-- 11. test command and bad input
M.advance(100)
M.slash("/brb", "test")
M.check(#M.sounds == 3, "/brb test plays")
M.slash("/brb", "61")
M.check(M.printed("usage"), "range check")
-- 1.1.0: a quote never plays over another of our voice lines
KennyAddonsHub.MarkVoiceBusy(5)
B.db.throttle = 0
local okBusy, why = B.PlayQuote("break")
M.check(okBusy == false and why == "busy", "quote waits while another voice line plays")
M.advance(6)
M.check((B.PlayQuote("break")), "quote plays afterwards")
M.done("BRBoss")
