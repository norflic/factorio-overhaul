-- Scénario greffé du lot RB-0 (31/10), essai E2 : grosses boîtes de collision d'une `unit` (PLAN.md §3).
-- À LANCER SUR LA COPIE JETABLE : banc.py ... --qui RB0 -- 2500 rb0-boite <copie>
--
-- 5 boîtes (±0,4 ; ±0,6 ; ±0,9 ; ±1,4 ; ±2,4) x 7 terrains x 4 répliques (une voie par unité, 12 tuiles de pas) :
--   ouvert ; porte de 2, 3, 5, 8 tuiles (barrière de murs de pierre perpendiculaire à la marche, sur tout le bloc, trouée
--   de la largeur dite à chaque voie : aucun détour possible à moins de 10 tuiles) ; forêt dense (arbres au hasard sur
--   20 x 10 tuiles) ; falaise (barrière nord-sud, trouée de 4 tuiles).
-- Chaque unité (force « rb0 ») part de x0, ordre go_to_location vers x0 + 50 (rayon 2, aucune distraction). Mesures par
-- cellule : arrivées (distance au but <= 3,5 à la fin, soit 2400 ticks), échecs signalés par on_ai_command_completed
-- (result == fail), durée moyenne des arrivées. Les unités n'ont pas d'ennemi : seule la boîte joue.

local C = require("scenarios/rb0_common")

local T0 = 60
local CHECK = 2450
local BOITES = { { "04", 0.4 }, { "06", 0.6 }, { "09", 0.9 }, { "14", 1.4 }, { "24", 2.4 } }
local TERRAINS = { "ouvert", "porte2", "porte3", "porte5", "porte8", "foret", "falaise" }
local REPL = 4
local PAS_Y, LARG_X, BLOC_Y = 12, 80, 60
local BX0, BY0 = 3000, 3000
local LONG = 50

local function cellule(si, ti)
  return BX0 + LARG_X * (si - 1), BY0 + BLOC_Y * (ti - 1)
end

script.on_event(defines.events.on_ai_command_completed, function(e)
  local g = C.g()
  local u = g.unites and g.unites[e.unit_number]
  if u and not u.fin then
    local pos = u.e and u.e.valid and u.e.position or nil
    u.fin = { tick = e.tick, result = e.result, distraction = e.was_distracted, x = pos and pos.x, y = pos and pos.y }
  end
end)

