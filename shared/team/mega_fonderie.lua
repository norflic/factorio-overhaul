--[[
  MÉGA-FONDERIE (lot MEGA-FONDERIE, demande du DC du 8/11, 17 h 50 : « Les foreuses électriques doivent extraire en masse, envoyer les
  minerais sur de très gros bus (plusieurs lignes), qui alimentent ensuite des blocs rectangulaires entiers dédiés uniquement à la fonte »).
  Conception : docs/MEGA_FONDERIE.md. Règle PURE : aucune API du jeu, aucun nom d'objet (tailles, débits et portées arrivent en DONNÉES,
  lues aux prototypes par script/team/champ.lua, Champ.data) ; testée hors jeu : tests/mega_fonderie_test.lua (mutants, coût).

  Mf.size(s)      dimensionnement : foreuses du gisement, minerai/s, lignes du bus (tapis choisi), fours par colonne, colonnes, plaques,
                  charbon, rectangle du bloc, colonnes de départ (budget) ; ou nil et la cause.
  Mf.decide(inp)  déclencheur : "decider" | "garder" | "attendre" | "refuser", et la cause (mots fixes, journal [FO-MEGA]).
  Mf.block(z)     plan du bloc rectangulaire dans son repère (u en travers, v le long des colonnes, entrée en v = 0, sens de marche
                  des tapis : v croissant, direction 4) : { ents, ports, w, h }.
  Mf.verify(pl, z) contrôle du plan : liste des écarts (vide : juste).
  Mf.grow(s)      croissance d'un bloc bâti, en unités « colonne » et « bande » (Fonte.balance) : jamais de retrait.
  Mf.cost(pl)     pièces du plan par sorte ; Mf.signature(z) ; Mf.line(...) : une ligne [FO-MEGA].

  Colonne de pas P = 2·fs + 6 (fs : côté du four) : u = 0 tapis de plaques | 1 bras de sortie | 2..fs+1 four | fs+2 bras d'entrée |
  fs+3 TAPIS D'ENTRÉE (une ligne du bus) | fs+4 bras d'entrée | fs+5..2fs+4 four | 2fs+5 bras de sortie | 2fs+6 = tapis de plaques de la
  colonne suivante (PARTAGÉ). Un bras par four prend sur le tapis d'entrée (minerai ET charbon : ligne mêlée), un bras le vide sur le tapis
  de plaques. Poteaux sur les tuiles libres des colonnes de bras (un four de fs tuiles laisse fs − 1 tuiles libres par bras). Au bout de
  chaque tapis de plaques, un QUAI : bras tapis -> coffre, rangée de poteaux entre deux rangées de bras.
  Convention des bras : `dir` = côté où il PREND (shared/team/modules.lua), `pick` et `drop` = tuiles explicites. Directions : 0 N, 2 E,
  4 S, 6 O. Déterminisme : listes dans l'ordre de construction, aucun `pairs`, aucune trigonométrie, aucun temps mesuré.
]]

local Fonte = require("shared.team.fonte")

local Mf = {}

