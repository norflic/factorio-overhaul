-- Diagnostic (lot CENTRALE, defaut C : chaudiere sans combustible au demarrage) : etape1-guide + toutes les 2 min, par faction, la
-- centrale du plan directeur : etat du projet, entites NON POSEES (nom, place, echecs, PNJ bloques, fantome present ?), objets
-- manquants a la reserve, quai de combustible (contenu du coffre), chaudiere (combustible, etat), bras thermiques (etat) et
-- charbon au coffre du QG. Lecture seule, aucun appel qui modifie la partie.
-- Lignes : [FO-PLANT] minute N | faction | projet #id etat raison (posees/total) | non poses : ... | quais : ... | chaudiere : ... | bras : ... | coffre_qg charbon=..
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
local MIN = 3600
local TAG = "[FO-PLANT] "
base.description = (base.description or "") .. " + diagnostic de la centrale (entites non posees, quai de combustible, chaudiere)"

local function factions()
  local out = {}
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

local function sname(v)
  for k, x in pairs(defines.entity_status) do if x == v then return k end end
  return tostring(v)
end

local function diag(s, r, minute)
  local okr, rep = pcall(remote.call, "fo-ia1d", "report", r.key)
  local proj
  if okr and rep then
    for _, pr in ipairs(rep.projects or {}) do
      for _, pt in ipairs(pr.parts or {}) do
        if pt.kind == "centrale" then proj = pr end
      end
    end
  end
  local head, unb, qua = "aucun projet de centrale", "", ""
  if proj then
    head = string.format("projet #%s %s %s (%d/%d)", tostring(proj.id), tostring(proj.state), tostring(proj.reason), proj.built or 0, proj.total or 0)
    local u = {}
    for _, e in ipairs(proj.unbuilt or {}) do
      local ghost = #s.find_entities_filtered({ name = "entity-ghost", ghost_name = e.name, position = { e.x, e.y }, radius = 0.6 })
      local t = e.task or {}
      u[#u + 1] = string.format("%s@%g,%g echecs%d pnj%d fantome%s tache %s age%ss cd%ss", e.name, e.x, e.y, e.fails, e.npc,
        ghost > 0 and "oui" or "non", tostring(t.task), tostring(t.age), tostring(t.cd))
    end
    unb = table.concat(u, "; ")
    local q = {}
    for _, x in ipairs(proj.quais or {}) do
      local t = x.task or {}
      q[#q + 1] = string.format("%s=%d@%g,%g tache %s age%ss cd%ss", x.item, x.count, x.x, x.y, tostring(t.task), tostring(t.age), tostring(t.cd))
    end
    qua = table.concat(q, " ")
    local m = {}
    for _, x in ipairs(proj.missing or {}) do m[#m + 1] = x[1] .. "x" .. x[2] end
    if #m > 0 then unb = unb .. " | manque " .. table.concat(m, ",") end
  end
  local boil = {}
  for _, b in ipairs(s.find_entities_filtered({ force = r.force, type = "boiler" })) do
    local inv = b.get_fuel_inventory()
    boil[#boil + 1] = string.format("(%.0f,%.0f) combustible=%d etat=%s", b.position.x, b.position.y, inv and inv.get_item_count() or -1, sname(b.status))
  end
  local arms = {}
  local cnt = {}
  for _, b in ipairs(s.find_entities_filtered({ force = r.force, type = "boiler" })) do
    for _, i in ipairs(s.find_entities_filtered({ position = b.position, radius = 4, force = r.force, type = "inserter" })) do
      local k = i.name .. ":" .. sname(i.status)
      cnt[k] = (cnt[k] or 0) + 1
    end
  end
  local ks = {}
  for k in pairs(cnt) do ks[#ks + 1] = k end
  table.sort(ks)
  for _, k in ipairs(ks) do arms[#arms + 1] = k .. "=" .. cnt[k] end
  local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = r.force, limit = 1 })[1]
  local coal = -1
  if hq then
    local inv = hq.get_inventory(defines.inventory.chest)
    coal = inv and inv.get_item_count("coal") or -1
  end
  log(TAG .. string.format("minute %d | %s | %s | non poses : %s | quais : %s | chaudiere : %s | bras : %s | coffre_qg charbon=%d", minute, r.key, head,
    unb, qua, #boil > 0 and table.concat(boil, " ") or "aucune", #arms > 0 and table.concat(arms, " ") or "-", coal))
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick > 0 and e.tick % (2 * MIN) == 0 and e.tick <= 60 * MIN then
    local s = ctx.surface()
    for _, r in ipairs(factions()) do diag(s, r, e.tick / MIN) end
  end
end

return base
