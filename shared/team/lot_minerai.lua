--[[
  Lot L9 de la feuille de route « Factorio Automated » (docs/VIDEO_AUTOMATISATION.md §6 L9 ; docs/TODO_VIDEO.md V45, V46, V47, G37, G42,
  G43, G57) : SONDER AVANT DE DÉCIDER, MINERAI D'ABORD. Règle PURE (aucune API Factorio, aucun nom d'objet : les ressources et leurs seuils
  viennent de l'appelant, lus en données). Testée hors jeu : tests/lot_minerai_test.lua. BRANCHÉE EN PARTIE : Lm.states_for et Lm.allows, via
  script/team/lots_minerai_glue.lua (:53 et :62) ; Lm.ores, Lm.role, Lm.reserve et Lm.needs_survey ne sont appelées par aucun script.

  La source : « If the resource scanner […] detects a large amount of ore in an upcoming Mega tile, that Mega tile will be built as a blank
  Mega tile even if we're in a power crisis », « because we don't know when we'll come across ore again » (M33) ; « whenever we build a tile
  we also scan for ore and build a mining tile if ore is present » (M34) ; le gist sonde chaque place (30 × 30, G37 ; 10 × 10 par tuile, G57)
  et saisit un gisement au-dessus d'un seuil PAR RESSOURCE (uranium > 100 000, G42 ; somme des minerais > 1 000 000, G43).

  Ce qui manque chez nous (audit du 7/11, **lu**) : shared/team/plan.lua classe déjà un lot « gisement » (P.classify_lot l.174-186, seuil
  unique P.MIN_RES_TILES = 24 tuiles, l.42), MAIS script/team/build.lua:2727-2728 (try_place) replie TOUT module sans ressource (fonderie,
  chaîne, mall, laboratoires) sur un lot « gisement » quand aucun lot libre ne le prend : une fabrique peut se poser sur le minerai. Et un
  petit gisement d'une ressource RARE (moins de 24 tuiles) est classé « libre » : rien ne le protège.

  Règles :
    1. Lm.ores(s, seuils) : minerais d'un relevé au-dessus de LEUR seuil (tuiles, ou quantité si le relevé la donne) ; seuils lus en
       données par ressource (seuils.tiles[r], seuils.amount[r]), défaut Lm.MIN_TILES ;
    2. Lm.role(s, seuils) : « minerai » dès qu'un minerai passe son seuil ; l'arbre et le rocher ne l'effacent pas (on défriche) ;
    3. Lm.allows(role, sorte) : un lot de minerai est RÉSERVÉ à l'extraction et à la fonte, MÊME EN CRISE (aucun paramètre de crise :
       c'est voulu) ; sorte inconnue : refus (garde fermée par défaut, L13) ;
    4. Lm.states_for(sorte) : états de lots essayés, dans l'ordre, par place_module ; une fabrique ne se replie JAMAIS sur un gisement
       (le treillis grandit à la place) ; la fonte s'y replie (fonderie au minerai) ;
    5. Lm.needs_survey(l, tick, ev_tick, max_age) : le relevé précède la décision ; un relevé plus ancien que le dernier événement qui
       change la place (porte fermée, bâtiment détruit, ennemi vu : G l.568-570) ou que max_age ticks de jeu est refait ;
    6. Lm.reserve(lots, seuils) : à la croissance du treillis, chaque lot de minerai neuf est RÉSERVÉ tout de suite (V45, V46),
       indépendamment de toute crise ; rend les réservations triées.
  Déterminisme : listes triées (nombre décroissant, puis nom), aucun `pairs` décisionnel, aucun hasard, aucun temps mesuré.
  Coût : O(ressources du relevé) par lot.
]]

local Lm = {}

Lm.MIN_TILES = 24 -- tuiles : défaut, égal à P.MIN_RES_TILES (shared/team/plan.lua:42) ; l'appelant passe la valeur du plan
Lm.ON_ORE = { extraction = true, fonte = true } -- M33 : seules sortes admises sur un lot de minerai
Lm.KINDS = { extraction = true, fonte = true, energie = true, fabrique = true }
Lm.STATES = {
  extraction = { { gisement = true } },
  fonte = { { libre = true, defricher = true }, { gisement = true } },
  energie = { { rive = true, eau = true } },
  fabrique = { { libre = true, defricher = true } },
}

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end
local function num(v) if type(v) ~= "number" or v ~= v then return 0 end return v end

