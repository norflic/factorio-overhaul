--[[
  Lot EXPERIMENTAUX-PUISSANCE (5/11) : banc hors jeu de la règle d'échelle par âge (shared/robots/echelle.lua). Lua 5.2, depuis la racine
  du mod :
      lua5.2 tests/echelle_test.lua
    §1 cibles du DC (QCM-5/11-XP) : une unité d'âge A tient au moins 3 min sous 10 déchiqueteurs du palier de son âge ; 5 salves tuent ce
       déchiqueteur, 4 non, pour chaque type de dégâts ; « mouche » : une mitrailleuse de 4 âges de moins ou plus lui fait au plus 3 % de
       ses dégâts sans résistance ; zone + 15 par âge (15 à l'âge 10, 90 à l'âge 15) ;
    §2 valeurs figées (âges 6 à 15) : fixe, PV, rayon, cratère ;
    §3 déchiqueteurs : relus contre la règle de prototypes/enemies.lua (palier 12 : 3,3 M PV, morsure 8 100, physique 76 / 74 %) ;
    §4 coût : plan trié par distance puis identifiant, plafonné, tranches qui couvrent tout une fois ;
    §5 forme : Lua pur, aucun pairs, aucun require dans une fonction ;
    §6 mutants : chaque règle a un mutant, tous refusés.
]]

package.path = "./?.lua;" .. package.path

local function read(p)
  local f = assert(io.open(p, "rb"), "lecture impossible : " .. p)
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/robots/echelle.lua")

local DTYPES = { "physical", "impact", "explosion", "fire", "acid", "poison", "laser", "electric" }

local FIXE = { [6] = 12.2, [7] = 16.1, [8] = 21.3, [9] = 28.2, [10] = 37.2, [11] = 49.2, [12] = 65.1, [13] = 258.2, [14] = 341.5, [15] = 451.7 }
local PV = { [6] = 27600, [7] = 79900, [8] = 171500, [9] = 358400, [10] = 640300, [11] = 1113300, [12] = 1873700, [13] = 3026000,
             [14] = 5074400, [15] = 8260200 }
local RAYON = { [10] = 15, [11] = 30, [12] = 45, [13] = 60, [14] = 75, [15] = 90 }

