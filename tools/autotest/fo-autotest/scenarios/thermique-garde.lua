--[[
  Lot THERMIQUE2, essai 3 (demande du lead, 3/11) : la garde « minerai brut au-delà de 3 000 au stock libre : plus de brûleur » (B.raw_full,
  shared/ai3/buts.lua) en moteur réel, sur la partie de dc-croissance (3 factions).
    - tick 120 : 4 000 charbons posés dans le coffre du QG de chaque faction (le stock libre de l'équipe = QG + annexes) ;
    - de la minute 1 à la minute 12, toutes les 10 s : foreuses à combustion de la faction sur du charbon, et charbon au stock (conteneurs de la
      force à 26 tuiles du QG, comme le relevé [FO-REGARD] R) ;
    - contrôle : aucune faction ne gagne de brûleur sur le charbon entre deux relevés quand son stock de charbon était ≥ 3 000 au premier ; au
      moins une faction jugeable (un avant-poste de charbon, stock ≥ 3 000 tout du long).
  Témoin attendu sans le lot (integ-0642 2c181c22) : la couverture d'Émeraude passe de 4 à 12 brûleurs de charbon entre 6 et 8 min.
  Lancement : banc.py --qui THERMIQUE2 -- 44000 thermique-garde <source>. Journal : [FO-THERMIQUE-GARDE].
]]
local CHECK = 43200
local base = require("scenarios/dc_evolution_common")(CHECK)
local FUEL, DOSE, LIMIT, START, EVERY = "coal", 4000, 3000, 3600, 600

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  return ok and rows or {}
end

local function hq_of(s, force)
  local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
  return (hq and hq.valid) and hq or nil
end

local function burners_on_fuel(s, force)
  local n = 0
  for _, d in ipairs(s.find_entities_filtered({ type = "mining-drill", force = force })) do
    if d.valid and d.prototype.burner_prototype ~= nil then
      local t = d.mining_target
      if t and t.valid and t.name == FUEL then n = n + 1 end
    end
  end
  return n
end

local function stock_of(s, force, center)
  local n = 0
  for _, c in ipairs(s.find_entities_filtered({ type = { "container", "logistic-container" }, force = force, position = center, radius = 26 })) do
    if c.valid then n = n + c.get_item_count(FUEL) end
  end
  return n
end

local function gst(ctx)
  local st = ctx.state()
  st.garde = st.garde or { rows = {}, order = {} }
  return st.garde
end

local tick0 = base.tick
base.description = "THERMIQUE2 : charbon au-dela de 3 000 au stock, aucun brûleur de charbon ajouté"
base.tick = function(ctx, e)
  tick0(ctx, e)
  local s = ctx.surface()
  local g = gst(ctx)
  if e.tick == 120 then
    for _, row in ipairs(teams()) do
      if row.force ~= "player" then
        local hq = hq_of(s, row.force)
        if hq then
          local put = hq.insert({ name = FUEL, count = DOSE })
          ctx.log(string.format("[FO-THERMIQUE-GARDE] %s : %d charbons poses au QG", row.key, put))
        end
      end
    end
  end
  if e.tick >= START and e.tick <= CHECK and e.tick % EVERY == 0 then
    for _, row in ipairs(teams()) do
      if row.force ~= "player" then
        local hq = hq_of(s, row.force)
        if hq then
          local r = g.rows[row.key]
          if not r then
            r = { burners0 = burners_on_fuel(s, row.force), min_stock = 1e9, added_full = 0, added_low = 0, samples = 0 }
            g.rows[row.key] = r
            g.order[#g.order + 1] = row.key
          end
          local b, k = burners_on_fuel(s, row.force), stock_of(s, row.force, hq.position)
          if r.last_b and b > r.last_b then
            if r.last_k >= LIMIT then
              r.added_full = r.added_full + (b - r.last_b)
              ctx.log(string.format("[FO-THERMIQUE-GARDE] %s tick %d : +%d brûleur(s) de charbon avec %d charbons au stock au releve d'avant", row.key, e.tick,
                b - r.last_b, r.last_k))
            else
              r.added_low = r.added_low + (b - r.last_b)
            end
          end
          r.last_b, r.last_k, r.samples = b, k, r.samples + 1
          if k < r.min_stock then r.min_stock = k end
        end
      end
    end
  end
end
base.finish = function(ctx)
  local g = gst(ctx)
  local judged, bad = 0, 0
  for _, key in ipairs(g.order) do
    local r = g.rows[key]
    ctx.log(string.format("[FO-THERMIQUE-GARDE] %s : brûleurs de charbon %d -> %d, stock de charbon minimal %d, ajoutés stock >= %d : %d, sous : %d (%d releves)",
      key, r.burners0, r.last_b or -1, r.min_stock, LIMIT, r.added_full, r.added_low, r.samples))
    if r.burners0 > 0 and r.min_stock >= LIMIT then judged = judged + 1 end
    bad = bad + r.added_full
  end
  ctx.check(judged > 0, "au moins une faction jugeable (avant-poste de charbon, stock >= 3 000 tout du long)", judged)
  ctx.check(bad == 0, "aucun brûleur de charbon ajouté quand le stock de charbon était >= 3 000", bad)
end
return base
