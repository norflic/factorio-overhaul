--[[
  Lot IA-G « le cerveau général » : test hors jeu (shared/ai3/catalogue.lua, shared/ai3/general.lua) sur les DONNÉES
  RÉELLES (fixtures : recettes vanilla + mod, technologies FINALES, machines ; relevé de tests/iag_fixture.lua).

    §1 catalogue : tout est DÉDUIT du relevé (packs = entrées des laboratoires, combustible, main, exécutants) ;
    §2 choix de recherche depuis le kit de départ : payable, valeur, coût, chaîne des pourquoi ; déterminisme (données
       dans l'ordre inverse : même décision) ;
    §3 ressources clés sur les données vanilla : exactement ce que l'échelle avait écrit à la main (R.FALLBACK_KEY) ;
    §4 règle H8 : ressource inconnue -> rien de payable, cause et exploration ;
    §5 inertie et suite des choix (une technologie faite ouvre les suivantes) ;
    §6 GÉNÉRALISATION : le MÊME code sur des DONNÉES CHANGÉES (engrenage au cuivre, pack rouge à la brique, prérequis
       changé, laboratoire changé) déplie autrement ;
    §7 mutants : chaque règle cassée est vue par au moins un contrôle ;
    §8 ANTI-ÉCHELLE : les fichiers de décision (shared/ai3/*.lua sauf reglages.lua, script/ai3/general.lua) ne nomment
       aucun objet, bâtiment, ressource ni technologie du jeu (entre guillemets ou comme identifiant) ;
    §9 coût de calcul (ordre de grandeur, PC non épinglé).
  Usage : lua5.2 tests/iag_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local K = require("shared.ai3.catalogue")
local Gen = require("shared.ai3.general")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[IAG] ECHEC : " .. msg) end
  end
end
local function say(s) if not quiet then print("[IAG] " .. s) end end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function kind_of(res)
  for _, k in ipairs(T.OUTPOST_ORDER) do if T.outposts[k].resource == res then return k end end
  return nil
end

--- Buts de référence d'une faction (ceux du runtime, script/ai3/general.lua) : la recherche choisie, le premier lot de
--- soldats (équipement de l'armée), la réserve de munitions.
local function ref_goals(tech)
  local goals = {}
  if tech then goals[#goals + 1] = { tech = tech } end
  for _, it in ipairs(T.kits.rifleman) do goals[#goals + 1] = { item = it[1], n = it[2] * 10 } end
  goals[#goals + 1] = { item = T.turret_ammo, n = 60 }
  return goals
end

--- État sans le stock CONSOMMABLE (seulement les machines et bâtiments durables) : besoin brut des buts.
local function durable_state(cat, st)
  local stock = {}
  for _, k in ipairs(sorted_keys(st.stock)) do if cat.g.machine[k] or cat.role[k] then stock[k] = st.stock[k] end end
  return { stock = stock, techs = st.techs, built = st.built, known = st.known }
end

local function key_of(cat, st, tech)
  local ds = durable_state(cat, st)
  local ev = Gen.prepare(cat, ds)
  local sum = Gen.summary(cat, ev, ds, ref_goals(tech))
  return Gen.key_resources(cat, sum, T.OUTPOST_ORDER, kind_of), sum
end

local function decide(cat, st, ctx)
  local ev = Gen.prepare(cat, st)
  local d = Gen.choose(cat, ev, st, ctx or {})
  local sum = d.tech and Gen.summary(cat, ev, st, { { tech = d.tech } }) or nil
  return d, sum, ev
end

local function run_all()
  -- §1 Catalogue.
  local cat = K.build(F.dump(), F.opts())
  check(#cat.pack_list == 7, "§1 packs = entrées du laboratoire (" .. #cat.pack_list .. ")")
  check(cat.fuel ~= nil and cat.role[cat.fuel] == nil and kind_of(cat.fuel) ~= nil, "§1 combustible déduit : " .. tostring(cat.fuel))
  check(cat.spec.hand_categories ~= nil and next(cat.spec.hand_categories) ~= nil, "§1 catégories de la main lues")
  local nm = {}
  for _, m in ipairs(cat.g.machine_list) do nm[#nm + 1] = m end
  check(#nm == 4, "§1 machines exécutables : main, fours du QG, foreuses, laboratoire (" .. table.concat(nm, " ") .. ")")
  local adv = 0
  for _, r in ipairs(cat.g.recipe_list) do
    local c = cat.g.recipes[r].category
    if not cat.spec.hand_categories[c] and not cat.g.by_category[c] then adv = adv + 1 end
  end
  check(adv == 0, "§1 aucune recette d'une catégorie sans exécutant (" .. adv .. ")")
  local n_mil, n_mach = 0, 0
  for _, k in ipairs(sorted_keys(cat.role)) do
    if cat.role[k] == "militaire" then n_mil = n_mil + 1 elseif cat.role[k] == "machine" then n_mach = n_mach + 1 end
  end
  check(n_mil >= 10 and n_mach >= 10, "§1 rôles des objets lus aux types (" .. n_mil .. " militaires, " .. n_mach .. " machines)")
  local d_h = F.dump({ mutate = function(d)
    d.techs["iag-verrou"] = { count = 1, time = 1, ingredients = {}, prerequisites = {}, unlocks = { "iron-chest" }, hidden = true, enabled = false }
  end })
  check(K.build(d_h, F.opts()).techs["iag-verrou"] == nil, "§1 technologie invisible (verrou d'époque) hors du graphe")
  -- Un combustible plus riche qu'aucun exécutant ne sait extraire (moteur réel, banc g1 : le cristal de résonance de
  -- l'âge 7) n'est pas le combustible ; un combustible plus riche sans avant-poste n'est pas la ressource clé.
  local d_f = F.dump({ mutate = function(d)
    d.resources[#d.resources + 1] = { entity = "iag-cristal", category = "iag-dur", products = { { type = "item", name = "iag-cristal", amount = 1 } } }
    d.items["iag-cristal"] = { type = "item", fuel_value = 50e6 }
    d.resources[#d.resources + 1] = { entity = "iag-tourbe", category = "basic-solid", products = { { type = "item", name = "iag-tourbe", amount = 1 } } }
    d.items["iag-tourbe"] = { type = "item", fuel_value = 20e6 }
  end })
  local cat_f = K.build(d_f, F.opts())
  check(cat_f.fuel == T.fuel, "§1 combustible : extractible ET rapporté par un avant-poste (" .. tostring(cat_f.fuel) .. ")")
  local o_nf = F.opts()
  o_nf.fuel_ok = nil
  local cat_nf = K.build(d_f, o_nf)
  check(cat_nf.fuel == "iag-tourbe", "§1 combustible sans condition d'avant-poste : le plus riche extractible (" .. tostring(cat_nf.fuel) .. ")")
  local key_f = Gen.key_resources(cat_f, { extract = {} }, T.OUTPOST_ORDER, kind_of)
  check(key_f.fuel == "coal", "§1 combustible clé : le meilleur qu'un avant-poste rapporte (" .. tostring(key_f.fuel) .. ")")

  -- §2 Choix depuis le kit de départ.
  local st = F.start_state()
  local d, sum, ev = decide(cat, st)
  check(d.tech ~= nil, "§2 une technologie choisie : " .. tostring(d.tech))
  check(d.tech and ev.tfeas[d.tech] == true, "§2 la technologie choisie est payable (graphe)")
  check(d.value and d.value > 0 and d.cost and d.cost > 0 and d.score > 0, "§2 valeur, coût, score")
  check(sum and sum.build[cat.labs[1].item] == 1, "§2 dépliage : un laboratoire à construire (aucun au départ)")
  check(sum and #sum.research >= 1 and sum.research[#sum.research] == d.tech, "§2 dépliage : la recherche en dernier")
  local d_ok = true
  for _, p in ipairs(cat.techs[d.tech].prerequisites) do if not st.techs[p] then d_ok = false end end
  check(d_ok, "§2 prérequis faits")
  say("§2 départ : " .. tostring(d.tech) .. " valeur " .. tostring(d.value) .. " coût " .. tostring(d.cost) .. " ; " .. Gen.why_text(d, sum))
  -- Lot KIT : depuis le kit RÉEL (coffre vide, aucun four), le même cerveau choisit une technologie payable, déplie un
  -- laboratoire et la recherche en dernier.
  local st_egal = F.start_state({ kit = "egal" })
  local d_e, sum_e = decide(cat, st_egal)
  check(next(st_egal.stock) == nil and st_egal.built[T.SMELTER] == 0, "§2 kit réel : coffre vide, aucun four")
  check(d_e.tech ~= nil and sum_e and sum_e.build[cat.labs[1].item] == 1 and sum_e.research[#sum_e.research] == d_e.tech,
    "§2 kit réel : une technologie choisie (" .. tostring(d_e.tech) .. "), laboratoire à construire, recherche en dernier")
  local cat_r = K.build(F.dump({ reverse = true }), F.opts())
  local d_r = decide(cat_r, F.start_state())
  check(d_r.tech == d.tech and d_r.score == d.score, "§2 déterminisme : données dans l'ordre inverse, même décision")
  -- Le caractère pondère : un conquérant (armée × 2) et un technocrate (recherche × 2) ne choisissent pas pareil.
  local d_army = decide(cat, st, { weights = { armee = 2000, recherche = 500, capital = 1000 } })
  local d_tech = decide(cat, st, { weights = { armee = 500, recherche = 2000, capital = 1000 } })
  check(d_army.tech ~= d_tech.tech, "§2 le caractère pondère le choix (armée : " .. tostring(d_army.tech) .. ", recherche : " .. tostring(d_tech.tech) .. ")")
  check(cat.role[(d_army.why[1] or {})[2] or ""] == "militaire", "§2 le conquérant choisit une technologie militaire")
  -- Valeur propre (H9) : une technologie prête qui ouvre un pack fabricable vaut au moins 100 (constante littérale : le
  -- mutant « packs à 0 » doit être vu) ; un objet sans source (bois) ne vaut qu'un quart (40 + 40/4 + 40 = 90).
  local best_pack = 0
  for _, t in ipairs(Gen.ready(cat, st)) do
    local v, _, pal = Gen.value(cat, ev, st, t, {})
    if pal and v > best_pack then best_pack = v end
  end
  check(best_pack >= 100, "§2 une technologie qui ouvre un pack vaut au moins 100 (" .. best_pack .. ")")
  local v_mil, why_mil = Gen.value(cat, ev, st, "military", {})
  local later = 0
  for _, w in ipairs(why_mil) do if w[1]:find("plus tard", 1, true) then later = later + 1 end end
  check(v_mil == 90 and later == 1, "§2 objet sans source (bois) compté au quart : valeur " .. v_mil .. ", " .. later .. " « plus tard »")

  -- §3 Ressources clés sur les données vanilla = ce que l'échelle avait écrit à la main.
  local key = key_of(cat, st, d.tech)
  local fb = R.FALLBACK_KEY
  check(key.top == fb.top and key.fuel == fb.fuel, "§3 ressource la plus demandée et combustible : " .. tostring(key.top) .. ", " .. tostring(key.fuel))
  check(table.concat(key.order, ",") == table.concat(fb.order, ","), "§3 ordre des avant-postes : " .. table.concat(key.order, ","))
  check(table.concat(sorted_keys(key.optional), ",") == table.concat(sorted_keys(fb.optional), ","),
    "§3 sans besoin au départ : " .. table.concat(sorted_keys(key.optional), ","))
  say(string.format("§3 besoins bruts (vanilla) : %s", Gen.fmt_map(key.need)))

  -- §4 H8 : ressource inconnue.
  local st_u = F.start_state({ unknown = { T.outposts.copper.resource } })
  st_u.stock[T.outposts.copper.product] = nil
  local d_u, _, ev_u = decide(cat, st_u)
  check(d_u.tech == nil, "§4 sans cuivre connu ni en stock, aucune recherche payable (" .. tostring(d_u.tech) .. ")")
  check(#d_u.blocked > 0, "§4 technologies de valeur bloquées listées")
  local sum_u = Gen.summary(cat, ev_u, st_u, { { tech = d_u.blocked[1] and d_u.blocked[1].tech } })
  local explores = table.concat(sum_u.explore, ",")
  check(explores:find(T.outposts.copper.resource, 1, true) ~= nil, "§4 exploration demandée : " .. explores)
  check(next(sum_u.hand) == nil and next(sum_u.build) == nil, "§4 H8 : rien fabriqué ni construit pour une recherche impayable")
  -- §4 bis Ce que rapporterait chaque ressource inconnue : le cuivre rouvre la recherche, l'uranium (centrifugeuse sans
  -- exécutant) ne rapporte rien aujourd'hui.
  local rv = Gen.resource_values(cat, ev_u, st_u, {})
  local by = {}
  for _, e in ipairs(rv) do by[e[1]] = e end
  local cu_res = T.outposts.copper.resource
  check(rv[1] and rv[1][1] == cu_res and rv[1][2] > 0 and #rv[1][3] > 0,
    "§4 bis le cuivre inconnu est la ressource qui rapporte le plus (" .. tostring(rv[1] and rv[1][1]) .. " " .. tostring(rv[1] and rv[1][2]) .. ")")
  check(by["uranium-ore"] and by["uranium-ore"][2] == 0, "§4 bis l'uranium ne rapporte rien aujourd'hui (pas d'exécutant de sa chaîne)")
  check(by["crude-oil"] == nil, "§4 bis le pétrole n'est pas candidat (aucun exécutant ne l'extrait)")
  say("§4 bis ressources inconnues : " .. (function() local t = {} for _, e in ipairs(rv) do t[#t + 1] = e[1] .. " " .. e[2] end return table.concat(t, ", ") end)())

  -- §5 Inertie, suite des choix.
  local second = d.ranked[2] and d.ranked[2][1]
  local d_in = decide(cat, st, { current = second })
  local gap = d.ranked[2] and d.ranked[1][2] * 100 / math.max(1, d.ranked[2][2]) or 999
  check(gap > 120 or d_in.tech == second, "§5 inertie : la technologie en cours garde + 20 % (écart " .. math.floor(gap) .. " %)")
  local st2 = F.start_state({ techs = { [d.tech] = true } })
  st2.built[cat.labs[1].item] = 1
  local d2 = decide(cat, st2)
  check(d2.tech ~= nil and d2.tech ~= d.tech, "§5 la technologie faite n'est plus candidate ; suivante : " .. tostring(d2.tech))
  local seq, sst = {}, F.start_state()
  sst.built[cat.labs[1].item] = 1
  for _ = 1, 8 do
    local dd = decide(cat, sst)
    if not dd.tech then break end
    seq[#seq + 1] = dd.tech
    sst.techs[dd.tech] = true
  end
  say("§5 suite des choix (vanilla, laboratoire posé) : " .. table.concat(seq, " > "))
  local p3 = false
  for _, t in ipairs(seq) do for _, r in ipairs(cat.techs[t].unlocks) do
    for _, p in ipairs(cat.products[r] or {}) do if cat.role[p] == "pack" and p ~= cat.pack_list[1] then p3 = true end end
  end end
  check(#seq == 8 and p3, "§5 huit recherches de suite, dont une qui ouvre un pack")

  -- §6 GÉNÉRALISATION : même code, données changées.
  local function with(mut) return K.build(F.dump({ mutate = mut }), F.opts()) end
  -- a. L'engrenage demande aussi une plaque de cuivre.
  local cu = T.outposts.copper.product
  local cat_a = with(function(dd)
    local g = dd.recipes["iron-gear-wheel"]
    g.ingredients[#g.ingredients + 1] = { type = "item", name = cu, amount = 1 }
  end)
  local key_a = key_of(cat_a, F.start_state(), d.tech)
  check(key_a.need.copper > key.need.copper, string.format("§6a engrenage au cuivre : besoin de cuivre %d -> %d", key.need.copper, key_a.need.copper))
  say(string.format("§6a besoins bruts : vanilla %s ; engrenage au cuivre %s ; ordre %s", Gen.fmt_map(key.need), Gen.fmt_map(key_a.need), table.concat(key_a.order, ",")))
  -- b. Le pack rouge demande une brique au lieu du cuivre (une ressource nécessaire plus tôt).
  local cat_b = with(function(dd)
    local r = dd.recipes["automation-science-pack"]
    for _, i in ipairs(r.ingredients) do if i.name == cu then i.name = "stone-brick" end end
  end)
  local key_b, sum_b = key_of(cat_b, F.start_state(), d.tech)
  check(not key_b.optional.stone and key_b.need.stone > 0, "§6b pack rouge à la brique : la pierre devient nécessaire (" .. tostring(key_b.need.stone) .. ")")
  check((sum_b.produce["stone-brick"] or 0) > 0, "§6b dépliage : briques produites par une machine (four du QG)")
  say(string.format("§6b besoins bruts : %s ; ordre %s ; sans besoin [%s]", Gen.fmt_map(key_b.need), table.concat(key_b.order, ","), table.concat(sorted_keys(key_b.optional), ",")))
  -- c. Un prérequis change : le pack vert exige désormais la recherche des murs.
  local cat_c = with(function(dd)
    local t = dd.techs["logistic-science-pack"]
    t.prerequisites[#t.prerequisites + 1] = "stone-wall"
  end)
  local d_c = decide(cat_c, F.start_state())
  local ev_c = Gen.prepare(cat_c, F.start_state())
  local ch_c = Gen.chains(cat_c, ev_c, F.start_state(), {})
  check(ch_c["stone-wall"] and ch_c["stone-wall"].target ~= nil, "§6c le prérequis nouveau hérite d'une chaîne vers un pack")
  check(d_c.tech ~= "logistic-science-pack", "§6c le pack vert n'est plus choisissable d'emblée ; choix : " .. tostring(d_c.tech))
  say("§6c prérequis changé : choix " .. tostring(d_c.tech) .. " (vanilla : " .. tostring(d.tech) .. ") ; " .. Gen.why_text(d_c))
  -- d. Le laboratoire demande des briques (fondues au four du QG, la pierre devient nécessaire avant toute recherche).
  local cat_d = with(function(dd)
    local r = dd.recipes["lab"]
    r.ingredients[#r.ingredients + 1] = { type = "item", name = "stone-brick", amount = 5 }
  end)
  local d_d, sum_d = decide(cat_d, F.start_state())
  check(d_d.tech ~= nil and sum_d and (sum_d.produce["stone-brick"] or 0) >= 5, "§6d laboratoire à la brique : briques produites au four ; choix " .. tostring(d_d.tech))
  -- d bis. Le laboratoire demande de l'acier, que seule une recherche débloque : aucune recherche possible (il faut un
  -- laboratoire pour rechercher l'acier) ; le graphe le voit (aucun choix), il ne fabrique rien pour rien.
  local cat_d2 = with(function(dd)
    local r = dd.recipes["lab"]
    r.ingredients[#r.ingredients + 1] = { type = "item", name = "steel-plate", amount = 5 }
  end)
  check(decide(cat_d2, F.start_state()).tech == nil, "§6d bis laboratoire à l'acier verrouillé : aucune recherche (impasse vue)")
  -- e. Aucune ligne de code de plus : les quatre variantes ont tourné sur les mêmes modules (vérifié par §8).
  check(true, "§6e mêmes modules pour les quatre variantes")
  -- f. Lot CHAÎNE : un CYCLE de recettes dans les données (la plaque de fer depuis l'engrenage, trois pour un, énergie 0 :
  -- le coût de choix préfère la boucle). Le dépliage finit de lui-même, sans fabriquer la plaque par la boucle.
  local function loop(from, to, n)
    return { category = "crafting", energy = 0, hidden = false, enabled = true,
      ingredients = { { type = "item", name = from, amount = 1 } }, products = { { type = "item", name = to, amount = n } } }
  end
  local _, sum_v = key_of(cat, F.start_state(), d.tech)
  local cat_f = with(function(dd) dd.recipes["ia-chaine-plaque"] = loop("iron-gear-wheel", "iron-plate", 3) end)
  local key_f, sum_f = key_of(cat_f, F.start_state(), d.tech)
  check(not sum_f.truncated and sum_f.nodes <= sum_v.nodes * 2 + 10 and (sum_f.hand["iron-plate"] or 0) == 0,
    "§6f cycle plaque <-> engrenage : dépliage fini (" .. sum_f.nodes .. " noeuds contre " .. sum_v.nodes .. "), plaque jamais fabriquée par la boucle")
  check(table.concat(key_f.order, ",") == table.concat(key.order, ","), "§6f le cycle ne change pas l'ordre des avant-postes")
  -- g. Tous les gisements d'une ressource interdits (le combustible : la foreuse le brûle aussi) : fini, aucune cause en
  -- « ?<machine> », aucune boucle (une autre voie, le bois, peut encore rendre le but payable).
  local coal = T.fuel
  local st_g = F.start_state({ unknown = { coal } })
  st_g.stock[coal] = nil
  local d_g, _, ev_g = decide(cat, st_g)
  local sum_g = Gen.summary(cat, ev_g, st_g, ref_goals(d.tech))
  local qmark = false
  for _, c in ipairs(sum_g.causes) do if c:sub(1, 1) == "?" then qmark = true end end
  for _, b in ipairs(d_g.blocked) do
    local sg = Gen.summary(cat, ev_g, st_g, { { tech = b.tech } })
    for _, c in ipairs(sg.causes) do if c:sub(1, 1) == "?" then qmark = true end end
  end
  check(not sum_g.truncated and not qmark and sum_g.nodes < 400, "§6g combustible sans gisement : fini (" .. sum_g.nodes .. " noeuds), aucune cause en « ?<machine> »")
  -- h. Trois recettes circulaires (x <- y <- z <- x, trois pour un, énergie 0), une seule entrée (z depuis la plaque de
  -- fer), et l'engrenage exige x : le coût de choix préfère la boucle à l'entrée.
  local cat_h = with(function(dd)
    dd.recipes["ia-chaine-1"] = loop("ia-y", "ia-x", 3)
    dd.recipes["ia-chaine-2"] = loop("ia-z", "ia-y", 3)
    dd.recipes["ia-chaine-3"] = loop("ia-x", "ia-z", 3)
    dd.recipes["ia-entree"] = loop("iron-plate", "ia-z", 1)
    local g = dd.recipes["iron-gear-wheel"]
    g.ingredients[#g.ingredients + 1] = { type = "item", name = "ia-x", amount = 1 }
  end)
  local _, sum_h = key_of(cat_h, F.start_state(), d.tech)
  check(not sum_h.truncated and sum_h.nodes <= sum_v.nodes * 2 + 20 and (sum_h.hand["ia-x"] or 0) > 0,
    "§6h trois recettes circulaires : dépliage fini (" .. sum_h.nodes .. " noeuds), l'objet est obtenu par l'entrée")

  -- §7 Ressource connue plus tard : un gisement découvert rend payable ce qui ne l'était pas.
  local st_k = F.start_state({ unknown = { T.outposts.copper.resource } })
  st_k.stock[cu] = nil
  local d_k1 = decide(cat, st_k)
  st_k.known[T.outposts.copper.resource] = true
  local d_k2 = decide(cat, st_k)
  check(d_k1.tech == nil and d_k2.tech ~= nil, "§7 gisement découvert : la recherche redevient payable (" .. tostring(d_k2.tech) .. ")")
end

-- Exécution normale.
run_all()
local base_pass, base_fail = pass, fail

-- §7 bis Mutants : chaque règle cassée doit faire échouer au moins un contrôle.
local function mutant(name, apply, restore)
  local p0, f0 = pass, fail
  quiet = true
  local ok, err = pcall(function()
    apply()
    run_all()
  end)
  restore()
  quiet = false
  local caught = (fail - f0) > 0 or not ok
  pass, fail = p0, f0
  check(caught, "mutant refusé : " .. name .. (ok and "" or (" (plantage : " .. tostring(err) .. ")")))
  return caught
end
local n_mut, n_caught = 0, 0
local function M(name, apply, restore)
  n_mut = n_mut + 1
  if mutant(name, apply, restore) then n_caught = n_caught + 1 end
end
do
  local v0 = Gen.V_PACK
  M("valeur des packs nulle", function() Gen.V_PACK = 0 end, function() Gen.V_PACK = v0 end)
  local ch0 = Gen.chains
  M("pas de chaînes vers les packs", function() Gen.chains = function() return {} end end, function() Gen.chains = ch0 end)
  local choose0 = Gen.choose
  M("payabilité ignorée (H8)", function()
    Gen.choose = function(cat, ev, state, ctx)
      local fake = setmetatable({ tfeas = setmetatable({}, { __index = function() return true end }) }, { __index = ev })
      return choose0(cat, fake, state, ctx)
    end
  end, function() Gen.choose = choose0 end)
  local kr0 = Gen.key_resources
  M("ressources clés par ordre alphabétique", function()
    Gen.key_resources = function(cat, sum, kinds, kind_of)
      local k = kr0(cat, sum, kinds, kind_of)
      table.sort(k.order)
      k.top = k.order[1]
      return k
    end
  end, function() Gen.key_resources = kr0 end)
  local build0 = K.build
  M("exécutants ignorés (toutes les machines)", function()
    K.build = function(dump, opts) local o = {} for k, v in pairs(opts or {}) do o[k] = v end o.exec = nil return build0(dump, o) end
  end, function() K.build = build0 end)
  M("technologies invisibles gardées", function()
    K.build = function(dump, opts)
      for _, t in pairs(dump.techs) do t.hidden = false t.enabled = true end
      return build0(dump, opts)
    end
  end, function() K.build = build0 end)
  local in0 = Gen.INERTIA_PCT
  M("inertie coupée", function() Gen.INERTIA_PCT = -50 end, function() Gen.INERTIA_PCT = in0 end)
  local ld0 = Gen.LATER_DIV
  M("objet impossible compté plein", function() Gen.LATER_DIV = 1 end, function() Gen.LATER_DIV = ld0 end)
  local cost0 = Gen.cost
  M("coût ignoré (valeur seule)", function() Gen.cost = function() return 0 end end, function() Gen.cost = cost0 end)
  local GR = require("shared.ai3.graphe")
  local mr0 = GR.MAX_RETRIES
  M("reprises après cycle interdites", function() GR.MAX_RETRIES = 0 end, function() GR.MAX_RETRIES = mr0 end)
  local md0 = GR.MAX_DEPTH
  M("profondeur maximale à 2", function() GR.MAX_DEPTH = 2 end, function() GR.MAX_DEPTH = md0 end)
end
check(n_caught == n_mut, string.format("mutants : %d refusés sur %d", n_caught, n_mut))

-- §8 ANTI-ÉCHELLE.
do
  local recipes = dofile("tests/fixtures/recipes_ia1e.lua")
  local techs = dofile("tests/fixtures/tech_ai3_final.lua")
  local ent = dofile("tests/fixtures/entities_ai3.lua")
  local names = {}
  for name, r in pairs(recipes) do
    names[name] = true
    for _, p in ipairs(r.products) do names[p.name] = true end
    for _, i in ipairs(r.ingredients) do names[i.name] = true end
  end
  for name, t in pairs(techs) do
    names[name] = true
    for _, i in ipairs(t.ingredients) do names[i[1]] = true end
  end
  for _, m in ipairs(ent.machines) do names[m.name] = true end
  for k in pairs(ent.resources) do names[k] = true end
  for _, it in ipairs(T.start_kit_generous) do names[it[1]] = true end
  -- Fichiers EXEMPTÉS, nommés et justifiés (demande de l'intégrateur, 27/10) :
  local EXEMPT = {
    ["shared/ai3/reglages.lua"] = "seules données nommées admises (types du moteur, réglages hérités, repli de votre équipe)",
    ["script/ai3/paliers.lua"] = "paliers de MESURE (§6.1) ; lus seulement par Ia3.measure (contrôlé plus bas)",
  }
  local files = {}
  local p = io.popen('ls shared/ai3/*.lua script/ai3/*.lua')
  for line in p:lines() do
    if not EXEMPT[line] then files[#files + 1] = line end
  end
  p:close()
  table.sort(files)
  for _, k in ipairs(sorted_keys(EXEMPT)) do print("[IAG] §8 exempté : " .. k .. " (" .. EXEMPT[k] .. ")") end
  -- Les paliers de mesure ne sont lus que par Ia3.measure (aucune décision ne les lit).
  do
    local f = assert(io.open("script/ai3/cerveau.lua", "rb"))
    local src = f:read("*a")
    f:close()
    local code = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
    local m0 = code:find("function Ia3.measure", 1, true)
    local m1 = m0 and code:find("\nfunction ", m0 + 1, true) or nil
    local outside = 0
    local pos = 1
    while true do
      local i = code:find("PALIERS", pos, true)
      if not i then break end
      local def = code:sub(math.max(1, i - 4), i + 20):find("Ia3.PALIERS = ", 1, true)
      if not def and not (m0 and i > m0 and (not m1 or i < m1)) then outside = outside + 1 end
      pos = i + 1
    end
    check(m0 ~= nil and outside == 0, "§8 paliers de mesure lus seulement par Ia3.measure (" .. outside .. " lecture(s) ailleurs)")
    local n_req = 0
    local pp = io.popen('grep -rl "script.ai3.paliers" script shared')
    for line in pp:lines() do if line ~= "script/ai3/paliers.lua" then n_req = n_req + 1 end end
    pp:close()
    check(n_req == 1, "§8 paliers requis par un seul fichier (" .. n_req .. ")")
  end
  -- Mots du vocabulaire GÉNÉRIQUE qui sont aussi des noms du jeu, admis seulement comme IDENTIFIANTS (jamais entre
  -- guillemets) : `lab` (champ « est un laboratoire » du format du graphe, shared/ai3/graphe.lua et fixtures), `water`
  -- (champ « eau vue » d'un regard, carte d'IA3-f).
  local VOCAB = { lab = true, water = true }
  -- TYPES DU MOTEUR (`LuaEntityPrototype.type`, API 1.1.91) qui sont aussi des noms de prototypes, admis entre guillemets
  -- ou comme identifiants (intégrateur, 27/10, à la fusion d'IA3-k) : la perception d'IA3-k classe ce qu'un PNJ voit par
  -- TYPE (`character` : un personnage ennemi ; `artillery-turret` : une tourelle, comme `ammo-turret` ; `gate` : le mot
  -- « porte » de la porte des tâches, identifiant seulement), jamais par nom ; même règle que R.ENTITY_ROLE de reglages.lua.
  local TYPES = { ["character"] = true, ["artillery-turret"] = true, ["gate"] = true }
  local total = 0
  for _ in pairs(names) do total = total + 1 end
  local bad = {}
  for _, file in ipairs(files) do
    local f = io.open(file, "rb")
    if f then
      local src = f:read("*a")
      f:close()
      -- Code sans commentaires (les identifiants) ; chaînes relevées à part.
      local code = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
      local strings = {}
      for s in code:gmatch('"([^"\n]*)"') do strings[s] = true end
      local bare = code:gsub('"[^"\n]*"', '""')
      local hits = {}
      for _, name in ipairs(sorted_keys(names)) do
        if TYPES[name] then -- type du moteur : vocabulaire admis
        elseif strings[name] then hits[#hits + 1] = '"' .. name .. '"'
        elseif not VOCAB[name] and name:match("^[%a_][%w_]*$") and bare:find("%f[%w_]" .. name .. "%f[^%w_]") then
          hits[#hits + 1] = name
        end
      end
      if #hits > 0 then bad[#bad + 1] = file .. " : " .. table.concat(hits, " ") end
      check(#hits == 0, "§8 anti-échelle : " .. file .. (#hits > 0 and (" nomme " .. table.concat(hits, " ")) or ""))
    else
      check(false, "§8 fichier introuvable : " .. file)
    end
  end
  print(string.format("[IAG] §8 anti-échelle : %d noms du jeu cherchés dans %d fichiers de décision, %d fichier(s) en défaut",
    total, #files, #bad))
  -- §8 bis (lot GENERAL, 28/10) : les dossiers de l'EXÉCUTANT et des factions (shared/team, script/team, shared/faction,
  -- script/faction, script/core, script/world, script/agents, script/gui, script/modules), que §8 ne couvrait pas. Ce sont
  -- des lignes qui nomment un objet du jeu entre guillemets. Trois sortes de fichiers :
  --   EXEC   : tables NOMMÉES de l'exécutant (ce que les PNJ savent poser, fabriquer, brûler : gabarits, empreintes,
  --            nom des pièces) : le nom y est la donnée, légitime ; plafond tout de même (rien ne s'y ajoute en silence) ;
  --   TYPE   : types du moteur ou masques de collision (`container`, `radar`, `water-tile`...), pas des noms de prototype ;
  --   DETTE  : décisions qui devraient lire T (shared/team/config.lua) ou le catalogue du cerveau (correctif proposé au
  --            rapport du lot) ; le plafond est l'état du 28/10 et ne peut que BAISSER.
  -- Tout autre fichier de ces dossiers : aucun nom. Une ligne en plus dans un fichier : ECHEC.
  local LEDGER = {
    ["shared/team/config.lua"] = { "EXEC", 41, "table nommée de l'exécutant (kit, avant-postes, fonte, munitions, pièces)" },
    ["shared/team/modules.lua"] = { "EXEC", 203, "gabarits de modules : catalogue d'usines posables, noms de leurs pièces" },
    ["shared/team/automatisation_donnees.lua"] = { "EXEC", 11, "données de l'exécutant d'IA3-e (machines et pièces posables)" },
    ["shared/team/plan.lua"] = { "EXEC", 12, "empreintes des pièces et pièces du plan (tapis, coffre, poteaux)" },
    ["script/team/build.lua"] = { "EXEC", 23, "construction : pièces posées (tapis, coffre, poteaux, bras)" },
    ["script/team/plant_arms.lua"] = { "EXEC", 1, "journal de la centrale : le fluide « vapeur » lu dans les chaudières (diagnostic)" },
    ["script/faction/vision.lua"] = { "TYPE", 2, "types du moteur (assembling-machine, furnace...)" },
    ["script/faction/journal.lua"] = { "TYPE", 2, "types du moteur (car, robots)" },
    ["script/modules/mult.lua"] = { "TYPE", 2, "types du moteur des machines à modules" },
    ["script/team/convoyeurs.lua"] = { "TYPE", 1, "type du moteur transport-belt (filtre des prototypes de tapis, lot CONVOYEURS)" },
    ["script/gui/team_window.lua"] = { "EXEC", 2, "coffre d'équipe : entité du mod" },
    ["shared/team/production.lua"] = { "DETTE", 16, "solveur de débits (lot IA1-e1) : machine par catégorie, matières brutes, recette par défaut du gaz : lire le catalogue du cerveau" },
    ["script/core/path_service.lua"] = { "TYPE", 1, "masque de collision d'eau" },
    ["shared/team/fond.lua"] = { "DETTE", 18, "cibles du travail de fond : lire T.outposts / T.start_kit" },
    ["shared/team/planner.lua"] = { "DETTE", 40, "table plaque -> avant-poste : déduire de T.outposts / T.smelter_inputs (comme manque.lua)" },
    ["shared/team/org.lua"] = { "DETTE", 2, "coût de recrue en plaques de fer : T.outposts.iron.product" },
    ["shared/team/scale.lua"] = { "DETTE", 1, "noms de pièces : T" },
    ["script/team/board.lua"] = { "DETTE", 2, "besoins de fonte : T.smelter_inputs" },
    ["script/team/poles.lua"] = { "DETTE", 6, "matières brutes et tourelles : T" },
    ["script/team/team.lua"] = { "DETTE", 4, "réserve de fer et objets clés : T" },
    ["script/team/worker.lua"] = { "DETTE", 6, "tourelle et munitions : T.turret / T.turret_ammo" },
    ["script/team/ia1_remote.lua"] = { "DETTE", 2, "relevé des matières produites : T.outposts" },
    ["script/team/player_team.lua"] = { "DETTE", 1, "coffre d'équipe (entité du mod)" },
    ["script/faction/chef.lua"] = { "DETTE", 1, "stocks du chef : T.outposts" },
    ["script/faction/outposts.lua"] = { "DETTE", 8, "tourelle et munitions des avant-postes : T" },
    ["script/faction/war.lua"] = { "DETTE", 3, "tourelles du QG et kit de départ : T" },
  }
  local function hit_lines(src, nameset)
    -- commentaires longs remplacés par autant de retours à la ligne : les numéros de ligne restent ceux du fichier
    local code = src:gsub("%-%-%[(=*)%[(.-)%]%1%]", function(_, body) return (body:gsub("[^" .. string.char(10) .. "]", "")) end)
    local n, found, ln = 0, {}, 0
    for line in (code .. string.char(10)):gmatch("([^" .. string.char(10) .. "]*)" .. string.char(10)) do
      ln = ln + 1
      -- commentaire de fin de ligne : retiré en suivant les guillemets (un "--" dans une chaîne reste)
      local quote, cut = nil, nil
      for i = 1, #line do
        local c = line:sub(i, i)
        if quote then
          if c == quote and line:sub(i - 1, i - 1) ~= "\\" then quote = nil end
        elseif c == '"' or c == "'" then quote = c
        elseif c == "-" and line:sub(i + 1, i + 1) == "-" then cut = i break end
      end
      if cut then line = line:sub(1, cut - 1) end
      for _, name in ipairs(sorted_keys(nameset)) do
        if not TYPES[name] and line:find('"' .. name .. '"', 1, true) then
          n = n + 1
          found[#found + 1] = string.format("ligne %d : %s (%s)", ln, name, (line:gsub("^%s+", "")):sub(1, 70))
          break
        end
      end
    end
    return n, found
  end
  local function culprits(found, n_ok)
    local out = {}
    for i = math.max(1, n_ok + 1), math.min(#found, n_ok + 6) do out[#out + 1] = "    " .. found[i] end
    return table.concat(out, string.char(10))
  end
  local NL = string.char(10)
  check(hit_lines('local a = "' .. T.turret_ammo .. '"' .. NL .. 'local b = 1', names) == 1
    and hit_lines('-- "' .. T.turret_ammo .. '"' .. NL .. 'local b = 1', names) == 0,
    "§8 bis témoin : une ligne qui nomme un objet est comptée, un commentaire non")
  local dirs = "shared/team script/team shared/faction script/faction script/core script/world script/agents script/gui script/modules"
  local pl = io.popen("ls " .. dirs:gsub("%S+", "%0/*.lua"))
  local extra, seen_ledger, debt = {}, {}, 0
  for line in pl:lines() do extra[#extra + 1] = line end
  pl:close()
  table.sort(extra)
  for _, file in ipairs(extra) do
    local f = io.open(file, "rb")
    local n, found = 0, {}
    if f then n, found = hit_lines(f:read("*a"), names) f:close() end
    local e = LEDGER[file]
    if e then
      seen_ledger[file] = true
      check(n <= e[2], string.format("§8 bis %s [%s] : %d ligne(s) nommant un objet du jeu, plafond %d (%s). Lire le nom dans T (shared/team/config.lua) ou le catalogue du cerveau, ou, si c'est une donnée nommée de l'exécutant, relever le plafond dans tests/iag_test.lua (LEDGER) en le justifiant. Lignes (les dernières du fichier sont les plus probables) : %s",
        file, e[1], n, e[2], e[3], NL .. culprits(found, e[2])))
      if n < e[2] then print(string.format("[IAG] §8 bis %s : %d ligne(s), plafond %d : à ABAISSER", file, n, e[2])) end
      if e[1] == "DETTE" then debt = debt + n end
    else
      check(n == 0, string.format("§8 bis %s : %d ligne(s) nomment un objet du jeu et le fichier n'est pas au registre. Lire le nom dans T (shared/team/config.lua) ou le catalogue du cerveau (docs/DETTE_NOMS.md), ou l'inscrire au LEDGER de tests/iag_test.lua avec sa catégorie (EXEC, TYPE, DETTE) et sa justification. Lignes : %s",
        file, n, NL .. culprits(found, 0)))
    end
  end
  for _, k in ipairs(sorted_keys(LEDGER)) do check(seen_ledger[k], "§8 bis fichier du registre introuvable : " .. k) end
  print(string.format("[IAG] §8 bis : %d fichiers de l'exécutant et des factions, dette de noms en dur dans les décisions : %d ligne(s)", #extra, debt))
  -- Le contrôle voit un nom : témoin positif.
  local probe = 'local x = "' .. T.turret_ammo .. '"'
  check(probe:find('"' .. T.turret_ammo .. '"', 1, true) ~= nil, "§8 témoin : un nom entre guillemets est vu")
end

-- §10 Le plus court d'abord (shared/ai3/projets.lua, P.update) : une recherche peu chère passe devant l'armée et la réserve.
do
  local P = require("shared.ai3.projets")
  local function order_of(short)
    local st = {}
    local goals = {
      { key = "extraction:a", family = "extraction", kind = "outpost", value = 92 },
      { key = "armee", family = "armee", kind = "army", value = 58, permanent = true },
      { key = "defense:munitions", family = "defense", kind = "stock", value = 55, permanent = true },
      { key = "recherche", family = "recherche", kind = "research", value = 70, short = short },
    }
    local out = P.update(st, goals, 0, 8)
    local keys = {}
    for _, p in ipairs(out) do keys[#keys + 1] = p.key end
    return table.concat(keys, ",")
  end
  local o1, o0 = order_of(true), order_of(nil)
  check(o1 == "extraction:a,recherche,armee,defense:munitions", "§10 recherche courte servie avant les familles permanentes : " .. o1)
  check(o0 == "extraction:a,armee,defense:munitions,recherche", "§10 sans le drapeau : ordre d'IA-V2 inchangé : " .. o0)
end

-- §11 Bras libres : profondeur d'avance, packs des recherches suivantes, extraction d'avance.
do
  check(Gen.ahead_depth(1, 8) == 0 and Gen.ahead_depth(1, 2) == 0, "§11 un seul PNJ sans tâche : rien d'avance")
  check(Gen.ahead_depth(2, 30) == 0, "§11 2 sans tâche sur 30 (7 %) : rien d'avance")
  -- Lot SCALE : le plafond suit l'effectif (shared/ai3/bras.lua, Br.depth_max : 3 jusqu'à 20 PNJ, 5 à 30).
  check(Gen.ahead_depth(2, 8) == 1 and Gen.ahead_depth(9, 30) == 3 and Gen.ahead_depth(20, 30) == 5
    and Gen.ahead_depth(20, 8) == 3,
    "§11 profondeur : 1 à 2 sur 8, 3 à 9 sur 30, plafond 3 à 8 PNJ et 5 à 30 (" .. Gen.ahead_depth(2, 8) .. ", "
    .. Gen.ahead_depth(9, 30) .. ", " .. Gen.ahead_depth(20, 30) .. ", " .. Gen.ahead_depth(20, 8) .. ")")
  check(Gen.spare_depth(100, 8, 8, 0) == 0, "§11 jamais à la première pensée (8 sur 8 sans tâche au départ : banc g5)")
  check(Gen.spare_depth(5, 8, 8, 6 * 3600) == 0, "§11 bras libres depuis moins d'une minute : rien")
  check(Gen.spare_depth(12, 8, 8, 6 * 3600) == 2, "§11 bras libres durables après 5 min : profondeur " .. Gen.spare_depth(12, 8, 8, 6 * 3600))
  local cat = K.build(F.dump(), F.opts())
  local st = F.start_state()
  local ev = Gen.prepare(cat, st)
  local d = Gen.choose(cat, ev, st, {})
  local nxt = {}
  for i = 2, #d.ranked do nxt[#nxt + 1] = d.ranked[i][1] end
  local la = Gen.lookahead(cat, ev, st, nxt, 2)
  local n = 0
  for _, it in ipairs(la) do n = n + it[2] end
  local expect = 0
  for i = 1, math.min(2, #nxt) do
    for _, ing in ipairs(cat.techs[nxt[i]].ingredients) do expect = expect + ing[2] * cat.techs[nxt[i]].count end
  end
  check(#la > 0 and n == expect, "§11 packs d'avance = ceux des 2 recherches suivantes (" .. n .. "/" .. expect .. ")")
  check(#Gen.lookahead(cat, ev, st, nxt, 0) == 0, "§11 profondeur 0 : aucun pack d'avance")
  local st_u = F.start_state({ unknown = { T.outposts.copper.resource } })
  st_u.stock[T.outposts.copper.product] = nil
  local ev_u = Gen.prepare(cat, st_u)
  check(#Gen.lookahead(cat, ev_u, st_u, nxt, 3) == 0, "§11 H8 : aucun pack d'avance pour une recherche impayable")
  -- Extraction d'avance (shared/ai3/buts.lua, B.targets).
  local B = require("shared.ai3.buts")
  local function sit(idle, tick, sat_top)
    return { key = R.FALLBACK_KEY, idle_grow = idle, tick = tick, cap = { iron = 2, coal = 2, copper = 1 },
      stock = { [T.outposts.iron.product] = sat_top and 10000 or 0 }, need = {} }
  end
  local stt = { targets = { iron = 2, coal = 2, copper = 1, stone = 0 }, iron2_set = true }
  B.targets(sit(true, 0, false), stt)
  check(stt.targets.iron == 3, "§11 bras libres : une capacité de plus pour la ressource la plus demandée (" .. stt.targets.iron .. ")")
  B.targets(sit(true, 60, false), stt)
  check(stt.targets.iron == 3, "§11 au plus une capacité toutes les 3 min")
  local stt2 = { targets = { iron = 2, coal = 2, copper = 1, stone = 0 }, iron2_set = true }
  B.targets(sit(true, 0, true), stt2)
  check(stt2.targets.iron == 2 and stt2.targets.copper == 2, "§11 produit saturé : la suivante dans l'ordre (cuivre)")
  local stt3 = { targets = { iron = 2, coal = 2, copper = 1, stone = 0 }, iron2_set = true }
  B.targets(sit(false, 0, false), stt3)
  check(stt3.targets.iron == 2 and stt3.targets.copper == 1, "§11 PNJ occupés : rien d'avance")
end

-- §9 Coût de calcul (ordre de grandeur).
do
  local t0 = os.clock()
  local cat
  for _ = 1, 5 do cat = K.build(F.dump(), F.opts()) end
  local t_cat = (os.clock() - t0) * 1000 / 5
  local st = F.start_state()
  t0 = os.clock()
  local ev
  for _ = 1, 10 do ev = Gen.prepare(cat, st) end
  local t_prep = (os.clock() - t0) * 1000 / 10
  t0 = os.clock()
  local d
  for _ = 1, 20 do d = Gen.choose(cat, ev, st, {}) end
  local t_choose = (os.clock() - t0) * 1000 / 20
  t0 = os.clock()
  for _ = 1, 20 do Gen.summary(cat, ev, st, ref_goals(d.tech)) end
  local t_sum = (os.clock() - t0) * 1000 / 20
  print(string.format("[IAG] §9 coût (ms, PC non épinglé) : catalogue %.1f, points fixes %.1f, choix %.2f, dépliage des buts %.2f",
    t_cat, t_prep, t_choose, t_sum))
  check(t_choose < 20 and t_sum < 20, "§9 choix et dépliage sous 20 ms hors jeu")
end

print(string.format("[IAG] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", pass, fail, n_caught, n_mut))
if fail > 0 then os.exit(1) end