Mf.EPS = 1e-9
Mf.MIN_LINES = 2     -- lignes PLEINES du bus au moins (en dessous, la colonne au bout d'une bande du champ suffit)
Mf.MAX_LINES = 12    -- lignes du bus au plus (au-delà : le tapis plus rapide, sinon les foreuses sont bornées)
Mf.MAX_SIDE = 32     -- fours par côté d'une colonne au plus (64 tuiles de long pour un four de 2)
Mf.PICKUP = 0.85     -- part du débit d'un bras qui prend sur un tapis (shared/team/champ_colonne.lua, Co.PICKUP)
Mf.MIN_FS = 2        -- côté de four au moins : un four de 1 ne laisse aucune tuile libre aux poteaux de la colonne

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local EPS = Mf.EPS
local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function pos(v) return num(v) and v > 0 end

---------------------------------------------------------------------------------------------------
-- 1. Dimensionnement
---------------------------------------------------------------------------------------------------
--- s = { tiles (tuiles du gisement), cover (part visée, défaut 1 : saturation), drills (foreuses connues, facultatif : cadre du champ),
---   drill = { size, rate }, belts = { { lane }, ... } du plus lent au plus rapide, furnace = { size, rate, fuel, fuel_rate, yield },
---   inserter = { rate }, pole = { reach, wire }, budget_cols (colonnes payables, facultatif) }.
--- Rend la taille z, ou nil et la cause.
function Mf.size(s)
  s = s or {}
  local d, fu, ins, po = s.drill or {}, s.furnace or {}, s.inserter or {}, s.pole or {}
  if not (pos(d.size) and pos(d.rate)) then return nil, "foreuse illisible" end
  if not (pos(fu.size) and pos(fu.rate)) then return nil, "four illisible" end
  if fu.size < Mf.MIN_FS then return nil, "four trop petit pour une colonne (poteaux sans place)" end
  if not pos(ins.rate) then return nil, "bras illisible" end
  if not (pos(po.reach) and pos(po.wire)) then return nil, "poteau illisible" end
  local belts = {}
  for _, b in ipairs(s.belts or {}) do if type(b) == "table" and pos(b.lane) then belts[#belts + 1] = b.lane end end
  if #belts == 0 then return nil, "aucun tapis" end
  local fs, rate, yield = floor(fu.size + EPS), fu.rate, pos(fu.yield) and fu.yield or 1
  local fuel = fu.fuel == true
  local fuel_rate = fuel and (pos(fu.fuel_rate) and fu.fuel_rate or 0) or 0
  -- un bras d'entrée porte le minerai ET le charbon d'un four ; un bras de sortie, ses plaques
  if ins.rate * Mf.PICKUP + EPS < rate + fuel_rate then return nil, "bras trop lent pour nourrir un four" end
  if ins.rate + EPS < rate * yield then return nil, "bras trop lent pour vider un four" end
  -- pas des poteaux le long d'une colonne : multiple de fs (tuiles libres), au plus 2 × portée + 1 (aucun bras entre deux poteaux hors
  -- d'une zone) et au plus portée + fs + 1 (le dernier bras, en hf − fs, à portée du dernier poteau, au moins en hf − pas + 1)
  local r = floor(po.reach + EPS)
  local stepv = floor(min(2 * r + 1, r + fs + 1) / fs + EPS) * fs
  if stepv < fs then return nil, "poteau trop court pour la colonne" end
  if po.wire + EPS < max(stepv, fs + 3) then return nil, "fils trop courts pour la colonne" end
  -- foreuses : connues (cadre du champ) ou estimées (une foreuse par s × (s + 1) tuiles en bandes)
  local cover = pos(s.cover) and min(s.cover, 1) or 1
  local drills = num(s.drills) and floor(max(0, s.drills) + EPS) or floor(max(0, s.tiles or 0) * cover / (d.size * (d.size + 1)) + EPS)
  if drills < 1 then return nil, "gisement vide" end
  local kpl = fuel and 1 or 2 -- voies de minerai par ligne (four à combustible : l'autre voie porte le charbon)
  local clamp = nil
  local lane, lines, per, bi
  for i, l in ipairs(belts) do
    lane, per, bi = l, kpl * l, i
    lines = ceil(drills * d.rate / per - EPS)
    if lines <= Mf.MAX_LINES then break end
    if i == #belts then clamp = "bus" end
  end
  -- colonne = une ligne du bus : ses fours absorbent la ligne, bornés par la voie de sortie (un côté vide sur UNE voie du tapis de
  -- plaques) et par Mf.MAX_SIDE ; la dernière colonne ne reçoit que le reste du minerai
  local nmax = ceil(per / rate / 2 - EPS)
  local nside_out = floor(lane / (rate * yield) + EPS)
  if nside_out < 1 then return nil, "tapis trop lent pour les plaques d'un four" end
  if nmax > nside_out then nmax, clamp = nside_out, clamp or "sortie" end
  if nmax > Mf.MAX_SIDE then nmax, clamp = Mf.MAX_SIDE, clamp or "colonne" end
  local per_eff = min(per, 2 * nmax * rate)
  local ncol = ceil(per_eff / rate - EPS) -- fours d'une colonne pleine
  local nside = ceil(ncol / 2 - EPS)
  lines = ceil(drills * d.rate / per_eff - EPS)
  if lines > Mf.MAX_LINES then
    lines, clamp = Mf.MAX_LINES, clamp or "bus"
    drills = floor(Mf.MAX_LINES * per_eff / d.rate + EPS)
  end
  local ore = drills * d.rate
  local last = min(ncol, max(1, ceil((ore - (lines - 1) * per_eff) / rate - EPS)))
  local furnaces = (lines - 1) * ncol + last
  if fuel and ncol * fuel_rate > lane + EPS then return nil, "voie de charbon trop lente pour une colonne" end
  local P = 2 * fs + 6
  -- quai au bout d'un tapis de plaques intérieur (deux côtés de colonnes) : bras tapis -> coffre, deux par rangée (un de chaque côté)
  local belt_plates = 2 * nside * rate * yield
  local bay_arms = max(1, ceil(belt_plates / (ins.rate * Mf.PICKUP) - EPS))
  local bay_rows = 2 * ceil(bay_arms / 2 - EPS) -- une rangée de bras, une rangée de poteaux
  local hf = nside * fs
  local z = {
    drills = drills, ore = ore, lane = lane, belt = bi, kpl = kpl, per_line = per_eff, lines = lines, cols = lines,
    full_lines = floor(ore / per_eff + EPS), nside = nside, ncol = ncol, furnaces = furnaces, last = last,
    plates = ore * yield, combustible = furnaces * fuel_rate, fuel = fuel, fs = fs, pitch = P, stepv = stepv, reach = r, wire = po.wire,
    bay_arms = bay_arms, bay_rows = bay_rows, hf = hf, w = lines * P + 1, h = hf + bay_rows, clamp = clamp,
    rate = rate, yield = yield, arm_rate = ins.rate,
  }
  if num(s.budget_cols) then
    z.start = max(1, min(lines, floor(s.budget_cols + EPS)))
    z.start_why = z.start < lines and "budget" or "cible"
  else
    z.start, z.start_why = lines, "cible"
  end
  return z
end

--- Échantillon du bloc : ses k premières colonnes (défaut 3), la dernière étant la colonne partielle du bloc. Les colonnes 2 à C − 1 sont
--- des translations l'une de l'autre (pas P) : la première (poteaux de bord), une du milieu et la dernière couvrent toutes les formes ;
--- le contrôle d'un bloc de 12 colonnes coûte ainsi celui de 3 (tests/mega_fonderie_test.lua, coût). `full` : la dernière colonne de
--- l'échantillon est pleine (coût d'une colonne pour le budget).
function Mf.sample(z, k, full)
  local c = {}
  for _, f in ipairs(Mf.FIELDS) do c[f] = z[f] end
  k = max(1, min(z.cols, k or 3))
  c.lines, c.cols = k, k
  if full then c.last = z.ncol end
  c.furnaces = (k - 1) * z.ncol + c.last
  c.w = k * z.pitch + 1
  c.start = min(z.start, k)
  return c
end
Mf.FIELDS = { "drills", "ore", "lane", "belt", "kpl", "per_line", "lines", "cols", "full_lines", "nside", "ncol", "furnaces", "last",
  "plates", "combustible", "fuel", "fs", "pitch", "stepv", "reach", "wire", "bay_arms", "bay_rows", "hf", "w", "h", "clamp", "rate", "yield",
  "arm_rate", "start", "start_why" }

--- Pièces d'UNE colonne pleine (et de son tapis de plaques de gauche, de son quai) : le coût d'un pas de croissance.
function Mf.col_cost(z)
  return Mf.cost(Mf.block(Mf.sample(z, 1, true)))
end

--- Signature d'une taille (le plan n'est refait que si elle change).
function Mf.signature(z)
  if not z then return "-" end
  return string.format("%d:%d:%d:%d:%d", z.lines, z.nside, z.furnaces, z.belt or 0, z.fs)
end

---------------------------------------------------------------------------------------------------
-- 2. Décision
---------------------------------------------------------------------------------------------------
--- inp = { on, smeltable, size (Mf.size ou nil), size_why, power, crisis, sig (signature du bloc déjà décidé, ou nil) }.
function Mf.decide(inp)
  inp = inp or {}
  if inp.on ~= true then return "refuser", "reglage eteint" end
  if inp.smeltable ~= true then return "refuser", "minerai sans four de champ" end
  local z = inp.size
  if not z then return "refuser", "donnees : " .. tostring(inp.size_why or "taille absente") end
  if (z.full_lines or 0) < Mf.MIN_LINES then
    return "refuser", string.format("gisement trop petit pour un bus : %d ligne(s) pleine(s) sur %d (la colonne du champ suffit)",
      z.full_lines or 0, Mf.MIN_LINES)
  end
  if inp.crisis then return "attendre", "crise (survie ou QG menace) : le travail de base d'abord" end
  -- R3 (règle du DC du 11/11, lot PAVAGE-GEANT) : pas de gisement lointain tant qu'un gisement ouvert plus proche du même minerai n'est pas plein
  if inp.nearer then return "attendre", "gisement ouvert plus proche pas plein" end
  if inp.power ~= true then return "attendre", "aucun reseau qui produit" end
  if inp.sig ~= nil and inp.sig == Mf.signature(z) then return "garder", "bloc deja decide, taille inchangee" end
  return "decider", string.format("%d ligne(s) de bus, %d four(s)", z.lines, z.furnaces)
end

---------------------------------------------------------------------------------------------------
-- 3. Plan du bloc
---------------------------------------------------------------------------------------------------
--- Plan du bloc de la taille z (z.start colonnes posées si only_start, sinon toutes : le rectangle entier est le même).
function Mf.block(z, only_start)
  local ents, ports = {}, { arrivals = {}, outputs = {} }
  local fs, P, nside, stepv, r = z.fs, z.pitch, z.nside, z.stepv, z.reach
  local hf, h = z.hf, z.h
  local cols = only_start and z.start or z.cols
  local function add(e) ents[#ents + 1] = e return e end
  local function belt(u, v, role, c) add({ kind = "tapis", u = u, v = v, size = 1, dir = 4, role = role, col = c }) end
  local function arm(u, v, du, dv, role, c) -- prend en (u + du, v + dv), dépose en (u − du, v − dv)
    local dir = (du == 1 and 2) or (du == -1 and 6) or (dv == 1 and 4) or 0
    add({ kind = "bras", u = u, v = v, size = 1, dir = dir, pick = { u + du, v + dv }, drop = { u - du, v - dv }, role = role, col = c })
  end
  local function pole(u, v, c) add({ kind = "poteau", u = u, v = v, size = 1, role = "poteau", col = c }) end
  local placed = 0
  for c = 1, cols do
    local u0 = (c - 1) * P
    local uin = u0 + fs + 3
    local nf = (c == z.cols) and z.last or z.ncol -- la dernière colonne peut être partielle
    for v = 0, hf - 1 do belt(uin, v, "entree", c) end
    ports.arrivals[#ports.arrivals + 1] = { u = uin, v = -1, dir = 4, col = c, kpl = z.kpl }
    for j = 0, nside - 1 do
      local v = j * fs
      for side = 1, 2 do
        if placed < z.furnaces and ((side == 1 and 2 * j < nf) or (side == 2 and 2 * j + 1 < nf)) then
          placed = placed + 1
          if side == 1 then
            add({ kind = "four", u = u0 + 2, v = v, size = fs, col = c })
            arm(u0 + fs + 2, v, 1, 0, "entree", c)   -- prend sur le tapis d'entrée (est), dépose dans le four (ouest)
            arm(u0 + 1, v, 1, 0, "sortie", c)        -- prend dans le four (est), dépose sur le tapis de plaques (ouest)
          else
            add({ kind = "four", u = u0 + fs + 5, v = v, size = fs, col = c })
            arm(u0 + fs + 4, v, -1, 0, "entree", c)
            arm(u0 + 2 * fs + 5, v, -1, 0, "sortie", c)
          end
        end
      end
    end
    -- poteaux : colonnes de bras d'entrée (u0 + fs + 2 ; + fs + 4 si la portée ne couvre pas les deux), de sortie (u0 + 2fs + 5, qui sert
    -- aussi la colonne suivante ; u0 + 1 pour la première colonne ou si la portée est courte)
    local pcols = { u0 + fs + 2, u0 + 2 * fs + 5 }
    if r < 2 then pcols[#pcols + 1] = u0 + fs + 4 end
    if c == 1 or r < 2 then pcols[#pcols + 1] = u0 + 1 end
    table.sort(pcols)
    for _, pu in ipairs(pcols) do
      local v = 1
      while v <= hf - 1 do pole(pu, v, c); v = v + stepv end
    end
  end
  -- tapis de plaques (C + 1) sur toute la hauteur, puis le quai : bras d'un côté puis de l'autre, coffres, rangée de poteaux
  for k = 0, cols do
    local uo = k * P
    for v = 0, h - 1 do belt(uo, v, "plaques", k) end
    local sides = {}
    if k > 0 then sides[#sides + 1] = -1 end
    if k < cols then sides[#sides + 1] = 1 end
    for row = 0, z.bay_rows - 1, 2 do
      local v = hf + row
      for _, sg in ipairs(sides) do
        arm(uo + sg, v, -sg, 0, "quai", k)
        add({ kind = "coffre", u = uo + 2 * sg, v = v, size = 1, role = "sortie", col = k })
        pole(uo + sg, v + 1, k)
      end
    end
    ports.outputs[#ports.outputs + 1] = { u = uo, v = h - 1, col = k }
  end
  return { ents = ents, ports = ports, w = cols * P + 1, h = h, cols = cols }
end

---------------------------------------------------------------------------------------------------
-- 4. Contrôle
---------------------------------------------------------------------------------------------------
local K = 8192 -- clé d'une tuile : (u + 4096) × K + (v + 4096), écrite en ligne (le contrôle en fait des dizaines de milliers)
local function key(u, v) return (u + 4096) * K + (v + 4096) end

--- Écarts du plan : chevauchement, hors du rectangle, four sans bras d'entrée ou de sortie justes, bras de quai sans tapis ni coffre,
--- bras (et four électrique) hors de la zone d'un poteau, poteaux non reliés, tapis d'entrée ou de plaques interrompu, fours comptés.
function Mf.verify(pl, z)
  local bad, nb = {}, 0
  local function no(msg) if nb < 20 then nb = nb + 1; bad[nb] = msg end end
  local at = {}
  local W, H = pl.w, pl.h
  local furnaces, arms, poles, nf, na, np, nchests = {}, {}, {}, 0, 0, 0, 0
  local ents = pl.ents
  for i = 1, #ents do
    local e = ents[i]
    local s = e.size or 1
    local u0, v0 = e.u, e.v
    if u0 < 0 or v0 < 0 or u0 + s > W or v0 + s > H then no(string.format("%s hors du rectangle en (%d, %d)", e.kind, u0, v0)) end
    for du = 0, s - 1 do
      local base = (u0 + du + 4096) * K + v0 + 4096
      for dv = 0, s - 1 do
        local k = base + dv
        if at[k] then no(string.format("chevauchement en (%d, %d)", u0 + du, v0 + dv)) end
        at[k] = e
      end
    end
    local kind = e.kind
    if kind == "bras" then na = na + 1; arms[na] = e
    elseif kind == "poteau" then np = np + 1; poles[np] = e
    elseif kind == "four" then nf = nf + 1; furnaces[nf] = e
    elseif kind == "coffre" then nchests = nchests + 1 end
  end
  -- bras : prise et dépôt
  local fin, fout = {}, {}
  for i = 1, na do
    local a = arms[i]
    local role, pk, dp = a.role, a.pick, a.drop
    local pe, de = at[(pk[1] + 4096) * K + pk[2] + 4096], at[(dp[1] + 4096) * K + dp[2] + 4096]
    if role == "entree" then
      if not (pe and pe.kind == "tapis" and pe.role == "entree") then no(string.format("bras d'entree (%d, %d) ne prend pas sur un tapis d'entree", a.u, a.v)) end
      if de and de.kind == "four" then fin[de] = (fin[de] or 0) + 1 else no(string.format("bras d'entree (%d, %d) ne depose pas dans un four", a.u, a.v)) end
    elseif role == "sortie" then
      if pe and pe.kind == "four" then fout[pe] = (fout[pe] or 0) + 1 else no(string.format("bras de sortie (%d, %d) ne prend pas dans un four", a.u, a.v)) end
      if not (de and de.kind == "tapis" and de.role == "plaques") then no(string.format("bras de sortie (%d, %d) ne depose pas sur un tapis de plaques", a.u, a.v)) end
    elseif role == "quai" then
      if not (pe and pe.kind == "tapis" and pe.role == "plaques") then no(string.format("bras de quai (%d, %d) ne prend pas sur un tapis de plaques", a.u, a.v)) end
      if not (de and de.kind == "coffre") then no(string.format("bras de quai (%d, %d) ne depose pas dans un coffre", a.u, a.v)) end
    end
  end
  for i = 1, nf do
    local f = furnaces[i]
    if fin[f] ~= 1 then no(string.format("four (%d, %d) : %d bras d'entree", f.u, f.v, fin[f] or 0)) end
    if fout[f] ~= 1 then no(string.format("four (%d, %d) : %d bras de sortie", f.u, f.v, fout[f] or 0)) end
  end
  if pl.cols == z.cols and nf ~= z.furnaces then no(string.format("%d four(s) au plan, %d voulu(s)", nf, z.furnaces)) end
  -- courant : grille des zones des poteaux (portée r autour de la tuile du poteau)
  local r = z.reach
  local cover = {}
  for i = 1, np do
    local p = poles[i]
    for du = -r, r do
      local base = (p.u + du + 4096) * K + p.v + 4096
      for dv = -r, r do cover[base + dv] = true end
    end
  end
  -- (fours électriques d'abord : le journal garde 20 écarts au plus, les bras sans courant les masqueraient)
  if not z.fuel then
    for i = 1, nf do
      local f = furnaces[i]
      local ok = false
      for du = 0, f.size - 1 do for dv = 0, f.size - 1 do if cover[key(f.u + du, f.v + dv)] then ok = true end end end
      if not ok then no(string.format("four electrique (%d, %d) sans courant", f.u, f.v)) end
    end
  end
  for i = 1, na do
    local a = arms[i]
    if not cover[(a.u + 4096) * K + a.v + 4096] then no(string.format("bras (%d, %d) sans courant", a.u, a.v)) end
  end
  -- fils : composante connexe des poteaux (seaux de côté ⌈fil⌉, carrés des distances : aucune racine)
  if np > 0 then
    local cell = ceil(z.wire - EPS)
    local w2 = z.wire * z.wire + EPS
    local bucket = {}
    for i = 1, np do
      local p = poles[i]
      local bk = key(floor(p.u / cell), floor(p.v / cell))
      local l = bucket[bk]
      if not l then l = {}; bucket[bk] = l end
      l[#l + 1] = i
    end
    local seen, stack, sn, n = { [1] = true }, { 1 }, 1, 1
    while sn > 0 do
      local p = poles[stack[sn]]
      stack[sn] = nil
      sn = sn - 1
      local bu, bv = floor(p.u / cell), floor(p.v / cell)
      for du = -1, 1 do
        for dv = -1, 1 do
          local l = bucket[key(bu + du, bv + dv)]
          if l then
            for li = 1, #l do
              local j = l[li]
              if not seen[j] then
                local q = poles[j]
                local dx, dy = q.u - p.u, q.v - p.v
                if dx * dx + dy * dy <= w2 then seen[j] = true; n = n + 1; sn = sn + 1; stack[sn] = j end
              end
            end
          end
        end
      end
    end
    if n ~= np then no(string.format("poteaux non relies : %d sur %d dans le reseau du premier", n, np)) end
  end
  -- tapis : chaque ligne d'entrée descend de v = 0 jusqu'au bas des fours, chaque tapis de plaques jusqu'au bout du quai, sens 4
  for _, port in ipairs(pl.ports.arrivals) do
    local base = (port.u + 4096) * K + 4096
    for v = 0, z.hf - 1 do
      local e = at[base + v]
      if not (e and e.kind == "tapis" and e.role == "entree" and e.dir == 4) then
        no(string.format("tapis d'entree de la colonne %d interrompu en v = %d", port.col, v)) break
      end
    end
  end
  for _, port in ipairs(pl.ports.outputs) do
    local base = (port.u + 4096) * K + 4096
    for v = 0, H - 1 do
      local e = at[base + v]
      if not (e and e.kind == "tapis" and e.role == "plaques" and e.dir == 4) then
        no(string.format("tapis de plaques %d interrompu en v = %d", port.col, v)) break
      end
    end
  end
  if nchests < 1 then no("aucun coffre de sortie") end
  return bad
end

--- Pièces du plan par sorte (le runtime les nomme et les compte au coffre).
function Mf.cost(pl)
  local out = { tapis = 0, four = 0, bras = 0, poteau = 0, coffre = 0 }
  for _, e in ipairs(pl.ents) do out[e.kind] = (out[e.kind] or 0) + 1 end
  return out
end

---------------------------------------------------------------------------------------------------
-- 5. Croissance (bloc bâti)
---------------------------------------------------------------------------------------------------
--- s = { input (minerai/s qui arrive au bloc), per_col (minerai/s d'une colonne pleine), posted (colonnes posées), cols (colonnes
--- réservées), bands (bandes qui produisent), band_rate (minerai/s d'une bande), bands_max }. Rend { action, n, why } ; action ∈
--- "ajouter_colonne", "ajouter_bandes", "equilibre", "plein", "sans_minerai", "sans_entree", "invalide". Jamais de retrait.
function Mf.grow(s)
  s = s or {}
  local posted, cols = floor((s.posted or 0) + EPS), floor((s.cols or 0) + EPS)
  local dec = Fonte.balance({ input = s.input or 0, capacity = s.per_col or 0, furnaces = posted, max_furnaces = cols,
    drills = s.bands or 0, drill_rate = s.band_rate or 0, max_drills = s.bands_max or 0 })
  local a = dec.action
  if a == "invalide" or a == "sans_entree" then return { action = a, n = 0, why = a } end
  if a == "ajouter_fours" or (a == "retirer_foreuses" and posted < cols) then
    return { action = "ajouter_colonne", n = 1, why = string.format("entree %.2f/s au-dela de %d colonne(s)", s.input or 0, posted) }
  end
  if a == "retirer_foreuses" then return { action = "plein", n = 0, why = "toutes les colonnes reservees sont posees" } end
  if a == "ajouter_foreuses" then
    return { action = "ajouter_bandes", n = max(1, (dec.drills or 0) - (s.bands or 0)), why = "colonnes en attente de minerai" }
  end
  if a == "retirer_fours" then return { action = "sans_minerai", n = 0, why = "gisement plein, colonnes en attente" } end
  return { action = "equilibre", n = 0, why = "equilibre" }
end

---------------------------------------------------------------------------------------------------
-- 6. Journal
---------------------------------------------------------------------------------------------------
--- Une ligne [FO-MEGA]. dep = { id, res, tiles } ; z = taille (ou nil) ; extra = texte du plan (ou nil).
function Mf.line(team, dep, verdict, cause, z, extra, minutes)
  local size = ""
  if z then
    size = string.format(" ; cible %d foreuse(s), %.1f minerai/s ; bus %d ligne(s) de tapis %d (voie %.2f/s, %d voie(s) de minerai par ligne) ; bloc %d colonne(s) x %d four(s) = %d four(s), %.1f plaques/s, charbon %.2f/s, rectangle %d x %d ; depart %d colonne(s) (%s)%s",
      z.drills, z.ore, z.lines, z.belt or 0, z.lane, z.kpl, z.cols, z.ncol, z.furnaces, z.plates, z.combustible, z.w, z.h, z.start, z.start_why,
      z.clamp and (", borne " .. z.clamp) or "")
  end
  return string.format("[FO-MEGA] %s : gisement %s (%s, %d tuiles) : %s : %s%s%s a %.1f min", tostring(team or "player"), tostring(dep.id),
    tostring(dep.res), dep.tiles or 0, verdict, cause, size, extra and (" ; " .. extra) or "", minutes or 0)
end

return Mf
