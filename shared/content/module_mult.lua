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

  PRODUCTIVITÉ : Q-M4 n'est PAS tranchée. Réglage UNIQUE ci-dessous : false = la productivité reste ADDITIVE (le
  moteur), aucun complément de productivité ; true = elle se multiplie comme la vitesse. Les modules cachés de
  productivité existent dans les deux cas (données identiques : basculer ne change que le script). POLLUTION : hors
  de la décision du DC, reste additive (moteur), aucun complément.
]]

local MM = {}

--- Réglage unique (Q-M4, en attente du DC) : la productivité se multiplie-t-elle ? false = additive (moteur).
MM.PRODUCTIVITY_MULTIPLIES = false

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

--- Facteur voulu T (centièmes) pour une liste d'effets en centièmes e_i : round(Π (100 + e_i) / 100^(n−1)),
--- chaque facteur au moins MM.MIN_FACTOR, résultat borné à [MM.MIN_T, MM.MAX_T]. Indépendant de l'ordre (produit
--- exact). Liste vide : 100.
function MM.target(list)
  local n = #list
  if n == 0 then return 100 end
  local big = { 1 }
  local used = 0
  for i = 1, n do
    local f = 100 + list[i]
    if f < MM.MIN_FACTOR then f = MM.MIN_FACTOR end
    big_mul(big, f)
    used = used + 1
  end
  return big_scaled_round(big, used - 1, MM.MIN_T, MM.MAX_T)
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
--- pas la vitesse par 1 : même résultat, moins de travail). Productivité : complément nul tant que
--- MM.PRODUCTIVITY_MULTIPLIES est faux (le moteur additionne).
function MM.complements(mods, opts)
  local prod_mult = MM.PRODUCTIVITY_MULTIPLIES
  if opts and opts.productivity_multiplies ~= nil then prod_mult = opts.productivity_multiplies end
  local out = {}
  for _, effect in ipairs(MM.EFFECTS) do
    local list = {}
    for i = 1, #mods do
      local v = mods[i][effect]
      if v and v ~= 0 then list[#list + 1] = v end
    end
    local c, t, s = MM.effect_complement(list)
    if effect == "productivity" and not prod_mult then
      c, t = 0, 100 + s
    end
    out[effect] = { c = c, t = t, s = s }
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
