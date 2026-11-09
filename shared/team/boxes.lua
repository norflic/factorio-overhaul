--[[
  Lot BOXES (directive du DC du 9/11) : la base est un ensemble de BOXES (gisement, fonderie, mall, energie) avec un cycle de vie.
  Règles PURES (aucun moteur, aucun `game`) ; le relevé des mesures est dans script/team/boxes_rt.lua.

  Statuts :
    MAXED            : tout ce qui est prévu est bâti ET alimenté (planned > 0, built == planned, powered == built), rien d'épuisé,
                       aucun déblocage technologique applicable depuis le dernier MAXED. Règle d'or : une box MAXED est IGNORÉE par les
                       scans réguliers (Bx.skip) ; elle ne repasse en cycle que par Bx.wake (épuisement physique ou déblocage applicable).
    VIDE             : épuisement physique (gisement sans minerai sous les foreuses) ; prime sur tout le reste.
    UPGRADE_REQUISE  : la box était MAXED (ou déjà en UPGRADE_REQUISE) et un déblocage applicable est arrivé : un scan doit la revoir.
    EN_COURS         : tout le reste (le `else` garanti : il n'existe pas de cinquième réponse).
  Un déblocage « applicable » = une recette activée de plus dont un produit pose une entité du TYPE de machine de la box
  (Bx.TYPES : types de prototypes, jamais un nom d'objet du jeu) ; le moteur compte, la règle compare (Bx.tech_new).

  Déterminisme : aucun `pairs`, aucun temps mesuré ; mêmes entrées, même sortie.
]]

local Bx = {}

Bx.MAXED, Bx.EN_COURS, Bx.UPGRADE_REQUISE, Bx.VIDE = "MAXED", "EN_COURS", "UPGRADE_REQUISE", "VIDE"
Bx.KINDS = { "gisement", "fonderie", "energie", "mall" } -- ordre du journal
Bx.UNKNOWN = -1 -- `planned` inconnu (gisement sans cadre) : jamais MAXED

--- Types de prototypes des machines de chaque sorte de box (un déblocage est applicable s'il pose une entité d'un de ces types).
Bx.TYPES = {
  gisement = { "mining-drill" },
  fonderie = { "furnace" },
  mall = { "assembling-machine" },
  energie = { "generator", "boiler", "solar-panel", "reactor" }, -- (ce qui PRODUIT ; un stockage n'ouvre pas de mise à niveau)
}

--- Statut d'une box depuis ses mesures b = { planned, built, powered, exhausted, tech_new, last }.
function Bx.status(b)
  if b.exhausted then return Bx.VIDE end
  if b.tech_new and (b.last == Bx.MAXED or b.last == Bx.UPGRADE_REQUISE) then return Bx.UPGRADE_REQUISE end
  local planned, built, powered = b.planned or 0, b.built or 0, b.powered or 0
  if planned > 0 and built == planned and powered == built and not b.tech_new then return Bx.MAXED end
  return Bx.EN_COURS
end

--- Les scans réguliers ignorent-ils cette box ? (vrai pour MAXED seulement)
function Bx.skip(status)
  return status == Bx.MAXED
end

--- Réveil d'une box ignorée : ev = { exhausted, tech_new } -> nouveau statut (inchangé sans événement).
function Bx.wake(last, ev)
  if ev.exhausted then return Bx.VIDE end
  if ev.tech_new and (last == Bx.MAXED or last == Bx.UPGRADE_REQUISE) then return Bx.UPGRADE_REQUISE end
  return last
end

--- Déblocage applicable : le compte de recettes activées posant le type de machine de la box a grandi depuis le compte figé au MAXED.
function Bx.tech_new(count_now, count_at_maxed)
  if count_at_maxed == nil then return false end
  return (count_now or 0) > count_at_maxed
end

--- Compte des recettes applicables à une sorte : `by_type` = { [type d'entité] = nombre de recettes activées qui en posent une }.
function Bx.count_for(kind, by_type)
  local n = 0
  for _, t in ipairs(Bx.TYPES[kind] or {}) do n = n + (by_type[t] or 0) end
  return n
end

--- La position (x, y) tombe-t-elle dans la boîte { x0, y0, x1, y1 } (bornes comprises) ?
function Bx.inside(box, x, y)
  return x >= box.x0 and x <= box.x1 and y >= box.y0 and y <= box.y1
end

--- Une box MAXED de la liste contient-elle (x, y) ? (lu par l'audit d'hygiène : ce poteau est sauté)
function Bx.maxed_at(list, x, y)
  for _, b in ipairs(list or {}) do
    if Bx.skip(b.status) and Bx.inside(b, x, y) then return true end
  end
  return false
end

--- Comptes par sorte : { [kind] = { n, maxed } } dans l'ordre de Bx.KINDS, et le nombre de réveils (MAXED -> autre chose).
function Bx.summary(list, prev_status)
  local c = {}
  for _, k in ipairs(Bx.KINDS) do c[k] = { n = 0, maxed = 0 } end
  local wakes = 0
  for _, b in ipairs(list or {}) do
    local k = c[b.kind]
    if k then
      k.n = k.n + 1
      if b.status == Bx.MAXED then k.maxed = k.maxed + 1 end
    end
    if prev_status and prev_status[b.kind .. ":" .. tostring(b.id)] == Bx.MAXED and b.status ~= Bx.MAXED then wakes = wakes + 1 end
  end
  return c, wakes
end

--- Ligne de journal [FO-BOX] d'une impulsion.
function Bx.line(key, tick, c, wakes)
  return string.format("[FO-BOX] %s : impulsion a %.1f min : %d gisements (%d MAXED), %d fonderies (%d MAXED), %d energie (%d MAXED), %d mall (%d MAXED) ; reveils : %d",
    tostring(key), tick / 3600, c.gisement.n, c.gisement.maxed, c.fonderie.n, c.fonderie.maxed, c.energie.n, c.energie.maxed, c.mall.n, c.mall.maxed, wakes)
end

return Bx
