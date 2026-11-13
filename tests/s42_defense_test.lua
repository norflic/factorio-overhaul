--[[
  Lot S42-DEFENSE (chantier 6 du DC). Banc HORS JEU. Lancement, depuis la racine du mod : lua5.2 tests/s42_defense_test.lua
    1. budget de défense dynamique (shared/ai3/budget_defense.lua) et son entrée dans la capitalisation et la famille armée ;
    2. nids sous le nuage (shared/ai3/nids_nuage.lua) ;
    3. tracé de l'enceinte (shared/ai3/enceinte.lua) ;
    4. câblage (lecture des sources) ;
    5. mutants : le texte de la règle est remplacé, le banc doit échouer.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end
local function load_mod(path, mutate)
  local src = slurp(path)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. path)
  if not fn then return nil, err end
  return fn()
end

local Ca = require("shared.ai3.capitalisation")
local Fa = require("shared.ai3.famille_armee")

---------------------------------------------------------------------------------------------------
-- 1. Budget de défense dynamique
---------------------------------------------------------------------------------------------------
local function battery_bd(Bd)
  local st = Bd.new()
  check(Bd.share(st, 0) == 50, "1 : au calme, la part est la base (50 pour mille)")
  check(Bd.share(st, 999999) == 50, "1 : au calme, la part reste la base quel que soit le tick")
  check(Bd.tier(Bd.share(st, 0)) == "base", "1 : palier base au calme")
  -- un mur ne pèse rien
  Bd.note(st, 100, "mur")
  check(Bd.share(st, 100) == 50, "1 : un mur perdu ne monte pas la part")
  -- une pièce ordinaire : 1 / 12
  Bd.note(st, 1000, "piece")
  check(Bd.share(st, 1000) == 50 + math.floor(900 / 12), "1 : une piece ordinaire : 50 + 900 / 12")
  check(Bd.tier(Bd.share(st, 1000)) == "alerte", "1 : palier alerte apres une perte")
  check(Bd.share(st, 1000 + 3000) == 50, "1 : une perte isolee rend la main en 50 s")
  check(Bd.calm_in(st, 1000) == 3000, "1 : calme dans 3000 ticks apres une piece")
  -- classe inconnue : pièce ordinaire
  local s2 = Bd.new()
  Bd.note(s2, 0, "inconnue")
  check(Bd.level(s2, 0) == 1, "1 : classe inconnue comptee comme une piece")
  -- trois pièces critiques coup sur coup : niveau plein
  local s3 = Bd.new()
  Bd.note(s3, 0, "critique")
  check(Bd.share(s3, 0) == 350, "1 : une piece critique : 350 pour mille")
  Bd.note(s3, 0, "critique") Bd.note(s3, 0, "critique")
  check(Bd.share(s3, 0) == 950, "1 : trois pieces critiques : 950 pour mille")
  check(Bd.tier(950) == "crise", "1 : palier crise")
  for _ = 1, 20 do Bd.note(s3, 0, "critique") end
  check(Bd.share(s3, 0) == 950 and Bd.level(s3, 0) == 12, "1 : le niveau est plafonne (pas de dette de calme au-dela)")
  -- décroissance linéaire, retour à la base au plus tard à CALM
  check(Bd.share(s3, 5 * 3600) == 500, "1 : a mi-chemin du calme, 500 pour mille")
  check(Bd.share(s3, 10 * 3600) == 50, "1 : dix minutes sans perte : retour a la base")
  check(Bd.share(s3, 10 * 3600 - 1) > 50 or Bd.level(s3, 10 * 3600 - 1) > 0, "1 : pas avant")
  local prev = 1000
  local mono = true
  for t = 0, 10 * 3600, 600 do
    local s = Bd.share(s3, t)
    if s > prev then mono = false end
    prev = s
  end
  check(mono, "1 : sans perte nouvelle, la part ne remonte jamais")
  -- une perte pendant la descente repart du niveau courant, pas du niveau noté
  Bd.note(s3, 5 * 3600, "piece")
  check(Bd.level(s3, 5 * 3600) == 7, "1 : la perte s'ajoute au niveau deja redescendu (6 + 1)")
  -- tick en arrière (état d'une sauvegarde) : pas de niveau négatif ni d'erreur
  check(Bd.level({ v = 3, t = 1000 }, 0) == 3, "1 : tick anterieur : niveau garde")
  check(Bd.level(nil, 0) == 0 and Bd.level({}, 0) == 0, "1 : etat absent ou vide : niveau nul")
  -- déterminisme
  local a, b = Bd.new(), Bd.new()
  for i = 1, 30 do Bd.note(a, i * 97, i % 3 == 0 and "critique" or "piece") Bd.note(b, i * 97, i % 3 == 0 and "critique" or "piece") end
  check(a.v == b.v and a.t == b.t and Bd.share(a, 5000) == Bd.share(b, 5000), "1 : deux deroules identiques, meme etat")
  -- bornes
  for t = 0, 40000, 1000 do
    local s = Bd.share(a, t)
    if not (s >= Bd.BASE and s <= Bd.MAX and s == math.floor(s)) then check(false, "1 : part hors bornes ou non entiere a " .. t) end
  end
end
local Bd = load_mod("shared/ai3/budget_defense.lua")
battery_bd(Bd)

-- 1 bis. Entrée dans la capitalisation
do
  local ch0 = Ca.character({}, {}, false, false)
  local chn = Ca.character({}, {}, false, false, nil)
  check(ch0.delta == chn.delta and ch0.alpha == chn.alpha and ch0.s == chn.s, "1b : sans part mesuree, la decision d'avant")
  check(ch0.delta == 100, "1b : part du caractere d'avant = 100 pour mille (temoin)")
  local c50 = Ca.character({}, {}, false, false, 50)
  check(c50.delta == 50 and c50.alpha == ch0.alpha, "1b : part mesuree 50 : delta 50, armee inchangee")
  check(Ca.character({}, {}, true, false, 50).delta == 50, "1b : la menace ne double plus une part mesuree")
  local c950 = Ca.character({}, {}, true, false, 950)
  check(c950.delta == 950 and c950.alpha == 0, "1b : en crise, la defense prend 950 et l'armee cede")
  local c700 = Ca.character({}, {}, false, false, 700)
  check(c700.delta == 700 and c700.alpha == 100, "1b : au-dessus du plafond commun, l'armee garde le reste (800 - 700)")
  check(Ca.character({}, {}, false, true, 950).delta == 0, "1b : production d'abord l'emporte toujours (survie)")
  check(Ca.character({}, {}, false, false, 5000).delta == 1000 and Ca.character({}, {}, false, false, -5).delta == 0, "1b : part bornee a 0..1000")
  check(Ca.character({}, {}, false, false, 0 / 0).delta == 100, "1b : part illisible : regle d'avant")
  for _, sh in ipairs({ 0, 50, 350, 800, 950, 1000 }) do
    local c = Ca.character({ agressivite = 2000 }, {}, false, false, sh)
    check(c.delta + c.alpha <= 1000 and c.alpha >= 0, "1b : defense + armee <= 1000 a " .. sh)
    local b = Ca.budget(c, 100, 1000, 1, 0)
    check(b >= 0, "1b : budget jamais negatif a " .. sh)
  end
  -- au calme, l'économie garde plus qu'avant ; en crise, presque rien
  local calm = Ca.budget(c50, 100, 0, 1, 0)
  local before = Ca.budget(ch0, 100, 0, 1, 0)
  local crisis = Ca.budget(c950, 100, 0, 1, 0)
  check(calm >= before, "1b : au calme la part de base n'affame pas l'economie (budget >= celui d'avant)")
  check(crisis < calm / 10, "1b : en crise le budget d'investissement s'efface devant la defense")
  -- famille armée : plafond relevé seulement quand la part est mesurée
  check(Fa.share({ delta = 950, alpha = 0 }) == Fa.SHARE_MAX, "1b : famille armee, plafond d'avant sans max")
  check(Fa.share({ delta = 950, alpha = 0, max = 1000 }) == 950, "1b : famille armee, la reserve suit la part mesuree")
  check(Fa.share({ delta = 50, alpha = 150, max = 1000 }) == 200, "1b : famille armee au calme : 200 pour mille")
  check(Fa.share({ delta = 900, alpha = 300, max = 1000 }) == 1000, "1b : famille armee, jamais plus de 1000")
end

---------------------------------------------------------------------------------------------------
-- 2. Nids sous le nuage
---------------------------------------------------------------------------------------------------
local function battery_nn(Nn)
  local sites = { { x = 0, y = 0 }, { x = 300, y = 0 } }
  local cands = {
    { x = 100, y = 0, p = 40 },   -- sous le nuage, à 100 du QG
    { x = 50, y = 50, p = 0 },    -- hors du nuage
    { x = 320, y = 10, p = 5 },   -- sous le nuage, près du second site
    { x = 900, y = 0, p = 80 },   -- trop loin de tout site
    { x = 101, y = 1, p = 40 },   -- le même nid que le premier (à moins de 3 tuiles)
    { x = -60, y = 0, p = 2 },
    { x = 0, y = 120, p = 2 },
    { x = 0, y = -130, p = 2 },
  }
  local out = Nn.pick(cands, sites, {}, 224)
  check(#out == 4, "2 : au plus quatre nids nouveaux par passage (" .. #out .. ")")
  check(out[1].x == 320 and out[1].y == 10, "2 : le plus proche d'un site d'abord")
  check(out[2].x == -60 and out[3].x == 100 and out[4].y == 120, "2 : ordre par distance au site le plus proche")
  for _, o in ipairs(out) do
    check(o.p >= 1, "2 : jamais un nid hors du nuage")
    check(not (o.x == 900), "2 : jamais un nid hors de portee")
    check(not (o.x == 101), "2 : un nid n'est pas compte deux fois")
  end
  local out2 = Nn.pick(cands, sites, { { x = 320, y = 10 }, { x = -61, y = 1 } }, 224)
  check(out2[1].x == 100 and #out2 == 3, "2 : un nid deja connu n'est pas redit")
  check(#Nn.pick({}, sites, {}, 224) == 0 and #Nn.pick(nil, nil, nil, nil) == 0, "2 : rien a relever : liste vide")
  check(#Nn.pick(cands, {}, {}, 224) == 0, "2 : sans site, rien")
  check(#Nn.pick({ { x = 10, y = 10 } }, sites, {}, 224) == 0, "2 : pollution illisible : pas sous le nuage")
  -- déterminisme : l'ordre d'entrée ne change pas la sortie
  local rev = {}
  for i = #cands, 1, -1 do if i ~= 5 then rev[#rev + 1] = cands[i] end end
  local fwd = {}
  for i = 1, #cands do if i ~= 5 then fwd[#fwd + 1] = cands[i] end end
  local o1, o2 = Nn.pick(fwd, sites, {}, 224), Nn.pick(rev, sites, {}, 224)
  local same = #o1 == #o2
  for i = 1, #o1 do if same and (o1[i].x ~= o2[i].x or o1[i].y ~= o2[i].y) then same = false end end
  check(same, "2 : sortie independante de l'ordre d'entree")
  -- tour de rôle
  check(Nn.site_index(0, 3) == 1 and Nn.site_index(1, 3) == 2 and Nn.site_index(2, 3) == 3 and Nn.site_index(3, 3) == 1, "2 : tour de role des sites")
  check(Nn.site_index(5, 0) == nil and Nn.site_index(nil, 2) == 1, "2 : tour de role, bornes")
end
local Nn = load_mod("shared/ai3/nids_nuage.lua")
battery_nn(Nn)

---------------------------------------------------------------------------------------------------
-- 3. Enceinte
---------------------------------------------------------------------------------------------------
local function in_box(b, x, y, m) return x >= b.x1 - m and x < b.x2 + m and y >= b.y1 - m and y < b.y2 + m end
local function battery_en(En)
  -- base carrée + gisement accolé en L + avant-poste détaché
  local base = { x1 = 0, y1 = 0, x2 = 40, y2 = 30 }
  local ore = { x1 = 40, y1 = 20, x2 = 70, y2 = 60 }
  local boxes = { base, ore }
  local plan, why = En.plan(boxes, { center = { x = 20, y = 15 } })
  check(plan ~= nil, "3 : trace rendu (" .. tostring(why) .. ")")
  if not plan then return end
  check(#plan.walls > 0 and #plan.gates > 0 and #plan.turrets > 0, "3 : murs, portes et tourelles")
  check(En.closed(boxes, plan), "3 : enceinte fermee (murs + portes), en L")
  local bad_wall, bad_gap = 0, 0
  for _, l in ipairs({ plan.walls, plan.gates }) do
    for _, c in ipairs(l) do
      for _, b in ipairs(boxes) do
        if in_box(b, c.x, c.y, 0) then bad_wall = bad_wall + 1 end
        if in_box(b, c.x, c.y, En.MARGIN) then bad_gap = bad_gap + 1 end
      end
    end
  end
  check(bad_wall == 0, "3 : aucun mur sur un batiment ni sur le minerai")
  check(bad_gap == 0, "3 : la marge interieure est tenue (aucun mur a moins de " .. En.MARGIN .. " tuiles)")
  -- tourelles : à l'intérieur du mur, hors des bâtiments et du minerai
  local wall = {}
  for _, l in ipairs({ plan.walls, plan.gates }) do for _, c in ipairs(l) do wall[c.x .. "," .. c.y] = true end end
  local t_bad = 0
  for _, t in ipairs(plan.turrets) do
    local within = false
    for _, b in ipairs(boxes) do
      if in_box(b, t.x, t.y, 0) then t_bad = t_bad + 1 end
      if in_box(b, t.x, t.y, En.MARGIN) then within = true end
    end
    if not within or wall[t.x .. "," .. t.y] then t_bad = t_bad + 1 end
  end
  check(t_bad == 0, "3 : tourelles dans la bande interieure, jamais sur le minerai ni sur le mur")
  -- une tourelle au moins de chaque côté
  local side = { n = 0, s = 0, e = 0, w = 0 }
  for _, t in ipairs(plan.turrets) do
    if t.y < 0 then side.n = side.n + 1 end
    if t.y >= 60 then side.s = side.s + 1 end
    if t.x < 0 then side.w = side.w + 1 end
    if t.x >= 70 then side.e = side.e + 1 end
  end
  check(side.n > 0 and side.s > 0 and side.e > 0 and side.w > 0, "3 : des tourelles sur les quatre cotes")
  -- portes : sur la ligne et la colonne du centre, des deux côtés
  local gn, gs, gw, ge = 0, 0, 0, 0
  for _, c in ipairs(plan.gates) do
    if c.y < 0 then gn = gn + 1 end
    if c.y > 30 then gs = gs + 1 end
    if c.x < 0 then gw = gw + 1 end
    if c.x > 40 then ge = ge + 1 end
  end
  check(gn >= En.GATE_W and gs >= En.GATE_W and gw >= En.GATE_W and ge >= En.GATE_W, "3 : une porte par cote au moins")
  local nog = En.plan(boxes, { gates = false })
  check(#nog.gates == 0 and #nog.walls == #plan.walls + #plan.gates, "3 : sans porte, les memes cases en murs")
  -- tri et déterminisme
  local sorted = true
  for i = 2, #plan.walls do
    local a, b = plan.walls[i - 1], plan.walls[i]
    if a.y > b.y or (a.y == b.y and a.x >= b.x) then sorted = false end
  end
  check(sorted, "3 : murs tries (y puis x), sans doublon")
  local p2 = En.plan({ ore, base }, { center = { x = 20, y = 15 } })
  local same = #p2.walls == #plan.walls and #p2.turrets == #plan.turrets
  for i = 1, #plan.walls do if same and (p2.walls[i].x ~= plan.walls[i].x or p2.walls[i].y ~= plan.walls[i].y) then same = false end end
  check(same, "3 : l'ordre des rectangles ne change pas le trace")
  -- rectangle seul : périmètre attendu
  local one = En.plan({ { x1 = 0, y1 = 0, x2 = 10, y2 = 10 } }, { gates = false })
  local side_len = 10 + 2 * En.MARGIN
  check(#one.walls == 4 * side_len + 4, "3 : carre seul : anneau de " .. (4 * side_len + 4) .. " cases (" .. #one.walls .. ")")
  check(En.closed({ { x1 = 0, y1 = 0, x2 = 10, y2 = 10 } }, one), "3 : carre seul ferme")
  -- avant-poste détaché : deux enceintes, fermées toutes les deux
  local far = { base, { x1 = 200, y1 = 200, x2 = 220, y2 = 220 } }
  local pf = En.plan(far, { gates = false })
  check(En.closed(far, pf), "3 : base et avant-poste detache : fermes")
  -- cour intérieure : pas de mur dedans
  local court = { { x1 = 0, y1 = 0, x2 = 100, y2 = 10 }, { x1 = 0, y1 = 90, x2 = 100, y2 = 100 }, { x1 = 0, y1 = 0, x2 = 10, y2 = 100 }, { x1 = 90, y1 = 0, x2 = 100, y2 = 100 } }
  local pc = En.plan(court, { gates = false })
  local inner = 0
  for _, c in ipairs(pc.walls) do if c.x > 20 and c.x < 80 and c.y > 20 and c.y < 80 then inner = inner + 1 end end
  check(inner == 0 and En.closed(court, pc), "3 : cour interieure fermee : aucun mur dedans")
  -- un trou dans le mur ouvre l'enceinte ; la reconstruction le rend
  local broken = { walls = {}, gates = plan.gates }
  for i, c in ipairs(plan.walls) do if i ~= 7 then broken.walls[#broken.walls + 1] = c end end
  check(not En.closed(boxes, broken), "3 : un mur manquant : enceinte ouverte")
  local hole = plan.walls[7]
  local miss = En.missing(plan.walls, function(x, y) return not (x == hole.x and y == hole.y) end)
  check(#miss == 1 and miss[1].x == hole.x and miss[1].y == hole.y, "3 : reconstruction : la case manquante, elle seule")
  check(#En.missing(plan.walls, function() return false end, 5) == 5, "3 : reconstruction bornee par passage")
  check(#En.missing(plan.walls, function() return true end) == 0, "3 : rien a refaire quand tout est pose")
  -- obstacle naturel : la case est retirée, et comptée comme fermée
  local water = function(x, y) return y < -3 end
  local pw = En.plan(boxes, { blocked = water, gates = false })
  local wet = 0
  for _, c in ipairs(pw.walls) do if water(c.x, c.y) then wet = wet + 1 end end
  check(wet == 0 and #pw.walls < #nog.walls, "3 : aucun mur sur une case impossible")
  check(En.closed(boxes, pw, { extra = water }) and not En.closed(boxes, pw), "3 : l'obstacle naturel ferme le trace")
  -- bornes
  local big, wb = En.plan({ { x1 = 0, y1 = 0, x2 = 5000, y2 = 10 } })
  check(big == nil and type(wb) == "string", "3 : emprise trop grande : refus ecrit")
  local none, wn = En.plan({})
  check(none == nil and type(wn) == "string", "3 : aucun rectangle : refus ecrit")
  local tiny = En.plan({ { x1 = 0, y1 = 0, x2 = 4, y2 = 4 } }, { margin = 0, gates = false })
  check(tiny ~= nil and En.closed({ { x1 = 0, y1 = 0, x2 = 4, y2 = 4 } }, tiny, { margin = 0 }), "3 : marge trop petite relevee au minimum")
end
local En = load_mod("shared/ai3/enceinte.lua")
battery_en(En)

---------------------------------------------------------------------------------------------------
-- 4. Câblage (lecture des sources)
---------------------------------------------------------------------------------------------------
do
  local cmd = slurp("script/faction/commander.lua")
  check(cmd:find("BdRt.note(f, entity, e.tick)", 1, true) ~= nil, "4 : le commandant note chaque perte d'une faction")
  local capi = slurp("script/ai3/capitalisation.lua")
  check(capi:find("def_share = def_share", 1, true) ~= nil and capi:find("BdRt.share(f, tick)", 1, true) ~= nil, "4 : la decision recoit la part mesuree")
  local cap = slurp("shared/ai3/capitalisation.lua")
  check(cap:find("input.production_first, input.def_share)", 1, true) ~= nil, "4 : Ca.decide passe la part a Ca.character")
  local pil = slurp("script/ai3/pilotage.lua")
  check(pil:find("capi.def_dyn and 1000", 1, true) ~= nil, "4 : la famille armee suit la part mesuree")
  local prev = slurp("script/ai3/prevision.lua")
  check(prev:find("Nn.pick(cands, sites, known, Pv.R_ATTR)", 1, true) ~= nil and prev:find('D.mark_seen(team_map, n.x, n.y, "spawner", nil, tick)', 1, true) ~= nil,
    "4 : la prevision fait connaitre les nids sous le nuage")
  for _, p in ipairs({ "shared/ai3/budget_defense.lua", "shared/ai3/nids_nuage.lua", "shared/ai3/enceinte.lua", "script/ai3/budget_defense.lua" }) do
    local src = slurp(p)
    check(src:find("global%.") == nil and src:find("pairs%(") == nil or src:find("ipairs%(") ~= nil and src:find("[^i]pairs%(") == nil,
      "4 : " .. p .. " : ni global ni pairs")
  end
  for _, p in ipairs({ "shared/ai3/budget_defense.lua", "shared/ai3/nids_nuage.lua", "shared/ai3/enceinte.lua" }) do
    local src = slurp(p)
    check(src:find("game%.") == nil and src:find("defines%.") == nil and src:find("require%(") == nil, "4 : " .. p .. " : Lua pur, sans dependance")
  end
end

---------------------------------------------------------------------------------------------------
-- 5. Mutants
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "shared/ai3/budget_defense.lua", battery_bd, "v = v - Bd.FULL * dt / Bd.CALM", "v = v" },                       -- la part ne redescend plus
  { "shared/ai3/budget_defense.lua", battery_bd, "Bd.BASE = 50 ", "Bd.BASE = 250" },                                -- base trop haute
  { "shared/ai3/budget_defense.lua", battery_bd, "if v > Bd.FULL then v = Bd.FULL end\n  st.v", "st.v" },           -- niveau non plafonné
  { "shared/ai3/budget_defense.lua", battery_bd, "mur = 0", "mur = 1" },                                            -- un mur pèse
  { "shared/ai3/nids_nuage.lua", battery_nn, "p >= Nn.P_MIN", "p >= -1" },                                          -- nid hors du nuage
  { "shared/ai3/nids_nuage.lua", battery_nn, "if a.dd ~= b.dd then return a.dd < b.dd end", "" },                   -- ordre perdu
  { "shared/ai3/nids_nuage.lua", battery_nn, "while #out > Nn.MAX_NEW do out[#out] = nil end", "" },                -- non borné
  { "shared/ai3/enceinte.lua", battery_en, "if (dx ~= 0 or dy ~= 0) and inside(g, x + dx, y + dy) then touch = true end",
    "if (dx == 0 or dy == 0) and (dx ~= 0 or dy ~= 0) and inside(g, x + dx, y + dy) then touch = true end" },       -- coins ouverts
  { "shared/ai3/enceinte.lua", battery_en, "local gi = grid_of(boxes, m - En.TURRET_GAP - 1)", "local gi = grid_of(boxes, m + 2)" }, -- tourelles hors du mur
  { "shared/ai3/enceinte.lua", battery_en, "if not present(c.x, c.y) then", "if present(c.x, c.y) then" },          -- reconstruction inversée
}
local p0 = passes
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local mod, err = load_mod(m[1], { m[3], m[4] })
  local dead = false
  if not mod then
    if tostring(err):find("texte introuvable", 1, true) then quiet = false; check(false, "5 : " .. tostring(err)); quiet = true else dead = true end
  else
    local fb = failures
    local ok = pcall(m[2], mod)
    if not ok or failures > fb then dead = true end
    failures = fb
  end
  if dead then killed = killed + 1 else quiet = false; check(false, "5 : mutant survivant : " .. m[3]); quiet = true end
end
quiet = false
passes = p0
check(killed == #MUTANTS, string.format("5 : mutants refuses %d / %d", killed, #MUTANTS))

print(string.format("[S42-DEFENSE] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
