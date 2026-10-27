--[[
  Lot CAPITAL : la guerre au MOTEUR SIMULÉ avec les améliorations des factions, contre le témoin (K9 : « l'équilibre
  contre le joueur ne doit pas casser ; dire l'effet sur la difficulté »).

  pvp_test.lua (1305 OK) ne voit PAS ce lot : le moteur simulé n'a ni la recette du centre ni les prototypes des niveaux
  (un nom « fo-… » inconnu y est une unité générique), donc le générateur n'y trouve rien à améliorer. Ce banc AJOUTE, dans
  son propre monde seulement (aucun autre test touché), la recette du centre (celle de prototypes/levels/common.lua), les
  prototypes des niveaux 1 à 6 de la mitrailleuse (vie et dégâts des données des niveaux, L.apply_stat) et le centre ;
  puis il joue la partie de pvp_test (2 factions, 60 soldats, 6 ouvriers, QG à 320 tuiles, base témoin du joueur
  défendue par 1 tourelle) en Normal pendant 45 min, améliorations ALLUMÉES (réglage fo-war-capital) puis au défaut du
  jeu (réglage ÉTEINT, correction après revue), et
  compare : centres posés, tourelles améliorées, attaques contre le joueur, soldats envoyés, soldats en vie.
  Usage : lua5.2 tests/capital_moteur_test.lua   (environ 1 à 2 min)
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local L = require("shared.levels.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[CAPITAL-MOTEUR] ECHEC : " .. msg) end
end
local function W() return M.world() end
local MIN = 3600

local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local OUTPOST = { x = -96, y = 96 }
local GUN, CC = L.by_key.gun, L.by_key.command
local function box(x0, y0, x1, y1) return { left_top = { x = x0, y = y0 }, right_bottom = { x = x1, y = y1 } } end

local function world(on)
  -- Allumé : réglage fo-war-capital allumé (option du moteur simulé) ; témoin : réglage à son défaut du jeu (ÉTEINT).
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "normal",
    groups_hit_player = true, turrets_kill = true, capital = on })
  local w = W()
  -- Recette du centre (prototypes/levels/common.lua) et objets du coût.
  w.recipes["fo-command-center"] = { name = "fo-command-center", category = "crafting", energy = 5, enabled = true,
    hidden = false,
    ingredients = { { type = "item", name = "iron-chest", amount = 4 }, { type = "item", name = "iron-gear-wheel", amount = 20 },
      { type = "item", name = "electronic-circuit", amount = 10 }, { type = "item", name = "stone-brick", amount = 20 } },
    products = { { type = "item", name = "fo-command-center", amount = 1 } } }
  _G.game.item_prototypes = M.item_prototypes(w.recipes)
  -- Prototypes : centre, mitrailleuse niveaux 1 à 6 (vie et dégâts des données des niveaux).
  local gp = w.prototypes["gun-turret"]
  local function gun_proto(n)
    local p = { type = "ammo-turret", collision_box = gp.collision_box, collision_mask = gp.collision_mask,
      selection_box = box(-1, -1, 1, 1),
      items_to_place_this = { { name = L.name(GUN, n), count = 1 } }, max_health = 400, attack_parameters = { cooldown = 6, damage_modifier = 1 } }
    for _, st in ipairs(GUN.stats) do
      local leaf = st.path[#st.path]
      if leaf == "max_health" then p.max_health = L.apply_stat(st, 400, n) end
      if leaf == "damage_modifier" then p.attack_parameters.damage_modifier = L.apply_stat(st, 1, n) end
    end
    return p
  end
  rawset(w.prototypes, "gun-turret", gun_proto(1))
  for n = 2, 6 do rawset(w.prototypes, L.name(GUN, n), gun_proto(n)) end
  for n = 1, 3 do
    rawset(w.prototypes, L.name(CC, n), { type = "container", max_health = 3000, collision_box = box(-1.9, -1.9, 1.9, 1.9),
      selection_box = box(-2, -2, 2, 2),
      collision_mask = gp.collision_mask, items_to_place_this = { { name = L.name(CC, 1), count = 1 } } })
  end
  M.load_mod()
  M.dispatch(w.on_init)
  local s = w.surface
  for i = 0, 3 do s.create_entity({ name = "stone-furnace", position = { x = OUTPOST.x - 6 + 4 * i, y = OUTPOST.y }, force = "player" }) end
  local t = s.create_entity({ name = "gun-turret", position = { x = OUTPOST.x, y = OUTPOST.y - 4 }, force = "player" })
  t.insert({ name = "piercing-rounds-magazine", count = 50 })
  M.command("fo-war", "start 2 60 6 320")
end

local function measure(on, minutes)
  world(on)
  M.run_ticks(minutes * MIN)
  local r = { cc = 0, cc2 = 0, up = 0, attacks = 0, sent = 0, alive = 0, decisions = 0 }
  for i = 1, 2 do
    local f = global.fo.war.factions[i]
    local fp = f.pvp or {}
    r.attacks = r.attacks + (fp.attacks or 0)
    r.sent = r.sent + (fp.sent_total or 0)
    r.alive = r.alive + (f.soldiers_count or 0)
    local st = remote.call("fo-capital", "status", f.key) or {}
    r.decisions = r.decisions + (st.decisions or 0)
    r.up = r.up + (st.upgrades or 0)
    if (st.cc_level or 0) >= 1 then r.cc = r.cc + 1 end
    if (st.cc_level or 0) >= 2 then r.cc2 = r.cc2 + 1 end
  end
  local lv = 0
  for _, e in ipairs(W().entities) do
    if e.valid and e.force.name ~= "player" then
      local fam, n = L.parse(e.name)
      if fam == GUN and n >= 2 then lv = lv + 1 end
    end
  end
  r.guns_up = lv
  if on then
    -- Réglage ÉTEINT en cours de partie (correction après revue) : plus aucune amélioration payée, plus aucun objet voulu
    -- ni dépliage laissé par la dernière décision (Capital.wanted, Capital.steps : nil).
    local Capital = package.loaded["script.ai3.capital"]
    local before = 0
    for i = 1, 2 do before = before + ((remote.call("fo-capital", "status", global.fo.war.factions[i].key) or {}).upgrades or 0) end
    W().settings["fo-war-capital"] = false
    M.run_ticks(5 * MIN)
    local after, stale = 0, 0
    for i = 1, 2 do
      local f = global.fo.war.factions[i]
      after = after + ((remote.call("fo-capital", "status", f.key) or {}).upgrades or 0)
      if Capital.wanted(f) ~= nil or Capital.steps(f) ~= nil then stale = stale + 1 end
      if f.team and f.team.capital and (f.team.capital.current or f.team.capital.wanted or f.team.capital.steps) then
        stale = stale + 1
      end
    end
    r.off_before, r.off_after, r.off_stale = before, after, stale
  end
  return r
end

local MINUTES = 45
local on = measure(true, MINUTES)
local off = measure(false, MINUTES)
local function line(tag, r)
  return string.format("%s : centres %d (niveau 2 : %d), decisions %d, ameliorations %d, tourelles au niveau >= 2 : %d, attaques contre le joueur %d, soldats envoyes %d, soldats en vie %d",
    tag, r.cc, r.cc2, r.decisions, r.up, r.guns_up, r.attacks, r.sent, r.alive)
end
print("[CAPITAL-MOTEUR] " .. line("allume", on))
print("[CAPITAL-MOTEUR] " .. line("temoin", off))
check(on.cc >= 1, "allumé : au moins une faction pose son centre au moteur simulé")
check(on.up >= 2 and on.guns_up >= 1, "allumé : des tourelles améliorées (niveau >= 2 en jeu)")
check(off.cc == 0 and off.up == 0 and off.decisions == 0, "témoin : aucune amélioration")
check(on.off_after == on.off_before and on.off_stale == 0,
  string.format("éteint en cours de partie : aucune amélioration de plus en 5 min (%d puis %d), aucun objet voulu laissé (%d)",
    on.off_before or -1, on.off_after or -1, on.off_stale or -1))
-- K9 : la pression contre le joueur en Normal ne s'effondre pas (au moins la moitié des attaques du témoin, et au moins 1
-- si le témoin attaque) ; l'écart est imprimé (effet sur la difficulté).
check(off.attacks == 0 or (on.attacks >= 1 and on.attacks * 2 >= off.attacks),
  string.format("K9 : attaques contre le joueur gardées (%d contre %d au témoin)", on.attacks, off.attacks))
print(string.format("[CAPITAL-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
