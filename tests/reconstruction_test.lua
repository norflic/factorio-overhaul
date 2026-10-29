--[[
  Lot RECONSTRUIRE : test hors jeu de la règle pure shared/team/reconstruction.lua (registre des bâtiments détruits, ordre,
  patience, lots, abandon) et de l'INFRASTRUCTURE ÉLECTRIQUE (valeur d'un poteau = consommateurs coupés, patience courte).
  Repris de tests/couverture_test.lua §7 (branche couverture-reco), sans la règle de couverture des tourelles.
  Usage : lua5.2 tests/reconstruction_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC_REC = read("shared/team/reconstruction.lua")

local function load_mod(name, src)
  local fn, err = load(src, "=" .. name, "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

local function suite(Rc)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  do
    local st = Rc.new()
    check(Rc.pending(st) == 0 and not Rc.hold_upgrades(st), "§7 registre vide : rien en attente, améliorations libres")
    local k1 = Rc.record(st, { name = "A", x = 10, y = 10, dir = 0, item = "ia", value = 8 }, 1000)
    local k2 = Rc.record(st, { name = "B", x = 12, y = 10, dir = 2, item = "ib", value = 1 }, 1010)
    local k3 = Rc.record(st, { name = "C", x = 100, y = 100, dir = 0, item = "ic", value = 5 }, 1020)
    check(Rc.pending(st) == 3 and Rc.hold_upgrades(st), "§7 trois pertes en attente : les améliorations attendent")
    check(#Rc.due(st, 1000 + Rc.CALM - 1) == 0, "§7 patience : rien avant le calme")
    local due = Rc.due(st, 1000 + Rc.CALM + 100)
    check(#due == 3 and due[1].key == k1 and due[2].key == k3 and due[3].key == k2, "§7 ordre par valeur décroissante, puis date")
    -- lot : le plus précieux et ses voisins de 12 tuiles
    local batch = Rc.batch(st, due, due[1], 12, 12)
    check(#batch == 2 and batch[1].key == k1 and batch[2].key == k2, "§7 lot de voisins (rayon 12) : le précieux et sa voisine")
    check(#Rc.batch(st, due, due[1], 1, 12) == 1, "§7 lot borné à 1 : une seule pièce")
    local items = Rc.items(batch)
    check(#items == 2 and items[1][1] == "ia" and items[1][2] == 1 and items[2][1] == "ib", "§7 objets du lot, triés, dénombrés")
    local same = Rc.items({ { item = "ia" }, { item = "ia" }, { item = "zz" } })
    check(same[1][1] == "ia" and same[1][2] == 2 and same[2][1] == "zz", "§7 objets identiques additionnés")
    -- tâche prise : plus proposée
    Rc.claim(st, { k1, k2 }, "tache-1")
    check(#Rc.due(st, 5000) == 1 and Rc.due(st, 5000)[1].key == k3, "§7 les pièces d'une tâche prise ne sont plus proposées")
    Rc.release(st, "tache-1")
    check(#Rc.due(st, 5000) == 3, "§7 tâche abandonnée : ses pièces reviennent")
    Rc.done(st, k1)
    check(Rc.pending(st) == 2, "§7 pièce refaite : retirée")
    -- défèrement
    Rc.defer(st, k3, 6000, 5000)
    check(#Rc.due(st, 5500) == 1 and #Rc.due(st, 6000) == 2, "§7 pièce différée (ennemis près d'elle) jusqu'à la date")
    -- pose refusée par le moteur : abandon après Rc.MAX_BLOCKS refus
    for i = 1, Rc.MAX_BLOCKS do Rc.block(st, k3) end
    check(not st.lost[k3].abandoned, "§7 pose refusée " .. Rc.MAX_BLOCKS .. " fois : encore refaisable")
    Rc.block(st, k3)
    check(st.lost[k3].abandoned == true and Rc.pending(st) == 1, "§7 pose refusée trop souvent : pièce abandonnée")
    -- même place détruite de nouveau : patience doublée, puis abandon
    local st2 = Rc.new()
    local ka = Rc.record(st2, { name = "A", x = 1, y = 1, dir = 0, item = "ia", value = 3 }, 0)
    local c1 = Rc.calm_for(st2.lost[ka])
    Rc.done(st2, ka)
    local kb = Rc.record(st2, { name = "A", x = 1, y = 1, dir = 0, item = "ia", value = 3 }, 100)
    check(kb == ka, "§7 la même place garde la même clé")
    check(st2.lost[kb].losses == 2 and Rc.calm_for(st2.lost[kb]) == 2 * c1, "§7 deuxième destruction au même endroit : patience doublée")
    for i = 1, 10 do
      Rc.done(st2, ka)
      Rc.record(st2, { name = "A", x = 1, y = 1, dir = 0, item = "ia", value = 3 }, 100 + i)
    end
    check(st2.lost[ka].abandoned and #Rc.due(st2, 1e9) == 0 and not Rc.hold_upgrades(st2),
      "§7 détruit trop souvent au même endroit : abandonné, n'empêche plus d'améliorer")
    check(Rc.calm_for({ losses = 99 }) <= Rc.CALM_MAX, "§7 patience bornée")
    -- améliorer attend, mais pas indéfiniment
    local st5 = Rc.new()
    Rc.record(st5, { name = "A", x = 1, y = 1, dir = 0, item = "ia", value = 3 }, 0)
    check(Rc.hold_upgrades(st5, nil, Rc.HOLD_MAX) and not Rc.hold_upgrades(st5, nil, Rc.HOLD_MAX + 1) and Rc.hold_upgrades(st5),
      "§7 une perte qui n'est pas refaite retient les améliorations pendant 20 min au plus (sans date : toujours)")
    -- priorité de tâche
    check(Rc.task_prio(8) > Rc.task_prio(1) and Rc.task_prio(8) < 90 and Rc.task_prio(1) >= 70, "§7 priorité de tâche selon la valeur, sous l'urgence (90)")
    -- purge des anciennes pertes
    local st3 = Rc.new()
    Rc.record(st3, { name = "A", x = 1, y = 1, dir = 0, item = "ia", value = 3 }, 0)
    Rc.prune(st3, Rc.TTL + 1)
    check(Rc.pending(st3) == 0, "§7 une perte jamais refaite finit par être oubliée")
    -- pièce sans objet pour la poser : non proposée
    local st4 = Rc.new()
    Rc.record(st4, { name = "A", x = 1, y = 1, dir = 0, value = 3 }, 0)
    check(#Rc.due(st4, 1e6) == 0, "§7 sans objet pour la poser, une pièce n'est pas proposée")
  end

  -- §7b Infrastructure électrique -------------------------------------------------------------------------
  do
    local st = Rc.new()
    local kp = Rc.record(st, { name = "P", x = 50, y = 50, dir = 0, item = "ip", value = Rc.pole_value(0), infra = true }, 1000)
    local kb = Rc.record(st, { name = "B", x = 80, y = 80, dir = 0, item = "ib", value = Rc.INFRA_VALUE, infra = true }, 1000)
    local kl = Rc.record(st, { name = "L", x = 10, y = 10, dir = 0, item = "il", value = 8 }, 1000)
    check(Rc.calm_for(st.lost[kp]) == Rc.CALM_INFRA and Rc.CALM_INFRA < Rc.CALM, "§7b patience courte pour l'infrastructure")
    check(Rc.calm_for(st.lost[kl]) == Rc.CALM, "§7b patience ordinaire pour le reste")
    check(#Rc.due(st, 1000 + Rc.CALM_INFRA) == 2 and #Rc.due(st, 1000 + Rc.CALM - 1) == 2, "§7b l'infrastructure est due avant le laboratoire")
    local due = Rc.due(st, 1000 + Rc.CALM)
    check(#due == 3 and due[1].key == kb and due[2].key == kl and due[3].key == kp, "§7b centrale avant labo avant poteau sans consommateur coupé")
    st.lost[kp].value = Rc.pole_value(10)
    due = Rc.due(st, 1000 + Rc.CALM)
    check(due[1].key == kb and due[2].key == kp, "§7b un poteau qui coupe 10 consommateurs passe avant le laboratoire")
    check(Rc.pole_value(0) == Rc.POLE_BASE and Rc.pole_value(1000) == Rc.POLE_CAP and Rc.pole_value(3) == Rc.POLE_BASE + 3, "§7b valeur du poteau croissante et bornée")
    check(Rc.POLE_CAP < Rc.INFRA_VALUE and Rc.task_prio(Rc.INFRA_VALUE) <= Rc.PRIO_MAX, "§7b un poteau ne dépasse pas la centrale ; priorité sous l'urgence")
    check(Rc.is_pole_value(st.lost[kp]) and not Rc.is_pole_value(st.lost[kb]) and not Rc.is_pole_value(st.lost[kl]), "§7b seul un poteau relit sa valeur au moteur")
    local c1 = Rc.calm_for(st.lost[kp])
    Rc.done(st, kp)
    local kp2 = Rc.record(st, { name = "P", x = 50, y = 50, dir = 0, item = "ip", value = 2, infra = true }, 1100)
    check(Rc.calm_for(st.lost[kp2]) == 2 * c1, "§7b une deuxième destruction double aussi la patience courte")
  end

  -- §7c Objets à fabriquer pour l'infrastructure -----------------------------------------------------------
  do
    local st = Rc.new()
    for i = 1, 10 do Rc.record(st, { name = "P", x = i, y = 0, dir = 0, item = "ip", value = 2, infra = true }, 1000) end
    Rc.record(st, { name = "B", x = 50, y = 50, dir = 0, item = "ib", value = Rc.INFRA_VALUE, infra = true }, 1000)
    Rc.record(st, { name = "L", x = 70, y = 70, dir = 0, item = "il", value = 8 }, 1000)
    local none = function() return 0 end
    check(#Rc.demand(st, 1000 + Rc.CALM_INFRA - 1, none) == 0, "§7c rien à fabriquer avant la patience")
    local d = Rc.demand(st, 1000 + Rc.CALM_INFRA, none)
    check(#d == 2 and d[1][1] == "ib" and d[1][2] == 1 and d[2][1] == "ip" and d[2][2] == Rc.SPARE_CAP, "§7c chaudière et poteaux demandés, bornés, triés ; pas le laboratoire")
    local dl = Rc.demand(st, 1000 + Rc.CALM, none)
    check(#dl == 2 and dl[1][1] == "ib" and dl[2][1] == "ip", "§7c le laboratoire ordinaire (due aussi) n'est pas fabriqué par cette règle")
    local d2 = Rc.demand(st, 1000 + Rc.CALM_INFRA, function(i) return i == "ip" and 4 or 0 end)
    check(#d2 == 2 and d2[2][2] == Rc.SPARE_CAP - 4, "§7c le stock déjà là est déduit")
    local d3 = Rc.demand(st, 1000 + Rc.CALM_INFRA, function(i) return i == "ip" and 99 or 0 end)
    check(#d3 == 1 and d3[1][1] == "ib", "§7c objet en stock : plus rien à fabriquer pour lui")
    local only = Rc.new()
    Rc.record(only, { name = "P", x = 1, y = 1, dir = 0, item = "ip", value = 2, infra = true }, 0)
    Rc.record(only, { name = "P", x = 2, y = 1, dir = 0, item = "ip", value = 2, infra = true }, 0)
    check(Rc.demand(only, Rc.CALM_INFRA, none)[1][2] == 2, "§7c deux poteaux perdus : deux à fabriquer")
  end

  -- §7d Réparation des pièces endommagées ------------------------------------------------------------------
  do
    local c = {
      { key = "a", x = 0, y = 0, ratio = 0.9 }, { key = "b", x = 2, y = 0, ratio = 0.3 }, { key = "c", x = 4, y = 0, ratio = 0.5 },
      { key = "d", x = 100, y = 0, ratio = 0.1 }, { key = "e", x = 3, y = 3, ratio = 0.59 }, { key = "f", x = 1, y = 1, ratio = 0.61 },
    }
    local out = Rc.repair_batch(c)
    check(#out == 1 and out[1].key == "d", "§7d la plus abîmée est la graine du lot (ses voisines seules l'accompagnent)")
    local out3 = Rc.repair_batch({ c[1], c[2], c[3], c[5], c[6] })
    check(#out3 == 3 and out3[1].key == "b" and out3[2].key == "c" and out3[3].key == "e", "§7d lot : voisines sous le seuil, plus abîmée d'abord")
    check(Rc.repair_batch({ c[1], c[6] }) and #Rc.repair_batch({ c[1], c[6] }) == 0, "§7d au-dessus du seuil (60 %) : rien à réparer")
    local near = {}
    for i = 1, 10 do near[i] = { key = "k" .. i, x = i, y = 0, ratio = 0.2 + i / 100 } end
    check(#Rc.repair_batch(near) == Rc.REPAIR_MAX, "§7d lot borné à Rc.REPAIR_MAX")
    local o2 = Rc.repair_batch({ c[2], c[3], c[5] })
    check(o2[1].key == "b" and o2[2].key == "c" and o2[3].key == "e", "§7d ordre : santé croissante")
    check(Rc.REPAIR_PRIO < Rc.PRIO_BASE, "§7d réparer passe après refaire")
  end

  -- §7e Pièce de remplacement (poteau du meilleur niveau fabricable) ------------------------------------------
  do
    local cands = {
      { name = "petit", item = "ip", supply = 2.5, wire = 7.5 }, { name = "moyen", item = "im", supply = 3.5, wire = 9 },
      { name = "grand", item = "ig", supply = 2, wire = 30 }, { name = "enorme", item = "ie", supply = 7, wire = 64 },
    }
    local function only(...) local set = {} for _, k in ipairs({ ... }) do set[k] = true end return function(c) return set[c.item] end end
    check(Rc.pick_alt(cands, 0, only("ip", "ig")).name == "petit", "§7e meilleur niveau fabricable : la plus grande zone d'alimentation parmi les disponibles")
    check(Rc.pick_alt(cands, 0, only("ie", "im", "ip")).name == "enorme", "§7e le meilleur niveau d'abord")
    check(Rc.pick_alt(cands, 8, only("ip")) == nil, "§7e fil trop court pour les voisins qui restent : pas de remplaçant")
    check(Rc.pick_alt(cands, 8, only("ip", "ig")).name == "grand", "§7e fil assez long : le remplaçant couvrant la portée")
    check(Rc.pick_alt(cands, 0, only()) == nil, "§7e rien de fabricable : nil")
    check(Rc.pick_alt({}, 0, only("ip")) == nil, "§7e aucun candidat : nil")
    local a = Rc.pick_alt({ { name = "b", item = "x", supply = 2, wire = 7 }, { name = "a", item = "y", supply = 2, wire = 7 } }, 0, only("x", "y"))
    check(a.name == "a", "§7e égalité : le nom décide (déterminisme)")
  end

  -- §7f Récolte de la matière naturelle d'un poteau (aucun remplaçant fabricable) ------------------------------
  do
    local cands = {
      { name = "petit", item = "ip", supply = 2.5, wire = 7.5 }, { name = "moyen", item = "im", supply = 3.5, wire = 9 },
      { name = "grand", item = "ig", supply = 2, wire = 30 },
    }
    -- ip : 1 bois manque ; im : 2 acier (non récoltable) ; ig : non fabricable à la main
    local miss = { ip = { bois = 1 }, im = { acier = 2 }, ig = nil }
    local function missing_of(c) return miss[c.item] end
    local function tree(k) return k == "bois" end
    local c, list = Rc.pick_gather(cands, 0, missing_of, tree)
    check(c and c.name == "petit" and #list == 1 and list[1][1] == "bois", "§7f le poteau dont tout le manque se récolte est choisi")
    check(list[1][2] == Rc.GATHER_BATCH, "§7f quantité : au moins un lot (" .. tostring(list[1][2]) .. ")")
    check(Rc.pick_gather(cands, 8, missing_of, tree) == nil, "§7f fil trop court pour les voisins : rien à récolter")
    check(Rc.pick_gather(cands, 0, missing_of, function() return false end) == nil, "§7f rien de récoltable : pas de tâche")
    check(Rc.pick_gather(cands, 0, function(c2) return c2.item == "im" and { acier = 2 } or nil end, tree) == nil,
      "§7f l'acier ne se coupe pas : récolter ne débloquerait rien")
    check(Rc.pick_gather(cands, 0, function() return { bois = 1, acier = 1 } end, tree) == nil, "§7f une seule matière non récoltable écarte le candidat")
    check(Rc.pick_gather({}, 0, missing_of, tree) == nil, "§7f aucun candidat : nil")
    check(Rc.pick_gather(cands, 0, function() return {} end, tree) == nil, "§7f rien ne manque : rien à récolter")
    -- le moins de manque d'abord, puis la plus grande zone, puis le nom
    local m2 = { ip = { bois = 5 }, ig = { bois = 2 } }
    local c2 = Rc.pick_gather(cands, 0, function(x) return m2[x.item] end, tree)
    check(c2 and c2.name == "grand", "§7f le moins de manque d'abord")
    local m3 = { ip = { bois = 3 }, im = { bois = 3 } }
    local c3 = Rc.pick_gather(cands, 0, function(x) return m3[x.item] end, tree)
    check(c3 and c3.name == "moyen", "§7f à manque égal, la plus grande zone d'alimentation")
    check(Rc.gather_qty(1) == Rc.GATHER_BATCH and Rc.gather_qty(15) == 15 and Rc.gather_qty(500) == Rc.GATHER_MAX, "§7f quantité bornée")
    local m4 = { ip = { bois = 30 } }
    local _, l4 = Rc.pick_gather(cands, 0, function(x) return m4[x.item] end, tree)
    check(l4 and l4[1][2] == Rc.GATHER_MAX, "§7f quantité plafonnée dans la tâche")
    local m6 = { ip = { bois = 1, acier = 0 } }
    local c6, l6 = Rc.pick_gather(cands, 0, function(x) return m6[x.item] end, tree)
    check(c6 and #l6 == 1 and l6[1][1] == "bois", "§7f une matière à 0 manquant ne compte pas")
    local m5 = { ip = { bois = 1, cuivre = 1 } }
    local _, l5 = Rc.pick_gather(cands, 0, function(x) return m5[x.item] end, function() return true end)
    check(l5 and #l5 == 2 and l5[1][1] == "bois" and l5[2][1] == "cuivre", "§7f liste triée par objet")
  end

  return pass, fail, msgs
end

local Rc0 = assert(load_mod("reconstruction", SRC_REC))
package.loaded["shared.team.reconstruction"] = Rc0
local pass, fail, msgs = suite(Rc0)
for _, m in ipairs(msgs) do print("[RECONSTRUIRE] ECHEC : " .. m) end

-- §8 Source : aucun nom du jeu, aucun hasard, aucun pairs, aucune trigonométrie
do
  local code = SRC_REC:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local clean = not code:find("[^i]pairs%(") and not code:find("math.random", 1, true) and not code:find("math.sin", 1, true)
    and not code:find("math.cos", 1, true) and not code:find("math.atan", 1, true) and not code:find("os.time", 1, true)
    and not code:find("%f[%w_]game%f[^%w_]") and not code:find("%f[%w_]global%f[^%w_]")
  if clean then pass = pass + 1 else fail = fail + 1 print("[RECONSTRUIRE] ECHEC : pairs, hasard, trigonométrie, game ou global") end
  local named = false
  for _, it in ipairs({ "gun-turret", "iron-plate", "lab", "stone-furnace", "iron-chest", "transport-belt", "small-electric-pole", "boiler" }) do
    if code:find('"' .. it .. '"', 1, true) then named = true end
  end
  if not named then pass = pass + 1 else fail = fail + 1 print("[RECONSTRUIRE] ECHEC : nomme un objet du jeu") end
end

-- §9 Mutants
local MUTANTS = {
  { "sans patience", "if tick - r.tick >= Rc.calm_for(r) then", "if true then" },
  { "patience fixe", "return math.min(Rc.CALM_MAX, (r.infra and Rc.CALM_INFRA or Rc.CALM) * (2 ^ (r.losses - 1)))", "return Rc.CALM" },
  { "patience infra ordinaire", "(r.infra and Rc.CALM_INFRA or Rc.CALM)", "Rc.CALM" },
  { "jamais d'abandon", "if r.losses > Rc.MAX_LOSSES then r.abandoned = true end", "" },
  { "ordre sans valeur", "if a.value ~= b.value then return a.value > b.value end", "" },
  { "tâche prise toujours proposée", "if not r.claimed and not r.abandoned", "if not r.abandoned" },
  { "pièce différée proposée", "and (not r.retry or tick >= r.retry)", "" },
  { "lot sans rayon", "if #out < max and (r == seed or d2(r, seed) <= radius * radius) then", "if #out < max then" },
  { "oubli jamais", "if tick - r.tick > Rc.TTL then st.lost[k] = nil end", "" },
  { "objets non additionnés", "n[r.item] = (n[r.item] or 0) + 1", "n[r.item] = 1" },
  { "attente des améliorations sans limite", "and (not tick or tick - r.tick <= Rc.HOLD_MAX) then return true end", "then return true end" },
  { "priorité sans valeur", "return math.min(Rc.PRIO_MAX, Rc.PRIO_BASE + value)", "return Rc.PRIO_BASE" },
  { "poteau sans plafond", "math.min(Rc.POLE_CAP - Rc.POLE_BASE, cut or 0)", "(cut or 0)" },
  { "poteau sans consommateurs coupés", "Rc.POLE_BASE + math.max(0, math.min(Rc.POLE_CAP - Rc.POLE_BASE, cut or 0))", "Rc.POLE_BASE" },
  { "infra non marquée", "infra = rec.infra or nil,", "" },
  { "demande non bornée", "math.min(Rc.SPARE_CAP, need[item]) - have(item)", "need[item] - have(item)" },
  { "demande du stock ignoré", "math.min(Rc.SPARE_CAP, need[item]) - have(item)", "math.min(Rc.SPARE_CAP, need[item])" },
  { "demande aussi hors infrastructure", "if r.infra then need[r.item] = (need[r.item] or 0) + 1 end", "need[r.item] = (need[r.item] or 0) + 1" },
  { "réparation sans seuil", "if c.ratio * 100 < (below or Rc.REPAIR_BELOW) then low[#low + 1] = c end", "low[#low + 1] = c" },
  { "réparation sans rayon", "if #out < Rc.REPAIR_MAX and (c == seed or ((c.x - seed.x) ^ 2 + (c.y - seed.y) ^ 2) <= Rc.BATCH_RADIUS * Rc.BATCH_RADIUS) then", "if #out < Rc.REPAIR_MAX then" },
  { "réparation sans plus abîmée d'abord", "if a.ratio ~= b.ratio then return a.ratio < b.ratio end", "" },
  { "remplaçant sans fil suffisant", "if c.wire >= (reach or 0) and can(c) then return c end", "if can(c) then return c end" },
  { "remplaçant sans disponibilité", "if c.wire >= (reach or 0) and can(c) then return c end", "if c.wire >= (reach or 0) then return c end" },
  { "remplaçant : moins bon niveau", "if a.supply ~= b.supply then return a.supply > b.supply end", "if a.supply ~= b.supply then return a.supply < b.supply end" },
  { "récolte : fil ignoré", "if c.wire >= (reach or 0) then", "if true then" },
  { "récolte : matière non récoltable acceptée", "if not harvestable(k) then ok = false break end", "" },
  { "récolte : rien à récolter accepté", "if ok and #out > 0 and (not best or total < best_total)", "if ok and (not best or total < best_total)" },
  { "récolte : plus de manque d'abord", "(not best or total < best_total)", "(not best or total > best_total)" },
  { "récolte : sans plafond", "return math.min(Rc.GATHER_MAX, math.max(Rc.GATHER_BATCH, n or 0))", "return math.max(Rc.GATHER_BATCH, n or 0)" },
  { "récolte : sans lot minimal", "return math.min(Rc.GATHER_MAX, math.max(Rc.GATHER_BATCH, n or 0))", "return math.min(Rc.GATHER_MAX, n or 0)" },
  { "récolte : manque nul compté", "if miss[k] > 0 then", "if true then" },
  { "pose refusée sans abandon", "if r.blocks > Rc.MAX_BLOCKS then r.abandoned = true end", "" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC_REC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local mod = load_mod("mut", SRC_REC:sub(1, a - 1) .. m[3] .. SRC_REC:sub(b + 1))
    local f2 = 1
    if mod then
      local ok, _, ff = pcall(suite, mod)
      f2 = ok and ff or 1
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
package.loaded["shared.team.reconstruction"] = Rc0
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[RECONSTRUIRE] ECHEC : mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[RECONSTRUIRE] mutants refusés : %d sur %d", refused, #MUTANTS))
print(string.format("[RECONSTRUIRE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
