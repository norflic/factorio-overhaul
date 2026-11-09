--[[
  Lot AZURE : règle pure du RETOUR EN ARRIÈRE d'une migration de champ (shared/team/migration_retour.lua). L'exécutant (retire garde les
  paires, step_build décide, rollback repose) est contrôlé sous moteur simulé dans tests/migration_champ_test.lua, section 10.
  Lancement : lua5.2 tests/migration_retour_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local okc, fail = 0, 0
local function check(c, msg) if c then okc = okc + 1 else fail = fail + 1; print("ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "r")); local s = h:read("*a"); h:close(); return s end
local MIN = 3600

local function run(R)
  local r = {}
  local C = R.CFG
  -- 1. les valeurs de la decision du DC
  r.c1 = C.stall == 15 * MIN and C.cool == 30 * MIN and C.max_rollbacks == 1 and C.undo_max == 40
  -- 2. pack : trie, borne, ne garde que des nombres et des chaines, compte l'ecart
  local es = {}
  for i = 1, 45 do es[#es + 1] = { name = "d", x = 100 - i, y = 5, dir = 2, oid = 1, sink = { name = "f", x = 100 - i, y = 7 } } end
  es[#es + 1] = { name = "d", x = 3, y = 1, oid = 2 }
  local packed, dropped = R.pack(es)
  r.c2 = #packed == 40 and dropped == 6 and packed[1].x == 3 and packed[1].dir == 0 and packed[1].sink == nil and packed[2].x == 55 and packed[2].sink.y == 7
    and packed[40].x == 93
  -- 3. pack : l'ordre des entrees est sans effet
  local rev = {}
  for i = #es, 1, -1 do rev[#rev + 1] = es[i] end
  local p2 = R.pack(rev)
  local same = #p2 == #packed
  for i = 1, #packed do if p2[i].x ~= packed[i].x or p2[i].y ~= packed[i].y then same = false end end
  r.c3 = same
  -- 4. pack : copie (la table d'entree n'est jamais gardee)
  local e1 = { name = "d", x = 1, y = 1, oid = 1, sink = { name = "f", x = 2, y = 2 } }
  local pk = R.pack({ e1 })
  r.c4 = pk[1] ~= e1 and pk[1].sink ~= e1.sink
  -- 5. progres : une entite de plus remet le compte a zero, sinon il court
  local rec = R.progress(nil, 10, 100)
  local rec2 = R.progress(rec, 10, 100 + 5 * MIN)
  local rec3 = R.progress(rec2, 11, 100 + 8 * MIN)
  r.c5 = rec.built == 10 and rec.since == 100 and rec2.since == 100 and R.stalled(rec2, 100 + 5 * MIN) == 5 * MIN and rec3.since == 100 + 8 * MIN
    and R.stalled(rec3, 100 + 8 * MIN) == 0 and R.stalled(nil, 5) == 0
  -- 6. progres : un projet qui perd des entites (detruites) n'est pas un progres
  r.c6 = R.progress({ built = 10, since = 7 }, 8, 900).since == 7
  -- 7. decision : cas du DC
  local function d(c) return (R.decide(c)) end
  r.c7 = d({ undo = 8, stalled = 15 * MIN, state = "chantier" }) == "retour"                       -- chantier lent : retour
    and d({ undo = 8, stalled = 15 * MIN - 1, state = "chantier" }) == "rien"                      -- 15 min moins un tick : on attend
    and d({ undo = 8, stalled = 0, state = "chantier" }) == "rien"                                 -- le chantier avance : paires non reposees
    and d({ undo = 8, stalled = 0, state = "chantier", abandon = true }) == "retour"               -- abandon : retour
    and d({ undo = 8, stalled = 99 * MIN, state = "chantier", produced = true }) == "rien"         -- une ligne a produit : jamais
    and d({ undo = 0, stalled = 99 * MIN, state = "chantier" }) == "rien"                          -- rien a reposer
    and d({ undo = 8, stalled = 99 * MIN, state = "fini" }) == "rien"                              -- ligne finie : son propre delai
    and d({ undo = 8, stalled = 99 * MIN, state = "fini", abandon = true }) == "retour"            -- ... sauf abandon
    and d({ undo = 8, stalled = 99 * MIN, state = nil }) == "retour"                               -- projet perdu et sans progres
    and d({ undo = 8, stalled = 20 * MIN, state = "bloque" }) == "retour"
  -- 8. raisons
  local _, w1 = R.decide({ undo = 8, stalled = 20 * MIN, state = "chantier" })
  local _, w2 = R.decide({ undo = 8, abandon = true })
  local _, w3 = R.decide({ undo = 8, stalled = 1, state = "chantier" })
  local _, w4 = R.decide({ undo = 0 })
  local _, w5 = R.decide({ undo = 3, produced = true })
  r.c8 = w1 == "chantier-lent" and w2 == "abandon" and w3 == "avance" and w4 == "sans-paire" and w5 == "produit"
  -- 9. suite : premier retour -> reserve, deuxieme -> annuler, final -> annuler
  r.c9 = R.after(1) == "parquer" and R.after(2) == "parquer" and R.after(1, true) == "parquer" and R.after(5) == "parquer"
    and R.after(1, false, { max_rollbacks = 2 }) == "reserve" and R.after(2, false, { max_rollbacks = 2 }) == "parquer"
  -- 10. pause
  r.c10 = R.cooling(1000, 999) == true and R.cooling(1000, 1000) == false and R.cooling(nil, 5) == false
  -- 11. ligne
  local l = R.line({ team = "azure", outpost = 4, pid = 7, why = "chantier-lent", minute = 75.5, undo = 21, placed = 13, busy = 6, items = 2, n = 1, next = "reserve" })
  local l2 = R.line({ team = "azure", outpost = 4, pid = 7, why = "abandon", minute = 140, undo = 21, placed = 0, busy = 21, items = 0, n = 2, next = "parquer", lost = 3 })
  r.c11 = l == "[FO-ROLLBACK] azure : avant-poste 4, projet 7 a 75.5 min (chantier-lent) : 21 paire(s) gardee(s), 13 reposee(s), 6 tuile(s) prise(s), 2 sans objet ; retour 1, bande remise en reserve"
    and l2:find("retour 2, bande en reserve, plus de nouvel essai ; 3 paire(s) au-dela de la borne, non gardee(s)", 1, true) ~= nil
  -- 12. plan d'obtention : stock d'abord, puis recettes dépliées (3 niveaux), atomicité de `used`
  local stock = { gear = 2, plate = 30, stone = 5 }
  local have = function(n) return stock[n] or 0 end
  local recipes = {
    drill = { out = 1, ingredients = { { name = "gear", amount = 3 }, { name = "plate", amount = 3 }, { name = "furnace", amount = 1 } } },
    gear = { out = 1, ingredients = { { name = "plate", amount = 2 } } },
    furnace = { out = 1, ingredients = { { name = "stone", amount = 5 } } },
    pair = { out = 2, ingredients = { { name = "plate", amount = 1 } } }, zero = { out = 0, ingredients = {} },
    two = { out = 1, ingredients = { { name = "gear", amount = 2 }, { name = "gear", amount = 2 } } },
    deep = { out = 1, ingredients = { { name = "deep2", amount = 1 } } }, deep2 = { out = 1, ingredients = { { name = "deep3", amount = 1 } } },
    deep3 = { out = 1, ingredients = { { name = "deep4", amount = 1 } } }, deep4 = { out = 1, ingredients = { { name = "plate", amount = 1 } } },
  }
  local rec = function(n) return recipes[n] end
  local ok1, u1 = R.plan("gear", 1, have, rec)
  local ok2, u2 = R.plan("gear", 3, have, rec)
  local ok3, u3 = R.plan("drill", 1, have, rec)
  local ok4 = R.plan("drill", 1, function(n) return n == "stone" and 3 or have(n) end, rec)  -- pas assez de pierre : four impossible
  local ok5, u5 = R.plan("pair", 3, have, rec)                                                  -- 3 voulus, 2 par fabrication : 2 fabrications
  local ok6 = R.plan("deep", 1, have, rec)                                                      -- 4 niveaux : refuse
  local ok7 = R.plan("rock", 1, have, rec)                                                      -- ni stock ni recette
  -- 13. attente bornée (R1) et ligne de la bande parquée
  r.c13 = R.wait_over(2 * 90 * 3600, 90 * 3600) == false and R.wait_over(2 * 90 * 3600 + 1, 90 * 3600) == true and R.wait_over(0, 90 * 3600) == false
    and R.wait_over(nil, nil) == false
    and R.park_line({ team = "azure", outpost = 3, pid = 6, why = "chantier-lent", minute = 140.5, built = 246, total = 575 })
      == "[FO-ROLLBACK] azure : avant-poste 3, projet 6 a 140.5 min (chantier-lent) : bande parquee en reserve, plus de nouvel essai ; 246 entite(s) baties sur 575 restent en place, matieres rendues, creneau libere"
  r.c12 = ok1 and u1.gear == 1 and u1.plate == nil
    and ok2 and u2.gear == 2 and u2.plate == 2 and ok3 and u3.gear == 2 and u3.plate == 3 + 2 and u3.stone == 5
    and not ok4 and ok5 and u5.plate == 2 and not ok6 and not ok7 and not R.plan("zero", 1, have, rec)
    and (select(2, R.plan("two", 1, have, rec)).gear == 2) and (select(2, R.plan("two", 1, have, rec)).plate == 4)
  -- 14. retrait permis : matieres reunies ET premier retrait de la bande (directive du 9/11)
  local m1, w1 = R.may_retire({ missing = 0, rollbacks = 0 })
  local m2, w2 = R.may_retire({ missing = 3, rollbacks = 0 })
  local m3, w3 = R.may_retire({ missing = 0, rollbacks = 1 })
  local m4, w4 = R.may_retire({ missing = 1, rollbacks = 1 })
  local m5 = R.may_retire({})
  local m6 = R.may_retire({ missing = 0, rollbacks = 1 }, { max_rollbacks = 2 })
  local m7 = R.may_retire({ missing = 0, rollbacks = 2 }, { max_rollbacks = 2 })
  r.c14 = m1 == true and w1 == "ok" and m2 == false and w2 == "matieres" and m3 == false and w3 == "deja-retiree" and m4 == false and w4 == "matieres"
    and m5 == true and m6 == true and m7 == false
  return r
end

local R = require("shared.team.migration_retour")
local res = run(R)
for i = 1, 14 do check(res["c" .. i], "cas " .. i) end

-- branchement (lecture des sources)
local S = read("script/team/migration_champ.lua")
check(S:find('local Rb = require("shared.team.migration_retour")', 1, true) ~= nil, "exécutant : règle chargée au chargement du module")
check(S:find("st.undo, st.pg, st.cool, st.undo_lost = packed, nil, nil, lost", 1, true) ~= nil, "retrait : les paires sont gardées")
check(S:find("Rb.decide({ undo = #st.undo, produced = false", 1, true) ~= nil and S:find("local res = rollback(f, surface, ms, o, st, p, tick, rwhy, ab)", 1, true) ~= nil,
  "suivi du chantier : décision puis retour en arrière")
check(S:find("if Rb.cooling(st.cool, tick) then", 1, true) ~= nil, "pause après un retour avant tout nouveau retrait")
check(S:find("for _, k in ipairs(st.stopped or {}) do bad[k] = true end", 1, true) ~= nil, "begin_band écarte les bandes parquées (réserve définitive ; hors cadre la migration de l'avant-poste s'arrête)")
check(S:find("log(Rb.line(", 1, true) ~= nil, "journal [FO-ROLLBACK]")

-- mutants
local src = read("shared/team/migration_retour.lua")
local muts = {
  { "stall 15 min", "stall = 15 * 3600", "stall = 25 * 3600" },
  { "stall inclusif", "if (c.stalled or 0) >= cfg.stall then", "if (c.stalled or 0) > cfg.stall then" },
  { "ligne produite ignoree", "if c.produced then return \"rien\", \"produit\" end", "" },
  { "abandon ignore", "if c.abandon then return \"retour\", \"abandon\" end", "" },
  { "pas de paire", "if (c.undo or 0) == 0 then return \"rien\", \"sans-paire\" end", "" },
  { "ligne finie reposee", "if c.state == \"fini\" then return \"rien\", \"fini\" end", "" },
  { "max retours", "max_rollbacks = 1,", "max_rollbacks = 2," },
  { "retrait sans matieres", "if (c.missing or 0) > 0 then return false, \"matieres\" end", "" },
  { "retrait repete", "if (c.rollbacks or 0) >= cfg.max_rollbacks then return false, \"deja-retiree\" end", "" },
  { "retrait repete (inclusif)", "(c.rollbacks or 0) >= cfg.max_rollbacks then", "(c.rollbacks or 0) > cfg.max_rollbacks then" },
  { "dernier retour sans annulation", "if final or n >= cfg.max_rollbacks then", "if n >= cfg.max_rollbacks + 1 then" },
  { "progres a la baisse", "if not rec or built > (rec.built or 0) then", "if not rec or built ~= (rec.built or 0) then" },
  { "pause jamais finie", "return until_tick ~= nil and now < until_tick", "return until_tick ~= nil" },
  { "pack non borne", "if i <= max then", "if i <= max + 100 then" },
  { "pack non trie", "table.sort(list, function(a, b)", "table.sort(list, function(a, b) if true then return false end" },
  { "plan sans stock", "local take = math.min(qty, math.max(0, avail))", "local take = 0" },
  { "plan sans recette", "if not rc or (rc.out or 0) < 1 then return false end", "if not rc then return false end rc.out = rc.out or 1" },
  { "plan sans profondeur", "if depth >= R.CFG.craft_depth then return false end", "" },
  { "plan fabrications arrondies", "local runs = math.ceil(rest / rc.out)", "local runs = math.floor(rest / rc.out)" },
  { "plan used partage", "local avail = have(name) - (used[name] or 0)", "local avail = have(name)" },
  { "attente non bornee", "return (waited or 0) > 2 * (gate_wait or 0)", "return false" },
  { "attente bornee a une fois", "return (waited or 0) > 2 * (gate_wait or 0)", "return (waited or 0) > (gate_wait or 0)" },
  { "pack garde l'entree", "out[#out + 1] = { name = e.name,", "out[#out + 1] = e or { name = e.name," },
}
local caught = 0
for _, m in ipairs(muts) do
  local s2, n = src:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")), 1)
  assert(n == 1, "mutant introuvable : " .. m[1])
  local ok, M = pcall(function() return assert(load(s2))() end)
  local all = false
  if ok then
    local ok2, x = pcall(run, M)
    all = ok2
    if ok2 then for i = 1, 14 do if not x["c" .. i] then all = false end end end
  end
  if not all then caught = caught + 1 else print("mutant survivant : " .. m[1]) end
end
check(caught == #muts, string.format("mutants refuses : %d sur %d", caught, #muts))

print(string.format("[MIGRATION-RETOUR] BILAN : %d OK, %d ECHEC(S)", okc, fail))
if fail > 0 then os.exit(1) end
