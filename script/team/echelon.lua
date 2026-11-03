--[[
  Lot ECHELON : côté RUNTIME de la règle pure shared/ai3/echelon.lua (lecture de l'état des chantiers, réglage, journal). Aucune décision ici.
  Réglage : fo-war-echelon (settings/industrie.lua, runtime-global, allumé par défaut). Éteint, rien n'est lu ni changé : le jeu est celui de main.
  Trois usages :
    1. Ex.held / Ex.produces : le PRODUCTEUR de ce qui manque passe d'abord à la réserve des chantiers (script/team/build.lua, reserve).
    2. Ex.waiters : les chantiers en attente de matière, lus par Ech.backlog (script/ai3/industrie.lua : la demande des chantiers).
    3. Ex.say : journal [FO-ECHELON] (une ligne par changement).
  Rien ici n'écrit dans global : lecture de f.build.projects seulement ; les lignes déjà dites se retiennent dans f.build.echelon (chaînes).
]]

local Ech = require("shared.ai3.echelon")

local Ex = {}

Ex.SETTING = "fo-war-echelon"

--- Essai 2 du lot (3/11) : la demande des chantiers (Ind.echelon_sources) a fait perdre 29 % des plaques sur 20261020 ; ELLE EST COUPEE tant qu'une mesure ne la rehabilite pas.
--- Le producteur d'abord (Ex.held) reste actif.
Ex.DEMAND = false

function Ex.on()
  local ok, s = pcall(function() return settings.global[Ex.SETTING] end)
  return ok and s ~= nil and s.value == true
end

--- Chantiers de l'équipe qui attendent de la matière : { { id, since, missing } } dans l'ordre de b.order. Un projet en « reserve » seulement :
--- les projets rouverts pour reconstruction ne retiennent pas de matière à la réserve (refresh_missing ne retire rien au coffre).
function Ex.waiters(f)
  local out = {}
  local b = f and f.build
  if not b then return out end
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    if p and p.state == "reserve" and p.missing and #p.missing > 0 then
      out[#out + 1] = { id = p.id, since = p.started or p.created or 0, missing = p.missing }
    end
  end
  return out
end

--- Ensemble des objets qu'un projet fabrique : le produit de son module (spec.product), sinon rien.
function Ex.produces(p)
  local prod = p and p.spec and p.spec.product
  if type(prod) == "string" then return { [prod] = true } end
  return {}
end

--- Ce qu'un projet peut prendre de `have` (objets libres au coffre) : le producteur de l'objet prend tout, un autre laisse la part retenue.
--- `held` : rendu par Ex.held (nil : rien de retenu, `have` inchangé). `prod` : Ex.produces(p).
function Ex.limit(held, prod, item, have)
  if not held or not held[item] then return have end
  return Ech.take_limit(have, held[item], prod[item] == true)
end

--- Quantités que les producteurs en attente retiennent, { [objet] = n }, ou nil (réglage éteint ou aucun producteur en attente).
function Ex.held(f, tick)
  if not Ex.on() then return nil end
  local b = f and f.build
  if not b then return nil end
  local list = {}
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    if p and p.state == "reserve" and p.missing and #p.missing > 0 then
      list[#list + 1] = { id = p.id, state = p.state, since = p.started or p.created or 0, produces = Ex.produces(p), missing = p.missing }
    end
  end
  local held = Ech.held_back(list, tick)
  if next(held) == nil then return nil end
  local parts = {}
  for _, k in ipairs(Ech.sorted_keys(held)) do parts[#parts + 1] = string.format("%s %d", k, held[k]) end
  Ex.say(f, tick, "retenu", "le producteur de ce qui manque passe d'abord : les autres chantiers laissent {" .. table.concat(parts, ", ") .. "}")
  return held
end

--- Journal [FO-ECHELON] : une ligne par changement de texte (clé = sujet), au plus une toutes les Ex.SAY_GAP ticks par sujet (les chiffres d'un
--- arriéré bougent à chaque pensée).
Ex.SAY_GAP = 5 * 3600
function Ex.say(f, tick, key, text)
  local b = f and f.build
  if not b then return end
  b.echelon = b.echelon or {}
  b.echelon_tick = b.echelon_tick or {}
  if b.echelon[key] == text then return end
  if b.echelon_tick[key] and (tick or 0) - b.echelon_tick[key] < Ex.SAY_GAP then return end
  b.echelon[key] = text
  b.echelon_tick[key] = tick or 0
  log(string.format("[FO-ECHELON] %s minute %.1f | %s", f.key or "player", (tick or 0) / 3600, text))
end

return Ex
