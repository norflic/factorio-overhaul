-- Scénario greffé du lot RB-1 CHAÎNE (31/10) : UN robot jouable de bout en bout, de l'usine au combat (PLAN.md ROBOTS, §6).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB1 -- 6000 rb-chaine <source>
-- Un Atelier d'automates (3 x 3) garni par DEUX coffres et DEUX bras (un par ingrédient : RB0-2), réglage `fo-war-robots-cap`
-- à 2, un nid à 60 tuiles du ralliement. Chronologie (ticks) :
--     5  réglage maître ÉTEINT ; plafond 2 ; relecture après sauvegarde (critère 10)
--  1300  éteint depuis 1295 : un kit en sortie, aucune unité, aucun point (critère 11) ; puis réglage ALLUMÉ
--  3700  2 kits en moins de 40 s depuis l'allumage (1) ; 2 unités nées près de la machine (2) ; au ralliement (3) ; le 3e kit
--        reste, la machine est arrêtée (4) ; une perte : les points sont rendus tout de suite (8)
--  4300  reprise : le 3e kit est devenu une unité, un 4e attend (5)
--  4320  sélection par zone puis marche-attaque sur le nid par `fo-robots.order` (6)
--  5800  le nid est détruit (7) ; registre cohérent, aucun échec de création (9) ; robot de faction adopté (12)
-- La relecture (10) porte sur un robot et un atelier créés à `init` (création de la carte), relus au chargement par le benchmark.
-- Faction : `war_start` à `init` ; au tick 5000 un robot est posé pour la faction (même chemin que le balayage) et Military.adopt le
-- place dans f.soldiers (12). Journal : [FO-RB-CHAINE].

local X0, Y0 = 1500, 1500
local CHECK = 5800
local T_ON = 1300
local T_RES = 3700
local T_REPRISE = 4300
local T_ORDRE = 4320
local T_FACTION = 5000
local CAP = 2
local KIT = "fo-robot-kit-steam-trotter"
local TROTTE = "steam-trotter"
local NID = { X0 + 60, Y0 + 13 }

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function R(ctx, fn, ...) return ctx.remote("fo-robots", fn, ...) end

--- Entité d'un robot inscrit, par son numéro (relais du mod : le moteur 1.1 n'a pas de recherche par numéro), ou nil.
local function unite(ctx, un)
  local i = un and R(ctx, "unit_info", un)
  return i and { name = i.name, position = { x = i.x, y = i.y }, valid = true } or nil
end

local function kits_en_sortie(w)
  local inv = w.get_output_inventory()
  return inv and inv.get_item_count(KIT) or -1
end

local function poser_atelier(s, force, x, y)
  local w = s.create_entity({ name = "fo-robot-workshop", position = { x, y }, force = force, raise_built = true })
  if w then w.set_recipe("fo-robot-make-" .. TROTTE) end
  return w
end

--- Un coffre et un bras par ingrédient (RB0-2), au nord de l'atelier.
local function garnir(s, w, force, ingredients)
  local pos = w.position
  local n = 0
  for i, ing in ipairs(ingredients) do
    local x = pos.x - 1 + (i - 1) * 2
    local c = s.create_entity({ name = "steel-chest", position = { x, pos.y - 3 }, force = force })
    c.insert({ name = ing[1], count = ing[2] })
    local b = s.create_entity({ name = "fast-inserter", position = { x, pos.y - 2 }, force = force })
    b.pickup_position = { x, pos.y - 3 }
    b.drop_position = { x, pos.y - 1 }
    n = n + 1
  end
  return n
end