--- La suite pour un module (réel ou mutant). Rend ok, échecs, messages.
local function suite(Ech)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end
  for a = 6, 15 do
    local p = Ech.palier(a)
    local b = Ech.dechiqueteur(p)
    -- §1 survie : 3 min sous 10 déchiqueteurs du palier de son âge
    local dps = 10 * (60 / b.cadence) * Ech.apres(b.morsure, Ech.fixe(a), 50)
    check(Ech.pv(a) >= 180 * dps and Ech.pv(a) < 180 * dps + 100, string.format("§1 âge %d : %d PV, tient %.0f s sous 10 déchiqueteurs du palier %d",
      a, Ech.pv(a), Ech.pv(a) / dps, p))
    -- §1 salves : 5 tuent, 4 non, pour chaque type
    for _, t in ipairs(DTYPES) do
      local s = Ech.salve(a, t)
      local r = b.res[t] or { 0, 0 }
      local net = s and Ech.apres(s, r[1], r[2])
      check(s and 5 * net >= b.pv and 4 * net < b.pv, string.format("§1 âge %d, %s : salve %s, 5 tuent le palier %d (%d PV), 4 non", a, t, tostring(s), p, b.pv))
    end
    -- §1 mouche : une mitrailleuse de l'âge A − 4 (ou moins) fait au plus 3 % de ses dégâts sans résistance
    for g = 4, 6 do
      local c = Ech.coup_tourelle(a - g)
      if c > 0 then
        check(Ech.apres(c, Ech.fixe(a), 50) <= 0.03 * c, string.format("§1 âge %d : mitrailleuse de l'âge %d (%.1f) réduite à %.3f", a, a - g, c,
          Ech.apres(c, Ech.fixe(a), 50)))
      end
    end
    -- et une mitrailleuse de son âge passe encore (pas d'immunité)
    check(Ech.apres(Ech.coup_tourelle(a), Ech.fixe(a), 50) >= 0.25 * Ech.coup_tourelle(a), "§1 âge " .. a .. " : une mitrailleuse de son âge passe encore")
    -- §2 valeurs figées
    check(math.abs(Ech.fixe(a) - FIXE[a]) < 0.06, string.format("§2 âge %d : fixe %.2f, attendu %.1f", a, Ech.fixe(a), FIXE[a]))
    check(Ech.pv(a) == PV[a], string.format("§2 âge %d : PV %d, attendu %d", a, Ech.pv(a), PV[a]))
    check(Ech.rayon(a) == RAYON[a], string.format("§2 âge %d : rayon %s, attendu %s", a, tostring(Ech.rayon(a)), tostring(RAYON[a])))
    check((Ech.cratere(a) == nil) == (RAYON[a] == nil) and (not RAYON[a] or math.abs(Ech.cratere(a) - RAYON[a] / 6) < 1e-9),
      "§2 âge " .. a .. " : cratère")
    local res = Ech.resistances(a)
    local ok = #res == #DTYPES
    for i, r in ipairs(res) do ok = ok and r.type == DTYPES[i] and math.abs(r.decrease - FIXE[a]) < 0.06 and r.percent == 50 end
    check(ok, "§2 âge " .. a .. " : résistances sur les 8 types, fixe et 50 %")
    if a > 6 then check(Ech.pv(a) > Ech.pv(a - 1), "§1 âge " .. a .. " : échelon, plus de PV qu'à l'âge " .. (a - 1)) end
  end
  -- §3 déchiqueteurs : comme prototypes/enemies.lua
  local d12 = Ech.dechiqueteur(12)
  check(d12.pv == 3300000 and d12.morsure == 8100 and d12.cadence == 50, "§3 palier 12 : 3,3 M PV, morsure 8 100 toutes les 50 ticks")
  check(d12.res.physical[1] == 76 and d12.res.physical[2] == 74 and d12.res.acid[1] == 64 and d12.res.acid[2] == 64 and d12.res.laser == nil,
    "§3 palier 12 : physique 76 / 74 %, acide 64 / 64 %, rien au laser")
  check(Ech.dechiqueteur(3).pv == 375 and Ech.dechiqueteur(4).morsure == 90, "§3 paliers vanilla")
  check(Ech.dechiqueteur(9).res.physical[1] == 52 and Ech.dechiqueteur(9).res.physical[2] == 50, "§3 palier 9 : physique 12 + 40 / 10 + 40 %")
  -- formule du moteur, valeurs écrites
  check(math.abs(Ech.apres(100, 20, 50) - 40) < 1e-9 and math.abs(Ech.apres(10, 10, 0) - 0.5) < 1e-9
    and math.abs(Ech.apres(5, 10, 0) - 1 / 7) < 1e-9 and math.abs(Ech.apres(5, 10, 50) - 1 / 14) < 1e-9, "§3 formule de dégâts du moteur")
  check(Ech.palier(15) == 12 and Ech.palier(6) == 3 and Ech.palier(1) == 1 and Ech.palier(20) == 12, "§3 palier de l'âge : A − 3, borné")
  -- §4 coût
  local cands = {}
  for i = 1, 50 do cands[i] = { x = (i * 37) % 17 - 8, y = (i * 53) % 13 - 6, id = 100 - i } end
  local plan = Ech.plan(cands, { x = 0, y = 0 })
  local sorted = #plan == math.min(50, Ech.PLAFOND)
  local function ring(c) return math.floor(math.sqrt(c.x * c.x + c.y * c.y) / Ech.ANNEAU) end
  local pos = {}
  for i, c in ipairs(cands) do pos[c] = i end
  for i = 2, #plan do
    local a, b = plan[i - 1], plan[i]
    if ring(a) > ring(b) or (ring(a) == ring(b) and pos[a] > pos[b]) then sorted = false end
  end
  check(sorted and Ech.ANNEAU == 3, "§4 plan rangé par anneau de 3 tuiles, du centre au bord, puis dans l'ordre d'entrée")
  check(cands[1].id == 99, "§4 la liste d'entrée n'est pas touchée")
  local big = {}
  for i = 1, Ech.PLAFOND + 500 do big[i] = { x = i % 90, y = 0, id = i } end
  check(#Ech.plan(big, { x = 0, y = 0 }) == Ech.PLAFOND, "§4 plafond par salve")
  local n, seen, dup = 1000, {}, false
  for k = 1, Ech.ticks(n) do
    local a, b = Ech.tranche(k, n)
    for i = a, b do if seen[i] then dup = true end seen[i] = true end
  end
  local all = true
  for i = 1, n do all = all and seen[i] == true end
  check(all and not dup and Ech.ticks(n) == math.ceil(n / Ech.TRANCHE), "§4 tranches : chaque cible une fois")
  -- §4 rangement incrémental : par lots, la même file qu'en une fois
  local p = Ech.nouveau_plan({ x = 0, y = 0 })
  for a = 1, #cands, 7 do Ech.ranger(p, cands, a, math.min(#cands, a + 6)) end
  -- §4 parcours par tranches (Ech.suivants) : la même file que Ech.liste, plafond compris, épuisé à la DERNIÈRE tranche, jamais avant
  local function parcours(pl, tr)
    local cur, out, fins, tranches = Ech.curseur(), {}, 0, 0
    while true do
      local t, fini = Ech.suivants(pl, cur, tr)
      tranches = tranches + 1
      for _, x in ipairs(t) do out[#out + 1] = x end
      if fini then fins = fins + 1; break end
      if tranches > 100000 then break end
    end
    return out, tranches
  end
  local pb = Ech.nouveau_plan({ x = 0, y = 0 })
  Ech.ranger(pb, big, 1, #big)
  local lb, tb = parcours(pb, Ech.TRANCHE)
  local lbl = Ech.liste(pb)
  local sb = #lb == #lbl and #lb == Ech.PLAFOND and tb == math.ceil(Ech.PLAFOND / Ech.TRANCHE)
  for i = 1, #lbl do sb = sb and lb[i] == lbl[i] end
  check(sb, "§4 parcours par tranches = liste en une fois (plafond, dernière tranche)")
  local pc = Ech.nouveau_plan({ x = 0, y = 0 })
  local sparse = {}
  for i = 1, 25 do sparse[i] = { x = (i % 5) * 20, y = 0, id = i } end -- anneaux vides entre les pleins
  Ech.ranger(pc, sparse, 1, #sparse)
  local lc, tc = parcours(pc, 4)
  local lcl = Ech.liste(pc)
  local sc = #lc == 25 and #lcl == 25 and tc == 7
  for i = 1, #lcl do sc = sc and lc[i] == lcl[i] end
  check(sc, "§4 parcours : anneaux vides sautés, dernière tranche partielle")
  local _, t5 = parcours(pc, 5)
  check(t5 == 5, "§4 parcours : file multiple de la tranche, aucune tranche vide à la fin")
  local _, f0 = Ech.suivants(Ech.nouveau_plan({ x = 0, y = 0 }), Ech.curseur(), Ech.TRANCHE)
  check(f0 == true, "§4 parcours d'un plan vide : épuisé tout de suite")
  local l2 = Ech.liste(p)
  local same = #l2 == #plan
  for i = 1, #plan do same = same and l2[i] == plan[i] end
  check(same, "§4 rangement par lots = rangement en une fois")
  -- §7 modules : produit
  local eff = Ech.effectif({ range = 40, zone = 30, salve = 1000 }, { portee = 0.2, puissance = 0.5 })
  check(math.abs(eff.range - 48) < 1e-9 and math.abs(eff.zone - 36) < 1e-9 and math.abs(eff.salve - 1500) < 1e-9, "§7 modules : portée et zone × 1,2, salve × 1,5")
  local e0 = Ech.effectif({ range = 40, zone = 30, salve = 1000 }, nil)
  check(e0.range == 40 and e0.zone == 30 and e0.salve == 1000, "§7 modules : sans bonus, inchangé")
  -- §8 balayage (Stylet, âge 11, portée 45)
  local bp = Ech.balayage(11, 45)
  check(bp.angle == 30 and bp.pas == 10 and bp.longueur == 45 and bp.salve == Ech.salve(11, "laser") and bp.demi == 1.5,
    "§8 balayage : 30° en 10 pas, rayon de la longueur de la portée, salve laser de l'âge")
  local o, cb = { x = 0, y = 0 }, { x = 10, y = 0 }
  local rs = Ech.rayons(o, cb, 45)
  local okr = rs and #rs == 11
  if okr then
    for _, q in ipairs(rs) do okr = okr and math.abs(math.sqrt(q.x * q.x + q.y * q.y) - 45) < 1e-6 end
    -- premier et dernier à ±15° de la cible, milieu sur la cible
    okr = okr and math.abs(rs[1].x / 45 - 0.96592582628906829) < 1e-6 and math.abs(rs[11].x / 45 - 0.96592582628906829) < 1e-6
      and rs[1].y * rs[11].y < 0 and math.abs(rs[6].y) < 1e-6 and math.abs(rs[6].x - 45) < 1e-6
    -- pas réguliers de 3°
    for k = 2, 11 do
      local a, b = rs[k - 1], rs[k]
      local cosk = (a.x * b.x + a.y * b.y) / (45 * 45)
      okr = okr and math.abs(cosk - 0.99862953475457383) < 1e-9
    end
  end
  check(okr, "§8 balayage : 11 rayons de 45, de −15° à +15° par pas de 3°, le milieu sur la cible")
  check(Ech.rayons(o, o, 45) == nil, "§8 balayage : cible sur l'unité, rien")
  check(Ech.dans_bande({ x = 20, y = 1.4 }, o, { x = 45, y = 0 }, 1.5) and not Ech.dans_bande({ x = 20, y = 1.6 }, o, { x = 45, y = 0 }, 1.5)
    and not Ech.dans_bande({ x = 47, y = 0 }, o, { x = 45, y = 0 }, 1.5) and Ech.dans_bande({ x = 46, y = 0 }, o, { x = 45, y = 0 }, 1.5),
    "§8 balayage : bande de 1,5 autour du rayon, bout compris")
  local fx = Ech.feux(o, { x = 45, y = 0 }, 4)
  check(#fx == 11 and math.abs(fx[1].x - 4) < 1e-9 and math.abs(fx[11].x - 44) < 1e-9, "§8 balayage : un feu tous les 4 tuiles le long du rayon")
  -- §10 IMPACT, variante B : brûlures
  local unit = true
  for k = 1, 24 do
    local d = Ech.DIR24[k]
    if math.abs(d[1] * d[1] + d[2] * d[2] - 1) > 1e-12 then unit = false end
  end
  check(#Ech.DIR24 == 24 and unit and math.abs(Ech.DIR24[7][2] - 1) < 1e-12 and math.abs(Ech.DIR24[13][1] + 1) < 1e-12
    and math.abs(Ech.DIR24[4][1] - Ech.DIR24[4][2]) < 1e-12, "§10 24 directions unitaires, pas de 15° (90° et 180° exacts)")
  local br = Ech.brulures({ x = 100, y = -50 }, 90)
  local nb = { ["huge-scorchmark"] = 0, ["big-scorchmark"] = 0, ["medium-scorchmark"] = 0 }
  local dist_ok = true
  for i, b in ipairs(br) do
    nb[b.nom] = (nb[b.nom] or 0) + 1
    local d = math.sqrt((b.x - 100) ^ 2 + (b.y + 50) ^ 2)
    local want = i == 1 and 0 or (b.nom == "big-scorchmark" and 31.5 or 63)
    if math.abs(d - want) > 1e-9 then dist_ok = false end
  end
  check(#br == 19 and nb["huge-scorchmark"] == 1 and nb["big-scorchmark"] == 6 and nb["medium-scorchmark"] == 12 and dist_ok,
    "§10 brûlures : 1 au centre, 6 à 0,35 du rayon, 12 à 0,7")
  check(Ech.pas_brulure(100) == 1 and Ech.pas_brulure(300) == 1 and Ech.pas_brulure(301) == 2 and Ech.pas_brulure(4000) == 14 and Ech.pas_brulure(0) == 1,
    "§10 une petite brûlure sur k cibles tuées : au plus 300 par salve")
  return pass, fail, msgs
end

local Ech = require("shared.robots.echelle")
local pass, fail, msgs = suite(Ech)
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end

-- §9 la règle appliquée aux géants de robotsjeu et au Bourdon (accord du lead, 5/11) : données et sources
local Ro = require("shared.content.robots")
local function same_res(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i].type ~= b[i].type or a[i].decrease ~= b[i].decrease or a[i].percent ~= b[i].percent then return false end
  end
  return true
end
local ro_ok, ro_ids = true, {}
for _, r in ipairs(Ro.giants()) do
  ro_ids[#ro_ids + 1] = r.id
  if not (r.hp == Ech.pv(r.age) and same_res(r.resistances, Ech.resistances(r.age)) and r.salve == Ech.salve(r.age, r.dtype)
    and r.zone == Ech.rayon(r.age) and r.cratere == Ech.cratere(r.age) and r.zone_cooldown == Ech.CADENCE_ZONE) then ro_ok = false end
end
check(ro_ok and #ro_ids == 3, "§9 géants de robotsjeu (" .. table.concat(ro_ids, ", ") .. ") : PV, résistances, salve, zone, cratère, cadence de leur âge")
check(Ro.robot("crowned").hp == 8260200 and Ro.robot("toroid").zone == 60, "§9 Couronné 8 260 200 PV, Torique zone de 60 tuiles")
local ro_line = true
for _, r in ipairs(Ro.ROBOTS) do
  if not r.is_giant and (r.salve or r.zone or r.resistances) then ro_line = false end
end
check(ro_line, "§9 les robots de ligne de robotsjeu ne suivent pas la règle (hors décision)")
local PB = read("prototypes/bourdon.lua")
check(PB:find("max_health = Ech.pv(AGE_BOURDON)", 1, true) ~= nil and PB:find("resistances = Ech.resistances(AGE_BOURDON)", 1, true) ~= nil,
  "§9 Bourdon : PV et résistances de son âge (prototype)")
check(require("shared.robots.bourdon").AGE == 15, "§9 Bourdon : âge 15")
local SB = read("script/robots/bourdon.lua")
check(SB:find("XpG.cible(b.e, { range = B.PORTEE_AUTO })", 1, true) ~= nil and not SB:find("find_nearest_enemy({ position = b.e.position", 1, true),
  "§9 Bourdon : cible « tout ce qui est ennemi » (militaire d'abord)")
local PR = read("prototypes/robots.lua")
check(PR:find("s.resistances = table.deepcopy(r.resistances)", 1, true) ~= nil, "§9 géants de robotsjeu : résistances posées sur le prototype")
local SG = read("script/robots/geant.lua")
check(SG:find("XpG.salve(u, un, r,", 1, true) ~= nil and SG:find("at = tick + r.zone_cooldown", 1, true) ~= nil,
  "§9 géants de robotsjeu : salve de zone à la cadence de la règle")

-- §5 forme
check(not SRC:gsub("ipairs%(", ""):find("pairs%("), "§5 aucun pairs")
check(not SRC:find("game%.") and not SRC:find("script%.") and not SRC:find("%f[%w]global%f[%W]"), "§5 Lua pur (ni game, ni script, ni global)")

-- §6 mutants
local MUTANTS = {
  { "écart de 3 âges", "Ech.ECART = 4", "Ech.ECART = 3" },
  { "résistance à 30 %", "Ech.POURCENT = 50", "Ech.POURCENT = 30" },
  { "survie de 2 min", "Ech.SURVIE_S = 180", "Ech.SURVIE_S = 120" },
  { "meute de 5", "Ech.MEUTE = 10", "Ech.MEUTE = 5" },
  { "10 salves", "Ech.SALVES = 5", "Ech.SALVES = 10" },
  { "zone + 10 par âge", "Ech.PAS_ZONE = 15", "Ech.PAS_ZONE = 10" },
  { "zone décalée", "Ech.AGE_ZONE0 = 9", "Ech.AGE_ZONE0 = 10" },
  { "palier de l'âge A − 2", "Ech.DECALAGE_PALIER = 3", "Ech.DECALAGE_PALIER = 2" },
  { "formule sans le cas < 1", "if d < 1 then d = 1 / (2 - d) end", "if d < 0 then d = 0 end" },
  { "résistances du palier sans sa part fixe", "res[t] = { r[1] + nt.resist, math.min(95, r[2] + nt.resist) }", "res[t] = { r[1], math.min(95, r[2] + nt.resist) }" },
  { "acide oublié", 'or t == "acid" then', 'then' },
  { "munition chargeur", "return a <= 8 and 8 or 24", "return 5" },
  { "salve sans la part fixe", "return math.ceil(net / (1 - r[2] / 100) + r[1])", "return math.ceil(net / (1 - r[2] / 100))" },
  { "plan du bord vers le centre", "  for k = 1, p.top do", "  for k = p.top, 1, -1 do" },
  { "rangement qui oublie la dernière entrée", "local c = cands[i]\n    Ech.poser(p, c.x, c.y, c)", "local c = cands[i]\n    if i == b then break end\n    Ech.poser(p, c.x, c.y, c)" },
  { "brûlures : anneau extérieur à 0,6", "part = 0.7, pas = 2", "part = 0.6, pas = 2" },
  { "brûlures : 6 points au lieu de 12", "part = 0.7, pas = 2", "part = 0.7, pas = 4" },
  { "brûlures : rotation de quart de tour fausse", "for _ = 1, q do x, y = -y, x end", "for _ = 1, q do x, y = y, -x end" },
  { "brûlures sans plafond", "return math.max(1, math.ceil(n / Ech.BRULURES_MAX))", "return 1" },
  { "parcours sans plafond","while #out < n and cur.pris < Ech.PLAFOND and cur.k <= p.top do", "while #out < n and cur.k <= p.top do" },
  { "parcours qui saute un anneau", "      cur.k, cur.i = cur.k + 1, 1", "      cur.k, cur.i = cur.k + 2, 1" },
  { "parcours épuisé trop tôt", "if r and i <= #r then fini = false; break end", "if r and i < #r then fini = false; break end" },
  { "parcours jamais épuisé par le reste vide", "    fini = true\n    while k <= p.top do", "    fini = false\n    while k <= p.top do" },
  { "module de portée sans effet sur la zone", "zone = r.zone and r.zone * (1 + bp)", "zone = r.zone" },
  { "puissance en somme au lieu du produit", "salve = r.salve and r.salve * (1 + bf)", "salve = r.salve and r.salve + bf" },
  { "balayage de 36°", "local COS15, SIN15 = 0.96592582628906829, 0.25881904510252074", "local COS15, SIN15 = 0.95105651629515353, 0.30901699437494740" },
  { "pas de 4°", "local COS3, SIN3 = 0.99862953475457383, 0.052335956242943835", "local COS3, SIN3 = 0.99756405025982425, 0.069756473744125301" },
  { "bande sans le bout du segment", "if t < 0 then t = 0 elseif t > 1 then t = 1 end", "if t < 0 then t = 0 end" },
  { "balayage hors laser", 'salve = Ech.salve(age, "laser") }', 'salve = Ech.salve(age, "physical") }' },
  { "feux à la mauvaise distance", "local t = i * pas / l", "local t = (i - 0.5) * pas / l" },
  { "anneaux de 6 tuiles", "Ech.ANNEAU = 3", "Ech.ANNEAU = 6" },
  { "plafond ignoré", "if #out >= Ech.PLAFOND then return out end", "" },
  { "tranche qui saute une cible", "local a = (k - 1) * Ech.TRANCHE + 1", "local a = (k - 1) * Ech.TRANCHE + 2" },
  { "cratère au quart de la zone", "Ech.CRATERE_PART = 6", "Ech.CRATERE_PART = 4" },
  { "petits avec une zone", "if age < Ech.AGE_ZONE_MIN then return nil end", "" },
}
local kept = {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local src = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local f = load(src, "=mutant", "t")
    local bad = 1
    if f then
      local ok, M = pcall(f)
      if ok and type(M) == "table" then
        local ok2, _, ff = pcall(suite, M)
        bad = ok2 and ff or 1
      end
    end
    if bad == 0 then kept[#kept + 1] = m[1] end
  end
end
check(#kept == 0, "§6 mutants NON refusés : " .. table.concat(kept, " ; "))

for _, m in ipairs(msgs) do print("[ECHELLE] ECHEC " .. m) end
print(string.format("[ECHELLE] mutants refusés : %d sur %d", #MUTANTS - #kept, #MUTANTS))
print(string.format("[ECHELLE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
