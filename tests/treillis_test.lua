-- Lot INDUSTRIE I3 (31/10) : règles pures de shared/team/treillis.lua (croissance du treillis vers un gisement, cause du refus),
-- leur branchement dans script/team/build.lua et script/ai3/capitalisation.lua (lecture du source), et leurs mutants.
-- Lancer : lua5.2 tests/treillis_test.lua   (depuis la racine du mod)
package.path = "./?.lua;" .. package.path
local P = require("shared.team.plan")

local ok_n, fail_n = 0, 0
local function section(t) print("== " .. t) end

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  return src
end

--- La suite des contrôles, rejouée sur le module de référence puis sur chaque mutant. Rend le nombre d'échecs ; `say` décide si on
--- l'écrit (référence seulement).
local function suite(Tr, say)
  local fails = 0
  local function check(c, msg)
    if c then
      if say then ok_n = ok_n + 1 end
    else
      fails = fails + 1
      if say then fail_n = fail_n + 1 print("  ECHEC : " .. msg) end
    end
  end

  -- 1. anneaux
  check(Tr.ring(0, 0) == 0 and Tr.ring(3, -5) == 5 and Tr.ring(-7, 2) == 7, "anneau = distance de Tchebychev en lots")
  check(Tr.ring_of_point(100, 100, 100, 100, 28) == 0 and Tr.ring_of_point(100, 100, 135, 100, 28) == 1
    and Tr.ring_of_point(100, 100, 100 - 307, 100 - 326, 28) == 12, "anneau d'un point : le lot qui le contient (35 tuiles = 1 ; 326 = 12)")
  check(Tr.ring_of_point(0, 0, 14, 0, 28) == 1 and Tr.ring_of_point(0, 0, 13, 0, 28) == 0, "frontière à la demi-rue")
  -- 2. cible de croissance du cerveau
  check(Tr.grow_target(35, 28, 12) == 2 and Tr.grow_target(154, 28, 12) == 6 and Tr.grow_target(155, 28, 12) == 6, "cible = ceil(far / pas)")
  check(Tr.grow_target(500, 28, 12) == 12 and Tr.grow_target(500, 28, 5) == 5, "jamais plus que le plafond")
  check(Tr.grow_target(60, 28, 12, 1) == 4, "marge d'anneaux")
  check(Tr.reach_radius(nil, 12) == 12 and Tr.reach_radius(4, 12) == 4 and Tr.reach_radius(9, 12) == 9, "portée = rayon figé de l'enceinte, sinon le plafond")
  -- 3. bandes d'un anneau : chaque lot de l'anneau une fois, aucun autre
  for k = 0, 12 do
    local seen, dup, off = {}, 0, 0
    for _, b in ipairs(Tr.ring_bands(k)) do
      for j = b.j0, b.j1 do
        for i = b.i0, b.i1 do
          local key = i .. ":" .. j
          if seen[key] then dup = dup + 1 end
          seen[key] = true
          if Tr.ring(i, j) ~= k then off = off + 1 end
        end
      end
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    check(dup == 0 and off == 0 and n == (k == 0 and 1 or 8 * k), "anneau " .. k .. " : " .. n .. " lots, " .. dup .. " en double, " .. off .. " hors anneau")
  end
  local r = Tr.rings_to_probe(3, 6)
  check(#r == 3 and r[1] == 4 and r[3] == 6 and #Tr.rings_to_probe(6, 6) == 0, "anneaux sondés : de radius + 1 au plafond")
  -- 4. chunks
  local c = Tr.chunks(0, 0, 32, 32)
  check(#c == 1 and c[1].x == 0 and c[1].y == 0, "un chunk exactement")
  c = Tr.chunks(-5, 30, 30, 34)
  check(#c == 4 and c[1].x == -1 and c[1].y == 0 and c[4].x == 0 and c[4].y == 1, "un rectangle à cheval sur 4 chunks, y puis x")
  c = Tr.chunks(-33, -33, -32, -32)
  check(#c == 1 and c[1].x == -2 and c[1].y == -2, "coordonnées négatives : plancher")

  -- 5. décision, minerai DANS le treillis mais trop loin du module
  local d = Tr.decide({ found = true, dist = 100, reach = 140, deposit_ring = 3, radius = 5, cap = 12 })
  check(d.action == "ok" and d.cause == "a_portee", "à portée : rien à faire")
  d = Tr.decide({ found = true, dist = 140, reach = 140, deposit_ring = 3, radius = 5, cap = 12 })
  check(d.action == "ok", "pile à la portée : à portée")
  d = Tr.decide({ found = true, dist = 200, reach = 140, deposit_ring = 5, radius = 5, cap = 12 })
  check(d.action == "grandir" and d.radius == 6 and d.cause == "trop_loin_bord", "lot de minerai au bord : un anneau de plus pour des lots libres autour")
  d = Tr.decide({ found = true, dist = 200, reach = 140, deposit_ring = 3, radius = 7, cap = 12 })
  check(d.action == "refuser" and d.cause == "trop_loin_plein", "lot de minerai au milieu du treillis : grandir n'y change rien, refus écrit")
  d = Tr.decide({ found = true, dist = 200, reach = 140, deposit_ring = 3, radius = 7, cap = 12, pending = 12 })
  check(d.action == "attendre" and d.cause == "trop_loin_en_cours", "évaluations en file : attendre")
  d = Tr.decide({ found = true, dist = 200, reach = 140, deposit_ring = 12, radius = 12, cap = 12 })
  check(d.action == "refuser", "au plafond : refus")
  d = Tr.decide({ found = true, dist = 200, reach = 140, deposit_ring = 5, radius = 5, cap = 12, enc_r = 5 })
  check(d.action == "refuser" and d.cause == "enceinte", "enceinte : le rayon est figé, refus écrit (les îlots sont le lot suivant)")

  -- 6. décision, aucun lot du treillis ne porte le minerai
  d = Tr.decide({ radius = 3, cap = 12 })
  check(d.action == "sonder" and d.cause == "a_sonder", "jamais sondé : sonder")
  d = Tr.decide({ radius = 3, cap = 12, probe = false })
  check(d.action == "refuser" and d.cause == "aucun_gisement", "sondé, rien jusqu'au plafond : refus, pas de croissance pour rien")
  d = Tr.decide({ radius = 3, cap = 12, probe = 8 })
  check(d.action == "grandir" and d.radius == 9 and d.cause == "hors_grandir", "minerai à l'anneau 8 : d'un coup jusqu'à 9 (marge d'un anneau)")
  d = Tr.decide({ radius = 3, cap = 12, probe = 12 })
  check(d.action == "grandir" and d.radius == 12, "minerai au plafond : jusqu'au plafond, pas au-delà")
  d = Tr.decide({ radius = 3, cap = 12, probe = 13 })
  check(d.action == "refuser" and d.cause == "hors_plafond", "sonde au-delà du plafond : refus")
  d = Tr.decide({ radius = 9, cap = 12, probe = 8, pending = 40 })
  check(d.action == "attendre" and d.cause == "en_cours", "minerai dans le treillis, lots pas encore relevés : attendre")
  d = Tr.decide({ radius = 9, cap = 12, probe = 8, pending = 0 })
  check(d.action == "refuser" and d.cause == "lot_refuse", "minerai dans le treillis, tout relevé, aucun lot : les lots sont refusés (nid, ennemi)")
  d = Tr.decide({ radius = 9, cap = 12, probe = 9, pending = 0 })
  check(d.action == "refuser" and d.cause == "lot_refuse", "minerai à l'anneau du rayon même : déjà dans le treillis, pas de croissance")
  d = Tr.decide({ radius = 5, cap = 12, probe = 8, enc_r = 5 })
  check(d.action == "refuser" and d.cause == "enceinte", "enceinte figée sous l'anneau du minerai : refus écrit")
  d = Tr.decide({ radius = 3, cap = 12, probe = 8, enc_r = 6 })
  check(d.action == "grandir" and d.radius == 6, "enceinte plus large que le rayon : on grandit jusqu'à elle, pas au-delà")
  d = Tr.decide({ radius = 3, cap = 6, probe = 6 })
  check(d.action == "grandir" and d.radius == 6, "plafond de l'appelant respecté (6)")
  -- aucun nom d'objet : mêmes nombres, résultat identique
  local d1 = Tr.decide({ found = false, radius = 3, cap = 12, probe = 5 })
  local d2 = Tr.decide({ found = false, radius = 3, cap = 12, probe = 5, res = "zz-quelconque" })
  check(d1.cause == d2.cause and d1.radius == d2.radius, "la décision ne lit aucun nom")
  -- 7. journal
  local l = Tr.line({ team = "amber", tick = 8640, res = "copper-ore", cause = "hors_grandir", action = "grandir", from = 3, to = 9, probe = 8 })
  check(l:find("%[FO%-TREILLIS%] amber : copper%-ore, cause hors_grandir %-> grandir : rayon 3 %-> 9, minerai a l'anneau 8") and l:find("2.4 min"), "ligne de journal : " .. l)
  l = Tr.line({ team = "amber", tick = 0, res = "x", cause = "aucun_gisement", action = "refuser", probe = false, cap = 12 })
  check(l:find("rien jusqu'a l'anneau 12"), "ligne de journal : rien trouvé")
  l = Tr.line({ team = "a", tick = 0, res = "x", cause = "trop_loin_plein", action = "refuser", dist = 200.7, reach = 140 })
  check(l:find("200 tuiles du lot pour 140 de portee"), "ligne de journal : distance")

  -- 8. suite d'une croissance : on ne grandit pas deux fois pour la même sonde
  local rad = 3
  local steps = 0
  repeat
    local dd = Tr.decide({ radius = rad, cap = 12, probe = 8, pending = 0 })
    if dd.action == "grandir" then rad = dd.radius end
    steps = steps + 1
  until dd.action ~= "grandir" or steps > 5
  check(rad == 9 and steps == 2, "rayon 9 atteint en UNE croissance, puis plus de croissance (lots relevés, refus ou attente)")
  return fails
end

---------------------------------------------------------------------------------------------------
section("Référence")
local Tr = require("shared.team.treillis")
local f0 = suite(Tr, true)
print(string.format("  (%d contrôle(s) de la suite en échec sur la référence)", f0))

---------------------------------------------------------------------------------------------------
section("Branchement : le moteur appelle la règle, rien n'est ré-écrit à côté")
do
  local build = read("script/team/build.lua")
  local capi = read("script/ai3/capitalisation.lua")
  local function has(src, pat) return src:find(pat, 1, true) ~= nil end
  local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
  check(has(build, 'require("shared.team.treillis")'), "build.lua charge la règle")
  check(has(build, "Tr.decide(s)") and has(build, "probe_ore(f, surface, res)") and has(build, "treillis_step(f, surface, item, dt, d, reach * P.PITCH)"),
    "plan_feed passe par treillis_step (décision + sonde)")
  check(not has(build, "if not dt and b.radius < Build.RADIUS_MAX then Build.grow(f, b.radius + 1) end"), "l'ancien +1 par refus, borné à RADIUS_MAX, a disparu")
  check(has(build, "Build.RADIUS_ORE = Tr.CAP") and has(build, "Build.RADIUS_MAX = 5"), "croissance ordinaire à 5, croissance vers un gisement à Tr.CAP")
  check(has(build, "r = math.min(r, cap or Build.RADIUS_MAX)"), "Build.grow : plafond par défaut inchangé")
  check(has(build, "ungenerated(b, surface, item, x0, y0, x1, y1)") and has(build, "ungen_retry(f, surface, tick)"),
    "lots lointains : relevé différé tant qu'un chunk n'est pas généré, puis repris")
  check(has(build, "<= Build.RADIUS_MAX then return false end"), "en deçà du rayon ordinaire, aucune vérification de chunk (comportement d'avant)")
  check(has(capi, "Tr.reach_radius(enc and enc.r, Build.RADIUS_ORE)") and has(capi, "Build.grow(f, Tr.grow_target(far, Pl.PITCH, Build.RADIUS_ORE), Build.RADIUS_ORE)"),
    "le cerveau lit la même portée et demande la même croissance")
  check(not has(capi, "math.min(Build.RADIUS_MAX, math.ceil(far / Pl.PITCH))"), "l'ancien plafond du cerveau a disparu")
  -- la règle ne nomme aucun objet du jeu
  local src = read("shared/team/treillis.lua")
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local named = false
  for _, w in ipairs({ "iron", "copper", "coal", "stone", "uranium", "plate", "ore" }) do
    if code:find(w, 1, true) then named = true print("  nom d'objet dans le code : " .. w) end
  end
  check(not named, "aucun nom d'objet dans le code de la règle")
  -- les constantes de pas viennent du plan
  check(P.PITCH == 28 and P.MIN_RES_TILES == 24, "pas du treillis et minerai minimal du plan (la sonde et le lot s'accordent)")
end

---------------------------------------------------------------------------------------------------
section("Mutants : chacun doit être refusé par au moins un contrôle")
do
  local src = read("shared/team/treillis.lua")
  local mutants = {
    { "plafond ignoré", "return min(cap or Tr.CAP, ceil(far / pitch) + (margin or 0))", "return ceil(far / pitch) + (margin or 0)" },
    { "arrondi vers le bas", "return min(cap or Tr.CAP, ceil(far / pitch) + (margin or 0))", "return min(cap or Tr.CAP, floor(far / pitch) + (margin or 0))" },
    { "portée = plafond malgré l'enceinte", "function Tr.reach_radius(enc_r, cap) return enc_r or cap or Tr.CAP end", "function Tr.reach_radius(enc_r, cap) return cap or Tr.CAP end" },
    { "portée : enceinte seule", "function Tr.reach_radius(enc_r, cap) return enc_r or cap or Tr.CAP end", "function Tr.reach_radius(enc_r, cap) return enc_r or 5 end" },
    { "anneau sans coins : bande nord raccourcie", "{ i0 = -k, j0 = -k, i1 = k, j1 = -k },", "{ i0 = -k + 1, j0 = -k, i1 = k, j1 = -k }," },
    { "anneau : coins comptés deux fois", "{ i0 = -k, j0 = -k + 1, i1 = -k, j1 = k - 1 }", "{ i0 = -k, j0 = -k, i1 = -k, j1 = k - 1 }" },
    { "sonde : anneau déjà dans le treillis", "for k = radius + 1, cap or Tr.CAP do", "for k = radius, cap or Tr.CAP do" },
    { "sonde : s'arrête avant le plafond", "for k = radius + 1, cap or Tr.CAP do", "for k = radius + 1, (cap or Tr.CAP) - 1 do" },
    { "chunk : fin inclusive", "for cy = floor(y0 / Tr.CHUNK), floor((y1 - 1) / Tr.CHUNK) do", "for cy = floor(y0 / Tr.CHUNK), floor(y1 / Tr.CHUNK) do" },
    { "chunk : x sans la fin", "for cx = floor(x0 / Tr.CHUNK), floor((x1 - 1) / Tr.CHUNK) do out", "for cx = floor(x0 / Tr.CHUNK), floor(x0 / Tr.CHUNK) do out" },
    { "anneau d'un point : troncature", "return floor(max(abs(x - ox), abs(y - oy)) / pitch + 0.5)", "return floor(max(abs(x - ox), abs(y - oy)) / pitch)" },
    { "à portée : strict", "if (s.dist or 0) <= (s.reach or 0) then", "if (s.dist or 0) < (s.reach or 0) then" },
    { "trop loin : jamais de croissance", "local g = grow_or_wall(ring, \"trop_loin_bord\")\n    if g then return g end", "local g = nil\n    if g then return g end" },
    { "trop loin : attendre ignoré", "if (s.pending or 0) > 0 then return { cause = \"trop_loin_en_cours\", action = \"attendre\" } end", "" },
    { "enceinte ignorée (trop loin)", "if s.enc_r and min(cap, ring + Tr.MARGIN_PROBE) > s.enc_r then return { cause = \"enceinte\", action = \"refuser\" } end", "" },
    { "sonde absente : refus", "if s.probe == nil then return { cause = \"a_sonder\", action = \"sonder\" } end", "if s.probe == nil then return { cause = \"aucun_gisement\", action = \"refuser\" } end" },
    { "rien trouvé : on grandit quand même", "if s.probe == false then return { cause = \"aucun_gisement\", action = \"refuser\" } end", "if s.probe == false then return { cause = \"hors_grandir\", action = \"grandir\", radius = min(cap, radius + 1) } end" },
    { "au-delà du plafond : on grandit", "if s.probe > cap then return { cause = \"hors_plafond\", action = \"refuser\" } end", "" },
    { "minerai déjà dans le treillis : on regrandit", "if s.probe <= radius then", "if s.probe < radius then" },
    { "dans le treillis : jamais attendre", "if (s.pending or 0) > 0 then return { cause = \"en_cours\", action = \"attendre\" } end\n    return { cause = \"lot_refuse\"", "return { cause = \"lot_refuse\"" },
    { "marge d'anneau perdue", "Tr.MARGIN_PROBE = 1 ", "Tr.MARGIN_PROBE = 0 " },
    { "croissance au-delà de l'enceinte", "if s.enc_r then target = min(target, s.enc_r) end", "" },
    { "plafond oublié dans la croissance", "local target = min(cap, ring + Tr.MARGIN_PROBE)", "local target = ring + Tr.MARGIN_PROBE" },
    { "cause perdue dans le journal", "tostring(t.cause), tostring(t.action)", "tostring(t.action), tostring(t.action)" },
    { "rayon du journal", "string.format(\" : rayon %d -> %d\", t.from or 0, t.to or 0)", "string.format(\" : rayon %d -> %d\", t.to or 0, t.from or 0)" },
  }
  local refused = 0
  for _, m in ipairs(mutants) do
    local a, b = src:find(m[2], 1, true)
    if not a then
      fail_n = fail_n + 1
      print("  ECHEC : mutant '" .. m[1] .. "' : motif introuvable dans la règle (le test doit suivre le source)")
    else
      local mut = src:sub(1, a - 1) .. m[3] .. src:sub(b + 1)
      local chunk, err = load(mut, "mutant", "t")
      if not chunk then
        fail_n = fail_n + 1
        print("  ECHEC : mutant '" .. m[1] .. "' ne compile pas : " .. tostring(err))
      else
        local ok, TrM = pcall(chunk)
        local fails = ok and suite(TrM, false) or 1
        if fails > 0 then
          refused = refused + 1
          ok_n = ok_n + 1
        else
          fail_n = fail_n + 1
          print("  ECHEC : mutant SURVIVANT : " .. m[1])
        end
      end
    end
  end
  print(string.format("  mutants refusés : %d / %d", refused, #mutants))
end

print(string.format("[TREILLIS] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
