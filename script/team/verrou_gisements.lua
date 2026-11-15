--[[
  Lot C1-COUT (CHANTIER 1 du DC, 15/11), côté RUNTIME du verrou des améliorations (règle pure : shared/team/verrou_gisements.lua).
    Vgr.hold(f) -> hold, why : vrai tant que les grands gisements des minerais des champs (fonderie ou combustible, lus aux données)
    ne sont pas couverts à R.COVER_HIGH (80 %). Lit le relevé EXISTANT de la capitalisation (f.team.capi.deps : tuiles, tuiles sous
    une foreuse, verdict « plein ») ; une équipe sans relevé n'est pas retenue.
  Lecteurs : script/team/build.lua (amélioration des tapis, Conv.step), script/ai3/capital.lua (remplacements de tapis et de bras,
  ctx.rang_hold ; une zone Maj + Z du joueur n'est jamais retenue), script/team/box_upgrade_rt.lua (bras du rétrofit des boxes).
  Journal [FO-VERROU-GISEMENTS] : une ligne quand le verrou change d'état (f.team.vg_hold, booléen).
]]
local Vg = require("shared.team.verrou_gisements")
local T = require("shared.team.config")
local Ca = require("shared.ai3.capitalisation")

local Vgr = {}

local BIG = nil -- cache LOCAL (prototypes : ne changent pas dans une session ; jamais dans global)

--- Minerais des champs : ceux dont le puits de l'avant-poste est un FOUR (type du prototype), et le combustible des équipes.
local function big()
  if BIG then return BIG end
  local out = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local o = T.outposts[kind]
    local fp = o and o.sink and game.entity_prototypes[o.sink]
    if o and o.resource and ((fp and fp.type == "furnace") or o.resource == T.fuel) then out[o.resource] = true end
  end
  BIG = out
  return out
end

function Vgr.hold(f)
  local t = f and f.team
  local cs = t and t.capi
  if not (cs and cs.deps) then return false, "aucun releve des gisements" end
  local hold, why = Vg.hold(cs.deps, big(), { small = Ca.GIANT_SMALL })
  if (t.vg_hold or false) ~= hold then
    t.vg_hold = hold
    log(string.format("[FO-VERROU-GISEMENTS] %s : ameliorations automatiques (tapis, bras) %s : %s a %.1f min", f.key or "player",
      hold and "retenues" or "permises", why, (game and game.tick or 0) / 3600))
  end
  return hold, why
end

return Vgr
