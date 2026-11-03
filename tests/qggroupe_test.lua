--[[
  Lot QGGROUPE : banc HORS JEU de la règle pure shared/team/qg_groupe.lua. Lancement : lua5.2 tests/qggroupe_test.lua (racine du mod).
  Côtés, mémoire des pertes, choix des côtés (90° au moins, pas de va-et-vient), tailles et places des groupes (nombre constant, écart tenu),
  appui au point le plus faible (les mesures de QGSURVIE2 : une par côté à 10-12 tuiles = appui d'UNE tourelle), affectation ; mutants.
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function read_src(path)
  local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s
end
local SRC = read_src("shared/team/qg_groupe.lua")
local function load_g(src) return assert(load(src, "@shared.team.qg_groupe"))() end

local function d(a, b) return math.sqrt((a.dx - b.dx) ^ 2 + (a.dy - b.dy) ^ 2) end

local function facts(G)
  local r = {}
  r.sides = table.concat({ G.side(0, -10), G.side(10, -10), G.side(10, 0), G.side(10, 10), G.side(0, 10), G.side(-10, 10),
    G.side(-10, 0), G.side(-10, -10) }, ",")
  r.edge = tostring(G.side(1000, -414)) .. "," .. tostring(G.side(1000, -415))
  r.centre = tostring(G.side(0, 0))
  r.gap = G.gap_sides(1, 8) .. "," .. G.gap_sides(1, 5) .. "," .. G.gap_sides(2, 4)
  -- mémoire : une perte à 39 tuiles au sud compte, une à 41 non ; une vieille de 31 min part
  local marks = {}
  G.note(marks, 0, 0, 39, 2)
  G.note(marks, 0, 0, 41, 5)
  G.note(marks, 100, 30, 30, 1) -- SE, 42,4 tuiles : hors rayon
  G.note(marks, 200, 20, 20, 1) -- SE
  G.note(marks, 300, -1, -20, 1) -- N
  r.n_marks = #marks
  local rk = G.rank(marks, 400)
  r.rank = (rk[1] and rk[1].side or 0) .. ":" .. (rk[1] and rk[1].w or 0) .. "," .. (rk[2] and rk[2].side or 0) .. "," .. (rk[3] and rk[3].side or 0)
  local old = {}
  G.note(old, 0, 0, 10, 1)
  G.note(old, G.MEMORY + 1, 10, 0, 1)
  r.expire = #old .. "," .. old[1].side
  -- choix des côtés : S le plus lourd, SE adjacent écarté, N pris
  local ch = G.choose_sides({ { side = 5, w = 10 }, { side = 4, w = 8 }, { side = 1, w = 3 } }, 2, nil)
  r.choose = table.concat(ch, ",")
  -- pas de va-et-vient : les anciens côtés restent à 80 % du plus lourd ; partent à 70 %
  r.keep = table.concat(G.choose_sides({ { side = 3, w = 10 }, { side = 5, w = 8 } }, 2, { 5, 1 }), ",")
  r.leave = table.concat(G.choose_sides({ { side = 3, w = 10 }, { side = 5, w = 7 } }, 2, { 5, 1 }), ",")
  r.none = #G.choose_sides({}, 2, nil)
  -- tailles : 4 -> un groupe de 4 ; 5 -> 3 + 2 ; 8 -> 4 + 4 ; 9 sur 2 côtés -> 5 + 4 (jamais plus de groupes que de côtés)
  r.sizes = table.concat(G.sizes(4, 2), "+") .. "|" .. table.concat(G.sizes(5, 2), "+") .. "|" .. table.concat(G.sizes(8, 2), "+") .. "|" ..
    table.concat(G.sizes(9, 2), "+") .. "|" .. table.concat(G.sizes(3, 1), "+") .. "|" .. #G.sizes(0, 2)
  -- places : 4 au sud, écart 6 -> ligne y = 10, x = -9, -3, 3, 9 (du centre vers les bouts)
  local s4 = G.slots(4, { 5 }, 6)
  local xs = {}
  for _, p in ipairs(s4) do xs[#xs + 1] = p.dx .. ":" .. p.dy end
  r.slots4 = table.concat(xs, " ")
  -- 7 tourelles, S et N : 4 + 3, nombre exact, écart minimal 6 dans chaque groupe, groupes à 20 tuiles l'un de l'autre
  local s7 = G.slots(7, { 5, 1 }, 6)
  r.n7 = #s7
  local mind, maxd_in = math.huge, 0
  for i = 1, #s7 do
    for j = i + 1, #s7 do
      local dd = d(s7[i], s7[j])
      if dd < mind then mind = dd end
      if s7[i].group == s7[j].group and dd > maxd_in then maxd_in = dd end
    end
  end
  r.min7, r.maxin7 = math.floor(mind * 10 + 0.5), math.floor(maxd_in * 10 + 0.5)
  -- diagonale SE, 3 tourelles : centre (7, 7), ligne perpendiculaire (NE-SO)
  local s3 = G.slots(3, { 4 }, 6)
  r.slots3 = s3[1].dx .. ":" .. s3[1].dy .. " " .. s3[2].dx .. ":" .. s3[2].dy .. " " .. s3[3].dx .. ":" .. s3[3].dy
  r.noside = #G.slots(4, {}, 6)
  -- appui : une par côté (QGSURVIE2, 10 à 12 tuiles du coffre) -> une seule tourelle face au point le plus faible
  local ring = { { x = 12, y = 0, s = 1000 }, { x = -12, y = 0, s = 1000 }, { x = 0, y = 10, s = 1000 }, { x = 0, y = -10, s = 1000 } }
  local w, t = G.support(ring, 18, 0, 0)
  r.ring = w .. "/" .. t
  -- une ligne de 4 à 6 tuiles : 18 tuiles de bout en bout, la portée (bornes comprises) -> 4 tourelles au point le plus faible
  local line = {}
  for _, p in ipairs(s4) do line[#line + 1] = { x = p.dx, y = p.dy, s = 1000 } end
  local w2, t2 = G.support(line, 18, 0, 0)
  r.line = w2 .. "/" .. t2
  -- tourelle vide : part 0, elle compte comme point d'entrée mais n'appuie personne
  local half = { { x = 0, y = 0, s = 1000 }, { x = 3, y = 0, s = 0 }, { x = 40, y = 0, s = 500 } }
  local w3, t3, i3 = G.support(half, 18, -10, 0)
  r.half = w3 .. "/" .. t3 .. "@" .. i3
  local we = G.support({ { x = 0, y = 0, s = 500 }, { x = 31, y = 0, s = 1000 } }, 18, -10, 0)
  r.edge18 = we
  r.facing = G.facing(4023, 1000, 7000) .. "," .. G.facing(2296, 4000, 4000) .. "," .. G.facing(100, 0, 0) .. "," .. G.facing(500, 900, 600)
  -- affectation : 4 tourelles une par côté vers la ligne sud : chaque place prend la plus proche, jamais plus que de tourelles
  local tur = { { x = 12, y = 0, id = 4 }, { x = -12, y = 0, id = 2 }, { x = 0, y = 10, id = 3 }, { x = 0, y = -10, id = 1 } }
  local tg = {}
  for _, p in ipairs(s4) do tg[#tg + 1] = { x = p.dx, y = p.dy } end
  local mv = G.assign(tur, tg)
  local mm = {}
  for _, m in ipairs(mv) do mm[#mm + 1] = tur[m.i].id .. ">" .. m.x .. ":" .. m.y end
  r.assign = table.concat(mm, " ")
  r.assign_more = #G.assign({ { x = 0, y = 0, id = 1 } }, tg)
  r.assign_still = #G.assign({ { x = -3, y = 10, id = 1 } }, { { x = -3, y = 11 } })
  r.due = tostring(G.due({ on = true, calm = true, tick = 100, last = nil, sides = 1 })) .. "," ..
    tostring(G.due({ on = true, calm = false, tick = 100, sides = 1 })) .. "," ..
    tostring(G.due({ on = true, calm = true, tick = 100, last = 0, sides = 1 })) .. "," ..
    tostring(G.due({ on = true, calm = true, tick = G.PERIOD, last = 0, sides = 1 })) .. "," ..
    tostring(G.due({ on = false, calm = true, tick = 100, sides = 1 })) .. "," ..
    tostring(G.due({ on = true, calm = true, tick = 100, sides = 0 }))
  return r
end

local F = facts(load_g(SRC))
check(F.sides == "1,2,3,4,5,6,7,8", "huit côtés N, NE, E, SE, S, SO, O, NO (y vers le bas) : " .. F.sides)
check(F.edge == "3,2", "bord du secteur E/NE à tan(22,5°) : " .. F.edge)
check(F.centre == "nil", "centre sans côté")
check(F.gap == "1,4,2", "écart circulaire des côtés : " .. F.gap)
check(F.n_marks == 3, "mémoire : hors de 40 tuiles, rien n'est noté (" .. F.n_marks .. ")")
check(F.rank == "5:2,1,4", "rang des côtés : S (tourelle, 2) puis N et SE à égalité, côté croissant : " .. F.rank)
check(F.expire == "1,3", "une marque de plus de 30 min part : " .. F.expire)
check(F.choose == "5,1", "côtés : S, puis N (SE adjacent écarté) : " .. F.choose)
check(F.keep == "5,1", "pas de va-et-vient : anciens côtés gardés à 80 % : " .. F.keep)
check(F.leave == "3,5", "anciens côtés quittés sous 75 % : " .. F.leave)
check(F.none == 0, "sans marque, aucun côté")
check(F.sizes == "4|3+2|4+4|5+4|3|0", "tailles des groupes : " .. F.sizes)
check(F.slots4 == "3:10 -3:10 9:10 -9:10", "4 au sud en ligne serrée du centre vers les bouts : " .. F.slots4)
check(F.n7 == 7, "nombre CONSTANT : 7 tourelles, 7 places")
check(F.min7 == 60, "écart de pose tenu (6 tuiles) entre toutes les places : " .. F.min7)
check(F.maxin7 == 180, "un groupe de 4 tient dans la portée (18 tuiles de bout en bout) : " .. F.maxin7)
check(F.slots3 == "7:7 11:3 3:11", "3 au SE : centre (7, 7), ligne NE-SO : " .. F.slots3)
check(F.noside == 0, "sans côté, aucune place (emplacements d'avant)")
check(F.ring == "1000/4000", "une par côté (mesure QGSURVIE2) : appui d'UNE tourelle au point le plus faible : " .. F.ring)
check(F.line == "2000/4000", "ligne de 4 à 6 tuiles : le cracheur d'un bout est sous 2 tourelles (le double de l'anneau) : " .. F.line)
check(F.half == "500/1500@3", "tourelle vide sans part ; la plus isolée est le point le plus faible : " .. F.half)
check(F.edge18 == 1000, "portée bornes comprises : le tueur à 18 tuiles de la voisine est sous elle : " .. tostring(F.edge18))
check(F.facing == "574,2296,0,500", "valeur face à une vague = valeur × appui / total : " .. F.facing)
check(F.assign == "3>3:10 2>-3:10 4>9:10 1>-9:10", "affectation à la plus proche : " .. F.assign)
check(F.assign_more == 1, "jamais plus de déplacements que de tourelles")
check(F.assign_still == 0, "à moins de 2 tuiles de sa place : ne bouge pas")
check(F.due == "true,false,false,true,false,false", "regroupement dû : calme, période, interrupteur, côtés : " .. F.due)

local function mutate(old, new)
  local a, b = SRC:find(old, 1, true)
  if not a then return nil end
  return SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1)
end
local mutants = {
  { "nord et sud inversés", "return dy < 0 and 1 or 5", "return dy < 0 and 5 or 1" },
  { "secteur droit trop large", "local TAN = 0.41421356", "local TAN = 0.6" },
  { "rayon des marques ignoré", "if w <= 0 or dx * dx + dy * dy > G.MARK_R * G.MARK_R then return nil end", "if w <= 0 then return nil end" },
  { "mémoire sans fin", "if tick - m.t <= G.MEMORY then keep[#keep + 1] = m end", "keep[#keep + 1] = m" },
  { "côtés adjacents permis", "if G.gap_sides(s, r.side) < 2 then ok = false end", "if G.gap_sides(s, r.side) < 1 then ok = false end" },
  { "va-et-vient", "if wp * 100 >= ranked[1].w * G.KEEP_PCT then", "if false then" },
  { "groupes de 8", "G.GROUP_MAX = 4 ", "G.GROUP_MAX = 8 " },
  { "reste perdu", "for g = 1, ng do out[g] = base + (g <= extra and 1 or 0) end", "for g = 1, ng do out[g] = base end" },
  { "pas de tangente", "local tx, ty = -u[2], u[1]", "local tx, ty = u[1], u[2]" },
  { "écart divisé", "out[#out + 1] = { dx = round(cx + tx * r * gap), dy = round(cy + ty * r * gap), group = g, side = s }",
    "out[#out + 1] = { dx = round(cx + tx * r * gap / 2), dy = round(cy + ty * r * gap / 2), group = g, side = s }" },
  { "appui = total", "if weakest == nil or sum < weakest then weakest, worst = sum, i end", "if weakest == nil or sum > weakest then weakest, worst = sum, i end" },
  { "portée exclusive", "if dx * dx + dy * dy <= r2 then sum = sum + num(b.s) end", "if dx * dx + dy * dy < r2 then sum = sum + num(b.s) end" },
  { "tueur au contact", "if l > 0 then px, py = px + ux / l * G.REACH, py + uy / l * G.REACH end", "" },
  { "valeur entière gardée", "return math.floor(value * weakest / total)", "return math.floor(value)" },
  { "toute tourelle bouge", "if bd > G.MOVE_MIN * G.MOVE_MIN then", "if true then" },
  { "sans période", "if a.last ~= nil and num(a.tick) - num(a.last) < G.PERIOD then return false end", "" },
  { "sans calme", "if not a.on or not a.calm or num(a.sides) <= 0 then return false end", "if not a.on or num(a.sides) <= 0 then return false end" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local txt = mutate(m[2], m[3])
  if not txt then check(false, "mutant « " .. m[1] .. " » : texte introuvable")
  else
    local ok, M = pcall(function() return facts(load_g(txt)) end)
    local same = ok
    if ok then for k, v in pairs(F) do if M[k] ~= v then same = false end end end
    if not same then killed = killed + 1 end
    check(not same, "mutant « " .. m[1] .. " » détecté")
  end
end
print(string.format("[QGGROUPE] mutants refusés : %d sur %d", killed, #mutants))
print(string.format("[QGGROUPE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
