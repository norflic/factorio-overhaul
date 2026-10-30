--[[
  Lot FER-MARQUE : banc HORS JEU de la CHAÎNE au moteur simulé (tests/mock_engine.lua), même départ que tests/survie_moteur_test.lua
  (votre équipe, coffre, fo-war-ia3-comportement allumé). Le vrai M.gate et le vrai M.sense de script/ai3/comportement.lua.

    1. mode survie ÉTEINT : un gisement marqué seulement par des cases mobiles (6 unités vues : 900) est refusé 8 fois sur 8 (avant) ;
    2. mode survie ALLUMÉ, tâche de ressources (service, rebuild) : 2 refus, puis départ (famine), passe-droit ensuite ; journal
       [FO-FAMINE] ; compteur du séjour ; tâche de DÉFENSE (fortify) : refusée comme avant ;
    3. menace FIXE (ver) au but, même avec les cases mobiles : 8 refus sur 8, ligne « prudence gardee » ;
       3 bis (relecture) : une mort ancienne au but (calme) ne bloque pas ; Fa.DEATHS_MAX morts de l'heure au but : 8 refus sur 8 ;
    4. regard d'un PNJ sur place, sans ennemi : les cases mobiles vides sont effacées en survie, pas hors survie ;
    5. global sérialisable ; déterminisme (deux passages identiques).
  Lancement : lua5.2 tests/fer_marque_moteur_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local function setup()
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  if W().remote["fo-ia3f"] then remote.call("fo-ia3f", "set_fog", false) end
  W().prototypes["small-worm-turret"] = { type = "turret", max_health = 200,
    collision_box = { left_top = { x = -0.9, y = -0.8 }, right_bottom = { x = 0.9, y = 0.8 } },
    attack_parameters = { range = 25 } }
  local s = game.surfaces[1]
  s.find_nearest_enemy = function(t)
    local best, bd
    for _, e in ipairs(W().entities) do
      if e.valid and e.force and e.force.name == "enemy" then
        local dx, dy = e._x - t.position.x, e._y - t.position.y
        local d = dx * dx + dy * dy
        if d <= t.max_distance * t.max_distance and (not bd or d < bd) then best, bd = e, d end
      end
    end
    return best
  end
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 30 }, { "coal", 200 }, { "stone-furnace", 8 }, { "pistol", 2 }, { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(600)
  return global.fo.pteam.team
end

local function logs_with(tag)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(tag, 1, true) then out[#out + 1] = l end end
  return out
end

local function run_all()
  local trace = {}
  local f = setup()
  local C = require("script.ai3.comportement")
  local Fa = require("shared.team.famine")
  local Survie = require("script.team.survie")
  local Registry = require("script.companion.registry")
  local ids = {}
  for id in pairs(f.engineers) do ids[#ids + 1] = id end
  table.sort(ids)
  local ag = Registry.get(ids[4])
  remote.call("fo-ia3k", "forget", "player")
  ag.entity.teleport({ x = 0, y = 10 })
  local gx, gy = 40, -70 -- gisement : à 80 tuiles du QG, hors de la garde du QG (32)
  local function wave(x, y) x, y = x or gx, y or gy for u = 1, 6 do remote.call("fo-ia3k", "mark", "player", x + 4, y + u, "unit") end end
  local function steps_to(x, y, act) return { { "home" }, { "goto", { x = x, y = y }, 3 }, { "act", act }, { "home" } } end
  local function tries(kind, key, n, x, y)
    local refused, first = 0, nil
    for i = 1, n do
      if C.gate(f, ag, { key = key, kind = kind }, steps_to(x or gx, y or gy, kind), game.tick) then first = first or i else refused = refused + 1 end
    end
    return refused, first
  end

  ---------------------------------------------------------------------------------------------------
  section("1. Mode survie éteint : le gisement reste fermé (avant)")
  ---------------------------------------------------------------------------------------------------
  check(C.enabled() and not Survie.on(f), "comportements allumés, mode survie éteint")
  wave()
  local dg = remote.call("fo-ia3k", "danger", "player")
  check(dg and #dg.threats == 0 and dg.summary.cells > 0, "le but n'est marqué que par des cases mobiles (" .. tostring(dg and dg.summary.cells) .. " cases, 0 menace fixe)")
  local r0 = tries("service", "fm:service-off", 8)
  check(r0 == 8, "hors survie : " .. r0 .. " refus sur 8 (règle d'avant)")
  check(#logs_with("[FO-FAMINE]") == 0, "hors survie : aucune ligne [FO-FAMINE]")

  ---------------------------------------------------------------------------------------------------
  section("2. Mode survie allumé : famine")
  ---------------------------------------------------------------------------------------------------
  local s = Survie.state(f)
  s.on, s.since, s.beat = true, game.tick, game.tick
  -- But neuf B (aucun refus d'avant) : 2 refus, puis départ, puis passe-droit.
  local bx, by = -40, -70
  wave(bx, by)
  local r1, first1 = tries("service", "fm:service-on", 8, bx, by)
  check(first1 == Fa.W + 1, "service : départ au " .. tostring(first1) .. "e essai (attendu " .. (Fa.W + 1) .. ")")
  check(r1 == Fa.W, "service : " .. r1 .. " refus sur 8 (passe-droit ensuite)")
  local fl = logs_with("[FO-FAMINE]")
  check(#fl >= 3 and fl[1]:find("-> wait", 1, true) and fl[Fa.W + 1]:find("-> go (famine)", 1, true)
    and fl[Fa.W + 2]:find("-> go (passe-droit)", 1, true), "journal : attentes, « go (famine) », puis passe-droit (" .. tostring(fl[Fa.W + 1]) .. ")")
  check(fl[1]:find("mobile 900, fixe 0, morts 0, seuil", 1, true) ~= nil, "journal : parts du but (" .. tostring(fl[1]) .. ")")
  check((s.famine_go or 0) >= 1, "compteur du séjour : " .. tostring(s.famine_go) .. " départ(s) de famine")
  -- But A, refusé 8 fois hors survie : ces refus de suite comptent (même destination) : départ au premier essai en survie.
  local rA, firstA = tries("service", "fm:service-A", 1)
  check(firstA == 1, "but déjà refusé 8 fois avant le mode : départ dès le 1er essai en survie (refus de suite gardés par destination)")
  -- Reconstruction vers un but neuf C.
  local cx, cy = -60, 40
  wave(cx, cy)
  local r2, first2 = tries("rebuild", "fm:rebuild-on", 8, cx, cy)
  check(first2 == Fa.W + 1, "reconstruction vers le gisement : départ au " .. tostring(first2) .. "e essai (" .. r2 .. " refus)")
  -- Défense vers un but neuf D : règle d'avant.
  local dx_, dy_ = 70, 40
  wave(dx_, dy_)
  local r3 = tries("fortify", "fm:fortify-on", 8, dx_, dy_)
  check(r3 == 8, "tâche de défense (fortify) : " .. r3 .. " refus sur 8 (hors famine)")

  ---------------------------------------------------------------------------------------------------
  section("3. Menace fixe au but : prudence gardée")
  ---------------------------------------------------------------------------------------------------
  remote.call("fo-ia3k", "forget", "player")
  wave()
  wave(90, -90)
  remote.call("fo-ia3k", "mark", "player", 100, -90, "worm", 25)
  local r4 = tries("service", "fm:service-ver", 8, 90, -90)
  check(r4 == 8, "ver connu au but + cases mobiles : " .. r4 .. " refus sur 8")
  local kl = logs_with("prudence gardee")
  check(#kl >= 1 and kl[1]:find("menace fixe au but", 1, true) ~= nil, "journal : « prudence gardee » (" .. tostring(kl[1]) .. ")")

  ---------------------------------------------------------------------------------------------------
  section("3 bis. Morts au but (calme) : une ou deux ne bloquent pas, Fa.DEATHS_MAX gardent la prudence (relecture)")
  ---------------------------------------------------------------------------------------------------
  -- Morts « anciennes » (plus d'une minute : calme d'ACTIF, tâche proche du QG) posées au but E, puis vieillies à la main.
  local function deaths_at(x, y, n)
    for _ = 1, n do remote.call("fo-ia3k", "death", "player", x + 1, y + 1) end
    for _, d in ipairs(C.team(f).map.deaths) do d.t = game.tick - 2 * 3600 end
  end
  remote.call("fo-ia3k", "forget", "player")
  local ex, ey = -70, -20
  wave(ex, ey)
  deaths_at(ex, ey, 1)
  local r5, first5 = tries("service", "fm:service-mort1", 8, ex, ey)
  check(first5 == Fa.W + 1, "1 mort ancienne au but (calme) + cases mobiles : départ au " .. tostring(first5) .. "e essai (" .. r5 .. " refus)")
  remote.call("fo-ia3k", "forget", "player")
  local hx, hy = 60, 60
  wave(hx, hy)
  deaths_at(hx, hy, Fa.DEATHS_MAX)
  local r6 = tries("service", "fm:service-morts", 8, hx, hy)
  check(r6 == 8, Fa.DEATHS_MAX .. " morts anciennes au but (calme) + cases mobiles : " .. r6 .. " refus sur 8 (pas de marche suicide)")
  local fs = C.team(f).stats.famine or {}
  check((fs["prudence:morts"] or 0) == 8, "compteur : " .. tostring(fs["prudence:morts"]) .. " refus « prudence:morts » (8 attendus : la règle de famine les a jugés)")
  -- (la ligne « prudence gardee » est limitée à une toutes les Fa.KEEP_LOG ticks par équipe : celle du ver, section 3, est au même tick)
  C.team(f).famine_keep_t = nil
  tries("service", "fm:service-morts", 1, hx, hy)
  local ml = logs_with("morts de l'heure au but ou plus")
  check(#ml >= 1, "journal : « prudence gardee » pour les morts au but (" .. tostring(ml[1]) .. ")")

  ---------------------------------------------------------------------------------------------------
  section("4. Regard sur place : marque vide effacée")
  ---------------------------------------------------------------------------------------------------
  local function look_at_goal()
    remote.call("fo-ia3k", "forget", "player")
    wave()
    local before = remote.call("fo-ia3k", "danger", "player").summary.cells
    ag.entity.teleport({ x = gx, y = gy })
    for _ = 1, 30 do
      M.run_ticks(60)
      if ag.entity.valid then ag.entity.teleport({ x = gx, y = gy }) end
      C.sense(ag, game.tick)
      if remote.call("fo-ia3k", "danger", "player").summary.cells < before then break end
    end
    return before, remote.call("fo-ia3k", "danger", "player").summary.cells
  end
  s.on = false
  local b_off, a_off = look_at_goal()
  check(a_off == b_off, "hors survie : le regard n'efface rien (" .. b_off .. " -> " .. a_off .. " cases)")
  s.on, s.since = true, game.tick
  local b_on, a_on = look_at_goal()
  check(a_on < b_on, "survie : le regard vide efface des cases mobiles (" .. b_on .. " -> " .. a_on .. ")")
  local rl = logs_with("[FO-FAMINE] player : regard")
  check(#rl >= 1, "journal : ligne de regard (" .. tostring(rl[1]) .. ")")
  check((s.famine_clear or 0) > 0, "compteur du séjour : " .. tostring(s.famine_clear) .. " case(s) effacée(s)")
  ag.entity.teleport({ x = 0, y = 10 })

  ---------------------------------------------------------------------------------------------------
  section("5. Sauvegarde")
  ---------------------------------------------------------------------------------------------------
  check(pcall(M.serialize, global), "global sérialisable (aucune fonction)")
  trace.log = table.concat(logs_with("[FO-FAMINE]"), "\n")
  trace.tick = game.tick
  return trace
end

local r1 = run_all()
print(string.format("[FER-MARQUE-MOTEUR] premier passage : %d OK, %d ECHEC(S)", passes, failures))
local p1, f1 = passes, failures
passes, failures = 0, 0
local r2 = run_all()
section("6. Déterminisme : deux passages identiques")
check(r1.log == r2.log and r1.tick == r2.tick, "mêmes lignes [FO-FAMINE], même tick final")
print(string.format("[FER-MARQUE-MOTEUR] BILAN : %d OK, %d ECHEC(S) (premier passage %d OK, %d ECHEC)", passes + p1, failures + f1, p1, f1))
os.exit((failures + f1) == 0 and 0 or 1)
