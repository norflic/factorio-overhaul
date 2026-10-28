--[[
  ADOPTION des machines POSÉES À LA MAIN par le joueur (lot ADOPTE, exigence du DC du 27/10 : « si moi je pose un four, il
  faut que le four soit visible par mes PNJ »). Règles PURES (aucune API Factorio) ; l'exécution est script/team/adopte.lua.

  Avant : aucun bâtiment posé à la main n'entrait dans les registres de l'équipe (f.smelters, ...) : les tournées de fonte
  ne le chargeaient pas, le cerveau ne le comptait pas. Danger de conception : le service d'un four VIDE sa sortie et
  recharge son entrée ; appliqué à un four d'une ligne à tapis du joueur, il lui volerait ses plaques. D'où la règle :

    * seules les machines ISOLÉES sont adoptées (ni bras, ni tapis, ni foreuse à moins de A.CLEAR tuiles) ;
    * dans un rayon de service A.RADIUS du coffre d'équipe ;
    * jamais une machine posée sur une tuile réservée par le plan directeur ;
    * le type est celui d'un registre connu (R.ADOPT, shared/ai3/reglages.lua) et, s'il l'exige, la machine brûle du combustible ;
    * réglage de carte fo-war-adopte pour couper (runtime-global, vrai par défaut).
  Une machine adoptée dont un bras, un tapis ou une foreuse est posé ensuite à côté est RENDUE au joueur (A.releasable).

    A.decide(c)        -> adopter (bool), motif
    A.releasable(c)    -> rendre (bool)
    A.sorted(list)     -> les entrées triées par numéro d'unité (déterminisme des migrations)

  Déterminisme : aucune décision selon l'ordre de pairs, aucune mesure de temps.
]]

local A = {}

A.RADIUS = 40  -- tuiles autour du coffre d'équipe : au-delà, la machine reste au joueur (le service se fait depuis le coffre)
A.CLEAR = 2.5  -- marge (tuiles) autour de la boîte de la machine où un bras, un tapis ou une foreuse la rattache à une ligne

--- c = { on, registry, burner_needed, burner, already, reserved, dist2, radius, linked } ; `linked` : booléen ou fonction (appelée
--- en dernier, seulement si tout le reste est acquis : elle coûte une recherche du moteur).
--- Rend adopter, motif ("ok" ou la première raison du refus : coupe, role, combustible, deja, plan, loin, ligne).
function A.decide(c)
  if not c.on then return false, "coupe" end
  if not c.registry then return false, "role" end
  if c.burner_needed and not c.burner then return false, "combustible" end
  if c.already then return false, "deja" end
  if c.reserved then return false, "plan" end
  local r = c.radius or A.RADIUS
  if (c.dist2 or 0) > r * r then return false, "loin" end
  local l = c.linked
  if type(l) == "function" then l = l() end
  if l then return false, "ligne" end
  return true, "ok"
end

--- Une machine adoptée est rendue au joueur quand une ligne la rejoint ou quand l'adoption est coupée.
function A.releasable(c)
  return (not c.on) or (c.linked and true or false)
end

--- Entrées { unit = n, ... } triées par numéro d'unité (copie).
function A.sorted(list)
  local out = {}
  for _, e in ipairs(list) do out[#out + 1] = e end
  table.sort(out, function(a, b) return a.unit < b.unit end)
  return out
end

A.IDLE_KEEP = 2          -- machines libres gardées au coffre (un avant-poste en prend deux par agrandissement)
A.DEPLOY_PER_THINK = 4   -- machines dormantes posées au plus par fenêtre
A.IDLE_WINDOW = 18000    -- ticks (5 min) : une machine n'est dormante que si elle est restée LIBRE (ni réservée, ni prise) toute la fenêtre

--- Fenêtre d'observation du stock libre (état `w` = { t0, lo } ou nil, tenu par l'appelant). Chaque appel donne le nombre libre ;
--- à la fermeture de la fenêtre (A.IDLE_WINDOW ticks) rend le MINIMUM observé (ce qui est resté libre tout du long) et rouvre la
--- fenêtre ; sinon rend nil. Le kit de départ (8 fours pour les paires des avant-postes) n'est donc jamais posé au QG avant qu'un
--- avant-poste l'ait réclamé ou ait eu 5 min pour le faire. Rend le nouvel état et le minimum (ou nil).
function A.window(w, tick, free)
  if not w then return { t0 = tick, lo = free }, nil end
  if free < w.lo then w.lo = free end
  if tick - w.t0 >= A.IDLE_WINDOW then
    local lo = w.lo
    return { t0 = tick, lo = free }, lo
  end
  return w, nil
end

--- Machines DORMANTES à poser au QG (lot ADOPTE, constat du DC : « votre équipe garde 12-13 fours au coffre à 60 min contre 0
--- chez les factions »). Trace (fo-logs/2026-10-27_ADOPTE/diag-1) : les fours fabriqués pour des avant-postes lointains
--- reviennent au coffre quand le chantier échoue (chemin, avant-poste plein) ; ils y restent. `free` : exemplaires LIBRES au
--- coffre (coffre moins ce que des tâches ont réservé), `placed` : machines du registre, `pending` : machines en commande,
--- `cap` : plafond du registre, `fuel` : combustible libre, `per_fuel` : combustible d'une machine. Rend le nombre à poser.
function A.deploy(free, placed, pending, cap, fuel, per_fuel)
  local n = (free or 0) - A.IDLE_KEEP
  n = math.min(n, (cap or 0) - (placed or 0) - (pending or 0), math.floor((fuel or 0) / math.max(1, per_fuel or 1)), A.DEPLOY_PER_THINK)
  return math.max(0, n)
end

A.HOLD_AFTER = 2           -- agrandissements d'un même avant-poste échoués de suite (danger, chemin) avant la mise en attente
A.HOLD_TICKS = 10 * 3600   -- … pendant 10 min : ni commande d'avance, ni nouvel essai (les objets déjà pris sont revenus au coffre)

--- Un avant-poste dont l'agrandissement vient d'échouer `fails` fois de suite est-il mis en attente ? (lot ADOPTE, cause des fours
--- dormants : 31 agrandissements échoués sur 38 en 60 min, graine 20261020, chacun reprenait puis rendait ses 8 fours et ses
--- foreuses ; le fond fabriquait pour lui).
function A.hold(fails)
  return (fails or 0) >= A.HOLD_AFTER
end

--- Boîte de recherche des voisins d'une machine : sa boîte de collision élargie de A.CLEAR.
function A.search_box(pos, half_w, half_h)
  return { { pos.x - half_w - A.CLEAR, pos.y - half_h - A.CLEAR }, { pos.x + half_w + A.CLEAR, pos.y + half_h + A.CLEAR } }
end

return A
