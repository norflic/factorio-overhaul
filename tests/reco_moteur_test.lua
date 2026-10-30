--[[
  Lot RECO-DIRECTION : la chaîne de bout en bout sur le MOTEUR SIMULÉ (tests/mock_engine.lua). Règles pures : tests/reco_test.lua.

  Ce qu'il prouve (moteur simulé : chemins droits, tout est généré, aucun ennemi ne chasse l'éclaireur) :
    1. votre équipe : un nid CACHÉ à l'est (hors de l'œil du QG) ; des pièces de l'équipe tuées par des biters venus de l'est (événement
       on_entity_died, filtres du front) ; la direction E devient suspecte ; un ouvrier libre part à l'est (mission « reco ») ; il voit
       le nid ; le nid n'est PAS dans la carte de connaissance de l'équipe tant qu'il n'est pas rentré ; il l'est à son retour ; la
       direction est ensuite expliquée (aucun second envoi) ; la chaîne continue (le nid connu est lu par K.enemy_points, comme
       l'expédition des soldats) ;
    2. éclaireur TUÉ en route : carnet perdu (le nid reste inconnu, aucune marque à l'endroit de sa mort), journal, aucun renvoi pendant le
       délai, direction toujours suspecte, nouvel envoi après le délai, qui trouve le nid ;
    3. une faction : même chaîne (direction suspecte et envoi) ;
    4. reconnaissance coupée (set_reco false) : aucun relevé, aucun envoi ;
    5. attaque d'une faction RIVALE : ne compte pas (seulement les biters) ;
    6. déterminisme (deux parties identiques, mêmes lignes [FO-RECO]) ; état sérialisable.

  Usage : lua5.2 tests/reco_moteur_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[RECO-MOTEUR] ECHEC : " .. msg) end
end
local function W() return M.world() end

local function logs(pat)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(pat, 1, true) then out[#out + 1] = l end end
  return out
end

local NEST = { x = 420, y = 30 }

local function pteam_world()
  local patches = {
    { x = 40, y = 10, name = "coal" }, { x = -30, y = 40, name = "stone" }, { x = 10, y = -45, name = "copper-ore" },
    { x = -40, y = -30, name = "iron-ore" },
  }
  M.new_game({ patches = patches, p_busy = 0, p_nopath = 0, p_lost = 0 })
  rawset(W().prototypes, "biter-spawner", { type = "unit-spawner", max_health = 350 })
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 2 }, { "firearm-magazine", 40 }, { "burner-mining-drill", 12 }, { "stone-furnace", 12 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.new_entity("biter-spawner", NEST.x, NEST.y, s, "enemy")
  return global.fo.pteam.team, s
end

--- Une pièce de l'équipe f tuée par un biter en (x, y) (le tueur à côté). `force` : force du tueur (défaut « enemy »).
local function kill_piece(f, s, x, y, force)
  local e = M.new_entity("stone-furnace", x, y, s, f.force)
  require("script.faction.state").own(e, f.id, "furnace", "test")
  local biter = M.new_entity("small-biter", x + 2, y, s, force or "enemy")
  W().events[defines.events.on_entity_died]({ entity = e, force = biter.force, cause = biter, tick = game.tick })
  e.destroy()
  biter.destroy()
end

local K = require("shared.ai3.carte")

local function nest_known(f)
  local k = f.ai3f
  if not k then return false end
  for _, p in ipairs(K.enemy_points(k.m, NEST.x, NEST.y, 16)) do
    if p.kind == "spawner" then return true end
  end
  return false
end

--- Joue jusqu'à `limit` ticks, par pas de 60, en appelant `each(tick)` ; s'arrête quand each rend vrai.
local function run_until(limit, each)
  for _ = 1, limit / 60 do
    M.run_ticks(60)
    if each(game.tick) then return true end
  end
  return false
end

---------------------------------------------------------------------------------------------------
-- 1. Votre équipe : attaques de l'est, éclaireur, nid connu au retour seulement
---------------------------------------------------------------------------------------------------
local function play_success()
  local f, s = pteam_world()
  M.run_ticks(3 * 3600)
  check(f.ai3f and f.ai3f.home_seen, "abords du QG vus (condition d'envoi)")
  check(not nest_known(f), "nid caché : inconnu de l'équipe au départ")
  kill_piece(f, s, 60, 4)
  M.run_ticks(600)
  kill_piece(f, s, 64, -6)
  local sus = logs("[FO-RECO] player : direction E suspecte")
  check(#sus == 1, "direction E suspecte après deux pièces perdues (" .. #sus .. ")")
  local sent_at, seen_at, back_at, known_at, known_while_out = nil, nil, nil, nil, false
  run_until(10 * 3600, function(t)
    if not sent_at and #logs("[FO-RECO] player : eclaireur") > 0 and #logs("envoye vers E") > 0 then sent_at = t end
    if not seen_at and #logs("voit un nid") > 0 then seen_at = t end
    if not back_at and #logs("de retour de E") > 0 then back_at = t end
    local kn = nest_known(f)
    if kn and not known_at then known_at = t end
    if kn and not back_at then known_while_out = true end
    return back_at ~= nil and t - back_at > 1200
  end)
  return f, s, sent_at, seen_at, back_at, known_at, known_while_out
end

local f, s, sent_at, seen_at, back_at, known_at, known_while_out = play_success()
check(sent_at ~= nil, "éclaireur envoyé vers l'est (" .. tostring(sent_at and sent_at / 3600) .. " min)")
check(seen_at ~= nil and sent_at and seen_at > sent_at, "il voit le nid en marchant (" .. tostring(seen_at and seen_at / 3600) .. " min)")
check(not known_while_out, "le nid n'entre PAS dans la carte de l'équipe tant que l'éclaireur n'est pas rentré")
check(back_at ~= nil and seen_at and back_at > seen_at, "il rentre (" .. tostring(back_at and back_at / 3600) .. " min)")
check(known_at ~= nil and back_at and known_at >= back_at - 60, "le nid est connu à son retour (" .. tostring(known_at and known_at / 3600) .. " min)")
check(seen_at and back_at and back_at - seen_at >= 600, "transmission au retour, pas au moment où il le voit (" ..
  tostring(seen_at and back_at and (back_at - seen_at)) .. " ticks plus tard)")
check(f.reco and f.reco.sent == 1 and f.reco.back == 1 and f.reco.found == 1 and f.reco.lost == 0, "compteurs : 1 envoi, 1 retour avec nid")
-- Une pièce tuée par un VER (tueur immobile) ne donne pas de direction.
do
  rawset(W().prototypes, "small-worm-turret", { type = "turret", max_health = 200 })
  local hits0 = f.reco.hits
  local e = M.new_entity("stone-furnace", -80, 0, s, f.force)
  require("script.faction.state").own(e, f.id, "furnace", "test")
  local worm = M.new_entity("small-worm-turret", -90, 0, s, "enemy")
  W().events[defines.events.on_entity_died]({ entity = e, force = worm.force, cause = worm, tick = game.tick })
  e.destroy()
  worm.destroy()
  check(f.reco.hits == hits0, "pièce tuée par un ver (immobile) : aucune direction relevée")
end
check(#logs("[FO-IA3F] player : eclaireur") >= 1 and #logs("(reco)") >= 1, "mission de la machinerie d'IA3-f (journal [FO-IA3F], genre reco)")
-- La direction est expliquée : plus d'envoi, même si les attaques continuent.
kill_piece(f, s, 62, 2)
kill_piece(f, s, 61, 0)
M.run_ticks(20 * 3600)
check(f.reco.sent == 1, "direction expliquée par le nid connu : aucun second envoi (" .. f.reco.sent .. ")")
check(#logs("direction E expliquee par le nid connu") >= 1, "journal : direction expliquée")
check(K.enemy_points(f.ai3f.m, 0, 0, 480)[1] ~= nil, "le nid connu est lu par K.enemy_points (comme l'expédition des soldats, Sd.add_known)")
check(pcall(M.serialize, global), "global sérialisable (votre équipe)")
local lines_a = logs("[FO-RECO]")
for _, l in ipairs(lines_a) do print("  " .. l) end

---------------------------------------------------------------------------------------------------
-- 6. Déterminisme
---------------------------------------------------------------------------------------------------
do
  play_success()
  kill_piece(global.fo.pteam.team, game.surfaces[1], 62, 2)
  kill_piece(global.fo.pteam.team, game.surfaces[1], 61, 0)
  M.run_ticks(20 * 3600)
  local b = logs("[FO-RECO]")
  local same = #b == #lines_a
  for i = 1, math.min(#b, #lines_a) do if b[i] ~= lines_a[i] then same = false end end
  check(same, "deux parties identiques : mêmes lignes [FO-RECO] (" .. #lines_a .. " et " .. #b .. ")")
end

---------------------------------------------------------------------------------------------------
-- 2. Éclaireur tué en route
---------------------------------------------------------------------------------------------------
do
  local f2, s2 = pteam_world()
  -- Pour isoler le RENVOI de la reconnaissance, les demandes d'exploration ordinaires (ressources) sont effacées à chaque pas : sinon un
  -- éclaireur d'IA3-f (qui, lui, transmet ce qu'il voit tout de suite : comportement d'avant le lot) peut voir le nid le premier
  -- (moteur simulé, 29/10 : explorations du charbon à 8,6 et 13,0 min, nid connu à 13,1 min, avant la fin du délai). Les besoins de sites
  -- (qui rouvrent ces demandes toutes les 30 s) sont donc vidés aussi.
  local function quiet()
    f2.site_needs = {}
    if f2.ai3f then
      f2.ai3f.req = {}
      -- Une exploration ordinaire partie entre deux pas est rappelée tout de suite (durée écoulée : retour au QG).
      for _, ex in ipairs(f2.ai3f.exl or {}) do
        if ex.kind == "explore" and ex.state ~= "home" then ex.started = -10 ^ 9 end
      end
    end
  end
  local function run(n) for _ = 1, n / 60 do quiet(); M.run_ticks(60) end end
  run(3 * 3600)
  kill_piece(f2, s2, 60, 4)
  kill_piece(f2, s2, 64, -6)
  local killed_at, scout_id, death_p = nil, nil, nil
  run_until(10 * 3600, function(t)
    quiet()
    for _, ex in ipairs(f2.ai3f.exl or {}) do
      if ex.kind == "reco" and (ex.leg or 0) >= 2 then
        local a = require("script.companion.registry").get(ex.agent)
        if a and a.entity and a.entity.valid then
          local p = a.entity.position
          if p.x > 150 then
            scout_id = a.id
            death_p = { x = p.x, y = p.y }
            -- Relecture : tué PAR UN BITER (cause « small-biter/enemy », comme en jeu ; le die() du moteur simulé ne donne pas de
            -- tueur, la carte du danger d'IA3-k ne l'aurait pas noté de toute façon), puis corps détruit.
            local biter = M.new_entity("small-biter", p.x + 2, p.y, a.entity.surface, "enemy")
            W().events[defines.events.on_entity_died]({ entity = a.entity, force = biter.force, cause = biter, tick = game.tick })
            a.entity.destroy()
            killed_at = t
            return true
          end
        end
      end
    end
    return false
  end)
  check(killed_at ~= nil, "éclaireur tué en route, à plus de 150 tuiles du QG")
  run(600)
  check(#logs("ECLAIREUR " .. tostring(scout_id) .. " MORT") >= 1 or #logs("ECLAIREUR " .. tostring(scout_id) .. " PERDU") >= 1,
    "journal : mort de l'éclaireur, carnet perdu")
  check(f2.reco.lost == 1 and f2.reco.back == 0, "compteurs : 1 perte, aucun retour")
  check(not nest_known(f2), "carnet perdu : le nid reste inconnu")
  local marks_far = 0
  for _, mk in ipairs(f2.ai3f.m.marks) do if mk.x > 120 then marks_far = marks_far + 1 end end
  check(marks_far == 0, "aucune marque de danger à l'endroit de sa mort (l'équipe ne sait pas où il est tombé)")
  -- Relecture : ni dans la carte du danger d'IA3-k (réflexes de route de toute l'équipe, D.mark_death).
  local Cm = require("script.ai3.comportement")
  local Dg = require("shared.ai3.danger")
  local tm = Cm.team(f2)
  check(death_p ~= nil and Dg.deaths_near(tm.map, { death_p }, 48, game.tick) == 0 and (tm.stats.deaths_reco or 0) == 1,
    "aucune mort marquée dans la carte du danger d'IA3-k à l'endroit de sa mort (" .. tostring(tm.stats.deaths_reco) .. " mort compté à part)")
  local sent0 = f2.reco.sent
  run(require("shared.ai3.reco").COOL_DEATH - 1800)
  check(f2.reco.sent == sent0, "aucun renvoi pendant le délai")
  check(f2.reco.sec[1] and f2.reco.sec[1].w >= require("shared.ai3.reco").SEND_MIN, "direction E toujours suspecte (" ..
    tostring(f2.reco.sec[1] and f2.reco.sec[1].w) .. ")")
  local back_before = #logs("de retour de E")
  local by_reco, by_other = false, false
  run_until(12 * 3600, function()
    quiet()
    if #logs("de retour de E") > back_before then by_reco = true return true end
    if nest_known(f2) then by_other = true return true end
    return false
  end)
  check(f2.reco.sent >= 2, "nouvel envoi après le délai (" .. f2.reco.sent .. ")")
  check(by_reco, "explorations ordinaires coupées : c'est le second éclaireur qui rapporte le nid")
  if by_reco then
    check(nest_known(f2), "second éclaireur rentré : nid transmis")
    print("  cas 2 : le second éclaireur a rapporté le nid")
  else
    -- Un éclaireur ordinaire d'IA3-f (transmission immédiate, comportement d'avant le lot) l'a vu le premier : la direction devient
    -- expliquée et le second éclaireur n'apporte rien de plus (moteur simulé, 29/10 : explorateur du fer à 141 tuiles du nid).
    run(3600)
    check(#logs("direction E expliquee") >= 1 or f2.reco.back >= 1, "nid vu par un autre œil : direction expliquée ensuite")
    print("  cas 2 : le nid a été vu d'abord par un éclaireur ordinaire (IA3-f) pendant la seconde reconnaissance")
  end
  check(pcall(M.serialize, global), "global sérialisable (après une mort)")
end

---------------------------------------------------------------------------------------------------
-- 4. Reconnaissance coupée (5. attaque d'une faction rivale : section 3)
---------------------------------------------------------------------------------------------------
do
  local f3, s3 = pteam_world()
  remote.call("fo-ia3f", "set_reco", false)
  check(global.fo.ai3f.reco_off == true, "coupure rangée dans global (survit au chargement d'une sauvegarde)")
  M.run_ticks(3 * 3600)
  kill_piece(f3, s3, 60, 4)
  kill_piece(f3, s3, 64, -6)
  M.run_ticks(5 * 3600)
  check(f3.reco == nil and #logs("[FO-RECO] player : eclaireur") == 0, "reconnaissance coupée : aucun relevé, aucun envoi")
  remote.call("fo-ia3f", "set_reco", true)
  check(global.fo.ai3f.reco_off == nil, "reconnaissance rallumée : drapeau retiré de global")
end
---------------------------------------------------------------------------------------------------
-- 3. Une faction : même chaîne
---------------------------------------------------------------------------------------------------
do
  local patches = {}
  for _, c in ipairs({ { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }) do
    local hx, hy = c[1] * 320 * 0.7071, c[2] * 320 * 0.7071
    for i, name in ipairs({ "coal", "iron-ore", "copper-ore", "stone" }) do
      patches[#patches + 1] = { x = hx + (i - 2.5) * 30, y = hy + 40, name = name, amount = 50000 }
    end
  end
  M.new_game({ seed = 4242, patches = patches, p_busy = 0, p_nopath = 0, p_lost = 0 })
  rawset(W().prototypes, "biter-spawner", { type = "unit-spawner", max_health = 350 })
  check(remote.call("factorio-overhaul", "war_start", 4, 20, 6, 320) == true, "guerre lancée (4 factions)")
  M.run_ticks(4 * 3600)
  local war = global.fo.war
  local fa = war.factions[1]
  local surface = game.surfaces[1]
  -- Nid caché à 300 tuiles au nord du QG de la faction.
  M.new_entity("biter-spawner", fa.hq_pos.x, fa.hq_pos.y - 330, surface, "enemy")
  kill_piece(fa, surface, fa.hq_pos.x + 2, fa.hq_pos.y - 40)
  kill_piece(fa, surface, fa.hq_pos.x - 3, fa.hq_pos.y - 44)
  -- Attaque d'une faction RIVALE : ne compte pas.
  local fb = war.factions[2]
  local before = fa.reco and fa.reco.hits or 0
  kill_piece(fa, surface, fa.hq_pos.x + 40, fa.hq_pos.y, fb.force)
  check((fa.reco and fa.reco.hits or 0) == before, "pièce tuée par une faction rivale : pas une attaque de biters")
  check(#logs("[FO-RECO] " .. fa.key .. " : direction N suspecte") == 1, fa.key .. " : direction N suspecte")
  local ok = run_until(15 * 3600, function()
    return #logs("[FO-RECO] " .. fa.key .. " : eclaireur") > 0 and #logs("de retour de N") > 0
  end)
  check(#logs("[FO-RECO] " .. fa.key .. " : eclaireur") > 0, fa.key .. " : éclaireur envoyé vers le nord")
  check(ok, fa.key .. " : éclaireur rentré")
  local known = false
  for _, p in ipairs(K.enemy_points(fa.ai3f.m, fa.hq_pos.x, fa.hq_pos.y - 330, 16)) do if p.kind == "spawner" then known = true end end
  check(known, fa.key .. " : nid connu après le retour")
  for _, l in ipairs(logs("[FO-RECO] " .. fa.key)) do print("  " .. l) end
  check(pcall(M.serialize, global), "global sérialisable (factions)")
end

print(string.format("[RECO-MOTEUR] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