--- Minerais au-dessus de leur seuil. s = { res = { [r] = tuiles }, amount = { [r] = quantité } (facultatif) } ; seuils = { tiles =
--- { [r] = n }, amount = { [r] = q }, min_tiles = défaut }. Rend { { res, tiles, amount, why = "tuiles" | "quantite" } } trié.
function Lm.ores(s, seuils)
  seuils = seuils or {}
  local st, sa = seuils.tiles or {}, seuils.amount or {}
  local def = seuils.min_tiles or Lm.MIN_TILES
  local out = {}
  for _, r in ipairs(sorted_keys(s and s.res)) do
    local n, q = num(s.res[r]), num(s.amount and s.amount[r])
    local why = nil
    if n > 0 and n >= (st[r] or def) then why = "tuiles"
    elseif sa[r] and q >= sa[r] then why = "quantite" end
    if why then out[#out + 1] = { res = r, tiles = n, amount = q, why = why } end
  end
  table.sort(out, function(a, b)
    if a.tiles ~= b.tiles then return a.tiles > b.tiles end
    return a.res < b.res
  end)
  return out
end

--- Rôle d'un lot relevé : "minerai" (et son minerai principal), ou "general". Les refus (nid, falaise, conteste, eau majoritaire) et
--- la rive restent ceux de P.classify_lot : l'appelant ne demande le rôle qu'aux lots qui ne sont ni refusés ni rive.
function Lm.role(s, seuils)
  local list = Lm.ores(s, seuils)
  if #list > 0 then return "minerai", list[1].res, list end
  return "general", nil, list
end

--- Une sorte de module (extraction, fonte, energie, fabrique) peut-elle aller sur un lot de ce rôle ? Rend ok, raison.
function Lm.allows(role, kind)
  if not Lm.KINDS[kind] then return false, "sorte inconnue (garde fermee)" end
  if role == "minerai" and not Lm.ON_ORE[kind] then
    return false, "lot de minerai reserve a l'extraction et a la fonte"
  end
  return true
end

--- États de lots à essayer, dans l'ordre (copies). Sorte inconnue : aucun.
function Lm.states_for(kind)
  local out = {}
  for _, set in ipairs(Lm.STATES[kind] or {}) do
    local c = {}
    for _, k in ipairs(sorted_keys(set)) do c[k] = set[k] end
    out[#out + 1] = c
  end
  return out
end

--- Faut-il refaire le relevé avant de décider ? l = { tick } (dernier relevé ; nil : jamais) ; ev_tick = dernier événement qui change
--- la place (nil : aucun) ; max_age = âge maximal en ticks de jeu (nil : aucun). Rend vrai et la raison, ou faux.
function Lm.needs_survey(l, tick, ev_tick, max_age)
  local t = l and l.tick
  if type(t) ~= "number" then return true, "jamais releve" end
  if type(ev_tick) == "number" and ev_tick > t then return true, "evenement apres le releve" end
  if type(max_age) == "number" and type(tick) == "number" and tick - t > max_age then return true, "releve trop ancien" end
  return false
end

--- Réservations à la croissance du treillis. lots = { { key, s (relevé), used, reserved } } (ordre de l'appelant) ; rend
--- { { key, res, why } } triés par clé : chaque lot neuf de minerai, ni pris ni déjà réservé. Aucune crise n'y entre (V45).
function Lm.reserve(lots, seuils)
  local out = {}
  for _, l in ipairs(lots or {}) do
    if not l.used and not l.reserved then
      local role, res, list = Lm.role(l.s, seuils)
      if role == "minerai" then out[#out + 1] = { key = l.key, res = res, why = list[1].why } end
    end
  end
  table.sort(out, function(a, b) return tostring(a.key) < tostring(b.key) end)
  return out
end

return Lm