return {
  description = "RB-1 : un robot de bout en bout (atelier -> kit -> unite -> ordre -> nid detruit), plafond, perte, reprise, faction",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(X0 - 40, Y0 - 25, X0 + 100, Y0 + 40, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 160, Y0 - 160 }, { X0 + 200, Y0 + 200 } } })) do e.destroy() end
    game.map_settings.enemy_expansion.enabled = false
    ctx.power(X0 + 10, Y0)
    ctx.power(X0 + 40, Y0)

    st.prototypes = game.entity_prototypes["fo-robot-workshop"] ~= nil and game.item_prototypes[KIT] ~= nil
      and game.entity_prototypes["fo-robot-player-" .. TROTTE] ~= nil
    if not st.prototypes then
      ctx.fail("prototypes du lot presents (atelier, kit, unite du joueur)")
      return
    end

    -- guerre d'une faction (critere 12), paisible
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 1, 30, 4)
    ctx.log("guerre (une faction) : " .. tostring(st.war))

    -- la chaine principale : atelier W1 de la force du joueur
    st.w1 = poser_atelier(s, "player", X0 + 0.5, Y0 + 0.5)
    st.garni = st.w1 and garnir(s, st.w1, "player", { { "engine-unit", 60 }, { "steel-plate", 132 } }) or 0
    ctx.log(string.format("atelier %s, %d coffre(s)/bras (le nid sera pose au tick %d)", tostring(st.w1 and st.w1.unit_number), st.garni, T_ORDRE))

    -- le temoin de relecture (critere 10) : une force a part, un atelier avec un ralliement choisi, un robot
    local f0 = game.forces["rb-relu"] or game.create_force("rb-relu")
    -- amie du joueur : sinon les robots du joueur (vision 30) vont attaquer le témoin
    f0.set_friend("player", true)
    game.forces.player.set_friend(f0, true)
    f0.set_cease_fire("player", true)
    game.forces.player.set_cease_fire(f0, true)
    st.w0 = poser_atelier(s, f0, X0 - 29.5, Y0 + 0.5)
    st.rally0 = { x = X0 - 30, y = Y0 + 20 }
    if st.w0 then R(ctx, "set_rally", st.w0.unit_number, st.rally0.x, st.rally0.y) end
    st.r0, st.r0_why = R(ctx, "spawn", "rb-relu", TROTTE, X0 - 30, Y0 + 12)
    local etat = R(ctx, "state", "rb-relu")
    st.used0_init = etat and etat.used or -1
    ctx.log(string.format("temoin de relecture : atelier %s, robot %s, points %s", tostring(st.w0 and st.w0.unit_number),
      tostring(st.r0), tostring(st.used0_init)))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.prototypes then return end
    local t = e.tick
    local s = ctx.surface()

    -- relevé de la position de naissance de chaque unité nouvelle (critère 2) : toutes les 5 ticks
    if t >= T_ON and t <= T_ORDRE and t % 5 == 0 then
      st.vues = st.vues or {}
      local etat = R(ctx, "state", "player")
      for _, un in ipairs(etat and etat.units or {}) do
        if not st.vues[un] then
          local u = unite(ctx, un)
          if u and u.valid then st.vues[un] = { x = u.position.x, y = u.position.y, tick = t } end
        end
      end
    end

    if t == 5 then
      -- réglages : maître éteint, plafond 2 ; relecture (critère 10)
      st.set_off = ctx.call("war_setting", "fo-war-robots", false)
      st.set_cap = ctx.call("war_setting", "fo-war-robots-cap", CAP)
      local etat = R(ctx, "state", "rb-relu")
      local u0 = unite(ctx, st.r0)
      local w = R(ctx, "workshop", st.w0 and st.w0.valid and st.w0.unit_number or -1)
      local ok_ledger = R(ctx, "check")
      st.created0 = etat and etat.stats.created or 0
      ctx.check(st.r0 ~= nil and u0 and u0.valid and u0.name == "fo-robot-player-" .. TROTTE
        and etat and etat.used == st.used0_init and etat.used == 1 and etat.by_id[TROTTE] == 1 and etat.units[1] == st.r0
        and w and w.rally and w.rally.x == st.rally0.x and w.rally.y == st.rally0.y and etat.workshops >= 2 and ok_ledger == true,
        "(10) relu apres sauvegarde : meme robot, memes points, meme atelier et son ralliement",
        string.format("robot %s (cree a init) valide=%s, points %s/%s, atelier ralliement %s, ateliers %s, registre %s",
          tostring(st.r0), tostring(u0 and u0.valid), tostring(etat and etat.used), tostring(st.used0_init),
          w and w.rally and (w.rally.x .. "," .. w.rally.y) or "nil", tostring(etat and etat.workshops), tostring(ok_ledger)))
    end

    if t == T_ON then
      -- (11) éteint : aucune unité, aucun point, un kit attend dans la sortie
      local etat = R(ctx, "state", "player")
      local kits = kits_en_sortie(st.w1)
      ctx.check(etat and etat.enabled == false and #etat.units == 0 and etat.used == 0 and kits == 1
        and st.w1.products_finished == 1 and st.set_off == false,
        "(11) reglage eteint : un kit attend en sortie, aucune unite, aucun point",
        string.format("reglage %s, unites %s, points %s, kits en sortie %d, fabriques %d", tostring(etat and etat.enabled),
          tostring(etat and #etat.units), tostring(etat and etat.used), kits, st.w1.products_finished))
      ctx.call("war_setting", "fo-war-robots", true)
      st.t_on = t
      st.finis_on = st.w1.products_finished
    end

    if t == T_RES then
      local etat = R(ctx, "state", "player")
      local w1 = st.w1
      local kits = kits_en_sortie(w1)
      -- (1) 2 kits au moins en 40 s depuis l'allumage : fabriqués depuis T_ON
      local fabriques = w1.products_finished - (st.finis_on or 0)
      ctx.check(fabriques >= 2 and w1.products_finished >= 3 and (t - T_ON) <= 2400,
        "(1) atelier garni par coffre et bras : au moins 2 kits en 40 s depuis l'allumage",
        string.format("%d kit(s) fabriques depuis l'allumage (%d au total) en %d ticks", fabriques, w1.products_finished, t - T_ON))
      -- (2) deux unités nées près de la machine
      local pres, vues = 0, 0
      for _, un in ipairs(etat.units) do
        local v = st.vues and st.vues[un]
        if v then
          vues = vues + 1
          if dist(v, w1.position) <= 8 then pres = pres + 1 end
        end
      end
      ctx.check(#etat.units == 2 and vues == 2 and pres == 2 and etat.stats.created - st.created0 == 2,
        "(2) kits retires : 2 unites creees pres de la machine", string.format("%d unite(s), vues %d, pres %d, creees %d",
          #etat.units, vues, pres, etat.stats.created - st.created0))
      -- (3) elles marchent au ralliement
      local rally = R(ctx, "workshop", w1.unit_number)
      local cible = { x = w1.position.x, y = w1.position.y + 1.5 + 2 + 9 }
      local arrivees, det = 0, {}
      for _, un in ipairs(etat.units) do
        local u = unite(ctx, un)
        if u and u.valid then
          local d = dist(u.position, cible)
          local v = st.vues and st.vues[un]
          det[#det + 1] = string.format("%d : %.1f (nee en %s a %s, maintenant %.1f,%.1f)", un, d,
            v and string.format("%.1f,%.1f", v.x, v.y) or "?", v and v.tick or "?", u.position.x, u.position.y)
          if d <= 4 then arrivees = arrivees + 1 end
        end
      end
      ctx.check(arrivees == 2 and rally ~= nil and rally.rally == nil, "(3) elles marchent au ralliement (9 tuiles au sud de la sortie)",
        "ralliement " .. string.format("%.1f,%.1f", cible.x, cible.y) .. " ; " .. table.concat(det, " ; "))
      -- (4) plafond à 2 : le 3e kit reste, la machine s'arrête
      local statut = defines.entity_status
      ctx.check(etat.used == CAP and etat.cap == CAP and kits == 1 and (w1.status == statut.full_output or w1.crafting_progress >= 0.99),
        "(4) plafond a 2 : le 3e kit reste en sortie et la machine s'arrete",
        string.format("points %d/%d, kits en sortie %d, statut %s, avancement %.2f", etat.used, etat.cap, kits, tostring(w1.status), w1.crafting_progress))
      st.avant_perte = { units = etat.units, fabriques = w1.products_finished }
      -- (8) une perte rend les points tout de suite : mort d'une unité, relu 2 ticks plus tard
      st.lost0 = etat.stats.lost
      st.victime = etat.units[1]
      R(ctx, "kill", st.victime)
      st.t_mort = t
    end

    if t == T_RES + 2 then
      local etat = R(ctx, "state", "player")
      ctx.check(etat.used == CAP - 1 and #etat.units == 1 and etat.stats.lost - st.lost0 == 1,
        "(8) points rendus a la mort : 2 -> 1 deux ticks apres, effectif et compteur de pertes a jour",
        string.format("points %d, unites %d, pertes %d", etat.used, #etat.units, etat.stats.lost - st.lost0))
    end

    if t == T_REPRISE then
      -- (5) reprise : le 3e kit est devenu une unité, un 4e attend
      local etat = R(ctx, "state", "player")
      local nouveau = false
      for _, un in ipairs(etat.units) do
        local connu = false
        for _, a in ipairs(st.avant_perte.units) do if a == un then connu = true end end
        if not connu then nouveau = true end
      end
      ctx.check(etat.used == CAP and #etat.units == 2 and nouveau and kits_en_sortie(st.w1) == 1 and st.w1.products_finished == st.avant_perte.fabriques + 1,
        "(5) une perte libere : le 3e kit devient une unite, la machine reprend et fabrique un 4e kit",
        string.format("points %d, unites %d (nouvelle %s), kits en sortie %d, fabriques %d (avant %d)", etat.used, #etat.units,
          tostring(nouveau), kits_en_sortie(st.w1), st.w1.products_finished, st.avant_perte.fabriques))
    end

    if t == T_ORDRE then
      -- le nid est posé à 60 tuiles du ralliement, juste avant l'ordre
      st.nid = s.create_entity({ name = "biter-spawner", position = { NID[1], NID[2] }, force = "enemy" })
      -- (6) sélection par zone puis marche-attaque sur le nid
      local cx, cy = st.w1.position.x, st.w1.position.y + 1.5 + 2 + 9
      local r = R(ctx, "order", "player", "attack", NID[1], NID[2], { x0 = cx - 14, y0 = cy - 14, x1 = cx + 14, y1 = cy + 14 }, 24)
      local rien = R(ctx, "order", "player", "attack", NID[1], NID[2], { x0 = cx + 200, y0 = cy + 200, x1 = cx + 210, y1 = cy + 210 }, 24)
      local bad = R(ctx, "order", "player", "danser", NID[1], NID[2], { x0 = cx - 14, y0 = cy - 14, x1 = cx + 14, y1 = cy + 14 }, 24)
      ctx.check(r.selected == 2 and r.ordered == 2 and rien.selected == 0 and rien.ordered == 0 and bad.selected == 2 and bad.ordered == 0,
        "(6) selection par zone puis ordre de marche-attaque ; zone vide : rien ; ordre inconnu : refuse",
        string.format("zone %d/%d, zone vide %d/%d, ordre inconnu %d/%d", r.selected, r.ordered, rien.selected, rien.ordered,
          bad.selected, bad.ordered))
      -- le même appel, mais le réglage maître éteint, ne donne aucun ordre
      st.t_ordre = t
    end

    if t == T_FACTION then
      -- (12) une faction : le robot est un soldat
      local rows = ctx.remote("fo-ia1", "teams") or {}
      local row
      for _, r in ipairs(rows) do if r.key ~= "player" then row = r end end
      local poi = ctx.remote("factorio-overhaul", "points_of_interest")
      local hq
      for _, p in ipairs(poi and poi.factions or {}) do if p.key == (row and row.key) then hq = p.hq end end
      if not (row and hq) then
        ctx.fail("(12) faction : robot adopte comme soldat", "faction ou QG absents (guerre non lancee ?)")
        return
      end
      local avant = row.soldiers
      local un, why = R(ctx, "spawn", row.force, TROTTE, hq.x, hq.y + 16)
      local vue = un and R(ctx, "faction_view", un)
      local rows2 = ctx.remote("fo-ia1", "teams") or {}
      local apres
      for _, r in ipairs(rows2) do if r.key == row.key then apres = r.soldiers end end
      local u = unite(ctx, un)
      st.faction = { force = row.force, un = un, soldiers_avant = avant }
      ctx.check(un ~= nil and u and u.valid and u.name == "fo-robot-" .. row.key .. "-" .. TROTTE and vue and vue.listed and vue.kind == "soldier"
        and apres == avant + 1 and vue.garrison >= 1 and vue.near >= 1,
        "(12) faction : Military.adopt sur l'unite creee, effectif et garnison a jour",
        string.format("unite %s (%s) : %s ; soldats %s -> %s, garnison %s, proche du rassemblement %s (loin %s), nom %s, a %s, QG %s", tostring(un), tostring(why),
          vue and ("inscrite=" .. tostring(vue.listed) .. " genre=" .. tostring(vue.kind)) or "sans vue", tostring(avant), tostring(apres),
          vue and tostring(vue.garrison) or "?", vue and tostring(vue.near) or "?", vue and tostring(vue.far) or "?", u and u.name or "?",
          vue and vue.at and (vue.at.x .. "," .. vue.at.y) or "?", vue and vue.hq and (vue.hq.x .. "," .. vue.hq.y) or "?"))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.prototypes then return end
    local s = ctx.surface()
    -- (7) le nid est détruit
    local nid_mort = not (st.nid and st.nid.valid)
    local etat = R(ctx, "state", "player")
    local vivants = 0
    for _, un in ipairs(etat.units) do
      local u = unite(ctx, un)
      if u and u.valid then vivants = vivants + 1 end
    end
    ctx.check(nid_mort, "(7) le groupe tue un nid pose a 60 tuiles", string.format("nid detruit=%s, robots vivants %d, ordres donnes %d",
      tostring(nid_mort), vivants, etat.stats.ordered))
    -- (9) registre cohérent, aucun échec de création, aucune unité fantôme
    local ok_ledger, raison = R(ctx, "check")
    local valides = true
    for _, un in ipairs(etat.units) do
      local u = unite(ctx, un)
      if not (u and u.valid) then valides = false end
    end
    ctx.check(ok_ledger == true and etat.stats.create_failed == 0 and valides,
      "(9) registre coherent, aucun echec de creation, aucune unite fantome (pas d'erreur du mod : le banc ne s'est pas arrete)",
      string.format("coherent=%s (%s), echecs de creation %d, creees %d, pertes %d, kits retires %d", tostring(ok_ledger), tostring(raison),
        etat.stats.create_failed, etat.stats.created, etat.stats.lost, etat.stats.kits_removed))
    -- bilan chiffré : kits payés contre unités arrivées (risque 4 du plan)
    ctx.log(string.format("kits retires %d, unites creees %d, pertes %d, points %d/%d", etat.stats.kits_removed, etat.stats.created,
      etat.stats.lost, etat.used, etat.cap))
  end,
}
