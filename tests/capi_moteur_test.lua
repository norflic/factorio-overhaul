--[[
  Lot CAPIB : la capitalisation BRANCHÉE, au moteur simulé (tests/mock_engine.lua). Ce n'est pas une preuve en jeu
  (le moteur simulé ne pose pas les fantômes du plan directeur comme le jeu) : il vérifie que le branchement tourne sans
  erreur, décide, envoie ses ordres aux exécutants, et ne fait RIEN réglage éteint.
    §1 réglage allumé (fo-war-capi et fo-war-ia3e) : décisions [FO-CAPI] à chaque cycle de capitalisation (Capi.CYCLE pensées),
       gisements recensés (plus de 64 tuiles quand le gisement en a plus), ordres envoyés, aucun ordre « fours » au-delà du minerai
       livré. Lot X10-S10 (décision du DC du 7/11, 17 h 47, QCM-7/11-X10, OBJECTIFS §4 : « Oui, factions lointaines plus lentes
       (Recommandé) ») : le joueur est posé près de la faction 1 (PROCHE : une pensée toutes les 300 ticks, une décision par minute,
       attendu d'avant S10) ; la faction 2 reste LOINTAINE et calme (une pensée toutes les Cd.SLOW = 600 ticks : une décision toutes
       les 2 min, attendu divisé par la cadence) ;
    §2 réglage fo-war-capi allumé SANS fo-war-ia3e : rien (la capitalisation exige son exécutant) ;
    §3 réglage éteint : aucun état f.team.capi, aucune ligne [FO-CAPI].
  Usage : lua5.2 tests/capi_moteur_test.lua   (depuis la racine du mod ; environ 1 à 2 min)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[CAPI-MOTEUR] ECHEC : " .. msg) end
end
local function say(s) print("[CAPI-MOTEUR] " .. s) end
local function W() return M.world() end
local MIN = 3600

-- Gisements LARGES (le moteur simulé pose un disque de ressource par entrée) : plusieurs entrées voisines par minerai.
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

local function run(opts, minutes)
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful",
    ia3e = opts.ia3e, capi = opts.capi })
  M.load_mod()
  M.dispatch(W().on_init)
  M.command("fo-war", "start 2 30 30 320")
  -- Lot X10-S10 : le joueur à 30 tuiles du QG de la faction 1 (dans sa zone : rythme normal) ; la faction 2 reste loin de lui.
  local f1 = global.fo.war.factions[1]
  if opts.near and f1 and f1.hq_pos then W().player.character.teleport({ x = f1.hq_pos.x + 30, y = f1.hq_pos.y }) end
  local ok, err = pcall(M.run_ticks, minutes * MIN)
  local lines = {}
  for _, l in ipairs(W().logs) do if l:find("[FO-CAPI]", 1, true) then lines[#lines + 1] = l end end
  local out = { ok = ok, err = err, lines = lines, st = {} }
  for i = 1, 2 do
    local f = global.fo.war.factions[i]
    out.st[i] = f and remote.call("fo-capi", "status", f.key) or nil
    out.raw = out.raw or {}
    out.raw[i] = f and f.team and f.team.capi or nil
    -- Lot X10-S10 : la faction est-elle passée en cadence lente (journal [FO-CADENCE] « LENTE ») ?
    out.lente = out.lente or {}
    for _, l in ipairs(W().logs) do
      if f and l:find("[FO-CADENCE] " .. tostring(f.key) .. " : cadence LENTE", 1, true) then out.lente[i] = true end
    end
  end
  return out
end

-- §1 réglage allumé (faction 1 proche du joueur, faction 2 lointaine et calme)
local on = run({ ia3e = true, capi = true, near = true }, 30)
check(on.ok, "§1 branchement allume sans erreur (" .. tostring(on.err) .. ")")
local decisions, orders, maxtiles, deps = 0, 0, 0, 0
for i = 1, 2 do
  local st = on.st[i] or {}
  decisions = decisions + (st.decisions or 0)
  orders = orders + (st.orders or 0)
  for _, d in ipairs(st.deps or {}) do
    deps = deps + 1
    if (d.tiles or 0) > maxtiles then maxtiles = d.tiles end
  end
end
say(string.format("§1 allume : %d decisions, %d ordres envoyes, %d gisements recenses (le plus grand : %d tuiles), %d lignes [FO-CAPI]",
  decisions, orders, deps, maxtiles, #on.lines))
for i = 1, math.min(4, #on.lines) do say("   " .. on.lines[i]:sub(1, 400)) end
for i = math.max(1, #on.lines - 3), #on.lines do say("   " .. on.lines[i]:sub(1, 600)) end
-- Lot X10-S10 : attendu PAR FACTION selon son état. Proche : une décision par minute (au moins 20 en 30 min, attendu d'avant S10).
-- Lointaine et calme : le cycle de capitalisation compte des PENSÉES (Capi.CYCLE = 12, une minute à 300 ticks), donc une décision
-- toutes les 2 min à Cd.SLOW = 600 (décision du DC citée en tête). Seuil 14, juste sous le mesuré (décision du lead du 8/11, sur la
-- note de revue-s : 20 × 300 / 600 = 10 était trop lâche) : 15 décisions mesurées en 30 min, exactement la moitié des 30 de la faction
-- proche et du témoin cadence éteinte.
local Cd = require("shared.faction.cadence")
local d1 = (on.st[1] or {}).decisions or 0
local d2 = (on.st[2] or {}).decisions or 0
check(not on.lente[1] and on.lente[2], string.format("§1 etats : faction 1 jamais en cadence lente (%s), faction 2 lointaine en cadence lente (%s)",
  tostring(on.lente[1]), tostring(on.lente[2])))
check(d1 >= 20, "§1 faction 1 PROCHE du joueur : une decision par minute (au moins 20 en 30 min) : " .. d1)
local FAR_MIN = 14
check(d2 >= FAR_MIN, string.format("§1 faction 2 LOINTAINE et calme : une decision par cycle de %d pensees a %d ticks (au moins %d en 30 min, 15 mesurees) : %d",
  12, Cd.SLOW, FAR_MIN, d2))
check(deps >= 2, "§1 gisements recenses : " .. deps)
-- Le moteur simulé pose une entité de ressource par gisement (une tuile) : le recensement au-delà de 64 tuiles se prouve
-- en moteur réel seulement (banc capi-partie, BRANCHEMENT.md).
check(maxtiles >= 1, "§1 recensement rend la composante (moteur simule : 1 tuile par gisement) : " .. maxtiles)
-- Le moteur simulé n'a pas la foreuse électrique de l'exécutant (fonderies du plan directeur) : aucune extraction n'y est
-- commandée (périmètre du lot : les avant-postes à combustion restent au décideur d'avant) ; chaque décision est écrite.
check(#on.lines >= decisions, "§1 une ligne [FO-CAPI] par decision : " .. #on.lines .. " pour " .. decisions .. " (ordres " .. orders .. ")")

-- §2 capi sans automatisation : rien
local noauto = run({ ia3e = false, capi = true }, 6)
check(noauto.ok, "§2 sans erreur (" .. tostring(noauto.err) .. ")")
check(#noauto.lines == 0 and noauto.raw[1] == nil and noauto.raw[2] == nil,
  "§2 fo-war-capi sans fo-war-ia3e : aucune decision (" .. #noauto.lines .. " lignes)")

-- §3 réglage éteint
local off = run({ ia3e = true, capi = false }, 6)
check(off.ok, "§3 sans erreur (" .. tostring(off.err) .. ")")
check(#off.lines == 0 and off.raw[1] == nil and off.raw[2] == nil, "§3 eteint : aucun etat, aucune ligne (" .. #off.lines .. ")")

print(string.format("[CAPI-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
