--[[
  Lot STOCK-ECHELLE : que fait une équipe quand son stock (coffre du QG + annexes) est PLEIN ? Partie du guide
  (verif_guide_common, 30 ouvriers, automatisation et capitalisation allumées comme etape1-guide), puis, si FILL :
  au tick FILL_TICK le coffre du QG de chaque équipe (la vôtre et les factions) est REMPLI à 100 % d'un objet que personne
  ne consomme, et re-rempli avec chaque annexe posée par le jeu toutes les REFILL ticks. Kit de 30 coffres de fer au coffre
  de votre équipe pour que la croissance aille jusqu'au plafond (T.annex.max). Sans FILL : le témoin (même kit, même graine).
  Relevé toutes les SAMPLE ticks (journal [FO-STOCK-PLEIN]) : cases du QG et des annexes, cases occupées dans les corps des
  PNJ (hors arme et munitions : ce qu'ils n'ont pas pu déposer), objets au sol près du QG, production cumulée de plaques
  (statistiques de la force). Lecture : tools/autotest/stock_plein_lire.py (plein contre témoin).
  Lancement : banc.py ... -- 10000 stock-plein <source> (et stock-plein-temoin), même --graine.
]]
return function(FILL)
local base = require("scenarios/verif_guide_common")(30)
local FILL_TICK, REFILL, SAMPLE, CHECK = 1200, 300, 600, 9600
local JUNK = "raw-fish"
local TAG = "[FO-STOCK-PLEIN] "
local KIT = 30

local function hq_of(s, force)
  return s.find_entities_filtered({ name = { "fo-faction-hq", "fo-team-chest" }, force = force, limit = 1 })[1]
end

local function annex_of(s, hq, force)
  local p = hq.position
  return s.find_entities_filtered({ area = { { p.x - 8, p.y + 3 }, { p.x + 16, p.y + 22 } }, force = force,
    name = { "iron-chest", "wooden-chest", "steel-chest" } })
end

