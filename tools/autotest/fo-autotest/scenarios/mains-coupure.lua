--[[
  Lot MAINS-CHAINE (29/10) : COUPURE DU COURANT. La partie d'etape1-guide (30 ouvriers, automatisation et capitalisation
  allumees, releves [FO-FONCTION] dont le genre `chaine`), puis, au tick CUT (30 min), TOUTE generation d'electricite est
  arretee (generateurs, panneaux solaires, generateurs a combustion : `active = false`), et reprise toutes les 30 s pour les
  generateurs poses ensuite. Symptome du DC (28/10 soir) : « workers qui se mettent a miner a la main le fer puis le garder en
  inventaire, et continuer en boucle [...] survient surtout quand l'electricite est coupee ».
  Lecture : genre `chaine` des fenetres m40 et m50 (et m60), compteurs `fonte_vide`, `depot_refuse`, `mine_zero`, `fondu`,
  `mine_ore` ; outil tools/autotest/chaine_mesures.py. Rien n'entre dans le BILAN sauf la coupure elle-meme.
  Lancement : banc.py --out <archive> --qui MAINSC -- 216300 mains-coupure <source>   (graine : --graine N).
]]
local base = require("scenarios/etape1-guide")
local tick0, finish0 = base.tick, base.finish

local CUT = 30 * 3600
local TAG = "[FO-MAINS-COUPURE] "
local TYPES = { "generator", "solar-panel", "burner-generator", "electric-energy-interface" }

base.description = base.description .. " -- COUPURE du courant a 30 min"

local function cut(ctx, s, e)
  local n, by_force = 0, {}
  for _, ent in ipairs(s.find_entities_filtered({ type = TYPES })) do
    if ent.active then
      ent.active = false
      n = n + 1
      by_force[ent.force.name] = (by_force[ent.force.name] or 0) + 1
    end
  end
  local st = ctx.state()
  st.cut_total = (st.cut_total or 0) + n
  if n > 0 then
    local names = {}
    for k in pairs(by_force) do names[#names + 1] = k end
    table.sort(names)
    local parts = {}
    for _, k in ipairs(names) do parts[#parts + 1] = k .. "=" .. by_force[k] end
    ctx.log(string.format("coupure minute %.1f : %d generateur(s) arrete(s) (%s)", e.tick / 3600, n, table.concat(parts, " ")))
  end
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick >= CUT and e.tick % 1800 == 0 then cut(ctx, ctx.surface(), e) end
  if e.tick == CUT + 900 then
    -- 15 s apres : les generateurs poses avant la coupure sont a l'arret. NE PAS lire energy_generated_last_tick : un generateur
    -- desactive garde sa derniere valeur (418 a 2 447 kW lus apres la coupure, alors que [FO-FONCTION] statut donne
    -- `disabled_by_script` et les bras `no_power` : archives MAINS du 29/10). On compte l'etat reel.
    local off, on = 0, 0
    for _, ent in ipairs(ctx.surface().find_entities_filtered({ type = "generator" })) do
      if ent.status == defines.entity_status.disabled_by_script then off = off + 1 else on = on + 1 end
    end
    local st = ctx.state()
    st.gen_off, st.gen_on = off, on
    ctx.log(string.format("coupure : generateurs desactives %d, encore actifs %d (15 s apres)", off, on))
  end
end

base.finish = function(ctx)
  if finish0 then finish0(ctx) end
  local st = ctx.state()
  ctx.check((st.cut_total or 0) >= 1, "coupure : au moins un generateur arrete", st.cut_total)
  -- (un generateur pose par un PNJ dans les 15 s apres la coupure compte dans gen_on : il n'est coupe qu'a la reprise suivante)
  ctx.check((st.gen_off or 0) >= 1, "coupure : au moins un generateur desactive (statut) 15 s apres", (st.gen_off or 0) .. "/" .. (st.gen_on or 0))
end

return base
