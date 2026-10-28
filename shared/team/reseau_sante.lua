--[[
  Lot RESEAU-VIVANT : SANTÉ de la centrale et du réseau d'une équipe, après l'état « fini ». PUR : aucune API Factorio, aucun
  nom d'objet (le script range les pièces par GENRE lu au prototype : source = produit la vapeur ou le courant, gen = machine
  génératrice, eau = pompe), testé hors jeu par tests/reseau_sante_test.lua avec des mutants.

  Constat du DC (28/10) : « ils sont incapables de détecter des zones qui ne sont pas couvertes », une centrale détruite
  n'est jamais refaite, « il faut trouver une autre voie quand le site est dangereux ». Dans main, la connexité n'est vérifiée
  qu'une fois, à la fin d'un projet ; après « fini » plus personne ne regarde.

  UNE DÉCISION À PLUSIEURS ENTRÉES (aucune ne suffit seule) :
    pièces       combien de sources / machines / pompes / tuyaux la centrale devrait avoir et combien existent (existence) ;
    production   énergie produite lue au moteur (kW) contre la demande des consommateurs posés ;
    combustible  sources présentes mais à sec ;
    connexité    consommateurs sur un îlot sans centrale, sous aucun poteau ; centrale reliée ou non ;
    danger       ennemis à portée du site, pertes déjà subies sur le site, essais déjà faits.
  ACTIONS (une seule par décision) :
    "ok"          rien à faire ;
    "attendre"    le diagnostic n'est pas confirmé, ou ennemis à portée (jamais de pose sous le feu), ou plus d'autre site ;
    "reposer"     pièces perdues, site sûr : rouvrir le projet pour les refaire sur place ;
    "autre_site"  pièces perdues et site DANGEREUX (persistant) ou refait en vain : la centrale est demandée AILLEURS ;
    "relier"      centrale vivante mais des consommateurs sur un îlot : relever les poteaux perdus qui les rallument ;
    "couvrir"     centrale saine, des consommateurs sous AUCUN poteau depuis plusieurs relevés (hors chantier) : poser les poteaux
                  (en nombre minimal, R.repair) qui les relient au réseau d'une centrale ;
    "combustible" sources présentes, à sec, production nulle : ce n'est pas un problème de réseau (diagnostic publié).
  Option par défaut de la question au DC : reconstruire AILLEURS dans la zone sûre la plus proche du réseau.
  Déterminisme : entiers et booléens, aucune horloge mesurée, aucun hasard, aucun pairs.
]]

local S = {}

