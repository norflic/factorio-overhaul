-- Scénario greffé du lot RB-0 (31/10), essai E5 : un `collision_mask` réduit suffit-il à une unité pour franchir l'eau
-- (le « Lévite » flottant du plan) ? (PLAN.md §3)
-- À LANCER SUR LA COPIE JETABLE : banc.py ... --qui RB0 -- 1500 rb0-flotte <copie>
--
-- Deux unités de 4 répliques : rb0-u-04 (masque par défaut) et rb0-u-flot (masque {"not-colliding-with-itself"} : plus
-- aucune couche). Terrains, une voie de 12 tuiles par unité :
--   lac   : terre à l'ouest, lac de 40 tuiles (eau profonde) sur toute la hauteur de la zone, île-but à l'est (aucun détour) ;
--   mur   : trois rangées de murs de pierre sur 41 tuiles de haut (aucun détour) ;
--   foret : 160 arbres sur 20 x 20 tuiles.
-- go_to_location vers 70 tuiles à l'est (rayon 2). Mesures : arrivées, échecs, durée. L'unité flottante peut-elle même être
-- créée sur l'eau (can_place_entity) ? Aucune mesure visuelle (render_layer) : à juger sur capture.

local C = require("scenarios/rb0_common")

local T0 = 60
local CHECK = 1400
local X0, Y0 = 6000, 6000
local REPL = 4
local PAS = 12
local TYPES = { "rb0-u-04", "rb0-u-flot" }
local TERRAINS = { "lac", "mur", "foret" }

script.on_event(defines.events.on_ai_command_completed, function(e)
  local g = C.g()
  local u = g.unites and g.unites[e.unit_number]
  if u and not u.fin then
    local pos = u.e and u.e.valid and u.e.position or nil
    u.fin = { tick = e.tick, result = e.result, x = pos and pos.x, y = pos and pos.y }
  end
end)

return {
  description = "RB-0 E5 : masque de collision reduit : une unite franchit-elle eau, mur, foret ?",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    if not C.exige(ctx, TYPES, "unites rb0-u-04 et rb0-u-flot") then return end
    local s = ctx.surface()
    C.force("rb0")
    game.map_settings.enemy_expansion.enabled = false
    local H = PAS * REPL * #TYPES * #TERRAINS
    ctx.prepare_area(X0 - 10, Y0 - 10, X0 + 110, Y0 + H + 10, "grass-1")
    C.sans_ennemis(s, X0 - 20, Y0 - 20, X0 + 120, Y0 + H + 20)
    ctx.log(string.format("masques : rb0-u-04=%s ; rb0-u-flot=%s", serpent.line(game.entity_prototypes["rb0-u-04"].collision_mask),
      serpent.line(game.entity_prototypes["rb0-u-flot"].collision_mask)))
    local rng = game.create_random_generator(5311026)
    st.cells = {}
    local bloc = PAS * REPL * #TYPES
    for ti, terr in ipairs(TERRAINS) do
      local by = Y0 + bloc * (ti - 1)
      if terr == "lac" then C.eau(s, X0 + 15, by - 2, X0 + 55, by + bloc + 2, "deepwater") end
      if terr == "mur" then
        for dx = 0, 2 do
          for dy = -2, bloc + 2 do s.create_entity({ name = "stone-wall", position = { X0 + 30 + dx + 0.5, by + dy + 0.5 }, force = "player" }) end
        end
      end
      if terr == "foret" then
        for _ = 1, 160 * #TYPES * REPL / 4 do
          s.create_entity({ name = "tree-02", position = { X0 + 20 + rng(20) - 0.5, by + rng(bloc) - 0.5 } })
        end
      end
      for ki, tipo in ipairs(TYPES) do
        local cell = { terrain = terr, tipo = tipo, unites = {} }
        for r = 1, REPL do
          local y = by + PAS * ((ki - 1) * REPL + (r - 1)) + 6
          local u = s.create_entity({ name = tipo, position = { X0 + 2, y }, force = "rb0" })
          cell.unites[#cell.unites + 1] = { e = u, but = { X0 + 70, y } }
        end
        st.cells[#st.cells + 1] = cell
      end
    end
    -- créer l'unité flottante sur l'eau ?
    local pw = { X0 + 35, Y0 + 5 }
    st.sur_eau = {}
    for _, tipo in ipairs(TYPES) do
      st.sur_eau[tipo] = s.can_place_entity({ name = tipo, position = pw, force = "rb0" })
    end
    ctx.log(string.format("can_place_entity sur l'eau : rb0-u-04=%s ; rb0-u-flot=%s", tostring(st.sur_eau["rb0-u-04"]), tostring(st.sur_eau["rb0-u-flot"])))
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret or e.tick ~= T0 then return end
    local g = C.g()
    g.unites = {}
    for _, cell in ipairs(st.cells) do
      for _, u in ipairs(cell.unites) do
        if u.e and u.e.valid then
          g.unites[u.e.unit_number] = u
          u.e.set_command({ type = defines.command.go_to_location, destination = { x = u.but[1], y = u.but[2] }, radius = 2,
            distraction = defines.distraction.none })
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local res = {}
    for _, cell in ipairs(st.cells) do
      local arr, ech, tsum = 0, 0, 0
      local fins = {}
      for _, u in ipairs(cell.unites) do
        -- arrivee = commande reussie ET deplacement vers l'est >= 60 tuiles (but a 68 tuiles du depart)
        if u.fin and u.fin.result == defines.behavior_result.success and (u.fin.x or 0) >= u.but[1] - 10 then
          arr = arr + 1
          tsum = tsum + (u.fin.tick - T0)
        end
        if u.fin and u.fin.result == defines.behavior_result.fail then ech = ech + 1 end
        fins[#fins + 1] = u.fin and string.format("r%s@t%d(x=%.0f)", tostring(u.fin.result), u.fin.tick - T0, (u.fin.x or 0) - X0) or (u.e and u.e.valid and string.format("en_route(x=%.0f)", u.e.position.x - X0) or "invalide")
      end
      ctx.log("E5 fins " .. cell.tipo .. " " .. cell.terrain .. " : " .. table.concat(fins, " "))
      res[cell.tipo .. cell.terrain] = arr
      ctx.log(string.format("E5 %-11s %-6s : arrivees=%d/%d echecs=%d duree_moy=%s", cell.tipo, cell.terrain, arr, REPL, ech,
        arr > 0 and C.fmt(tsum / arr, 0) or "-"))
    end
    ctx.check((res["rb0-u-flotlac"] or 0) > (res["rb0-u-04lac"] or 0), "E5 le masque reduit franchit le lac (plus d'arrivees que le masque par defaut)",
      tostring(res["rb0-u-flotlac"]) .. " contre " .. tostring(res["rb0-u-04lac"]))
  end,
}
