--[[
  s42 thermiques (chantier 2.5 du DC, partie de 4 h 15 en 0.7.96 : aucune foreuse thermique ne doit subsister en milieu de partie).
  Usage : lua5.2 tests/s42_thermiques_test.lua

  Le verrou s41 (o.th_swept, Th.pairs_closed) fermait l'agrandissement du MÊME avant-poste. Voies de repose fermées ici, sur un avant-poste
  ou un gisement balayé, tant que l'électrique est posable :
    A. avant-poste thermique NEUF sur le même gisement (Outposts.build ; refusé aussi au tableau, Elec.filter) ;
    B. repli thermique d'une électrique sans courant (Swap.repli) : l'électrique rendue thermique était balayée à la pensée suivante ;
    C. thermique de secours de la reconstruction (substitute_drills).
  Et la condition de déclenchement du remplacement sur place, en règle pure (Th.replace_one).

  Preuves :
    1. règles pures (Th.electric_posable, Th.site_closed, Th.replace_one, Th.sorted_ids) ;
    2. vrai script/faction/outposts.lua, moteur factice : Outposts.build sur un gisement balayé rend nil sans toucher la surface ni le porteur ;
    3. séquence balayage -> effondrement -> repose rejouée 50 fois avec les VRAIES règles (E.peak_less, E.collapsed, E.thermal, E.filter,
       Outposts.extend, Outposts.build) : une seule vague de retraits, aucune repose, même quand la règle électrique repermet la thermique ;
    4. câblage (texte) ;
    5. mutants.
]]
package.path = "./?.lua;" .. package.path
defines = { direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = { chest = 1 } }
function log() end

