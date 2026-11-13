--[[
  s42 bus-continu (chantier 1 du DC, partie de 4 h 15 en 0.7.96 : « même les factions les plus avancées laissent leurs bus déconnectés ») : CONTRÔLE DE CONTINUITÉ d'une ligne de bus,
  du premier tapis à la dernière section. Règle PURE : aucune API du jeu, aucun nom d'objet (les genres sont des TYPES de prototype, donnés par l'appelant).
  Testée hors jeu : tests/s42_bus-continu_test.lua. Exécutant : script/team/mall_rangee.lua (Rt.continuite, à l'audit de la minute du mall).

  Constat (journal de la partie, emerald, 209,5 min) : « projet 42 sans progres depuis 10 min : chantier ; 103 entite(s) baties sur 106 ; manquantes : inserter/quai-bras ;
  transport-belt/mall-tronc ; transport-belt/mall-tronc » : deux tapis de la tête de la ligne du cuivre manquent, la ligne est coupée à sa première tuile et personne ne le dit ni ne le suit.

  Une PIÈCE du bus (plan du projet) : { x, y (centre), dir (0, 2, 4, 6), kind (type du prototype : tapis, répartiteur, souterrain), ug (« input » / « output » pour un souterrain),
  built, dropped, hand_gave, item (objet qui la pose), bc_n (réouvertures déjà faites par ce contrôle) }.
  `lire(x, y)` rend ce que le monde porte sur la tuile de centre (x, y) : nil, ou { kind, dir, ug } pour une pièce de convoyage de l'équipe.

  Verdicts par pièce, dans l'ordre du plan (donc du flux : la tête, la ligne, les prises, l'amenée) :
    « chantier » : la pièce n'est pas (ou plus) posée et son projet la sait à poser : rien à faire ici, elle est comptée (la ligne est coupée tant qu'elle manque) ;
    « absent »   : le plan la croit posée, le monde ne porte rien du genre : ROUVRIR la pose (au plus Bc.MAX_ROUVRE fois par pièce : pas de boucle sur un point que l'ennemi tient) ;
                   jamais une pièce cédée (dropped), retirée à la main (hand_gave) ou sans objet pour la poser ;
    « tourne »   : la pièce est là, mal orientée : la TOURNER (tapis et répartiteur ; un souterrain mal orienté est laissé, tourner un souterrain inverse son rôle) ;
    « autre »    : la tuile porte une AUTRE pièce de convoyage (un répartiteur ou un souterrain posé là par un autre module à la place du tapis) : le flux passe, ce n'est PAS un défaut
                   (compté dans `autre`, jamais rouvert : reposer un tapis sur un répartiteur échouerait sans fin) ;
    « sortie »   : (répartiteur en place) une de ses deux sorties n'est suivie d'aucun tapis, ou d'un tapis qui lui fait face : dit, la tuile fautive est celle d'une autre pièce du plan.
  Déterminisme : listes en ordre fixe, aucun pairs, aucun hasard.
]]

local Bc = {}

Bc.MAX_ROUVRE = 3      -- réouvertures d'une même pièce par ce contrôle, pour toute la partie
Bc.EVERY = 5 * 3600    -- ticks entre deux contrôles d'une équipe
Bc.LOGS = 60           -- lignes [FO-BUS-CONTINU] par équipe

local AVANT = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

--- Les deux tuiles (centres) en sortie d'un répartiteur de centre (x, y) orienté dir.
function Bc.sorties(x, y, dir)
  local f = AVANT[dir or 0] or AVANT[0]
  local lx, ly = (f[1] == 0) and 0.5 or 0, (f[1] == 0) and 0 or 0.5
  return { { x = x + f[1] - lx, y = y + f[2] - ly }, { x = x + f[1] + lx, y = y + f[2] + ly } }
end

--- Que faire d'un défaut : « rouvrir », « tourner » ou « laisser » (et pourquoi).
function Bc.action(cause, piece, genres)
  if cause == "absent" then
    if piece.dropped then return "laisser", "piece cedee" end
    if piece.hand_gave then return "laisser", "retiree a la main" end
    if not piece.item then return "laisser", "aucun objet pour la poser" end
    if (piece.bc_n or 0) >= Bc.MAX_ROUVRE then return "laisser", "deja rouverte " .. Bc.MAX_ROUVRE .. " fois" end
    return "rouvrir"
  elseif cause == "tourne" then
    if piece.kind == genres.souterrain then return "laisser", "souterrain mal oriente" end
    return "tourner"
  end
  return "laisser"
end

--- Contrôle. pieces : liste ordonnée (flux) ; lire(x, y) ; genres = { tapis, repartiteur, souterrain } (types de prototype).
--- Rend { defauts = { { i, x, y, cause, action, why } ... }, n = pièces vues, ok = pièces conformes, chantier, absent, tourne, sortie }.
function Bc.controle(pieces, lire, genres)
  local out = { defauts = {}, n = 0, ok = 0, chantier = 0, absent = 0, tourne = 0, sortie = 0, autre = 0 }
  local convoie = { [genres.tapis] = true, [genres.repartiteur] = true, [genres.souterrain] = true }
  local function defaut(i, x, y, cause, piece)
    local action, why = Bc.action(cause, piece, genres)
    out[cause] = out[cause] + 1
    out.defauts[#out.defauts + 1] = { i = i, x = x, y = y, cause = cause, action = action, why = why }
  end
  for i, p in ipairs(pieces) do
    out.n = out.n + 1
    if not p.built then
      defaut(i, p.x, p.y, "chantier", p)
    else
      local w = lire(p.x, p.y)
      if w and w.kind ~= p.kind and convoie[w.kind] then
        out.autre = out.autre + 1
        out.ok = out.ok + 1
      elseif not w or w.kind ~= p.kind then
        defaut(i, p.x, p.y, "absent", p)
      elseif (w.dir or 0) ~= (p.dir or 0) or (p.kind == genres.souterrain and p.ug and w.ug ~= p.ug) then
        defaut(i, p.x, p.y, "tourne", p)
      else
        local bon = true
        if p.kind == genres.repartiteur then
          for _, s in ipairs(Bc.sorties(p.x, p.y, p.dir)) do
            local a = lire(s.x, s.y)
            if not (a and convoie[a.kind]) or (a.dir or 0) == ((p.dir or 0) + 4) % 8 then
              bon = false
              defaut(i, s.x, s.y, "sortie", p)
            end
          end
        end
        if bon then out.ok = out.ok + 1 end
      end
    end
  end
  return out
end

--- La ligne est-elle continue ? (aucun défaut)
function Bc.continue(res) return #res.defauts == 0 end

return Bc
