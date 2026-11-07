--[[
  Lot TOURELLE-JOURNAL (7/11) : banc HORS JEU du journal des tourelles (script/team/tourelle_journal.lua), moteur simulé.
    - [FO-TOURELLE-MORTE] : une tourelle de la force « player » tuée LOIN du QG est écrite (position, tueur, distance, portées, posée par) ;
      une seconde mort dans la même seconde de jeu ne l'est pas, elle est comptée dans la ligne suivante ; une tourelle d'une autre force :
      rien ;
    - « posée par » : last_user (le joueur), sinon le registre de l'équipe (f.turrets), sinon « inconnu » ;
    - [FO-TOURELLE-RETIREE] : Tj.removed écrit qui, pourquoi, quoi et qui l'avait posée ; rien pour un bâtiment qui n'est pas une tourelle.
  Lancement : lua5.2 tests/tourelle_journal_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function W() return M.world() end

M.new_game({ patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
local s = game.surfaces[1]
local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
M.run_ticks(120)

local function lines(tag)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(tag, 1, true) then out[#out + 1] = l end end
  return out
end
local function die(ent, cause)
  W().events[defines.events.on_entity_died]({ entity = ent, cause = cause, damage_type = { name = "physical" }, force = cause and cause.force or nil,
    tick = game.tick })
end

-- 1. Mort d'une tourelle du joueur loin du QG (hors du rayon de [FO-QG-TOURELLE]).
local tu = s.create_entity({ name = "gun-turret", position = { x = 205, y = 5 }, force = "player" })
rawset(tu, "last_user", { valid = true, name = "DC" }) -- (le moteur simulé refuse une écriture inattendue)
local shooter = s.create_entity({ name = "small-biter", position = { x = 226, y = 5 }, force = "enemy" })
M.run_ticks(60 - game.tick % 60) -- début d'une seconde de jeu
local n0 = #lines("[FO-TOURELLE-MORTE]")
die(tu, shooter)
local l1 = lines("[FO-TOURELLE-MORTE]")
check(#l1 == n0 + 1, "une ligne [FO-TOURELLE-MORTE] pour une tourelle du joueur loin du QG")
local last = l1[#l1] or ""
check(last:find("gun-turret", 1, true) and last:find("(205.0, 5.0)", 1, true) and last:find("posee par joueur DC", 1, true)
  and last:find("a 21.0 tuiles", 1, true) and last:find("a 200.0 tuiles du coffre", 1, true) ~= nil, "ligne : nom, position, tueur à 21 tuiles, coffre à 200, posée par le joueur : " .. last)

-- 2. Une seconde par ligne : une mort de plus dans la même seconde n'est pas écrite, elle est comptée ensuite.
local tu2 = s.create_entity({ name = "gun-turret", position = { x = 205, y = 15 }, force = "player" })
die(tu2, shooter)
check(#lines("[FO-TOURELLE-MORTE]") == n0 + 1, "même seconde : pas de seconde ligne")
M.run_ticks(60)
local tu3 = s.create_entity({ name = "gun-turret", position = { x = 205, y = 25 }, force = "player" })
die(tu3, nil)
local l3 = lines("[FO-TOURELLE-MORTE]")
check(#l3 == n0 + 2 and (l3[#l3]:find("1 mort(s) de tourelle non journalisee(s)", 1, true) ~= nil) and l3[#l3]:find("cause inconnu", 1, true) ~= nil
  and l3[#l3]:find("posee par inconnu", 1, true) ~= nil, "seconde suivante : une ligne, la mort sautée comptée, tueur et poseur inconnus : " .. tostring(l3[#l3]))

-- 3. Autre force : rien.
local en = s.create_entity({ name = "gun-turret", position = { x = 300, y = 5 }, force = "enemy" })
M.run_ticks(60)
die(en, nil)
check(#lines("[FO-TOURELLE-MORTE]") == n0 + 2, "tourelle d'une autre force : aucune ligne")

-- 4. Posée par : registre de l'équipe ; Tj.removed.
local Tj = require("script.team.tourelle_journal")
local f = global.fo and global.fo.pteam and global.fo.pteam.team
local tq = s.create_entity({ name = "gun-turret", position = { x = 12, y = 5 }, force = "player" })
if f then
  f.turrets = f.turrets or {}
  f.turrets[tq.unit_number] = tq
end
check(f ~= nil and Tj.placed_by(tq) == "equipe player", "posée par : registre de l'équipe (" .. tostring(Tj.placed_by(tq)) .. ")")
local nr = #lines("[FO-TOURELLE-RETIREE]")
Tj.removed(Tj.describe(tq), "chantier de l'equipe player", "emprise de test", "deplacee en (14.0, 5.0)")
local lr = lines("[FO-TOURELLE-RETIREE]")
check(#lr == nr + 1 and lr[#lr]:find("par chantier de l'equipe player", 1, true) and lr[#lr]:find("posee par equipe player", 1, true) ~= nil,
  "[FO-TOURELLE-RETIREE] : qui, pourquoi, quoi, posée par : " .. tostring(lr[#lr]))
Tj.removed(Tj.describe(chest), "test", "pas une tourelle", "rien")
check(#lines("[FO-TOURELLE-RETIREE]") == nr + 1, "un coffre n'est pas une tourelle : aucune ligne")

-- 5. Minage à la main : une tuile recouverte par un bâtiment est écartée (script/team/worker.lua, mining_entity), surface factice.
--    Ressources rendues dans l'ordre du tableau (« ordre du moteur ») ; bâtiments : boîtes { x1, y1, x2, y2 }.
local Worker = require("script.team.worker")
local Harvest = require("script.team.harvest")
local me = Worker._mining_entity
local function fake_surface(resources, buildings)
  local sf = {}
  function sf.find_entities_filtered(t)
    local out = {}
    if t.invert then
      local ex = {}
      for _, ty in ipairs(t.type) do ex[ty] = true end
      local a = t.area
      for _, b in ipairs(buildings) do
        if not ex[b.type] and b.box[1] < a[2][1] and b.box[3] > a[1][1] and b.box[2] < a[2][2] and b.box[4] > a[1][2] then
          out[#out + 1] = b
          if t.limit and #out >= t.limit then break end
        end
      end
      return out
    end
    local want = {}
    for _, n in ipairs(t.name) do want[n] = true end
    for _, r in ipairs(resources) do
      local dx, dy = r.position.x - t.position.x, r.position.y - t.position.y
      if want[r.name] and dx * dx + dy * dy <= t.radius * t.radius then
        out[#out + 1] = r
        if t.limit and #out >= t.limit then break end
      end
    end
    return out
  end
  return sf
end
local function ore(x, y) return { name = "iron-ore", type = "resource", valid = true, position = { x = x, y = y } } end
local turret = { name = "gun-turret", type = "ammo-turret", valid = true, position = { x = 2, y = 1 }, box = { 1, 0, 3, 2 } }
local FREE = { "resource" }
local T, C1, C2 = ore(0.5, 0.5), ore(1.5, 0.5), ore(1.5, 1.5)
local team = { is_player = true, key = "player" }
local old_player = Harvest.PLAYER
Harvest.PLAYER = false
-- (a) votre équipe, ancien choix (premier rendu) : la tuile recouverte C1, rendue la première, est écartée au profit de T.
local sf = fake_surface({ C1, T }, { turret })
local r, cv = me(sf, { x = 0.5, y = 0.5 }, { "iron-ore" }, team, FREE)
check(r == T and cv == turret, "équipe : la tuile sous la tourelle (rendue la première) est écartée, la tuile libre minée, la tourelle notée")
local r0 = me(sf, { x = 0.5, y = 0.5 }, { "iron-ore" }, team, nil)
check(r0 == C1, "sans `free` : ancien choix à l'identique (premier rendu, la tuile sous la tourelle) : témoin")
r, cv = me(fake_surface({ C1, C2 }, { turret }), { x = 1.5, y = 0.5 }, { "iron-ore" }, team, FREE)
check(r == nil and cv == turret, "équipe : toutes les tuiles sous la tourelle : rien à miner, la tourelle notée")
r, cv = me(fake_surface({ C1, T }, {}), { x = 0.5, y = 0.5 }, { "iron-ore" }, team, FREE)
check(r == C1 and cv == nil, "équipe : aucun bâtiment : choix d'avant à l'identique (premier rendu)")
-- (b) une faction (Harvest.applies) : plus proche de la cible ; la tuile visée recouverte : rayon 2,5, plus proche libre.
local fac = { key = "f1" }
local D = ore(0.5, 2.5)
r, cv = me(fake_surface({ D, C1, T }, { turret }), { x = 1.5, y = 0.5 }, { "iron-ore" }, fac, FREE)
check(r == T and cv == turret, "faction : la tuile visée (sous la tourelle) écartée, la plus proche libre à 2,5 tuiles prise (" .. tostring(r and r.position.x) .. ")")
r, cv = me(fake_surface({ D, C1, T }, {}), { x = 1.5, y = 0.5 }, { "iron-ore" }, fac, FREE)
check(r == C1 and cv == nil, "faction : aucun bâtiment : la tuile visée (choix d'avant à l'identique)")
-- Bâtiments qui ne comptent pas : PNJ debout, objet au sol.
local pnj = { name = "fo-companion", type = "character", valid = true, position = { x = 1.5, y = 0.5 }, box = { 1.2, 0.2, 1.8, 0.8 } }
local item = { name = "item-on-ground", type = "item-entity", valid = true, position = { x = 1.5, y = 0.5 }, box = { 1.4, 0.4, 1.6, 0.6 } }
r, cv = me(fake_surface({ C1, T }, { pnj, item }), { x = 1.5, y = 0.5 }, { "iron-ore" }, team, FREE)
check(r == C1 and cv == nil, "un PNJ debout et un objet au sol ne recouvrent pas la tuile")
Harvest.PLAYER = old_player

-- 6. Minage refusé : une ligne par seconde de jeu au plus, refus sautés comptés.
M.run_ticks(60 - game.tick % 60)
local nm = #lines("minage refuse")
Tj.mine_refused(turret, "PNJ 1 (player, minage a la main)", "iron-ore", "test")
Tj.mine_refused(turret, "PNJ 2 (player, minage a la main)", "iron-ore", "test")
Tj.mine_refused(turret, "PNJ 3 (player, minage a la main)", "iron-ore", "test")
local lm = lines("minage refuse")
check(#lm == nm + 1 and lm[#lm]:find("selection = gun-turret", 1, true) ~= nil and lm[#lm]:find("par PNJ 1", 1, true) ~= nil,
  "minage refusé : une ligne (sélection, qui) dans la seconde : " .. tostring(lm[#lm]))
M.run_ticks(60)
Tj.mine_refused(nil, "PNJ 4 (player, minage a la main)", "iron-ore", "test")
lm = lines("minage refuse")
check(#lm == nm + 2 and lm[#lm]:find("selection = aucune", 1, true) ~= nil and lm[#lm]:find("2 refus non journalise(s)", 1, true) ~= nil,
  "seconde suivante : une ligne, sélection vide écrite, 2 refus sautés comptés : " .. tostring(lm[#lm]))

-- 7. Artillerie (relecture de la 0.6.59 : « toute tourelle ») : absente de la liste partagée Rg.TURRET_TYPES, journalisée quand même.
local gp = W().prototypes["gun-turret"]
W().prototypes["artillery-turret"] = { type = "artillery-turret", max_health = 2000,
  collision_box = { left_top = { x = -1.2, y = -1.2 }, right_bottom = { x = 1.2, y = 1.2 } }, collision_mask = gp.collision_mask }
local art = s.create_entity({ name = "artillery-turret", position = { x = 400.5, y = 5.5 }, force = "player" })
local in_shared = false
for _, ty in ipairs(require("shared.ai3.reglages").TURRET_TYPES) do if ty == "artillery-turret" then in_shared = true end end
check(art ~= nil and art.type == "artillery-turret" and not in_shared and Tj.is_turret(art),
  "artillerie : une tourelle pour le journal, sans toucher la liste partagée de l'IA")
M.run_ticks(60 - game.tick % 60)
local na = #lines("[FO-TOURELLE-MORTE]")
die(art, shooter)
local la = lines("[FO-TOURELLE-MORTE]")
check(#la == na + 1 and la[#la]:find("artillery-turret", 1, true) and la[#la]:find("(400.5, 5.5)", 1, true) ~= nil,
  "artillerie du joueur tuée : une ligne [FO-TOURELLE-MORTE] : " .. tostring(la[#la]))
local art2 = s.create_entity({ name = "artillery-turret", position = { x = 410.5, y = 5.5 }, force = "player" })
local nr2 = #lines("[FO-TOURELLE-RETIREE]")
Tj.removed(Tj.describe(art2), "test", "emprise de test", "deplacee")
check(#lines("[FO-TOURELLE-RETIREE]") == nr2 + 1, "artillerie retirée par le script : une ligne [FO-TOURELLE-RETIREE]")

print(string.format("[TOURELLE-JOURNAL] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
