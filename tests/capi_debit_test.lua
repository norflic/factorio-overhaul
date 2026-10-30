--[[
  Lot CAPI-DEBIT (30/10) : emplacements du plan directeur ouverts aux modules de la capitalisation.
    §1 classe d'un ordre « module » ouvert (matière, figé, actif) ;
    §2 emplacements de plus par le stock libre des produits des fonderies ;
    §3 compte des emplacements (figés hors du compte, matière toujours comptée, plafond des figés), le cas mesuré d'Azur ;
    §4 texte du refus (préfixe de main), déterminisme, état sans fonction ;
    §5 mutants (chaque règle a un contrôle qui la tient) ;
    §6 branchement au moteur simulé (tests/mock_engine.lua) : Capi.slots lit les ordres ouverts et l'état des modules de
       l'exécutant tels que le runtime les range, écrit [FO-CAPI-EMPLACEMENTS] au changement seulement. Ce n'est PAS une preuve
       en jeu (le moteur simulé n'a pas la foreuse électrique de l'exécutant : aucun module n'y part).
  Usage : lua5.2 tests/capi_debit_test.lua   (depuis la racine du mod ; environ 30 s, §6 compris)
]]
package.path = "./?.lua;" .. package.path
local Em = require("shared.ai3.emplacements")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("[CAPI-DEBIT] ECHEC : " .. msg) end
  end
end
local function say(s) print("[CAPI-DEBIT] " .. s) end
local MIN = 3600

local function mod(key, states, progress, opened) return { key = key, states = states, progress_tick = progress, opened = opened or 0 } end

local function suite()
  local T = 100 * MIN
  -- §1 classe
  check(Em.class(mod("a", { "reserve" }, T - 60 * MIN), T) == "matiere", "§1 un module en réserve attend sa matière, même vieux")
  check(Em.class(mod("a", { "attente" }, T), T) == "matiere", "§1 un module pas encore planifié compte comme matière")
  check(Em.class(mod("a", { "chantier" }, T - 2 * MIN), T) == "actif", "§1 un chantier qui a progressé il y a 2 min est actif")
  check(Em.class(mod("a", { "defrichage" }, T - 10 * MIN), T) == "fige", "§1 défrichage sans entité bâtie depuis 10 min : figé")
  check(Em.class(mod("a", { "bloque" }, T - 11 * MIN), T) == "fige", "§1 bloqué depuis 11 min : figé")
  check(Em.class(mod("a", { "chantier" }, T - 10 * MIN + 1), T) == "actif", "§1 un tick sous la borne : encore actif")
  check(Em.class(mod("a", { "reserve", "chantier" }, T - 30 * MIN), T) == "matiere", "§1 un module en réserve dans l'ordre : matière")
  check(Em.class(mod("a", { "fini" }, T - 30 * MIN), T) == "actif", "§1 fini (fermé au suivi suivant) : compté, jamais libéré")
  check(Em.class(mod("a", {}, T - 30 * MIN), T) == "actif", "§1 sans module connu : compté (prudent)")
  check(Em.class({ key = "a", states = { "chantier" }, opened = T - 12 * MIN }, T) == "fige", "§1 sans progrès noté : l'ouverture fait foi")
  -- relecture : entrée en chantier (le temps de réserve ne compte pas dans le « figé »)
  check(Em.work_tick(nil, { "reserve" }, T) == nil, "§1 horloge de chantier : rien tant que la matière est attendue")
  check(Em.work_tick(T - 5 * MIN, { "reserve", "chantier" }, T) == nil, "§1 horloge remise à nil si un module retourne en réserve")
  check(Em.work_tick(nil, { "defrichage" }, T) == T, "§1 horloge posée à la première pensée en chantier")
  check(Em.work_tick(T - 5 * MIN, { "chantier" }, T) == T - 5 * MIN, "§1 horloge gardée pendant le chantier")
  check(Em.work_tick(T - 5 * MIN, { "fini" }, T) == nil, "§1 horloge sans objet hors chantier")
  check(Em.class({ key = "a", states = { "defrichage" }, progress_tick = T - 14 * MIN, work_tick = T - MIN }, T) == "actif",
    "§1 sorti de réserve il y a 1 min après 14 min de réserve : actif (pas figé dès le premier tick)")
  check(Em.class({ key = "a", states = { "defrichage" }, progress_tick = T - 30 * MIN, work_tick = T - 10 * MIN }, T) == "fige",
    "§1 10 min de chantier sans entité bâtie après la réserve : figé")
  check(Em.class({ key = "a", states = { "chantier" }, progress_tick = T - 3 * MIN, work_tick = T - 20 * MIN }, T) == "actif",
    "§1 entité bâtie après l'entrée en chantier : le dernier progrès fait foi")
  -- §2 stock
  check(Em.extra({}) == 0, "§2 aucun produit : aucun emplacement de plus")
  check(Em.extra(nil) == 0, "§2 stock absent : 0")
  check(Em.extra({ 999, 50000 }) == 0, "§2 le produit le plus faible décide (999 < 1000)")
  check(Em.extra({ 1000, 1000 }) == 1, "§2 1000 de chaque : un de plus")
  check(Em.extra({ 2500, 50000 }) == 2, "§2 2500 et 50000 : deux de plus")
  check(Em.extra({ 50000, 50000 }) == Em.EXTRA_MAX, "§2 plafonné à Em.EXTRA_MAX")
  check(Em.extra({ -5, "x" }) == 0, "§2 valeurs invalides : 0")
  -- §3 compte
  local s = Em.slots({ base = 2, plates = { 0, 0 }, mods = {}, tick = T })
  check(s.cap == 2 and s.room == 2 and not s.busy, "§3 rien d'ouvert : 2 emplacements libres")
  s = Em.slots({ base = 2, plates = { 0, 0 }, mods = { mod("a", { "chantier" }, T), mod("b", { "fantomes" }, T - MIN) }, tick = T })
  check(s.busy and s.room == 0 and s.counted == 2, "§3 deux chantiers actifs, stock pauvre : occupé (comme main)")
  s = Em.slots({ base = 2, plates = { 0, 0 }, mods = { mod("a", { "reserve" }, 0), mod("b", { "reserve" }, 0) }, tick = T })
  check(s.busy and s.materials == 2, "§3 deux modules en réserve depuis longtemps : ils tiennent leurs emplacements (coffre protégé)")
  s = Em.slots({ base = 2, plates = { 0, 0 }, mods = { mod("a", { "defrichage" }, T - 20 * MIN), mod("b", { "bloque" }, T - 15 * MIN) }, tick = T })
  check(not s.busy and s.room == 2 and s.free_stalled == 2 and #s.keys_stalled == 2, "§3 deux modules figés : les deux emplacements sont libres")
  s = Em.slots({ base = 2, plates = { 0, 0 }, mods = { mod("a", { "defrichage" }, 0), mod("b", { "bloque" }, 0), mod("c", { "chantier" }, 0) }, tick = T })
  check(s.free_stalled == Em.STALLED_FREE and s.counted == 3 - Em.STALLED_FREE and s.room == 2 - (3 - Em.STALLED_FREE),
    "§3 au plus Em.STALLED_FREE figés hors du compte (" .. s.why .. ")")
  check(s.keys_stalled[1] == "a" and s.keys_stalled[2] == "b", "§3 les premiers figés dans l'ordre des ordres ouverts sont libérés")
  s = Em.slots({ base = 2, plates = { 5000, 5000 }, mods = { mod("a", { "chantier" }, T), mod("b", { "chantier" }, T) }, tick = T })
  check(s.cap == 4 and s.room == 2 and not s.busy, "§3 stock riche : deux emplacements de plus")
  s = Em.slots({ base = 2, plates = { 5000, 300 }, mods = { mod("a", { "chantier" }, T), mod("b", { "chantier" }, T) }, tick = T })
  check(s.busy and s.extra == 0, "§3 fer riche mais cuivre pauvre : aucun de plus (les foreuses demandent les deux)")
  -- cas mesuré d'Azur (audit CAPI-AUDIT : un module en défrichage depuis 74 min, un en réserve ; 48 950 fers au coffre)
  s = Em.slots({ base = 2, plates = { 48950, 3000 }, mods = { mod("couvrir:fer", { "defrichage" }, T - 74 * MIN), mod("chaine:x", { "reserve" }, T - 5 * MIN) }, tick = T })
  check(s.counted == 1 and s.cap == 4 and s.room == 3, "§3 cas d'Azur : 3 emplacements libres au lieu de 0 (" .. s.why .. ")")
  -- même partie sans stock : le figé seul libère
  s = Em.slots({ base = 2, plates = { 0, 0 }, mods = { mod("couvrir:fer", { "defrichage" }, T - 74 * MIN), mod("chaine:x", { "reserve" }, T - 5 * MIN) }, tick = T })
  check(s.room == 1, "§3 cas d'Azur sans stock : 1 emplacement libre (le figé)")
  -- §4 texte, déterminisme
  check(Em.busy_text(s):sub(1, #"plan directeur occupe (") == "plan directeur occupe (", "§4 préfixe du refus de main gardé")
  local in1 = { base = 2, plates = { 1200, 1500 }, mods = { mod("a", { "chantier" }, 0), mod("b", { "reserve" }, T) }, tick = T }
  local a, b = Em.slots(in1), Em.slots(in1)
  check(a.why == b.why and a.room == b.room and table.concat(a.keys_stalled, ",") == table.concat(b.keys_stalled, ","), "§4 même entrée, même sortie")
  local function pure(t, d)
    for _, v in pairs(t) do
      if type(v) == "function" then return false end
      if type(v) == "table" and (d > 4 or not pure(v, d + 1)) then return false end
    end
    return true
  end
  check(pure(a, 0), "§4 la sortie ne contient aucune fonction (elle va dans global : cs.slots)")
end

suite()
say(string.format("§1-§4 : %d OK, %d ECHEC(S)", passes, failures))

-- §5 mutants : chacun doit faire échouer au moins un contrôle
local function mutant(name, apply, undo)
  local p0, f0 = passes, failures
  quiet = true
  apply()
  suite()
  undo()
  quiet = false
  local caught = failures > f0
  passes, failures = p0, f0
  check(caught, "§5 mutant détecté : " .. name)
end
local S0, F0, E0, P0 = Em.STALL, Em.STALLED_FREE, Em.EXTRA_MAX, Em.PER_SLOT
mutant("jamais figé", function() Em.STALL = math.huge end, function() Em.STALL = S0 end)
mutant("figé dès 1 min", function() Em.STALL = MIN end, function() Em.STALL = S0 end)
mutant("figés sans plafond", function() Em.STALLED_FREE = 99 end, function() Em.STALLED_FREE = F0 end)
mutant("aucun emplacement par le stock", function() Em.EXTRA_MAX = 0 end, function() Em.EXTRA_MAX = E0 end)
mutant("stock sans plafond", function() Em.EXTRA_MAX = 99 end, function() Em.EXTRA_MAX = E0 end)
mutant("emplacement par le stock trop bon marché", function() Em.PER_SLOT = 100 end, function() Em.PER_SLOT = P0 end)
mutant("la réserve peut être figée", function() Em.MATERIAL_STATES.reserve = nil Em.WORK_STATES.reserve = true end,
  function() Em.MATERIAL_STATES.reserve = true Em.WORK_STATES.reserve = nil end)
local wt0 = Em.work_tick
mutant("horloge de chantier ignorée (réserve comptée dans le figé)", function() Em.work_tick = function() return nil end end,
  function() Em.work_tick = wt0 end)
local extra0 = Em.extra
mutant("le produit le plus riche décide", function()
  Em.extra = function(pl)
    local hi = 0
    for _, v in ipairs(pl or {}) do if type(v) == "number" and v > hi then hi = v end end
    return math.min(Em.EXTRA_MAX, math.floor(hi / Em.PER_SLOT))
  end
end, function() Em.extra = extra0 end)
say(string.format("§5 mutants : %d OK, %d ECHEC(S) au total", passes, failures))

-- §6 branchement au moteur simulé
local M = require("tests.mock_engine")
local function W() return M.world() end
local function lines_of(tag)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(tag, 1, true) then out[#out + 1] = l end end
  return out
end
local function patches()
  local out = {}
  local d = 0.7071
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for ci, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do
    for k = 1, 8 do
      local a = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 }, { 0.7, 0.7 }, { -0.7, 0.7 }, { -0.7, -0.7 }, { 0.7, -0.7 } }
      out[#out + 1] = { x = c[1] * 320 + a[k][1] * 48, y = c[2] * 320 + a[k][2] * 48, name = names[(k + ci) % 4 + 1] }
    end
  end
  return out
end
M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
M.load_mod()
M.dispatch(W().on_init)
M.command("fo-war", "start 2 30 30 320")
local ok, err = pcall(M.run_ticks, 4 * MIN)
check(ok, "§6 4 min sans erreur (" .. tostring(err) .. ")")
local f = global.fo.war.factions[1]
local cs = f and f.team and f.team.capi
check(cs ~= nil, "§6 état de capitalisation de la faction 1")
local Capi = require("script.ai3.capitalisation")
local first = lines_of("[FO-CAPI-EMPLACEMENTS]")
check(#first >= 1, "§6 [FO-CAPI-EMPLACEMENTS] écrit à la première décision (" .. #first .. ")")
if first[1] then say("   " .. first[1]:sub(1, 400)) end
if cs then
  local st = f.team.ia3e
  local tick = game.tick
  local function inject(id, key, state, progress, work)
    st.mods[#st.mods + 1] = { id = id, product = "produit-test", state = state, missing = {}, built = 0, total = 4, capi = key }
    cs.open[#cs.open + 1] = { key = key, kind = "couvrir", exec = "module", mod_ids = { id }, product = "produit-test", n = 4,
      opened = progress, progress_tick = progress, missing = {}, work_tick = work }
    return cs.open[#cs.open]
  end
  local open0, mods0 = #cs.open, #st.mods
  -- relecture : un ordre d'une sauvegarde 0.6.21 (sans horloge de chantier) n'est pas libéré au chargement ; l'horloge est posée
  local old = inject(9100, "couvrir:ancien", "defrichage", tick - 20 * MIN, nil)
  local sl0 = Capi.slots(f, cs, {}, tick)
  check(old.work_tick == tick and sl0.free_stalled == 0, "§6 ordre sans horloge (sauvegarde 0.6.21) : horloge posée, pas libéré tout de suite")
  table.remove(cs.open) table.remove(st.mods)
  inject(9101, "couvrir:fige", "defrichage", tick - 20 * MIN, tick - 20 * MIN)
  inject(9102, "couvrir:reserve", "reserve", tick - 20 * MIN, nil)
  local n0 = #lines_of("[FO-CAPI-EMPLACEMENTS]")
  local sl = Capi.slots(f, cs, {}, tick)
  check(sl.open == open0 + 2 and sl.free_stalled >= 1, "§6 Capi.slots lit les ordres injectés (" .. sl.why .. ")")
  local stalled = table.concat(sl.keys_stalled, ",")
  check(stalled:find("couvrir:fige", 1, true) ~= nil and not stalled:find("couvrir:reserve", 1, true),
    "§6 le défrichage figé est libéré, la réserve tient son emplacement")
  local stock = {}
  for _, m in ipairs(require("shared.ai3.automatiser").METHODS) do if m.ore then stock[m.product] = 5000 end end
  local sl2 = Capi.slots(f, cs, stock, tick)
  check(sl2.extra == Em.EXTRA_MAX and sl2.cap == sl.cap + Em.EXTRA_MAX, "§6 le stock des produits des fonderies (données de l'exécutant) ouvre les emplacements de plus")
  Capi.slots(f, cs, stock, tick)
  local n1 = #lines_of("[FO-CAPI-EMPLACEMENTS]")
  check(n1 == n0 + 2, "§6 une ligne par changement, aucune à situation égale (" .. (n1 - n0) .. " ligne(s) pour 3 appels)")
  -- retire l'injection (l'état reste celui de la partie)
  while #cs.open > open0 do table.remove(cs.open) end
  while #st.mods > mods0 do table.remove(st.mods) end
  ok, err = pcall(M.run_ticks, 2 * MIN)
  check(ok, "§6 la partie continue sans erreur après le retrait (" .. tostring(err) .. ")")
end

print(string.format("[CAPI-DEBIT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
