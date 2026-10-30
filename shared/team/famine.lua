--[[
  Lot FER-MARQUE : la FAMINE ne laisse plus un gisement fermé par le seul passage des vagues. PUR (aucune API Factorio, aucun nom
  d'objet) ; testé hors jeu (tests/fer_marque_test.lua). Toutes les équipes (factions et votre équipe) : la règle ne lit que l'état de
  survie de l'équipe (shared/team/survie.lua) et la carte du danger (shared/ai3/danger.lua).

  Diagnostic (fo-logs/2026-10-30_MATIN/DIAG-FER-EQUIPE.md, verif-guide 0.6.24, graine 1618033988) : votre équipe a eu 0 à 2 plaques
  de fer pendant 47 min. Son seul gisement de fer connu était marqué par des cases MOBILES (D.MOBILE_CAP = 900, -10 % par minute,
  remis à 900 à chaque vague) ; un but au-dessus du seuil (600) donne « wait », et l'escalade exige un but « libre »
  (script/ai3/comportement.lua, goal_free) : le mode survie ne la rouvrait jamais (shared/team/survie.lua, en-tête, « INCHANGÉ »).

  Principe du Directeur Créatif (29/10) : « si on manque cruellement de ressources, l'objectif est justement ces ressources hein, pas
  la défense ... on investit les ressources dans la production de plus de ressources » ; pour la porte « trop dangereux » : les morts
  près de la base ne doivent pas bloquer, les morts sur un trajet lointain gardent la prudence.

  Règle (Fa.goal, puis Fa.decide), jugée par la porte d'une tâche refusée :
    S'APPLIQUE  équipe en mode survie (pénurie durable d'une matière clé ET paralysie : Sv.decide) ; tâche de ressources (Fa.KINDS) ;
                but au-dessus du seuil ; ce danger du but vient SEULEMENT de cases mobiles : aucune menace fixe à portée du but (ver,
                nid, tourelle adverse, meute) et aucune mort de PNJ au but, sauf des morts que la porte juge déjà « au calme »
                (tâche proche du QG, morts toutes anciennes : shared/team/actif.lua, A.calm).
    EFFET       le but est traité comme libre pour l'ESCALADE : après Fa.W refus de suite (Sv.ESCALADE_W), la tâche part, avec une
                escorte s'il y a des soldats libres (2 au moins), sinon seule, risque accepté (réflexes du PNJ gardés) ; le passe-droit
                de 5 min suit (comportement.lua, M.PASS_TICKS). Avant Fa.W refus : attente.
    INCHANGÉ    menace fixe au but -> prudence (attente) ; mort au but hors calme -> prudence ; Sv.DEATHS_WAIT morts sur la route ->
                « morts » (aucune escalade) ; équipe hors survie ou tâche hors Fa.KINDS -> règle d'avant.
  Regard (Fa.clear) : un PNJ d'une équipe en mode survie qui regarde autour de lui sans voir d'ennemi efface les cases mobiles vides de
  son disque de vue (D.forget_mobile) ; les menaces fixes s'oublient comme avant (D.forget_unseen), les morts restent.
  Aucun `pairs`, aucun hasard, aucun temps mesuré.
]]

local Sv = require("shared.team.survie")

local Fa = {}

-- Tâches qui produisent des ressources : celles de la porte assouplie (Sv.GATE_KINDS) + la reconstruction (un avant-poste perdu sur le
-- gisement : « rebuild » vers le gisement de fer est refusé dans le diagnostic, minutes 22 à 48).
Fa.KINDS = { mine = true, extend = true, build = true, service = true, rebuild = true }
Fa.W = Sv.ESCALADE_W      -- refus de suite avant de partir (2 : le 3e refus part)
Fa.ESCORT_MIN = 2         -- soldats libres pour demander une escorte (comme la porte ordinaire : escort_ok = libres >= 2)
Fa.KEEP_LOG = 600         -- ticks : une ligne « prudence gardée » au plus toutes les 10 s par équipe (les décisions de famine : toutes)

local function num(x)
  if type(x) ~= "number" or x ~= x then return 0 end
  return x
end

--- Le but de cette tâche relève-t-il de la famine ? a = { on (mode survie), kind (tâche), parts = D.exact_parts au but, calm (la porte
--- juge déjà sans les morts : tâche proche, morts anciennes), B (seuil) }. Rend vrai et "mobile", ou faux et la raison :
--- "hors-survie", "tache", "libre" (but sous le seuil : rien à faire ici), "nid" (menace fixe au but), "mort" (mort au but hors calme),
--- "vide" (aucune case mobile : le seuil vient d'ailleurs).
function Fa.goal(a)
  if not a.on then return false, "hors-survie" end
  if not Fa.KINDS[a.kind] then return false, "tache" end
  local p = a.parts or {}
  local fixed, deaths, mobile = num(p.fixed), num(p.deaths), num(p.mobile)
  local B = num(a.B)
  local goal = fixed + mobile + (a.calm and 0 or deaths)
  if goal < B then return false, "libre" end
  if fixed > 0 then return false, "nid" end
  if deaths > 0 and not a.calm then return false, "mort" end
  if mobile <= 0 then return false, "vide" end
  return true, "mobile"
end

--- Décision d'une tâche refusée dont le but relève de la famine (Fa.goal vrai). a = { n (refus de suite pour ce but, celui-ci compris),
--- free (soldats libres) }. Rend "wait" (n <= Fa.W), "escort" ou "go" (n > Fa.W), puis la raison.
function Fa.decide(a)
  if num(a.n) <= Fa.W then return "wait", "famine-attente" end
  if num(a.free) >= Fa.ESCORT_MIN then return "escort", "famine" end
  return "go", "famine"
end

--- Le regard efface-t-il les cases mobiles vides ? (mode survie seulement : hors famine, la marque s'éteint par le temps, comme avant)
function Fa.clear(on) return on and true or false end

--- Ligne du journal [FO-FAMINE] d'une décision (texte seul). d = { key, tick, kind, x, y, parts, B, n, decision, why, free }.
function Fa.line(d)
  local p = d.parts or {}
  return string.format("[FO-FAMINE] %s : porte a %.1f min : tache %s vers (%d, %d), but marque par des cases mobiles seulement (mobile %d, fixe %d, morts %d, seuil %d), refus de suite %d/%d -> %s (%s)%s",
    tostring(d.key), num(d.tick) / 3600, tostring(d.kind), math.floor(num(d.x)), math.floor(num(d.y)), num(p.mobile), num(p.fixed), num(p.deaths),
    num(d.B), num(d.n), Fa.W, tostring(d.decision), tostring(d.why),
    d.decision == "escort" and string.format(" : escorte demandee (%d soldat(s) libre(s))", num(d.free))
      or (d.decision == "go" and " : sans escorte, risque accepte" or " : attente"))
end

--- Ligne du journal [FO-FAMINE] d'un but de famine qui GARDE la prudence (nid fixe ou mort au but). d = { key, tick, kind, x, y, parts, B, why }.
function Fa.keep_line(d)
  local p = d.parts or {}
  return string.format("[FO-FAMINE] %s : porte a %.1f min : tache %s vers (%d, %d) en survie, but au-dessus du seuil (mobile %d, fixe %d, morts %d, seuil %d) -> wait (%s : prudence gardee)",
    tostring(d.key), num(d.tick) / 3600, tostring(d.kind), math.floor(num(d.x)), math.floor(num(d.y)), num(p.mobile), num(p.fixed), num(p.deaths),
    num(d.B), d.why == "nid" and "menace fixe au but" or "mort au but hors de la base")
end

return Fa
