--[[
  Lot L6 (portes avant d'étendre) : test hors jeu de shared/ai3/portes_extension.lua. Lancer depuis la racine du mod :
    lua5.2 tests/portes_extension_test.lua   -> [L6] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source du module, rechargé ; la suite doit ÉCHOUER. Coût : instructions (debug.sethook).
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/ai3/portes_extension.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L6] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

local function ord(key, t)
  t.key, t.item = key, t.item or key
  t.n, t.rank = t.n or 1, t.rank or 3
  return t
end
local function keys(list) local o = {} for _, x in ipairs(list) do o[#o + 1] = x.key end return table.concat(o, ",") end

local function suite(Pe)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  -- 1. Le défaut du 7/11 : 2 PNJ, 0 libre, 16 tâches libres. Fermée à la 2e mesure de suite (pas à la 1re).
  local D1 = { workers = 2, idle = 0, free_tasks = 16, batis = 10, open_sites = 0 }
  local st = Pe.new()
  local orders = { ord("chantier", { tours = true, site = true }), ord("tapis", { tours = true, belt = true }),
    ord("defense", { rank = 1, tours = true, site = true, n = 4 }) }
  local r1 = Pe.decide(st, D1, orders)
  want(not r1.closed, "D1 : une seule mesure tendue ne ferme pas")
  local r2 = Pe.decide(st, D1, orders)
  want(r2.closed, "D1 : fermee a la 2e mesure tendue")
  want(keys(r2.kept) == "tapis,defense", "D1 : chantier retenu, tapis et R1 gardes (" .. keys(r2.kept) .. ")")
  -- I2 : la défense (R1) garde ses 4 unités.
  want(r2.kept[2] and r2.kept[2].n == 4, "I2 : R1 ni retenu ni reduit")
  -- 2. Hystérésis : une mesure à peine sous le seuil de sortie ne rouvre pas ; 2 mesures détendues rouvrent.
  local mid = { workers = 10, idle = 1, free_tasks = 25, batis = 10, open_sites = 0 } -- 25 tâches (sortie 22, entrée 32) : ni tendu ni détendu
  Pe.decide(st, mid, {})
  Pe.decide(st, mid, {})
  want(st.closed, "hysteresis : 25 taches libres pour 10 PNJ ne rouvre pas (sortie a 22)")
  local calm = { workers = 10, idle = 3, free_tasks = 10, batis = 10, open_sites = 0 }
  Pe.decide(st, calm, {})
  want(st.closed, "hysteresis : une mesure detendue ne rouvre pas")
  local r3 = Pe.decide(st, calm, { ord("chantier", { tours = true, site = true }) })
  want(not r3.closed and keys(r3.kept) == "chantier", "2 mesures detendues rouvrent")
  -- 3. Seuil qui SUIT la taille : 30 PNJ, 10 libres, 20 tâches libres : pas tendu (seuil 92) ; 100 tâches : tendu.
  local big = Pe.new()
  local t30 = Pe.measure({ workers = 30, idle = 10, free_tasks = 20 })
  want(t30 == false, "30 PNJ, 20 taches libres : pas tendu (seuil qui suit l'effectif)")
  local t30b = Pe.measure({ workers = 30, idle = 10, free_tasks = 100 })
  want(t30b == true, "30 PNJ, 100 taches libres : tendu")
  local t30c = Pe.measure({ workers = 30, idle = 2, free_tasks = 0 })
  want(t30c == false, "30 PNJ, 2 libres, aucune tache qui attende : pas tendu (lot IA-CAPI)")
  -- 4. Garde fermée : mesure absente ou effectif nul -> fermée.
  local ra = Pe.decide(big, { batis = 0, open_sites = 0 }, { ord("chantier", { tours = true }) })
  want(ra.closed and #ra.kept == 0, "mesure absente : porte fermee")
  local z = Pe.measure({ workers = 0, idle = 0, free_tasks = 0 })
  want(z == true, "aucun PNJ : tendu")
  -- 5. Bras à seuil croissant : 0 module -> 1 chantier ; 100 modules -> 5 ; ouverts déduits ; I1.
  local room0, lim0 = Pe.site_room(0, 0)
  local room100, lim100 = Pe.site_room(100, 2)
  want(lim0 == 1 and room0 == 1, "0 module : 1 chantier a la fois")
  want(lim100 == 5 and room100 == 3, "100 modules, 2 ouverts : 3 places (" .. room100 .. ")")
  local calm2 = { workers = 10, idle = 5, free_tasks = 0, batis = 50, open_sites = 1 } -- limite 3, 2 places
  local s5 = Pe.new()
  local many = {}
  for i = 1, 6 do many[i] = ord("c" .. i, { site = true }) end
  local r5 = Pe.decide(s5, calm2, many)
  want(#r5.kept == 2 and #r5.refused == 4, "I1 : 2 chantiers ouverts sur 6 demandes (" .. #r5.kept .. ")")
  -- 6. Petites marches : tendu (une seule mesure) -> une unité ; détendu -> n ; mesuré -> une unité.
  local s6 = Pe.new()
  local r6 = Pe.decide(s6, { workers = 4, idle = 0, free_tasks = 20, batis = 0, open_sites = 0 }, { ord("fours", { n = 3 }) })
  want(r6.kept[1] and r6.kept[1].n == 1 and r6.kept[1].reduced, "tendu : une unite par decision")
  local s6b = Pe.new()
  local r6b = Pe.decide(s6b, calm2, { ord("fours", { n = 3 }), ord("labos", { n = 2, measured = true }) })
  want(r6b.kept[1].n == 3 and r6b.kept[2].n == 1, "detendu : n garde ; manque mesure : une unite")
  -- 7. Anti-répétition : même objet mesuré deux décisions de suite -> retenu, sauf seul de son rang ; un autre objet passe.
  local s7 = Pe.new()
  Pe.decide(s7, calm2, { ord("a", { item = "x", measured = true }) })
  local r7 = Pe.decide(s7, calm2, { ord("a", { item = "x", measured = true }), ord("b", { item = "y", measured = true }) })
  want(keys(r7.kept) == "b", "repetition : x retenu, y passe (" .. keys(r7.kept) .. ")")
  local r7b = Pe.decide(s7, calm2, { ord("a", { item = "y", measured = true, alone = true }) })
  want(keys(r7b.kept) == "a", "repetition : seul en manque de son rang, permis")
  -- 7 bis. API option par option (decide_turn de la décision découpée) : places décomptées, R1 non réduit.
  local s7c = Pe.new()
  local g = Pe.gate(s7c, calm2)
  local why_site = Pe.check(g, ord("c", { site = true }))
  Pe.take(g, ord("c", { site = true }))
  Pe.take(g, ord("c2", { site = true }))
  local why_full = Pe.check(g, ord("c3", { site = true }))
  local n_def = Pe.units(g, ord("def", { rank = 1, n = 5 }))
  want(why_site == nil and why_full ~= nil and n_def == 5, "API option par option : places decomptees, R1 non reduit")
  -- 7 ter. Traduction des ordres de la capitalisation (Pe.translate) et filtre du runtime (Pe.filter).
  local CTX = { family_of = function(k) return (k == "garde") and "defense" or "capi" end, family_rank = { defense = 1, capi = 3 },
    site_kinds = { chaine = true, couvrir = true }, tours_kinds = { chaine = true, couvrir = true, labos = true } }
  local pc = Pe.translate({ key = "k", kind = "chaine", item = "x", n = 3 }, CTX)
  local pg = Pe.translate({ key = "g", kind = "garde", n = 2 }, CTX)
  local pl = Pe.translate({ key = "l", kind = "labos", n = 1 }, CTX)
  local pr = Pe.translate({ key = "r", kind = "couvrir", resource = "minerai", n = 1 }, CTX)
  want(pc.rank == 3 and pc.site and pc.tours and not pc.belt and not pc.measured, "traduction : chaine = rang 3, chantier, tournees")
  want(pg.rank == 1 and not pg.site, "traduction : rang lu par la famille (garde -> defense -> 1)")
  want(pl.tours and not pl.site, "traduction : laboratoires = tournees sans chantier")
  want(pr.item == "minerai", "traduction : objet = ressource a defaut d'objet")
  want(not pc.measured and not pc.alone, "traduction sans manque mesure (L3 eteint) : ni mesure ni seul")
  local CTXM = { family_of = CTX.family_of, family_rank = CTX.family_rank, site_kinds = CTX.site_kinds, tours_kinds = CTX.tours_kinds,
    measured = { x = 12, y = 0 }, measured_n = 1 }
  local pm = Pe.translate({ key = "k", kind = "chaine", item = "x", n = 3 }, CTXM)
  local pn = Pe.translate({ key = "n", kind = "chaine", item = "y", n = 3 }, CTXM)
  want(pm.measured and pm.alone and not pn.measured, "traduction : manque mesure de L3 (x : 12) ; y a 0 n'est pas mesure ; seul en manque")
  CTXM.measured_n = 2
  want(not Pe.translate({ key = "k", kind = "chaine", item = "x" }, CTXM).alone, "traduction : deux objets en manque, pas seul")
  local s7f = Pe.new()
  local ords = { { key = "c", kind = "chaine", n = 2 }, { key = "g", kind = "garde", n = 2 }, { key = "e", kind = "equiper", n = 1 } }
  Pe.filter(s7f, D1, ords, CTX)
  local rf = Pe.filter(s7f, D1, ords, CTX)
  want(rf.closed and rf.why.c and not rf.why.g and not rf.why.e and rf.refused == 1 and rf.kept == 2,
    "filtre : chaine retenue, garde (rang 1) et levier gardes")
  -- 9. Lot VIDEO-COUVERTURE 3 (G73, C3.3) : sous saturation, la recherche est coupée EXPLICITEMENT (packs, laboratoires), sans dépendre de la
  -- liste de tournées de l'appelant ; elle reprend dès que la saturation tombe (hystérésis comprise).
  local CTXR = { family_of = function() return "recherche" end, family_rank = { recherche = 3 }, site_kinds = {}, tours_kinds = {} } -- l'appelant ne déclare AUCUNE tournée
  local pk = Pe.translate({ key = "p", kind = "packs", item = "x", n = 2 }, CTXR)
  local lb = Pe.translate({ key = "l", kind = "labos", n = 1 }, CTXR)
  local ch = Pe.translate({ key = "c", kind = "fours", item = "y", n = 1 }, CTXR)
  want(pk.research and lb.research and not ch.research, "traduction : packs et labos nourrissent la recherche, pas les fours")
  want(pk.tours and lb.tours and not ch.tours, "traduction : la recherche ajoute des tournees meme si l'appelant ne les declare pas")
  local sr = Pe.new()
  local rord = { { key = "p", kind = "packs", item = "x", n = 2 }, { key = "l", kind = "labos", n = 1 }, { key = "f", kind = "fours", item = "y", n = 1 },
    { key = "t", kind = "techno", n = 1 } }
  Pe.filter(sr, D1, rord, CTXR)
  local rc = Pe.filter(sr, D1, rord, CTXR)
  want(rc.closed and rc.why.p and rc.why.l and not rc.why.f and not rc.why.t and rc.refused == 2,
    "sous saturation : 0 ordre packs ni labos emis (ni fours, ni techno retenus)")
  want(rc.why.p and rc.why.p:find("recherche coupee", 1, true) ~= nil, "la raison dit que la recherche est coupee (" .. tostring(rc.why.p) .. ")")
  local calm9 = { workers = 10, idle = 3, free_tasks = 10, batis = 10, open_sites = 0 }
  local rk1 = Pe.filter(sr, calm9, rord, CTXR)
  want(rk1.closed and rk1.why.p, "une mesure detendue ne rouvre pas la recherche")
  local rk2 = Pe.filter(sr, calm9, rord, CTXR)
  want(not rk2.closed and rk2.why.p == nil and rk2.why.l == nil and rk2.kept == 4, "des que la saturation tombe : les ordres packs et labos sont emis")
  -- la recherche d'un rang sur (R1) n'est jamais coupee (I2) ; un tapis non plus
  local s9 = Pe.new()
  Pe.decide(s9, D1, {})
  local r9 = Pe.decide(s9, D1, { ord("r1", { rank = 1, research = true }), ord("rb", { research = true, belt = true }), ord("rx", { research = true }) })
  want(keys(r9.kept) == "r1,rb", "recherche : R1 et tapis gardes, l'autre retenu (" .. keys(r9.kept) .. ")")
  -- 8. Déterminisme : mêmes entrées, mêmes sorties.
  local sa, sb = Pe.new(), Pe.new()
  local ra8 = Pe.decide(sa, D1, orders)
  local rb8 = Pe.decide(sb, D1, orders)
  want(Pe.describe(sa, ra8) == Pe.describe(sb, rb8), "deterministe")
  -- 9. RACINE (lot tv-fer, partie du 8/11 : « 0 PNJ libre sur 8, 6 tache(s) libre(s) », ordre couvrir iron-ore retenu 14 minutes de suite).
  local Rn = { workers = 8, idle = 0, free_tasks = 30, batis = 0, open_sites = 0 } -- (lot IA-CAPI : 6 tâches ne ferment plus ; 30 > 26)
  local function ctx_root(short) -- short = { [produit] = manque } ; couvrir/ouvrir iron-ore -> iron-plate
    return { family_of = function() return "capi" end, family_rank = { capi = 3 }, site_kinds = { couvrir = true, ouvrir = true },
      tours_kinds = { couvrir = true, ouvrir = true, chaine = true }, measured = {}, measured_n = 0,
      root_of = function(o)
        if o.kind ~= "couvrir" and o.kind ~= "ouvrir" then return nil end
        return o.resource == "iron-ore" and short["iron-plate"] or nil
      end }
  end
  local couv = { key = "couvrir:iron-ore", kind = "couvrir", resource = "iron-ore", n = 17 }
  local chain = { key = "chaine:gun-turret", kind = "chaine", item = "gun-turret", n = 1 }
  local sR = Pe.new()
  Pe.filter(sR, Rn, { couv }, ctx_root({}))
  local rRn = Pe.filter(sR, Rn, { couv, chain }, ctx_root({}))
  want(rRn.closed, "racine : porte fermee (0 libre sur 8)")
  want(rRn.why["couvrir:iron-ore"] ~= nil and rRn.why["chaine:gun-turret"] ~= nil, "racine : sans manque, couvrir est retenu comme avant")
  local sR2 = Pe.new()
  Pe.filter(sR2, Rn, { couv }, ctx_root({ ["iron-plate"] = 600 }))
  local rR = Pe.filter(sR2, Rn, { couv, chain }, ctx_root({ ["iron-plate"] = 600 }))
  want(rR.closed, "racine : la porte reste fermee")
  want(rR.why["couvrir:iron-ore"] == nil, "racine : couvrir iron-ore passe la porte fermee (iron-plate en manque)")
  want(rR.why["chaine:gun-turret"] ~= nil, "racine : un ordre qui n'est pas une racine reste retenu")
  want(#rR.roots == 1 and rR.roots[1].key == "couvrir:iron-ore" and rR.roots[1].need == 600, "racine : journal (cle, manque 600)")
  local rRc = Pe.filter(Pe.new(), { workers = 8, idle = 5, free_tasks = 0, batis = 0, open_sites = 0 }, { couv }, ctx_root({ ["iron-plate"] = 600 }))
  want(not rRc.closed and #rRc.roots == 0, "racine : porte ouverte, rien a noter")
  -- La porte des chantiers reste : plus de place -> la racine est retenue quand meme.
  local rRs = Pe.filter(Pe.new(), { workers = 8, idle = 5, free_tasks = 0, batis = 0, open_sites = 1 }, { couv }, ctx_root({ ["iron-plate"] = 600 }))
  want(rRs.why["couvrir:iron-ore"] ~= nil, "racine : la porte des chantiers (bras) s'applique encore")
  -- R0 et R1, recherche : inchangés (une recherche n'est jamais une racine).
  local always = ctx_root({})
  always.root_of = function() return 600 end
  local tr = Pe.translate({ key = "packs", kind = "packs", resource = "iron-ore", n = 1 }, always)
  want(not tr.root, "racine : un ordre de recherche n'est pas une racine")
  -- Manque nul : pas une racine.
  local tz = Pe.translate(couv, ctx_root({ ["iron-plate"] = 0 }))
  want(not tz.root, "racine : manque 0 ne fait pas une racine")
  -- 10. Lot IA-CAPI (partie du DC 0.6.96, joueur, minute 114, tick 409980 : « 1 PNJ libre(s) sur 22, 4 tache(s) libre(s) (tendu
  -- au-dela de 68) » ; porte fermée de la minute 16 à la 114, 38 ordres chaine retenus sur 38, aucune rangée d'assembleurs envoyée).
  -- Les règles I2 (file sûre) et ZERO-IDLE donnent une tâche à tout PNJ sans tâche : la part de PNJ libres reste à 0 ou 1 par
  -- construction, dans les 5 factions. Le transport sature quand du travail ATTEND au-delà de ce que l'effectif sert.
  local P114 = { workers = 22, idle = 1, free_tasks = 4, batis = 2, open_sites = 0 }
  local chaine = { ord("chaine:copper-cable", { tours = true, site = true }) }
  local s10 = Pe.new()
  Pe.decide(s10, P114, chaine)
  local r10 = Pe.decide(s10, P114, chaine)
  want(not r10.closed and keys(r10.kept) == "chaine:copper-cable", "IA-CAPI : 1 PNJ libre sur 22, 4 taches libres : porte ouverte, la rangee passe")
  -- fermée par un vrai engorgement (minute 109 : 0 libre sur 23, 77 tâches > 71), elle rouvre quand les tâches libres retombent au
  -- seuil de sortie (minute 103 : 3 libres sur 22, 30 tâches <= 46), sans attendre 20 % de PNJ libres
  local P109 = { workers = 23, idle = 0, free_tasks = 77, batis = 2, open_sites = 0 }
  local s10b = Pe.new()
  Pe.decide(s10b, P109, {})
  Pe.decide(s10b, P109, {})
  want(s10b.closed, "IA-CAPI : 77 taches libres pour 23 PNJ : fermee")
  local P103 = { workers = 22, idle = 3, free_tasks = 30, batis = 2, open_sites = 0 }
  Pe.decide(s10b, P103, {})
  local r10b = Pe.decide(s10b, P103, chaine)
  want(not r10b.closed and #r10b.kept == 1, "IA-CAPI : 30 taches libres pour 22 PNJ (sortie 46) : rouverte, la rangee passe")
  -- entre les deux seuils (60 tâches : sortie 46, entrée 68) : ni tendu ni détendu, l'état reste (hystérésis sur les tâches)
  local s10c = Pe.new()
  Pe.decide(s10c, P109, {})
  Pe.decide(s10c, P109, {})
  local mid22 = { workers = 22, idle = 0, free_tasks = 60, batis = 2, open_sites = 0 }
  Pe.decide(s10c, mid22, {})
  Pe.decide(s10c, mid22, {})
  want(s10c.closed, "IA-CAPI : 60 taches libres pour 22 PNJ (entre 46 et 68) : reste fermee")
  -- seuil strict (minute 107 : 71 tâches pour un seuil de 71) : pas tendu
  want(Pe.measure({ workers = 23, idle = 0, free_tasks = 71 }) == false, "IA-CAPI : 71 taches au seuil de 71 : pas tendu")
  return bad
end

local Pe = require("shared.ai3.portes_extension")
local bad = suite(Pe)
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "suite du module")
print(string.format("[L6] suite : %d defaut(s)", #bad))
-- Fait relevé (pas une règle) : avec la vraie pile, chaque sorte d'ordre de la capitalisation est de rang 3 (Pi.order_family rend
-- « capi » ou « recherche ») : l'invariant I2 (R0 et R1 jamais retenus) est donc VIDE pour la capitalisation : aucun ordre R0 ou R1 n'y passe.
do
  local Pi = require("shared.ai3.pile")
  local all3 = true
  for _, k in ipairs({ "couvrir", "ouvrir", "chaine", "packs", "labos", "fours", "energie", "equiper", "techno" }) do
    if (Pi.FAMILY_RANK[Pi.order_family(k)] or 3) ~= 3 then all3 = false end
  end
  print("[L6] fait : toutes les sortes d'ordres de la capitalisation sont de rang 3 avec la vraie pile : " .. tostring(all3))
  check(all3, "fait releve : ordres de la capitalisation au rang 3 (I2 vide pour elle)")
end

local MUTANTS = {
  { "racine ignoree (porte du transport pour tous)", "elseif g.closed and o.tours and not o.belt and not o.root then", "elseif g.closed and o.tours and not o.belt then" },
  { "racine : tout ordre a tournees est racine", "local root = type(root_n) == \"number\" and root_n > 0 and not research", "local root = true and not research" },
  { "racine : manque nul compte", "local root = type(root_n) == \"number\" and root_n > 0 and not research", "local root = type(root_n) == \"number\" and not research" },
  { "racine : la recherche peut etre racine", "local root = type(root_n) == \"number\" and root_n > 0 and not research", "local root = type(root_n) == \"number\" and root_n > 0" },
  { "racine : journal oublie", "if p.root and g.closed and p.tours and not p.belt and p.rank > Pe.SAFE_RANK then", "if false then" },
  { "porte du transport retiree", "elseif g.closed and o.tours and not o.belt and not o.root then", "elseif false then" },
  { "tapis non exempte", "elseif g.closed and o.tours and not o.belt and not o.root then", "elseif g.closed and o.tours and not o.root then" },
  { "seuil fixe au lieu du seuil qui suit l'effectif", "local y = Pe.BACKLOG_PER * w + Pe.BACKLOG_BASE", "local y = 8" },
  { "bras : seuil fixe (sans les modules)", "local limit = math.floor(math.max(0, b) / Pe.MODULES_PER_SITE) + 1", "local limit = 1" },
  { "R0 et R1 retenus (I2 rompu)", "if rank > Pe.SAFE_RANK then\n", "if true then\n" },
  { "petites marches retirees", "and (g.tense or o.measured) and", "and false and" },
  { "anti-repetition retiree", "elseif o.measured and o.item ~= nil and o.item == g.last_item and not o.alone then", "elseif false then" },
  { "sans hysteresis (rouvre des que non tendu)", "st.calm_n = calm and (st.calm_n or 0) + 1 or 0", "st.calm_n = (not tense) and 99 or 0" },
  { "mesure absente = porte ouverte", "return true, cause -- garde fermée", "return false, cause -- garde fermée" },
  { "fermee des la 1re mesure tendue", "if st.tense_n >= Pe.SAT_THINKS then", "if st.tense_n >= 1 then" },
  { "places de chantier non decomptees (I1 rompu)", "if o.site and rank > Pe.SAFE_RANK then g.room = g.room - 1 end", "" },
  { "anti-repetition sans memoire d'une decision a l'autre", "function Pe.finish(st, g) st.last_item = g.measured_item end", "function Pe.finish(st, g) end" },
  { "traduction : rang 3 pour tous", "rank = (fam ~= nil and (ctx.family_rank or {})[fam]) or 3,", "rank = 3," },
  { "traduction : chantier ignore", "local site = (ctx.site_kinds or {})[o.kind] == true", "local site = false" },
  { "recherche : coupure explicite retiree", "if g.closed and o.research and not o.belt then", "if false then" },
  { "recherche : sortes d'ordres oubliees", "Pe.RESEARCH_KINDS = { packs = true, labos = true }", "Pe.RESEARCH_KINDS = {}" },
  { "recherche : labos oublies", "Pe.RESEARCH_KINDS = { packs = true, labos = true }", "Pe.RESEARCH_KINDS = { packs = true }" },
  { "traduction : tournees ignorees", "tours = research or (ctx.tours_kinds or {})[o.kind] == true", "tours = research" },
  { "traduction : manque mesure ignore", "local measured = item ~= nil and ((ctx.measured or {})[item] or 0) > 0", "local measured = false" },
  { "traduction : seul toujours vrai", "alone = measured and (ctx.measured_n or 0) == 1, research = research }", "alone = measured, research = research }" },
  -- Lot IA-CAPI : la tension ne lit que les tâches qui attendent.
  { "IA-CAPI : PNJ libres a nouveau dans la tension", "local tense = free > y", "local tense = idle * 1000 < w * 100 or free > y" },
  { "IA-CAPI : PNJ libres seuls (taches ignorees)", "local tense = free > y", "local tense = idle * 1000 < w * 100" },
  { "IA-CAPI : 20 % de PNJ libres exiges pour rouvrir", "local calm = free <= y_exit", "local calm = idle * 1000 >= w * 200 and free <= y_exit" },
  { "IA-CAPI : sortie au seuil d'entree (sans hysteresis)", "local calm = free <= y_exit", "local calm = free <= y" },
  { "IA-CAPI : seuil de sortie fixe", "local y_exit = Pe.BACKLOG_EXIT_PER * w + Pe.BACKLOG_BASE", "local y_exit = 8" },
  { "IA-CAPI : tendu au seuil", "local tense = free > y", "local tense = free >= y" },
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
    if killed then refused = refused + 1 else print("[L6] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[L6] mutants refuses : %d sur %d", refused, #MUTANTS))

-- Coût en INSTRUCTIONS.
local function instr(fn, n)
  local worst = 0
  for _ = 1, n do
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    fn()
    debug.sethook()
    if c > worst then worst = c end
  end
  return worst
end
local function orders_n(k)
  local l = {}
  for i = 1, k do l[i] = ord("o" .. i, { item = "i" .. (i % 7), n = 3, tours = i % 2 == 0, site = i % 3 == 0, measured = i % 4 == 0 }) end
  return l
end
local o8, o40 = orders_n(8), orders_n(40)
local st = Pe.new()
local a = { workers = 12, idle = 2, free_tasks = 20, batis = 60, open_sites = 1 }
local w0 = instr(function() Pe.transport(st, a) end, 50)
local w8 = instr(function() Pe.decide(st, a, o8) end, 50)
local w40 = instr(function() Pe.decide(st, a, o40) end, 20)
print(string.format("[L6] cout : mesure %d instructions ; decision a 8 ordres %d ; a 40 ordres %d (sethook, compte de 1)", w0, w8, w40))
check(w0 <= 300 and w8 <= 3000 and w40 <= 12000, "cout borne (mesure <= 300, 8 ordres <= 3 000, 40 ordres <= 12 000)")
check(w40 - w8 <= 6 * (w8 - w0) + 1000, "cout lineaire en nombre d'ordres")

print(string.format("[L6] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
