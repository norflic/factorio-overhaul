--[[
  Lot TV-VAPEUR, point V36 : colle moteur du tampon de vapeur d'une centrale (règle pure : shared/team/vapeur_tampon.lua ; remplissage :
  Cc.refill, shared/team/charbon_centrale.lua ; appelant : quai_tasks de script/team/build.lua, champ Build.Vg).
  Vg.low(f, p, surface) : le tampon de vapeur de la centrale `p` est-il bas (hystérésis) ? Lecture des boîtes à fluide des machines à
  vapeur BÂTIES du plan (au plus Vt.MAX_READ), toutes les Vt.EVERY ticks ; entre deux lectures, l'état gardé. Mémoire : b.charbon[p.id] =
  { steam_low, steam_at, steam_ratio } (booléen et nombres). Aucune décision ne dépend d'un temps mesuré : seulement des ticks de jeu et du
  contenu des boîtes (état de jeu). Réglage fo-war-vapeur-tampon (défaut allumé). Journal [FO-VAPEUR-TAMPON] à chaque changement d'état.
]]

local M = require("shared.team.modules")
local Vt = require("shared.team.vapeur_tampon")

local Vg = {}

Vg.SETTING = "fo-war-vapeur-tampon"

function Vg.enabled()
  local ok, v = pcall(function() return settings.global[Vg.SETTING].value end)
  if ok and v == false then return false end
  return true
end

--- Parts lues : { { amount, cap } } des machines à vapeur du plan `p` posées et à la force `f.force`.
local function read_parts(f, p, surface)
  local parts = {}
  for _, e in ipairs(p.ents or {}) do
    if #parts >= Vt.MAX_READ then break end
    local sp = M.spec(e.name)
    if sp and sp.kind == "generator" and sp.steam then
      local ent = surface.find_entity(e.name, { e.x, e.y })
      if ent and ent.valid and ent.force.name == f.force then
        local fb = ent.fluidbox
        local cap = fb and fb.get_capacity(1)
        if cap and cap > 0 then
          local fl = fb[1]
          parts[#parts + 1] = { amount = fl and fl.amount or 0, cap = cap }
        end
      end
    end
  end
  return parts
end

function Vg.low(f, p, surface)
  if not Vg.enabled() then return false end
  local b = f.build
  if not b or p.state ~= "fini" then return false end
  b.charbon = b.charbon or {}
  local st = b.charbon[p.id] or {}
  b.charbon[p.id] = st
  local tick = game.tick
  if st.steam_at and tick - st.steam_at < Vt.EVERY then return st.steam_low == true end
  st.steam_at = tick
  local ratio = Vt.ratio(read_parts(f, p, surface))
  local was = st.steam_low == true
  local now = Vt.low(was, ratio)
  st.steam_low, st.steam_ratio = now, ratio
  if now ~= was then
    b.vt_logs = (b.vt_logs or 0) + 1
    if b.vt_logs <= Vt.LOGS then
      log(string.format("[FO-VAPEUR-TAMPON] %s : centrale %d, tampon de vapeur %s a %.1f min (taux %s, seuils %d %% / %d %%)",
        f.key or "player", p.id, now and "BAS" or "revenu", tick / 3600, ratio and string.format("%.0f %%", ratio * 100) or "inconnu",
        Vt.LOW_IN * 100, Vt.LOW_OUT * 100))
    end
  end
  return now
end

return Vg
