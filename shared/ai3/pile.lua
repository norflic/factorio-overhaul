--[[
  Lot PILE-PRIORITE (vague 8, demande du DC du 29/10, 20 h 45 : « on répare + protège (donc on s'adapte) et ensuite on
  continue et on améliore (il est possible pour protéger, on doive avoir besoin de fer et donc en venir à construire une
  usine, aller chercher un nouveau gisement de fer […]) en fait la pile de priorité ne s'applique pas qu'aux IA mais aussi
  au cerveau principal » ; et à 15 h : « si on manque cruellement de ressources, l'objectif est justement ces ressources,
  pas la défense […] si on peut pas se l'acheter, on investit les ressources dans la production de plus de ressources »).

  PUR (aucune API Factorio, aucun nom d'objet ni de bâtiment du jeu : les objets viennent des appelants, les entrées de
  la fonderie de shared/team/config.lua). Testé hors jeu : tests/pile_test.lua. Une PILE DE CADRES par équipe, rangée
  dans l'état persistant du cerveau (f.team.ia3.pile, donc global par storage.lua), recalculée à chaque pensée :

    R0 SURVIVRE   équipe sous son effectif de départ, QG menacé ;
    R1 S'ADAPTER  RÉPARER (pièce détruite refaisable, avec ou sans son objet au stock ; projet du plan directeur rouvert)
                  + PROTÉGER (poste sous son MINIMUM de tourelles : QG, avant-poste non défendu, centrale ; PAS la
                  croissance du front, sinon le cadre ne se fermerait jamais) ;
    R2 PRODUIRE   sous-cadres des cadres ouverts : la matière brute qui leur manque (livre de recettes, déplié par le
                  planificateur), puis son minerai, puis l'exploration si aucune source n'est connue (profondeur bornée
                  Pi.DEPTH_MAX) ; et le mode survie-pénurie (manque cruel, shared/team/survie.lua) ;
    R3 AMÉLIORER  capital, capitalisation (sauf ses investissements de production), changement de foreuses, migration
                  du champ, recherche chère.

  Règles :
    - un cadre EXISTE tant que son signal existe (pièce encore au registre, poste sous son minimum, manque présent) : il
      s'ouvre sur l'événement qui crée le signal et se FERME quand il est satisfait (pièce refaite, poste pourvu, manque
      couvert) ou quand une règle d'événement le retire (pièce abandonnée par son compteur de pertes ou de poses refusées).
      AUCUNE HORLOGE ne ferme un cadre (c'est ce qui remplace le gel de 20 min retiré par le lot SANS-GEL) ;
    - une place tenue par l'ennemi (pièce différée : ennemis près d'elle) devient un cadre « place » (protéger ou
      nettoyer, lots PORTE-BASE et NETTOYAGE-SITE) qui NE RETIENT PAS l'amélioration : un site perdu ne gèle rien ;
    - sommet `top` = le plus petit rang d'un cadre qui retient ; `hold` = top < R3 et cadre non BLOQUÉ ; BLOQUÉ = aucun
      cadre R1 n'a de voie (objet ni au stock ni fabricable, matière sans source connue, tourelle sans recette) : un
      siège sans issue ne gèle rien ; un siège où l'on avance retient ;
    - Pi.allows(st, famille, objet) : une famille de rang supérieur au sommet est SUSPENDUE, sauf si elle sert un cadre
      ouvert (objet dans `focus`) ;
    - ordre interne de R1 (journal et service du stock virtuel) : « production d'abord » (shared/team/priorite.lua, le fer
      ne paie pas les deux) met les pièces à refaire et les matières devant la protection ; sinon la protection d'abord.

  Déterminisme : listes triées par (rang, sous-ordre, clé), entiers, aucun `pairs` décisionnel, aucun hasard, aucun
  temps mesuré.
]]

local T = require("shared.team.config")

local Pi = {}

Pi.SURVIVRE, Pi.ADAPTER, Pi.PRODUIRE, Pi.AMELIORER = 0, 1, 2, 3
Pi.RANK_NAME = { [0] = "survivre", [1] = "adapter", [2] = "produire", [3] = "ameliorer" }
-- Rang de chaque famille de travail (les buts de shared/ai3/buts.lua, les exécutants du runtime).
Pi.FAMILY_RANK = {
  survivre = 0, reparer = 1, proteger = 1, defense = 1, preparer = 1,
  produire = 2, extraction = 2, armee = 2, invest = 2,
  ameliorer = 3, capital = 3, capi = 3, upgrade = 3, recherche = 3, foreuses = 3, migration = 3,
}
-- Manques du planificateur permanent repris par la pile (et donnés au cerveau par besoins avec leur priorité) : ceux
-- des demandes de rang R0 et R1 (défense 90, survie 90 à 96, reconstruction d'un avant-poste 60). Plus bas : charbon (52),
-- réserve de munitions (35), recherche (40) : la production ordinaire, déjà servie par les projets.
Pi.INJECT_PRIO = 60
Pi.DEPTH_MAX = 3      -- objet ou plaque (1) -> minerai (2) -> exploration (3)
Pi.PLACES_MAX = 6     -- places tenues par l'ennemi gardées dans la pile (les plus précieuses)
Pi.CLOSED_KEEP = 6    -- derniers cadres dépilés gardés pour le journal
Pi.LOG_EVERY = 5 * 3600 -- journal [FO-PILE] : toutes les 5 min (et à chaque changement de sommet) ; aucune décision ne le lit
-- Postes dont le manque est une CROISSANCE (lot DEFENSE-FRONT : tourelles en plus là où les pièces tombent) : leur manque
-- de matière reste demandé, mais ils n'ouvrent pas de cadre (sinon la pile ne se viderait jamais).
Pi.GROWTH_POSTS = { front = true }
-- Intégration 0.6.19 (PILE-PRIORITE x ILOTS-MURS) : le poste de l'îlot isolé est FACULTATIF (shared/team/planner.lua, optional,
-- « ressources d'abord », jamais devant la production) : il n'ouvre pas de cadre « protéger », sinon un îlot sans tourelles
-- retiendrait le changement de foreuses, la migration du champ et l'amélioration (script/team/team.lua, PileRt.hold).
Pi.OPTIONAL_POSTS = { ilot = true }
-- Raisons du planificateur (plan.defend.posts[i].why) qui avancent ou peuvent avancer ; « recette » : aucune voie.
Pi.POST_STUCK = { recette = true }

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

function Pi.new()
  return { top = Pi.AMELIORER, hold = false, blocked = false, frames = {}, focus = {}, opened = {}, closed = {},
    closed_n = 0 }
end

--- Une matière a-t-elle une voie de production ? (elle-même ou son minerai a une source connue).
local function has_source(sig, item)
  local src = sig.sources or {}
  if src[item] then return true end
  local ore = (sig.inputs or {})[item]
  return ore ~= nil and src[ore] == true
end

--- Met la pile à jour. sig = {
---   survive     = raison (chaîne) ou nil : R0 ;
---   repair      = { { key, item, value, prio, have, craftable, claimed, enemy, infra } } : pièces du registre (non abandonnées) ;
---   plan_reopened = vrai : un projet du plan directeur rouvert doit encore prendre des objets au coffre (ses pièces ne sont pas
---                   au registre) ; plan_path = faux : un de ces objets n'est ni au coffre ni fabricable (aucune voie) ;
---   posts       = { { id, have, want, why, raw = { [matière] = n } } } : postes du planificateur (plan.defend.posts) ;
---   raw_need    = { [matière] = { n, prio } } : manque brut des demandes du planificateur permanent (Planner.plan) ;
---   sources     = { [matière] = vrai } : matières qui ont une source connue (avant-poste, site, gisement à portée) ;
---   inputs      = { [plaque] = minerai } : entrées de la fonderie ;
---   production_first = vrai : « production d'abord » (shared/team/priorite.lua) ;
---   penurie     = vrai : mode survie-pénurie (R2 sans parent) ;
---   prep        = { { id, have, want, exec, nohold, why } } : sites à PRÉPARER (lot PREVISION, Pc.pile_rows) }
--- Rend st (mis à jour) : top, hold, blocked, frames (triés), focus, short, crafts, reserve, changed.
function Pi.update(st, sig, tick)
  sig = sig or {}
  local frames = {}
  local pf = sig.production_first and true or false
  -- R0.
  if sig.survive then
    frames[#frames + 1] = { key = "survivre", rank = Pi.SURVIVRE, kind = "survivre", why = tostring(sig.survive), exec = true,
      sub = 0, depth = 0 }
  end
  -- R1 : réparer (agrégé par objet), places tenues par l'ennemi (sans retenue).
  local by_item, places = {}, {}
  for _, r in ipairs(sig.repair or {}) do
    if r.item then
      if r.enemy and not r.claimed then
        places[#places + 1] = r
      else
        local a = by_item[r.item]
        if not a then
          a = { item = r.item, n = 0, have = r.have or 0, craftable = r.craftable and true or false, claimed = 0, prio = 0,
            infra = r.infra and true or false }
          by_item[r.item] = a
        end
        a.n = a.n + 1
        if r.claimed then a.claimed = a.claimed + 1 end
        if (r.prio or 0) > a.prio then a.prio = r.prio or 0 end
      end
    end
  end
  local crafts, reserve = {}, {}
  local focus = {}
  for _, item in ipairs(sorted_keys(by_item)) do
    local a = by_item[item]
    local open_n = a.n - a.claimed -- pièces dont aucune tâche n'est prise : leur objet est à garder ou à fabriquer
    local exec = a.claimed > 0 or a.have > 0 or a.craftable
    frames[#frames + 1] = { key = "reparer:" .. item, rank = Pi.ADAPTER, kind = "reparer", item = item, n = a.n,
      have = a.have, exec = exec, sub = pf and 0 or 1, depth = 0 }
    focus[item] = true
    if open_n > 0 then
      local keep = math.min(a.have, open_n)
      if keep > 0 then reserve[#reserve + 1] = { item, keep } end
      -- L'objet manque : il devient une fabrication de rang R1 (l'infrastructure électrique a déjà la sienne, Rc.demand).
      if open_n > keep and a.craftable and not a.infra then crafts[#crafts + 1] = { item, open_n - keep, a.prio } end
    end
  end
  if sig.plan_reopened then
    -- (relecture : voie = chaque objet qui manque au projet est au coffre ou fabricable ; sinon le cadre ne retient pas seul)
    frames[#frames + 1] = { key = "reparer:plan", rank = Pi.ADAPTER, kind = "reparer", exec = sig.plan_path ~= false,
      sub = pf and 0 or 1, depth = 0 }
  end
  -- R1 : protéger (postes sous leur minimum).
  for _, p in ipairs(sig.posts or {}) do
    if (p.have or 0) < (p.want or 0) and not Pi.GROWTH_POSTS[p.id] and not Pi.OPTIONAL_POSTS[p.id] then
      local exec = not Pi.POST_STUCK[p.why or ""]
      for _, m in ipairs(sorted_keys(p.raw)) do
        if not has_source(sig, m) then exec = false end
      end
      frames[#frames + 1] = { key = "proteger:" .. tostring(p.id), rank = Pi.ADAPTER, kind = "proteger", have = p.have or 0,
        want = p.want or 0, why = p.why, exec = exec, sub = pf and 1 or 0, depth = 0 }
    end
  end
  -- Lot PREVISION : R1 PRÉPARER (une vague IMMINENTE prévue dépasse la défense d'un site ; shared/ai3/prevision_choix.lua). Le cadre
  -- EXISTE tant que la prévision tient son verrou (hystérésis d'ÉTAT dans la prévision, aucune horloge) ; il ne RETIENT pas quand
  -- la prévision le dit (`nohold` : au-delà des Pc.PREP_MAX plus grands écarts, insurmontable, « production d'abord », sans
  -- exécutant) ; son `exec` dit si un exécutant l'a accepté (tourelles d'avance du front, recrues).
  for _, p in ipairs(sig.prep or {}) do
    if (p.have or 0) < (p.want or 0) then
      frames[#frames + 1] = { key = "preparer:" .. tostring(p.id), rank = Pi.ADAPTER, kind = "preparer", have = p.have or 0,
        want = p.want or 0, why = p.why, exec = p.exec and true or false, nohold = (p.nohold or pf) and true or nil,
        sub = pf and 1 or 0, depth = 0 }
    end
  end
  -- Places tenues par l'ennemi (sous-but « protéger ou nettoyer la place ») : les plus précieuses d'abord.
  table.sort(places, function(a, b)
    if (a.value or 0) ~= (b.value or 0) then return (a.value or 0) > (b.value or 0) end
    return tostring(a.key) < tostring(b.key)
  end)
  for i = 1, math.min(#places, Pi.PLACES_MAX) do
    local r = places[i]
    frames[#frames + 1] = { key = "place:" .. tostring(r.key), rank = Pi.ADAPTER, kind = "place", item = r.item, exec = false,
      nohold = true, sub = 2, depth = 0 }
  end
  -- Parent des sous-cadres : le premier cadre qui retient, dans l'ordre (rang, sous-ordre, clé).
  local parent = nil
  for _, fr in ipairs(frames) do
    if not fr.nohold then
      if not parent or fr.rank < parent.rank or (fr.rank == parent.rank and (fr.sub < parent.sub
        or (fr.sub == parent.sub and fr.key < parent.key))) then parent = fr end
    end
  end
  -- Manques de rang R0/R1 (repris par le cerveau par besoins avec leur priorité) et sous-cadres PRODUIRE, bornés en profondeur.
  local short = {}
  local seen = {}
  local function produce(item, n, depth, from)
    if depth > Pi.DEPTH_MAX or seen[item] then return end
    seen[item] = true
    focus[item] = true
    if not parent then return end
    local src = has_source(sig, item)
    frames[#frames + 1] = { key = "produire:" .. item, rank = parent.rank, kind = "produire", item = item, n = n,
      parent = from, exec = src, sub = pf and 0 or 3, depth = depth }
    local ore = (sig.inputs or {})[item]
    if ore then
      produce(ore, n, depth + 1, "produire:" .. item)
    elseif not src and depth + 1 <= Pi.DEPTH_MAX then
      frames[#frames + 1] = { key = "explorer:" .. item, rank = parent.rank, kind = "explorer", item = item,
        parent = "produire:" .. item, exec = false, sub = pf and 0 or 3, depth = depth + 1 }
    end
  end
  for _, item in ipairs(sorted_keys(sig.raw_need)) do
    local r = sig.raw_need[item]
    if (r.prio or 0) >= Pi.INJECT_PRIO and (r.n or 0) > 0 then
      short[item] = { n = math.ceil(r.n), prio = r.prio }
      produce(item, math.ceil(r.n), 1, parent and parent.key or nil)
    end
  end
  -- R2 sans parent : le manque cruel (mode survie-pénurie).
  if sig.penurie then
    frames[#frames + 1] = { key = "produire:penurie", rank = Pi.PRODUIRE, kind = "produire", exec = true, sub = 0, depth = 0 }
  end
  table.sort(frames, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.sub ~= b.sub then return a.sub < b.sub end
    if a.depth ~= b.depth then return a.depth < b.depth end
    return a.key < b.key
  end)
  -- Sommet, blocage, retenue.
  local top = Pi.AMELIORER
  for _, fr in ipairs(frames) do
    if not fr.nohold and fr.rank < top then top = fr.rank end
  end
  local blocked = false
  if top == Pi.ADAPTER then
    blocked = true
    for _, fr in ipairs(frames) do
      if fr.rank == Pi.ADAPTER and not fr.nohold and fr.exec and fr.kind ~= "produire" and fr.kind ~= "explorer" then
        blocked = false
      end
    end
  end
  local hold = top < Pi.AMELIORER and not blocked
  -- Ouvertures et fermetures (par l'état, jamais par l'horloge).
  local now = {}
  for _, fr in ipairs(frames) do
    now[fr.key] = true
    fr.opened = (st.opened or {})[fr.key] or tick
  end
  local opened = {}
  for _, fr in ipairs(frames) do opened[fr.key] = fr.opened end
  for _, k in ipairs(sorted_keys(st.opened)) do
    if not now[k] then
      st.closed_n = (st.closed_n or 0) + 1
      st.closed = st.closed or {}
      table.insert(st.closed, 1, k)
      while #st.closed > Pi.CLOSED_KEEP do table.remove(st.closed) end
    end
  end
  st.changed = (top ~= st.top) or (hold ~= st.hold) or (blocked ~= st.blocked) -- lu par le journal (script/team/pile.lua)
  st.top, st.hold, st.blocked = top, hold, blocked
  if not hold then st.refus = nil end -- lot FUITES-PILE : fin de l'épisode de retenue, un refus futur sera de nouveau écrit
  st.frames, st.opened, st.focus, st.short = frames, opened, focus, short
  st.crafts, st.reserve = crafts, reserve
  st.tick = tick
  return st
end

--- Une famille (et l'objet qu'elle produit, facultatif) est-elle permise par la pile ? Rang ≤ sommet, ou pile non retenue,
--- ou l'objet sert un cadre ouvert.
function Pi.allows(st, family, item)
  if not st or not st.hold then return true end
  local rank = Pi.FAMILY_RANK[family] or Pi.AMELIORER
  if rank <= (st.top or Pi.AMELIORER) then return true end
  if item and st.focus and st.focus[item] then return true end
  return false
end

---------------------------------------------------------------------------------------------------
-- Lot FUITES-PILE (vague 10) : les chemins qui contournaient la pile passent par une PORTE unique.
---------------------------------------------------------------------------------------------------
-- Familles d'investissement de PRODUCTION : pile retenue, elles passent encore quand la matière qu'elles produisent MANQUE (« si
-- on peut pas se l'acheter, on investit les ressources dans la production de plus de ressources », DC 29/10 ; même règle que
-- g.invest des buts de la capitalisation, shared/ai3/cerveau.lua). Le capital pur (niveau d'un bâtiment), la recherche, le
-- changement de foreuses, la migration et l'amélioration des tapis n'en sont pas.
Pi.INVEST_FAMILIES = { capital = true, capi = true, invest = true, produire = true, extraction = true }

--- Un travail de la famille `family` (objet produit `item`, facultatif ; `short` : cette matière manque) peut-il AVANCER (ouvrir
--- un ordre, réserver au coffre, faire fabriquer ses objets) ? Rend (permis, raison du refus).
--- Permis : pile non retenue ; famille de rang ≤ sommet ; objet d'un cadre ouvert (focus) ; investissement de production d'une
--- matière qui manque. RÉPARER (rang R1 et moins) n'est JAMAIS suspendu par cette porte : la pile ne suspend que ce qui améliore
--- (R0 passe devant la réparation par les priorités des tâches, pas par une suspension).
function Pi.porte(st, family, item, short)
  if not st or not st.hold then return true, nil end
  local rank = Pi.FAMILY_RANK[family] or Pi.AMELIORER
  if rank <= Pi.ADAPTER then return true, nil end
  if Pi.allows(st, family, item) then return true, nil end
  if short and Pi.INVEST_FAMILIES[family] then return true, nil end
  return false, string.format("pile au sommet %s : %s (rang %s) suspendu%s", Pi.RANK_NAME[st.top or Pi.AMELIORER] or "?",
    tostring(family), Pi.RANK_NAME[rank] or "?", item and (", " .. tostring(item) .. " hors des cadres ouverts et sans manque") or "")
end

--- Fuite (b) : famille d'un MODULE du plan directeur. `rebuilding` : pièces DÉTRUITES à refaire (reconstruction, rang s'adapter,
--- shared/team/rebuild_sweep.lua Sw.rebuilding) ; `growth` : pas d'agrandissement d'une ligne finie (investissement de production) ;
--- `kind` : "migration" (migration du champ) ; sinon un module NEUF, « capi » s'il vient de la capitalisation, « capital » sinon.
function Pi.module_family(rebuilding, growth, capi, kind)
  if rebuilding then return "reparer" end
  if kind == "migration" then return "migration" end
  if growth then return "invest" end
  return capi and "capi" or "capital"
end

--- Fuite (a) : famille d'un ORDRE de la capitalisation (shared/ai3/capitalisation.lua) : laboratoires, packs et recherches à effet
--- sont de la recherche ; le reste (couvrir, ouvrir, chaîne, équiper) de la capitalisation.
Pi.ORDER_RESEARCH = { labos = true, packs = true, techno = true }
function Pi.order_family(kind)
  return Pi.ORDER_RESEARCH[kind] and "recherche" or "capi"
end

--- Relecture FUITES-PILE : un but d'AMÉLIORATION dont le produit ne sert aucun cadre ouvert (`focus`) : module neuf, de migration ou
--- pas d'agrandissement (g.pile de rang > s'adapter), alimentation qui porte les pièces d'un agrandissement (g.grow), but de la
--- capitalisation (g.kind « capi », objet de son ordre). Ses PROPRES manques ne justifient pas l'exception « matière qui manque » de
--- Pi.porte (Pi.short_core) : sans cela, un module neuf de cuivre dont les foreuses demandent des circuits rendait le cuivre
--- « manquant » et passait la retenue tout seul, pensée après pensée (relecture, moteur simulé : projet gardé sous la retenue).
function Pi.improving(g, focus)
  if type(g) ~= "table" then return false end
  local item
  if g.kind == "module" and (g.pile or g.grow) then
    if g.pile and (Pi.FAMILY_RANK[g.pile] or Pi.AMELIORER) <= Pi.ADAPTER then return false end
    item = g.product
  elseif g.kind == "capi" then
    item = g.order and g.order.item
  else
    return false
  end
  return not (item ~= nil and focus ~= nil and focus[item] == true)
end

Pi.SHORT_EPS = 1e-6 -- manques fractionnaires (recettes) : en deçà, plus rien ne manque

--- Relecture FUITES-PILE : manques « propres » de l'équipe, lus par l'exception « matière qui manque » de la porte (shared/ai3/cerveau.lua,
--- script/team/pile.lua PileRt.porte) : les manques de la pensée (`raw` = E.raw, { [matière] = { n } }) MOINS ceux des projets
--- d'amélioration hors des cadres ouverts (`projects` : projets émis par la pensée, p.goal et p.missing de shared/ai3/projets.lua).
--- Rend { [matière] = n > 0 } (entiers). Pur, clés triées.
function Pi.short_core(raw, projects, focus)
  local own = {}
  for _, p in ipairs(projects or {}) do
    if p.missing and Pi.improving(p.goal, focus) then
      for _, k in ipairs(sorted_keys(p.missing)) do own[k] = (own[k] or 0) + (p.missing[k] or 0) end
    end
  end
  local out = {}
  for _, k in ipairs(sorted_keys(raw)) do
    local v = ((raw[k] and raw[k].n) or 0) - (own[k] or 0)
    if v > Pi.SHORT_EPS then out[k] = math.ceil(v - Pi.SHORT_EPS) end
  end
  return out
end

Pi.REFUS_OUT_MAX = 40 -- refus en attente d'écriture au journal ; au-delà, comptés seulement (st.refus_lost)

--- Note un REFUS de la pile (clé stable : ordre, projet, but) ; une seule fois par clé et par épisode de retenue (st.refus est vidé
--- quand la pile ne retient plus, Pi.update). Rend vrai si le refus est nouveau. Le runtime l'écrit au journal [FO-PILE]
--- (script/team/pile.lua, PileRt.flush) ; aucune décision ne le lit.
function Pi.suspend(st, key, text)
  if not st then return false end
  st.refus = st.refus or {}
  key = tostring(key)
  if st.refus[key] then return false end
  st.refus[key] = true
  st.refus_n = (st.refus_n or 0) + 1
  st.refus_out = st.refus_out or {}
  if #st.refus_out < Pi.REFUS_OUT_MAX then st.refus_out[#st.refus_out + 1] = key .. " : " .. tostring(text)
  else st.refus_lost = (st.refus_lost or 0) + 1 end
  return true
end

--- Signaux d'une pensée du cerveau par besoins (shared/ai3/cerveau.lua) : vue de l'équipe, plan du planificateur permanent,
--- entrées du runtime (inp : repair, plan_reopened ; script/team/pile.lua), situation (s.cap) et contexte (gisements).
function Pi.signals(view, base, inp, s, ctx)
  inp = inp or {}
  local survive = nil
  local em = view.emergency
  local floor = (em and em.floor) or view.recover_floor
  -- Relecture PILE : sous l'effectif de départ, R0 ne retient que si une recrue est POSSIBLE. Plafond global d'agents atteint
  -- (view.recruit_blocked, script/team/team.lua : Registry.count() >= fo-agents-max) : l'effectif ne remontera jamais par
  -- cette voie, et R0 (jamais « bloqué ») aurait gelé l'amélioration pour toute la partie.
  if floor and (view.workers or 0) < floor and not view.recruit_blocked then survive = "effectif"
  elseif view.hq_threat then survive = "qg" end
  local inputs, sources = {}, {}
  for _, p in ipairs(sorted_keys(T.smelter_inputs)) do inputs[p] = T.smelter_inputs[p][1] end
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    if ((s and s.cap or {})[kind] or 0) > 0 or ((view.sites or {})[kind] or 0) > 0 or ((view.pending or {})[kind] or 0) > 0 then
      sources[spec.resource] = true
      sources[spec.product] = true
    end
  end
  for _, k in ipairs(sorted_keys(ctx and ctx.reach)) do sources[k] = true end
  for _, k in ipairs(sorted_keys(ctx and ctx.known)) do sources[k] = true end
  local posts = {}
  for _, d in ipairs((base.defend and base.defend.posts) or {}) do
    posts[#posts + 1] = { id = d.id, have = d.have, want = d.want, why = d.why, raw = d.raw }
  end
  return { survive = survive, repair = inp.repair, plan_reopened = inp.plan_reopened, plan_path = inp.plan_path, posts = posts,
    raw_need = base.raw_need, sources = sources, inputs = inputs,
    production_first = (base.priorite and base.priorite.production_first) or false,
    penurie = view.survie and true or false,
    prep = ctx and ctx.prevu or nil } -- lot PREVISION : sites à préparer (script/ai3/prevision.lua, Prev.pile_rows)
end

--- Ligne du journal [FO-PILE] (lue par script/team/pile.lua ; aucune décision ne la lit).
function Pi.describe(st)
  local parts = {}
  for _, fr in ipairs(st.frames or {}) do
    local s = Pi.RANK_NAME[fr.rank] .. ">" .. fr.key
    if fr.kind == "proteger" or fr.kind == "preparer" then
      s = s .. "(" .. (fr.have or 0) .. "/" .. (fr.want or 0) .. "," .. tostring(fr.why) .. ")"
      if fr.nohold then s = s .. "[sans retenue]" end
    elseif fr.kind == "reparer" and fr.item then s = s .. "(" .. (fr.n or 0) .. ",stock " .. (fr.have or 0) .. ")"
    elseif fr.kind == "produire" and fr.n then s = s .. "=" .. fr.n end
    if not fr.exec then s = s .. "[sans voie]" end
    parts[#parts + 1] = s
  end
  return string.format("sommet %s, ameliorer %s, %d cadre(s) : %s ; depiles %d%s",
    Pi.RANK_NAME[st.top or 3], st.blocked and "PERMIS (bloque)" or (st.hold and "SUSPENDU" or "permis"), #(st.frames or {}),
    #parts > 0 and table.concat(parts, " ; ") or "pile vide", st.closed_n or 0,
    (st.closed and #st.closed > 0) and (" (" .. table.concat(st.closed, ", ") .. ")") or "")
end

return Pi