local function fill(inv)
  if inv.count_empty_stacks() == 0 then return 0 end
  return inv.insert({ name = JUNK, count = 100 * #inv })
end

local function forces_of(ctx)
  local out = { "player" }
  for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if row.key ~= "player" and row.force then out[#out + 1] = row.force end
  end
  return out
end

local init0, tick0 = base.init, base.tick
base.description = FILL and "STOCK-PLEIN : stock rempli a 100 % (QG et annexes), observation des equipes"
  or "STOCK-PLEIN TEMOIN : meme partie et meme kit, stock non rempli"
base.check_tick = CHECK

base.init = function(ctx)
  ctx.call("war_setting", "fo-war-ia3e", true)
  ctx.call("war_setting", "fo-war-capi", true)
  if init0 then init0(ctx) end
  local st = ctx.state()
  if st.chest and st.chest.valid then st.chest.insert({ name = "iron-chest", count = KIT }) end
  st.samples = {}
end

local function sample(ctx, e)
  local st = ctx.state()
  local s = ctx.surface()
  for _, force in ipairs(forces_of(ctx)) do
    local hq = hq_of(s, force)
    if hq and hq.valid then
      local inv = hq.get_inventory(defines.inventory.chest)
      local qu, qs = #inv - inv.count_empty_stacks(), #inv
      local au, as, na = 0, 0, 0
      for _, a in ipairs(annex_of(s, hq, force)) do
        local ai = a.get_inventory(defines.inventory.chest)
        na, au, as = na + 1, au + #ai - ai.count_empty_stacks(), as + #ai
      end
      local n, carried, items = 0, 0, {}
      for _, c in ipairs(s.find_entities_filtered({ force = force, type = "character" })) do
        if not c.player then
          n = n + 1
          local mi = c.get_main_inventory()
          if mi then
            carried = carried + #mi - mi.count_empty_stacks()
            for name, cnt in pairs(mi.get_contents()) do items[name] = (items[name] or 0) + cnt end
          end
        end
      end
      local names = {}
      for name in pairs(items) do names[#names + 1] = name end
      table.sort(names, function(a, b) if items[a] ~= items[b] then return items[a] > items[b] end return a < b end)
      local top = {}
      for i = 1, math.min(3, #names) do top[#top + 1] = names[i] .. ":" .. items[names[i]] end
      local p = hq.position
      local ground = s.count_entities_filtered({ area = { { p.x - 40, p.y - 40 }, { p.x + 40, p.y + 40 } }, name = "item-on-ground" })
      local fstat = game.forces[force] and game.forces[force].item_production_statistics
      local iron = fstat and fstat.get_input_count("iron-plate") or 0
      local copper = fstat and fstat.get_input_count("copper-plate") or 0
      ctx.log(TAG .. string.format("t=%d %s | qg=%d/%d annexes=%d(%d/%d) | pnj=%d portes_cases=%d sol=%d | prod_fer=%d prod_cuivre=%d | stock_fer=%d | top=%s",
        e.tick, force, qu, qs, na, au, as, n, carried, ground, iron, copper,
        hq.get_item_count("iron-plate"), table.concat(top, ",")))
      st.samples[#st.samples + 1] = { tick = e.tick, force = force, qu = qu, qs = qs, na = na, au = au, as = as, n = n,
        carried = carried, ground = ground, iron = iron }
    end
  end
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local s = ctx.surface()
  local st = ctx.state()
  if FILL and e.tick >= FILL_TICK and e.tick % REFILL == 0 then
    local put = 0
    for _, force in ipairs(forces_of(ctx)) do
      local hq = hq_of(s, force)
      if hq and hq.valid then
        put = put + fill(hq.get_inventory(defines.inventory.chest))
        for _, a in ipairs(annex_of(s, hq, force)) do put = put + fill(a.get_inventory(defines.inventory.chest)) end
      end
    end
    st.junk = (st.junk or 0) + put
    if e.tick == FILL_TICK then ctx.log(TAG .. "stock rempli a 100 % : " .. put .. " " .. JUNK) end
  end
  if e.tick >= SAMPLE and e.tick % SAMPLE == 0 then sample(ctx, e) end
end

local function window(rows, force, key, t0)
  local sum, n = 0, 0
  for _, r in ipairs(rows) do
    if r.force == force and r.tick >= t0 then sum, n = sum + r[key], n + 1 end
  end
  return n > 0 and sum / n or 0, n
end

base.finish = function(ctx)
  local st = ctx.state()
  local rows = st.samples or {}
  ctx.check(#rows >= 10, "releves du stock pris", #rows)
  local mid = CHECK / 2
  for _, force in ipairs(forces_of(ctx)) do
    local carried, n = window(rows, force, "carried", mid)
    local pnj = window(rows, force, "n", mid)
    local ground = window(rows, force, "ground", mid)
    local qu = window(rows, force, "qu", mid)
    local qs = window(rows, force, "qs", mid)
    local fa = window(rows, force, "au", mid)
    local fs = window(rows, force, "as", mid)
    local na = window(rows, force, "na", mid)
    local first, last
    for _, r in ipairs(rows) do
      if r.force == force then first = first or r; last = r end
    end
    local per_min = (first and last and last.tick > first.tick) and (last.iron - first.iron) * 3600 / (last.tick - first.tick) or 0
    ctx.log(TAG .. string.format("RESUME %s | 2e moitie (%d releves) : qg %.1f/%.0f annexes %.1f (%.0f/%.0f cases) | pnj %.1f portes_cases %.1f (%.2f par pnj) sol %.1f | plaques de fer produites %.1f/min",
      force, n, qu, qs, na, fa, fs, pnj, carried, pnj > 0 and carried / pnj or 0, ground, per_min))
  end
  if FILL then
    local qu, qs = window(rows, "player", "qu", mid), window(rows, "player", "qs", mid)
    ctx.check(qs > 0 and qu >= 0.95 * qs, "le coffre du QG de votre equipe est plein (>= 95 % des cases) sur la 2e moitie", string.format("%.1f/%.0f", qu, qs))
    local na = window(rows, "player", "na", mid)
    ctx.log(TAG .. string.format("annexes de votre equipe a la 2e moitie : %.1f (plafond T.annex.max)", na))
  end
  ctx.check(true, "mesure sans seuil : lecture par tools/autotest/stock_plein_lire.py (plein contre temoin)")
end

return base
end
