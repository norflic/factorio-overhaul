--[[
  Tirs des tourelles par âge (lot TIRS) : RÈGLES PURES (Lua pur, testées hors jeu par tests/tirs_test.lua).
    R.garder(compteur, part)     accumulateur entier : garde a événements sur b, sans ordre ni hasard
    R.plafond(etat, tick, max)   plafond de tirs habillés par tick (unités de travail, jamais un temps)
    R.proche(joueurs, s, x, y, d) la tourelle est-elle à moins de d tuiles (Tchebychev) d'un joueur connecté ?
    R.decider(etat, age, tick, A, T, proche)  décision d'habillage d'un événement : "garde" ou le motif du refus
    R.verifier_effets(trigger, permis_noms)  un Trigger ne contient QUE des effets visuels ou sonores
    R.verifier_prototype(p, permis_noms)     un prototype du lot (explosion, projectile, faisceau…) est sans jeu
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

--- Proximité : joueurs = liste { s = indice de surface, x, y } des joueurs CONNECTÉS (relevé périodique, dans
--- l'ordre des indices) ou nil (pas encore relevé). Liste nil ou vide (aucun joueur connecté : bancs sans images) :
--- vrai (pas de filtre). Sinon vrai si un joueur de la même surface est à d tuiles au plus en x ET en y.
function R.proche(joueurs, s, x, y, d)
  if joueurs == nil or #joueurs == 0 then return true end
  for i = 1, #joueurs do
    local j = joueurs[i]
    if j.s == s and j.x - d <= x and x <= j.x + d and j.y - d <= y and y <= j.y + d then return true end
  end
  return false
end

--- Décision d'habillage d'un événement de l'âge `age` au tick `tick` (pure ; modifie etat).
--- etat = { cpt = {}, quota = {}, plafond = { tick, n } } ; A = T.ages[age] ; proche = R.proche(...).
--- Ordre : (1) proximité AVANT l'accumulateur (une tourelle hors de vue n'avance pas la part de son âge) ;
--- (2) part de l'âge ; (3) quota de l'âge ce tick ; (4) plafond commun ce tick. Rend "garde", "loin", "part",
--- "quota" ou "plafond". Avec T.plafond_tick >= somme des quotas des âges (R.verifier_ages), (4) ne refuse jamais un
--- tir qu'a laissé passer (3) : chaque âge reçoit son quota quel que soit l'ordre de mise à jour des tourelles.
function R.decider(etat, age, tick, A, T, proche)
  if not proche then return "loin" end
  local g, c = R.garder(etat.cpt[age], A.part)
  etat.cpt[age] = c
  if not g then return "part" end
  local q = etat.quota[age]
  if not q then
    q = { tick = -1, n = 0 }
    etat.quota[age] = q
  end
  if q.tick == tick and q.n >= A.quota then return "quota" end
  if not R.plafond(etat.plafond, tick, T.plafond_tick) then return "plafond" end
  R.plafond(q, tick, A.quota)
  return "garde"
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
  elseif p.type ~= "trivial-smoke" and p.type ~= "animation" then
    return ou .. " : type non permis au lot"
  end
  return nil
end

local function couleur_ok(c)
  if type(c) ~= "table" or #c < 3 or #c > 4 then return false end
  for i = 1, #c do if type(c[i]) ~= "number" or c[i] < 0 or c[i] > 1 then return false end end
  return true
end

local function ecart_couleur(a, b)
  local m = 0
  for i = 1, 3 do m = math.max(m, math.abs(a[i] - b[i])) end
  return m
end

local function nombre(x, min, max)
  return type(x) == "number" and x >= min and (max == nil or x <= max)
end

--- Contrôle la table des âges : rend la liste des motifs (vide si bien formée).
function R.verifier_ages(T)
  local out = {}
  local function non(m) out[#out + 1] = m end
  if not nombre(T.probabilite, 1e-9, 1) then non("probabilite hors ]0, 1]") end
  if not nombre(T.plafond_tick, 1) then non("plafond_tick < 1") end
  if not nombre(T.proximite, 1) then non("proximite < 1 tuile") end
  if not nombre(T.releve, 1) or T.releve % 1 ~= 0 then non("releve : entier >= 1 tick") end
  local vus, somme_quotas = {}, 0
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
      if type(A.quota) ~= "number" or A.quota < 1 or A.quota % 1 ~= 0 then non(w .. " : quota entier >= 1")
      else somme_quotas = somme_quotas + A.quota end
      if not A.bouche or #A.bouche == 0 then non(w .. " : bouche vide") end
      if not A.impact or #A.impact == 0 then non(w .. " : impact vide") end
      if not A.trace then non(w .. " : trace absente (le premier dard crée l'impact)") end
      for i, b in ipairs(A.bouche or {}) do
        local wi = w .. ".bouche[" .. i .. "]"
        local an = T.ANIMS[b.anim]
        if not an then non(wi .. " : anim inconnue " .. tostring(b.anim)) else
          if an.variations and not an.variations[b.variation or 0] then non(wi .. " : variation inconnue") end
          -- image basse définition : pas plus de ×2 dans l'axe ni ×1,5 en largeur (tache floue au-delà, ronde 3)
          if not an.hr and (not nombre(b.longueur, 0.1, 2.0) or not nombre(b.largeur, 0.1, 1.5)) then
            non(wi .. " : image basse definition agrandie au-dela de x2 (axe) ou x1,5 (largeur)")
          end
        end
        if not nombre(b.largeur, 0.01) or not nombre(b.longueur, 0.01) then non(wi .. " : largeur, longueur") end
        if not couleur_ok(b.teinte) then non(wi .. " : teinte") end
        if not nombre(b.duree, 1, 30) then non(wi .. " : duree de 1 a 30 ticks") end
      end
      if A.lumiere and (not couleur_ok(A.lumiere.couleur) or not nombre(A.lumiere.taille, 0.1, 40)
          or not nombre(A.lumiere.intensite, 0, 1) or not nombre(A.lumiere.duree, 1, 60)) then
        non(w .. " : lumiere de bouche (couleur, taille, intensite, duree)")
      end
      if A.fumee and (not couleur_ok(A.fumee.couleur) or not nombre(A.fumee.nombre, 1, 8)) then
        non(w .. " : fumee de bouche (couleur, nombre de 1 a 8)")
      end
      for i, x in ipairs(A.impact or {}) do
        local wi = w .. ".impact[" .. i .. "]"
        if (x.source == nil) == (x.image == nil) then non(wi .. " : source OU image") end
        if x.image ~= nil and not T.IMAGES[x.image] then non(wi .. " : image inconnue " .. tostring(x.image)) end
        if x.tourne ~= nil then non(wi .. " : tourne interdit (texture couchee vue verticale, ronde 3)") end
        if not nombre(x.echelle, 1e-9) then non(wi .. " : echelle") end
        if not couleur_ok(x.teinte) then non(wi .. " : teinte") end
        if x.duree ~= nil and not nombre(x.duree, 1) then non(wi .. " : duree") end
        if x.frames ~= nil and (not nombre(x.frames, 1, 100) or x.frames % 1 ~= 0) then non(wi .. " : frames entier de 1 a 100") end
        if x.enfle and (not nombre(x.enfle.depart, 0.05, 1) or not nombre(x.enfle.ticks, 1, 60)) then
          non(wi .. " : enfle { depart dans ]0, 1], ticks }")
        end
        if x.lumiere and not couleur_ok(x.lumiere.couleur) then non(wi .. " : couleur de lumiere") end
        if x.fumee and not couleur_ok(x.fumee.couleur) then non(wi .. " : couleur de fumee") end
        if x.etincelles and not nombre(x.etincelles.nombre, 1, 40) then non(wi .. " : nombre d'etincelles") end
      end
      local t = A.trace
      if t then
        if not nombre(t.vitesse, 1) then non(w .. " : vitesse de la traçante >= 1 tuile/tick (arrivée en moins de 30 ticks)") end
        if not T.IMAGES[t.image] then non(w .. " : image de la traçante inconnue") end
        if t.nombre ~= nil and not nombre(t.nombre, 1, 4) then non(w .. " : nombre de dards de 1 a 4") end
        if (t.nombre or 1) > 1 and not nombre(t.ralenti, 0.5, 0.95) then non(w .. " : ralenti des dards dans [0,5 ; 0,95]") end
        -- le dernier dard reste au-dessus de 1 tuile par tick
        if (t.nombre or 1) > 1 and nombre(t.vitesse, 1) and nombre(t.ralenti, 0.5, 0.95)
            and t.vitesse * t.ralenti ^ (t.nombre - 1) < 1 then
          non(w .. " : dernier dard sous 1 tuile/tick")
        end
      end
      local tr = A.trait
      if tr then
        -- un trait de mitrailleuse reste un claquement bref et fin (le faisceau continu est celui du laser)
        if not nombre(tr.duree, 1, 2) then non(w .. " : duree du trait de 1 a 2 ticks") end
        if not nombre(tr.epaisseur, 0.1, 1.0) then non(w .. " : epaisseur du trait <= 1") end
        if not couleur_ok(tr.teinte) or not couleur_ok(tr.coeur) then non(w .. " : teintes du trait") end
        local L = A.laser
        if L and couleur_ok(tr.teinte) and couleur_ok(L.teinte)
            and (math.abs(tr.epaisseur - L.epaisseur) < 0.3 or ecart_couleur(tr.teinte, L.teinte) < 0.15) then
          non(w .. " : trait de la mitrailleuse trop proche du faisceau du laser du meme age (epaisseur, teinte)")
        end
      end
      for i, c in ipairs((A.son and A.son.couches) or {}) do
        local f = c.fichiers
        if type(f) ~= "table" or type(f[1]) ~= "string" or not f[1]:find("%d", 1, true) or f[3] < f[2] then
          non(w .. ".son[" .. i .. "] : fichiers = { motif %d, premier, dernier }")
        end
        if not nombre(c.volume, 1e-9, 1) then non(w .. ".son[" .. i .. "] : volume") end
        if not nombre(c.max, 1) then non(w .. ".son[" .. i .. "] : max >= 1 (aggregation)") end
        if c.vitesse ~= nil and (type(c.vitesse) ~= "table" or not nombre(c.vitesse[1], 1 / 64)
            or not nombre(c.vitesse[2], c.vitesse[1])) then
          non(w .. ".son[" .. i .. "] : vitesse = { min >= 1/64, max >= min }")
        end
      end
    end
  end
  if nombre(T.plafond_tick, 1) and T.plafond_tick < somme_quotas then
    non("plafond_tick (" .. T.plafond_tick .. ") < somme des quotas (" .. somme_quotas .. ") : l'ordre de mise a jour "
      .. "decide quel age est habille")
  end
  if T.sans_effet ~= nil and (T.ages[T.sans_effet] or vus[T.sans_effet]) then non("sans_effet : un age sans entree") end
  -- toute entrée de ages est un témoin (pas d'âge oublié de la liste ordonnée)
  for e = 1, 30 do
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

--- Décalage d'animation pour qu'un rendering.draw_animation créé au tick `tick` montre l'image 0 à ce tick :
--- image = floor(tick × vitesse + decalage) mod n.
function R.decalage(tick, vitesse, n)
  return (-(tick * vitesse)) % n
end

return R
