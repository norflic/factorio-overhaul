--[[
  Lot AMELIORATION « monter en largeur et par bloc » : test hors jeu de la règle pure (shared/ai3/amelioration.lua) sur les DONNÉES
  RÉELLES des niveaux (shared/levels/config.lua), et de son branchement dans shared/ai3/capital.lua (ctx.blocs).

    §1 un bloc de fours monte d'un niveau EN ENTIER avant qu'un seul bâtiment monte de deux (boucle de décisions simulée) ;
    §2 le cas refusé du DC : « un seul bâtiment poussé au maximum alors que 20 fours sont au niveau 1 » ;
    §3 plafond du centre, emprise d'un bloc fixe, objet sans coût connu, refus récent : une CAUSE par groupe, jamais un silence ;
    §4 stock : le lot est ce que le stock libre paie (au moins un) ; coût = n × le coût des DONNÉES ;
    §5 ordre : le débit (fours, foreuses) passe avant la défense en temps de paix, la défense avant sous menace ; le besoin d'un bloc
       l'avance ; les poids de la faction (traits) modulent les familles ;
    §6 déterminisme (relevé inversé) ;
    §7 branchement dans Cap.candidates : la chaîne du centre (Q16) reste SEULE candidate individuelle, tout le reste passe par blocs ;
       Cap.emit paie un lot plus petit quand le stock virtuel ne couvre pas tout ; le but porte n, l'unité et le bloc ;
    §8 coût d'une décision sur 600 bâtiments (hors jeu) ;
    §9 MUTANTS : la règle est réécrite de 8 façons fausses (le texte du module est modifié puis rechargé), chacune est vue.
  Usage : lua5.2 tests/amelioration_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local L = require("shared.levels.config")
local Cap = require("shared.ai3.capital")
local Am0 = require("shared.ai3.amelioration")
local P = require("shared.ai3.projets")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[AMELIORATION] ECHEC : " .. msg) end
  end
  return cond
end
local function say(s) if not quiet then print("[AMELIORATION] " .. s) end end

local BASE = {
  gun = { type = "ammo-turret", role = "militaire", health = 400, dmg = 1, cooldown = 10 },
  wall = { type = "wall", role = "militaire", health = 350 },
  drill = { type = "mining-drill", role = "foreuse", health = 300, speed = 0.5 },
  furnace = { type = "furnace", role = "fabrique", health = 300, speed = 2 },
  assembler = { type = "assembling-machine", role = "fabrique", health = 350, speed = 0.75 },
}
local function proto_of(Ld)
  local cache = {}
  for _, fam in ipairs(Ld.families) do
    for n = 1, fam.max do
      local name = Ld.name(fam, n)
      if fam.key == "command" then
        cache[name] = { type = "container", role = "logistique", health = 3000, item = name }
      elseif BASE[fam.key] then
        local b = BASE[fam.key]
        local p = { type = b.type, role = b.role, item = name }
        for _, st in ipairs(fam.stats) do
          local leaf = st.path[#st.path]
          if leaf == "max_health" then p.health = Ld.apply_stat(st, b.health, n) end
          if leaf == "damage_modifier" then p.dmg = Ld.apply_stat(st, b.dmg, n) end
          if leaf == "crafting_speed" or leaf == "mining_speed" then p.speed = Ld.apply_stat(st, b.speed, n) end
        end
        p.health = p.health or b.health
        p.speed = p.speed or b.speed
        if b.cooldown then p.dps = (p.dmg or 1) / b.cooldown end
        cache[name] = p
      end
    end
  end
  return function(name) return cache[name] end
end
local proto = proto_of(L)

local UNIT = { ["iron-plate"] = 2, ["copper-plate"] = 2, ["stone-brick"] = 5, ["iron-gear-wheel"] = 5,
  ["electronic-circuit"] = 8, ["steel-plate"] = 12, ["fo-command-center"] = 300, ["battery"] = 30, ["engine-unit"] = 40,
  ["plastic-bar"] = 6, ["fo-tungsten-plate"] = 20, ["fo-resonance-crystal"] = 25 }
local function unit_cost(item) return UNIT[item] end

local FUR, DR, WALL, GUN, CC = L.by_key.furnace, L.by_key.drill, L.by_key.wall, L.by_key.gun, L.by_key.command
local BIG = {}
for _, it in ipairs({ "iron-plate", "copper-plate", "stone-brick", "iron-gear-wheel", "electronic-circuit", "steel-plate", "battery", "engine-unit", "plastic-bar", "fo-tungsten-plate", "fo-resonance-crystal" }) do
  BIG[it] = 100000
end

local function ctx(over)
  local c = { proto = proto, unit_cost = unit_cost, stock = BIG, weights = {}, cc_level = 3 }
  for k, v in pairs(over or {}) do c[k] = v end
  return c
end

--- Relevé : count bâtiments de la famille `fam` au niveau `lvl`, bloc `block`, numéros à partir de `id0`.
local function ents(list, fam, lvl, count, block, id0, extra)
  for i = 1, count do
    local e = { id = id0 + i, name = L.name(fam, lvl), working = true, block = block }
    for k, v in pairs(extra or {}) do e[k] = v end
    list[#list + 1] = e
  end
  return list
end

--- Applique une décision de lot au relevé simulé (monte les bâtiments choisis d'un niveau).
local function apply(list, cand)
  local by = {}
  for _, id in ipairs(cand.ids) do by[id] = true end
  for _, e in ipairs(list) do
    if by[e.id] then
      local fam, n = L.parse(e.name)
      e.name = L.name(fam, n + 1)
    end
  end
end

local function levels_of(list, block, fam)
  local lo, hi = 99, 0
  for _, e in ipairs(list) do
    local f, n = L.parse(e.name)
    if e.block == block and f == fam then
      lo, hi = math.min(lo, n), math.max(hi, n)
    end
  end
  return lo, hi
end

local function best(Am, list, over)
  local res = Am.candidates(L, list, ctx(over), CC, Cap)
  table.sort(res.cands, function(a, b)
    local sa = a.score or 0
    local sb = b.score or 0
    if sa ~= sb then return sa > sb end
    return a.key < b.key
  end)
  return res.cands[1], res
end

local function run_all(Am, full)
  -- §1 Un bloc de 20 fours au niveau 1 : deux décisions (12 + 8) le montent au niveau 2 ; jamais un bâtiment à +2.
  local list = ents({}, FUR, 1, 20, "p1", 100)
  local steps, max_gap = 0, 0
  local first
  for _ = 1, 60 do
    local c = best(Am, list, { cc_level = 3 })
    if not c then break end
    first = first or c
    steps = steps + 1
    apply(list, c)
    local lo, hi = levels_of(list, "p1", FUR)
    max_gap = math.max(max_gap, hi - lo)
    if lo >= 6 then break end
  end
  local lo, hi = levels_of(list, "p1", FUR)
  check(first and first.n == 12 and #first.ids == 12, "§1 premier lot = BATCH_MAX bâtiments : " .. tostring(first and first.n))
  check(first and first.from == 1 and first.to == 2 and first.bloc == "p1", "§1 le lot monte le niveau MINIMAL du bloc d'un cran")
  check(max_gap <= 1, "§1 jamais un bâtiment à +2 niveaux du minimum de son bloc : écart max " .. max_gap)
  check(lo == 6 and hi == 6, string.format("§1 le bloc entier atteint le plafond du centre 3 (niveau 6) : %d..%d", lo, hi))
  check(steps == 10, "§1 5 niveaux x (12 + 8) bâtiments = 10 décisions : " .. steps)

  -- §2 Le cas refusé : 20 fours au niveau 1, un seul au niveau 5 (poussé au maximum) : le lot monte les 19 fours du niveau 1, pas lui.
  local l2 = ents({}, FUR, 1, 19, "p1", 100)
  l2[#l2 + 1] = { id = 200, name = L.name(FUR, 5), working = true, block = "p1" }
  local c2 = best(Am, l2, { cc_level = 3 })
  local has200 = false
  for _, id in ipairs(c2 and c2.ids or {}) do if id == 200 then has200 = true end end
  check(c2 and c2.from == 1 and not has200, "§2 un bâtiment déjà haut ne monte pas avant le reste de son bloc (niveau minimal 1)")
  check(c2 and c2.bloc_low == 19 and c2.bloc_size == 20, "§2 le lot sait la taille du bloc et la part au niveau minimal")

  -- §3 Causes.
  local capd = ents({}, DR, 2, 4, "q", 300)
  local _, r3 = best(Am, capd, { cc_level = 1 })
  check(r3.report[1] and r3.report[1].state == "refuse" and r3.report[1].cause == "plafond-centre",
    "§3 bloc au plafond du centre : cause plafond-centre : " .. tostring(r3.report[1] and r3.report[1].cause))
  local _, r3b = best(Am, capd, { cc_level = 0 })
  check(r3b.report[1].cause == "sans-centre", "§3 sans centre : cause sans-centre")
  local at_era = ents({}, FUR, 6, 3, "fixe", 400, { fixed = true })
  local c3c, r3c = best(Am, at_era, { cc_level = 4 })
  check(c3c == nil and r3c.report[1].cause == "emprise", "§3 bloc fixe : le niveau 7 change l'emprise (2 -> 3) : refus emprise : " .. tostring(r3c.report[1].cause))
  local free_blk = ents({}, FUR, 6, 3, "libre", 410)
  local c3d = best(Am, free_blk, { cc_level = 4 })
  check(c3d ~= nil and c3d.to == 7, "§3 bloc non fixe : le même passage est permis (le moteur vérifie la place)")
  local nocost = ents({}, FUR, 1, 3, "x", 420)
  local c3e, r3e = best(Am, nocost, { cc_level = 3, unit_cost = function(item) if item == "steel-plate" then return nil end return UNIT[item] end })
  check(c3e == nil and tostring(r3e.report[1].cause):sub(1, 9) == "sans-cout", "§3 objet du coût sans moyen connu : bloc impayable (H8) : " .. tostring(r3e.report[1].cause))
  local c3f, r3f = best(Am, ents({}, FUR, 1, 3, "x", 430), { cc_level = 3, exclude = { ["bloc:x:furnace:2"] = true } })
  check(c3f == nil and r3f.report[1].cause == "refus-recent", "§3 refus récent du bloc : cause refus-recent")
  local c3g = best(Am, ents({}, FUR, 1, 3, "x", 430), { cc_level = 3, exclude = { ["e:431"] = true, ["e:432"] = true } })
  check(c3g and c3g.n == 1 and c3g.ids[1] == 433, "§3 bâtiments refusés seuls écartés du lot sans fermer le bloc")
  local c3h, r3h = best(Am, ents({}, FUR, L.by_key.furnace.max, 2, "m", 440), { cc_level = 15 })
  check(c3h == nil and r3h.report[1].cause == "niveau-max", "§3 niveau maximal : cause niveau-max")

  -- §4 Stock : le lot est ce que le stock paie, au moins un ; coût = n x données.
  local st = { ["steel-plate"] = 10, ["stone-brick"] = 100 }
  local c4 = best(Am, ents({}, FUR, 1, 20, "p1", 100), { cc_level = 3, stock = st })
  local unit = L.cost(FUR, 2)
  local per = math.huge
  for _, it in ipairs(unit) do per = math.min(per, math.floor((st[it[1]] or 0) / it[2])) end
  check(c4 and c4.n == per, string.format("§4 lot = ce que le stock paie : %s (attendu %d)", tostring(c4 and c4.n), per))
  local ok_cost = c4 ~= nil
  for i, it in ipairs(unit) do
    if not (c4 and c4.cost[i] and c4.cost[i][1] == it[1] and c4.cost[i][2] == it[2] * c4.n) then ok_cost = false end
  end
  check(ok_cost, "§4 coût du lot = n x coût des DONNÉES (Ld.cost)")
  local c4b = best(Am, ents({}, FUR, 1, 20, "p1", 100), { cc_level = 3, stock = {} })
  check(c4b and c4b.n == 1, "§4 stock vide : un seul bâtiment (la fabrication se demande comme pour un bâtiment seul)")

  -- §5 Ordre. Foreuses et murs au même niveau : en paix le débit passe devant, sous menace la défense.
  local mix = ents(ents({}, DR, 1, 6, "champ", 100), WALL, 1, 6, "mur", 200)
  local c5 = best(Am, mix, { cc_level = 3 })
  check(c5 and c5.family == "drill", "§5 en paix, les foreuses avant les murs : " .. tostring(c5 and c5.family))
  local c5b = best(Am, mix, { cc_level = 3, threat = true })
  check(c5b and c5b.family == "wall", "§5 sous menace, la défense passe devant : " .. tostring(c5b and c5b.family))
  local two = ents(ents({}, DR, 1, 6, "a", 100), DR, 1, 6, "b", 200)
  local c5c = best(Am, two, { cc_level = 3, need = function(block) return block == "b" and 300 or 100 end })
  check(c5c and c5c.bloc == "b", "§5 le bloc en manque monte avant les autres : " .. tostring(c5c and c5c.bloc))
  local c5d = best(Am, mix, { cc_level = 3, weights = { capital = 100, defense = 3000 } })
  check(c5d and c5d.family == "wall", "§5 les traits de la faction (poids de la défense) renversent l'ordre des familles")
  local idle = ents(ents({}, DR, 1, 6, "act", 100, { working = true }), DR, 1, 6, "arret", 200, { working = false })
  local c5e = best(Am, idle, { cc_level = 3 })
  check(c5e and c5e.bloc == "act", "§5 un bloc en marche avant un bloc à l'arrêt")

  -- §6 Déterminisme : relevé inversé, même décision.
  local lst = ents(ents(ents({}, FUR, 1, 10, "a", 100), DR, 1, 10, "b", 200), WALL, 2, 10, "c", 300)
  local rev = {}
  for i = #lst, 1, -1 do rev[#rev + 1] = lst[i] end
  local d1 = best(Am, lst, { cc_level = 3 })
  local d2 = best(Am, rev, { cc_level = 3 })
  local same = d1 and d2 and d1.key == d2.key and #d1.ids == #d2.ids
  if same then for i, id in ipairs(d1.ids) do if d2.ids[i] ~= id then same = false end end end
  check(same, "§6 même décision, relevé dans l'ordre inverse")

  -- §6 bis Gel de la reconstruction levé SAUF manque, objet par objet (décision du lead, 8/11).
  do
    local unit2 = L.cost(DR, 2)
    local item1, q1 = unit2[1][1], unit2[1][2]
    local stock = {}
    for _, it in ipairs(unit2) do stock[it[1]] = it[2] * 30 end
    local fours = ents({}, DR, 1, 12, "p1", 100)
    -- (a) une reconstruction ouverte qui laisse de quoi payer le coût PLUS ses pièces manquantes : le lot passe, entier.
    local needs_ok = { [item1] = q1 * 5 }
    local ca = best(Am, fours, { cc_level = 3, stock = stock, recon = needs_ok })
    check(ca and ca.n == 12, "§6 bis reconstruction ouverte mais stock suffisant pour le lot ET ses manques : lot de 12 : " .. tostring(ca and ca.n))
    -- (b) le lot est réduit à ce que le stock paie une fois les manques déduits.
    local needs_part = { [item1] = q1 * 30 - q1 * 4 }
    local cb = best(Am, fours, { cc_level = 3, stock = stock, recon = needs_part })
    check(cb and cb.n == 4, "§6 bis le lot est réduit au stock net des manques de la reconstruction : " .. tostring(cb and cb.n))
    -- (c) l'objet est tout entier réservé à la reconstruction : refus dit, cause reconstruction:<objet>.
    local needs_all = { [item1] = q1 * 30 }
    local cc2, rc2 = best(Am, fours, { cc_level = 3, stock = stock, recon = needs_all })
    check(cc2 == nil and rc2.report[1].cause == "reconstruction:" .. item1,
      "§6 bis objet pris par la reconstruction : refus reconstruction:" .. item1 .. " : " .. tostring(rc2.report[1].cause))
    -- (d) sans reconstruction : inchangé.
    local cd = best(Am, fours, { cc_level = 3, stock = stock })
    check(cd and cd.n == 12, "§6 bis sans reconstruction ouverte : lot de 12")
    -- (e) Am.net ne modifie pas le stock et ne passe jamais sous zéro.
    local nn = Am.net({ a = 3 }, { a = 10, b = 4 })
    check(nn.a == 0 and nn.b == nil, "§6 bis stock net jamais négatif, objet absent non créé")
  end

  if not full then return end

  -- §7 Branchement dans Cap.candidates (ctx.blocs).
  -- Centre 1 (plafond 2). Fours niveau 1 (bloc p1), un four niveau 2 (bloc p1), mitrailleuses niveau 1 (bloc q).
  local lst7 = {}
  ents(lst7, FUR, 1, 8, "p1", 100)
  lst7[#lst7 + 1] = { id = 500, name = L.name(FUR, 2), working = true, block = "p1" }
  ents(lst7, GUN, 1, 4, "q", 600)
  local census = { list = lst7, center = { id = 1, name = L.name(CC, 1) } }
  local res7 = Cap.candidates(L, census, ctx({ cc_level = nil, blocs = true, stock = BIG }))
  local singles, blocs = 0, 0
  for _, c in ipairs(res7.cands) do
    if tostring(c.key):sub(1, 5) == "bloc:" then blocs = blocs + 1 elseif not c.center then singles = singles + 1 end
  end
  check(blocs == 2, "§7 deux blocs (fours p1, mitrailleuses q) : " .. blocs)
  local nchain = 0
  for _, c in ipairs(res7.cands) do if c.chain then nchain = nchain + 1 end end
  check(singles == nchain, string.format("§7 les seuls candidats individuels sont ceux de la chaîne du centre : %d seul(s), %d chaîne(s)", singles, nchain))
  check(#res7.report == 2, "§7 le rapport porte un état par (bloc, famille) : " .. #res7.report)
  local old = Cap.candidates(L, census, ctx({ cc_level = nil, stock = BIG }))
  local n_old = 0
  for _, c in ipairs(old.cands) do if not c.center then n_old = n_old + 1 end end
  check(n_old == 12 and old.report == nil, "§7 sans ctx.blocs : l'ancienne règle, un candidat par bâtiment : " .. n_old)

  -- Choix + but + émission d'un lot payé en plus petit.
  local r7 = Cap.candidates(L, { list = ents({}, DR, 1, 20, "p1", 100), center = { id = 1, name = L.name(CC, 2) } },
    ctx({ cc_level = nil, blocs = true, stock = BIG }))
  local d
  for _, c in ipairs(r7.cands) do if c.bloc then d = c end end
  check(d and d.bloc == "p1" and d.n == 12 and r7.report and #r7.report == 1, "§7 le candidat porte le bloc, n et le rapport")
  local g = Cap.goal(d, {})
  check(g and g.bloc == "p1" and g.n == 12 and g.unit and g.unit[1][2] == d.unit[1][2], "§7 le but porte n, l'unité et le bloc")
  local E = { avail = {}, tasks = {}, raw = {}, view = { workers_idle = 0 } }
  for _, it in ipairs(g.cost) do E.avail[it[1]] = it[2] end -- tout le lot
  local emit = Cap.emit(P)
  local r = emit(E, { prio = 50 }, g)
  check(r == "ok" and E.pay and E.pay[1].n == 12, "§7 émission : le lot entier est payé si le stock virtuel le couvre")
  local E2 = { avail = {}, tasks = {}, raw = {}, view = { workers_idle = 0 } }
  for _, it in ipairs(g.unit) do E2.avail[it[1]] = it[2] * 5 + 1 end -- de quoi payer 5 bâtiments
  local r2 = emit(E2, { prio = 50 }, g)
  check(r2 == "ok" and E2.pay and E2.pay[1].n == 5, "§7 émission : le stock virtuel couvre 5 bâtiments, 5 sont payés : " .. tostring(E2.pay and E2.pay[1].n))
  local okc = E2.pay and E2.pay[1].cost[1][2] == g.unit[1][2] * 5
  check(okc, "§7 émission : le coût payé est celui des 5 bâtiments")

  -- §7 bis La chaîne du centre (Q16) est SECONDAIRE : 30 foreuses au niveau 1 (bloc p1), centre 1 (plafond 2). Le centre veut UNE foreuse au
  -- niveau 2 : tant qu'un bloc de production est payable, c'est le BLOC qui monte, pas une foreuse seule (DC, 8/11).
  local function choose_q16(CapX)
    local census16 = { list = ents({}, DR, 1, 30, "p1", 100), center = { id = 1, name = L.name(CC, 1) } }
    return CapX.choose(L, census16, ctx({ cc_level = nil, blocs = true, stock = BIG }))
  end
  local d16 = choose_q16(Cap)
  check(d16.bloc == "p1" and not d16.chain, "§7 bis chaîne Q16 secondaire : le bloc de production monte avant la foreuse seule : " .. tostring(d16.key))
  -- Sans stock pour le bloc (rien n'est payable en entier), la chaîne reste permise : le centre ne meurt pas de faim.
  local census16b = { list = ents({}, DR, 1, 30, "p1", 100), center = { id = 1, name = L.name(CC, 1) } }
  local d16b = Cap.choose(L, census16b, ctx({ cc_level = nil, blocs = true, stock = {} }))
  check(d16b.chain ~= nil and d16b.bloc == nil, "§7 bis sans stock, la chaîne Q16 reste permise : " .. tostring(d16b.key))
  -- Mutant du DC : « seul le bâtiment de la chaîne Q16 monte alors que les blocs de production restent au niveau 1 ».
  do
    local f = assert(io.open("shared/ai3/capital.lua", "rb"))
    local src = f:read("*a")
    f:close()
    local i, j = src:find("t.cand and not prod_ready then", 1, true)
    assert(i, "mutant Q16 : motif introuvable")
    local mut = assert(load(src:sub(1, i - 1) .. "t.cand then" .. src:sub(j + 1), "=mutantQ16", "t"))()
    local dm = choose_q16(mut)
    check(dm.chain ~= nil and dm.bloc == nil, "§7 bis le mutant « seule la chaîne Q16 monte, les blocs restent au niveau 1 » est vu par le contrôle précédent")
  end

  -- §7 ter Tapis et bras : rang lu à la vitesse des données, jamais un nom ; un bras ne change que vers un bras de MÊME portée.
  local MP = {
    a = { type = "transport-belt", group = "belt", w = 1, h = 1, energy = "none", cats = {}, speed = 0.03, item = "ia" },
    b = { type = "transport-belt", group = "belt", w = 1, h = 1, energy = "none", cats = {}, speed = 0.06, item = "ib" },
    c = { type = "transport-belt", group = "belt", w = 1, h = 1, energy = "none", cats = {}, speed = 0.09, item = "ic" },
    i1 = { type = "inserter", group = "ins", w = 1, h = 1, energy = "electric", cats = {}, speed = 0.014, item = "j1", reach = "0,-1>0,1" },
    i2 = { type = "inserter", group = "ins", w = 1, h = 1, energy = "electric", cats = {}, speed = 0.04, item = "j2", reach = "0,-1>0,1" },
    i3 = { type = "inserter", group = "ins", w = 1, h = 1, energy = "electric", cats = {}, speed = 0.02, item = "j3", reach = "0,-2>0,2" },
  }
  local mc = { mproto = function(n) return MP[n] end, machines = { "a", "b", "c", "i1", "i2", "i3" } }
  local sa = Cap.successors(L, mc, "a")
  check(#sa == 2 and sa[1] == "b" and sa[2] == "c", "§7 ter tapis : rangs supérieurs par vitesse croissante")
  local si = Cap.successors(L, mc, "i1")
  check(#si == 1 and si[1] == "i2", "§7 ter bras : le bras à portée différente n'est jamais une cible")
  local cm = { list = {}, center = { id = 1, name = L.name(CC, 1) }, machines = {} }
  for i = 1, 30 do cm.machines[i] = { id = i, name = "a", working = true, block = (i <= 20) and "p1" or "p2" } end
  local rc, _ = Cap.replace_candidates(L, cm, ctx({ mproto = mc.mproto, machines = mc.machines, stock = { ib = 50, ic = 50 },
    unit_cost = function() return 3 end }))
  local byblock = {}
  for _, c in ipairs(rc) do byblock[#byblock + 1] = c.key end
  check(#rc == 2 and rc[1].replace.n == 12 and rc[2].replace.n == 10, "§7 ter tapis : un lot par bloc, de 12 au plus : " .. #rc .. " lot(s)")

  -- §8 Coût d'une décision sur 600 bâtiments.
  local big = {}
  ents(big, DR, 1, 240, "champ", 1000)
  ents(big, FUR, 1, 140, "champ", 2000)
  ents(big, WALL, 3, 200, "mur", 3000)
  ents(big, GUN, 2, 20, "tour", 4000)
  local t0 = os.clock()
  for _ = 1, 20 do best(Am, big, { cc_level = 3 }) end
  local ms = (os.clock() - t0) * 1000 / 20
  say(string.format("§8 une décision sur %d bâtiments : %.3f ms (hors jeu)", #big, ms))
  check(ms < 25, "§8 décision sur 600 bâtiments sous 25 ms hors jeu : " .. string.format("%.2f", ms))
end

---------------------------------------------------------------------------------------------------
-- Exécution et MUTANTS
---------------------------------------------------------------------------------------------------
run_all(Am0, true)
local base_fail = fail
say(string.format("règle réelle : %d OK, %d ECHEC(S)", pass, fail))

local function source()
  local f = assert(io.open("shared/ai3/amelioration.lua", "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local function mutate(src, old, new)
  local i, j = src:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  return src:sub(1, i - 1) .. new .. src:sub(j + 1)
end

local MUTANTS = {
  { "niveau maximal du bloc au lieu du minimal (un seul bâtiment poussé)",
    "for _, mb in ipairs(g.members) do if mb.n < m then m = mb.n end end",
    "m = 0; for _, mb in ipairs(g.members) do if mb.n > m then m = mb.n end end" },
  { "tous les blocs fondus en un seul",
    'local block = e.block or "?"', 'local block = "?"' },
  { "plafond du centre ignoré",
    "elseif not Ld.check(fam, m + 1, cc) then", "elseif false then" },
  { "emprise d'un bloc fixe ignorée",
    "elseif g.fixed and Ld.footprint(fam, m) ~= Ld.footprint(fam, m + 1) then", "elseif false then" },
  { "lot limité à un seul bâtiment",
    "Am.BATCH_MAX = 12", "Am.BATCH_MAX = 1" },
  { "la production ne passe plus devant la défense",
    "Am.PROD_PCT = 200", "Am.PROD_PCT = 100" },
  { "objet sans coût connu ignoré (jamais impayable)",
    "if #missing > 0 then\n          row.cause", "if false then\n          row.cause" },
  { "gel total gardé : une reconstruction ouverte retient tout lot",
    "local net = Am.net(ctx.stock, ctx.recon)", "local net = Am.net(ctx.stock, ctx.recon); if ctx.recon then net = {} end" },
  { "la reconstruction ouverte est ignorée (stock brut)",
    "local net = Am.net(ctx.stock, ctx.recon)", "local net = ctx.stock or {}" },
  { "bâtiments refusés seuls gardés dans le lot",
    'if not (ctx.exclude and ctx.exclude["e:" .. mb.id]) then avail[#avail + 1] = mb end', "avail[#avail + 1] = mb" },
}

local survived = {}
for _, m in ipairs(MUTANTS) do
  local src = mutate(source(), m[2], m[3])
  local chunk, err = load(src, "=mutant", "t")
  assert(chunk, "mutant ne compile pas : " .. tostring(err))
  local Am = chunk()
  local before_fail, before_pass = fail, pass
  local before_quiet = quiet
  quiet = true
  local ok, e = pcall(run_all, Am, false)
  quiet = before_quiet
  local caught = (not ok) or fail > before_fail
  fail, pass = before_fail, before_pass -- les contrôles des mutants ne comptent pas dans le bilan du banc
  if caught then
    pass = pass + 1
  else
    survived[#survived + 1] = m[1]
    fail = fail + 1
    print("[AMELIORATION] ECHEC : mutant SURVIVANT : " .. m[1])
  end
  say(string.format("§9 mutant « %s » : %s", m[1], caught and "refusé" or "SURVIVANT"))
end
check(#survived == 0, "§9 tous les mutants sont refusés")

print(string.format("[AMELIORATION] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", pass, fail, #MUTANTS - #survived, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
