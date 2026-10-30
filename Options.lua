-- Settings panel (Esc > Options > AddOns > BRBoss) and an optional LibDataBroker launcher for Titan, ElvUI, Bazooka...
local addonName, ns = ...

local CHECKS = {
  { "enabled", "Play boss lines", "Master switch. /brb mute toggles it too." },
  { "breakQuote", "Line when a break ends", "When a DBM, BigWigs or BRBoss break runs out." },
  { "pullQuote", "Pull Quote: line at pull 0", "When a DBM, BigWigs or Blizzard pull countdown hits zero." },
  { "subtitle", "Show the line in chat", "Prints who said it and what they said." },
  { "trustedOnly", "Only timers from me, friends or guild", "Applies when the host tells us who started the timer." },
  { "announce", "/brb also posts one line to party/raid chat", "Off by default. Never posts during chat lockdown." },
}

function ns.QuoteLabel(key)
  local q = ns.QuoteByKey[key]
  return q and (q.who .. ": " .. q.line) or "Random line"
end

local category
function ns.BuildOptions()
  if category or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  local db = ns.BRB.db
  local panel = CreateFrame("Frame")
  panel.name = "BRBoss"
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("BRBoss")
  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("A boss voice line when the raid break ends. Type /brb help for commands.")
  local y = -64
  for _, c in ipairs(CHECKS) do
    local key, label = c[1], c[2]
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, y)
    cb.Text:SetText(label)
    cb:SetChecked(db[key])
    cb:SetScript("OnClick", function(self) db[key] = self:GetChecked() and true or false end)
    y = y - 30
  end
  local keys = { "random" }
  for _, q in ipairs(ns.Quotes) do keys[#keys + 1] = q.key end
  local pick = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  pick:SetSize(320, 24)
  pick:SetPoint("TOPLEFT", 20, y - 6)
  pick:SetText("Line: " .. ns.QuoteLabel(db.quote))
  pick:SetScript("OnClick", function(self)
    local i = 1
    for n, k in ipairs(keys) do if k == db.quote then i = n end end
    db.quote = keys[i % #keys + 1]
    self:SetText("Line: " .. ns.QuoteLabel(db.quote))
  end)
  local test = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  test:SetSize(100, 24)
  test:SetPoint("LEFT", pick, "RIGHT", 8, 0)
  test:SetText("Test")
  test:SetScript("OnClick", function() ns.BRB.Slash("test") end)
  category = Settings.RegisterCanvasLayoutCategory(panel, "BRBoss")
  Settings.RegisterAddOnCategory(category)
  ns.category = category
end

function ns.OpenOptions()
  if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID()) end
end

-- LibDataBroker launcher: only if a broker display already loaded LibStub + LibDataBroker-1.1.
function ns.BuildLauncher()
  if ns.launcher then return end
  -- One shared "Kenny's addons" entry with a menu when several of our addons are installed; our own when alone.
  ns.launcher = ns.Hub.Launcher(addonName, {
    type = "launcher", leftHint = "Options", rightHint = "Mute or unmute lines",
    label = "BRBoss",
    icon = "Interface\\AddOns\\BRBoss\\media\\icon",
    OnClick = function(_, button)
      if button == "RightButton" then ns.BRB.Slash("mute") else ns.OpenOptions() end
    end,
    OnTooltipShow = function(tt)
      tt:AddLine("BRBoss")
      tt:AddLine("Left-click: options", 1, 1, 1)
      tt:AddLine("Right-click: mute or unmute lines", 1, 1, 1)
      tt:AddLine(ns.BRB.db.enabled and "Lines: on" or "Lines: muted", 0.6, 0.6, 0.6)
    end,
  })
end
