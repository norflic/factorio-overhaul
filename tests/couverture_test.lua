--[[
  Lot COUVERTURE (8/11) : test hors jeu de shared/ai3/couverture.lua. Lancer depuis la racine du mod :
    lua5.2 tests/couverture_test.lua   -> [COUVERTURE] BILAN : N OK, 0 ECHEC(S)
  Trois parties : (1) la règle seule, (2) la règle branchée sur la VRAIE porte L6 (Pe.filter, comme Capi.portes la branche), (3) mutants :
  substitution unique dans le source du module, rechargé ; la suite doit ÉCHOUER.
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/ai3/couverture.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[COUVERTURE] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end
local Pe = require("shared.ai3.portes_extension")

local function suite(Cv)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  local base = { kind = "couvrir", product = "iron-plate", saturated = {}, free = 11, crisis = false }
  local NIL = {} -- valeur « absente » (pairs ne voit pas nil)
  local function with(t) local c = {} for k, v in pairs(base) do c[k] = v end for k, v in pairs(t) do if v == NIL then c[k] = nil else c[k] = v end end return c end

  -- 1. La règle seule.
  local ok, why = Cv.loop(base)
  want(ok == true and why:find("non sature", 1, true) ~= nil, "couvrir, produit non sature, places libres : passe en boucle (" .. tostring(why) .. ")")
  want(Cv.loop(with({ kind = "ouvrir" })) == true, "ouvrir : meme regle")
  want(Cv.loop(with({ kind = "chaine" })) == false, "une chaine d'assembleurs n'est pas une extraction")
  want(Cv.loop(with({ kind = "packs" })) == false, "des packs de recherche non plus")
  want(Cv.loop(with({ kind = NIL })) == false, "sorte absente : refus")
  local sat, swhy = Cv.loop(with({ saturated = { ["iron-plate"] = true } }))
  want(sat == false and swhy:find("sature", 1, true) ~= nil, "produit sature : plus de debouche, le verdict le dit")
  want(Cv.loop(with({ saturated = { ["copper-plate"] = true } })) == true, "la saturation d'un AUTRE produit ne retient pas celui-ci")
  want(Cv.loop(with({ free = 0 })) == false, "gisement couvert (0 place) : rien a poser")
  want(Cv.loop(with({ free = NIL })) == false, "places inconnues : compte comme aucune (garde fermee par defaut)")
  want(Cv.loop(with({ free = 0 / 0 })) == false, "places NaN : refus")
  want(Cv.loop(with({ free = -3 })) == false, "places negatives : refus")
  want(Cv.loop(with({ product = NIL })) == false, "ressource sans produit suivi : refus")
  want(Cv.loop(with({ product = 12 })) == false, "produit illisible : refus")
  local cr, cwhy = Cv.loop(with({ crisis = true }))
  want(cr == false and cwhy:find("crise", 1, true) ~= nil, "crise (survie, QG menace) : le travail de base d'abord")
  want(Cv.loop(nil) == false, "entree absente : refus")
  want(Cv.loop(with({ saturated = NIL })) == true, "table de saturation absente : aucun produit sature")

  -- 2. Compte des modules posés.
  want(Cv.batis(0, 0) == 0, "batis : rien")
  want(Cv.batis(30, 2) == 32, "batis : cumul + finis des ordres ouverts")
  want(Cv.batis(nil, 3) == 3 and Cv.batis(4, nil) == 4, "batis : une valeur absente compte zero")
  want(Cv.batis(-5, 1) == 1 and Cv.batis(0 / 0, 1) == 1 and Cv.batis(math.huge, 1) == 1, "batis : valeur illisible compte zero")
  local limit = function(b) return math.floor(b / Pe.MODULES_PER_SITE) + 1 end
  want(limit(Cv.batis(0, 0)) == 1 and limit(Cv.batis(60, 0)) == 3, "avec le cumul, la limite de chantiers suit la taille (60 modules : 3)")
  local hist = { { exec = "module", state = "fini" }, { exec = "module", state = "echec" }, { exec = "labos", state = "fini" },
    { exec = "module", state = "fini" } }
  want(Cv.seed(hist) == 2, "amorce : 2 modules finis dans l'historique")
  want(Cv.seed({ { exec = "champ", state = "fini" }, { exec = "champ", state = "ouvert" }, { exec = "outpost", state = "fini" } }) == 1,
    "amorce : une bande du champ finie compte, un avant-poste non")
  want(Cv.seed(hist, function() return 3 end) == 6, "amorce : nombre de modules par ordre")
  want(Cv.seed(nil) == 0 and Cv.seed({}) == 0, "amorce : historique absent ou vide")
  want(Cv.seed({ "x", 4 }) == 0, "amorce : entrees illisibles ignorees")

  want(Cv.slot_growth(0, 25) == 0 and Cv.slot_growth(24, 25) == 0 and Cv.slot_growth(25, 25) == 1 and Cv.slot_growth(60, 25) == 2,
    "emplacements : un de plus par tranche de 25 chantiers finis")
  want(Cv.slot_growth(nil, 25) == 0 and Cv.slot_growth(-9, 25) == 0 and Cv.slot_growth(50, 0) == 0 and Cv.slot_growth(50, nil) == 0,
    "emplacements : valeur ou pas illisible = zero")
  -- 2c. Modules d'un ordre de saturation.
  local g1, c1 = Cv.sat_modules(5, 0, 3, 8)
  want(g1 == 1 and c1 and c1:find("bras libres", 1, true), "modules : aucun bras libre -> 1 module, cause bras")
  local g2, c2 = Cv.sat_modules(5, 9, 3, 8)
  want(g2 == 4 and c2 and c2:find("bras libres", 1, true), "modules : 9 bras, 3 par module -> 1 + 3 = 4 modules sur 5 voulus")
  local g3, c3 = Cv.sat_modules(5, 30, 3, 8)
  want(g3 == 5 and c3 == nil, "modules : assez de bras -> tous les modules voulus, aucun ecart")
  local g4, c4 = Cv.sat_modules(20, 300, 3, 8)
  want(g4 == 8 and c4 and c4:find("plafond", 1, true), "modules : plafond de surete 8")
  want(Cv.sat_modules(nil, nil, nil, nil) == 1 and Cv.sat_modules(0 / 0, -4, 0, 0) == 1, "modules : entrees illisibles -> 1 module")
  want(Cv.sat_modules(1, 99, 3, 8) == 1, "modules : un seul voulu, un seul obtenu")
  -- 2b. Réserve de machines : la pose prévue devient une demande du mall.
  local function rate_of(list, item) for _, w in ipairs(list) do if w.item == item then return w.rate end end return nil end
  local mod = { key = "couvrir:a", kind = "couvrir", items = { { "drill", 14 }, { "belt", 420 }, { "pole", 30 } } }
  local mod2 = { key = "ouvrir:b", kind = "ouvrir", items = { { "drill", 6 }, { "belt", 150 } } }
  local chn = { key = "chaine:c", kind = "chaine", items = { { "gear", 99 } } }
  local w = Cv.reserve_wants({ mod, chn }, nil)
  want(#w == 3 and w[1].item == "belt" and w[2].item == "drill" and w[3].item == "pole", "wants : objets triés, la chaine est ignoree")
  want(rate_of(w, "belt") == 420 / Cv.PACE_MIN and rate_of(w, "drill") == 14 / Cv.PACE_MIN, "wants : quantite du module / rythme de pose")
  local w2 = Cv.reserve_wants({ mod, mod2 }, nil)
  want(rate_of(w2, "drill") == 20 / Cv.PACE_MIN and rate_of(w2, "belt") == 570 / Cv.PACE_MIN, "wants : somme sur les ordres de la decision")
  local w3 = Cv.reserve_wants({ mod, mod2 }, { ["couvrir:a"] = "porte L6 : transport sature" })
  want(rate_of(w3, "belt") == 150 / Cv.PACE_MIN and rate_of(w3, "pole") == nil, "wants : un ordre retenu par la porte ne compte pas")
  local w4 = Cv.reserve_wants({ mod }, { ["couvrir:a"] = "porte L6 : bras : 1 chantier(s) ouvert(s)" })
  want(rate_of(w4, "belt") == 420 / Cv.PACE_MIN, "wants : un ordre retenu seulement faute de place de chantier compte")
  local big = Cv.reserve_wants({ { key = "x", kind = "couvrir", items = { { "belt", 100000 } } } }, nil)
  want(rate_of(big, "belt") == Cv.RATE_MAX, "wants : plafonne a Cv.RATE_MAX par objet")
  local junk = Cv.reserve_wants({ { key = "x", kind = "couvrir", items = { { "belt", 0 / 0 }, { "pole", -2 }, { 5, 3 }, { "gear", math.huge }, { "ok", 3 } } } }, nil)
  want(#junk == 1 and junk[1].item == "ok", "wants : quantites illisibles ignorees")
  want(#Cv.reserve_wants(nil, nil) == 0 and #Cv.reserve_wants({ "x" }, nil) == 0, "wants : entree absente ou illisible")

  -- 3. Branchée sur la vraie porte L6, comme Capi.portes la branche (root_of rend un nombre > 0 pour un ordre en boucle).
  local A = { workers = 8, idle = 0, free_tasks = 30, batis = 0, open_sites = 0 } -- 30 taches libres pour 8 PNJ (seuil 26) : tendu (lot IA-CAPI : la part de PNJ libres ne compte plus)
  local function ctx_for(saturated, free, crisis)
    return { family_of = function() return "capi" end, family_rank = { capi = 3 }, site_kinds = { couvrir = true, ouvrir = true, chaine = true },
      tours_kinds = { couvrir = true, ouvrir = true, chaine = true }, measured = {}, measured_n = 0,
      root_of = function(o)
        local okk = Cv.loop({ kind = o.kind, product = o.resource == "iron-ore" and "iron-plate" or nil, saturated = saturated,
          free = free, crisis = crisis })
        return okk and 1 or nil
      end }
  end
  local couv = { key = "couvrir:iron-ore@1,2", kind = "couvrir", resource = "iron-ore", n = 14 }
  local chain = { key = "chaine:gun-turret", kind = "chaine", item = "gun-turret", n = 1 }
  local st = Pe.new()
  Pe.filter(st, A, { couv }, ctx_for({}, 11, false))
  local r = Pe.filter(st, A, { couv, chain }, ctx_for({}, 11, false))
  want(r.closed, "porte du transport fermee (0 PNJ libre sur 8, 2 mesures)")
  want(r.why[couv.key] == nil, "porte fermee : le couvrir EN BOUCLE passe")
  want(r.why[chain.key] ~= nil and r.why[chain.key]:find("transport sature", 1, true) ~= nil, "porte fermee : la chaine, elle, reste retenue")
  local st2 = Pe.new()
  Pe.filter(st2, A, { couv }, ctx_for({ ["iron-plate"] = true }, 11, false))
  local r2 = Pe.filter(st2, A, { couv }, ctx_for({ ["iron-plate"] = true }, 11, false))
  want(r2.why[couv.key] ~= nil, "produit sature : le couvrir est retenu par la porte fermee")
  local st3 = Pe.new()
  Pe.filter(st3, A, { couv }, ctx_for({}, 0, false))
  local r3 = Pe.filter(st3, A, { couv }, ctx_for({}, 0, false))
  want(r3.why[couv.key] ~= nil, "gisement couvert : retenu (rien a poser)")
  local st4 = Pe.new()
  Pe.filter(st4, A, { couv }, ctx_for({}, 11, true))
  local r4 = Pe.filter(st4, A, { couv }, ctx_for({}, 11, true))
  want(r4.why[couv.key] ~= nil, "crise : retenu")
  -- La porte des chantiers borne le travail ouvert : 1 chantier de plus par 25 modules posés.
  local c2 = { key = "couvrir:iron-ore@3,4", kind = "couvrir", resource = "iron-ore", n = 14 }
  local B0 = { workers = 8, idle = 0, free_tasks = 6, batis = 0, open_sites = 0 }
  local st5 = Pe.new()
  Pe.filter(st5, B0, { couv }, ctx_for({}, 11, false))
  local r5 = Pe.filter(st5, B0, { couv, c2 }, ctx_for({}, 11, false))
  want(r5.why[couv.key] == nil and r5.why[c2.key] ~= nil and r5.why[c2.key]:find("chantier", 1, true) ~= nil,
    "0 module pose : un seul chantier en boucle (le second est retenu par la porte des chantiers)")
  local B60 = { workers = 8, idle = 0, free_tasks = 6, batis = Cv.batis(58, 2), open_sites = 0 }
  local st6 = Pe.new()
  Pe.filter(st6, B60, { couv }, ctx_for({}, 11, false))
  local r6 = Pe.filter(st6, B60, { couv, c2 }, ctx_for({}, 11, false))
  want(r6.why[couv.key] == nil and r6.why[c2.key] == nil, "60 modules poses (cumul) : deux chantiers en boucle de front")
  -- Déterminisme.
  local sa, sb = Pe.new(), Pe.new()
  Pe.filter(sa, A, { couv }, ctx_for({}, 11, false)) Pe.filter(sb, A, { couv }, ctx_for({}, 11, false))
  local ra = Pe.filter(sa, A, { couv, chain }, ctx_for({}, 11, false))
  local rb = Pe.filter(sb, A, { couv, chain }, ctx_for({}, 11, false))
  want(Pe.describe(sa, { closed = ra.closed, kept = { 1 }, refused = {}, room = ra.room, limit = ra.limit, cause = ra.cause })
    == Pe.describe(sb, { closed = rb.closed, kept = { 1 }, refused = {}, room = rb.room, limit = rb.limit, cause = rb.cause }), "deterministe")
  return bad
end

local Cv = require("shared.ai3.couverture")
local bad = suite(Cv)
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "suite du module")
print(string.format("[COUVERTURE] suite : %d defaut(s)", #bad))

local MUTANTS = {
  { "sorte quelconque", "if not Cv.KINDS[a.kind] then return false,", "if false then return false," },
  { "chaine admise", "Cv.KINDS = { couvrir = true, ouvrir = true }", "Cv.KINDS = { couvrir = true, ouvrir = true, chaine = true }" },
  { "ouvrir oublie", "Cv.KINDS = { couvrir = true, ouvrir = true }", "Cv.KINDS = { couvrir = true }" },
  { "crise ignoree", "if a.crisis then return false, \"crise (survie ou QG menace) : le travail de base d'abord\" end\n  if type(a.product)", "if type(a.product)" },
  { "produit absent admis", "if type(a.product) ~= \"string\" then return false,", "if false then return false," },
  { "gisement couvert admis", "or a.free <= 0 then return false, \"gisement sans place libre\"", "or a.free < 0 then return false, \"gisement sans place libre\"" },
  { "places inconnues admises", "if type(a.free) ~= \"number\" or a.free ~= a.free or a.free <= 0 then return false, \"gisement sans place libre\"", "if (type(a.free) ~= \"number\" and a.free ~= nil) or a.free ~= a.free or a.free <= 0 then return false, \"gisement sans place libre\"" },
  { "saturation ignoree", "if (a.saturated or {})[a.product] and not a.saturation then return false,", "if false then return false," },
  { "saturation de tout produit", "if (a.saturated or {})[a.product] and not a.saturation then return false,", "if next(a.saturated or {}) ~= nil and not a.saturation then return false," },
  { "emplacements : tranche ignoree", "return math.floor(d / per)", "return 0" },
  { "emplacements : pas nul admis", "if type(per) ~= \"number\" or per ~= per or per < 1 then return 0 end", "" },
  { "modules : bras ignores", "local by_hands = 1 + math.floor(h / ph + 1e-9)", "local by_hands = 1000" },
  { "modules : plafond oublie", "local got = math.min(w, cap, by_hands)", "local got = math.min(w, by_hands)" },
  { "modules : au-dela du voulu", "local got = math.min(w, cap, by_hands)", "local got = math.min(cap, by_hands)" },
  { "wants : plafond oublie", "if rate > Cv.RATE_MAX then rate = Cv.RATE_MAX end", "" },
  { "wants : rythme oublie", "local rate = qty[k] / Cv.PACE_MIN", "local rate = qty[k]" },
  { "wants : retenus comptes", "local counts = why == nil or tostring(why):find(\"chantier\", 1, true) ~= nil", "local counts = true" },
  { "wants : chantier non compte", "local counts = why == nil or tostring(why):find(\"chantier\", 1, true) ~= nil", "local counts = why == nil" },
  { "wants : toute sorte", "if type(o) == \"table\" and Cv.KINDS[o.kind] and counts then", "if type(o) == \"table\" and counts then" },
  { "wants : quantite negative", "n == n and n > 0 and n < math.huge then qty", "n == n and n < math.huge then qty" },
  { "batis : cumul oublie", "return nat(done) + nat(open_fini)", "return nat(open_fini)" },
  { "batis : ouverts oublies", "return nat(done) + nat(open_fini)", "return nat(done)" },
  { "batis : valeur negative comptee", "if type(v) ~= \"number\" or v ~= v or v < 0 or v == math.huge then return 0 end", "if type(v) ~= \"number\" then return 0 end" },
  { "amorce : echec compte", "Cv.SITE_EXECS[r.exec] and r.state == \"fini\" then", "Cv.SITE_EXECS[r.exec] then" },
  { "amorce : champ oublie", "Cv.SITE_EXECS = { module = true, champ = true }", "Cv.SITE_EXECS = { module = true }" },
  { "amorce : exec quelconque", "Cv.SITE_EXECS[r.exec] and r.state == \"fini\" then", "r.state == \"fini\" then" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local s, n = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if n ~= 1 then
    check(false, "mutant introuvable (" .. n .. " substitution(s)) : " .. m[1])
  else
    local ok, Pm = pcall(load_mod, s)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Pm) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if killed then refused = refused + 1 else print("[COUVERTURE] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[COUVERTURE] mutants refuses : %d sur %d", refused, #MUTANTS))
-- Plancher de la porte des chantiers (Pe.site_room, troisieme argument = emplacements de la capitalisation, Em.slots).
local PE_PATH = "shared/ai3/portes_extension.lua"
local PE_SRC = read(PE_PATH)
local function load_pe(src) return assert(load(src, "=" .. PE_PATH, "t", _ENV))() end
local function suite_floor(P)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  local r0, l0 = P.site_room(0, 0, nil)
  want(r0 == 1 and l0 == 1, "sans plancher : la limite d'avant (1 chantier pour 0 module)")
  local r2, l2 = P.site_room(0, 0, 2)
  want(r2 == 2 and l2 == 2, "plancher 2 : 2 chantiers pour 0 module")
  local r3, l3 = P.site_room(0, 1, 2)
  want(r3 == 1 and l3 == 2, "plancher 2, 1 ouvert : une place")
  local r4, l4 = P.site_room(60, 0, 2)
  want(l4 == 3 and r4 == 3, "le plancher ne baisse jamais la limite de G12 (60 modules : 3)")
  local r5, l5 = P.site_room(0, 0, 0 / 0)
  want(l5 == 1 and r5 == 1, "plancher NaN ignore")
  local r6, l6 = P.site_room(nil, 0, 5)
  want(r6 == 0 and l6 == 0, "mesure absente : aucune place, meme avec un plancher (garde fermee par defaut)")
  local g = P.gate(P.new(), { workers = 8, idle = 4, free_tasks = 0, batis = 0, open_sites = 0, site_floor = 3 })
  want(g.room == 3 and g.limit == 3, "Pe.gate lit a.site_floor")
  local g2 = P.gate(P.new(), { workers = 8, idle = 4, free_tasks = 0, batis = 0, open_sites = 0 })
  want(g2.room == 1 and g2.limit == 1, "Pe.gate sans a.site_floor : la limite d'avant")
  return bad
end
do
  local bad2 = suite_floor(Pe)
  for _, m in ipairs(bad2) do check(false, m) end
  check(#bad2 == 0, "suite du plancher des chantiers")
  local MUT2 = {
    { "plancher ignore", "if fl ~= nil and fl > limit then limit = fl end", "" },
    { "plancher remplace la limite", "if fl ~= nil and fl > limit then limit = fl end", "if fl ~= nil then limit = fl end" },
    { "plancher non lu par la porte", "Pe.site_room(a and a.batis, a and a.open_sites, a and a.site_floor)", "Pe.site_room(a and a.batis, a and a.open_sites)" },
    { "plancher sur mesure absente", "if b == nil or o == nil then return 0, 0,", "if o == nil then return 0, 0," },
  }
  local ref2 = 0
  for _, m in ipairs(MUT2) do
    local s2, n = PE_SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
    if n ~= 1 then
      check(false, "mutant introuvable (" .. n .. ") : " .. m[1])
    else
      local ok, Pm = pcall(load_pe, s2)
      local ran, sb = false, nil
      if ok then ran, sb = pcall(suite_floor, Pm) end
      local killed = (not ok) or (not ran) or (#sb > 0)
      if killed then ref2 = ref2 + 1 else print("[COUVERTURE] mutant NON refuse : " .. m[1]) end
      check(killed, "mutant refuse : " .. m[1])
    end
  end
  print(string.format("[COUVERTURE] mutants du plancher refuses : %d sur %d", ref2, #MUT2))
end
print(string.format("[COUVERTURE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
