--[[
  FONDERIE-BLOC (lot FONDERIE-BLOC, retour du DC du 8/11 en jouant la 0.6.66). Règle PURE : aucune API du jeu, aucun nom d'objet, aucun nom de
  minerai ; lue hors jeu (tests/fonderie_bloc_test.lua) et en jeu (script/team/fonderie_bloc.lua).

  Le DC : « une fonderie est bien placée. Cependant, la logique ne va pas jusqu'au bout. Conformément à mes directives de "blocs", ils
  devraient relier le coffre de charbon pour créer un input continu et automatisé [...] Actuellement, ce n'est pas fait. »

  MESURÉ (journal de sa partie, 14 h 30) : le plan du champ ne trouve pas de voie de charbon (« aucune place pour le tronc », « trace du charbon :
  aucun chemin ») et garde le COFFRE DE TÊTE (shared/team/champ.lua, repli 0.6.42, « cadre a coffres : refus coutait 53 % / 100 % »). Ce coffre
  est un quai d'entrée du projet de champ, garni à la main par les tournées « fill » des PNJ. Ni la liaison de quai ni le piquage ne le servent :
    1. son DÉBIT est nul (p.inflow n'existe que pour les modules) : Li.pairs l'écarte, le piquage le classe « ne_se_paie_pas » ;
    2. aucune SOURCE de charbon n'existe à portée (aucun coffre de sortie de charbon, aucun tapis de charbon à moins de 40 tuiles) ;
    3. rien ne DEMANDE de ligne de charbon pour lui (seule la centrale en a une, plan_alim).

  Cette règle couvre le point 3 (le point 1 est corrigé à la source : le coffre de tête porte son débit, `flow`) :
    - Fb.decide : quand un quai de combustible, sans liaison ni piquage, après que le piquage a conclu, demande son ALIMENTATION DE QUAI ;
    - Fb.sites / Fb.arrival / Fb.entities / Fb.verify : la géométrie d'arrivée contre le coffre (un bras qui prend sur le dernier tapis et
      dépose dans le coffre, un poteau contre le bras) ; le tapis et la ligne de foreuses viennent de Build.plan_drills (comme la centrale) ;
    - Fb.pick_names : bras et poteau, lus aux pièces du champ ;
    - Fb.line : le journal [FO-FONDERIE-BLOC].
  Le coffre reste en tampon (le repli PNJ existe déjà : il baisse sous Build.QUAI_LOW et la tournée reprend).

  Déterminisme : listes triées, aucun `pairs` dans une décision, aucune trigonométrie, aucun temps mesuré.
]]

local Li = require("shared.team.liaison")

local Fb = {}

