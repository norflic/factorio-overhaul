--- Lot RANGEES-ASM (demande du DC, 8/11, 13 h 05) : « Si la base manque de câbles de cuivre, tes agents ne doivent pas poser
--- 5 îlots isolés à des kilomètres de distance avec 5 coffres différents. Ils doivent aligner une rangée d'assembleurs (ex: 5 à
--- la suite) qui partagent la même ligne d'entrée (input de cuivre) et la même ligne de sortie, exactement comme le ferait un
--- joueur humain optimisé. »
---
--- Règle PURE (aucun nom d'objet, aucun moteur) : un ordre « chaine » d'un objet arrive avec un débit demandé. Avant ce lot,
--- chaque ordre ouvrait un module NEUF (script/ai3/capitalisation.lua, execute) d'au plus A.FIRST_RATE_MAX objets/min : une
--- hausse de la demande donnait un îlot de plus, chacun avec son quai. Ici :
---   1. un module de la même recette encore EN ATTENTE (rien de posé ni de réservé) et plus court que la borne du gabarit est
---      AGRANDI sur place : sa rangée passe à n + k machines (mêmes tapis prolongés : un seul gabarit plus long) ;
---   2. sinon, une rangée NEUVE dimensionnée sur la demande (k machines), portée à Ra.MIN_ROW quand la demande justifie une
---      rangée (k >= Ra.JUSTIFY), bornée par le gabarit ; posée PRÈS d'une rangée existante de la même recette s'il y en a une ;
---   3. refus avec sa cause (débit nominal nul, demande nulle, gabarit sans borne).
local Ra = {}

Ra.MIN_ROW = 5          -- machines au moins d'une rangée neuve quand la demande la justifie (« ex: 5 à la suite »)
Ra.JUSTIFY = 2          -- la demande justifie une rangée dès qu'elle occupe au moins 2 machines (1 : une machine suffit)
Ra.GROWABLE = { attente = true } -- états du plan directeur où le gabarit d'un module se change encore sans rien défaire

local function sorted_existing(existing)
  local out = {}
  for _, e in ipairs(existing or {}) do out[#out + 1] = e end
  table.sort(out, function(a, b) return (a.id or 0) < (b.id or 0) end)
  return out
end

--- q = { rate = objets/min demandés, nom1 = objets/min d'UNE machine, n_max = borne du gabarit (machines),
---       existing = { { id, n, state } } modules de la même recette suivis par l'automatisation }.
--- Rend { action = "agrandir" | "nouveau" | "refus", n, k, target, from, near, why }.
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
    if Ra.GROWABLE[e.state] and n0 >= 1 and n0 < n_max then
      return { action = "agrandir", target = e.id, from = n0, n = math.min(n_max, n0 + k), k = k,
        why = "rangee de la meme recette en attente" }
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
    why = near and "rangees existantes deja posees ou pleines : nouvelle rangee a cote" or "aucune rangee de cette recette" }
end

--- Ligne de journal d'une décision : [FO-RANGEES-ASM].
function Ra.line(who, item, rate, d)
  return string.format("[FO-RANGEES-ASM] %s : %s %.0f/min -> %s%s%s%s (%s)", tostring(who), tostring(item), rate or 0,
    tostring(d.action),
    d.target and (" module " .. tostring(d.target) .. " de " .. tostring(d.from)) or "",
    d.n and (" a " .. tostring(d.n) .. " machine(s), besoin " .. tostring(d.k)) or "",
    d.near and (" pres du module " .. tostring(d.near)) or "",
    tostring(d.why))
end

return Ra
