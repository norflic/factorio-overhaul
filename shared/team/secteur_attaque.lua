--[[ Lot s44 reparation : « secteur sous attaque, sans couverture » (règle pure).

  Constat (partie du DC 0.7.102, minute 72) : la centrale du joueur tombe sous les fusiliers d'Azur ; 30 s après, le relevé rouvre
  12 pièces et le registre repose les poteaux (53 s après leur mort). La seule garde était « aucune unité ennemie à 28 tuiles AU
  MOMENT du départ » : les assaillants qui reviennent par vagues (ou tirent de plus loin) tuent l'ouvrier sur place, en boucle.

  Règle : une pièce à refaire attend (elle n'est PAS abandonnée) tant que son secteur est SOUS ATTAQUE (une pièce de l'équipe y est
  morte à moins de Sa.R tuiles depuis moins de Sa.T ticks) ET SANS COUVERTURE (aucune tourelle active — munie, alimentée ou pleine —
  dont la portée atteint la place). Reprise dès qu'une tourelle couvre ou que la mémoire de l'attaque s'éteint.
  Les tourelles elles-mêmes (types du moteur) ne sont jamais retenues : les reposer, c'est rétablir la couverture.

  Mémoire : `mem.hits` = liste { x, y, t } bornée à Sa.MAX (la plus ancienne sort), dans l'ordre d'arrivée. Aucun `pairs`, aucun hasard.
]]

local Sa = {}

Sa.R = 32          -- tuiles : rayon du secteur autour d'une mort récente
Sa.T = 60 * 60     -- 1 min : durée de la mémoire d'une mort (la vague est finie si plus rien ne meurt)
Sa.MAX = 64        -- morts gardées au plus

-- Types du moteur des tourelles : jamais différées (elles rétablissent la couverture).
Sa.TURRET_TYPES = { ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, turret = true }

function Sa.new() return { hits = {} } end

--- Note une mort de pièce en (x, y) au tick `tick`.
function Sa.note(mem, x, y, tick)
  local h = mem.hits
  h[#h + 1] = { x = x, y = y, t = tick }
  while #h > Sa.MAX do table.remove(h, 1) end
end

--- Oublie les morts plus vieilles que Sa.T.
function Sa.prune(mem, tick)
  local h, keep = mem.hits, {}
  for i = 1, #h do
    if tick - h[i].t < Sa.T then keep[#keep + 1] = h[i] end
  end
  mem.hits = keep
end

--- Vrai si une mort récente (moins de Sa.T) est à moins de Sa.R tuiles de (x, y).
function Sa.under_attack(mem, x, y, tick)
  if not mem then return false end
  local h, r2 = mem.hits, Sa.R * Sa.R
  for i = #h, 1, -1 do
    local m = h[i]
    if tick - m.t < Sa.T then
      local dx, dy = m.x - x, m.y - y
      if dx * dx + dy * dy <= r2 then return true end
    end
  end
  return false
end

--- Tourelle active ? `kind` = type du moteur ; `ammo` = munitions au chargeur ; `energy` = énergie tampon ; `fluid` = fluide présent.
function Sa.turret_active(kind, ammo, energy, fluid)
  if kind == "ammo-turret" then return (ammo or 0) > 0 end
  if kind == "electric-turret" then return (energy or 0) > 0 end
  if kind == "fluid-turret" then return (fluid or 0) > 0 end
  return false
end

--- Couverture : `turrets` = { { x, y, range, active } } ; vrai si une tourelle active atteint (x, y).
function Sa.covered(turrets, x, y)
  for i = 1, #(turrets or {}) do
    local t = turrets[i]
    if t.active then
      local dx, dy, r = t.x - x, t.y - y, t.range or 0
      if dx * dx + dy * dy <= r * r then return true end
    end
  end
  return false
end

--- Décision : la pièce de type `ty` en (x, y) doit-elle attendre ? `cover_fn()` n'est appelé que si le secteur est sous attaque.
function Sa.must_wait(mem, ty, x, y, tick, cover_fn)
  if ty and Sa.TURRET_TYPES[ty] then return false end
  if not Sa.under_attack(mem, x, y, tick) then return false end
  return not cover_fn()
end

return Sa
