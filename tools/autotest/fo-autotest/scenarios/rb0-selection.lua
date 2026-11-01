-- Scénario greffé du lot RB-0 (31/10), essai E6 : outil de sélection `rb0-selection` sur unités et araignées.
-- À LANCER SUR LA COPIE JETABLE : banc.py ... --qui RB0 --captures -- 600 rb0-selection <copie>
--
-- LIMITE DU BANC : aucun événement de sélection ne peut être produit par script (il faut un joueur qui glisse la souris).
-- Ce que le banc SAIT répondre : (1) le prototype se charge avec entity_type_filters = {unit, spider-vehicle} et les
-- quatre modes (le jeu l'accepte) ; (2) les champs lus à l'exécution ; (3) les gestionnaires des 4 événements existent et
-- écrivent `[FO-RB0-SELECTION] EVENT ...` au journal, pour une partie jouée à la main par le Directeur Créatif.
-- Ce que seul un humain peut répondre : zone reçue en vue carte, clic sans glisser (zone vide ou non), touches.
-- Protocole humain : tools/autotest/robots/README.md.
-- Au tick 60 : 6 unités rb0-u-04, 2 rb0-u-09, 2 araignées rb0-spider-1 et 2 biters ennemis, groupés autour de (11000, 11000) ;
-- si un joueur avec un personnage existe, il reçoit l'outil dans la main.

local C = require("scenarios/rb0_common")

local X0, Y0 = 11000, 11000
local CHECK = 400

local function lister(e, titre)
  local l = {}
  for _, ent in ipairs(e.entities or {}) do
    if ent.valid then l[#l + 1] = ent.name .. "@" .. string.format("%.1f,%.1f", ent.position.x, ent.position.y) end
  end
  log(string.format("[FO-RB0-SELECTION] EVENT %s tick=%d joueur=%s outil=%s zone=(%.1f,%.1f)-(%.1f,%.1f) entites=%d : %s", titre, e.tick,
    tostring(e.player_index), tostring(e.item), e.area.left_top.x, e.area.left_top.y, e.area.right_bottom.x, e.area.right_bottom.y,
    #l, table.concat(l, " ")))
  local g = C.g()
  g.evenements = (g.evenements or 0) + 1
end

script.on_event(defines.events.on_player_selected_area, function(e) if e.item == "rb0-selection" then lister(e, "selection") end end)
script.on_event(defines.events.on_player_alt_selected_area, function(e) if e.item == "rb0-selection" then lister(e, "alt") end end)
script.on_event(defines.events.on_player_reverse_selected_area, function(e) if e.item == "rb0-selection" then lister(e, "reverse") end end)
script.on_event(defines.events.on_player_alt_reverse_selected_area, function(e) if e.item == "rb0-selection" then lister(e, "alt-reverse") end end)

local function modes(p, nom)
  local ok, v = pcall(function() return p[nom] end)
  if not ok then return "illisible" end
  return serpent.line(v, { comment = false })
end

return {
  description = "RB-0 E6 : outil de selection sur unites et araignees (chargement, champs, gestionnaires)",
  base = nil,
  check_tick = CHECK,
  shots_delay = 200,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    if not C.exige(ctx, { "rb0-u-04", "rb0-u-09", "rb0-spider-1", "rb0-selection" }, "unites, araignee, outil") then return end
    local s = ctx.surface()
    C.force("rb0")
    ctx.prepare_area(X0 - 30, Y0 - 30, X0 + 30, Y0 + 30, "grass-1")
    C.sans_ennemis(s, X0 - 50, Y0 - 50, X0 + 50, Y0 + 50)
    st.ents = {}
    for i = 1, 6 do st.ents[#st.ents + 1] = s.create_entity({ name = "rb0-u-04", position = { X0 - 8 + 2 * i, Y0 }, force = "rb0" }) end
    for i = 1, 2 do st.ents[#st.ents + 1] = s.create_entity({ name = "rb0-u-09", position = { X0 - 6 + 4 * i, Y0 + 5 }, force = "rb0" }) end
    for i = 1, 2 do st.ents[#st.ents + 1] = s.create_entity({ name = "rb0-spider-1", position = { X0 - 10 + 20 * i, Y0 - 8 }, force = "rb0" }) end
    for i = 1, 2 do
      st.ents[#st.ents + 1] = s.create_entity({ name = "medium-biter", position = { X0 - 3 + 6 * i, Y0 + 14 }, force = "enemy" })
    end
    local p = game.item_prototypes["rb0-selection"]
    ctx.log("selection_mode_flags=" .. modes(p, "selection_mode_flags"))
    ctx.log("alt_selection_mode_flags=" .. modes(p, "alt_selection_mode_flags"))
    ctx.log("reverse_selection_mode_flags=" .. modes(p, "reverse_selection_mode_flags"))
    ctx.log("alt_reverse_selection_mode_flags=" .. modes(p, "alt_reverse_selection_mode_flags"))
    ctx.log("entity_type_filters=" .. modes(p, "entity_type_filters") .. " reverse_entity_type_filters=" .. modes(p, "reverse_entity_type_filters"))
    ctx.log("touches attendues : glisser = LMB, alt = Maj + LMB, reverse = RMB, alt-reverse = Maj + RMB (doc SelectionToolPrototype, lue, non jouee)")
    ctx.check(p.type == "selection-tool", "E6 l'outil rb0-selection est un outil de selection charge par le jeu", p.type)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret or e.tick ~= 60 then return end
    local n = 0
    for _, pl in pairs(game.players) do
      if pl.character and pl.cursor_stack then
        pl.teleport({ X0, Y0 + 2 })
        local ok = pl.cursor_stack.set_stack({ name = "rb0-selection", count = 1 })
        ctx.log("joueur " .. pl.index .. " : outil mis en main = " .. tostring(ok))
        n = n + 1
      end
    end
    st.joueurs = n
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local nb = 0
    for _, e in ipairs(st.ents) do if e and e.valid then nb = nb + 1 end end
    ctx.log("E6 entites posees=" .. nb .. " ; joueurs avec personnage=" .. tostring(st.joueurs) .. " ; evenements de selection recus=" .. tostring(C.g().evenements or 0))
    ctx.check(nb == #st.ents, "E6 unites et araignees posees pour le test humain", nb .. " / " .. #st.ents)
  end,

  shots = function(ctx, add)
    add("e6-groupe", 11000, 11004, 1, 0, { res = { 1280, 720 }, info = false, aa = false })
  end,
}
