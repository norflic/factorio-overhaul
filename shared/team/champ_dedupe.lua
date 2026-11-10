--[[
  Lot COMBUSTIBLE-MIGRATION (suite, 9/11) : déduplication des pièces d'un projet de champ dont la tuile est DÉJÀ au plan d'un autre projet.
  PUR : aucune API Factorio, aucun nom d'objet ; testé hors jeu par tests/champ_dedupe_test.lua (mutants). Exécutant : Build.SITES.champ
  (script/team/champ.lua).

  Défaut cherché (fo-logs/2026-11-09_CANDIDAT/carte-g123456789-1d7c6218, votre équipe) : « projet 9 (bande -37) : 28 pièce(s) écartée(s), leurs tuiles déjà
  au plan du projet 11 : small-electric-pole 4, transport-belt 24 » (rôle champ-charbon, commun), alors que la voie de charbon du champ de fer livre
  si peu que 72 fours sur 112 sont sans combustible. Avant ce lot, une pièce était écartée dès que sa tuile était au plan d'un AUTRE projet, quel que soit
  ce que le détenteur y pose : un tapis d'un autre flux, ou dans l'autre sens, coupait le tronc en silence.

  Règle : une pièce n'est écartée que si, sur CHACUNE de ses tuiles prises, le détenteur porte la même pièce (même nom, même rôle, même direction : un
  doublon légitime, le tronc commun posé par la première bande d'un côté). Sinon la tuile est un CONFLIT : une pièce du réseau du charbon en conflit
  coupe le tronc (`cut`), l'exécutant refuse le réseau avec la cause au journal (une autre tentative le retrace, les tuiles du détenteur étant alors
  connues du plan) ; toute autre pièce reste écartée comme avant (la ligne du journal la compte à part).
  Aucun `pairs` décisionnel, aucun hasard, aucun temps mesuré.
]]

local M = {}

--- Le détenteur `h` porte-t-il la même pièce que `e` ? Mêmes nom, rôle et direction (direction absente = 0). `h` nil : non.
function M.same(e, h)
  if not (e and h) then return false end
  return e.name == h.name and e.role == h.role and (e.dir or 0) == (h.dir or 0)
end