Fb.PERIOD = Li.PERIOD       -- ticks entre deux relevés (30 s)
Fb.CONFIRM = 2              -- relevés de suite où le quai reste sans source avant de demander (le piquage et la liaison jouent d'abord)
Fb.MAX_TRIES = 2            -- projets d'alimentation demandés au plus pour un même quai
Fb.RETRY_AFTER = 20 * 3600  -- ticks : essais épuisés, un essai de plus après 20 min
Fb.RETRY_GAP = 5 * 3600     -- ticks entre deux essais : un plan refusé (pas de gisement, pas de place) ne change pas en 30 s
Fb.MAX_OPEN = 1             -- alimentations de quai ouvertes à la fois par équipe (le plan cherche un gisement : lourd)
Fb.MAX_SITES = 3            -- côtés du coffre essayés au plus par plan (comme les trois arrivées de la centrale)
Fb.MIN_FLOW = Li.MIN_FLOW   -- objets/s : sous ce débit un quai ne vaut aucune ligne
Fb.ENEMY_R = Li.ENEMY_R     -- tuiles : jamais de pose avec un ennemi à cette portée du coffre
Fb.BUSY = 6                 -- quais relevés au plus par passe de Build

-- Causes du piquage (script/team/piquage.lua, mark) après lesquelles une ligne dédiée peut être demandée : le piquage a CONCLU qu'il ne servira pas ce quai.
-- Les autres causes (à confirmer, relevés insuffisants, menace, ennemi, sortie plus rentable) sont des attentes : la liaison ou le piquage agissent.
Fb.READY_CAUSES = { aucune_source = true, ne_se_paie_pas = true, essais_epuises = true, projet_refuse = true }

local DV = Li.DV

---------------------------------------------------------------------------------------------------
-- 1. Décision
---------------------------------------------------------------------------------------------------
--- inp = { flow (objets/s du quai), served (bool : liaison, piquage ou alimentation finie), open (bool : une alimentation de CE quai est en cours),
---   open_total (alimentations ouvertes de l'équipe), pq_cause (cause du piquage pour ce quai, ou nil), seen (relevés de suite sans source),
---   tries, since_try (ticks depuis le dernier essai), threat (QG menacé), enemies (nombre), free (PNJ libres) }.
--- Rend action ("demander" | "attendre" | "laisser"), raison (mots fixes, au journal).
function Fb.decide(inp)
  if inp.served then return "laisser", "deja servi par un tapis" end
  if (inp.flow or 0) < Fb.MIN_FLOW then return "laisser", string.format("debit du quai %.3f/s : rien a economiser", inp.flow or 0) end
  if inp.open then return "attendre", "alimentation deja en cours" end
  if not Fb.READY_CAUSES[inp.pq_cause or ""] then
    return "attendre", string.format("le piquage n'a pas conclu (%s)", tostring(inp.pq_cause or "pas encore juge"))
  end
  if (inp.seen or 0) < Fb.CONFIRM then return "attendre", string.format("a confirmer (%d/%d releves)", inp.seen or 0, Fb.CONFIRM) end
  if inp.threat then return "attendre", "QG menace" end
  if (inp.tries or 0) >= Fb.MAX_TRIES and (inp.since_try or Fb.RETRY_AFTER) < Fb.RETRY_AFTER then
    return "laisser", string.format("%d essai(s) sans effet, prochain dans %.0f min", inp.tries, (Fb.RETRY_AFTER - (inp.since_try or 0)) / 3600)
  end
  if (inp.tries or 0) > 0 and (inp.since_try or Fb.RETRY_AFTER) < Fb.RETRY_GAP then
    return "attendre", string.format("dernier essai il y a %.1f min, prochain dans %.1f min", (inp.since_try or 0) / 3600, (Fb.RETRY_GAP - (inp.since_try or 0)) / 3600)
  end
  if (inp.open_total or 0) >= Fb.MAX_OPEN then return "attendre", "une alimentation de quai est deja ouverte" end
  if (inp.free or 0) < 1 then return "attendre", "aucun PNJ libre" end
  if (inp.enemies or 0) > 0 then return "attendre", "ennemi a portee du coffre" end
  return "demander", "quai sans source (piquage : " .. tostring(inp.pq_cause) .. ")"
end

---------------------------------------------------------------------------------------------------
-- 2. Géométrie d'arrivée
---------------------------------------------------------------------------------------------------
--- Côtés du coffre (tuile tx, ty) où le bras et la dernière tuile de tapis sont libres, avec une tuile de poteau contre le bras, au plus Fb.MAX_SITES.
--- free(x, y) -> bool ; taken[clé] : tuiles déjà prises. Rend { { site = { dir, ax, ay, bx, by }, pole = { tx, ty } } } dans l'ordre N, E, S, O.
function Fb.sites(tx, ty, free0, taken)
  local out = {}
  local function free(x, y) return free0(x, y) and not (taken and taken[x .. ":" .. y]) end
  for _, s in ipairs(Li.sites(tx, ty, free)) do
    if #out >= Fb.MAX_SITES then break end
    local tk = { [s.ax .. ":" .. s.ay] = true, [s.bx .. ":" .. s.by] = true } -- le poteau ne tombe ni sur le bras ni sur le tapis de ce côté
    local px, py = Li.pole_tile(s, free, tk)
    if px then out[#out + 1] = { site = s, pole = { px, py } } end
  end
  return out
end

--- Arrivée du tapis des foreuses (Build.plan_drills) : la tuile derrière le bras, sa direction vers le bras.
function Fb.arrival(site) return { x = site.bx, y = site.by, dir = Li.end_dir(site) } end

--- Entités posées contre le coffre : le bras (il PREND sur la dernière tuile du tapis, direction = vers sa prise, convention de Li.entities) et son poteau.
--- inp = { site, pole = { tx, ty }, names = { arm, pole } }. Centres de tuile (+ 0,5).
function Fb.entities(inp)
  local s = inp.site
  return {
    { name = inp.names.arm, x = s.ax + 0.5, y = s.ay + 0.5, dir = s.dir, role = "liaison-bras" },
    { name = inp.names.pole, x = inp.pole[1] + 0.5, y = inp.pole[2] + 0.5, dir = 0, role = "liaison" },
  }
end

--- Preuve : le bras prend sur la tuile d'arrivée et dépose dans le coffre D, et la dernière tuile du tapis mène au bras. ents = Fb.entities ;
--- arr = Fb.arrival ; D = { x, y } (tuile du coffre). Rend la liste des écarts (vide : juste).
function Fb.verify(ents, arr, D)
  local bad = {}
  local arm
  for _, e in ipairs(ents) do if e.role == "liaison-bras" then arm = e end end
  if not arm then return { "aucun bras" } end
  local tx, ty = math.floor(arm.x), math.floor(arm.y)
  local v = DV[arm.dir]
  if not v then return { "direction du bras inconnue" } end
  if tx + v[1] ~= arr.x or ty + v[2] ~= arr.y then bad[#bad + 1] = "le bras ne prend pas sur la tuile d'arrivee" end
  if tx - v[1] ~= D.x or ty - v[2] ~= D.y then bad[#bad + 1] = "le bras ne depose pas dans le coffre" end
  local w = DV[arr.dir]
  if not w then bad[#bad + 1] = "direction d'arrivee inconnue"
  elseif arr.x + w[1] ~= tx or arr.y + w[2] ~= ty then bad[#bad + 1] = "la derniere tuile du tapis ne mene pas au bras" end
  return bad
end

---------------------------------------------------------------------------------------------------
-- 3. Pièces
---------------------------------------------------------------------------------------------------
--- Bras et poteau d'un projet de champ : ents = { { name, role } }, info(name) -> { reach, burner, rate, w, h, wire } ou nil, is_pole(name) -> bool.
--- Bras : électrique, de portée 1, le plus lent (comme Liaison) parmi les bras du champ (rôle champ-bras) ; poteau 1 x 1 de plus long fil.
--- Rend arm, pole (nil quand le champ n'en porte pas).
function Fb.pick_names(ents, info, is_pole)
  local arm, rate, pole, wire
  for _, e in ipairs(ents) do
    local s = info(e.name)
    if s and e.role == "champ-bras" and not s.burner and s.reach == 1 then
      if not rate or s.rate < rate or (s.rate == rate and e.name < arm) then arm, rate = e.name, s.rate end
    elseif s and is_pole(e.name) and s.w == 1 and s.h == 1 then
      if not wire or s.wire > wire or (s.wire == wire and e.name < pole) then pole, wire = e.name, s.wire end
    end
  end
  return arm, pole
end

---------------------------------------------------------------------------------------------------
-- 4. Journal
---------------------------------------------------------------------------------------------------
--- Une ligne [FO-FONDERIE-BLOC] : quai (clé, objet, débit), verdict, cause.
function Fb.line(team, dock, verdict, why, minutes)
  return string.format("[FO-FONDERIE-BLOC] %s : quai %s (%s, %.2f/s) : %s : %s a %.1f min", team or "player", tostring(dock.key), tostring(dock.item),
    dock.flow or 0, verdict, why, minutes or 0)
end

return Fb
