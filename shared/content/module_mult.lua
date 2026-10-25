--[[
  Modules MULTIPLICATIFS (lot MOD-1, décision D-15 du Directeur Créatif, 24/10). Lua PUR, testé hors jeu
  (tests/module_mult_test.lua).

  Règle voulue : sur une machine, facteur de vitesse = Π (1 + b_i), facteur d'énergie = Π (1 + c_i), sur les
  modules de la machine ; jusqu'au plafond du moteur (× 328,67 par type d'effet, F190 du lot MOD-0), rien au-delà.
  Le moteur 1.1 ADDITIONNE (F190). Mécanisme (MOD-0, F192) : une balise CACHÉE par machine porte le complément
      C = (T − 100) − S      (en centièmes entiers)
  où S = Σ e_i est la somme que le moteur fait déjà (effets des modules de la machine, en centièmes) et T le facteur
  voulu en centièmes. Le moteur voit alors S + C = T − 100 (plus les balises du joueur, qui restent ADDITIVES :
  elles ne sont pas des modules de la machine). Le complément est décomposé en modules cachés de puissances de deux
  (± 0,01 à ± 163,84), 15 par effet et par signe : toute valeur de −327,67 à +327,67 tient en 15 emplacements.

  Déterminisme (ARCHITECTURE §2) : tout est en ENTIERS. Le produit est EXACT (grand entier en base 100), donc
  indépendant de l'ordre des modules (déplacer un module d'une case à l'autre ne change rien) ; l'arrondi final est
  au centième le plus proche (moitié vers le haut) ; aucun flottant dans une décision, aucune table parcourue par
  pairs, aucun temps mesuré.

  Bornes (moteur 1.1.91, F190) : chaque effet de module est rangé en centièmes sur 16 bits signés (+327,67 au plus),
  la SOMME sature à +327,67 et la machine applique son plancher (−80 %). D'où :
    - facteur d'un module : 100 + e_i, au moins 20 (un module à −80 % ou moins compte × 0,2) ;
    - facteur voulu T : borné à [20, 32 867] (−80 % à +327,67 %) ;
    - complément C : borné à [−32 767, +32 767] (15 bits par signe).

  PRODUCTIVITÉ (lot MOD-3, décision D-17 du DC, 25/10, réponse à Q-M4 : « on garde la multiplication pour les 2 ») :
  elle se MULTIPLIE comme la vitesse (réglage MM.PRODUCTIVITY_MULTIPLIES = true ; false redonnerait l'addition du
  moteur, sans complément). POLLUTION : hors de la décision du DC, reste additive (moteur), aucun complément.

  ÉNERGIE AU PLAFOND (lot MOD-3, D-17, Q-M5 B « garder l'écart ») : quand le produit de vitesse (ou de productivité)
  dépasse le plafond du moteur, la machine ne reçoit que × 328,67 ; l'énergie suivait pourtant le produit ENTIER et
  rattrapait le plafond elle aussi (D-15 : 34 modules de palier 10, vitesse × 328,67 et énergie × 328,67). Règle :
  chaque module ne paie l'énergie que de la part de son bonus qui sert encore. En logarithmes, la part d'énergie des
  modules de vitesse est multipliée par r_v = ln(V plafonnée) / ln(V entière), celle des modules de productivité par
  r_p (même définition) ; les autres parts (efficacité) sont gardées. Avec des modules de vitesse seuls, cela donne
  exactement la règle proposée par l'orchestrateur : énergie = V_plafonnée ^ (ln Π(1 + 0,6 b) / ln Π(1 + b)). Les
  logarithmes sont en VIRGULE FIXE ENTIÈRE (MM.log2_fp, 16 bits après la virgule) : aucun math.log dans une décision
  (son résultat au dernier bit n'est pas garanti identique d'un système à l'autre). Hors du plafond, rien ne change
  (le produit exact reste la règle).
]]

local MM = {}

--- Réglage unique de la productivité (Q-M4 tranchée par D-17) : true = multipliée ; false = additive (moteur).
MM.PRODUCTIVITY_MULTIPLIES = true
--- Réglage de l'énergie au plafond (Q-M5 B, D-17) : true = l'énergie garde l'écart ; false = produit borné seul (D-15).
MM.ENERGY_KEEPS_GAP = true

--- Effets portés par la balise cachée, dans cet ordre (ordre des emplacements de la balise).
MM.EFFECTS = { "speed", "consumption", "productivity" }

--- Puissances de deux par signe : 2^0 … 2^14 centièmes (0,01 … 163,84).
MM.BITS = 15
MM.MAX_C = 2 ^ MM.BITS - 1          -- 32 767 centièmes
MM.FLOOR = -80                      -- plancher du moteur (−80 %)
MM.MIN_T = 100 + MM.FLOOR           -- 20 : facteur minimal, en centièmes
MM.MAX_T = 100 + 32767              -- 32 867 : × 328,67, plafond du moteur
MM.MIN_FACTOR = MM.MIN_T            -- facteur minimal d'UN module (−80 % : × 0,2)

--- Balise cachée : un emplacement par module de complément possible (3 effets × 15 bits ; un seul signe à la fois).
MM.BEACON = "fo-mm-balise"
MM.BEACON_SLOTS = #MM.EFFECTS * MM.BITS
--- Préfixe des modules cachés : « fo-mm-<effet>-<p|n><bit sur 2 chiffres> ».
MM.PREFIX = "fo-mm-"

--- Nom du module caché qui porte ±2^bit centièmes de l'effet.
function MM.module_name(effect, sign, bit)
  return MM.PREFIX .. effect .. "-" .. (sign > 0 and "p" or "n") .. string.format("%02d", bit)
end

--- Valeur (fraction, pour le prototype) du module caché. Les puissances de deux /100 sont EXACTES en double une fois
--- remultipliées par 100 (vérifié par le test) ; le positif reçoit l'epsilon de la règle des modules
--- (shared/content/modules.lua : le moteur tronque au centième).
MM.EPSILON = 1e-6
function MM.module_value(sign, bit)
  local v = (2 ^ bit) / 100
  if sign > 0 then return v + MM.EPSILON end
  return -v
end

--- Liste de tous les modules cachés : { name, effect, sign, bit, value }, dans un ordre fixe.
function MM.all_modules()
  local out = {}
  for _, effect in ipairs(MM.EFFECTS) do
    for _, sign in ipairs({ 1, -1 }) do
      for bit = 0, MM.BITS - 1 do
        out[#out + 1] = { name = MM.module_name(effect, sign, bit), effect = effect, sign = sign, bit = bit,
          value = MM.module_value(sign, bit) }
      end
    end
  end
  return out
end

--- Lecture d'un effet de prototype comme le moteur : centièmes, troncature vers zéro. Moteur réel (MOD-0, F190) :
--- 1,15 sans epsilon donne +114 % ; le sens pour un négatif inexact (−0,55 × 100 = −55,000000000000007 en double)
--- est mesuré par le scénario mod1-modules (lignes « CENTIEMES ») : la troncature vers zéro y est l'hypothèse.
function MM.engine_cents(v)
  if v == nil then return 0 end
  local x = v * 100
  if x >= 0 then return math.floor(x) end
  return -math.floor(-x)
end

--- Lecture d'un effet RENDU PAR LE MOTEUR à l'exécution (LuaItemPrototype.module_effects) : le moteur rend la valeur
--- qu'il a RANGÉE, centièmes / 100 en flottant 32 bits (moteur réel, lot MOD-1 : 0,48 + ε rendu 0,4799999893,
--- 1,4 + ε rendu 1,3999999762) ; la tronquer perdrait un centième. Arrondi au plus proche.
function MM.runtime_cents(v)
  if v == nil then return 0 end
  local x = v * 100
  if x >= 0 then return math.floor(x + 0.5) end
  return -math.floor(-x + 0.5)