return {
  description = "RB-0 E2 : boites de collision 0,4 a 2,4 contre couloirs, foret, falaise",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    local noms = {}
    for _, b in ipairs(BOITES) do noms[#noms + 1] = "rb0-u-" .. b[1] end
    if not C.exige(ctx, noms, "5 unites rb0-u-*") then return end
    local s = ctx.surface()
    C.force("rb0")
    game.map_settings.enemy_expansion.enabled = false
    local x1, y1 = BX0 - 10, BY0 - 10
    local x2, y2 = BX0 + LARG_X * #BOITES, BY0 + BLOC_Y * #TERRAINS
    ctx.prepare_area(x1, y1, x2, y2, "grass-1")
    C.sans_ennemis(s, x1, y1, x2, y2)
    local rng = game.create_random_generator(20261031)
    st.cells = {}
    local murs, arbres, falaises, falaises_ko = 0, 0, 0, 0
    for si, b in ipairs(BOITES) do
      for ti, terr in ipairs(TERRAINS) do
        local cx, cy = cellule(si, ti)
        local cell = { boite = b[1], terrain = terr, unites = {} }
        st.cells[#st.cells + 1] = cell
        for r = 1, REPL do
          local ly = cy + 6 + (r - 1) * PAS_Y -- axe de la voie (frontière de tuile : entier)
          local gap = ({ porte2 = 2, porte3 = 3, porte5 = 5, porte8 = 8 })[terr]
          local but_y = ly
          if gap then
            -- BARRIERE perpendiculaire (x = cx + 25, 1 tuile d'epaisseur) sur toute la hauteur du bloc plus 8 tuiles de chaque
            -- cote, trouee de `gap` tuiles centree sur l'axe de CHAQUE voie ; le but est au centre de la trouee de la voie.
            local haut = math.floor(ly - gap / 2)
            but_y = haut + gap / 2
            if r == 1 then
              for y = cy - 8, cy + 6 + (REPL - 1) * PAS_Y + 8 do
                local libre = false
                for rr = 1, REPL do
                  local lyy = cy + 6 + (rr - 1) * PAS_Y
                  local hh = math.floor(lyy - gap / 2)
                  if y >= hh and y < hh + gap then libre = true end
                end
                if not libre then
                  s.create_entity({ name = "stone-wall", position = { cx + 25.5, y + 0.5 }, force = "player" })
                  murs = murs + 1
                end
              end
            end
          elseif terr == "foret" then
            for _ = 1, 40 do
              local px = cx + 15 + rng(20) - 1 + 0.5
              local py = ly - 5 + rng(10) - 1 + 0.5
              if s.create_entity({ name = "tree-02", position = { px, py } }) then arbres = arbres + 1 end
            end
          elseif terr == "falaise" then
            for k = -1, 1 do
              if k ~= 0 then
                local ok = s.create_entity({ name = "cliff", position = { cx + 25, ly + 4 * k }, cliff_orientation = "north-to-south" })
                if ok then falaises = falaises + 1 else falaises_ko = falaises_ko + 1 end
              end
            end
          end
          local u = s.create_entity({ name = "rb0-u-" .. b[1], position = { cx + 2, but_y }, force = "rb0" })
          cell.unites[#cell.unites + 1] = { e = u, but = { cx + LONG, but_y }, depart = { cx + 2, but_y } }
        end
      end
    end
    ctx.log(string.format("masque de collision de rb0-u-04 : %s ; de medium-biter : %s",
      serpent.line(game.entity_prototypes["rb0-u-04"].collision_mask), serpent.line(game.entity_prototypes["medium-biter"].collision_mask)))
    ctx.log(string.format("murs=%d arbres=%d falaises=%d (refusees %d)", murs, arbres, falaises, falaises_ko))
    st.murs, st.falaises = murs, falaises
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    if e.tick == T0 then
      local g = C.g()
      g.unites = g.unites or {}
      local n, ko = 0, 0
      for _, cell in ipairs(st.cells) do
        for _, u in ipairs(cell.unites) do
          if u.e and u.e.valid then
            g.unites[u.e.unit_number] = u
            u.e.set_command({ type = defines.command.go_to_location, destination = { x = u.but[1], y = u.but[2] }, radius = 2,
              distraction = defines.distraction.none })
            n = n + 1
          else
            ko = ko + 1
          end
        end
      end
      st.ordres = n
      st.sans_unite = ko
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    ctx.log("E2 ordres donnes=" .. tostring(st.ordres) .. " unites non posees=" .. tostring(st.sans_unite))
    ctx.log("E2 boite ; terrain ; arrivees/" .. REPL .. " ; echecs signales ; encore en route ; distance moyenne au but des non-arrives ; duree moyenne (ticks) des arrivees")
    local res = {}
    for _, cell in ipairs(st.cells) do
      local arr, ech, enr, dsum, dn, tsum, mortes = 0, 0, 0, 0, 0, 0, 0
      for _, u in ipairs(cell.unites) do
        local e = u.e
        if e and e.valid then
          local d = C.dist(e.position, { x = u.but[1], y = u.but[2] })
          if u.fin and u.fin.result == defines.behavior_result.success and (u.fin.x or 0) - u.depart[1] >= 40 then
            arr = arr + 1
            tsum = tsum + ((u.fin and u.fin.tick or CHECK) - T0)
          else
            dsum = dsum + d
            dn = dn + 1
          end
          if u.fin and u.fin.result == defines.behavior_result.fail then ech = ech + 1 end
          if not u.fin then enr = enr + 1 end
        else
          mortes = mortes + 1
          if u.fin and u.fin.result == defines.behavior_result.success and (u.fin.x or 0) - u.depart[1] >= 40 then
            arr = arr + 1
            tsum = tsum + (u.fin.tick - T0)
          end
        end
      end
      cell.arr = arr
      res[cell.boite .. cell.terrain] = arr
      local fins = {}
      for _, u in ipairs(cell.unites) do
        fins[#fins + 1] = u.fin and string.format("r%s@t%d(%.0f,%.0f)", tostring(u.fin.result), u.fin.tick - T0, (u.fin.x or 0) - u.depart[1], (u.fin.y or 0) - u.depart[2]) or "-"
      end
      ctx.log("E2 fins (result, tick relatif, deplacement dx,dy) " .. cell.boite .. " " .. cell.terrain .. " : " .. table.concat(fins, " "))
      ctx.log(string.format("E2 ±%s %-9s : arrivees=%d/%d echecs=%d en_route=%d invalides=%d dist_non_arrives=%s duree_moy=%s", cell.boite, cell.terrain, arr, REPL, ech, enr, mortes,
        dn > 0 and C.fmt(dsum / dn, 1) or "-", arr > 0 and C.fmt(tsum / arr, 0) or "-"))
    end
    local sf = ctx.surface()
    local restants = sf.count_entities_filtered({ name = "stone-wall", area = { { BX0 - 10, BY0 - 10 }, { BX0 + LARG_X * #BOITES, BY0 + BLOC_Y * #TERRAINS } } })
    local cliffs = sf.count_entities_filtered({ name = "cliff", area = { { BX0 - 10, BY0 - 10 }, { BX0 + LARG_X * #BOITES, BY0 + BLOC_Y * #TERRAINS } } })
    ctx.log(string.format("E2 murs de pierre restants a la fin : %d / %d (les unites ne les ont pas detruits si egal) ; falaises %d / %d", restants, st.murs, cliffs, st.falaises))
    local ouvert09 = res["09ouvert"] or 0
    ctx.check(ouvert09 >= REPL * 0.95, "E2 ±0,9 en terrain ouvert : >= 95 % d'arrivees", ouvert09 .. " / " .. REPL)
    -- tableau synthétique
    for _, b in ipairs(BOITES) do
      local l = {}
      for _, t in ipairs(TERRAINS) do l[#l + 1] = t .. "=" .. tostring(res[b[1] .. t]) end
      ctx.log("E2 SYNTHESE ±" .. b[1] .. " : " .. table.concat(l, " "))
    end
  end,
}
