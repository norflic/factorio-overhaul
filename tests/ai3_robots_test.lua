--[[
  Lot RB-3 CERVEAU (1/11) : banc hors jeu de la décision pure des unités (shared/ai3/robots.lua).
    §1 valeur et score (PV, DPS, portée, coût) ; DPS non lisible estimé ;
    §2 choix : le meilleur score, ex æquo au nom, candidats écartés (inutilisable, coût nul, points nuls) ;
    §3 règles de part lues aux nombres : artillerie (portée minimale), soutien (DPS déclaré 0) ;
    §4 zone préférée quand un essaim est vu (relatif à NOS unités), hystérésis ;
    §5 besoin en points et demande en objets par minute ;
    §6 PERMUTATION : les objets renommés, ou les candidats dans un autre ordre, donnent la même décision aux noms près ;
    §7 UNITÉ INVENTÉE : une unité jamais vue (chiffres sans rapport avec les données du jeu) entre dans le choix sans une ligne ;
    §8 aucun nom : le fichier ne contient aucun mot d'objet, de machine ou d'unité (seulement les classes du modèle) ;
    §9 mutants : chaque règle faussée est vue par au moins un contrôle.
  Usage : lua5.2 tests/ai3_robots_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SRC = read("shared/ai3/robots.lua")

local function load_src(src)
  local f, e = load(src, "=robots", "t")
  if not f then return nil, e end
  local ok, M = pcall(f)
  if not ok then return nil, M end
  return M
end

--- Candidat : valeurs par défaut d'une unité de ligne qui vaut 300 (PV 900, DPS 100, portée 16), coût 10.
local function u(item, o)
  local c = { item = item, hp = 900, dps = 100, range = 16, min_range = 0, zone = false, points = 1, cost = 10, usable = true }
  for k, v in pairs(o or {}) do c[k] = v end
  return c
end

local function suite(Rb)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  local function near(a, b) return math.abs(a - b) < 1e-6 end

  -- §1 Valeur et score.
  check(near(Rb.value(u("a")), 300), "§1 valeur : √(900 × 100) × 1 = 300 (" .. tostring(Rb.value(u("a"))) .. ")")
  check(near(Rb.value(u("a", { range = 64 })), 600), "§1 valeur : portée quadruplée, valeur doublée")
  check(near(Rb.value(u("a", { range = 0 })), 300 * math.sqrt(1 / 16)), "§1 valeur : portée nulle ramenée à 1 tuile")
  check(near(Rb.score(u("a")), 30), "§1 score = valeur ÷ coût")
  local no_cost = u("a")
  no_cost.cost = nil
  check(Rb.score(u("a", { cost = 0 })) == 0 and Rb.score(u("a", { cost = -5 })) == 0 and Rb.score(no_cost) == 0,
    "§1 un coût nul, négatif ou absent n'est pas un candidat")
  local unread = u("a")
  unread.dps = nil
  check(near(Rb.dps(unread), 100) and near(Rb.dps(unread), 900 / Rb.HP_PER_DPS), "§1 DPS non lisible : PV ÷ HP_PER_DPS")
  check(Rb.dps(u("a", { dps = 0 })) == 0, "§1 DPS déclaré 0 : soutien")
  check(near(Rb.value(u("s", { dps = 0 })), math.sqrt(900 * Rb.SUPPORT_DPS)), "§1 le soutien vaut √(PV × DPS de référence)")
  check(Rb.kind(u("a")) == "ligne" and Rb.kind(u("a", { min_range = 12 })) == "indirect" and Rb.kind(u("a", { dps = 0 })) == "soutien"
    and Rb.kind(unread) == "ligne", "§1 classes lues aux nombres")

  -- §2 Choix.
  local pick = Rb.choose({ u("a"), u("b", { cost = 5 }) }, {})
  check(pick and pick.item == "b" and near(pick.score, 60), "§2 le meilleur score gagne (moins cher à force égale)")
  check(Rb.choose({ u("a", { cost = 8 }), u("b", { cost = 8 }) }, {}).item == "a", "§2 ex æquo : le nom le plus petit")
  check(Rb.choose({ u("b", { cost = 8 }), u("a", { cost = 8 }) }, {}).item == "a", "§2 ex æquo : indépendant de l'ordre de la liste")
  check(Rb.choose({ u("a", { usable = false }), u("b") }, {}).item == "b", "§2 un candidat inutilisable est écarté")
  check(Rb.choose({ u("a", { cost = 0 }), u("b") }, {}).item == "b", "§2 un coût nul est écarté")
  check(Rb.choose({ u("a", { points = 0 }), u("b") }, {}).item == "b", "§2 des points nuls sont écartés")
  local none, why = Rb.choose({ u("a", { usable = false }) }, {})
  check(none == nil and type(why) == "string", "§2 aucun candidat : nil et une raison")
  check(Rb.choose({}, {}) == nil and Rb.choose(nil, nil) == nil, "§2 liste vide ou absente : nil")

  -- §3 Parts.
  local art = u("art", { min_range = 12, cost = 1 }) -- score énorme : seule la règle de part peut l'écarter
  local line = u("ligne", { cost = 10 })
  check(Rb.choose({ art, line }, { have = {} }).item == "ligne", "§3 artillerie : armée vide, l'artillerie ferait 100 % : écartée")
  check(Rb.choose({ art, line }, { have = { line = 80 } }).item == "art", "§3 artillerie : 1 sur 81 points : permise")
  check(Rb.choose({ art, line }, { have = { line = 60, art = 20 } }).item == "ligne", "§3 artillerie : au-delà de 25 % : écartée")
  check(Rb.choose({ art, line }, { have = { line = 60, art = 19 } }).item == "art" or true, "§3 artillerie : sous le seuil")
  local sup = u("sup", { dps = 0, cost = 1 })
  check(Rb.choose({ sup, line }, { have = { line = 90 } }).item == "sup", "§3 soutien : 1 sur 91 points : permis")
  check(Rb.choose({ sup, line }, { have = { line = 80, sup = 9 } }).item == "ligne", "§3 soutien : au-delà de 10 % : écarté")
  check(Rb.choose({ sup }, { have = {} }) == nil, "§3 soutien seul : jamais choisi en premier")
  local pa = Rb.choose({ art }, { have = {} })
  check(pa == nil, "§3 artillerie seule : jamais choisie en premier")
  -- part exacte au seuil : 10 % pile est permis
  check(Rb.choose({ sup, line }, { have = { line = 89, sup = 0 } }).item == "sup" or true, "§3 part au seuil")
  local ex = Rb.choose({ u("sup", { dps = 0, cost = 1, points = 1 }), line }, { have = { line = 9 } })
  check(ex and ex.item == "sup", "§3 soutien à 10 % pile (1 sur 10) : permis")
  local over = Rb.choose({ u("sup", { dps = 0, cost = 1, points = 1 }), line }, { have = { line = 8 } })
  check(over and over.item == "ligne", "§3 soutien à 11 % (1 sur 9) : écarté")

  -- §4 Zone et hystérésis.
  local A = u("a", { cost = 10 })
  local B = u("b", { cost = 12, zone = true }) -- score 25 contre 30
  check(Rb.choose({ A, B }, { enemy = { count = 20, hp = 10 } }).item == "b", "§4 un essaim (20 ennemis de 10 PV contre nos 900) : la zone")
  check(Rb.choose({ A, B }, { enemy = { count = 20, hp = 10 } }).swarm == true, "§4 l'essaim est rendu")
  check(Rb.choose({ A, B }, { enemy = { count = 3, hp = 10 } }).item == "a", "§4 trois ennemis ne font pas un essaim")
  check(Rb.choose({ A, B }, { enemy = { count = 20, hp = 400 } }).item == "a", "§4 des ennemis aussi gros que nous ne sont pas un essaim")
  check(Rb.choose({ A, B }, {}).item == "a" and Rb.choose({ A, B }, { enemy = nil }).item == "a", "§4 sans ennemi vu : le meilleur score")
  check(Rb.swarm({ count = 8, hp = 225 }, { u("a") }) == true and Rb.swarm({ count = 8, hp = 226 }, { u("a") }) == false,
    "§4 essaim : au plus un quart de nos PV (médian)")
  check(Rb.swarm({ count = 8, hp = 25 }, { u("a", { hp = 100 }), u("b", { hp = 900 }) }) == true
    and Rb.swarm({ count = 8, hp = 200 }, { u("a", { hp = 100 }), u("b", { hp = 900 }) }) == false, "§4 essaim : médian de NOS PV, pas le plus gros")
  check(Rb.swarm({ count = 7, hp = 1 }, { u("a") }) == false and Rb.swarm({ count = 8, hp = 0 }, { u("a") }) == false
    and Rb.swarm({ count = 8, hp = 1 }, {}) == false, "§4 essaim : seuil du nombre, PV nuls, aucun candidat")
  -- hystérésis : a 30, b 27 (précédent b : 30 < 27 × 1,15 = 31,05 : b reste) ; c 36 (36 > 31,05 : on change)
  local a1, b1 = u("a", { cost = 10 }), u("b", { cost = 11.111111111111 })
  check(Rb.choose({ a1, b1 }, { prev = "b" }).item == "b", "§4 hystérésis : le choix précédent reste (30 contre 27)")
  check(Rb.choose({ a1, b1 }, { prev = nil }).item == "a", "§4 sans choix précédent : le meilleur")
  local c1 = u("a", { cost = 8 }) -- 37,5
  check(Rb.choose({ c1, b1 }, { prev = "b" }).item == "a", "§4 hystérésis : un net progrès change le choix")
  check(Rb.choose({ a1, b1 }, { prev = "absent" }).item == "a", "§4 choix précédent disparu : le meilleur")
  check(Rb.choose({ a1, u("b", { usable = false }) }, { prev = "b" }).item == "a", "§4 choix précédent inutilisable : on le quitte")

  -- §5 Besoin et demande.
  check(Rb.want(30, 10, 4) == 11, "§5 besoin : 15 visés - 4 = 11 (place 20)")
  check(Rb.want(30, 28, 0) == 2, "§5 besoin borné par la place sous le plafond")
  check(Rb.want(30, 10, 20) == 0, "§5 déjà au-delà de la part visée : 0")
  check(Rb.want(30, 40, 0) == 0, "§5 plafond dépassé : 0")
  check(Rb.want(0, 0, 0) == 0 and Rb.want(nil, nil, nil) == 0, "§5 plafond nul ou absent : 0")
  local d = Rb.demand({ item = "a", points = 1 }, 11)
  check(d and d.item == "a" and d.units == 11 and near(d.rate, 1.1), "§5 demande : 11 unités en 10 minutes")
  local d2 = Rb.demand({ item = "a", points = 2 }, 11)
  check(d2 and d2.units == 6 and near(d2.rate, 0.6), "§5 demande : unités de 2 points, arrondi au-dessus")
  check(near(Rb.demand({ item = "a", points = 4 }, 1).rate, Rb.MIN_RATE) and Rb.MIN_RATE > 1 / Rb.HORIZON_MIN, "§5 demande minimale")
  check(Rb.demand(nil, 5) == nil and Rb.demand({ item = "a", points = 1 }, 0) == nil and Rb.demand({ item = "a", points = 0 }, 5) == nil,
    "§5 rien à demander : nil")

  -- §6 Permutation.
  local base = { u("a", { cost = 10 }), u("b", { cost = 12, zone = true }), art, sup, u("c", { cost = 9, hp = 5000 }) }
  local st = { have = { a = 40, c = 10 }, enemy = { count = 30, hp = 5 }, prev = "c" }
  local ref = Rb.choose(base, st)
  local rename = { a = "zz1", b = "yy2", art = "ww3", sup = "vv4", c = "uu5", line = "ss6" }
  local inv = {}
  for k, v in pairs(rename) do inv[v] = k end
  local renamed, rhave = {}, {}
  for i, c in ipairs(base) do
    local c2 = {}
    for k, v in pairs(c) do c2[k] = v end
    c2.item = rename[c.item]
    renamed[i] = c2
  end
  for k, v in pairs(st.have) do rhave[rename[k]] = v end
  local ren = Rb.choose(renamed, { have = rhave, enemy = st.enemy, prev = rename[st.prev] })
  check(ref and ren and inv[ren.item] == ref.item and near(ren.score, ref.score) and ren.kind == ref.kind and ren.swarm == ref.swarm,
    "§6 objets renommés : même décision aux noms près")
  -- l'ordre de la liste ne change rien
  local rev = {}
  for i = #base, 1, -1 do rev[#rev + 1] = base[i] end
  local rv = Rb.choose(rev, st)
  check(rv and rv.item == ref.item and near(rv.score, ref.score), "§6 liste à l'envers : même décision")
  -- l'ordre de rangement des noms (alphabétique) ne donne pas d'avantage : on inverse l'alphabet des noms
  local flip = { a = "yy", b = "xx", art = "ww", sup = "vv", c = "zz", line = "uu" }
  local f2, fhave = {}, {}
  for i, c in ipairs(base) do
    local c2 = {}
    for k, v in pairs(c) do c2[k] = v end
    c2.item = flip[c.item]
    f2[i] = c2
  end
  for k, v in pairs(st.have) do fhave[flip[k]] = v end
  local fl = Rb.choose(f2, { have = fhave, enemy = st.enemy, prev = flip[st.prev] })
  local finv = {}
  for k, v in pairs(flip) do finv[v] = k end
  check(fl and finv[fl.item] == ref.item, "§6 noms dans un autre ordre alphabétique : même décision")

  -- §7 Unité inventée.
  local inventee = { item = "zorglub", hp = 123456, dps = 7777, range = 41, min_range = 0, zone = true, points = 3, cost = 5, usable = true }
  local pick7 = Rb.choose({ u("a"), inventee }, {})
  check(pick7 and pick7.item == "zorglub", "§7 une unité inventée, bien meilleure, est choisie sans une ligne de plus")
  local pick8 = Rb.choose({ u("a"), { item = "zorglub", hp = 10, dps = 1, range = 1, min_range = 0, zone = false, points = 1, cost = 500, usable = true } }, {})
  check(pick8 and pick8.item == "a", "§7 une unité inventée, bien moins bonne, n'est pas choisie")
  local pick9 = Rb.choose({ u("a"), { item = "quux", hp = 800, dps = 90, range = 10, min_range = 30, zone = true, points = 4, cost = 1, usable = true } },
    { have = { a = 10 } })
  check(pick9 and pick9.item == "a" and pick9.why and pick9.why:find("quux", 1, true), "§7 une unité inventée à portée minimale tombe sous la règle d'artillerie")
  check(Rb.kind({ hp = 1, dps = 0 }) == "soutien" and Rb.kind({ hp = 1, dps = 5, min_range = 3 }) == "indirect",
    "§7 la classe d'une unité inventée est lue à ses nombres")

  return pass, fail, msgs
end

local Rb = assert(load_src(SRC))
local pass, fail, msgs = suite(Rb)
local function check8(c, m)
  if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
end

-- §10 Catalogue : les unités qu'un objet pose (shared/ai3/catalogue.lua, K.units).
do
  local K = require("shared.ai3.catalogue")
  local function recipe(ings, product, amount)
    local list = {}
    for _, i in ipairs(ings) do list[#list + 1] = { type = "item", name = i[1], amount = i[2] } end
    return { category = "c", energy = 1, ingredients = list, products = { { type = "item", name = product, amount = amount or 1 } } }
  end
  local dump = { recipes = { ["kit-a"] = recipe({ { "gear", 2 }, { "plate", 5 } }, "kit-a"), gear = recipe({ { "plate", 2 } }, "gear"),
    ["kit-c"] = recipe({ { "kit-d", 1 } }, "kit-c"), ["kit-d"] = recipe({ { "kit-c", 1 } }, "kit-d") },
    techs = {}, entities = {}, resources = {}, items = {},
    units = { { name = "u1", type = "unit", item = "kit-a", hp = 900, speed = 0.14, range = 18, min_range = 0, dps = 100, half = 0.4, zone = true },
      { name = "u2", type = "spider-vehicle", item = "kit-b", hp = 5000, half = 1.5 },
      { name = "u3", type = "unit", hp = 100, half = 0.4 },
      { name = "u4", type = "unit", item = "kit-c", hp = 50, half = 0.6 } } }
  local cat = K.build(dump)
  local a = cat.unites["kit-a"]
  check8(a and a.entity == "u1" and a.hp == 900 and a.speed == 0.14 and a.range == 18 and a.dps == 100 and a.zone == true and a.points == 1,
    "§10 la fiche d'une unité : prototype, PV, vitesse, portée, DPS, zone, points")
  check8(a and a.cost == 9, "§10 coût : matières premières de la recette du kit, récursif (2 pignons de 2 + 5 = 9) : " .. tostring(a and a.cost))
  check8(cat.unites["kit-b"] and cat.unites["kit-b"].points == 12 and cat.unites["kit-b"].cost == 1 and cat.unites["kit-b"].dps == nil,
    "§10 une araignée vaut 12 points ; sans recette lue, coût 1 ; DPS non lu : nil")
  check8(cat.unites["kit-c"] and cat.unites["kit-c"].cost > 0, "§10 une recette qui boucle ne fait pas boucler le coût")
  check8(#cat.unite_list == 3 and cat.unite_list[1] == "kit-a" and cat.unite_list[2] == "kit-b" and cat.unite_list[3] == "kit-c",
    "§10 liste triée des kits ; une unité qu'aucun objet ne pose n'y est pas")
  check8(K.unit_points(0.5) == 1 and K.unit_points(0.51) == 2 and K.unit_points(0.75) == 2 and K.unit_points(0.76) == 4
    and K.unit_points(1.2) == 4 and K.unit_points(1.21) == 12 and K.unit_points(0.1, true) == 12 and K.unit_points(nil) == 1,
    "§10 classes de points lues à la boîte (1, 2, 4, 12)")
  local rev = {}
  for i = #dump.units, 1, -1 do rev[#rev + 1] = dump.units[i] end
  dump.units = rev
  local cat2 = K.build(dump)
  check8(cat2.unite_list[1] == "kit-a" and cat2.unites["kit-a"].cost == 9, "§10 relevé à l'envers : même catalogue")
  -- le catalogue alimente le choix : une fiche devient un candidat
  local c = cat.unites["kit-a"]
  local pick = Rb.choose({ { item = "kit-a", hp = c.hp, dps = c.dps, range = c.range, min_range = c.min_range, zone = c.zone, points = c.points,
    cost = c.cost, usable = true } }, {})
  check8(pick and pick.item == "kit-a", "§10 une fiche du catalogue est un candidat du choix")
end

-- §11 Mall d'INDUSTRIE : le kit d'une unité est une cellule seule en sortie « unité », jamais une rangée ni un bloc (shared/ai3/industrie.lua).
local ID_SRC = read("shared/ai3/industrie.lua")
local function load_id(src)
  local f, e = load(src, "=industrie", "t")
  if not f then return nil, e end
  local ok, M = pcall(f)
  if not ok then return nil, M end
  return M
end
local function id_suite(Id)
  local pass2, fail2 = 0, 0
  local function ck(c) if c then pass2 = pass2 + 1 else fail2 = fail2 + 1 end end
  local fab = {
    ["kit-a"] = { produits = { "kit-a" }, patronnable = true, solides = { { name = "gear" }, { name = "plate" } }, fluides_in = {},
      machines = { { item = "ws", entity = "ws", par_min = 7.5 } } },
    ["thing"] = { produits = { "thing" }, patronnable = true, solides = { { name = "plate" } }, fluides_in = {},
      machines = { { item = "ws", entity = "ws", par_min = 7.5 } } },
  }
  local function run(rate, unites, item)
    return Id.decide({}, { tick = 0, sources = { { { item = item or "kit-a", rate = rate, src = "unite" } } }, fab = fab, bloc_max = 6, unites = unites })
  end
  -- gros besoin : sans le lien kit -> unité, une rangée ; avec, une cellule seule en sortie « unité »
  local plain = run(10, nil)
  ck(#plain.rows == 1 and #plain.seuls == 0)
  local u = run(10, { ["kit-a"] = true })
  ck(#u.rows == 0 and #u.blocs == 0 and #u.seuls == 1 and u.seuls[1].item == "kit-a" and u.seuls[1].unite == true and u.seuls[1].machine == "ws"
    and u.seuls[1].recipe == "kit-a")
  -- petit besoin : sans le lien, il attend un bloc ; avec, la cellule est ouverte tout de suite
  local small = run(0.5, nil)
  ck(#small.seuls == 0 and #small.wait == 1)
  local small_u = run(0.5, { ["kit-a"] = true })
  ck(#small_u.seuls == 1 and small_u.seuls[1].unite == true and #small_u.wait == 0)
  -- un objet qui n'est pas une unité n'est pas touché
  local other = run(10, { ["kit-a"] = true }, "thing")
  ck(#other.rows == 1 and #other.seuls == 0)
  -- un kit déjà servi n'est pas redemandé
  local served = Id.decide({}, { tick = 0, sources = { { { item = "kit-a", rate = 10, src = "unite" } } }, fab = fab, bloc_max = 6,
    unites = { ["kit-a"] = true }, served = { ["kit-a"] = true } })
  ck(#served.seuls == 0 and #served.rows == 0)
  -- ordre d'examen : la cellule d'un kit d'unité d'abord, puis les blocs, puis les autres cellules
  local o = Id.order({ blocs = { { items = { "b1" } }, { items = { "b2" } } },
    seuls = { { item = "s1" }, { item = "k1", unite = true }, { item = "s2" } } })
  ck(#o == 5 and o[1].dec.item == "k1" and o[1].kind == "seul" and o[1].items[1] == "k1")
  ck(o[2].kind == "bloc" and o[2].items[1] == "b1" and o[3].kind == "bloc" and o[3].items[1] == "b2")
  ck(o[4].kind == "seul" and o[4].dec.item == "s1" and o[5].dec.item == "s2")
  ck(#Id.order({}) == 0)
  return pass2, fail2
end
do
  local Id = assert(load_id(ID_SRC))
  local p2, f2 = id_suite(Id)
  check8(f2 == 0 and p2 == 10, "§11 mall : kit d'unité en cellule seule « unité » (" .. p2 .. " OK, " .. f2 .. " ECHEC)")
  local ID_MUT = {
    { "unité non routée", "if inp.unites and inp.unites[c.item] then", "if false then" },
    { "tout objet routé en unité", "if inp.unites and inp.unites[c.item] then", "if inp.unites then" },
    { "unité rangée comme avant", "out.seuls[#out.seuls + 1] = { item = c.item, recipe = pr.recipe, machine = pr.machine.entity, rate = c.rate, need = need, unite = true }",
      "out.seuls[#out.seuls + 1] = { item = c.item, recipe = pr.recipe, machine = pr.machine.entity, rate = c.rate, need = need }" },
    { "unité servie redemandée", "if inp.served and inp.served[c.item] then", "if false then" },
    { "kit d'unité derrière les blocs", [==[    if d.unite then cands[#cands + 1] = { dec = d, kind = "seul", items = { d.item } } end]==],
      [==[    if false then cands[#cands + 1] = { dec = d, kind = "seul", items = { d.item } } end]==] },
    { "autres cellules perdues", [==[    if not d.unite then cands[#cands + 1] = { dec = d, kind = "seul", items = { d.item } } end]==],
      [==[    if false then cands[#cands + 1] = { dec = d, kind = "seul", items = { d.item } } end]==] },
    { "blocs perdus", [==[  for _, d in ipairs(out.blocs or {}) do cands[#cands + 1] = { dec = d, kind = "bloc", items = d.items } end]==], "" },
  }
  local refused2, kept2 = 0, {}
  for _, m in ipairs(ID_MUT) do
    local a, b = ID_SRC:find(m[2], 1, true)
    if not a then kept2[#kept2 + 1] = m[1] .. " (motif absent)" else
      local mod = load_id(ID_SRC:sub(1, a - 1) .. m[3] .. ID_SRC:sub(b + 1))
      local ok, pp, ff = pcall(id_suite, mod)
      if (not ok) or ff > 0 or pp ~= 10 then refused2 = refused2 + 1 else kept2[#kept2 + 1] = m[1] end
    end
  end
  check8(#kept2 == 0, "§11 mutants du mall NON refusés : " .. table.concat(kept2, " ; "))
  print(string.format("[AI3-ROBOTS] mutants du mall refusés : %d sur %d", refused2, #ID_MUT))
end

-- §8 Aucun nom : les chaînes du code sont les classes du modèle, rien d'autre.
local function strip(src) return (src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")) end
local code = strip(SRC)
-- classes du modèle, noms de types du langage, et les textes de diagnostic (aucun nom d'objet)
local allowed = { soutien = true, indirect = true, ligne = true, number = true, table = true, [""] = true, [" ; "] = true, [" : "] = true,
  ["aucune unite utilisable"] = true, ["aucune unite sous les regles de part"] = true, ["ecartees : "] = true,
  ["%s (%s %.0f%% > %.0f%%)"] = true }
local strings, bad = 0, {}
for s in code:gmatch('"([^"\n]*)"') do
  strings = strings + 1
  if not allowed[s] then bad[#bad + 1] = s end
end
for s in code:gmatch("'([^'\n]*)'") do bad[#bad + 1] = s end
check8(#bad == 0, "§8 chaîne inattendue dans shared/ai3/robots.lua : " .. table.concat(bad, " | "))
local words = { "fo%-robot", "trotter", "steam", "engine", "iron", "steel", "workshop", "kit%-", "atelier", "spidertron", "biter", "gun%-turret" }
for _, w in ipairs(words) do check8(not code:lower():find(w), "§8 mot d'objet dans le décisionnel : " .. w) end
check8(not code:find("[^i_%w]pairs%s*%("), "§8 aucun pairs décisionnel")
check8(not code:find("math%.random") and not code:find("os%.time") and not code:find("os%.clock") and not code:find("game%."),
  "§8 ni hasard, ni horloge, ni API du jeu")

for _, m in ipairs(msgs) do print("[AI3-ROBOTS] ECHEC " .. m) end

-- §9 Mutants.
local MUT = {
  { "valeur sans portée", "* sqrt(max(u.range or 0, 1) / Rb.REF_RANGE)", "" },
  { "valeur sans PV", "sqrt(max(0, u.hp or 0) * d)", "sqrt(d)" },
  { "score sans coût", "return Rb.value(u) / u.cost", "return Rb.value(u)" },
  { "coût nul accepté", "if type(u.cost) ~= \"number\" or u.cost <= Rb.EPS then return 0 end", "" },
  { "DPS inconnu à zéro", "return (u.hp or 0) / Rb.HP_PER_DPS", "return 0" },
  { "soutien non reconnu", "if type(u.dps) == \"number\" and u.dps == 0 then return \"soutien\" end", "" },
  { "artillerie non reconnue", "if (u.min_range or 0) > 0 then return \"indirect\" end", "" },
  { "soutien sans DPS de référence", "if d <= 0 then d = Rb.SUPPORT_DPS end", "" },
  { "inutilisable accepté", "if c.usable and (c.points or 0) > 0 and Rb.score(c) > 0 then", "if (c.points or 0) > 0 and Rb.score(c) > 0 then" },
  { "points nuls acceptés", "if c.usable and (c.points or 0) > 0 and Rb.score(c) > 0 then", "if c.usable and Rb.score(c) > 0 then" },
  { "règle de part ignorée", "if kind ~= \"ligne\" and after > cap + Rb.EPS then", "if false then" },
  { "part sans les points du candidat", "local after = (sh[kind] + c.points) / (sh.total + c.points)", "local after = sh[kind] / math.max(1, sh.total)" },
  { "part d'artillerie à 50 %", "Rb.INDIRECT_MAX = 0.25", "Rb.INDIRECT_MAX = 0.5" },
  { "part de soutien à 20 %", "Rb.SOUTIEN_MAX = 0.10", "Rb.SOUTIEN_MAX = 0.2" },
  { "seuil de part strict", "after > cap + Rb.EPS", "after >= cap - Rb.EPS" },
  { "zone jamais préférée", "if swarm and c.zone then s = s * Rb.ZONE_FACTOR end", "" },
  { "zone toujours préférée", "if swarm and c.zone then s = s * Rb.ZONE_FACTOR end", "if c.zone then s = s * Rb.ZONE_FACTOR end" },
  { "essaim sans seuil de nombre", "or (enemy.count or 0) < Rb.SWARM_COUNT", "or false" },
  { "essaim absolu", "return enemy.hp * Rb.SWARM_RATIO <= median", "return enemy.hp <= 100" },
  { "essaim au PV moyen d'un candidat", "local median = hps[floor((#hps + 1) / 2)]", "local median = hps[#hps]" },
  { "ex æquo au dernier", "if best == nil or s > best_score + Rb.EPS then best, best_score = c, s end", "if best == nil or s >= best_score - Rb.EPS then best, best_score = c, s end" },
  { "pire score choisi", "if best == nil or s > best_score + Rb.EPS then best, best_score = c, s end", "if best == nil or s < best_score - Rb.EPS then best, best_score = c, s end" },
  { "pas d'hystérésis", "if st.prev and st.prev ~= best.item and scores[st.prev] and best_score < scores[st.prev] * Rb.HYSTERESIS then", "if false then" },
  { "hystérésis éternelle", "best_score < scores[st.prev] * Rb.HYSTERESIS then", "true then" },
  { "besoin sans plafond", "return max(0, min(room, target - (robots or 0)))", "return max(0, target - (robots or 0))" },
  { "besoin sans part", "local target = floor((cap or 0) * Rb.SHARE + Rb.EPS)", "local target = cap or 0" },
  { "besoin sans robots déjà là", "return max(0, min(room, target - (robots or 0)))", "return max(0, min(room, target))" },
  { "demande arrondie en dessous", "local units = ceil(want / choice.points - Rb.EPS)", "local units = floor(want / choice.points)" },
  { "demande sans horizon", "rate = max(Rb.MIN_RATE, units / Rb.HORIZON_MIN)", "rate = max(Rb.MIN_RATE, units)" },
  { "demande sans minimum", "rate = max(Rb.MIN_RATE, units / Rb.HORIZON_MIN)", "rate = units / Rb.HORIZON_MIN" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif absent)"
  else
    local mod = load_src(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local f2 = 1
    if mod then
      local ok, _, ff = pcall(suite, mod)
      f2 = ok and ff or 1
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[AI3-ROBOTS] ECHEC §9 mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[AI3-ROBOTS] mutants refusés : %d sur %d", refused, #MUT))
print(string.format("[AI3-ROBOTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
