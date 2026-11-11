--[[
  Lot RACCORD-BANDE (partie neuve 0.6.72, INTEG-0672 : « champ: 1 composante(s) de poteaux (11 poteaux) sans chaine jusqu'au reseau alimente »,
  projets 4 à 6, puis « migration abandonnee apres 3 echec(s) de suite ») : shared/team/champ_raccord.lua, Ra.tiered_chain.
  Une bande à ~100 tuiles du réseau alimenté, au milieu du minerai et des thermiques : l'ancienne boîte (poteaux + cible + 8 tuiles, minerai interdit
  hors des rangées de la bande) ne donnait aucune chaîne. Maintenant : boîte étroite, puis AUTOUR (boîte large), puis À TRAVERS le minerai.
    §1 le cas d'avant : sol libre -> palier 1 (comportement inchangé) ;
    §2 minerai en travers, un contournement existe : « autour », aucun poteau sur le minerai hors des rangées de la bande ;
    §3 minerai partout : « a travers le minerai » ; les tuiles occupées (thermiques) ne sont jamais prises ;
    §4 mur de tuiles occupées : aucun palier ne passe (refus), le dernier palier est nommé ;
    §5 la bande entière (Ra.connect, 11 poteaux) est raccordée là où l'ancienne règle (palier 1 seul) laissait « sans chaine » ;
    §6 coût borné (debug.sethook, pire cas : aucune chaîne) ; §7 mutants.
  Usage : lua5.2 tests/raccord_bande_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local P = require("shared.team.plan")

local passes, failures = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end
local function read(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end
local SRC = read("shared/team/champ_raccord.lua")
local function load_ra(src) return assert(load(src, "=champ_raccord(variante)"))() end
local Ra = load_ra(SRC)

local R = 7.5
local function key(x, y) return (x + 50000) * 100000 + (y + 50000) end

--- Une carte : rectangles de minerai et de tuiles occupées ; le centre de la bande est (110, 5), le réseau alimenté (0, 0).
local function world(ore_rects, block_rects)
  -- ensembles précalculés (comme le moteur : lectures de tables, pas de parcours de rectangles) : le coût mesuré est celui de la règle
  local function set_of(rects)
    local s = {}
    for _, r in ipairs(rects) do for x = r[1], r[3] do for y = r[2], r[4] do s[key(x, y)] = true end end end
    return s
  end
  local ore_s, blk_s = set_of(ore_rects), set_of(block_rects)
  return {
    ore = function(x, y) return ore_s[key(x, y)] == true end,
    blocked = function(x, y) return blk_s[key(x, y)] == true end,
  }
end

--- Paramètres de Ra.tiered_chain pour la carte `w` ; rangées de la bande : la bande de colonnes x de 100 à 115 (axe y : perpendiculaire à la route vers le réseau). reads = compteur de lectures du moteur par marge.
local function params(w, used, reads, hull)
  return { hull = hull or { x0 = 0, y0 = 0, x1 = 110, y1 = 5 }, reach = R, pole_chain = P.pole_chain, key = key, used = used or {},
    blocked = function(margin)
      if reads then reads[margin] = (reads[margin] or 0) + 1 end
      return w.blocked
    end,
    ore = w.ore, rows = function(x, y) return x >= 100 and x <= 115 end }
end

local A, B = { x = 110, y = 5 }, { x = 0, y = 0 }

--- La chaîne est valide : chaque pas à portée, aucun poteau sur une tuile occupée, ni deux sur la même tuile.
local function valid(ch, w, a, b, allow_ore)
  local pts = { a }
  for _, c in ipairs(ch) do pts[#pts + 1] = c end
  pts[#pts + 1] = b
  local seen = {}
  for i = 1, #pts - 1 do
    local dx, dy = pts[i].x - pts[i + 1].x, pts[i].y - pts[i + 1].y
    if dx * dx + dy * dy > R * R + 1e-6 then return false, "pas trop long" end
  end
  for _, c in ipairs(ch) do
    local tx, ty = math.floor(c.x), math.floor(c.y)
    if w.blocked(tx, ty) then return false, "poteau sur une tuile occupee" end
    if seen[key(tx, ty)] then return false, "deux poteaux sur une tuile" end
    seen[key(tx, ty)] = true
    if not allow_ore and w.ore(tx, ty) and not (tx >= 100 and tx <= 115) then return false, "poteau sur le minerai hors des rangees" end
  end
  return true
end

-- §1 sol libre
do
  local w = world({}, {})
  local ch, tier = Ra.tiered_chain(A, B, params(w))
  check(ch ~= nil and tier == Ra.TIERS[1].name, "§1 sol libre : palier 1 (" .. tostring(tier) .. ")")
  check(ch and valid(ch, w, A, B, false), "§1 chaîne valide")
end

-- §2 minerai en travers (y de -12 à 20), contournable par le sud ou le nord dans la boîte large (y de -24 à 29)
do
  local w = world({ { 30, -12, 100, 20 } }, {})
  local reads = {}
  local ch, tier = Ra.tiered_chain(A, B, params(w, nil, reads))
  check(ch ~= nil and tier == Ra.TIERS[2].name, "§2 minerai en travers : « autour » (" .. tostring(tier) .. ")")
  check(ch and valid(ch, w, A, B, false), "§2 aucun poteau sur le minerai hors des rangées de la bande : " .. tostring((select(2, valid(ch or {}, w, A, B, false)))))
  check(reads[8] == 1 and reads[24] == 1, "§2 une lecture du moteur par marge utilisée (8 : " .. tostring(reads[8]) .. ", 24 : " .. tostring(reads[24]) .. ")")
  local _, t1 = Ra.tiered_chain(A, B, params(w), nil)
  check(t1 ~= Ra.TIERS[1].name, "§2 la boîte étroite seule (règle d'avant) ne passait pas")
end

-- §3 minerai partout (y de -40 à 60) : seul chemin = à travers ; des thermiques (tuiles occupées) bouchent une partie du chemin direct
do
  local w = world({ { 20, -40, 105, 60 } }, { { 40, -2, 46, 8 }, { 70, 0, 76, 10 } })
  local ch, tier = Ra.tiered_chain(A, B, params(w))
  check(ch ~= nil and tier == Ra.TIERS[3].name, "§3 minerai partout : « a travers le minerai » (" .. tostring(tier) .. ")")
  local ok, why = valid(ch or {}, w, A, B, true)
  check(ch and ok, "§3 chaîne valide, thermiques contournes (" .. tostring(why) .. ")")
  local on_ore = 0
  for _, c in ipairs(ch or {}) do if w.ore(math.floor(c.x), math.floor(c.y)) then on_ore = on_ore + 1 end end
  check(on_ore > 0, "§3 des poteaux sont bien sur le minerai (" .. on_ore .. ")")
  -- une tuile déjà prise (poteau du plan, chaîne posée) n'est pas reprise
  local used = {}
  local first = Ra.tiered_chain(A, B, params(w, used))
  for _, c in ipairs(first or {}) do used[key(math.floor(c.x), math.floor(c.y))] = true end
  local second = Ra.tiered_chain({ x = 110, y = 6 }, B, params(w, used))
  local shared = false
  for _, c in ipairs(second or {}) do if used[key(math.floor(c.x), math.floor(c.y))] then shared = true end end
  check(second ~= nil and not shared, "§3 deuxième chaîne : aucune tuile déjà prise")
end

-- §4 mur de tuiles occupées sur toute la hauteur de la boîte large : aucun palier
do
  local w = world({ { 20, -40, 105, 60 } }, { { 40, -60, 60, 80 } })
  local ch, tier = Ra.tiered_chain(A, B, params(w))
  check(ch == nil and tier == Ra.TIERS[3].name, "§4 mur : refus, dernier palier nommé (" .. tostring(tier) .. ")")
end

-- §5 la bande entière (11 poteaux) : Ra.connect avec la chaîne par paliers contre la règle d'avant (palier 1 seul)
local band = {}
for i = 0, 10 do band[#band + 1] = { x = 104 + (i % 6), y = 3 + math.floor(i / 6) * 4 } end
local function connect(w, only_first)
  local used = {}
  local prm = params(w, used)
  local added, fails = Ra.connect(band, { B }, R, function(a, b)
    local ch
    if only_first then
      local t = Ra.TIERS[1]
      local x0, y0, x1, y1 = prm.hull.x0 - t.margin, prm.hull.y0 - t.margin, prm.hull.x1 + t.margin, prm.hull.y1 + t.margin
      ch = P.pole_chain(a, b, R, false, function(x, y)
        local tx, ty = math.floor(x), math.floor(y)
        if tx < x0 or tx > x1 or ty < y0 or ty > y1 then return false end
        return not w.blocked(tx, ty) and not used[key(tx, ty)] and (not w.ore(tx, ty) or (tx >= 100 and tx <= 115))
      end, nil)
    else
      ch = Ra.tiered_chain(a, b, prm)
    end
    for _, c in ipairs(ch or {}) do used[key(math.floor(c.x), math.floor(c.y))] = true end
    return ch
  end)
  return added, fails
end
do
  local w = world({ { 20, -40, 105, 60 } }, { { 40, -2, 46, 8 }, { 70, 0, 76, 10 } })
  local _, fails_old = connect(w, true)
  local added, fails = connect(w, false)
  check(#fails_old == 1 and fails_old[1].n == 11, "§5 règle d'avant : 1 composante de 11 poteaux « sans chaine » (" .. #fails_old .. ")")
  check(#fails == 0 and #added > 0, "§5 chaîne par paliers : bande raccordée, " .. #added .. " poteau(x) de liaison")
  local pts = {}
  for _, p in ipairs(band) do pts[#pts + 1] = p end
  for _, p in ipairs(added) do pts[#pts + 1] = p end
  pts[#pts + 1] = B
  local comp = Ra.components(pts, R)
  local all = true
  for i = 1, #pts do if comp[i] ~= comp[#pts] then all = false end end
  check(all, "§5 tous les poteaux de la bande sont dans la composante du réseau alimenté")
end

-- §6 coût : instructions de la VM (debug.sethook), pire cas = aucune chaîne (3 paliers épuisés) sur une grande carte ; 1 M d'instructions ~ 9 ms
local function cost(fn)
  local count = 0
  debug.sethook(function() count = count + 1 end, "", 1000)
  fn()
  debug.sethook()
  return count * 1000
end
do
  local w = world({ { 20, -40, 105, 60 } }, { { 40, -60, 60, 80 } })
  local worst_all = cost(function() Ra.tiered_chain(A, B, params(w)) end)
  local per = {}
  for ti = 1, #Ra.TIERS do
    local prm = params(w)
    prm.tier = ti
    per[ti] = cost(function() Ra.tiered_chain(A, B, prm) end)
  end
  local wC = world({ { 20, -40, 105, 60 } }, { { 40, -2, 46, 8 }, { 70, 0, 76, 10 } })
  local prm3 = params(wC)
  prm3.tier = 3
  local found = cost(function() Ra.tiered_chain(A, B, prm3) end)
  local m = math.max(per[1], per[2], per[3], found)
  print(string.format("[RACCORD-BANDE] cout (sethook, 1 M instructions ~ 9 ms) : 3 paliers sans chaine %.2f M ; un palier sans chaine %.2f / %.2f / %.2f M ; palier 3 avec chaine %.2f M ; pire palier ~%.1f ms",
    worst_all / 1e6, per[1] / 1e6, per[2] / 1e6, per[3] / 1e6, found / 1e6, m / 1e6 * 9))
  check(m < 0.7e6, "§6 un palier : au plus 0,7 million d'instructions (" .. m .. ")")
end

-- §7 mutants : chacun doit faire échouer la batterie ci-dessus
local function battery(RaX)
  local bad = 0
  local function exp(c) if not c then bad = bad + 1 end end
  local wB = world({ { 30, -12, 100, 20 } }, {})
  local chB, tB = RaX.tiered_chain(A, B, params(wB))
  exp(chB ~= nil and tB == RaX.TIERS[2].name and valid(chB, wB, A, B, false))
  local wC = world({ { 20, -40, 105, 60 } }, { { 40, -2, 46, 8 }, { 70, 0, 76, 10 } })
  local chC, tC = RaX.tiered_chain(A, B, params(wC))
  exp(chC ~= nil and tC == RaX.TIERS[3].name and valid(chC, wC, A, B, true))
  local wD = world({ { 20, -40, 105, 60 } }, { { 40, -60, 60, 80 } })
  exp(RaX.tiered_chain(A, B, params(wD)) == nil)
  local wA = world({}, {})
  local _, tA = RaX.tiered_chain(A, B, params(wA))
  exp(tA == RaX.TIERS[1].name)
  -- les rangées de la bande autorisent le minerai dès le palier 1 (minerai seulement dans les colonnes de la bande)
  local wE = world({ { 100, -40, 115, 60 } }, {})
  local chE, tE = RaX.tiered_chain(A, B, params(wE))
  exp(chE ~= nil and tE == RaX.TIERS[1].name)
  -- un mur dans la boîte étroite : la boîte large le contourne (« autour »), jamais hors de la boîte du palier
  local wF = world({}, { { 40, -14, 60, 17 } })
  local chF, tF = RaX.tiered_chain(A, B, params(wF))
  exp(chF ~= nil and tF == RaX.TIERS[2].name and valid(chF, wF, A, B, true))
  -- la boîte du palier est respectée (bande proche : mur de 12 tuiles dans la boîte étroite, contournable seulement hors d'elle)
  local A2 = { x = 40, y = 5 }
  local wG = world({}, { { 14, -14, 26, 17 } })
  local chG, tG = RaX.tiered_chain(A2, B, params(wG, nil, nil, { x0 = 0, y0 = 0, x1 = 40, y1 = 5 }))
  exp(chG ~= nil and tG == RaX.TIERS[2].name and valid(chG, wG, A2, B, true))
  -- un seul palier demandé (découpage sur plusieurs ticks) : seul celui-là est essayé
  local prm = params(world({}, {}))
  prm.tier = 3
  local chT, tT = RaX.tiered_chain(A, B, prm)
  exp(chT ~= nil and tT == RaX.TIERS[3].name)
  -- tuiles déjà prises
  local usedC = {}
  local first = RaX.tiered_chain(A, B, params(wC, usedC))
  for _, c in ipairs(first or {}) do usedC[key(math.floor(c.x), math.floor(c.y))] = true end
  local second = RaX.tiered_chain({ x = 110, y = 6 }, B, params(wC, usedC))
  local shared = false
  for _, c in ipairs(second or {}) do if usedC[key(math.floor(c.x), math.floor(c.y))] then shared = true end end
  exp(second ~= nil and not shared)
  return bad
end
check(battery(Ra) == 0, "§7 la batterie des mutants passe sur le vrai module")
local NL = string.char(10)
local function drop_line(pat) return function(s) return (s:gsub("[^" .. NL .. "]*" .. pat .. "[^" .. NL .. "]*" .. NL, "", 1)) end end
local function plain(from, to) return function(s) local i, j = s:find(from, 1, true) if not i then return nil end return s:sub(1, i - 1) .. to .. s:sub(j + 1) end end
local MUT = {
  { "pas de palier « a travers le minerai »", drop_line('name = "a travers le minerai"') },
  { "pas de palier « autour » (boite large retiree)", drop_line('name = "autour"') },
  { "palier « autour » aussi etroit que le premier", plain('margin = 24, ore = false, name = "autour"', 'margin = 8, ore = false, name = "autour"') },
  { "minerai libre des le premier palier", plain('margin = 8, ore = false, name = "boite etroite"', 'margin = 8, ore = true, name = "boite etroite"') },
  { "tuiles occupees franchies", plain("if blocked(tx, ty) or p.used[k] then return false end", "if p.used[k] then return false end") },
  { "tuiles deja prises reprises", plain("if blocked(tx, ty) or p.used[k] then return false end", "if blocked(tx, ty) then return false end") },
  { "rangees de la bande ignorees", plain("return t.ore or not p.ore(tx, ty) or p.rows(tx, ty)", "return t.ore or not p.ore(tx, ty)") },
  { "hors de la boite permis", plain("if tx < x0 or tx > x1 or ty < y0 or ty > y1 then return false end", "") },
  { "palier demande ignore (tous les paliers a chaque appel)", plain("if p.tier ~= nil and ti ~= p.tier then goto continue end", "") },
  { "un seul essai (le dernier palier seul)", plain("for ti, t in ipairs(Ra.TIERS) do", "for ti, t in ipairs({ Ra.TIERS[3] }) do") },
}
local refused = 0
for _, m in ipairs(MUT) do
  local src2 = m[2](SRC)
  if not src2 or src2 == SRC then
    print("  MUTANT introuvable : " .. m[1])
  else
    local ok, RaX = pcall(load_ra, src2)
    local killed = not ok
    if ok then
      local ok2, bad = pcall(battery, RaX)
      killed = (not ok2) or bad > 0
    end
    if killed then refused = refused + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
  end
end
check(refused == #MUT, "§7 mutants refusés : " .. refused .. " sur " .. #MUT)
-- §6 bis : la paire la plus proche (poteau de la bande, poteau alimenté), déterministe
do
  local own = { { x = 200, y = 0 }, { x = 190, y = 10 }, { x = 210, y = -4 } }
  local tg = { { x = 0, y = 0 }, { x = 30, y = 5 }, { x = 20, y = -9 } }
  local n = Ra.nearest(own, tg)
  check(n and n.at.x == 190 and n.at.y == 10 and n.to.x == 30 and n.to.y == 5 and math.abs(n.d - math.sqrt(160 * 160 + 5 * 5)) < 1e-9, "§6bis paire la plus proche")
  check(Ra.nearest({}, tg) == nil and Ra.nearest(own, {}) == nil, "§6bis rien à apparier : nil")
end

-- §8 câblage (lecture des sources) : le raccord réel passe par les paliers, un palier par essai, et la migration reprend après la pause
local champ_src, mig_src = read("script/team/champ.lua"), read("script/team/migration_champ.lua")
local function has(src, text, msg) check(src:find(text, 1, true) ~= nil, "§8 " .. msg) end
has(champ_src, "local prm = { tier = only, hull = hull,", "champ.lua : raccord_tous passe par Ra.tiered_chain, un palier par essai")
-- (0.6.74, 3fd9c27c : raccord_tous reçoit aussi l'avant-poste `o`)
has(champ_src, "local n_r, why_r, wait_r, nc = raccord_tous(f, surface, bd, ents, cx, cy, p, o)", "champ.lua : le projet est passé à raccord_tous (palier suivant à l'essai suivant)")
has(champ_src, "proj.rtier = only + 1", "champ.lua : palier suivant mémorisé sur le projet")
has(champ_src, "local nearest = proj and Ra.nearest(own, targets) or nil", "champ.lua : réseau lointain : la ligne est demandée sans palier local")
has(champ_src, "LB.ensure(f, surface, proj, fails[1], wire, bd.names.pole, game.tick)", "champ.lua : après le dernier palier, la ligne est demandée")
has(read("script/team/ligne_bande.lua"), "Build.SITES.ligne_bande = plan_site", "ligne_bande.lua : le site est branché")
has(mig_src, "CHAMP_CFG.pause = 5 * 3600", "migration_champ.lua : pause de 5 min")
has(mig_src, "if pause and st.abandoned then st.pause = CHAMP_CFG.pause end", "migration_champ.lua : la pause est posée à l'abandon d'une bande du champ")
has(mig_src, "local waited = st and st.pause or CFG.revive", "migration_champ.lua : la reprise lit la pause")
has(read("script/team/gisement.lua"), "AUCUNE ne remplace la foreuse retiree", "gisement.lua : retrait d'une thermique journalisé avec les électriques qui tournent")
print(string.format("[RACCORD-BANDE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, refused, #MUT))
os.exit(failures == 0 and 0 or 1)
