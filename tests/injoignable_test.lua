--[[
  Lot INJOIGNABLE : banc HORS JEU du défaut de la partie du DC (0.7.113, équipe azure) : son seul gisement de fer proche (310, 374) perdu
  30 min. Lancement : lua5.2 tests/injoignable_test.lua (depuis la racine du mod).
    1. shared/team/echec_pose.lua : une pose ratée sur place n'est jamais « injoignable » (écart court ; aucun écart sans objets) ;
    2. câblage de script/team/worker.lua (ACTS.build) : plus de marquage 30 min, écart par Ep.verdict, journal [FO-SITES] ;
    3. shared/ai3/projets.lua (P.update, `hold`) : « extraction:<x> » pas fini tant qu'aucun avant-poste n'existe et qu'une pose est en cours ;
       câblage de shared/ai3/cerveau.lua ; C.think de bout en bout ;
    4. shared/ai3/zero_idle.lua : « sans_avant_poste » au lieu de « plein » sans aucun avant-poste du type ;
    5. mutants.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Ep = require("shared.team.echec_pose")
local P = require("shared.ai3.projets")
local ZI = require("shared.ai3.zero_idle")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function read(p)
  local fh = assert(io.open(p, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

section("1. Verdict d'une pose ratée")
do
  local m, ttl = Ep.verdict({ closed = false, drills = 3, sinks = 3 })
  check(m == "pose" and ttl == 7200, "objets portés, rien posé -> « pose », écart 2 min (rendu " .. tostring(m) .. ", " .. tostring(ttl) .. ")")
  check(ttl < 108000, "écart d'une pose ratée < 30 min d'un vrai injoignable")
  m, ttl = Ep.verdict({ drills = 0, sinks = 3 })
  check(m == "lacking" and ttl == nil, "sans foreuse -> « lacking », site non écarté")
  m, ttl = Ep.verdict({ drills = 3, sinks = 0 })
  check(m == "lacking" and ttl == nil, "sans réceptacle -> « lacking », site non écarté")
  m, ttl = Ep.verdict({ closed = true, drills = 3, sinks = 3 })
  check(m == "thermique_ferme" and ttl == 7200, "gisement balayé fermé aux thermiques -> écart court")
  local line = Ep.line("azure", 29400, "iron-ore", { x = 310.5, y = 374.5 }, "pose", 7200, { drills = 3, sinks = 3 })
  check(line:find("[FO-SITES] pose ratee tick 29400 azure iron-ore : (310, 374), motif pose", 1, true) ~= nil, "ligne [FO-SITES] : " .. line)
  check(line:find("pas injoignable", 1, true) ~= nil, "la ligne dit que le site n'est pas injoignable")
  check(Ep.line("a", 1, "x", { x = 0, y = 0 }, "lacking", nil, {}):find("site non ecarte", 1, true) ~= nil, "lacking : « site non ecarte »")
end

section("2. Câblage de ACTS.build (script/team/worker.lua)")
do
  local w = read("script/team/worker.lua")
  local a = w:find("ACTS.build = function", 1, true)
  local b = w:find("ACTS.extend = function", 1, true)
  check(a and b and a < b, "ACTS.build trouvé")
  local body = (a and b) and w:sub(a, b) or ""
  local fail = body:match("if not o then(.-)return false") or ""
  check(fail:find("Ep.verdict(", 1, true) ~= nil, "le motif vient de Ep.verdict")
  check(fail:find("Sites.mark_unreachable(task.site, tick)", 1, true) == nil, "plus de marquage 30 min sans délai")
  check(fail:find("if ttl then Sites.mark_unreachable(task.site, tick, ttl) end", 1, true) ~= nil, "écart seulement avec un délai (aucun pour « lacking »)")
  check(fail:find("Sites.release(task.site)", 1, true) ~= nil, "le site est rendu à la réserve")
  check(fail:find("log(Ep.line(", 1, true) ~= nil, "rapport de pose au journal")
  check(fail:find("Th.site_closed(", 1, true) ~= nil and fail:find("get_item_count(T.DRILL)", 1, true) ~= nil, "motif déduit : site fermé, puis objets portés")
end

section("3. Projet d'extraction : pas fini sans avant-poste")
do
  local st = {}
  local g = { key = "extraction:iron", family = "extraction", kind = "outpost", outpost = "iron", value = 80, want = 1 }
  P.update(st, { g }, 100, 15)
  check(#st.projects == 1 and st.projects[1].state == "actif", "projet ouvert")
  local function fini_logged(s)
    for _, e in ipairs(s.log or {}) do if e.kind == "fini" and e.key == "extraction:iron" then return true end end
    return false
  end
  -- la tâche « build » est prise : le but disparaît (capacité en chantier) ; aucun avant-poste
  P.update(st, {}, 200, 15, { ["extraction:iron"] = true })
  check(#st.projects == 1 and st.projects[1].state == "attente" and st.projects[1].cause == "chantier", "hold : projet gardé en attente (chantier)")
  check(not fini_logged(st), "hold : pas d'annonce « fini »")
  local n = #st.log
  P.update(st, {}, 300, 15, { ["extraction:iron"] = true })
  check(#st.log == n, "hold répété : une seule annonce « attente »")
  -- la pose échoue : le but revient, le MÊME projet repart
  local id = st.projects[1].id
  local order = P.update(st, { g }, 400, 15, {})
  check(st.projects[1].id == id and st.projects[1].state == "actif" and #order == 1, "but revenu : même projet, actif, déplié")
  check(not fini_logged(st), "toujours aucune annonce « fini »")
  -- avant-poste bâti : plus de hold, le but disparaît -> fini
  P.update(st, {}, 500, 15, {})
  check(#st.projects == 0 and fini_logged(st), "avant-poste bâti (sans hold) : projet fini")
  -- compatibilité : sans 5e argument, l'ancien comportement
  local st2 = {}
  P.update(st2, { g }, 1, 4)
  P.update(st2, {}, 2, 4)
  check(#st2.projects == 0 and fini_logged(st2), "sans hold : fini comme avant")

  local c = read("shared/ai3/cerveau.lua")
  check(c:find("P.update(st, goals, tick, s.workers, hold)", 1, true) ~= nil, "cerveau : P.update reçoit hold")
  check(c:find('if (s.cap[kind] or 0) <= 0 and (s.pending[kind] or 0) > 0 then hold["extraction:" .. kind] = true end', 1, true) ~= nil,
    "cerveau : hold = aucune capacité ET une pose en cours")
end

section("4. Zero-idle : « sans_avant_poste »")
do
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local RICH = { [T.outposts.iron.product] = 900, [T.outposts.copper.product] = 900, [T.outposts.stone.product] = 1500, [T.fuel] = 600 }
  local function v(outposts)
    return { stock = RICH, outposts = outposts, open = {}, workers_idle = 6, workers_fond = 0, defend_first = true, hq_turrets = T.defend_hq }
  end
  local s = { key = { order = { "iron", "copper" } } }
  local cu = { id = 1, kind = "copper", drills = 3, full = false, turrets = 4, d2 = 100 }
  local r = ZI.decide(ZI.input(v({ cu }), s, book, RICH, nil))
  check(r.causes.iron == "sans_avant_poste", "aucun avant-poste de fer -> « sans_avant_poste » (rendu " .. tostring(r.causes.iron) .. ")")
  check(r.causes.copper ~= "sans_avant_poste", "le cuivre (un avant-poste) n'est pas « sans_avant_poste »")
  local fe = { id = 2, kind = "iron", drills = 3, full = true, turrets = 4, d2 = 200 }
  r = ZI.decide(ZI.input(v({ cu, fe }), s, book, RICH, nil))
  check(r.causes.iron == "plein", "un avant-poste de fer plein -> « plein » (rendu " .. tostring(r.causes.iron) .. ")")
  -- kinds construits à la main sans n_any (anciens appelants) : « plein » comme avant
  local k = { { kind = "iron", product = T.outposts.iron.product, outposts = {}, open = {}, no_go = {}, tiers = {} } }
  r = ZI.decide({ idle = 2, book = book, avail = RICH, kinds = k })
  check(r.causes.iron == "plein", "sans n_any : « plein » (compatibilité)")
  -- aucun ordre pour le fer : les PNJ restent libres (left) pour la tâche « build »
  r = ZI.decide(ZI.input(v({}), s, book, RICH, nil))
  check(#r.orders == 0 and r.left == 6, "aucun avant-poste du tout : rien émis, 6 PNJ restent libres")
end

section("5. Mutants")
do
  local saved = Ep.verdict
  local refused = 0
  Ep.verdict = function() return "pose", 108000 end -- ancien comportement : 30 min quel que soit le motif
  local m, ttl = Ep.verdict({ drills = 0, sinks = 0 })
  if not (m == "lacking" and ttl == nil) then refused = refused + 1 end
  Ep.verdict = saved
  local st = {}
  P.update(st, { { key = "extraction:iron", value = 1 } }, 1, 4)
  P.update(st, {}, 2, 4, nil) -- mutant : hold oublié par l'appelant
  if #st.projects == 0 then refused = refused + 1 end
  check(refused == 2, "mutants refusés : " .. refused .. " sur 2")
end

print(string.format("[INJOIGNABLE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
