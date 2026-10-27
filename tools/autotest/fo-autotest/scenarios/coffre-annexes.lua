--[[
  Lot COFFRE : annexes du QG en moteur réel (script/team/stock.lua). La partie du guide (verif_guide_common), puis au tick
  4 000 le coffre de votre équipe est REMPLI de déchets jusqu'à plus de 90 % de ses 96 cases (bois, charbon, pierre, plaques
  de cuivre) : le jeu doit poser des coffres au sud du QG, y ranger l'excédent (le coffre du QG revient sous 80 %), sans rien
  perdre, et une prise d'un objet rangé doit réussir (tâche d'un PNJ : tourelles, packs…). Contrôles au tick 12 000.
  Lancement : `banc.py ... -- 12200 coffre-annexes <source>` ; journal : [FO-COFFRE].
]]
local base = require("scenarios/verif_guide_common")(4)

local FILL_TICK, CHECK = 4000, 12000
local JUNK = { { "wood", 4000 }, { "coal", 1500 }, { "stone", 1200 }, { "copper-plate", 1500 } }
local TAG = "[FO-COFFRE] "

local function fill_of(chest)
  local inv = chest.get_inventory(defines.inventory.chest)
  return #inv - inv.count_empty_stacks(), #inv
end

local function annex_chests(s, chest)
  local out = {}
  for _, e in ipairs(s.find_entities_filtered({ area = { { chest.position.x - 8, chest.position.y + 3 },
    { chest.position.x + 16, chest.position.y + 22 } }, force = "player", name = { "iron-chest", "wooden-chest" } })) do
    out[#out + 1] = e
  end
  return out
end

local function total(s, chest, item)
  local n = chest.get_item_count(item)
  for _, e in ipairs(annex_chests(s, chest)) do n = n + e.get_item_count(item) end
  return n
end

local tick0 = base.tick
base.description = "COFFRE : annexes du QG, coffre rempli de dechets puis range, rien de perdu"
base.check_tick = CHECK

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local st = ctx.state()
  local chest = st.chest
  if not (chest and chest.valid) then return end
  local s = ctx.surface()
  if e.tick == FILL_TICK then
    st.before = {}
    for _, j in ipairs(JUNK) do st.before[j[1]] = total(s, chest, j[1]) end
    st.put = {}
    for _, j in ipairs(JUNK) do st.put[j[1]] = chest.insert({ name = j[1], count = j[2] }) end -- le coffre peut refuser une partie
    local u, n = fill_of(chest)
    st.filled = { u, n }
    ctx.log(TAG .. string.format("coffre rempli de dechets : %d/%d cases", u, n))
  elseif st.filled and e.tick > FILL_TICK and e.tick % 600 == 0 then
    local u, n = fill_of(chest)
    local annexes = annex_chests(s, chest)
    local used_a, size_a = 0, 0
    for _, a in ipairs(annexes) do
      local inv = a.get_inventory(defines.inventory.chest)
      used_a, size_a = used_a + #inv - inv.count_empty_stacks(), size_a + #inv
    end
    local parts = {}
    for _, j in ipairs(JUNK) do
      parts[#parts + 1] = string.format("%s %d+%d", j[1], chest.get_item_count(j[1]), total(s, chest, j[1]) - chest.get_item_count(j[1]))
    end
    ctx.log(TAG .. string.format("tick %d : coffre %d/%d, annexes %d (%d/%d) | %s", e.tick, u, n, #annexes, used_a, size_a,
      table.concat(parts, " ")))
    st.max_annexes = math.max(st.max_annexes or 0, #annexes)
    if u >= n * 0.9 and not st.full_since then st.full_since = e.tick end
    if u < n * 0.9 then st.full_since = nil end
    if st.full_since and e.tick - st.full_since > (st.full_max or 0) then st.full_max = e.tick - st.full_since end
  end
end

base.finish = function(ctx)
  local st = ctx.state()
  local s = ctx.surface()
  local chest = st.chest
  ctx.check(chest ~= nil and chest.valid, "coffre d'equipe present")
  if not (chest and chest.valid) then return end
  ctx.check(st.put ~= nil and (st.put.wood or 0) > 0, "dechets inseres", st.put and st.put.wood)
  ctx.check(st.filled ~= nil and st.filled[1] >= st.filled[2] * 0.85, "coffre rempli de dechets (>= 85 % des cases)",
    st.filled and (st.filled[1] .. "/" .. st.filled[2]) or "non rempli")
  local annexes = annex_chests(s, chest)
  ctx.check(#annexes >= 1, "au moins une annexe posee au sud du QG", #annexes)
  local u, n = fill_of(chest)
  ctx.check(u <= n * 0.8, "coffre du QG revenu a 80 % ou moins des cases", u .. "/" .. n)
  ctx.check((st.full_max or 0) <= 7200, "coffre du QG jamais a 90 % ou plus plus de 2 min de suite (T.annex)", st.full_max or 0)
  local lost = {}
  for _, j in ipairs(JUNK) do
    local want = (st.before[j[1]] or 0) + (st.put[j[1]] or 0)
    local have = total(s, chest, j[1])
    -- la partie consomme (plaques, charbon, pierre) et ramasse (bois des arbres abattus) : le bois, que personne ne consomme
    -- ici, ne descend jamais sous ce qui a ete range ; les autres ne tombent pas sous la moitie
    local floor = j[1] == "wood" and 0.95 or 0.5
    if have < want * floor then lost[#lost + 1] = string.format("%s %d/%d", j[1], have, want) end
  end
  ctx.check(#lost == 0, "rien de perdu (QG + annexes : le bois range reste, le reste ne tombe pas sous la moitie)", table.concat(lost, ", "))
  ctx.check(chest.get_item_count("wood") >= 100 and total(s, chest, "wood") >= 4000,
    "le bois range est toujours au stock (QG + annexes)", total(s, chest, "wood"))
end

-- Images (session avec images) : le QG de votre équipe et ses annexes, après le rangement.
base.shots_delay = CHECK + 60
base.shots = function(ctx, add)
  local chest = ctx.state().chest
  if chest and chest.valid then
    add("coffre-annexes-qg", chest.position.x + 4, chest.position.y + 8, 0.9)
    add("coffre-annexes-large", chest.position.x, chest.position.y + 6, 0.35)
  end
end

return base
