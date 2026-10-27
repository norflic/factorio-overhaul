--[[
  Tirs des tourelles par âge (lot TIRS) : RÈGLES PURES (Lua pur, testées hors jeu par tests/tirs_test.lua).
    R.garder(compteur, part)     accumulateur entier : garde a événements sur b, sans ordre ni hasard
    R.plafond(etat, tick, max)   plafond de tirs habillés par tick (unités de travail, jamais un temps)
    R.verifier_effets(trigger, permis_noms)  un Trigger ne contient QUE des effets visuels ou sonores
    R.verifier_prototype(p, permis_noms)     un prototype du lot (explosion, projectile, faisceau) est sans jeu
    R.verifier_ages(T)           la table shared/tirs/ages.lua est bien formée
    R.couleur(c)                 { r, g, b[, a] } -> table de couleur du moteur
]]

local R = {}

--- Accumulateur de Bresenham : rend (garde ?, nouveau compteur). part = { a, b }, 0 < a <= b.
function R.garder(compteur, part)
  local c = (compteur or 0) + part[1]
  if c >= part[2] then return true, c - part[2] end
  return false, c
end

--- Plafond par tick : etat = { tick, n } (modifié) ; rend vrai si le tir peut encore être habillé ce tick.
function R.plafond(etat, tick, max)
  if etat.tick ~= tick then etat.tick, etat.n = tick, 0 end
  if etat.n >= max then return false end
  etat.n = etat.n + 1
  return true
end

-- Effets permis dans les actions des prototypes du lot : aucun ne touche au jeu (dégâts, entité de jeu, recul,
-- collant, feu, tuile, script, objet, falaise…).
local PERMIS = { ["create-explosion"] = true, ["create-particle"] = true, ["create-trivial-smoke"] = true,
  ["play-sound"] = true }

local function liste(t)
  if t == nil then return {} end
  if t.type ~= nil then return { t } end
  return t
end

--- Contrôle un Trigger (TriggerItem ou liste) : rend nil si permis, sinon un motif. permis_noms : ensemble des
--- noms d'explosions et de particules acceptés (ceux du lot et ceux de la vanilla qu'il cite).
function R.verifier_effets(trigger, permis_noms, ou)
  ou = ou or "action"
  for i, item in ipairs(liste(trigger)) do
    if item.type ~= "direct" then
      return ou .. "[" .. i .. "] : type « " .. tostring(item.type) .. " » (seul « direct » est permis)"
    end
    for j, d in ipairs(liste(item.action_delivery)) do
      if d.type ~= "instant" then
        return ou .. "[" .. i .. "].action_delivery[" .. j .. "] : livraison « " .. tostring(d.type) .. " »"
      end
      for _, champ in ipairs({ "source_effects", "target_effects" }) do
        for k, eff in ipairs(liste(d[champ])) do
          local lieu = ou .. "[" .. i .. "]." .. champ .. "[" .. k .. "]"
          if not PERMIS[eff.type] then return lieu .. " : effet « " .. tostring(eff.type) .. " » interdit" end
          local nom = eff.entity_name or eff.particle_name or eff.smoke_name
          if nom ~= nil and not permis_noms[nom] then return lieu .. " : nom « " .. tostring(nom) .. " » hors liste" end
        end
      end
    end
  end
  return nil
end

--- Contrôle un prototype du lot : rend nil si sans jeu, sinon un motif.
function R.verifier_prototype(p, permis_noms)
  local ou = tostring(p.type) .. "/" .. tostring(p.name)
  if p.type == "beam" then
    if p.action ~= nil then return ou .. " : un trait ne porte aucune action" end
  elseif p.type == "projectile" then
    if p.final_action ~= nil then return ou .. " : final_action interdite" end
    if p.piercing_damage ~= nil then return ou .. " : piercing_damage interdit" end
    if p.collision_box ~= nil then return ou .. " : collision_box interdite (la traçante ne touche rien)" end
    local m = R.verifier_effets(p.action, permis_noms, ou .. ".action")
    if m then return m end
  elseif p.type == "explosion" then
    local m = R.verifier_effets(p.created_effect, permis_noms, ou .. ".created_effect")
    if m then return m end
  elseif p.type == "optimized-particle" then
    for _, k in ipairs({ "ended_on_ground_trigger_effect", "regular_trigger_effect", "ended_in_water_trigger_effect" }) do
      if p[k] ~= nil and p[k] ~= false then return ou .. " : " .. k .. " interdit" end
    end
  elseif p.type ~= "trivial-smoke" then
    return ou .. " : type non permis au lot"
  end
  return nil
end

