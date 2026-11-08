--[[
  Lot VIDEO-L13 « PLAFONDS ET GARDES FERMÉES PAR DÉFAUT » (feuille de route validée par le DC le 7/11 :
  docs/VIDEO_AUTOMATISATION.md §6 L13, docs/TODO_VIDEO.md §G rang 12, lignes W01, C13, G02). Règle PURE, testée hors jeu
  (tests/plafonds_test.lua). BRANCHÉE : shared/ai3/capitalisation.lua:2109-2222 (Pf.open_room, Pf.ledger,
  Pf.fits_item, Pf.take) pour les sortes de Ca.CAPPED (:164).

  Référence : le bug des « silos sans fin » de la vidéo de suite (V2 0:56-2:36 ; commentaire C13) : une garde lisait le signal
  d'un mod absent, l'entrée valait 0, la condition « en manque » restait vraie et l'usine posait des silos sans fin. Ici :
    1. GARDE FERMÉE PAR DÉFAUT : une entrée absente (nil), non numérique, non finie (NaN, ±inf) ou négative FERME la garde, avec
       un refus écrit qui la nomme. Jamais `x or 0` sur l'entrée d'une garde.
    2. PLAFOND PAR OBJET, relatif à la demande : débit posé (tous états, confirmé ou non : lot L5) + débit des ordres ouverts +
       débit ajouté ≤ Pf.K × la demande. Exception : la PREMIÈRE unité d'un objet demandé (rien de posé ni d'ouvert, une unité
       ajoutée) passe toujours, même si son débit dépasse Pf.K × la demande (une machine trop rapide pour un petit besoin).
       Demande nulle : rien.
    3. PLAFOND ABSOLU en nombre (G02, MAX_MEGATILES = 484 chez l'auteur ; Ml.MACHINES_MAX = 64 chez nous) : posés + ouverts +
       ajoutés ≤ Pf.HARD (ou s.hard).
    4. DÉCISION ENTIÈRE : un registre (Pf.ledger) décompte chaque ajout accordé (Pf.take) ; deux ordres de la même décision sur
       le même objet ne dépassent pas le plafond à eux deux.
    5. PLAFOND DES ORDRES OUVERTS (comparaison avec Ca.OPEN_MAX, shared/ai3/capitalisation.lua:148, 1970) : Pf.open_room lit la
       LISTE des ordres ouverts ; absente, la garde est fermée (Ca.decide lit `#ctx.open`, où ctx.open vaut {} quand
       input.open manque : la garde y est OUVERTE sur une entrée absente).
  Unités : demande, posé, ouvert et ajout dans la même unité (objets/min en général) ; les nombres (n_posed, n_open, add.n) en
  unités posées. Déterminisme : aucune table parcourue par pairs pour décider, aucun hasard ; entrées et sorties : nombres,
  chaînes, tables. Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua §8).
]]

local Pf = {}

Pf.K = 2      -- plafond = 2 fois la demande (même rapport que Ca.LEAD, Ca.CHAIN_LEAD, Ml.LEAD)
Pf.HARD = 64  -- unités posées + ouvertes au plus par objet (Ml.MACHINES_MAX)
Pf.EPS = 1e-9

local function fmt(x)
  if type(x) ~= "number" then return tostring(x) end
  if x == math.floor(x) and math.abs(x) < 1e15 then return string.format("%d", x) end
  return string.format("%.1f", x)
end

--- Entrée d'une garde (règle 1). Rend v (nombre fini, ≥ 0) ou nil et la raison du refus.
function Pf.input(v, name)
  if type(v) == "number" and v == v and v >= 0 and v ~= math.huge then return v end -- (cas courant : aucun texte formaté)
  name = tostring(name or "?")
  if v == nil then return nil, "entree absente : " .. name end
  if type(v) ~= "number" then return nil, "entree non numerique : " .. name end
  if v ~= v or v == math.huge or v == -math.huge then return nil, "entree invalide : " .. name end
  if v < 0 then return nil, "entree negative : " .. name end
  return v
end