local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end
local function read(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end

-- 1. règles pures
local TH_SRC = read("shared/team/thermique.lua")
local Th = require("shared.team.thermique")
local E = require("shared.team.electrique")

check(Th.electric_posable(nil) == true, "posable : sans verdict -> oui (un gisement balayé avait une bande qui produisait)")
check(Th.electric_posable({ obtainable = true, plants = 1, poles = true }) == true, "posable : centrale finie, objets obtenables -> oui")
check(Th.electric_posable({ obtainable = false, plants = 1, poles = true }) == false, "posable : foreuse électrique pas obtenable -> non")
check(Th.electric_posable({ obtainable = true, plants = 0, poles = true }) == false, "posable : aucune centrale finie -> non")
check(Th.electric_posable({ obtainable = true, plants = 2, poles = false }) == false, "posable : aucun poteau obtenable -> non")

local swept = { id = 2, kind = "iron", pos = { x = 100, y = 100 }, th_swept = 600 }
local plain = { id = 3, kind = "iron", pos = { x = 100, y = 100 } }
local other = { id = 4, kind = "copper", pos = { x = 100, y = 100 }, th_swept = 600 }
do
  local c, by = Th.site_closed("iron", { x = 130, y = 100 }, { plain, swept }, nil)
  check(c == true and by == 2, "site : avant-poste balayé du même minerai à 30 tuiles -> fermé, numéro rendu")
end
check(Th.site_closed("iron", { x = 164, y = 100 }, { swept }, nil) == true, "site : à 64 tuiles pile -> fermé (borne incluse, comme Champ.SIB_R)")
check(Th.site_closed("iron", { x = 165, y = 100 }, { swept }, nil) == false, "site : à 65 tuiles -> autre gisement, ouvert")
check(Th.site_closed("iron", { x = 130, y = 100 }, { plain }, nil) == false, "site : voisin jamais balayé -> ouvert")
check(Th.site_closed("iron", { x = 130, y = 100 }, { other }, nil) == false, "site : voisin balayé d'un AUTRE minerai -> ouvert")
check(Th.site_closed("iron", { x = 130, y = 100 }, { swept }, { obtainable = true, plants = 0, poles = true }) == false,
  "site : électrique non posable (aucune centrale) -> ouvert (secours thermique légitime)")
check(Th.site_closed("iron", { x = 130, y = 100 }, { swept }, { obtainable = true, plants = 1, poles = true }) == true, "site : électrique posable -> fermé")
check(Th.site_closed("iron", nil, { swept }, nil) == false and Th.site_closed("iron", { x = 1, y = 1 }, nil, nil) == false, "site : entrées absentes -> ouvert, sans erreur")
do
  local ids = Th.sorted_ids({ [7] = 1, [2] = 1, [100001] = 1, [5] = 1 })
  check(#ids == 4 and ids[1] == 2 and ids[2] == 5 and ids[3] == 7 and ids[4] == 100001, "sorted_ids : numéros triés")
end

local function rep(c) local go, mode, why, n = Th.replace_one(c); return go, mode, why, n end
local base = { powered = true, electric = 4, starved = 0, stock = 1, el_rate = 0.5, th_rate = 0.25, removed = 1 }
local function with(t) local c = {} for k, v in pairs(base) do c[k] = v end for k, v in pairs(t) do c[k] = v end return c end
do
  local go, mode, why, n = rep(base)
  check(go == true and mode == "retirer-puis-poser" and why == "ok" and n == 1, "déclenchement : réseau alimenté, stock, débit -> une électrique, retirer puis poser")
  go, mode = rep(with({ pose_first = true }))
  check(go == true and mode == "poser-d-abord", "déclenchement : même tuile de sortie possible -> poser d'abord")
  go, mode, why, n = rep(with({ powered = false }))
  check(go == false and why == "reseau sans production" and n == 0, "déclenchement : réseau sans production -> non")
  go, _, why = rep(with({ starved = 1 }))
  check(go == false and why == "site sous-alimente", "déclenchement : une électrique du site en manque de courant -> non")
  go = rep(with({ electric = 0, starved = 0 }))
  check(go == true, "déclenchement : première électrique du site (aucun consommateur) -> le réseau qui produit suffit")
  go, _, why = rep(with({ stock = 0 }))
  check(go == false and why == "pas d'electrique au stock", "déclenchement : pas d'objet électrique -> non (jamais de retrait à vide)")
  go = rep(with({ removed = 2 }))
  check(go == true, "déclenchement : échange 1 électrique pour 2 thermiques, débit égal -> oui")
  go, _, why = rep(with({ removed = 3 }))
  check(go == false and why == "debit en baisse", "déclenchement : échange 1 pour 3, débit posé < débit retiré -> non")
  go = rep(with({ el_rate = false, th_rate = false, removed = 3 }))
  check(go == true, "déclenchement : cadences non lues -> comparaison sautée, stock exigé")
  go = rep(nil)
  check(go == false, "déclenchement : sans entrée -> non, sans erreur")
end

-- 2. vrai Outposts.build / Outposts.extend
package.loaded["script.faction.state"] = { own = function() end, sorted_keys = function(t) local k = {} for a in pairs(t) do k[#k + 1] = a end table.sort(k) return k end }
package.loaded["script.faction.sites"] = {}
local PQ = dofile("script/ai3/places_qg.lua")
package.loaded["script.ai3.places_qg"] = { on_resource = function() return false end, is_reserved = PQ.is_reserved }
package.loaded["script.team.famine_fer"] = { open = function() return true end, key_starved = function() return true end }
local OUT_SRC = read("script/faction/outposts.lua")
local function load_outposts(src)
  package.loaded["script.faction.outposts"] = nil
  return assert(load(src, "outposts", "t", _G))()
end
local touched
local function trap(label)
  return setmetatable({}, { __index = function(_, k) touched = touched + 1; error("moteur touché : " .. label .. "." .. tostring(k)) end })
end
local function force_of(outposts, v)
  local f = { key = "ambre", force = "f1", id = 1, outposts = {}, stats = {}, turrets = {}, next_oid = 10, outposts_count = 0, elec = v and { v = v } or nil }
  for _, o in ipairs(outposts) do f.outposts[o.id] = o end
  return f
end
-- rend vrai quand la pose est REFUSÉE proprement (nil, rien de touché)
local function build_refused(O, outposts, site, v)
  touched = 0
  local ok, o = pcall(O.build, force_of(outposts, v), trap("surface"), "iron", site, trap("porteur"))
  return ok and o == nil and touched == 0
end
local function extend_refused(O, o)
  touched = 0
  local ok, n = pcall(O.extend, force_of({ o }), trap("surface"), o, trap("porteur"))
  return ok and n == 0 and touched == 0
end
local function sw(id, x, y) return { id = id, kind = "iron", pos = { x = x, y = y }, drills = 0, migr = "en cours", th_swept = 600, drill_list = {}, sinks = {} } end
local O = load_outposts(OUT_SRC)
local POSABLE = { on = true, obtainable = true, plants = 1, poles = true }
check(build_refused(O, { sw(2, 100, 100) }, { x = 120, y = 110 }, POSABLE), "build : site sur un gisement balayé -> nil, ni surface ni porteur touchés")
check(build_refused(O, { sw(2, 100, 100) }, { x = 120, y = 110 }, nil), "build : sans verdict de la règle électrique -> fermé aussi")
check(not build_refused(O, { sw(2, 100, 100) }, { x = 300, y = 110 }, POSABLE), "build, témoin : site d'un autre gisement -> la garde ne s'applique pas")
check(not build_refused(O, { { id = 2, kind = "iron", pos = { x = 100, y = 100 }, drills = 4, drill_list = {}, sinks = {} } }, { x = 120, y = 110 }, POSABLE),
  "build, témoin : voisin jamais balayé -> la garde ne s'applique pas")
check(not build_refused(O, { sw(2, 100, 100) }, { x = 120, y = 110 }, { on = true, obtainable = true, plants = 0, poles = true }),
  "build, témoin : centrale perdue (électrique non posable) -> le secours thermique reste permis")

-- 3. séquence balayage -> effondrement -> repose, vraies règles
-- État d'un gisement de fer : `pairs_up` paires thermiques, `el` électriques en marche (bande qui produit). À chaque tour :
--   a. balayage (gisement couvert) : les paires debout sont rendues au stock, l'avant-poste est marqué (o.th_swept), le cumul retiré monte ;
--   b. règle d'effondrement : pic corrigé du retrait volontaire (E.peak_less), puis E.collapsed / E.thermal (ce que lit Elec.think) ;
--   c. toutes les voies de repose sont demandées, QUEL QUE SOIT le verdict de (b) (pire cas : thermique permise) : agrandissement du même
--      avant-poste, avant-poste neuf sur le gisement (tableau : E.filter avec le refus de Th.site_closed ; puis Outposts.build).
local function sequence(O2, rounds, opts)
  opts = opts or {}
  local o = { id = 2, kind = "iron", pos = { x = 100, y = 100 }, drills = 16, migr = "en cours", drill_list = {}, sinks = {} }
  local pairs_up, el, waves, retired, reposed, collapses = 20, 16, 0, 0, 0, 0
  local peak, seen, was = pairs_up + el, 0, false
  for r = 1, rounds do
    if pairs_up > 0 then
      retired, waves, pairs_up = retired + pairs_up, waves + 1, 0
      o.th_swept = o.th_swept or r * 600
    end
    local active = pairs_up + el
    if not opts.no_peak_less then peak, seen = E.peak_less(peak, retired, seen) end
    local allowed, down = E.collapsed({ active = active, peak = peak, stalled = 10 ^ 9, was = was })
    was = down
    if allowed then collapses = collapses + 1 end
    -- (c) pire cas : la thermique est permise par la règle électrique (ressource lue sans électrique en marche)
    local v = { on = true, obtainable = true, plants = 1, poles = true, el_live = el, poles_stock = 50, since = 0 }
    local th_ok = (E.thermal({ on = true, obtainable = true, plants = 1, poles = true, el_live = el, poles_stock = 50, since = 0, res_live = 0 }))
    assert(th_ok == true, "le pire cas doit permettre la thermique")
    if not extend_refused(O2, o) then pairs_up, reposed = pairs_up + 4, reposed + 4 end
    local task = { kind = "build", key = "build:iron", outpost_kind = "iron", site = { x = 110 + (r % 20), y = 95 }, items = { { "drill", 4 } } }
    local kept = E.filter({ task }, "drill", function(t)
      if not opts.no_filter and Th.site_closed(t.outpost_kind, t.site, { o }, v) then return false, "gisement balaye" end
      return true
    end)
    if #kept > 0 and not build_refused(O2, { o }, task.site, v) then pairs_up, reposed = pairs_up + 4, reposed + 4 end
  end
  return waves, retired, reposed, collapses
end
do
  local waves, retired, reposed, collapses = sequence(O, 50)
  check(waves == 1 and retired == 20 and reposed == 0,
    string.format("séquence : 50 tours, une seule vague de retraits, aucune repose (vagues %d, retirées %d, reposées %d)", waves, retired, reposed))
  check(collapses == 0, "séquence : le retrait volontaire n'est pas lu comme un effondrement (E.peak_less ; " .. collapses .. " effondrement(s))")
  -- même sans la correction du pic (effondrement LU à chaque tour) et sans le refus au tableau, la repose reste impossible (Outposts.build)
  local w2, _, rp2, c2 = sequence(O, 50, { no_peak_less = true, no_filter = true })
  check(c2 > 0 and w2 == 1 and rp2 == 0,
    string.format("séquence, pire cas : effondrement lu %d fois, tableau ouvert : toujours une vague, aucune repose (vagues %d, reposées %d)", c2, w2, rp2))
end

-- 4. câblage (texte)
local SWAP = read("script/team/foreuse_swap.lua")
local RECON = read("script/team/reconstruction.lua")
local ELEC = read("script/team/electrique.lua")
check(SWAP:find("if o.migr == nil and not Th.pairs_closed(o) then", 1, true) ~= nil, "câblage : le repli thermique saute un avant-poste balayé")
do
  local a = SWAP:find("local go, _, why = Th.replace_one(", 1, true)
  local b = SWAP:find("local done_swap = swap_one(", 1, true)
  local c = SWAP:find('count(st, "reserve charbon")', 1, true)
  check(a ~= nil and b ~= nil and c ~= nil and c < a and a < b, "câblage : la condition de déclenchement est lue après la réserve et AVANT le retrait (swap_one)")
  check(SWAP:find("stock = Stock.count(f, T.DRILL_ELECTRIC)", 1, true) ~= nil and SWAP:find("removed = 1 + ((r.exchange and r.exchange.drills)", 1, true) ~= nil,
    "câblage : stock relu au moteur, thermiques retirées = 1 + voisines de l'échange")
  check(SWAP:find("status == defines.entity_status.no_power or status == defines.entity_status.low_power", 1, true) ~= nil and SWAP:find("local site = (pass.site or {})[ref.o.id]", 1, true) ~= nil, "câblage : satisfaction du site lue au statut des électriques (sans courant, sous-alimentée)")
end
check(RECON:find("if spec and Th.pairs_closed(host) then spec = nil end", 1, true) ~= nil, "câblage : pas de thermique de secours de la reconstruction sur un avant-poste balayé")
check(ELEC:find("local closed, by = Th.site_closed(t.outpost_kind, t.site, swept, v)", 1, true) ~= nil, "câblage : le tableau refuse l'avant-poste neuf d'un gisement balayé")
check(OUT_SRC:find("if Th.site_closed(kind, site, list, f.elec and f.elec.v) then return nil end", 1, true) ~= nil
  and OUT_SRC:find("if Th.site_closed", 1, true) < OUT_SRC:find("Outposts.reclaim(f, site, carrier, 24)", 1, true),
  "câblage : la garde de Outposts.build précède la reprise des réceptacles et la pose")
check(tonumber(read("script/team/champ.lua"):match("Champ%.SIB_R = (%d+)")) == Th.CFG.sib_r, "câblage : rayon du gisement = Champ.SIB_R")
-- aucun nom d'objet dans les règles ajoutées
do
  local a = TH_SRC:find("function M.electric_posable", 1, true)
  local b = TH_SRC:find("--- Le gisement est-il couvert", 1, true)
  local part = TH_SRC:sub(a, b)
  check(not part:find("mining%-drill") and not part:find("burner") and not part:find("game%."), "pur : ni nom d'objet ni API dans les règles s42")
end

-- 5. mutants
local function mutate(src, old, new)
  local a, b = src:find(old, 1, true)
  assert(a, "mutant : texte introuvable : " .. old)
  return src:sub(1, a - 1) .. new .. src:sub(b + 1)
end
local survivors, total = 0, 0
local function mutant(name, alive)
  total = total + 1
  if alive then survivors = survivors + 1; print("  MUTANT VIVANT : " .. name) end
end
do
  local M1 = load_outposts(mutate(OUT_SRC, "if Th.site_closed(kind, site, list, f.elec and f.elec.v) then return nil end", ""))
  mutant("garde de build retirée", build_refused(M1, { sw(2, 100, 100) }, { x = 120, y = 110 }, POSABLE))
  local w, _, rp = sequence(M1, 50, { no_filter = true })
  mutant("séquence sans garde de build", w == 1 and rp == 0)
  local function th_mut(old, new) return assert(load(mutate(TH_SRC, old, new), "th", "t", _G))() end
  local T1 = th_mut("if not M.electric_posable(elec) then return false end", "")
  mutant("site fermé même sans centrale", T1.site_closed("iron", { x = 130, y = 100 }, { swept }, { plants = 0 }) == false)
  local T2 = th_mut("if M.pairs_closed(q) and q.kind == kind and", "if q.kind == kind and")
  mutant("site fermé par un voisin jamais balayé", T2.site_closed("iron", { x = 130, y = 100 }, { plain }, nil) == false)
  local T3 = th_mut("<= r2 then", "< 0 then")
  mutant("rayon du gisement", T3.site_closed("iron", { x = 130, y = 100 }, { swept }, nil) == true)
  local T4 = th_mut('if (tonumber(c.stock) or 0) < 1 then return false, nil, "pas d\'electrique au stock", 0 end', "")
  mutant("retrait sans objet électrique au stock", (T4.replace_one(with({ stock = 0 }))) == false)
  local T5 = th_mut("if er and tr and er + EPS < removed * tr then", "if er and tr and er + EPS < tr then")
  mutant("débit retiré de l'échange ignoré", (T5.replace_one(with({ removed = 3 }))) == false)
  local T6 = th_mut('if sat + EPS < cfg.site_satisfaction then return false, nil, "site sous-alimente", 0 end', "")
  mutant("satisfaction du site ignorée", (T6.replace_one(with({ starved = 2 }))) == false)
  local T7 = th_mut('if c.powered ~= true then return false, nil, "reseau sans production", 0 end', "")
  mutant("réseau sans production accepté", (T7.replace_one(with({ powered = false }))) == false)
end
check(survivors == 0, string.format("mutants : %d refusés sur %d (%d vivant(s))", total - survivors, total, survivors))
package.loaded["script.faction.outposts"] = O

print(string.format("[S42-THERMIQUES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
