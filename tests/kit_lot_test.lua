--[[
  Lot POSE-PAR-LOTS (DC, 8/11, 17 h 50) : banc HORS JEU de la regle pure des KITS de fabrication (shared/ai3/kit_lot.lua) et de son
  branchement dans les projets (shared/ai3/projets.lua, P.want_kit). Lancement : lua5.2 tests/kit_lot_test.lua (depuis la racine du mod).

  Sections :
    1. K.build sur les VRAIES recettes (tests/fixtures/recipes.lua) : le cas du journal (courroies, poteaux, machines a vapeur,
       foreuses) tient en kits bornes (duree, cases), sans matiere premiere manquante, sans depasser le stock, intermediaires
       communs fabriques une fois ;
    2. bornes : stock insuffisant (reste = manque brut), objet non fabricable, unite plus lourde que la borne, plafond de kits ;
    3. P.want_kit : une tache de fabrication par kit (cle, pieces, etapes, matieres), UNE fabrication du budget par kit, cles libres,
       plusieurs projets sans collision sur le stock, repli sur P.want, interrupteur P.KIT_ON ;
    4. determinisme ;
    5. cout mesure par debug.sethook (instructions de la machine virtuelle, jamais le temps) ;
    6. mutants : chaque regle retiree fait echouer au moins un controle.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local QUIET = false -- vrai pendant les mutants : leurs echecs attendus ne sont pas imprimes
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not QUIET then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) print("== " .. name) end

local recipes = dofile("tests/fixtures/recipes.lua")

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local SRC = { kit = read("shared/ai3/kit_lot.lua"), projets = read("shared/ai3/projets.lua") }

--- Charge les modules (eventuellement modifies : mutant = { kit = {{ancien, nouveau}}, projets = {{ancien, nouveau}} }).
local function load_modules(mut)
  mut = mut or {}
  local function build(name, src, edits)
    for _, e in ipairs(edits or {}) do
      local s, n = src:gsub(e[1]:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (e[2]:gsub("%%", "%%%%")))
      assert(n >= 1, "mutant sans effet : " .. e[1])
      src = s
    end
    local fn = assert(load(src, "=" .. name))
    return fn()
  end
  package.loaded["shared.ai3.kit_lot"] = build("kit_lot", SRC.kit, mut.kit)
  package.loaded["shared.ai3.projets"] = nil
  local Pm = build("projets", SRC.projets, mut.projets)
  package.loaded["shared.ai3.projets"] = Pm
  local Book = require("shared.team.book")
  local book = Book.new(recipes, { stack_of = function(item)
    if item == "iron-plate" or item == "copper-plate" or item == "steel-plate" or item == "stone" or item == "wood" then return 100 end
    if item == "transport-belt" or item == "pipe" or item == "iron-gear-wheel" or item == "iron-stick" or item == "copper-cable" then return 100 end
    if item == "electronic-circuit" or item == "small-electric-pole" or item == "medium-electric-pole" or item == "inserter" then return 50 end
    return 50
  end })
  return package.loaded["shared.ai3.kit_lot"], Pm, book
end

local function sum_uses(kits)
  local u = {}
  for _, k in ipairs(kits) do
    for item, n in pairs(k.uses) do u[item] = (u[item] or 0) + n end
  end
  return u
end
local function total_wants(kits)
  local w = {}
  for _, k in ipairs(kits) do for _, x in ipairs(k.wants) do w[x[1]] = (w[x[1]] or 0) + x[2] end end
  return w
end
local function copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end

-- Le cas du journal (neuve40, votre equipe 14 a 36 min) : « transport-belt 153, medium-electric-pole 34, steam-engine 5, electric-mining-drill 2 »
local CAS = { { "transport-belt", 153 }, { "medium-electric-pole", 34 }, { "steam-engine", 5 }, { "electric-mining-drill", 2 } }
local RICHE = { ["iron-plate"] = 4000, ["copper-plate"] = 3000, ["steel-plate"] = 200, ["stone"] = 300, ["wood"] = 100, ["stone-furnace"] = 20 }

--- Toutes les verifications qui doivent TOUTES tenir : rejouees telles quelles sur chaque mutant.
local function suite(K, P, book, label, quiet)
  local before = failures
  local function ck(cond, msg) return check(cond, (label and (label .. " : ") or "") .. msg) end
  -- 1. cas du journal, stock riche
  local res = K.build(book, copy(RICHE), CAS)
  ck(#res.kits >= 1 and #res.kits <= K.MAX_KITS, "au moins un kit et au plus " .. K.MAX_KITS .. " (" .. #res.kits .. ")")
  ck(#res.rest == 0, "stock riche : rien ne reste a servir (" .. #res.rest .. ")")
  local tw = total_wants(res.kits)
  for _, w in ipairs(CAS) do ck(tw[w[1]] == w[2], "toutes les pieces sont dans les kits : " .. w[1] .. " " .. tostring(tw[w[1]])) end
  for i, kit in ipairs(res.kits) do
    ck(kit.energy <= K.MAX_S, "kit " .. i .. " : duree " .. kit.energy .. " s <= " .. K.MAX_S)
    ck(kit.slots <= K.MAX_SLOTS, "kit " .. i .. " : " .. kit.slots .. " cases <= " .. K.MAX_SLOTS)
  end
  local u = sum_uses(res.kits)
  for item, n in pairs(u) do ck(n <= (RICHE[item] or 0), "les kits ne prennent pas plus que le stock : " .. item) end
  for item, n in pairs(RICHE) do ck(res.avail[item] == n - (u[item] or 0), "stock virtuel apres les kits : " .. item) end
  -- un engrenage n'est fabrique qu'une fois par kit (un seul plan)
  for i, kit in ipairs(res.kits) do
    local seen = {}
    for _, c in ipairs(kit.crafts) do
      ck(not seen[c.recipe], "kit " .. i .. " : la recette " .. c.recipe .. " n'apparait qu'une fois")
      seen[c.recipe] = true
    end
  end
  -- 2. stock insuffisant : ce qui manque de matiere premiere reste (manque brut), rien n'est promis au-dela du stock
  local pauvre = { ["iron-plate"] = 60, ["copper-plate"] = 10 }
  local rp = K.build(book, copy(pauvre), CAS)
  local up = sum_uses(rp.kits)
  ck((up["iron-plate"] or 0) <= 60 and (up["copper-plate"] or 0) <= 10, "stock pauvre : aucun kit au-dela du stock")
  ck(#rp.rest >= 1, "stock pauvre : un reste est rendu au chemin d'avant")
  for _, kit in ipairs(rp.kits) do
    local plan = book:plan(kit.wants, pauvre)
    ck(next(plan.raw) == nil, "stock pauvre : un kit ne manque d'aucune matiere premiere")
  end
  -- stock vide : aucun kit, tout le manque reste
  local rv = K.build(book, {}, CAS)
  ck(#rv.kits == 0 and #rv.rest == #CAS, "stock vide : aucun kit, " .. #CAS .. " restes (" .. #rv.kits .. ", " .. #rv.rest .. ")")
  -- objet non fabricable a la main (plaque) : au reste
  local rn = K.build(book, copy(RICHE), { { "iron-plate", 40 }, { "transport-belt", 10 } })
  local restn = {}
  for _, r in ipairs(rn.rest) do restn[r[1]] = r[2] end
  ck(restn["iron-plate"] == 40 and #rn.kits == 1, "une plaque n'est pas un kit : elle reste (fonderie)")
  -- 3. plafond de kits : max_kits = 1 → le reste est rendu
  local r1 = K.build(book, copy(RICHE), CAS, { max_kits = 1 })
  ck(#r1.kits == 1, "max_kits 1 : un seul kit (" .. #r1.kits .. ")")
  local covered = total_wants(r1.kits)
  local restq = {}
  for _, r in ipairs(r1.rest) do restq[r[1]] = (restq[r[1]] or 0) + r[2] end
  for _, w in ipairs(CAS) do ck((covered[w[1]] or 0) + (restq[w[1]] or 0) == w[2], "max_kits 1 : kit + reste = manque (" .. w[1] .. ")") end
  local r0 = K.build(book, copy(RICHE), CAS, { max_kits = 0 })
  ck(#r0.kits == 0 and #r0.rest == #CAS, "max_kits 0 : aucun kit")
  -- une unite plus lourde que la borne de duree est quand meme fabriquee (une seule)
  local rl = K.build(book, copy(RICHE), { { "electric-mining-drill", 3 } }, { max_s = 1 })
  ck(#rl.kits >= 1 and total_wants(rl.kits)["electric-mining-drill"] == 3, "borne de duree trop basse : les unites partent une par une dans des kits (" .. #rl.kits .. ")")
  ck(#rl.kits <= K.MAX_KITS, "... sans depasser le plafond de kits")
  -- 4. P.want_kit
  local st = {}
  local E = P.context(copy(RICHE), book, { open = {} }, st)
  E.st = st
  E.tick = 600
  local proj = { id = 7, key = "auto:centrale" }
  P.want_kit(E, proj, CAS, 83, "module")
  local nk = 0
  local tw2 = {}
  for _, t in ipairs(E.tasks) do
    if t.kind == "craft" and t.kit then
      nk = nk + 1
      ck(t.key:match("^ia3:7:kit:module:%d+$") ~= nil, "cle de kit " .. t.key)
      ck(t.ia3 == 7 and t.prio == 83 and t.tag == "ia3" and t.why == "auto:centrale", "champs de la tache de kit")
      ck(type(t.steps) == "table" and #t.steps >= 1 and type(t.uses) == "table" and #t.uses >= 1, "etapes et matieres de la tache")
      ck(t.item == t.kit[1][1] and t.count == t.kit[1][2], "item et count = premiere piece")
      for _, w in ipairs(t.kit) do tw2[w[1]] = (tw2[w[1]] or 0) + w[2] end
    end
  end
  ck(nk == #res.kits and nk >= 1, "une tache par kit (" .. nk .. ")")
  ck(E.crafts == nk, "chaque kit compte pour UNE fabrication du budget par pensee (" .. E.crafts .. " pour " .. nk .. ")")
  for _, w in ipairs(CAS) do ck(tw2[w[1]] == w[2], "P.want_kit : tout le manque est en kit : " .. w[1]) end
  ck(#(st.kit_log or {}) == nk, "une annonce par kit (" .. #(st.kit_log or {}) .. ")")
  -- relance a la pensee suivante (meme contenu, kits libres) : pas de nouvelle annonce
  local E2 = P.context(copy(RICHE), book, { open = {} }, st)
  E2.st = st
  E2.tick = 900
  P.want_kit(E2, proj, CAS, 83, "module")
  ck(#(st.kit_log or {}) == nk, "meme contenu : pas de nouvelle annonce (" .. #(st.kit_log or {}) .. ")")
  -- cle prise (ouverte) : le kit suivant prend la cle suivante, jamais la meme
  local open = { ["ia3:7:kit:module:1"] = true }
  local E3 = P.context(copy(RICHE), book, { open = open }, {})
  E3.st = {}
  P.want_kit(E3, proj, { { "transport-belt", 20 } }, 83, "module")
  local k3
  for _, t in ipairs(E3.tasks) do if t.kit then k3 = t end end
  ck(k3 and k3.key == "ia3:7:kit:module:2", "cle ouverte : le kit prend la cle libre suivante (" .. tostring(k3 and k3.key) .. ")")
  -- 5. deux projets, un seul stock : aucune collision
  local E4 = P.context({ ["iron-plate"] = 220, ["copper-plate"] = 100 }, book, { open = {} }, {})
  E4.st = {}
  P.want_kit(E4, { id = 1, key = "a" }, { { "transport-belt", 100 } }, 80, "module")
  P.want_kit(E4, { id = 2, key = "b" }, { { "transport-belt", 100 } }, 79, "module")
  local used = {}
  for _, t in ipairs(E4.tasks) do
    if t.kit then for _, it in ipairs(t.uses) do used[it[1]] = (used[it[1]] or 0) + it[2] end end
  end
  ck((used["iron-plate"] or 0) <= 220, "deux projets : les kits ne depassent pas le stock commun (" .. tostring(used["iron-plate"]) .. " sur 220)")
  ck((E4.raw["iron-plate"] or { n = 0 }).n > 0, "deux projets : ce que le stock ne couvre plus devient un manque brut de fer")
  ck(E4.avail["iron-plate"] ~= nil and E4.avail["iron-plate"] >= 0, "stock virtuel jamais negatif")
  -- 6. interrupteur : P.KIT_ON faux = chemin d'avant (aucune tache kit)
  local KO = P.KIT_ON
  P.KIT_ON = false
  local E5 = P.context(copy(RICHE), book, { open = {} }, {})
  E5.st = {}
  P.want_kit(E5, proj, CAS, 83, "module")
  local kitted = 0
  for _, t in ipairs(E5.tasks) do if t.kit then kitted = kitted + 1 end end
  P.KIT_ON = KO
  ck(kitted == 0 and #E5.tasks > 0, "P.KIT_ON faux : le chemin d'avant (morceaux de 30 s), aucun kit")
  -- 6 bis. bornes explicites : cases (inventaire) et budget de fabrications de la pensee
  local rs = K.build(book, copy(RICHE), CAS, { max_slots = 8, max_kits = 12 })
  ck(#rs.kits >= 2, "borne de cases 8 : le manque est coupe en plusieurs kits (" .. #rs.kits .. ")")
  for i, kit in ipairs(rs.kits) do ck(kit.slots <= 8 or #kit.wants == 1, "borne de cases 8 : kit " .. i .. " a " .. kit.slots .. " cases") end
  local tws = total_wants(rs.kits)
  local rss = {}
  for _, r in ipairs(rs.rest) do rss[r[1]] = (rss[r[1]] or 0) + r[2] end
  for _, w in ipairs(CAS) do ck((tws[w[1]] or 0) + (rss[w[1]] or 0) == w[2], "borne de cases : kits + reste = manque (" .. w[1] .. ")") end
  local E8 = P.context(copy(RICHE), book, { open = {} }, {})
  E8.st = {}
  E8.crafts = P.MAX_CRAFTS - 1
  P.want_kit(E8, proj, CAS, 83, "module")
  local k8 = 0
  for _, t in ipairs(E8.tasks) do if t.kit then k8 = k8 + 1 end end
  ck(k8 <= 1, "budget de fabrications presque epuise : au plus un kit (" .. k8 .. ")")
  ck(E8.crafts <= P.MAX_CRAFTS, "le budget de fabrications n'est pas depasse (" .. E8.crafts .. ")")
  -- stock direct : ce qui est deja la est pris avant toute fabrication
  local E9 = P.context(copy(RICHE), book, { open = {} }, {})
  E9.st = {}
  E9.avail["transport-belt"] = 500
  E9.avail["steam-engine"] = 2
  P.want_kit(E9, proj, { { "transport-belt", 100 }, { "steam-engine", 5 } }, 83, "module")
  ck(E9.avail["transport-belt"] == 400, "stock direct pris : 500 - 100 = 400 (" .. tostring(E9.avail["transport-belt"]) .. ")")
  ck(E9.avail["steam-engine"] == 0, "stock direct partiel pris en entier (" .. tostring(E9.avail["steam-engine"]) .. ")")
  local t9
  for _, t in ipairs(E9.tasks) do if t.kit then t9 = t end end
  ck(t9 and t9.kit[1][1] == "steam-engine" and t9.kit[1][2] == 3, "seul le manque net (5 - 2 = 3) est fabrique")
  -- 7. le stock couvre tout : rien a fabriquer
  local E6 = P.context(copy(RICHE), book, { open = {} }, {})
  E6.st = {}
  E6.avail["transport-belt"] = 500
  E6.avail["medium-electric-pole"] = 100
  E6.avail["steam-engine"] = 10
  E6.avail["electric-mining-drill"] = 10
  local ok6 = P.want_kit(E6, proj, CAS, 83, "module")
  ck(ok6 == true and #E6.tasks == 0, "tout au stock : vrai et aucune tache")
  return failures == before
end

local function run_all()
  local K, P, book = load_modules()
  suite(K, P, book, nil)
  return K, P, book
end

section("1 a 3. kits sur les recettes du jeu, bornes, P.want_kit")
local K, P, book = run_all()

section("4. determinisme")
do
  local function sig(res)
    local parts = {}
    for _, k in ipairs(res.kits) do
      local w = {}
      for _, x in ipairs(k.wants) do w[#w + 1] = x[1] .. "=" .. x[2] end
      parts[#parts + 1] = table.concat(w, ",") .. "/" .. k.energy .. "/" .. k.slots
    end
    for _, r in ipairs(res.rest) do parts[#parts + 1] = "rest:" .. r[1] .. "=" .. r[2] end
    return table.concat(parts, ";")
  end
  local a = sig(K.build(book, copy(RICHE), CAS))
  local b = sig(K.build(book, copy(RICHE), CAS))
  check(a == b, "deux appels donnent les memes kits")
  print("  kits du cas du journal : " .. a)
end

section("5. cout mesure par debug.sethook (instructions de la machine virtuelle)")
do
  local function instr(fn)
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 100)
    fn()
    debug.sethook()
    return n * 100
  end
  -- pire cas vise : 10 projets, chacun avec un manque de 4 objets, stock riche
  local cost1 = instr(function() K.build(book, copy(RICHE), CAS) end)
  local cost10 = instr(function()
    local E = P.context(copy(RICHE), book, { open = {} }, {})
    E.st = {}
    for i = 1, 10 do P.want_kit(E, { id = i, key = "p" .. i }, CAS, 80, "module") end
  end)
  -- comparaison : le chemin d'avant (P.want) sur les memes manques
  local cost10_old = instr(function()
    local E = P.context(copy(RICHE), book, { open = {} }, {})
    E.st = {}
    for i = 1, 10 do P.want(E, { id = i, key = "p" .. i }, CAS, 80, false, "module") end
  end)
  print(string.format("  1 projet (K.build) : %d instructions ; 10 projets P.want_kit : %d ; 10 projets P.want (avant) : %d ; rapport %.2f",
    cost1, cost10, cost10_old, cost10 / math.max(1, cost10_old)))
  check(cost1 < 600000, "un projet : moins de 600 000 instructions (" .. cost1 .. ")")
  check(cost10 < 4000000, "dix projets : moins de 4 000 000 instructions par pensee (" .. cost10 .. ")")
end

section("6. mutants")
do
  local mutants = {
    { "duree ignoree", { kit = { { "if K.energy(plan) > max_s or K.slots(book, plan) > max_slots then", "if K.slots(book, plan) > max_slots then" } } } },
    { "cases ignorees", { kit = { { "if K.energy(plan) > max_s or K.slots(book, plan) > max_slots then", "if K.energy(plan) > max_s then" } } } },
    { "matiere premiere ignoree", { kit = { { 'if next(plan.raw) ~= nil then return false, "raw", plan end', "" } } } },
    { "plafond de kits ignore", { kit = { { "if #kits >= max_kits and #cur == 0 then", "if false then" } } } },
    { "stock virtuel non debite", { kit = { { "av = plan.avail\n    cur = {}", "cur = {}" } } } },
    { "reste perdu", { kit = { { "rest[#rest + 1] = { item, left }\n          left = 0\n        else", "left = 0\n        else" } } } },
    { "non fabricable en kit", { kit = { { "if left > 0 and not book:handcraftable(item) then", "if false then" } } } },
    { "kit sans budget", { projets = { { "    E.crafts = E.crafts + 1\n    local head = kit.wants[1]", "    local head = kit.wants[1]" } } } },
    { "cle ouverte reprise", { projets = { { "until not (E.keys[key] or E.open[key])", "until true" } } } },
    { "interrupteur ignore", { projets = { { "if not P.KIT_ON then return P.want(E, proj, list, prio, false, tag) end", "" } } } },
    { "reste non servi", { projets = { { "return P.want(E, proj, res.rest, prio, false, tag)", "return false" } } } },
    { "stock direct non debite", { projets = { { "      E.avail[item] = have - n\n    elseif n > 0 then", "    elseif n > 0 then" } } } },
    { "annonce a chaque pensee", { kit = { { "if st.kit_sig[rec.key] == sig then return false end", "" } } } },
    { "kit sans pieces", { projets = { { "kit = pieces,", "kit = nil," } } } },
    { "budget de kits hors plafond", { projets = { { "local room = math.min(Kit.MAX_KITS, P.MAX_CRAFTS - E.crafts)", "local room = Kit.MAX_KITS + 5" } } } },
  }
  for _, m in ipairs(mutants) do
    local before_f = failures
    local before_p = passes
    local Km, Pm, bookm = load_modules(m[2])
    QUIET = true
    local ok, err = pcall(suite, Km, Pm, bookm, "mutant " .. m[1], true)
    QUIET = false
    local caught = (failures > before_f) or not ok
    -- les echecs d'un mutant ne sont pas des echecs du banc : ils sont retires du bilan, seul « detecte » compte
    local mut_fail = failures - before_f
    failures = before_f
    passes = before_p
    check(caught, "mutant non detecte : " .. m[1] .. (ok and "" or (" (plantage : " .. tostring(err):sub(1, 60) .. ")")))
    print(string.format("  mutant %-34s %s (%d controle(s) en echec%s)", m[1], caught and "DETECTE" or "SURVIT", mut_fail, ok and "" or ", plantage"))
  end
end

print(string.format("[KIT-LOT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