--- Relevé du courant d'une décision (lot VIDEO-COUVERTURE 5, critère C5.4, TODO W02) : rend nil quand la garde est ouverte, sinon la
--- raison du refus, qui NOMME l'entrée. `pw` = input.power de Ca.decide :
---   nil          aucune centrale finie : l'AMORÇAGE (le premier ordre électrique demande la centrale, script/ai3/automatisation.lua,
---                submit ; fermer ici empêcherait l'électrification de jamais commencer) ; l'exécutant refuse déjà ce qui ne se pose pas ;
---   table        un relevé existe : sa capacité (have_kw) doit être un nombre fini ≥ 0. Absente, une centrale FINIE dont la capacité n'est
---                pas encore lue ouvrait des foreuses sans borne (garde ouverte sur mesure manquante : les « silos sans fin » de C13).
function Pf.power_missing(pw)
  if pw == nil then return nil end
  local _, why = Pf.input(pw.have_kw, "power.have_kw")
  return why
end

--- Le même refus, en texte de journal (« courant : entree absente : power.have_kw »), ou nil.
function Pf.power_why(pw)
  local why = Pf.power_missing(pw)
  return why and ("courant : " .. why) or nil
end

local OPS = {
  ["<"] = function(a, b) return a < b end,
  ["<="] = function(a, b) return a <= b end,
  [">"] = function(a, b) return a > b end,
  [">="] = function(a, b) return a >= b end,
}

--- Comparaison fermée par défaut : vrai seulement si la valeur ET la limite sont présentes et que la relation tient. Rend ok,
--- raison (le refus, ou la relation vérifiée).
function Pf.test(v, op, limit, name)
  local f = OPS[op]
  if not f then return false, "operateur inconnu : " .. tostring(op) end
  local a, wa = Pf.input(v, name)
  if a == nil then return false, wa end
  local b, wb = Pf.input(limit, tostring(name or "?") .. " (limite)")
  if b == nil then return false, wb end
  if f(a, b) then return true, string.format("%s %s %s %s", tostring(name or "?"), fmt(a), op, fmt(b)) end
  return false, string.format("%s %s non %s %s", tostring(name or "?"), fmt(a), op, fmt(b))
end

