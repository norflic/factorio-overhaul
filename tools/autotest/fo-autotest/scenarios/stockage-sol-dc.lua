--[[
  Lot STOCKAGE-VITAL (objets au sol, 7/11, demande du lead) : sur la SAUVEGARDE du DC (fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip,
  0.6.53 ; 1 774 objets au pied du coffre de l'équipe, recensement de x10-sprites), Stock.pick_ground reprend-il les objets au sol ?
  Le coffre de l'équipe était PLEIN au journal (1 472/1 472 cases à la minute 172) : sans place, rien n'est repris.
  Lancement : `banc.py --sauvegarde <zip> --qui STOCKAGE-VITAL -- 3700 stockage-sol-dc <source>` ; la partie du banc est une COPIE.

  Relevé au départ puis toutes les 600 ticks : objets au sol à 10 tuiles au plus du coffre de l'équipe (par objet), remplissage du stock
  (cases prises / cases, annexes), objets repris (f.stats.ground_taken, ground_passes), raison du coffre urgent (f.stock_why), refus
  par objet (f.stats.refused) ; sonde fo-ia1 stock_cost (dépôt d'UNE plaque de fer, repris aussitôt : un refus y est compté).
  Lot STOCKAGE-VITAL (C1, C2, C8 de DIAG_CONSO, 7/11) : chaque ligne porte aussi les cumuls des deux compteurs (dépôts refusés, prises de
  tâche, poches pleines) ; FIN donne ce qui est ENTRÉ au stock (différence du contenu depuis DEPART, par objet) et le statut de chaque
  machine à packs rouges de l'équipe (cause d'arrêt, entrées, sortie), relevé direct : [FO-CAPI-CONF] ne relève qu'une fois par minute.
  CRITÈRES (écrits AVANT le passage) : D1 coffre de l'équipe trouvé, au moins 1 700 objets au sol à 10 tuiles au départ ; D2 objets au
  sol à 10 tuiles en BAISSE à la fin (sinon : pourquoi, au rapport).
]]
local R, EVERY, SPAN = 10, 600, 3600

local S = { description = "STOCKAGE-VITAL : objets au sol autour du coffre d'equipe, sur la sauvegarde du DC", check_tick = -1 }

local function team_chest(s)
  local list = s.find_entities_filtered({ name = "fo-team-chest", force = "player" })
  table.sort(list, function(a, b) return a.unit_number < b.unit_number end)
  return list[1], #list
end

local function ground(s, pos)
  local n, by = 0, {}
  for _, e in ipairs(s.find_entities_filtered({ name = "item-on-ground", position = pos, radius = R })) do
    local st = e.stack
    if st and st.valid_for_read then
      n = n + st.count
      by[st.name] = (by[st.name] or 0) + st.count
    end
  end
  local names = {}
  for k in pairs(by) do names[#names + 1] = k end
  table.sort(names)
  local parts = {}
  for _, k in ipairs(names) do parts[#parts + 1] = k .. " " .. by[k] end
  return n, table.concat(parts, ", ")
end

local function probe(ctx)
  if not ctx.has("fo-ia1", "stock_cost") then return {} end
  local ok, res = pcall(ctx.remote, "fo-ia1", "stock_cost", "player", "iron-plate", 1, 1)
  return ok and res or {}
end

local function refused_text(r)
  local names = {}
  for k in pairs(r or {}) do names[#names + 1] = k end
  table.sort(names)
  local parts = {}
  for _, k in ipairs(names) do parts[#parts + 1] = k .. " " .. r[k] end
  return table.concat(parts, ", ")
end

local function line(ctx, label)
  local st = ctx.state()
  local s = ctx.surface()
  local n, by = ground(s, st.pos)
  local pr = probe(ctx)
  ctx.log(string.format("%s : tick %d (+%d), au sol %d a %d tuiles (%s) ; stock %s/%s cases, annexes %s ; repris %s en %s passage(s) ; raison du coffre urgent %s ; refus {%s}",
    label, game.tick, game.tick - st.t0, n, R, by, tostring(pr.fill_used), tostring(pr.fill_size), tostring(pr.annexes),
    tostring(pr.ground_taken), tostring(pr.ground_passes), tostring(pr.why), refused_text(pr.refused)))
  ctx.log(string.format("%s COMPTEURS : depots refuses %s, prises de tache %s dont %s poche(s) pleine(s)", label, tostring(pr.refused_calls),
    tostring(pr.claims), tostring(pr.claim_full)))
  return n, pr
end

--- Ce qui est entré au stock depuis DEPART : différence du contenu par objet, les 14 plus fortes hausses puis les 6 plus fortes baisses.
local function delta_text(c0, c1)
  local d = {}
  for k, v in pairs(c1 or {}) do d[k] = v - ((c0 or {})[k] or 0) end
  for k, v in pairs(c0 or {}) do if not (c1 or {})[k] then d[k] = -v end end
  local up, down = {}, {}
  for k, v in pairs(d) do if v > 0 then up[#up + 1] = k elseif v < 0 then down[#down + 1] = k end end
  table.sort(up, function(a, b) if d[a] ~= d[b] then return d[a] > d[b] end return a < b end)
  table.sort(down, function(a, b) if d[a] ~= d[b] then return d[a] < d[b] end return a < b end)
  local pu, pd = {}, {}
  for i = 1, math.min(14, #up) do pu[i] = up[i] .. " +" .. d[up[i]] end
  for i = 1, math.min(6, #down) do pd[i] = down[i] .. " " .. d[down[i]] end
  return table.concat(pu, ", "), table.concat(pd, ", ")
end

--- C8 : statut de chaque machine à packs rouges de l'équipe du joueur (500 tuiles autour du coffre).
local function red_packs(ctx, s, pos, label)
  local names = {}
  for k, v in pairs(defines.entity_status) do names[v] = k end
  local list = {}
  for _, e in ipairs(s.find_entities_filtered({ type = "assembling-machine", force = "player", position = pos, radius = 500 })) do
    local r = e.get_recipe()
    if r and r.name == "automation-science-pack" then list[#list + 1] = e end
  end
  table.sort(list, function(a, b) return a.unit_number < b.unit_number end)
  local by = {}
  for _, e in ipairs(list) do
    local k = names[e.status] or tostring(e.status)
    by[k] = (by[k] or 0) + 1
  end
  ctx.log(string.format("%s PACKS ROUGES : %d machine(s) ; statuts {%s}", label, #list, refused_text(by)))
  for i = 1, math.min(8, #list) do
    local e = list[i]
    local inp = e.get_inventory(defines.inventory.assembling_machine_input)
    local out = e.get_inventory(defines.inventory.assembling_machine_output)
    ctx.log(string.format("%s PACKS ROUGES : %s unite %d en (%.1f, %.1f) statut %s, entree {%s}, sortie %d, faites %d, energie %.0f", label, e.name,
      e.unit_number, e.position.x, e.position.y, names[e.status] or tostring(e.status), refused_text(inp and inp.get_contents() or {}),
      out and out.get_item_count() or -1, e.products_finished or -1, e.energy or -1))
  end
end

S.init = function(ctx)
  local st = ctx.state()
  local s = ctx.surface()
  st.t0 = game.tick
  S.check_tick = st.t0 + SPAN
  local chest, n = team_chest(s)
  ctx.check(chest ~= nil and st.t0 > 0, "partie du DC chargee, coffre d'equipe trouve", string.format("tick %d, %d coffre(s)", st.t0, n))
  if not chest then return end
  st.pos = { x = chest.position.x, y = chest.position.y }
  ctx.log(string.format("coffre d'equipe en (%.1f, %.1f)", st.pos.x, st.pos.y))
  local _, pr = line(ctx, "DEPART")
  st.n0, st.c0 = _, pr.contents or {}
  red_packs(ctx, s, st.pos, "DEPART")
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.pos then return end
  local dt = e.tick - st.t0
  if dt > 0 and dt % EVERY == 0 and dt < SPAN then line(ctx, "RELEVE") end
end

S.finish = function(ctx)
  local st = ctx.state()
  if not st.pos then
    ctx.check(false, "coffre d'equipe trouve")
    return
  end
  local n, pr = line(ctx, "FIN")
  local up, down = delta_text(st.c0, pr.contents)
  ctx.log(string.format("FIN ENTREES au stock depuis DEPART : {%s} ; SORTIES {%s}", up, down))
  red_packs(ctx, ctx.surface(), st.pos, "FIN")
  ctx.check((st.n0 or 0) >= 1700, "D1 objets au sol au pied du coffre au depart", st.n0)
  ctx.check(n < (st.n0 or 0), "D2 objets au sol en baisse a la fin", string.format("%d -> %d", st.n0 or 0, n))
end

return S
