--[[
  Lot ACIER (directive du DC, 8/11, 17 h 20) : REGLE PURE (aucune API Factorio, aucun nom d'objet écrit : l'acier est le produit de fonte
  dont l'ENTREE est elle-même un produit de fonte, lu dans T.smelter_inputs).
  Lot COLONNES (chantier 6 du DC, 11/11) : la même règle sert CHAQUE produit d'une colonne dédiée (Ac.items) : tout produit de fonte dont
  l'entrée n'est pas le minerai d'un avant-poste à four (la colonne du champ le fond sur place) : l'acier (entrée : une plaque) et les
  briques (entrée : un minerai que l'avant-poste met en coffre). Chaque produit a son bloc, sa demande et sa transition.

  Constat : l'acier se faisait par les tournées « smelt » des PNJ (fours du QG chargés à la main de plaques) ; sans PNJ libre pour le trajet,
  la production tombait à zéro. Solution : un bloc « fonderie d'acier » = une rangée DYNAMIQUE de fours (gabarit G.simple avec un four,
  shared/team/modules.lua) dont l'entrée est le tapis de plaques de fer (quai, puis liaison ou piquage) et la sortie un tapis vers un
  coffre tampon ; elle est demandée comme une rangée d'assembleurs (shared/ai3/rangees_asm.lua : agrandie sur place, place entière réservée).

  1. DEMANDE (Ac.seen, Ac.need, Ac.ask) : l'acier est demandé à la main (plan.smelt) pendant Ac.CONFIRM pensées de suite ; le débit voulu est
     le plus grand de la consommation mesurée par minute et du manque divisé par Ac.HORIZON minutes (au moins Ac.MIN_RATE) ; une rangée est
     demandée ou agrandie quand ce besoin dépasse Ac.GROW_AT fois la capacité posée ou en chantier, du besoin plus Ac.MARGIN moins cette capacité.
  2. TRANSITION (Ac.decide_cut), modèle D09 (shared/team/intermediaires.lua) : quand une fonderie d'acier FINIE produit (débit mesuré au
     fours de la rangée) au moins ce que l'équipe demande (max(Ac.FLOOR, besoin × Ac.COVER)), plus aucune tâche « smelt » d'acier n'est
     émise ; HYSTERESIS : reprise quand de l'acier manque encore ET que le débit tombe sous Ac.OFF fois ce seuil, après Ac.HOLD ticks au moins.
     Mode survie : jamais coupé (la main reste ouverte).
  Déterminisme : aucune table parcourue par `pairs`, aucun temps mesuré (ticks de jeu, débits par minute de jeu).
]]

local T = require("shared.team.config")
local M = require("shared.team.modules")

local Ac = {}

Ac.CONFIRM = 2          -- pensées de suite avec de l'acier demandé à la main avant de demander un bloc
Ac.HORIZON = 10         -- minutes : le manque d'acier se rattrape sur cette durée
Ac.MIN_RATE = 4         -- acier par minute demandé au moins quand il manque (un four de rang 1 en fait 3,75)
Ac.MARGIN = 0.25        -- débit de plus demandé que le besoin (le bloc ne doit pas être juste)
Ac.GROW_AT = 0.9        -- agrandir quand le besoin dépasse 90 % de la capacité posée ou en chantier
Ac.FLOOR = 2            -- débit mesuré (par minute) sous lequel on ne coupe jamais la main
Ac.COVER = 1.0          -- le bloc doit produire au moins ce que l'équipe demande
Ac.OFF = 0.5            -- reprise sous la moitié du seuil
Ac.HOLD = 3 * 3600      -- ticks : une décision de coupure ne s'inverse pas avant (bruit de la mesure à la minute)
Ac.RETRY = 3 * 3600     -- ticks : après un refus, on ne redemande pas avant

