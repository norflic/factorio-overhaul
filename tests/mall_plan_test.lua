--[[
  Lot MALL, tranche 1 : test hors jeu de la règle pure du secteur du mall et de l'état S (shared/team/mall_plan.lua).
    §1 grille et masques ; §2 choix sur terrain libre (près du QG, hors du lot du QG) ; §3 eau, minerai, bâtiments, inconnu interdits ;
    §4 étendue et direction ; §5 arbres ; §6 repli de taille et décompte des causes ; §7 déterminisme ; §8 état S ; §9 journal ;
    §10 coût au pire cas (debug.sethook, ≤ 370 k instructions par passe) ; §11 hygiène (aucun pairs, aucun nom d'objet) ; §12 mutants.
  Usage : lua5.2 tests/mall_plan_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/mall_plan.lua")
local function load_mp(src)
  local fn, err = load(src, "=mall_plan", "t")
  assert(fn, err)
  return fn()
end
local Mp = load_mp(SRC)

local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. what) end
end

-- Grille de test : QG en (qx, qy), terrain libre, puis des taches
local function plain(qx, qy)
  local g = Mp.grid_around(qx, qy)
  for j = 0, g.n - 1 do
    local masks = {}
    for i = 0, g.n - 1 do masks[i + 1] = 0 end
    Mp.set_run(g, 0, j, masks)
  end
  return g
end
local function paint(g, x0, y0, x1, y1, m) -- tuiles [x0, x1) × [y0, y1) : les cases touchées reçoivent m (ajouté)
  local C = Mp.CELL
  for j = math.floor((y0 - g.gy0) / C), math.floor((y1 - 1 - g.gy0) / C) do
    for i = math.floor((x0 - g.gx0) / C), math.floor((x1 - 1 - g.gx0) / C) do
      if i >= 0 and j >= 0 and i < g.n and j < g.n then
        local cur = Mp.get(g, i, j)
        local add = 0
        for _, b in ipairs({ 1, 2, 4, 8, 16 }) do
          if math.floor(m / b) % 2 == 1 and math.floor(cur / b) % 2 == 0 then add = add + b end
        end
        Mp.set(g, i, j, cur + add)
      end
    end
  end
end
local QX, QY = 100, -40
local KO = { x0 = QX - 12, y0 = QY - 12, x1 = QX + 12, y1 = QY + 12 } -- lot du QG (P.lot_rect(lat, 0, 0))
local function opt(size, radius) return { size = size, radius = radius, qx = QX, qy = QY, keep_out = KO } end

-- §1 grille et masques
do
  local g = Mp.grid(0, 0, 4)
  check(Mp.get(g, 0, 0) == Mp.INCONNU and Mp.get(g, 3, 3) == Mp.INCONNU, "§1 grille neuve inconnue")
  Mp.set(g, 2, 1, Mp.EAU + Mp.ARBRE)
  check(Mp.get(g, 2, 1) == 17 and Mp.get(g, 1, 1) == Mp.INCONNU, "§1 set/get d'une case")
  check(Mp.get(g, -1, 0) == Mp.INCONNU and Mp.get(g, 4, 0) == Mp.INCONNU, "§1 hors grille inconnu")
  check(Mp.mask(true, false, true, false, true) == 1 + 4 + 16, "§1 masque")
  local g2, cx0, cy0, nch = Mp.grid_around(100, -40)
  check(nch == 15 and g2.n == 60 and cx0 == 3 - 7 and cy0 == -2 - 7, "§1 grille autour du QG : 15 chunks, 60 cases")
  check(g2.gx0 == cx0 * 32 and g2.gy0 == cy0 * 32, "§1 origine au coin d'un chunk")
end

-- §2 terrain libre
local best_plain
do
  local g = plain(QX, QY)
  local s = Mp.choose(g, opt(8, 84))
  best_plain = s
  check(s ~= nil, "§2 une fenêtre en terrain libre")
  if s then
    check(not (s.x0 < KO.x1 and s.x1 > KO.x0 and s.y0 < KO.y1 and s.y1 > KO.y0), "§2 hors du lot du QG")
    check(math.max(math.abs((s.x0 + s.x1) / 2 - QX), math.abs((s.y0 + s.y1) / 2 - QY)) <= 84, "§2 centre dans le rayon")
    check(s.x1 - s.x0 == 64 and s.y1 - s.y0 == 64, "§2 64 × 64 tuiles")
    check(s.ext == 64, "§2 étendue pleine (64 tuiles) en terrain libre")
    check(s.d <= 48, "§2 fenêtre proche du QG (≤ 48 tuiles), d = " .. tostring(s.d))
    -- direction : s'éloigne du QG
    local cx, cy = (s.x0 + s.x1) / 2, (s.y0 + s.y1) / 2
    local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
    check(DV[s.dir][1] * (cx - QX) + DV[s.dir][2] * (cy - QY) > 0, "§2 la croissance s'éloigne du QG")
  end
end

-- §3 catégories interdites
for _, case in ipairs({ { Mp.EAU, "eau" }, { Mp.MINERAI, "minerai" }, { Mp.BATI, "bati" }, { Mp.INCONNU, "inconnu" } }) do
  local g = plain(QX, QY)
  local s0 = Mp.choose(g, opt(8, 84))
  -- une tache de la catégorie au milieu de la meilleure fenêtre : elle doit changer
  paint(g, s0.x0 + 24, s0.y0 + 24, s0.x0 + 32, s0.y0 + 32, case[1])
  local s = Mp.choose(g, opt(8, 84))
  check(s ~= nil, "§3 " .. case[2] .. " : une autre fenêtre existe")
  if s then
    local hit = s.x0 < s0.x0 + 32 and s.x1 > s0.x0 + 24 and s.y0 < s0.y0 + 32 and s.y1 > s0.y0 + 24
    check(not hit, "§3 " .. case[2] .. " : la fenêtre évite la case interdite")
  end
end

-- §4 étendue et direction : un lac à l'est de toutes les fenêtres proches, terrain libre ailleurs
do
  local g = plain(QX, QY)
  local s0 = best_plain
  paint(g, s0.x1, g.gy0, s0.x1 + 8, g.gy0 + g.n * 8, Mp.EAU) -- bande d'eau collée à l'est de la fenêtre libre
  local s = Mp.choose(g, opt(8, 84))
  check(s ~= nil and s.ext >= 8, "§4 une fenêtre avec étendue")
  if s and s.x1 == s0.x1 then check(s.dir ~= 2, "§4 pas de croissance vers le lac collé à l'est") end
  -- étendue mesurée : fenêtre bornée par l'eau à 16 tuiles au nord, terrain ouvert ailleurs mais grille bornée
  local g2 = plain(QX, QY)
  local fake = { size = 8, radius = 84, qx = QX, qy = QY, keep_out = KO, ext = 8 }
  local s2 = Mp.choose(g2, fake)
  check(s2 and s2.ext <= 64, "§4 étendue plafonnée à Mp.EXT cases")
end

-- §5 arbres : défrichables, mais une fenêtre sans arbres l'emporte à étendue et distance égales
do
  local g = plain(QX, QY)
  local s0 = best_plain
  paint(g, s0.x0, s0.y0, s0.x1, s0.y1, Mp.ARBRE)
  local s = Mp.choose(g, opt(8, 84))
  check(s ~= nil, "§5 une fenêtre existe avec des arbres")
  if s then check(s.soft < 64, "§5 la fenêtre pleine d'arbres n'est pas prise quand une voisine est libre (soft = " .. s.soft .. ")") end
  -- tout est boisé : les arbres n'interdisent rien
  local g2 = plain(QX, QY)
  paint(g2, g2.gx0, g2.gy0, g2.gx0 + 480, g2.gy0 + 480, Mp.ARBRE)
  check(Mp.choose(g2, opt(8, 84)) ~= nil, "§5 forêt entière : une fenêtre quand même")
end

-- §6 repli de taille, décompte des causes
do
  local g = plain(QX, QY)
  -- damier : une case de minerai toutes les 7 cases (aucune fenêtre de 8 cases, des fenêtres de 6)
  for j = 0, g.n - 1, 7 do for i = 0, g.n - 1, 7 do Mp.set(g, i, j, Mp.MINERAI) end end
  local s8, t8 = Mp.choose(g, opt(8, 84))
  check(s8 == nil and t8 and t8.minerai > 0, "§6 aucune fenêtre de 8 cases sur le damier, cause minerai")
  local s6 = Mp.choose(g, opt(6, 84))
  check(s6 ~= nil, "§6 fenêtre de 6 cases sur le damier")
  check(Mp.dominant(t8) == "minerai", "§6 cause dominante minerai")
  -- tout en eau : aucune fenêtre, eau dominante
  local g2 = plain(QX, QY)
  paint(g2, g2.gx0, g2.gy0, g2.gx0 + 480, g2.gy0 + 480, Mp.EAU)
  local s, t = Mp.choose(g2, opt(6, 112))
  check(s == nil and Mp.dominant(t) == "eau", "§6 tout en eau : cause eau")
  check(Mp.dominant({}) == "aucune fenetre", "§6 décompte vide")
end

-- §7 déterminisme : deux calculs identiques ; les égalités se départagent par distance, y, x
do
  local g = plain(QX, QY)
  local a = Mp.choose(g, opt(8, 84))
  local b = Mp.choose(g, opt(8, 84))
  check(a.x0 == b.x0 and a.y0 == b.y0 and a.dir == b.dir and a.score == b.score, "§7 même entrée, même fenêtre")
end

-- §8 état S
do
  local plates = { { item = "p1", auto = true }, { item = "p2", auto = true } }
  check(Mp.etat({ plant = false, plaques = plates, asm = true }).code == "S1", "§8 S1 sans centrale")
  check(Mp.etat({ plant = true, plaques = { { item = "p1", auto = true }, { item = "p2", auto = false } }, asm = true }).code == "S2", "§8 S2 une plaque sans source")
  check(Mp.etat({ plant = true, plaques = {}, asm = true }).code == "S2", "§8 S2 aucune plaque connue")
  check(Mp.etat({ plant = true, plaques = plates, asm = true, crise = "survie" }).code == "S3", "§8 S3 crise")
  check(Mp.etat({ plant = true, plaques = plates, asm = false }).code == "S4", "§8 S4 sans assembleur")
  local e = Mp.etat({ plant = true, plaques = plates, asm = true })
  check(e.ok and e.code == "S", "§8 S vrai")
  check(Mp.etat({ plant = true, plaques = { { item = "p1", auto = false } }, asm = true }).cause:find("p1", 1, true) ~= nil, "§8 la cause nomme la plaque")
end

-- §9 journal
do
  local l = Mp.line_sector("player", best_plain, 4096, 1.5)
  check(l:find("^%[FO%-MALL%] player : SECTEUR %(") ~= nil and l:find("64x64") ~= nil, "§9 ligne du secteur")
  check(Mp.line_none("azure", 84, { eau = 3 }, 2, 10):find("cause dominante : eau", 1, true) ~= nil, "§9 ligne sans secteur")
  check(Mp.line_etat("player", Mp.etat({}), false, 1):find("attente S1", 1, true) ~= nil, "§9 ligne d'état")
  check(Mp.inside(best_plain, best_plain.x0, best_plain.y0, best_plain.x0 + 24, best_plain.y0 + 24), "§9 lot dans le secteur")
  check(not Mp.inside(best_plain, best_plain.x0 - 1, best_plain.y0, best_plain.x0 + 24, best_plain.y0 + 24), "§9 lot qui déborde")
end

-- §10 coût au pire cas : terrain ouvert (toutes les fenêtres du rayon passent, étendues pleines), puis terrain mité (étendues pas à pas),
-- puis aucune fenêtre (décompte des causes). Plafond : 370 k instructions par passe (≈ 5 ms ; une passe = un essai de Mp.TRIES).
local function cost(fn)
  local n = 0
  debug.sethook(function() n = n + 1 end, "", 1)
  fn()
  debug.sethook()
  return n
end
do
  local worst = 0
  for _, t in ipairs(Mp.TRIES) do
    local g = plain(QX, QY)
    local c1 = cost(function() Mp.choose(g, opt(t.size, t.radius)) end)
    local gm = plain(QX, QY)
    for j = 0, gm.n - 1, 3 do for i = (j % 2) * 5, gm.n - 1, 11 do Mp.set(gm, i, j, Mp.BATI) end end
    local c2 = cost(function() Mp.choose(gm, opt(t.size, t.radius)) end)
    local ge = plain(QX, QY)
    for j = 0, ge.n - 1, 2 do for i = 0, ge.n - 1, 2 do Mp.set(ge, i, j, Mp.EAU) end end
    local c3 = cost(function() Mp.choose(ge, opt(t.size, t.radius)) end)
    worst = math.max(worst, c1, c2, c3)
    print(string.format("  cout Mp.choose taille %d rayon %d : libre %d, mite %d, aucune %d instructions", t.size, t.radius, c1, c2, c3))
  end
  check(worst <= 370000, "§10 Mp.choose ≤ 370 k instructions au pire (" .. worst .. ")")
end

-- §11 hygiène : aucun pairs, aucun nom d'objet du jeu
do
  local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("[^i]pairs%("), "§11 aucun pairs dans la règle")
  for _, nm in ipairs({ "iron", "copper", "plate", "assembling", "belt", "inserter" }) do
    check(not code:find(nm, 1, true), "§11 aucun nom d'objet (" .. nm .. ")")
  end
end

-- §12 mutants : chaque règle faussée est vue
do
  local muts = {
    { "ignore le minerai", "local any = prefix%(g, Mp.INTERDIT%)", "local any = prefix(g, Mp.INTERDIT - Mp.MINERAI)" },
    { "ignore le lot du QG", "if ko and x0 < ko.x1", "if false and x0 < ko.x1" },
    { "rayon ignoré", "i_hi, j_hi = min%(n %- size, i_hi%), min%(n %- size, j_hi%)", "i_hi, j_hi = n - size, n - size" },
    { "étendue ignorée", "local score = 10 %* ex", "local score = 0 * ex" },
    { "S2 ignoré", "if #missing > 0 then", "if false then" },
    { "S3 ignoré", "if inp.crise then", "if false then" },
  }
  for _, m in ipairs(muts) do
    local src2, n = SRC:gsub(m[2], m[3])
    local caught = false
    if n == 0 then
      print("  mutant introuvable : " .. m[1])
    else
      local ok, M2 = pcall(load_mp, src2)
      if not ok then caught = true
      else
        local g = plain(QX, QY)
        local s = M2.choose(g, opt(8, 84))
        -- minerai : la fenêtre de référence tachée de minerai
        if m[1] == "ignore le minerai" then
          local s0 = Mp.choose(g, opt(8, 84))
          paint(g, s0.x0 + 24, s0.y0 + 24, s0.x0 + 32, s0.y0 + 32, Mp.MINERAI)
          local s1 = M2.choose(g, opt(8, 84))
          caught = s1 and s1.x0 == s0.x0 and s1.y0 == s0.y0
        elseif m[1] == "ignore le lot du QG" then
          local gq = plain(QX, QY)
          local s1 = M2.choose(gq, { size = 6, radius = 84, qx = QX, qy = QY, keep_out = KO })
          local s0 = Mp.choose(gq, { size = 6, radius = 84, qx = QX, qy = QY, keep_out = KO })
          caught = not (s1 and s0 and s1.x0 == s0.x0 and s1.y0 == s0.y0)
        elseif m[1] == "rayon ignoré" then
          -- tout est interdit à moins de 130 tuiles du QG : la règle juste ne trouve rien, le mutant prend une fenêtre au-delà du rayon
          local g5 = plain(QX, QY)
          paint(g5, QX - 130, QY - 130, QX + 130, QY + 130, Mp.BATI)
          caught = M2.choose(g5, opt(8, 84)) ~= nil and Mp.choose(g5, opt(8, 84)) == nil
        elseif m[1] == "étendue ignorée" then
          local g4 = plain(QX, QY)
          paint(g4, best_plain.x1, g4.gy0, best_plain.x1 + 8, g4.gy0 + 480, Mp.EAU)
          paint(g4, best_plain.x0 - 8, g4.gy0, best_plain.x0, g4.gy0 + 480, Mp.EAU)
          paint(g4, g4.gx0, best_plain.y1, g4.gx0 + 480, best_plain.y1 + 8, Mp.EAU)
          paint(g4, g4.gx0, best_plain.y0 - 8, g4.gx0 + 480, best_plain.y0, Mp.EAU)
          local a, b = Mp.choose(g4, opt(8, 84)), M2.choose(g4, opt(8, 84))
          caught = not (a and b and a.x0 == b.x0 and a.y0 == b.y0)
        elseif m[1] == "S2 ignoré" then
          caught = M2.etat({ plant = true, plaques = { { item = "p", auto = false } }, asm = true }).ok
        elseif m[1] == "S3 ignoré" then
          caught = M2.etat({ plant = true, plaques = { { item = "p", auto = true } }, asm = true, crise = "survie" }).ok
        end
      end
    end
    check(caught, "§12 mutant vu : " .. m[1])
  end
end

-- §13 tenue du débit de S2 (règle pure), mutants compris
do
  local function suite(M)
    local out, mem = {}, nil
    local serie = { { 0, 30 }, { 50, 29 }, { 100, 30 }, { 18099, 30 }, { 18100, 30 }, { 18101, 15 }, { 18102, 14.9 }, { 18103, 29 }, { 18104, 30 }, { 18105, 30 }, { 36103, 30 }, { 36104, 30 }, { 36105, 29 }, { 36106, 15 } }
    for _, p in ipairs(serie) do
      mem = M.s2_tenue(mem, p[2], p[1])
      out[#out + 1] = (mem.open and "O" or "f") .. ":" .. tostring(mem.since)
    end
    return table.concat(out, " ")
  end
  local ref = suite(Mp)
  check(ref == "f:0 f:nil f:100 f:100 O:100 O:100 f:nil f:nil f:18104 f:18104 f:18104 O:18104 O:18104 O:18104", "§13 suite de référence (" .. ref .. ")")
  local m1 = Mp.s2_tenue(nil, 30, 0, 600)
  m1 = Mp.s2_tenue(m1, 30, 599, 600)
  check(not m1.open, "§13 tenue passée en argument : un tick trop tôt")
  m1 = Mp.s2_tenue(m1, 30, 600, 600)
  check(m1.open == true, "§13 tenue passée en argument : atteinte")
  local m2 = Mp.s2_tenue(Mp.s2_tenue(nil, 30, 0), 29, 60)
  check(m2.since == nil, "§13 un creux sous le seuil remet la tenue à zéro")
  local src = assert(io.open("shared/team/mall_plan.lua", "rb")):read("*a")
  local function mute(a, b)
    local i, j = src:find(a, 1, true)
    assert(i, "motif introuvable : " .. a)
    local chunk = assert(load(src:sub(1, i - 1) .. b .. src:sub(j + 1), "mutant", "t"))
    return chunk()
  end
  for _, mu in ipairs({
    { "mem.open and flow < Mp.S2_PLAQUES_BAS", "mem.open and flow < Mp.S2_PLAQUES_MIN", "maintien au seuil haut (pas d'hystérésis)" },
    { "      mem.since = nil\n    end", "    end", "creux sans remise à zéro" },
    { "tick - mem.since >= (tenue or Mp.S2_TENUE)", "tick - mem.since > (tenue or Mp.S2_TENUE)", "tenue atteinte un tick trop tard" },
    { "tick - mem.since >= (tenue or Mp.S2_TENUE)", "true", "aucune tenue" },
  }) do
    local ok, sig = pcall(function() return suite(mute(mu[1], mu[2])) end)
    check(not ok or sig ~= ref, "§13 mutant vu : " .. mu[3])
  end
end

print(string.format("[MALL-PLAN] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
if ko_n > 0 then os.exit(1) end