--- Verdict pour une pièce `e` dont les tuiles prises ont pour détenteurs `held` = { { pid, ent }, ... } (une entrée par tuile prise ; ent nil si le projet
--- détenteur ne porte plus de pièce sur cette tuile). Rend ("garder" si rien n'est pris, "ecarter" si tout est un doublon légitime, "conflit" sinon).
function M.verdict(e, held)
  if #held == 0 then return "garder" end
  for _, x in ipairs(held) do
    if not M.same(e, x.ent) then return "conflit" end
  end
  return "ecarter"
end

--- Une pièce en conflit coupe-t-elle le tronc du charbon ? `role_coal` : le rôle de la pièce est celui du réseau du charbon.
function M.cuts_trunk(verdict, role_coal)
  return verdict == "conflit" and role_coal == true
end

--- RÉSERVATION DU TRONC (partie 90 min 123456789, « TRONC COUPE » : 28 pièces du réseau du charbon du projet 9 sur des tuiles de la bande de cuivre du projet 11,
--- planifiée 0,2 min plus tôt que lui alors que le cadre du champ de fer, tronc compris, datait de 12,1 min) : dès que la première bande d'un cadre est planifiée, les
--- tuiles du réseau du charbon REPORTÉ (projets liés, pas encore planifiés) sont retenues au plan sous un propriétaire de cadre ; les autres projets les évitent
--- (blocked_in lit b.occ) ; les projets du MÊME avant-poste les traitent comme libres et les prennent (leur propriétaire devient le projet).
function M.marker(oid) return "cadre:" .. tostring(oid) end

--- Ce propriétaire de tuile est-il la réservation du cadre de l'avant-poste `oid` ?
function M.own(owner, oid)
  return owner ~= nil and owner == M.marker(oid)
end

--- Retient les tuiles `tiles` ({ { x, y }, ... }) au nom du cadre de `oid` dans `occ` ({ [clé] = propriétaire }) ; `key(x, y)` donne la clé. Une tuile déjà prise
--- (un projet, ou un autre cadre) n'est jamais écrasée. Rend le nombre de tuiles retenues.
function M.reserve(occ, tiles, oid, key)
  local n = 0
  for _, t in ipairs(tiles) do
    local k = key(t[1], t[2])
    if occ[k] == nil then occ[k] = M.marker(oid); n = n + 1 end
  end
  return n
end

--- Lot CC-SAUT (F515, mandat du DC du 10/11, 22 h 20 : « un obstacle ponctuel n'annule jamais toute la rangée ») : tuiles du cadre à retenir dès qu'il est
--- FIGÉ. Le cadre fixe la place de la colonne de fours de CHAQUE bande future (rejouée sans recherche, shared/team/champ_colonne.lua, Co.place `fixed`), mais
--- seules les tuiles du réseau du charbon reporté étaient retenues (M.reserve) : un autre projet planifié entre-temps (référence 0.6.91, graine 314159265 :
--- la ligne de poteaux du même avant-poste, projet 4, à 8,1 min) prenait la place figée, et la bande entière était refusée « bande vide : 17 foreuse(s)
--- possibles, 2 groupe(s) sans place de fonderie ; 1re tuile prise (17, 77), relevee « reserve » » (puis une bande de 34 foreuses). Rend les tuiles des pièces
--- HORS ressource du plan entier (colonnes, coffres, bras, poteaux et tapis hors du gisement), jamais celles des foreuses ni d'une pièce qui touche une
--- ressource (les lignes de poteaux peuvent traverser le gisement). `ents` = { { kind, x, y, size, w, h } } (centre en tuiles, côtés) ; `is_ore(x, y)` vrai
--- sur une tuile de ressource. Rend { { x, y }, ... } dans l'ordre des pièces (déterministe).
function M.frame_tiles(ents, is_ore)
  local out = {}
  for _, e in ipairs(ents or {}) do
    if e.kind ~= "foreuse" then
      local w, h = e.w or e.size or 1, e.h or e.size or 1
      local x0, y0 = math.floor(e.x - w / 2 + 0.5), math.floor(e.y - h / 2 + 0.5)
      local tiles, on_ore = {}, false
      for x = x0, x0 + w - 1 do
        for y = y0, y0 + h - 1 do
          if is_ore(x, y) then on_ore = true end
          tiles[#tiles + 1] = { x, y }
        end
      end
      if not on_ore then for _, t in ipairs(tiles) do out[#out + 1] = t end end
    end
  end
  return out
end
--- Libère les tuiles retenues par le cadre de `oid` (cadre refait). Rend le nombre libéré. (L'ordre de passage est sans effet.)
function M.clear(occ, oid)
  local n, m = 0, M.marker(oid)
  for k, v in pairs(occ or {}) do
    if v == m then occ[k] = nil; n = n + 1 end
  end
  return n
end

--- Avant-postes dont un cadre retient des tuiles dans `occ`, triés (nombres).
function M.owners(occ)
  local seen, out = {}, {}
  for _, v in pairs(occ or {}) do
    if type(v) == "string" then
      local id = tonumber(v:match("^cadre:(.+)$"))
      if id and not seen[id] then seen[id] = true; out[#out + 1] = id end
    end
  end
  table.sort(out)
  return out
end

--- Cadres à libérer : ceux dont l'avant-poste n'a plus aucun projet de champ vivant (`alive` = { [oid] = true } : projets ni refusés ni annulés ; un réseau du charbon
--- qui n'est finalement pas demandé, une bande refusée ou un cadre abandonné ne gardent pas leurs tuiles). Rend la liste triée des numéros.
function M.dead(owners, alive)
  local out = {}
  for _, oid in ipairs(owners) do
    if not (alive and alive[oid]) then out[#out + 1] = oid end
  end
  return out
end

--- Lot UPS-2 (sprint du DC, 10/11) : tick du prochain essai d'un plan qui ATTEND que son tronc de charbon se libère. Mesuré au banc V0679-A
--- (123456789, 90 min) : la bande -38 du joueur (projet 21) était replanifiée à chaque passe pendant toute l'attente (1 781 plans en 5 min de
--- jeu, scarlet 1 717), soit l'essentiel de build:plan:place (258 s sur 1 007 s de banc, ≈ 14 ms par tick dans la fenêtre). Le prochain
--- essai vient `poll` ticks plus tard, et jamais après la fin de l'attente (`t0 + wait`) : la décision « attente finie, réseau accepté tel
--- quel » tombe au même tick qu'avant. Un conflit levé pendant l'attente est vu au plus `poll` ticks plus tard.
function M.next_try(tick, t0, wait, poll)
  local stop = t0 + wait
  local nx = tick + poll
  if nx > stop then nx = stop end
  if nx < tick then nx = tick end
  return nx
end

return M
