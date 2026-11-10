--[[
  Lot CC-PLAN-FIGE (F512, 10/11/2026) : la partie neuve avec l'épave (etape1-guide-epave) aux RÉGLAGES DE CARTE de la partie 0.6.89 du DC
  (journal fo-logs/2026-11-10_PLAYTEST-0689, ligne [FO-REGLAGES] : fo-war-factions=4, fo-war-workers=8 ; graine 4271945338).
  Le guide écrit 2 factions et 30 ouvriers : ici, 4 factions et 8 ouvriers sont écrits APRÈS son init (avant le lancement de la guerre).
  Lancement : banc.py --out <archive> --graine 4271945338 --qui CC-PLAN-FIGE -- 162000 etape1-guide-epave-dc <source>.
]]
local base = require("scenarios/etape1-guide-epave")
local init0 = base.init

base.description = "CC-PLAN-FIGE : " .. tostring(base.description or "etape1-guide-epave") .. ", reglages de carte du DC (4 factions, 8 ouvriers)"

base.init = function(ctx)
  if init0 then init0(ctx) end
  local a = ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 4)
  local w = ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", 8)
  ctx.check(a == 4 and w == 8, "reglages de carte du DC (4 factions, 8 ouvriers)", tostring(a) .. ", " .. tostring(w))
end

return base
