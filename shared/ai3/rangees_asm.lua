--- Lot RANGEES-ASM (demande du DC, 8/11, 13 h 05) : « Si la base manque de câbles de cuivre, tes agents ne doivent pas poser
--- 5 îlots isolés à des kilomètres de distance avec 5 coffres différents. Ils doivent aligner une rangée d'assembleurs (ex: 5 à
--- la suite) qui partagent la même ligne d'entrée (input de cuivre) et la même ligne de sortie, exactement comme le ferait un
--- joueur humain optimisé. »
---
--- Règle PURE (aucun nom d'objet, aucun moteur) : un ordre « chaine » d'un objet arrive avec un débit demandé. Avant ce lot,
--- chaque ordre ouvrait un module NEUF (script/ai3/capitalisation.lua, execute) d'au plus A.FIRST_RATE_MAX objets/min : une
--- hausse de la demande donnait un îlot de plus, chacun avec son quai. Ici, pour les rangées de la même recette (par numéro) :
---   1. AGRANDIR la première qui le peut : « attente » (rien de posé : son gabarit est refait plus long) ou « dyn » (rangée
---      dynamique, finie, avec des machines en attente : rendues au chantier sur place, script/team/rangee_dyn.lua) ;
---   2. sinon, une rangée en chantier qui pourra grandir : REFUS « agrandie a sa fin » (jamais un îlot de plus pendant un chantier) ;
---   3. sinon (rangées pleines, figées ou aucune), une rangée NEUVE dimensionnée sur la demande (k machines), portée à Ra.MIN_ROW
---      quand la demande justifie une rangée (k >= Ra.JUSTIFY), bornée par le gabarit, posée PRÈS d'une rangée existante ;
---   4. refus avec sa cause (débit nominal nul, demande nulle, gabarit sans borne).
--- Ra.pick : variante du gabarit (deux voies, tapis plus rapide débloqué) quand une voie du tapis jaune bornerait la rangée sous
--- Ra.MIN_ROW (câbles en assembleur 2 : 2 sur une voie jaune, 4 sur deux, 5 sur une voie rapide).
local Ra = {}

Ra.MIN_ROW = 5          -- machines au moins d'une rangée neuve quand la demande la justifie (« ex: 5 à la suite »)
Ra.JUSTIFY = 2          -- la demande justifie une rangée dès qu'elle occupe au moins 2 machines (1 : une machine suffit)
Ra.GROWABLE = { attente = true } -- états où le gabarit d'un module se change sans rien défaire (rangée sans mode écrit)
Ra.MODES = { attente = true, dyn = true } -- modes d'agrandissement ; « chantier » : pourra grandir une fois finie

local function sorted_existing(existing)
  local out = {}
  for _, e in ipairs(existing or {}) do out[#out + 1] = e end
  table.sort(out, function(a, b) return (a.id or 0) < (b.id or 0) end)
  return out
end

--- Mode et borne d'une rangée existante : e.grow écrit par l'exécutant, sinon « attente » si son état le permet (borne de l'ordre).
local function mode_of(e, n_max)
  local mode = e.grow
  if mode == nil and Ra.GROWABLE[e.state] then mode = "attente" end
  return mode, math.floor(e.n_max or n_max)
end

--- q = { rate = objets/min demandés, nom1 = objets/min d'UNE machine, n_max = borne du gabarit (machines),
---       existing = { { id, n, state, grow = "attente" | "dyn" | "chantier" | nil, n_max } } rangées de la même recette }.
--- Rend { action = "agrandir" | "nouveau" | "refus", mode, n, k, target, from, near, why }.
function Ra.decide(q)
  q = q or {}
  if not (type(q.nom1) == "number" and q.nom1 > 0) then return { action = "refus", why = "debit nominal nul" } end
  if not (type(q.rate) == "number" and q.rate > 0) then return { action = "refus", why = "demande nulle" } end
  if not (type(q.n_max) == "number" and q.n_max >= 1) then return { action = "refus", why = "gabarit sans borne" } end
  local n_max = math.floor(q.n_max)
  local k = math.max(1, math.ceil(q.rate / q.nom1 - 1e-9))
  local ex = sorted_existing(q.existing)
  for _, e in ipairs(ex) do
    local n0 = e.n or 0
    local mode, cap = mode_of(e, n_max)
    if Ra.MODES[mode] and n0 >= 1 and n0 < cap then
      return { action = "agrandir", mode = mode, target = e.id, from = n0, n = math.min(cap, n0 + k), k = k,
        why = mode == "dyn" and "rangee dynamique de la meme recette, finie, place reservee" or "rangee de la meme recette en attente" }
    end
  end
  for _, e in ipairs(ex) do
    local mode, cap = mode_of(e, n_max)
    if mode == "chantier" and (e.n or 0) < cap then
      return { action = "refus", target = e.id, k = k, why = "rangee de la meme recette en chantier : agrandie a sa fin" }
    end
  end
  local n = k
  if k >= Ra.JUSTIFY then n = math.max(k, Ra.MIN_ROW) end
  n = math.min(n, n_max)
  local near = nil
  for _, e in ipairs(ex) do
    if e.state ~= "refuse" then near = e.id break end
  end
  return { action = "nouveau", n = n, k = k, near = near,
    why = near and "rangees existantes pleines ou figees : nouvelle rangee a cote" or "aucune rangee de cette recette" }
end

--- Variante du gabarit (liste du moins cher au plus cher : une voie, deux voies, puis chaque tapis plus rapide DÉBLOQUÉ, une puis deux
--- voies) : la première dont la borne atteint Ra.MIN_ROW ; sinon celle de la plus grande borne (la première à égalité). maxes[i] :
--- borne de la variante i, nil si elle ne se pose pas. Rend l'indice, ou nil si aucune ne se pose.
function Ra.pick(maxes)
  local best, bmax = nil, -1
  for i = 1, #maxes do
    local m = maxes[i]
    if type(m) == "number" then
      if m >= Ra.MIN_ROW then return i end
      if m > bmax then best, bmax = i, m end
    end
  end
  return best
end

--- Ligne de journal d'une décision : [FO-RANGEES-ASM].
function Ra.line(who, item, rate, d)
  return string.format("[FO-RANGEES-ASM] %s : %s %.0f/min -> %s%s%s%s%s (%s)", tostring(who), tostring(item), rate or 0,
    tostring(d.action),
    d.mode and ("-" .. tostring(d.mode)) or "",
    d.target and (" module " .. tostring(d.target) .. (d.from and (" de " .. tostring(d.from)) or "")) or "",
    d.n and (" a " .. tostring(d.n) .. " machine(s), besoin " .. tostring(d.k)) or "",
    d.near and (" pres du module " .. tostring(d.near)) or "",
    tostring(d.why))
end

return Ra