local function couleur_ok(c)
  if type(c) ~= "table" or #c < 3 or #c > 4 then return false end
  for i = 1, #c do if type(c[i]) ~= "number" or c[i] < 0 or c[i] > 1 then return false end end
  return true
end

--- Contrôle la table des âges : rend la liste des motifs (vide si bien formée).
function R.verifier_ages(T)
  local out = {}
  local function non(m) out[#out + 1] = m end
  if type(T.probabilite) ~= "number" or T.probabilite <= 0 or T.probabilite > 1 then non("probabilite hors ]0, 1]") end
  if type(T.plafond_tick) ~= "number" or T.plafond_tick < 1 then non("plafond_tick < 1") end
  local vus = {}
  for _, e in ipairs(T.temoins) do
    vus[e] = true
    local A = T.ages[e]
    local w = "age " .. tostring(e)
    if not A then non(w .. " : absent de ages") else
      local p = A.part
      if type(p) ~= "table" or type(p[1]) ~= "number" or type(p[2]) ~= "number" or p[1] < 1 or p[1] > p[2]
          or p[1] % 1 ~= 0 or p[2] % 1 ~= 0 then
        non(w .. " : part = { a, b } entiers, 1 <= a <= b")
      end
      if type(A.quota) ~= "number" or A.quota < 1 or A.quota % 1 ~= 0 then non(w .. " : quota entier >= 1") end
      if not A.bouche or #A.bouche == 0 then non(w .. " : bouche vide") end
      if not A.impact or #A.impact == 0 then non(w .. " : impact vide") end
      for _, champ in ipairs({ "bouche", "impact" }) do
        for i, x in ipairs(A[champ] or {}) do
          local wi = w .. "." .. champ .. "[" .. i .. "]"
          if (x.source == nil) == (x.image == nil) then non(wi .. " : source OU image") end
          if x.image ~= nil and not T.IMAGES[x.image] then non(wi .. " : image inconnue " .. tostring(x.image)) end
          if type(x.echelle) ~= "number" or x.echelle <= 0 then non(wi .. " : echelle") end
          if not couleur_ok(x.teinte) then non(wi .. " : teinte") end
          if x.duree ~= nil and (type(x.duree) ~= "number" or x.duree < 1) then non(wi .. " : duree") end
          if x.lumiere and not couleur_ok(x.lumiere.couleur) then non(wi .. " : couleur de lumiere") end
          if x.fumee and not couleur_ok(x.fumee.couleur) then non(wi .. " : couleur de fumee") end
          if x.etincelles and (type(x.etincelles.nombre) ~= "number" or x.etincelles.nombre < 1) then
            non(wi .. " : nombre d'etincelles")
          end
        end
      end
      if A.trace then
        if type(A.trace.vitesse) ~= "number" or A.trace.vitesse < 1 then
          non(w .. " : vitesse de la traçante >= 1 tuile/tick (arrivée en moins de 30 ticks)")
        end
        if not T.IMAGES[A.trace.image] then non(w .. " : image de la traçante inconnue") end
      end
      if A.trait and (type(A.trait.duree) ~= "number" or A.trait.duree < 1 or A.trait.duree > 30) then
        non(w .. " : duree du trait de 1 à 30 ticks")
      end
      for i, c in ipairs((A.son and A.son.couches) or {}) do
        local f = c.fichiers
        if type(f) ~= "table" or type(f[1]) ~= "string" or not f[1]:find("%d", 1, true) or f[3] < f[2] then
          non(w .. ".son[" .. i .. "] : fichiers = { motif %d, premier, dernier }")
        end
        if type(c.volume) ~= "number" or c.volume <= 0 or c.volume > 1 then non(w .. ".son[" .. i .. "] : volume") end
        if type(c.max) ~= "number" or c.max < 1 then non(w .. ".son[" .. i .. "] : max >= 1 (aggregation)") end
      end
    end
  end
  -- toute entrée de ages est un témoin (pas d'âge oublié de la liste ordonnée)
  for e = 1, 15 do
    if T.ages[e] and not vus[e] then non("age " .. e .. " absent de temoins") end
  end
  return out
end

function R.couleur(c)
  return { r = c[1], g = c[2], b = c[3], a = c[4] or 1 }
end

--- Fichiers d'une couche de son : motif « …%d… », premier, dernier.
function R.fichiers(f)
  local out = {}
  for i = f[2], f[3] do out[#out + 1] = string.format(f[1], i) end
  return out
end

--- Noms des prototypes du lot pour un âge (deux chiffres : fo-tir-05-bouche-1).
function R.nom(T, age, quoi, i)
  local n = T.PREFIXE .. string.format("%02d", age) .. "-" .. quoi
  if i then n = n .. "-" .. i end
  return n
end

return R
