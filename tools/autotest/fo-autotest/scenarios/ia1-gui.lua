--[[
  Lot IA1-i : interface « Équipe et factions » en moteur réel. Lancement :
    images (le vrai banc de l'interface : un joueur est connecté) :
      $env:FO_VISUAL_ARGS = '--ticks 17500'
      & "<racine>\fo-captures.bat" ia1-gui "<source>"
      $env:FO_VISUAL_ARGS = $null
    sans images (aucun joueur : prototypes, interface distante, journal, aucun rafraîchissement) :
      & "<racine>\fo-autotest.bat" nopause 16600 ia1-gui "<source>"
  Journal : [FO-IA1-GUI].

  Carte : coffre d'équipe garni près du point de départ ; réglages de carte 3 factions, 30 soldats, 4 ouvriers ;
  difficulté Facile ; la guerre n'est PAS lancée : c'est le bouton de l'interface qui la lance.
  Avec un joueur, chaque action passe par l'interface distante « fo-ia1i » : `toggle` (la fonction du raccourci et de
  la touche), `select` (celle du changement d'onglet), `click` (celle du clic : on_click) ; l'état est relu ensuite
  par « fo-ia1i » (fenêtre, onglet, confirmation, noms des éléments), « fo-ia1 » (orientation, effectif) et « fo-pvp »
  (guerre). Captures `x-ia1i-*.png` (show_gui, F51) ; coût du rafraîchissement mesuré (LuaProfiler).
]]

local CHECK = 16500
local T_WAIT = 15000 -- environ 4 min de guerre avant les captures des onglets

local function player(ctx)
  return game.connected_players[1]
end

local function names_has(st, name)
  for _, n in ipairs(st.names or {}) do if n == name then return true end end
  return false
end

local function keys_count(st, key)
  local n = 0
  for _, k in ipairs(st.keys or {}) do if k == key then n = n + 1 end end
  return n
end

local function team_row(ctx)
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key == "player" then return r end
  end
  return nil
end

local function shot(ctx, p, name)
  local st = ctx.state()
  game.take_screenshot({ path = "fo-shots/x-ia1i-" .. name .. ".png", player = p, show_gui = true,
    position = st.chest_pos, zoom = 1, resolution = { 1920, 1080 }, daytime = 0, force_render = true,
    allow_in_replay = true })
  st.shots = (st.shots or 0) + 1
  ctx.log("capture x-ia1i-" .. name .. ".png demandee au tick " .. game.tick)
end

local function R(ctx, fn, ...) return ctx.remote("fo-ia1i", fn, ...) end

-- Actions avec un joueur, par tick.
local steps = {}

steps[60] = function(ctx, p, st)
  local open = R(ctx, "toggle", p.index)
  local s = R(ctx, "state", p.index)
  st.expect_open = true
  ctx.check(open == true and s.open and s.shortcut and s.opened, "raccourci (toggle) : fenetre ouverte, bouton allume, opened",
    string.format("open=%s shortcut=%s opened=%s", tostring(s.open), tostring(s.shortcut), tostring(s.opened)))
  ctx.check(s.tab == "equipe" and keys_count(s, "fo-ia1i.goal") == 1 and keys_count(s, "fo-ia1i.staff") == 1,
    "Mon equipe : objectif et effectifs", "onglet " .. tostring(s.tab))
end

steps[120] = function(ctx, p, st)
  R(ctx, "select", p.index, "factions")
  local s = R(ctx, "state", p.index)
  ctx.check(s.tab == "factions" and s.selected == 3 and keys_count(s, "fo-ia1i.war-none") == 1 and names_has(s, "fo_ia1i_war_start"),
    "Factions sans guerre : bouton Lancer", "selected " .. tostring(s.selected))
end
steps[125] = function(ctx, p) shot(ctx, p, "01-factions-sans-guerre") end

steps[150] = function(ctx, p, st)
  local before = #ctx.remote("fo-pvp", "status").factions
  R(ctx, "click", p.index, "fo_ia1i_war_start")
  local pvp = ctx.remote("fo-pvp", "status")
  st.war_n = #pvp.factions
  ctx.check(before == 0 and st.war_n == 3, "clic Lancer la guerre : 3 factions (reglage de carte)",
    before .. " -> " .. st.war_n)
  local s = R(ctx, "state", p.index)
  ctx.check(names_has(s, "fo_ia1i_war_stop") and keys_count(s, "fo-ia1i.character") == 3,
    "Factions : bouton Arreter et une carte par faction", keys_count(s, "fo-ia1i.character"))
end

steps[200] = function(ctx, p, st)
  R(ctx, "select", p.index, "orientation")
  local before = ctx.remote("fo-ia1", "team_status", "player")
  R(ctx, "click", p.index, "fo_ia1i_preset_ressources")
  local after = ctx.remote("fo-ia1", "team_status", "player")
  ctx.check(after and after.orientation == "ressources", "clic Ressources : orientation de l'equipe",
    tostring(before and before.orientation) .. " -> " .. tostring(after and after.orientation))
end

steps[220] = function(ctx, p, st)
  st.n_before = (team_row(ctx) or {}).n or 0
  R(ctx, "click", p.index, "fo_ia1i_dismiss")
  local s = R(ctx, "state", p.index)
  ctx.check(s.confirm == "dismiss" and names_has(s, "fo_ia1i_dismiss_yes") and not names_has(s, "fo_ia1i_dismiss"),
    "Renvoyer : confirmation dans la fenetre", tostring(s.confirm))
  ctx.check(st.n_before > 0 and (team_row(ctx) or {}).n == st.n_before, "Renvoyer : rien avant la confirmation",
    st.n_before .. " PNJ")
end
steps[225] = function(ctx, p) shot(ctx, p, "02-orientation-confirmation") end
steps[300] = function(ctx, p, st)
  local s = R(ctx, "state", p.index)
  ctx.check(s.confirm == "dismiss" and names_has(s, "fo_ia1i_dismiss_yes"), "confirmation gardee par le rafraichissement",
    "refreshes " .. tostring(s.refreshes))
  R(ctx, "click", p.index, "fo_ia1i_dismiss_no")
  s = R(ctx, "state", p.index)
  ctx.check(s.confirm == nil and names_has(s, "fo_ia1i_dismiss") and (team_row(ctx) or {}).n == st.n_before,
    "Annuler : rien de renvoye", tostring((team_row(ctx) or {}).n))
end

steps[360] = function(ctx, p, st)
  st.expect_open = false
  local open = R(ctx, "toggle", p.index)
  local s = R(ctx, "state", p.index)
  st.ref_closed = s.refreshes
  ctx.check(open == false and not s.open and not s.shortcut, "touche (toggle) : fenetre fermee, bouton eteint")
end
steps[900] = function(ctx, p, st)
  local s = R(ctx, "state", p.index)
  ctx.check(s.refreshes == st.ref_closed, "fenetre fermee : aucun rafraichissement en 9 s",
    tostring(st.ref_closed) .. " -> " .. tostring(s.refreshes))
  R(ctx, "open", p.index, "equipe")
  st.ref_open = R(ctx, "state", p.index).refreshes
  st.expect_open = true
end
steps[1500] = function(ctx, p, st)
  local s = R(ctx, "state", p.index)
  local n = s.refreshes - st.ref_open
  ctx.check(n >= 9 and n <= 11, "fenetre ouverte : un rafraichissement par seconde (10 attendus en 600 ticks)", n)
end

-- Captures de chaque onglet après environ 4 min de guerre.
local TABS = { "equipe", "orientation", "factions", "pnj", "territoire", "chantiers" }
for i, k in ipairs(TABS) do
  steps[T_WAIT + 50 * (i - 1)] = function(ctx, p) R(ctx, "select", p.index, k) end
  steps[T_WAIT + 50 * (i - 1) + 5] = function(ctx, p) shot(ctx, p, string.format("%02d-%s", 2 + i, k)) end
end
steps[T_WAIT + 3] = function(ctx, p, st)
  local s = R(ctx, "state", p.index)
  ctx.check(keys_count(s, "fo-ia1b.mgr-gisements") == 1 and keys_count(s, "fo-ia1i.col-pole") == 1
    and keys_count(s, "fo-ia1i.chest") == 1 and keys_count(s, "fo-ia1i.journal") == 1,
    "Mon equipe : managers, poles, coffre, journal")
  ctx.check(keys_count(s, "fo-ia1i.j-line") >= 2, "journal : au moins 2 entrees affichees", keys_count(s, "fo-ia1i.j-line"))
end
steps[T_WAIT + 103] = function(ctx, p, st)
  local s = R(ctx, "state", p.index)
  local n = keys_count(s, "fo-ia1i.character")
  local rel = keys_count(s, "fo-ia1i.rel-truce") + keys_count(s, "fo-ia1i.rel-truce-due") + keys_count(s, "fo-ia1i.rel-war")
    + keys_count(s, "fo-ia1i.rel-provoked") + keys_count(s, "fo-ia1i.rel-truce-peaceful") + keys_count(s, "fo-ia1i.rel-eliminated")
  ctx.check(n == st.war_n and rel == n, "Factions : carte et relation pour chaque faction", n .. " cartes, " .. rel .. " relations")
  st.chef_decided = keys_count(s, "fo-ia1i.chef")
  st.knows = keys_count(s, "fo-ia1i.knows")
  ctx.log(string.format("postures decidees %d / %d ; factions qui savent quelque chose de vous %d", st.chef_decided, n, st.knows))
end
steps[T_WAIT + 153] = function(ctx, p, st)
  local s = R(ctx, "state", p.index)
  local row = team_row(ctx)
  local lines = keys_count(s, "fo-ia1i.role-executant") + keys_count(s, "fo-ia1i.role-generalist")
  ctx.check(row and lines == row.n, "PNJ : une ligne par PNJ vivant", lines .. " lignes, " .. tostring(row and row.n) .. " PNJ")
end

steps[T_WAIT + 300] = function(ctx, p, st)
  R(ctx, "select", p.index, "factions")
  R(ctx, "click", p.index, "fo_ia1i_war_stop")
  local s = R(ctx, "state", p.index)
  ctx.check(s.confirm == "stop" and names_has(s, "fo_ia1i_war_stop_yes") and #ctx.remote("fo-pvp", "status").factions == 3,
    "Arreter : confirmation dans la fenetre, guerre en cours")
end
steps[T_WAIT + 305] = function(ctx, p) shot(ctx, p, "09-arret-confirmation") end
steps[T_WAIT + 350] = function(ctx, p, st)
  R(ctx, "click", p.index, "fo_ia1i_war_stop_no")
  ctx.check(#ctx.remote("fo-pvp", "status").factions == 3, "Annuler l'arret : guerre en cours")
end

-- Coût du rafraîchissement (partie vivante, fenêtre ouverte) par onglet, et du relevé du journal.
steps[T_WAIT + 400] = function(ctx, p, st)
  for _, k in ipairs({ "equipe", "factions", "pnj", "orientation" }) do
    R(ctx, "select", p.index, k)
    local prof = game.create_profiler()
    for _ = 1, 20 do R(ctx, "refresh", p.index, false) end
    prof.stop()
    prof.divide(20)
    log({ "", "[FO-IA1-GUI] COUT\trafraichissement de l'onglet ", k, " (moyenne de 20, appel distant compris)\t", prof })
  end
  local prof = game.create_profiler()
  for _ = 1, 100 do R(ctx, "sample") end
  prof.stop()
  prof.divide(100)
  log({ "", "[FO-IA1-GUI] COUT\treleve du journal (moyenne de 100, appel distant compris)\t", prof })
  local prof0 = game.create_profiler()
  for _ = 1, 100 do R(ctx, "state", 0) end
  prof0.stop()
  prof0.divide(100)
  log({ "", "[FO-IA1-GUI] COUT\tappel distant temoin (state sans joueur, moyenne de 100)\t", prof0 })
  st.costs = true
end

steps[T_WAIT + 600] = function(ctx, p, st)
  R(ctx, "select", p.index, "orientation")
  R(ctx, "click", p.index, "fo_ia1i_dismiss")
  R(ctx, "click", p.index, "fo_ia1i_dismiss_yes")
  local row = team_row(ctx)
  ctx.check(row and row.n == 0, "Confirmer le renvoi : equipe renvoyee", tostring(row and row.n))
end
steps[T_WAIT + 700] = function(ctx, p, st)
  R(ctx, "select", p.index, "factions")
  R(ctx, "click", p.index, "fo_ia1i_war_stop")
  R(ctx, "click", p.index, "fo_ia1i_war_stop_yes")
  local pvp = ctx.remote("fo-pvp", "status")
  ctx.check(not pvp.active and #pvp.factions == 0, "Confirmer l'arret : guerre arretee", tostring(pvp.active))
  local s = R(ctx, "state", p.index)
  ctx.check(names_has(s, "fo_ia1i_war_start"), "apres l'arret : bouton Lancer revenu")
end
steps[T_WAIT + 800] = function(ctx, p) R(ctx, "select", p.index, "equipe") end
steps[T_WAIT + 805] = function(ctx, p) shot(ctx, p, "10-journal-apres") end
steps[T_WAIT + 900] = function(ctx, p, st)
  local kinds = {}
  for _, e in ipairs(R(ctx, "journal")) do kinds[e.kind] = true end
  ctx.check(kinds["war-started"] and kinds["orientation"] and kinds["war-stopped"],
    "journal : guerre lancee, orientation, guerre arretee")
end

return {
  description = "IA1-i : interface Equipe et factions (fenetre, onglets, boutons, captures)",
  base = nil,
  check_tick = CHECK,
  shots_delay = CHECK + 100,

  init = function(ctx)
    local set = {
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 3),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-soldiers", 30),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", 4),
    }
    ctx.check(set[1] == 3 and set[2] == 30 and set[3] == 4, "reglages de carte ecrits (3 factions, 30 soldats, 4 ouvriers)")
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "easy") == true, "difficulte Facile")
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local pos = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
    local chest = pos and s.create_entity({ name = "fo-team-chest", position = pos, force = "player", raise_built = true })
    if chest then
      for _, it in ipairs({ { "iron-plate", 600 }, { "copper-plate", 200 }, { "coal", 300 }, { "stone", 200 },
        { "pistol", 4 }, { "firearm-magazine", 80 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    local st = ctx.state()
    st.chest_pos = chest and { x = chest.position.x, y = chest.position.y } or c
    ctx.check(game.shortcut_prototypes["fo-team-gui"] ~= nil and game.custom_input_prototypes["fo-team-gui"] ~= nil,
      "prototypes : raccourci et touche fo-team-gui")
    local ci = game.custom_input_prototypes["fo-team-gui"]
    ctx.log("touche : " .. tostring(ci and ci.key_sequence) .. " ; raccourci : action " ..
      tostring(game.shortcut_prototypes["fo-team-gui"] and game.shortcut_prototypes["fo-team-gui"].action))
    ctx.check(ctx.has("fo-ia1i", "click") and ctx.has("fo-ia1i", "state"), "interface distante fo-ia1i")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local p = player(ctx)
    if not p then
      if not st.no_player_logged then
        st.no_player_logged = true
        ctx.log("aucun joueur connecte (banc sans images) : la fenetre se teste en session avec images (fo-captures.bat)")
      end
      return
    end
    if not st.player_seen then
      st.player_seen = e.tick
      ctx.log("joueur connecte : " .. p.name .. " (index " .. p.index .. ") au tick " .. e.tick)
      ctx.call("profiler", true)
    end
    -- Surveillance : toute fermeture de la fenêtre que le banc n'a pas demandée est journalisée avec ce que le moteur
    -- a ouvert à la place (type d'interface, personnage, contrôleur), puis la fenêtre est rouverte pour que les captures
    -- suivantes restent possibles. Passages du 25/10 : fermetures à des ticks DIFFÉRENTS sur la même carte (état de jeu
    -- déterministe, F238) : entrée locale de la session (fenêtre de test non réduite, au premier plan) ; le contrôle
    -- final vérifie qu'aucune ne tombe au tick d'un rafraîchissement de l'interface (multiple de 60).
    local t = p.opened_gui_type
    if t ~= st.last_type then
      local names = {}
      for k, v in pairs(defines.gui_type) do names[v] = k end
      local what = "-"
      pcall(function() if p.opened then what = p.opened.object_name .. ":" .. tostring(p.opened.name) end end)
      ctx.log(string.format("tick %d : opened_gui_type %s -> %s (%s), personnage %s, controleur %s, attente de reapparition %s",
        e.tick, tostring(names[st.last_type] or st.last_type), tostring(names[t] or t), what,
        tostring(p.character ~= nil and p.character.valid), tostring(p.controller_type), tostring(p.ticks_to_respawn)))
      if st.expect_open and t ~= defines.gui_type.custom then
        st.close_ticks = st.close_ticks or {}
        st.close_ticks[#st.close_ticks + 1] = e.tick
      end
      st.last_type = t
    end
    if st.expect_open and e.tick % 10 == 0 then
      local s = R(ctx, "state", p.index)
      if not s.open then
        st.lost = (st.lost or 0) + 1
        ctx.log("fenetre fermee sans action du banc (" .. st.lost .. "), vue au tick " .. e.tick .. " : rouverte")
        R(ctx, "open", p.index, s.tab or "equipe")
      end
    end
    local fn = steps[e.tick]
    if fn then fn(ctx, p, st) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = R(ctx, "state", st.player_seen and game.connected_players[1].index or 0)
    local j = R(ctx, "journal")
    ctx.check(#j >= 1, "journal tenu en moteur reel (" .. #j .. " entree(s))")
    for _, e in ipairs(j) do ctx.log(string.format("journal tick %d : %s %s %s %s", e.tick, e.kind, tostring(e.a), tostring(e.b), tostring(e.c))) end
    if not st.player_seen then
      ctx.check(s.refreshes == 0, "sans joueur : aucun rafraichissement d'interface", s.refreshes)
      return
    end
    ctx.check((st.shots or 0) == 10, "10 captures demandees", st.shots)
    local on_refresh = 0
    for _, t in ipairs(st.close_ticks or {}) do if t % 60 == 0 then on_refresh = on_refresh + 1 end end
    ctx.check(on_refresh == 0, "aucune fermeture non demandee au tick d'un rafraichissement",
      string.format("%d fermeture(s) non demandee(s) aux ticks %s", #(st.close_ticks or {}),
        table.concat(st.close_ticks or {}, ", ")))
    ctx.check(st.costs == true, "couts mesures")
    ctx.call("log_report", "IA1-GUI profileur (nth:60 = releve du journal + rafraichissement)")
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local c = st.chest_pos or { x = 0, y = 0 }
    add("equipe-sol", c.x, c.y, 0.5, 0)
  end,
}