end

---------------------------------------------------------------------------------------------------
-- Grand entier en base 100 (chiffres de poids faible d'abord) : produit EXACT de facteurs entiers.
---------------------------------------------------------------------------------------------------
local BASE = 100

--- n × f (f entier ≥ 0), en place.
local function big_mul(n, f)
  local carry = 0
  for i = 1, #n do
    local v = n[i] * f + carry
    local q = math.floor(v / BASE)
    n[i] = v - q * BASE
    carry = q
  end
  while carry > 0 do
    local q = math.floor(carry / BASE)
    n[#n + 1] = carry - q * BASE
    carry = q
  end
  return n
end

--- floor(n / 100^k + 1/2) borné à [lo, hi] (n ≥ 0, k ≥ 0).
local function big_scaled_round(n, k, lo, hi)
  -- Chiffres au-dessus de la virgule : indices k+1 … #n. Au-delà de 3 chiffres (≥ 1 000 000), plafond sûr.
  local high = #n - k
  if high > 3 then return hi end
  local v = 0
  for i = #n, k + 1, -1 do v = v * BASE + n[i] end
  if k >= 1 and (n[k] or 0) >= BASE / 2 then v = v + 1 end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

--- Produit exact Π (100 + e_i), chaque facteur au moins MM.MIN_FACTOR : grand entier et nombre de facteurs.
local function exact_product(list)
  local big = { 1 }
  local used = 0
  for i = 1, #list do
    local f = 100 + list[i]
    if f < MM.MIN_FACTOR then f = MM.MIN_FACTOR end
    big_mul(big, f)
    used = used + 1
  end
  return big, used
end

--- Facteur voulu T (centièmes) pour une liste d'effets en centièmes e_i : round(Π (100 + e_i) / 100^(n−1)),
--- chaque facteur au moins MM.MIN_FACTOR, résultat borné à [MM.MIN_T, MM.MAX_T]. Indépendant de l'ordre (produit
--- exact). Liste vide : 100.
function MM.target(list)
  local n = #list
  if n == 0 then return 100 end
  local big, used = exact_product(list)
  return big_scaled_round(big, used - 1, MM.MIN_T, MM.MAX_T)
end

--- Le produit (arrondi au centième) DÉPASSE-t-il le plafond du moteur ? (entiers seulement)
function MM.over_cap(list)
  if #list == 0 then return false end
  local big, used = exact_product(list)
  return big_scaled_round(big, used - 1, MM.MIN_T, MM.MAX_T + 1) > MM.MAX_T
end

---------------------------------------------------------------------------------------------------
-- Logarithme en base 2 en VIRGULE FIXE ENTIÈRE (énergie au plafond, D-17)
---------------------------------------------------------------------------------------------------
MM.LOG_BITS = 16                    -- bits après la virgule : log2(x) × 2^16, arrondi vers le bas (à ~2^-15 près)
local LOG_ONE = 2 ^ MM.LOG_BITS
local MANT_BITS = 24                -- mantisse sur 24 bits : son carré (< 2^50) reste exact en flottant double
local MANT_ONE = 2 ^ MANT_BITS

--- floor(log2(x) × 2^16) à 2^-15 près, pour un entier x de 1 à 2^28 : chiffre par chiffre (carrés successifs de la
--- mantisse), entiers exacts seulement (produits < 2^53, divisions par des puissances de deux).
function MM.log2_fp(x)
  local ip, pw = 0, 1
  while x >= pw * 2 do
    pw = pw * 2
    ip = ip + 1
  end
  local m = math.floor(x * MANT_ONE / pw)   -- mantisse dans [2^24, 2^25)
  local res = ip * LOG_ONE
  local bit = LOG_ONE / 2
  while bit >= 1 do
    m = math.floor(m * m / MANT_ONE)
    if m >= 2 * MANT_ONE then
      m = math.floor(m / 2)
      res = res + bit
    end
    bit = bit / 2
  end
  return res
end

local LOG_100            -- log2_fp(100), calculé une fois
--- log2 (virgule fixe) du facteur d'un effet en centièmes : log2((100 + e) / 100), facteur au moins MM.MIN_FACTOR.
function MM.log_factor(e)
  if not LOG_100 then LOG_100 = MM.log2_fp(100) end
  local f = 100 + e
  if f < MM.MIN_FACTOR then f = MM.MIN_FACTOR end
  return MM.log2_fp(f) - LOG_100
end

local function sum_logs(list)
  local s = 0
  for i = 1, #list do s = s + MM.log_factor(list[i]) end
  return s
end

--- Énergie au plafond (Q-M5 B, D-17) : facteur d'énergie T (centièmes) qui garde l'écart, ou nil si aucun produit ne
--- dépasse le plafond (rien à corriger). `mods` : liste de { speed, consumption, productivity } en centièmes ;
--- `lists` : listes par effet (comme MM.complements) ; `prod_mult` : la productivité se multiplie-t-elle.
--- La part d'énergie d'un module va à la vitesse s'il a un bonus de vitesse positif, à la productivité s'il a un bonus
--- de productivité positif (et pas de vitesse), sinon elle est gardée telle quelle (efficacité, malus).
function MM.energy_keep_gap(mods, lists, prod_mult)
  local over_s = MM.over_cap(lists.speed)
  local over_p = prod_mult and MM.over_cap(lists.productivity) or false
  if not over_s and not over_p then return nil end
  if not LOG_100 then LOG_100 = MM.log2_fp(100) end
  local l_cap = MM.log2_fp(MM.MAX_T) - LOG_100
  local free, part_s, part_p = 0, 0, 0
  for i = 1, #mods do
    local m = mods[i]
    local c = m.consumption
    if c and c ~= 0 then
      local l = MM.log_factor(c)
      if c > 0 and (m.speed or 0) > 0 then part_s = part_s + l
      elseif c > 0 and (m.productivity or 0) > 0 then part_p = part_p + l
      else free = free + l end
    end
  end
  local y = free
  if over_s then y = y + math.floor(part_s * l_cap / sum_logs(lists.speed)) else y = y + part_s end
  if over_p then y = y + math.floor(part_p * l_cap / sum_logs(lists.productivity)) else y = y + part_p end
  -- T au plus proche de 100 × 2^(y / 2^16) : plus grand t de [MIN_T, MAX_T] tel que log2(t / 100) ≤ y (dichotomie
  -- sur les entiers), puis t ou t + 1 selon l'écart.
  local lo, hi = MM.MIN_T, MM.MAX_T
  if MM.log2_fp(lo) - LOG_100 > y then return MM.MIN_T end
  while hi - lo > 1 do
    local mid = math.floor((lo + hi) / 2)
    if MM.log2_fp(mid) - LOG_100 <= y then lo = mid else hi = mid end
  end
  if MM.log2_fp(hi) - LOG_100 <= y then lo = hi end
  if lo < MM.MAX_T and (MM.log2_fp(lo + 1) - LOG_100) - y < y - (MM.log2_fp(lo) - LOG_100) then lo = lo + 1 end
  return lo
end

--- Complément d'UN effet : C = (T − 100) − S, borné à ±MM.MAX_C. Renvoie C, T, S.
function MM.effect_complement(list)
  local s = 0
  for i = 1, #list do s = s + list[i] end
  local t = MM.target(list)
  local c = (t - 100) - s
  if c > MM.MAX_C then c = MM.MAX_C end
  if c < -MM.MAX_C then c = -MM.MAX_C end
  return c, t, s
end

--- Effets en centièmes d'une machine : `mods` = liste (ordre des cases) de tables { speed = e, consumption = e,
--- productivity = e } (entiers, champs absents = 0) ; chaque module compte une fois. Renvoie :
---   { speed = { c = C, t = T, s = S }, consumption = {…}, productivity = {…} }
--- Seuls les modules qui PORTENT l'effet entrent dans son produit (un module sans effet de vitesse ne multiplie
--- pas la vitesse par 1 : même résultat, moins de travail). Productivité : complément nul si
--- MM.PRODUCTIVITY_MULTIPLIES est faux (le moteur additionne). Énergie : au plafond, elle garde l'écart
--- (MM.energy_keep_gap) si MM.ENERGY_KEEPS_GAP ; le champ `gap` de l'énergie vaut alors true.
function MM.complements(mods, opts)
  local prod_mult = MM.PRODUCTIVITY_MULTIPLIES
  if opts and opts.productivity_multiplies ~= nil then prod_mult = opts.productivity_multiplies end
  local keep_gap = MM.ENERGY_KEEPS_GAP
  if opts and opts.energy_keeps_gap ~= nil then keep_gap = opts.energy_keeps_gap end
  local out, lists = {}, {}
  for _, effect in ipairs(MM.EFFECTS) do
    local list = {}
    for i = 1, #mods do
      local v = mods[i][effect]
      if v and v ~= 0 then list[#list + 1] = v end
    end
    lists[effect] = list
    local c, t, s = MM.effect_complement(list)
    if effect == "productivity" and not prod_mult then
      c, t = 0, 100 + s
    end
    out[effect] = { c = c, t = t, s = s }
  end
  if keep_gap then
    local te = MM.energy_keep_gap(mods, lists, prod_mult)
    local e = out.consumption
    if te and te < e.t then
      local c = (te - 100) - e.s
      if c > MM.MAX_C then c = MM.MAX_C end
      if c < -MM.MAX_C then c = -MM.MAX_C end
      out.consumption = { c = c, t = te, s = e.s, gap = true }
    end
  end
  return out
end

--- Décomposition d'un complément en modules cachés : liste de { sign, bit } (bits croissants). 0 : liste vide.
function MM.decompose(c)
  local out = {}
  if c == 0 then return out end
  local sign = c > 0 and 1 or -1
  local v = c * sign
  if v > MM.MAX_C then v = MM.MAX_C end
  for bit = 0, MM.BITS - 1 do
    local p = 2 ^ bit
    if math.floor(v / p) % 2 == 1 then out[#out + 1] = { sign = sign, bit = bit } end
  end
  return out
end

--- Noms des modules cachés pour un jeu de compléments (ordre : effets de MM.EFFECTS, puis bits croissants).
function MM.beacon_modules(comp)
  local names = {}
  for _, effect in ipairs(MM.EFFECTS) do
    local e = comp[effect]
    if e and e.c ~= 0 then
      for _, d in ipairs(MM.decompose(e.c)) do names[#names + 1] = MM.module_name(effect, d.sign, d.bit) end
    end
  end
  return names
end

--- Somme (centièmes) portée par une liste de noms de modules cachés, par effet : contrôle de la décomposition.
function MM.decoded(names)
  local out = { speed = 0, consumption = 0, productivity = 0 }
  local prefix = MM.PREFIX:gsub("%-", "%%-")
  for _, nm in ipairs(names) do
    local effect, sg, bit = nm:match("^" .. prefix .. "(%a+)%-([pn])(%d%d)$")
    if effect then out[effect] = out[effect] + (sg == "p" and 1 or -1) * 2 ^ tonumber(bit) end
  end
  return out
end

--- Un jeu de compléments a-t-il besoin d'une balise ?
function MM.needs_beacon(comp)
  for _, effect in ipairs(MM.EFFECTS) do
    if comp[effect] and comp[effect].c ~= 0 then return true end
  end
  return false
end

--- Facteur affiché (texte « × 4,67 ») d'un T en centièmes : chaîne SANS flottant (entiers seulement).
function MM.factor_text(t, decimal_sep)
  decimal_sep = decimal_sep or ","
  local whole = math.floor(t / 100)
  local frac = t - whole * 100
  return whole .. decimal_sep .. string.format("%02d", frac)
end

--- Bonus affiché (texte « +367 % ») d'un T en centièmes.
function MM.bonus_text(t)
  local b = t - 100
  return (b >= 0 and "+" or "") .. b .. " %"
end

return MM
