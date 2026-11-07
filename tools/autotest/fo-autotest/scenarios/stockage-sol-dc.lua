--[[
  Lot STOCKAGE-VITAL (objets au sol, 7/11, demande du lead) : sur la SAUVEGARDE du DC (fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip,
  0.6.53 ; 1 774 objets au pied du coffre de l'équipe, recensement de x10-sprites), Stock.pick_ground reprend-il les objets au sol ?
  Le coffre de l'équipe était PLEIN au journal (1 472/1 472 cases à la minute 172) : sans place, rien n'est repris.
  Lancement : `banc.py --sauvegarde <zip> --qui STOCKAGE-VITAL -- 3700 stockage-sol-dc <source>` ; la partie du banc est une COPIE.

  Relevé au départ puis toutes les 600 ticks : objets au sol à 10 tuiles au plus du coffre de l'équipe (par objet), remplissage du stock
  (cases prises / cases, annexes), objets repris (f.stats.ground_taken, ground_passes), raison du coffre urgent (f.stock_why), refus
  par objet (f.stats.refused) ; sonde fo-ia1 stock_cost (dépôt d'UNE plaque de fer, repris aussitôt : un refus y est compté).
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
  return n
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
  st.n0 = line(ctx, "DEPART")
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
  local n = line(ctx, "FIN")
  ctx.check((st.n0 or 0) >= 1700, "D1 objets au sol au pied du coffre au depart", st.n0)
  ctx.check(n < (st.n0 or 0), "D2 objets au sol en baisse a la fin", string.format("%d -> %d", st.n0 or 0, n))
end

return S