--- Produits des colonnes dédiées, triés : chaque produit de `inputs` (produit -> { entrée, quantité }) dont l'entrée n'est pas la ressource
--- d'un avant-poste de `outposts` dont le récepteur est un four (is_furnace(nom)). Défaut : T.smelter_inputs, T.outposts, M.BASE.
function Ac.items(inputs, outposts, is_furnace)
  inputs, outposts = inputs or T.smelter_inputs, outposts or T.outposts
  is_furnace = is_furnace or function(n) return (M.BASE[n] or {}).kind == "furnace" end
  local fielded, ks, out = {}, {}, {}
  for k in pairs(outposts) do ks[#ks + 1] = k end
  for _, k in ipairs(ks) do if is_furnace(outposts[k].sink) then fielded[outposts[k].resource] = true end end
  ks = {}
  for k in pairs(inputs) do ks[#ks + 1] = k end
  table.sort(ks)
  for _, k in ipairs(ks) do if inputs[k] and not fielded[inputs[k][1]] then out[#out + 1] = k end end
  return out
end
Ac.ITEMS = Ac.items()

local function num(x)
  if type(x) ~= "number" or x ~= x then return 0 end
  return x
end

--- Compteur de pensées de suite avec de l'acier demandé à la main (fuite lente : une pensée sans demande retire 1, jamais sous 0).
function Ac.seen(count, short)
  count = num(count)
  if num(short) > 0 then return math.min(count + 1, Ac.CONFIRM + 4) end
  return math.max(0, count - 1)
end

--- Débit d'acier voulu (par minute) : a = { cons = consommation mesurée par minute, short = manque d'acier demandé à la main }.
function Ac.need(a)
  local cons = math.max(0, num(a.cons))
  local short = math.max(0, num(a.short))
  local n = math.max(cons, short / Ac.HORIZON)
  if short > 0 then n = math.max(n, Ac.MIN_RATE) end
  return n
end

--- Faut-il demander ou agrandir un bloc, et de combien ? a = { count (Ac.seen), need (Ac.need), cap = capacité posée ou en chantier
--- (par minute), tick, retry_at (tick avant lequel on ne redemande pas) }. Rend (débit à demander, ou 0), raison.
function Ac.ask(a)
  if num(a.count) < Ac.CONFIRM then return 0, "demande non confirmee" end
  local need, cap = num(a.need), math.max(0, num(a.cap))
  if need <= 0 then return 0, "aucun besoin" end
  if need <= cap * Ac.GROW_AT then return 0, "capacite suffisante" end
  if num(a.tick) < num(a.retry_at) then return 0, "refus recent" end
  local rate = need * (1 + Ac.MARGIN) - cap
  if rate <= 0 then return 0, "capacite suffisante" end
  return rate, cap > 0 and "capacite insuffisante" or "aucun bloc"
end

--- Seuil de débit du bloc (par minute) au-dessus duquel la main est inutile.
function Ac.threshold(need)
  return math.max(Ac.FLOOR, num(need) * Ac.COVER)
end

--- La tâche manuelle d'acier doit-elle rester COUPEE ? prev = { cut = bool, since = tick } ou nil ; a = { finished = nombre de blocs finis,
--- flow = acier produit par minute par les blocs finis (mesuré), need = Ac.need, short = manque d'acier demandé à la main, survie,
--- tick }. Rend (coupé, raison).
function Ac.decide_cut(prev, a)
  if a.survie then return false, "mode survie" end
  if num(a.finished) < 1 then return false, "aucun bloc fini" end
  local th = Ac.threshold(a.need)
  local flow = math.max(0, num(a.flow))
  local was = prev and prev.cut == true
  if was then
    if num(a.tick) - num(prev.since) < Ac.HOLD then return true, "tenue" end
    if num(a.short) > 0 and flow < th * Ac.OFF then return false, "debit sous le seuil de reprise" end
    return true, "debit suffisant"
  end
  if prev and prev.since and num(a.tick) - num(prev.since) < Ac.HOLD then return false, "tenue" end
  if flow >= th then return true, "debit mesure suffisant" end
  return false, "debit mesure sous le seuil"
end

--- Ligne de journal [FO-ACIER] (une par changement), avec le produit de la colonne.
function Ac.line(who, text, minutes, item)
  return string.format("[FO-ACIER] %s : %s%s a %.1f min", tostring(who), item and ("colonne " .. item .. " : ") or "", tostring(text), minutes or 0)
end

return Ac
