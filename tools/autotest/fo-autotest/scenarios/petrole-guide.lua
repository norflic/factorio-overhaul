--[[
  Lot PETROLE (A9) : la partie du guide (etape1-guide : 2 factions, 30 ouvriers, automatisation et capitalisation
  allumees) allongee a 90 min. Le reglage fo-war-petrole n'est PAS touche : c'est son defaut qui joue (allume depuis
  le lot PETROLE 2). Releve toutes les 10 min par faction : gisement connu, sites (etat, entites posees/total, manques),
  chevalets / raffineries / usines chimiques, packs chimiques fabriques, plastique / soufre / circuits avances / moteurs,
  technologies du palier 4 recherchees. Controles a 90 min : au moins une faction a fabrique le pack chimique et
  recherche une technologie qui le consomme.
  Lancement : banc.py --out <archive> --graine <g> --qui PETROLE<g> -- 324300 petrole-guide <source>.
]]
local base = require("scenarios/etape1-guide")

local OIL = { "pumpjack", "oil-refinery", "chemical-plant" }
local PACK = "chemical-science-pack"
local TAG = "[FO-PETROLE-GUIDE] "
local CHECK = 323000

local function factions()
  local out = {}
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

local function tier4(force)
  local f = game.forces[force]
  local out = {}
  if not f then return out end
  local names = {}
  for name in pairs(f.technologies) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local t = f.technologies[name]
    if t.researched then
      for _, ing in ipairs(t.research_unit_ingredients) do if ing.name == PACK then out[#out + 1] = name end end
    end
  end
  return out
end

local function line_for(s, key, force, tick)
  local okp, st = pcall(remote.call, "fo-petrole", "status", key)
  st = (okp and st) or {}
  local f = game.forces[force]
  local n = {}
  for _, name in ipairs(OIL) do n[name] = s.count_entities_filtered({ name = name, force = force }) end
  local prod = {}
  for _, it in ipairs({ "plastic-bar", "sulfur", "advanced-circuit", "engine-unit", PACK }) do
    prod[#prod + 1] = it .. "=" .. (f and f.item_production_statistics.get_input_count(it) or 0)
  end
  local sites = {}
  for _, x in ipairs(st.sites or {}) do
    sites[#sites + 1] = string.format("%s:%s(%s/%s)%s%s", x.key, tostring(x.state), tostring(x.built), tostring(x.total),
      x.reason and ("<" .. x.reason .. ">") or "", (x.missing and #x.missing > 0) and ("{" .. table.concat(x.missing, ",") .. "}") or "")
  end
  if st.plant then
    sites[#sites + 1] = string.format("centrale:%s(%s/%s)", tostring(st.plant.state), tostring(st.plant.built), tostring(st.plant.total))
  end
  return string.format("minute %d | %s | connus [%s] | decisions %d | sites [%s] | chevalets %d raffineries %d usines %d | %s | palier 4 [%s]",
    math.floor(tick / 3600), key, table.concat(st.known or {}, " "), st.decisions or 0, table.concat(sites, " "),
    n.pumpjack, n["oil-refinery"], n["chemical-plant"], table.concat(prod, " "), table.concat(tier4(force), " "))
end

local STATUS = {}
for k, v in pairs(defines.entity_status) do STATUS[v] = k end

--- Etat des machines du site du petrole (statut, recette, contenu des fluides) et contenu des coffres des quais.
local function machines_report(s, force, tag, tick)
  local parts = {}
  for _, e in ipairs(s.find_entities_filtered({ name = OIL, force = force })) do
    local fl = {}
    for i = 1, #e.fluidbox do
      local fb = e.fluidbox[i]
      fl[#fl + 1] = fb and string.format("%s %.0f", fb.name, fb.amount) or "-"
    end
    local rec = e.type == "mining-drill" and "" or (e.get_recipe and e.get_recipe() and e.get_recipe().name or "sans recette")
    parts[#parts + 1] = string.format("%s@%d,%d %s %s [%s]", e.name, e.position.x, e.position.y, STATUS[e.status] or tostring(e.status), rec, table.concat(fl, "; "))
  end
  local chests = {}
  local seen = {}
  for _, e in ipairs(s.find_entities_filtered({ name = OIL, force = force })) do
    for _, c in ipairs(s.find_entities_filtered({ name = "iron-chest", force = force, position = e.position, radius = 8 })) do
      local k = c.position.x * 100000 + c.position.y
      if not seen[k] then
        seen[k] = true
        local items = {}
        for n, v in pairs(c.get_inventory(defines.inventory.chest).get_contents()) do items[#items + 1] = n .. "=" .. v end
        table.sort(items)
        chests[#chests + 1] = string.format("coffre@%d,%d {%s}", c.position.x, c.position.y, table.concat(items, " "))
      end
    end
  end
  if #parts > 0 then
    log(TAG .. string.format("machines %s minute %d | %s", tag, math.floor(tick / 3600), table.concat(parts, " | ")))
    log(TAG .. string.format("quais %s minute %d | %s", tag, math.floor(tick / 3600), table.concat(chests, " | ")))
  end
end

local init0, tick0, finish0 = base.init, base.tick, base.finish
base.description = "PETROLE : partie du guide a 90 min, defaut du reglage fo-war-petrole"
base.check_tick = CHECK

base.init = function(ctx)
  if init0 then init0(ctx) end
  pcall(remote.call, "fo-petrole", "dump", true)
  local sv = settings.global["fo-war-petrole"]
  local on = sv and sv.value
  ctx.log(TAG .. "fo-war-petrole = " .. tostring(on))
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick > 0 and e.tick % 36000 == 0 then
    local s = ctx.surface()
    ctx.log(TAG .. line_for(s, "player", "player", e.tick))
    local rows = factions()
    rows[#rows + 1] = { key = "player", force = "player" }
    for _, r in ipairs(rows) do
      if r.key ~= "player" then ctx.log(TAG .. line_for(s, r.key, r.force, e.tick)) end
      if e.tick % 72000 == 0 then machines_report(s, r.force, r.key, e.tick) end
      -- projets non finis (diagnostic) : ce qui retient chaque chantier
      local okr, rep = pcall(remote.call, "fo-ia1d", "report", r.key)
      for _, pr in ipairs((okr and rep and rep.projects) or {}) do
        if pr.state ~= "fini" and pr.state ~= "refuse" then
          local ub = {}
          for _, u in ipairs(pr.unbuilt or {}) do ub[#ub + 1] = string.format("%s@%d,%d f%d npc%d", u.name, u.x, u.y, u.fails, u.npc) end
          ctx.log(TAG .. string.format("projet %s minute %d | #%s %s %s (%d/%d) obst %d/%d | non poses %s", r.key,
            math.floor(e.tick / 3600), tostring(pr.id), tostring(pr.state), tostring(pr.reason), pr.built or 0, pr.total or 0,
            pr.open_obstacles or 0, pr.obstacles or 0, table.concat(ub, "; ")))
          if (pr.state == "chantier" or pr.state == "fini") and e.tick % 72000 == 0 then
            local okt, tl = pcall(remote.call, "fo-petrole", "tasks", r.key, pr.id)
            ctx.log(TAG .. string.format("taches %s #%s | %s", r.key, tostring(pr.id), table.concat((okt and tl) or {}, " || ")))
          end
        end
      end
    end
  end
end

base.finish = function(ctx)
  if finish0 then finish0(ctx) end
  local s = ctx.surface()
  local n_pack, n_t4, n_fac = 0, 0, 0
  for _, r in ipairs(factions()) do
    n_fac = n_fac + 1
    ctx.log(TAG .. "FIN " .. line_for(s, r.key, r.force, game.tick))
    machines_report(s, r.force, r.key, game.tick)
    local okp, st = pcall(remote.call, "fo-petrole", "status", r.key)
    for _, l in ipairs((okp and st and st.logs) or {}) do ctx.log(TAG .. "journal " .. l) end
    local f = game.forces[r.force]
    if f and f.item_production_statistics.get_input_count(PACK) > 0 then n_pack = n_pack + 1 end
    if #tier4(r.force) > 0 then n_t4 = n_t4 + 1 end
  end
  -- Les packs chimiques fabriques A LA MAIN par les PNJ ne comptent pas dans les statistiques de production (F244) : le pack
  -- est PROUVE par une technologie qui le consomme, recherchee (n_pack, a titre informatif, compte les statistiques)
  ctx.log(TAG .. "factions dont les statistiques comptent des packs chimiques : " .. n_pack .. "/" .. n_fac)
  ctx.log(TAG .. "FIN " .. line_for(s, "player", "player", game.tick))
  machines_report(s, "player", "player", game.tick)
  ctx.check(n_t4 >= 1, "au moins une faction a recherche une technologie qui consomme le pack chimique (palier 4)", n_t4 .. "/" .. n_fac)
end

return base
