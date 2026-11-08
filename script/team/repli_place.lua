--[[
  Lot TV-REPLI (docs/TODO_VIDEO.md C07) : colle moteur du repli de placement simple (règle pure shared/team/repli_place.lua, Rp).
  Requise au CHARGEMENT dans un champ de Build (`Build.Repli`) : le bloc principal de script/team/build.lua est à 199 locales sur 200.

  QUAND : un module du plan directeur (fonderie, usine, laboratoires, foreuses de ravitaillement…) ne trouve de place dans AUCUN lot du
  treillis et le treillis ne peut plus grandir (Build.can_grow faux : rayon maximal, ou enceinte) ; avant ce lot le projet était
  refusé (« pas de lot », « place ») puis abandonné. Deux crochets dans script/team/build.lua : plan_project (module principal)
  et Build.plan_drills (dernier essai d'une ligne de foreuses). La centrale à vapeur n'est pas concernée (elle a son repli, l'eau
  hors du treillis, script/team/centrale_loin.lua).
  EFFET : le module est posé dans une fenêtre libre et sûre près du centre (le QG, ou le gisement de la ressource) ; ligne
  [FO-REPLI-PLACE] avec la cause de l'échec du plan et la place trouvée. Le module posé ainsi n'a pas de lot (`part.lot` = "repli", place.lot nil) :
  aucun lot du treillis n'est marqué pris ; les tuiles sont réservées par b.occ comme pour tout module.
  INTERRUPTEUR : réglage de carte `fo-war-repli-place` (settings/video.lua), ALLUMÉ par défaut ; absent (moteur simulé des tests) :
  éteint, sans erreur.
  ÉTAT : f.build.repli = { bad = { [fenêtre] = tick }, n = lignes écrites, ok = posés, ko = échecs, last = clé de la dernière pose } — nombres et chaînes, aucune
  fonction.
]]

local Rp = require("shared.team.repli_place")
local P = require("shared.team.plan")

local Rpl = {}
Rpl.SETTING = "fo-war-repli-place"
Rpl.Rp = Rp

local function read_setting() return settings.global[Rpl.SETTING].value end

--- Le repli est-il allumé ? (réglage absent : éteint)
function Rpl.on()
  local ok, v = pcall(read_setting)
  return ok and v == true
end

local function state(b)
  b.repli = b.repli or { bad = {}, n = 0, ok = 0, ko = 0 }
  b.repli.bad = b.repli.bad or {}
  return b.repli
end

--- Cherche une place de repli. ctx :
---   p (projet : p.id), why (cause de l'échec du plan), res (ressource du module ou nil), center = { x, y } (centre des fenêtres),
---   fopts (options de P.fit à garder : toward, head_toward, fan, cover_min, within…), read_masks, ore_set (les locales de build.lua),
---   avoid_margin (Build.AVOID_MARGIN : tuiles ajoutées au rayon d'un site écarté).
--- Rend une place au format de place_module ({ g, k, ox, oy, inst, cover, masks, lot = "repli" … }), ou nil, cause.
function Rpl.try(f, surface, g, ctx)
  if not Rpl.on() then return nil, "reglage eteint" end
  local b = f.build
  local st = state(b)
  local tick = game.tick
  local function read(rect)
    local masks = ctx.read_masks(f, surface, rect.x0 - 1, rect.y0 - 1, rect.x1 + 1, rect.y1 + 1)
    local ores = ctx.res and ctx.ore_set(surface, rect, ctx.res) or nil
    return masks, ores
  end
  local function lot_info(tx, ty)
    local i, j = P.lot_at(b.lat, tx, ty)
    local l = i and b.lots[P.lot_key(i, j)] or nil
    if not l then return nil end
    return l.state, l.reason
  end
  -- sites écartés par la centrale (b.avoid, script/team/reseau_vivant.lua) : la fenêtre ne touche pas leur disque élargi
  local function avoided(rect)
    if not b.avoid then return false end
    local cx, cy = (rect.x0 + rect.x1) / 2, (rect.y0 + rect.y1) / 2
    for _, a in ipairs(b.avoid) do
      local m = a.r + (ctx.avoid_margin or 0) + Rp.SIZE / 2
      if math.abs(cx - a.x) <= m and math.abs(cy - a.y) <= m then return true end
    end
    return false
  end
  local place, cause, info = Rp.pick(g, ctx.center, { tick = tick, bad = st.bad, res = ctx.res, fopts = ctx.fopts, read = read,
    lot_info = lot_info, avoided = avoided })
  local who = f.key or "player"
  local pid = ctx.p and ctx.p.id or 0
  if not place then
    st.ko = st.ko + 1
    if st.n < Rp.LOGS then
      st.n = st.n + 1
      log(string.format("[FO-REPLI-PLACE] %s : projet %d, %s : AUCUNE place de repli (cause du plan : %s ; %s)", who, pid, tostring(g.key),
        tostring(ctx.why), cause))
    end
    return nil, cause
  end
  -- un plan se refait sur plusieurs passes (relevés des masques en attente) : la même pose n'est comptée et écrite qu'une fois par projet
  local key = pid .. ":" .. place.ox .. "," .. place.oy .. "," .. place.k
  local again = st.last == key
  st.last = key
  if not again then st.ok = st.ok + 1 end
  place.lot = nil -- aucun lot du treillis (lu par plan_project et plan_drills : part.lot = "repli")
  place.repli = true
  if st.n < Rp.LOGS and not again then
    st.n = st.n + 1
    local c = ctx.center
    log(string.format("[FO-REPLI-PLACE] %s : projet %d, %s : pose de repli en (%d, %d) rotation %d, fenetre (%d, %d) anneau %d a %d tuile(s) du centre (%d, %d) ; cause du plan : %s ; %d fenetre(s) lue(s), %d ecartee(s)",
      who, pid, tostring(g.key), place.ox, place.oy, place.k, place.rect.x0, place.rect.y0, place.ring,
      math.abs(place.ox + place.g.w / 2 - c.x) + math.abs(place.oy + place.g.h / 2 - c.y), math.floor(c.x), math.floor(c.y),
      tostring(ctx.why), info.tried, info.skipped))
  end
  return place
end

return Rpl