--- Le plafond d'un objet accepte-t-il l'ajout ? s = { demand, posed, open (débits), n_posed, n_open (nombres), k, hard
--- (facultatifs) } ; add = { rate, n }. Rend ok, raison (celle du refus ; nil quand l'ajout passe sous le plafond, le texte
--- « premiere unite » quand il passe par l'exception de la règle 2).
function Pf.fits(s, add, item)
  local who = tostring(item or "?")
  if type(s) ~= "table" then return false, "plafond " .. who .. " : aucun releve" end
  if type(add) ~= "table" then return false, "plafond " .. who .. " : ajout absent" end
  local vals = {}
  for _, f in ipairs({ { "demand", s.demand }, { "posed", s.posed }, { "open", s.open }, { "n_posed", s.n_posed },
      { "n_open", s.n_open }, { "add.rate", add.rate }, { "add.n", add.n } }) do
    local v, why = Pf.input(f[2], f[1])
    if v == nil then return false, "plafond " .. who .. " : " .. why end
    vals[f[1]] = v
  end
  local k = Pf.K
  if s.k ~= nil then
    local v, why = Pf.input(s.k, "k")
    if v == nil then return false, "plafond " .. who .. " : " .. why end
    k = v
  end
  local hard = Pf.HARD
  if s.hard ~= nil then
    local v, why = Pf.input(s.hard, "hard")
    if v == nil then return false, "plafond " .. who .. " : " .. why end
    hard = v
  end
  local n_after = vals.n_posed + vals.n_open + vals["add.n"]
  if n_after > hard + Pf.EPS then
    return false, string.format("plafond %s : %s posees + %s ouvertes + %s > %s au plus", who, fmt(vals.n_posed),
      fmt(vals.n_open), fmt(vals["add.n"]), fmt(hard))
  end
  if vals.demand <= Pf.EPS then return false, "plafond " .. who .. " : demande nulle" end
  local cap = k * vals.demand
  local after = vals.posed + vals.open + vals["add.rate"]
  if after <= cap + Pf.EPS then return true end -- (aucune raison formatée : appelé pour chaque option essayée)
  local first = vals.posed <= Pf.EPS and vals.open <= Pf.EPS and vals.n_posed <= Pf.EPS and vals.n_open <= Pf.EPS
  if first and vals["add.n"] <= 1 + Pf.EPS then
    return true, string.format("plafond %s : premiere unite (%s/min pour une demande de %s/min)", who, fmt(vals["add.rate"]),
      fmt(vals.demand))
  end
  return false, string.format("plafond %s : %s/min poses + %s/min ouverts + %s/min > %s x demande %s/min", who, fmt(vals.posed),
    fmt(vals.open), fmt(vals["add.rate"]), fmt(k), fmt(vals.demand))
end

--- Registre d'une décision : { [objet] = s } (copies : la décision ne touche pas les relevés de l'appelant).
function Pf.ledger(states)
  local l = {}
  local ks = {}
  for k in pairs(states or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  for _, it in ipairs(ks) do
    local s = states[it]
    if type(s) == "table" then
      l[it] = { demand = s.demand, posed = s.posed, open = s.open, n_posed = s.n_posed, n_open = s.n_open, k = s.k,
        hard = s.hard }
    end
  end
  return l
end

--- L'ajout passe-t-il le plafond de son objet dans le registre ? (objet absent du registre : fermé)
function Pf.fits_item(ledger, item, add)
  return Pf.fits(ledger and ledger[item], add, item)
end

--- Décompte d'un ajout accordé (règle 4). Rend vrai si le décompte est fait ; faux (registre inchangé) si l'objet n'est pas au
--- registre ou qu'une valeur manque : un décompte ne remplace jamais une entrée absente (la garde resterait fermée de toute façon).
function Pf.take(ledger, item, add)
  local s = ledger and ledger[item]
  if type(s) ~= "table" or type(add) ~= "table" then return false end
  local o, no, r, n = Pf.input(s.open), Pf.input(s.n_open), Pf.input(add.rate), Pf.input(add.n)
  if o == nil or no == nil or r == nil or n == nil then return false end
  s.open, s.n_open = o + r, no + n
  return true
end

--- Plus grand nombre d'unités de débit `unit` qui passe le plafond (0 à want). Rend n, raison du refus de n + 1 (nil si want
--- passe en entier).
function Pf.room(s, unit, want, item)
  local u, wu = Pf.input(unit, "unit")
  if u == nil or u <= Pf.EPS then return 0, "plafond " .. tostring(item or "?") .. " : " .. (wu or "debit unitaire nul") end
  local w, ww = Pf.input(want, "want")
  if w == nil then return 0, "plafond " .. tostring(item or "?") .. " : " .. ww end
  w = math.floor(w + Pf.EPS)
  local lo, hi, best, why = 1, w, 0, nil
  while lo <= hi do -- le plafond est monotone en n : dichotomie
    local mid = math.floor((lo + hi) / 2)
    local ok, r = Pf.fits(s, { rate = mid * u, n = mid }, item)
    if ok then best, lo = mid, mid + 1 else hi, why = mid - 1, r end
  end
  if best >= w then why = nil end
  return best, why
end

--- Places d'ordres ouverts (règle 5). open = LISTE des ordres ouverts (nil : fermée), max = plafond. Rend room (≥ 0), raison
--- (du refus quand room = 0).
function Pf.open_room(open, max)
  if type(open) ~= "table" then return 0, "ordres ouverts : entree absente" end
  local m, why = Pf.input(max, "plafond des ordres ouverts")
  if m == nil then return 0, "ordres ouverts : " .. why end
  local room = math.max(0, math.floor(m + Pf.EPS) - #open)
  if room <= 0 then return 0, string.format("%d ordres ouverts (au plus %s)", #open, fmt(m)) end
  return room
end

return Pf
