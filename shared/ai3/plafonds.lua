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

local Ex = require("shared.ai3.exclusion") -- lot VIDEO-PLAFONDS, partie d (V99) : objets exclus de la demande

local Pf = {}

Pf.K = 2      -- plafond = 2 fois la demande (même rapport que Ca.LEAD, Ca.CHAIN_LEAD, Ml.LEAD)
Pf.HARD = 64  -- unités posées + ouvertes au plus par objet (Ml.MACHINES_MAX)
Pf.EPS = 1e-9

-- Lot VIDEO-PLAFONDS (G02, G03, G64) : PLAFOND DE SÛRETÉ PAR SORTE d'ordre, en DONNÉES (aucun nom d'objet : la sorte est le mot de
-- la capitalisation, `Ca.CAPPED`). Unités posées + ouvertes + voulues au plus. Une sorte absente du tableau n'a PAS de plafond de
-- sûreté ici (Pf.NO_HARD, hors d'atteinte : le témoin A/B de VIDEO-INTEG change 116 rendus sur 502 avec Pf.HARD = 64 pour les fours,
-- les chaînes et les packs, et Ca.CAP_HARD le laisse hors d'atteinte, à trancher par le lead et le DC).
--   labos = 25 : MAX_RESEARCH_TILES = 25 chez l'auteur (G03, « plafond du sommet » ; G64 : la recherche ne grandit plus au-delà).
Pf.NO_HARD = 1e6
Pf.HARD_KIND = { labos = 25 }

-- Lot TV-PILOTE (G02, « plafond de sûreté par type », MAX_MEGATILES = 484 chez l'auteur) : plafond de sûreté PAR OBJET et PAR SORTE pour les
-- fours, les chaînes et les packs, en DONNÉES (aucun nom d'objet). Unités posées + ouvertes + voulues d'UN objet, au plus (Pf.fits, s.hard ;
-- Ca.cap_hard choisit la sorte d'un objet). Valeurs MESURÉES, non devinées (fo-logs/2026-11-08_TV-PILOTE/MESURE_PLAFONDS.md) :
--   Le témoin A/B de VIDEO-INTEG a montré qu'un plafond UNIQUE de 64 change 116 rendus sur 502 : 64 fours ne tiennent pas l'arrivée de
--   1 800 minerais/min de la partie du DC (journal 0.6.58, minute 177 : plaques de fer à 1 749/min visées = 94 fours de pierre à 18,75/min,
--   le plus lent des fours). Le plafond d'un four doit donc passer au-dessus : fours = 192 (plus de 2 fois les 94, 4 fois les 47 des fours
--   d'acier), que la fonte à la main ne sert pas non plus (32 places de rangées au QG, Br.SMELT_HARD = 16).
--   Chaînes : le plus gros ordre vu dans 4 parties archivées (0.6.58 à 0.6.64, 8 factions) est de 9 machines (engrenages) ; une rangée
--   voulue à 2 fois sa demande (Ca.CHAIN_LEAD) reste sous 96 (6 PNJ de service par rangée de 16, 30 PNJ). Packs : 33 machines au plus par
--   ordre (cartes rouges, 163/min visées à 5 s la fabrication), 96 = trois fois cela.
-- Un plafond que le jeu réel n'atteint pas : il ne borne qu'une emballement (les « silos sans fin » de C13). Atteint, il écrit son refus
-- (« plafond <objet> : N posees + M ouvertes + k > H au plus »), journal [FO-CAPI-CONF] « refus » de script/ai3/capitalisation.lua.
Pf.HARD_OBJ = { fours = 192, chaine = 96, packs = 96 }

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

--- Plafond de sûreté d'une sorte d'ordre (Pf.HARD_KIND ; Pf.NO_HARD quand la sorte n'en a pas).
function Pf.hard_for(kind)
  local h = Pf.HARD_KIND[kind]
  if h == nil then return Pf.NO_HARD end
  return h
end

--- Lot TV-PILOTE (G02) : plafond de sûreté d'UN objet fabriqué selon sa sorte (Pf.HARD_OBJ ; Pf.NO_HARD quand la sorte n'en a pas : une
--- sorte inconnue ou absente n'est pas plafonnée ici, le plafond relatif de Pf.fits reste).
function Pf.hard_obj(kind)
  local h = Pf.HARD_OBJ[kind]
  if h == nil then return Pf.NO_HARD end
  return h
end

--- Lot VIDEO-PLAFONDS : combien d'unités d'une sorte d'ordre passent le plafond de sûreté. `want` = unités voulues, `have` =
--- unités déjà posées ou ouvertes. Rend room (0 à want), raison (nil quand tout passe ; sinon le refus, qui commence par
--- « plafond » : le journal [FO-CAPI-CONF] de script/ai3/capitalisation.lua l'écrit). Garde FERMÉE par défaut : une entrée absente
--- ou invalide rend 0 et le dit.
function Pf.kind_room(kind, want, have)
  local who = tostring(kind or "?")
  local w, ww = Pf.input(want, "unites voulues")
  if w == nil then return 0, "plafond " .. who .. " : " .. ww end
  local h, wh = Pf.input(have, "unites posees ou ouvertes")
  if h == nil then return 0, "plafond " .. who .. " : " .. wh end
  w = math.floor(w + Pf.EPS)
  local hard = Pf.hard_for(kind)
  local room = math.max(0, math.min(w, math.floor(hard + Pf.EPS) - math.floor(h + Pf.EPS)))
  if room >= w then return w end
  return room, string.format("plafond %s : %s posees ou ouvertes + %s voulues > %s au plus", who, fmt(h), fmt(w), fmt(hard))
end

--- Lot VIDEO-PLAFONDS, partie d : l'objet est-il exclu de la demande (réglage fo-war-exclusion) ? Passerelle vers Ex.has, pour que
--- shared/ai3/capitalisation.lua n'ait qu'un module de plus à connaître : ce fichier.
function Pf.excluded(set, item) return Ex.has(set, item) end
Pf.excluded_why = Ex.why

--- Lot VIDEO-PLAFONDS : PORTE des options d'une décision (Ca.options), une seule fois par appel. out = liste { o = ordre, mk = fonction
--- (n) -> ordre ou nil } ; excl = ensemble des objets exclus (nil : aucun) ; have = { [sorte] = unités posées ou ouvertes } (une sorte
--- de Pf.HARD_KIND sans valeur ici : garde FERMÉE, le motif le dit) ; refuse(clé, sorte, objet, motif) écrit le refus.
--- Rend une NOUVELLE liste :
---   - une option dont l'objet (item, sinon resource) est exclu est RETIRÉE, refus « exclu : » (clé de l'option) ;
---   - une option d'une sorte plafonnée (Pf.kind_room) est réduite à la taille qui passe (mk(room)), ou retirée à 0 place ; le refus
---     « plafond ... » est écrit sous la clé « plafond:<clé de l'option> » (autre clé que l'ordre retenu : il survit à l'ordre) ;
---   - toute autre option passe telle quelle (même table).
function Pf.gate(out, excl, have, refuse)
  local kept = {}
  for _, c in ipairs(out) do
    local o = c.o
    local item = o.item or o.resource
    if Ex.has(excl, item) then
      refuse(o.key, o.kind, o.item, Ex.why(item))
    elseif Pf.HARD_KIND[o.kind] == nil then
      kept[#kept + 1] = c
    else
      local room, why = Pf.kind_room(o.kind, o.n, have and have[o.kind])
      if why then refuse("plafond:" .. tostring(o.key), o.kind, nil, why) end
      if room >= (o.n or 0) then
        kept[#kept + 1] = c
      elseif room > 0 and c.mk then
        local o2 = c.mk(room)
        if o2 and (o2.n or 0) <= room then kept[#kept + 1] = { o = o2, mk = c.mk } end
      end
    end
  end
  return kept
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
