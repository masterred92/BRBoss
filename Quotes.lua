-- BRBoss voice lines. Every entry is a sound that already ships in the WoW: Forever client, played by FileDataID.
-- Nothing is bundled. IDs were checked against the community listfile (wow-listfile) and are vanilla-era files;
-- DBM and BigWigs play vanilla-era voice lines the same way on Forever (e.g. Loatheb 554236).
local _, ns = ...

-- kinds: "break" = played when a break ends, "pull" = played at pull 0 (Pull Quote option)
ns.Quotes = {
  { key = "nefarius_games", id = 554313, who = "Lord Victor Nefarius", line = "Let the games begin!", kinds = { ["break"] = true, pull = true } },
  { key = "ragnaros_toosoon", id = 558805, who = "Ragnaros", line = "TOO SOON!", kinds = { ["break"] = true } },
  { key = "ragnaros_purged", id = 558782, who = "Ragnaros", line = "BY FIRE BE PURGED!", kinds = { pull = true } },
  { key = "ragnaros_insect", id = 558795, who = "Ragnaros", line = "DIE, INSECT!", kinds = { pull = true } },
  { key = "vancleef_aggro", id = 547946, who = "Edwin VanCleef", line = "None may challenge the Brotherhood!", kinds = { ["break"] = true, pull = true } },
  { key = "cthun_die", id = 546633, who = "C'Thun", line = "You will die.", kinds = { pull = true } },
  { key = "murloc", id = 555997, who = "Murloc", line = "Mrglglglgl!", kinds = { ["break"] = true, pull = true } },
  { key = "kobold_candle", id = 553311, who = "Kobold", line = "You no take candle!", kinds = { ["break"] = true } },
  { key = "peon_ready", id = 558137, who = "Peon", line = "Ready to work!", kinds = { ["break"] = true } },
}

ns.QuoteByKey = {}
for _, q in ipairs(ns.Quotes) do ns.QuoteByKey[q.key] = q end
