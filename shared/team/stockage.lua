--[[
  Lot STOCKAGE-VITAL (retour du DC en jeu sur 0.6.58, 7/11 : « ils se sont retrouvés avec des coffres remplis de pierres […] ils ont pas
  pensé à poser des coffres […] c'est en posant les coffres à un moment que ça s'est libéré […] les coffres, il faudrait prévoir »).
  Règle PURE (aucun appel au moteur) : le stock d'une équipe (coffre du QG + annexes, script/team/stock.lua) garde de la place aux
  matières VITALES (fer, charbon : T.stock_vital), cesse de ramasser une matière non vitale quand elle est saturée ou que le stock est
  presque plein, et réclame un coffre en URGENCE au-dessus d'un seuil de remplissage, avant la saturation.

    Sg.reserve_slots(size, cfg)                 cases gardées aux matières vitales (cfg.reserve des cases, arrondi au-dessus)
    Sg.new_stacks(item, empty, size, vital, cfg) cases VIDES que `item` peut prendre (vitale : toutes ; sinon au-delà de la réserve)
    Sg.skip(saturated, fill, vital, cfg, short) matières à NE PAS ramasser aux avant-postes : non vitales saturées tant qu'une autre
                                                matière manque (short ~= false : même règle que le cerveau, Ia3.after_poles, et que le
                                                stop_stone de la sortie de spirale, shared/team/spirale.lua, qui s'y ramène), et toutes
                                                les non vitales quand le stock est rempli à cfg.stop_at ou plus (ensemble { [objet] = true }) ;
                                                jamais une matière de `need` (Sg.demanded), même stock presque plein
    Sg.demanded(short, missing, links)          matières demandées en ce moment et leur quantité (manque mesuré, manque de l'objectif ;
                                                plaque <-> minerai) : { [objet] = q }
    Sg.demand_room(rec, q, s, m)                part d'une matière demandée qui peut encore entrer dans la réserve des vitales (borne q,
                                                comptée par pensée : s et m, tables de la demande de cette pensée)
    Sg.urgent(fill, have_chest, cfg)            vrai : coffre à réclamer en urgence (rempli à cfg.urgent_at ou plus, aucun en main)
    Sg.fits(rows, empty)                        un contenu tient-il au stock (piles entamées, puis cases vides) ; (vrai/faux, cases)
  `fill` = cases prises / cases ; `vital` = { [objet] = true } ; `saturated` = { [objet] = true } (cerveau, f.team.ia3.saturated).
  Données : T.stockage (shared/team/config.lua).
]]

local Sg = {}

Sg.DEFAULT = { reserve = 0.15, stop_at = 0.80, urgent_at = 0.80 }

local function cfg_of(cfg) return cfg or Sg.DEFAULT end

function Sg.reserve_slots(size, cfg)
  cfg = cfg_of(cfg)
  if not size or size <= 0 then return 0 end
  return math.ceil(cfg.reserve * size - 1e-9)
end

function Sg.new_stacks(item, empty, size, vital, cfg)
  empty = math.max(0, empty or 0)
  if vital and vital[item] then return empty end
  return math.max(0, empty - Sg.reserve_slots(size, cfg))
end

--- Matières DEMANDÉES en ce moment, que Sg.skip n'écarte jamais (relecture du 7/11 : un stock à 90 % au plafond d'annexes ne doit
--- pas arrêter le cuivre que l'équipe attend) : manque brut mesuré du cerveau (`short` = { [objet] = n }, f.team.ia3.short, net du
--- stock) et manque de l'objectif courant (`missing` = { {objet, n}, ... }, f.team.missing, net du stock lui aussi) ; une plaque
--- demandée rend son minerai demandé, et l'inverse (`links` = { {minerai, plaque}, ... }, T.outposts : le minage à la main vise le
--- minerai, le ramassage des avant-postes la plaque). Rend { [objet] = q } : la plus grande des quantités demandées (les deux manques se
--- recouvrent : celui de l'objectif est une part du manque brut), q partagée par la plaque et son minerai (1 pour 1, fonte vanilla) ;
--- l'ordre de pairs ne change pas le résultat (maximum).
function Sg.demanded(short, missing, links)
  local out = {}
  for item, n in pairs(short or {}) do
    if type(n) == "number" and n > 0 then out[item] = math.max(out[item] or 0, n) end
  end
  for _, m in ipairs(missing or {}) do
    local n = tonumber(m[2]) or 0
    if type(m[1]) == "string" and n > 0 then out[m[1]] = math.max(out[m[1]] or 0, n) end
  end
  for _, l in ipairs(links or {}) do
    local q = math.max(out[l[1]] or 0, out[l[2]] or 0)
    if q > 0 then out[l[1]], out[l[2]] = q, q end
  end
  return out
end

--- Relecture revue-0659 (D1) : une matière demandée entre au dépôt dans la réserve des vitales, comme une vitale, jusqu'à la quantité
--- demandée `q` et pas au-delà (sinon elle mangerait la réserve du fer et du charbon). `rec` = { q, used = déjà entrée dans la réserve
--- pour elle, s, m } : compté PAR PENSÉE (relecture de 3a276733, B1 : lié à la seule valeur q, une demande revenue à la même quantité
--- après un creux trouvait used = q et la matière était refusée de nouveau) ; `s` et `m` sont les tables de la demande de la pensée
--- (f.team.ia3.short et f.team.missing, refaites à neuf à chaque pensée : shared/ai3/cerveau.lua, st.short ; script/team/team.lua,
--- f.team.missing), comparées par identité : une pensée neuve remet le compte à zéro, la demande y étant recomptée NETTE du stock ; la
--- somme des dépôts d'une même pensée ne dépasse pas q. Rend (place, rec) ; (0, rec) sans demande.
function Sg.demand_room(rec, q, s, m)
  if not q or q <= 0 then return 0, rec end
  if not rec or rec.q ~= q or rec.s ~= s or rec.m ~= m then rec = { q = q, used = 0, s = s, m = m } end
  return math.max(0, q - rec.used), rec
end

function Sg.skip(saturated, fill, vital, cfg, short, need)
  cfg = cfg_of(cfg)
  local out = {}
  vital = vital or {}
  need = need or {}
  if short ~= false then
    for item in pairs(saturated or {}) do
      if not vital[item] and not need[item] then out[item] = true end
    end
  end
  out.__all_non_vital = (fill or 0) >= cfg.stop_at or nil
  if out.__all_non_vital and next(need) ~= nil then out.__keep = need end
  return out
end

--- Vrai si `item` ne doit pas être ramassé selon l'ensemble rendu par Sg.skip (jamais une vitale, jamais une matière demandée).
function Sg.skipped(set, item, vital)
  if not set or (vital and vital[item]) then return false end
  if set.__keep and set.__keep[item] then return false end
  return set[item] == true or set.__all_non_vital == true
end

--- Lot STOCKAGE-VITAL (objets au sol, 7/11) : `rows` = { { n = objets, stack = taille de pile, part = place des piles entamées de cet
--- objet }, ... } (un objet par ligne) tient-il dans `empty` cases vides ? Rend (vrai/faux, cases neuves nécessaires).
function Sg.fits(rows, empty)
  local need = 0
  for _, r in ipairs(rows or {}) do
    local rest = (r.n or 0) - (r.part or 0)
    if rest > 0 then need = need + math.ceil(rest / math.max(1, r.stack or 1)) end
  end
  return need <= (empty or 0), need
end

function Sg.urgent(fill, have_chest, cfg)
  cfg = cfg_of(cfg)
  return (fill or 0) >= cfg.urgent_at and not have_chest
end

return Sg
