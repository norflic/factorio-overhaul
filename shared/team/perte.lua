--[[
  Lot PERIMETRE2 (diagnostic, 4/11) : MESURE des bâtiments perdus sous l'ennemi et de la couverture armée des points sensibles. Journal
  [FO-PERTE] (script/team/perte_log.lua) en LECTURE SEULE : aucune décision du mod ne lit ce module. Critères :
  fo-logs/2026-11-04_PERIMETRE2/CRITERES.md. Lua PUR, testé hors jeu (tests/perte_test.lua) ; aucun nom d'objet (types et rôles du moteur).

  - Pa.category(type, role, is_hq) : qg, centrale, fonderie, assembleur, labo, foreuse, tourelle, mur, logistique, autre.
  - Pa.site(d_hq, d_ap, ap_id) : qg (à Pa.SITE_R du QG), ap<id> (à Pa.SITE_R d'un avant-poste), base (à Pa.MAX_DIST), loin.
  - Pa.lack(n_range, n_armed, units) : ce qui manquait au bâtiment perdu : « a » aucune tourelle à portée, « b » à portée mais aucune armée,
    « c » armées mais submergées (au moins Pa.SWAMP unités ennemies par tourelle armée), « d » autre.
  - Pa.coverage(points, turrets) : couverture armée des points sensibles (convention du lot PERIMETRE).
  - Pa.add / Pa.summary : cumul par catégorie, site, côté, tueur et manque ; ligne de résumé.
]]

local Pa = {}

Pa.SITE_R = 40       -- tuiles : une perte à moins de cela du QG (ou d'un avant-poste) est « du QG » (de l'avant-poste)
Pa.MAX_DIST = 192    -- tuiles : au-delà, « loin »
Pa.SWAMP = 5         -- unités ennemies (à Pa.WAVE_R) par tourelle armée : au-delà, les tourelles sont submergées
Pa.WAVE_R = 30       -- tuiles : unités ennemies comptées autour du bâtiment perdu
Pa.WALL_R = 12       -- tuiles : un mur de l'équipe à moins de cela « protège » le bâtiment
Pa.COVER_PCT = 80
Pa.TAN_1000 = 414    -- tan(22,5°) × 1000 : secteurs de 45°
Pa.ROLE_W = { fabrique = 3, labo = 3, chauffe = 3, generateur = 3, pompe = 2, foreuse = 1 }
Pa.HQ_W = 20
Pa.SENSIBLE = { qg = true, centrale = true, fonderie = true, assembleur = true, labo = true, foreuse = true }
Pa.CATS = { "qg", "centrale", "fonderie", "assembleur", "labo", "foreuse", "tourelle", "mur", "logistique", "autre" }
Pa.LACKS = { "a", "b", "c", "d" }

local function d2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by return dx * dx + dy * dy end

local BY_TYPE = { furnace = "fonderie", ["assembling-machine"] = "assembleur", lab = "labo", ["mining-drill"] = "foreuse",
  boiler = "centrale", generator = "centrale", ["offshore-pump"] = "centrale", wall = "mur", gate = "mur" }

function Pa.category(ty, role, is_hq)
  if is_hq then return "qg" end
  local c = BY_TYPE[ty]
  if c then return c end
  if role == "militaire" then return "tourelle" end
  if role == "logistique" then return "logistique" end
  return "autre"
end

function Pa.sensible(cat) return Pa.SENSIBLE[cat] == true end

function Pa.site(d_hq, d_ap, ap_id)
  if d_hq and d_hq <= Pa.SITE_R then return "qg" end
  if d_ap and ap_id ~= nil and d_ap <= Pa.SITE_R then return "ap" .. tostring(ap_id) end
  if d_hq and d_hq <= Pa.MAX_DIST then return "base" end
  return "loin"
end

function Pa.side(dx, dy)
  dx, dy = dx or 0, dy or 0
  local ax, ay = math.abs(dx), math.abs(dy)
  if ax < 1 and ay < 1 then return "centre" end
  local ns = dy < 0 and "N" or "S"
  local eo = dx < 0 and "O" or "E"
  if ay * 1000 <= Pa.TAN_1000 * ax then return eo end
  if ax * 1000 <= Pa.TAN_1000 * ay then return ns end
  return ns .. eo
end

function Pa.lack(n_range, n_armed, units)
  if (n_range or 0) <= 0 then return "a" end
  if (n_armed or 0) <= 0 then return "b" end
  if (units or 0) >= Pa.SWAMP * n_armed then return "c" end
  return "d"
end

--- Couverture armée : points { {x, y, role} } (« qg » pour le coffre), tourelles { {x, y, range, armed} } -> { w, wc, n, nc }.
function Pa.coverage(points, turrets)
  local out = { w = 0, wc = 0, n = 0, nc = 0 }
  for _, p in ipairs(points or {}) do
    local w = p.role == "qg" and Pa.HQ_W or (Pa.ROLE_W[p.role] or 0)
    if w > 0 then
      local cov = false
      for _, t in ipairs(turrets or {}) do
        if t.armed then
          local r = (t.range or 0) * Pa.COVER_PCT / 100
          if d2(p.x, p.y, t.x, t.y) <= r * r then cov = true break end
        end
      end
      out.w, out.n = out.w + w, out.n + 1
      if cov then out.wc, out.nc = out.wc + w, out.nc + 1 end
    end
  end
  return out
end

--- Tourelles sans autre tourelle à leur portée.
function Pa.isolated(turrets)
  local n = 0
  for i, t in ipairs(turrets or {}) do
    local r2, alone = (t.range or 0) * (t.range or 0), true
    for j, u in ipairs(turrets) do
      if i ~= j and d2(t.x, t.y, u.x, u.y) <= r2 then alone = false break end
    end
    if alone then n = n + 1 end
  end
  return n
end

local function bump(t, k) t[k] = (t[k] or 0) + 1 end

--- Cumul : agg (table créée ici si nil) <- rec = { cat, site, side, killer, lack (sensibles seulement), wall }.
function Pa.add(agg, rec)
  agg = agg or { n = 0, cat = {}, site = {}, side = {}, killer = {}, lack = {}, wall = 0, sens = 0 }
  agg.n = agg.n + 1
  bump(agg.cat, rec.cat)
  bump(agg.site, rec.site)
  bump(agg.killer, rec.killer or "?")
  if Pa.sensible(rec.cat) then
    agg.sens = agg.sens + 1
    bump(agg.side, rec.side or "?")
    bump(agg.lack, rec.lack or "?")
    if rec.wall then agg.wall = agg.wall + 1 end
  end
  return agg
end

local function sorted_keys(t)
  local out = {}
  for k in next, t do out[#out + 1] = k end
  table.sort(out)
  return out
end

local function list(t, order)
  local parts, seen = {}, {}
  for _, k in ipairs(order or {}) do
    if t[k] then parts[#parts + 1] = k .. " " .. t[k]; seen[k] = true end
  end
  for _, k in ipairs(sorted_keys(t)) do
    if not seen[k] then parts[#parts + 1] = k .. " " .. t[k] end
  end
  return #parts > 0 and table.concat(parts, ", ") or "-"
end

--- Résumé lisible du cumul.
function Pa.summary(agg)
  if not agg or agg.n == 0 then return "aucune perte" end
  return string.format("%d perte(s) dont %d sensible(s) | categories : %s | sites : %s | cotes (sensibles) : %s | tueurs : %s | manque (sensibles) : %s | mur a %d tuiles : %d sur %d",
    agg.n, agg.sens, list(agg.cat, Pa.CATS), list(agg.site, { "qg", "base", "loin" }), list(agg.side), list(agg.killer),
    list(agg.lack, Pa.LACKS), Pa.WALL_R, agg.wall, agg.sens)
end

return Pa
