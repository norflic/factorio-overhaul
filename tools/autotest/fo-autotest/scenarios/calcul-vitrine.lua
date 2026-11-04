-- Scénario greffé du lot MACHINES-CALCUL (3/11) : les 20 machines de la chaîne du calcul avec leur vrai visuel, À L'ARRÊT
-- (alimentées, recette posée, rien à fabriquer : corps, pièce mobile figée, ombre), plus 3 machines à fluide dans les 4
-- directions (raccords tracés par le moteur ; le dessin, lui, n'a qu'une vue). Au travail : calcul-chaines et crafts-chaines.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui MACHINES-CALCUL -- 300 calcul-vitrine <source>            (contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache" --qui MACHINES-CALCUL -- 300 calcul-vitrine <source>
-- Captures : chaque rangée au zoom 1, chaque machine au zoom 2, les 4 directions au zoom 1 ; table fo-shots/calcul-vitrine-sites.tsv.

local X0, Y0 = 3600, 3000
local PAS_X, PAS_Y = 9, 11
-- par âge, puis par nom (même ordre que la planche fo-logs/2026-11-03_MACHINES-CALCUL/planche.png)
local MACHINES = {
  "fo-circuit-printer", "fo-sintering-furnace", "fo-arc-furnace", "fo-chiller", "fo-cleanroom",
  "fo-cooling-tower", "fo-crystal-lithograph", "fo-crystal-puller", "fo-data-center", "fo-die-prober",
  "fo-fiber-tower", "fo-packaging-line", "fo-plasma-etcher", "fo-rack-integrator", "fo-smt-line",
  "fo-wire-saw", "fo-cryogenic-unit", "fo-data-center-2", "fo-dilution-fridge", "fo-quantum-lab",
}
-- DA-CALCUL (4/11) : la tour de refroidissement aussi (ses tuyaux dessinés touchaient les bords nord et sud)
local DIRECTIONS = { "fo-chiller", "fo-data-center-2", "fo-cryogenic-unit", "fo-cooling-tower" }
local DECALAGE_Y = { 0, 11, 22, 33 } -- une rangée par machine : côté + 5 tuiles au moins
local DIRS = { { "N", defines.direction.north }, { "E", defines.direction.east }, { "S", defines.direction.south },
               { "O", defines.direction.west } }

--- Première recette (par nom) d'une catégorie de la machine, ou nil.
local function recette(proto)
  local cats = proto.crafting_categories or {}
  local noms = {}
  for n, r in pairs(game.recipe_prototypes) do
    if cats[r.category] then noms[#noms + 1] = n end
  end
  table.sort(noms)
  -- une recette à fluide d'abord : sans elle, les raccords n'existent pas (et la direction est ignorée, F91)
  for _, n in ipairs(noms) do
    local r = game.recipe_prototypes[n]
    for _, i in ipairs(r.ingredients) do if i.type == "fluid" then return n end end
    for _, p in ipairs(r.products) do if p.type == "fluid" then return n end end
  end
  return noms[1]
end

local function cote(name)
  local b = game.entity_prototypes[name].selection_box
  return math.floor(b.right_bottom.x - b.left_top.x + 0.5)
end

return {
  description = "MACHINES-CALCUL : les 20 machines du calcul a l'arret, et 4 machines a fluide dans les 4 directions",
  base = nil,
  check_tick = 200,
  shots_delay = 240,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites, st.dirs = {}, {}
    ctx.prepare_area(X0 - 10, Y0 - 12, X0 + 5 * PAS_X + 10, Y0 + 6 * PAS_Y + 10, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 150, Y0 - 150 }, { X0 + 200, Y0 + 220 } } })) do
      en.destroy()
    end
    ctx.power(X0 - 6, Y0 - 8)
    ctx.power(X0 + 5 * PAS_X + 4, Y0 + 5 * PAS_Y)
    local poses, avec_recette = 0, 0
    for i, name in ipairs(MACHINES) do
      local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
      local c = cote(name)
      local px = X0 + col * PAS_X + (c % 2 == 1 and 0.5 or 0)
      local py = Y0 + row * PAS_Y + (c % 2 == 1 and 0.5 or 0)
      local r = recette(game.entity_prototypes[name])
      local e = s.create_entity({ name = name, position = { px, py }, force = "player", recipe = r })
      if e then
        poses = poses + 1
        if e.get_recipe() then avec_recette = avec_recette + 1 end
      end
      st.sites[#st.sites + 1] = { name = name, x = px, y = py, side = c, row = row, e = e }
    end
    ctx.check(poses == #MACHINES, "machines du calcul posees", poses .. " / " .. #MACHINES)
    ctx.check(avec_recette == #MACHINES, "recette posee sur chaque machine", avec_recette .. " / " .. #MACHINES)
    local y = Y0 + 4 * PAS_Y + 2
    local tournees = 0
    for j, name in ipairs(DIRECTIONS) do
      local c = cote(name)
      local r = recette(game.entity_prototypes[name])
      for k, d in ipairs(DIRS) do
        local px = X0 + (k - 1) * (c + 4) + (c % 2 == 1 and 0.5 or 0)
        local py = y + DECALAGE_Y[j] + (c % 2 == 1 and 0.5 or 0)
        local e = s.create_entity({ name = name, position = { px, py }, force = "player", direction = d[2], recipe = r })
        if e and e.direction == d[2] then tournees = tournees + 1 end
        st.dirs[#st.dirs + 1] = { name = name, dir = d[1], x = px, y = py, side = c, j = j }
      end
    end
    ctx.check(tournees == 4 * #DIRECTIONS, "machines a fluide posees dans les 4 directions", tournees .. " / " .. 4 * #DIRECTIONS)
  end,

  finish = function(ctx)
    local st = ctx.state()
    local ok, ko = 0, {}
    for _, c in ipairs(st.sites) do
      if c.e and c.e.valid and c.e.energy > 0 then ok = ok + 1 else ko[#ko + 1] = c.name end
    end
    ctx.check(ok == #MACHINES, "machines alimentees au tick 200", ok .. " / " .. #MACHINES ..
      (#ko > 0 and (" ; sans courant : " .. table.concat(ko, ",")) or ""))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tmachine\tdirection\tzoom\tx\ty" }
    for row = 0, 3 do
      local cx, cy = X0 + 2 * PAS_X, Y0 + row * PAS_Y - 1.5
      local nm = string.format("rangee-%d-z1", row + 1)
      add(nm, cx, cy, 1, 0, { res = { (5 * PAS_X + 4) * 32, (PAS_Y + 2) * 32 }, info = false, aa = true })
      L[#L + 1] = string.format("%s\t-\t-\t1\t%.2f\t%.2f", nm, cx, cy)
    end
    for i, c in ipairs(st.sites) do
      local nm = string.format("m%02d-%s-z2", i, c.name)
      add(nm, c.x + 0.8, c.y - 1.2, 2, 0, { res = { (c.side + 6) * 64, (c.side + 6) * 64 }, info = false, aa = true })
      L[#L + 1] = string.format("%s\t%s\tN\t2\t%.2f\t%.2f", nm, c.name, c.x, c.y)
    end
    local vus = {}
    for _, d in ipairs(st.dirs) do
      if not vus[d.name] then
        vus[d.name] = true
        local cx, cy = d.x + 1.5 * (d.side + 4), d.y - 1.2
        local nm = "directions-" .. d.name .. "-z1"
        add(nm, cx, cy, 1, 0, { res = { (4 * (d.side + 4) + 4) * 32, (d.side + 7) * 32 }, info = false, aa = true })
        L[#L + 1] = string.format("%s\t%s\tNESO\t1\t%.2f\t%.2f", nm, d.name, cx, cy)
      end
    end
    game.write_file("fo-shots/calcul-vitrine-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