S.CONFIRM = 2          -- relevés de suite avant d'agir sur un diagnostic de production nulle (pas sur une perte certaine)
S.DANGER_R = 40        -- tuiles : ennemis à cette portée du site = site tenu
S.DANGER_SEEN = 4      -- relevés de suite avec des ennemis à portée avant de juger le site dangereux (quelques secondes ne suffisent pas)
S.MAX_TRIES = 2        -- reposes sur place sans que la production revienne, avant d'abandonner le site
S.SITE_LOSSES = 2      -- pertes de pièces sur le site (déjà refait) au-delà desquelles il est jugé dangereux
S.MAX_RELOC = 3        -- centrales de remplacement demandées au plus
S.MIN_DEMAND_KW = 1    -- demande en dessous de laquelle une production nulle n'est pas une panne
S.COVER_CONFIRM = 2    -- relevés du réseau de suite avec des consommateurs découverts (hors chantier) avant de poser des poteaux
S.MAX_COVER = 4        -- poses de couverture au plus pour un même épisode (remis à zéro quand plus rien n'est découvert)

function S.new()
  return { bad = 0, seen = 0, tries = 0, relocations = 0, site_losses = 0, cover_tries = 0, last = nil, last_tick = nil }
end

local function lost_of(inp)
  local m = inp.missing or {}
  return (m.source or 0) + (m.gen or 0) + (m.eau or 0) + (m.tuyau or 0)
end
S.lost = lost_of

--- Décision. inp : voir le haut du fichier ; st : S.new() (modifié). Rend action, raison (texte), détail { lost, danger }.
--- inp = { fini = bool, missing = { source, gen, eau, tuyau }, present = { source, gen, eau }, prod_kw, demand_kw, dry = n sources à sec,
---         islands = n consommateurs sur îlot, uncovered = n sous aucun poteau, enemies = n ennemis à portée du site,
---         lost_links = n poteaux perdus qui rallumeraient quelque chose }
function S.decide(inp, st)
  local lost = lost_of(inp)
  local detail = { lost = lost }
  if not inp.fini then
    st.bad, st.seen = 0, 0
    return "attendre", "centrale pas finie", detail
  end
  -- danger : persistance des ennemis à portée, pertes déjà subies sur le site
  if (inp.enemies or 0) > 0 then st.seen = st.seen + 1 else st.seen = 0 end
  local danger = st.seen >= S.DANGER_SEEN or st.site_losses >= S.SITE_LOSSES or st.tries >= S.MAX_TRIES
  detail.danger = danger
  if lost > 0 then
    -- perte CERTAINE : pas de confirmation à attendre
    if danger then
      if st.relocations < S.MAX_RELOC then
        return "autre_site", string.format("%d piece(s) perdue(s), site dangereux (ennemis vus %d fois, pertes %d, reposes %d)", lost,
          st.seen, st.site_losses, st.tries), detail
      end
      return "attendre", "pieces perdues, site dangereux, plus d'autre site", detail
    end
    if (inp.enemies or 0) > 0 then return "attendre", "ennemis a portee du site : pas de pose sous le feu", detail end
    return "reposer", string.format("%d piece(s) perdue(s), site sur", lost), detail
  end
  -- pièces toutes là
  local demand = inp.demand_kw or 0
  if (inp.prod_kw or 0) <= 0 and demand >= S.MIN_DEMAND_KW then
    st.bad = st.bad + 1
    if st.bad < S.CONFIRM then return "attendre", "production nulle (a confirmer)", detail end
    if (inp.dry or 0) > 0 then return "combustible", "production nulle, source(s) a sec", detail end
    if (inp.islands or 0) > 0 or (inp.uncovered or 0) > 0 then return "relier", "production nulle, consommateurs hors de la centrale", detail end
    return "attendre", "production nulle sans cause lue", detail
  end
  st.bad = 0
  if (inp.islands or 0) > 0 and (inp.lost_links or 0) > 0 then
    return "relier", string.format("%d consommateur(s) sur un ilot, %d poteau(x) perdu(s)", inp.islands, inp.lost_links), detail
  end
  if (inp.uncovered or 0) == 0 then st.cover_tries = 0 end
  if (inp.uncovered or 0) > 0 and (inp.uncov_reads or 0) >= S.COVER_CONFIRM and not inp.cover_busy then
    if st.cover_tries >= S.MAX_COVER then return "attendre", "consommateurs decouverts : poses de couverture epuisees", detail end
    return "couvrir", string.format("%d consommateur(s) sous aucun poteau depuis %d releves", inp.uncovered, inp.uncov_reads), detail
  end
  return "ok", "centrale saine", detail
end

--- Une décision exécutée : note l'action (essais, déménagements) pour les décisions suivantes.
function S.applied(st, action, tick)
  st.last, st.last_tick = action, tick
  if action == "reposer" then st.tries = st.tries + 1 end
  if action == "couvrir" then st.cover_tries = st.cover_tries + 1 end
  if action == "autre_site" then
    st.relocations = st.relocations + 1
    st.tries, st.site_losses, st.seen, st.bad = 0, 0, 0, 0
  end
end

--- Une perte de pièce sur le site (une pièce déjà refaite, perdue de nouveau) : pour le jugement de danger.
function S.note_loss(st, n)
  st.site_losses = st.site_losses + (n or 1)
end

--- La production est revenue : les essais sur place sont soldés.
function S.recovered(st)
  st.tries, st.bad = 0, 0
end

return S
