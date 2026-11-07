--[[
  Scénario GREFFÉ « l9-reserve » (lot MINERAI-SONDE, 7/11) : la règle L9 branchée en moteur réel, sans PNJ ni centrale (le plan directeur
  seul, 1 200 ticks). Chaîne : déclencheur (lot évalué, événement) -> décision (seuils par ressource, somme, réservation) -> action
  (marque l.reserved, lots remis à la file) -> effet (état « gisement » : aucune fabrique n'y va).

  Terrain : la zone de -100 à 100 en x et y est vidée et refaite en herbe ; le coffre d'équipe (le QG) est en (0, 0) ; le plan directeur
  est allumé au rayon 3. Le lot (i, j) est le carré de 24 tuiles centré en (28 i, 28 j). Six lots portent des minerais (quantités posées à
  la tuile, `amount`) ; le seuil de 24 tuiles N'EST ATTEINT que par le charbon :
    A (1, 1)   : 10 tuiles d'uranium à 12 000 = 120 000 -> gisement (avant le lot : libre)                          [C4.1]
    B (-1, 1)  : 10 tuiles d'uranium à 9 900 = 99 000 -> libre                                                      [C4.1]
    C (1, -1)  : 20 tuiles de fer à 60 000 = 1 200 000 -> gisement par la SOMME (avant : libre)                     [C4.2]
    D (-1, -1) : 20 tuiles de fer à 45 000 = 900 000 -> libre                                                      [C4.2]
    E (2, 0)   : 30 tuiles de charbon à 100 -> gisement par les tuiles (la règle d'avant, inchangée)
    F (-2, 0)  : 8 tuiles de fer à 50 000 = 400 000 et 3 gisements de pétrole à 300 000 -> libre (le pétrole n'entre pas dans la somme)
  Contrôles : classement de ces six lots ; marques `reserved` (A, C, E seulement) ; relevé refait après un événement (déclenché par le
  banc, remote fo-ia1d.lots_minerai « event » : un banc ne ferme pas de porte) : tous les lots dont le relevé précède l'événement sont
  remis à la file en moins de 2 pensées (130 ticks), refaits au budget d'évaluation du plan, puis plus aucun n'est en retard ; 2 fabriques
  demandées dès l'init : si le plan en rend une, aucune ne se pose sur un lot de gisement ni sur un lot réservé [C4.4 sur cette carte ;
  non prouvé si aucun plan n'aboutit en 1 150 ticks : le contrôle le dit, il ne compte pas]. Elles gardent aussi le plan directeur allumé.
  Journal : [FO-L9-RESERVE] + [FO-LOTS-MINERAI] du mod. Lancement : banc.py ... -- 1200 l9-reserve <source>
  TÉMOIN (l9-reserve-temoin, même terrain, réglage fo-war-lots-minerai ÉTEINT) : le classement d'avant (seuil unique de 24 tuiles) : A, B, C, D et F libres,
  E gisement ; aucune marque `reserved`, aucun événement, aucun relevé refait. Il prouve que le changement vient de la règle.
  Fichier commun : les deux scénarios (l9-reserve.lua, l9-reserve-temoin.lua) l'appellent avec `temoin` faux ou vrai.
]]

local CHECK = 1150
local T_CLASS = 650 -- au plus : tout le treillis doit être relevé (file vide) avant le classement
local T_EVENT = 680
local TAG = "[FO-L9-RESERVE]"
local N_FAB = 2

local function sorted_keys(t)
  local k = {}
  for x in pairs(t or {}) do k[#k + 1] = x end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  return k
end

--- Pose `list` (tuiles entières { x, y }) du minerai `name`, `amount` par tuile.
local function put(s, name, list, amount)
  local n = 0
  for _, t in ipairs(list) do
    if s.create_entity({ name = name, position = { t[1] + 0.5, t[2] + 0.5 }, amount = amount }) then n = n + 1 end
  end
  return n
end

local function block(x0, y0, w, h)
  local out = {}
  for dx = 0, w - 1 do for dy = 0, h - 1 do out[#out + 1] = { x0 + dx, y0 + dy } end end
  return out
end

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 2000 }, { "copper-plate", 600 }, { "coal", 1500 }, { "stone", 200 },
    { "electric-mining-drill", 30 }, { "stone-furnace", 30 }, { "transport-belt", 900 }, { "inserter", 120 },
    { "fast-inserter", 20 }, { "burner-inserter", 10 }, { "medium-electric-pole", 120 }, { "big-electric-pole", 30 },
    { "iron-chest", 20 }, { "assembling-machine-1", 20 }, { "pistol", 10 }, { "firearm-magazine", 200 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

local function lot_of(layout, i, j)
  for _, l in ipairs(layout and layout.lots or {}) do
    if l.i == i and l.j == j then return l end
  end
  return nil
end

--- Les demandes : N_FAB fabriques (elles gardent le plan directeur allumé : sans projet à servir, le cerveau l'éteint et sa mémoire part
--- avec lui ; pas de centrale, qui ferait attendre tous les autres projets). Rend la liste des numéros.
local function demander(ctx)
  local fab = {}
  for _ = 1, N_FAB do
    local id = ctx.remote("fo-ia1d", "request", "player", { gen = "gears", args = { 2, "assembling-machine-1" }, feed = true, prio = 60 })
    if id then fab[#fab + 1] = id end
  end
  return fab
end

local function lots_report(ctx)
  return ctx.remote("fo-ia1d", "lots_minerai", "player", "report")
end

return function(temoin)
return {
  description = temoin and "MINERAI-SONDE, TEMOIN : regle L9 eteinte, le seuil unique d'avant, 1 200 ticks"
    or "MINERAI-SONDE : seuils par ressource, somme, reservation et releve refait (L9 branchee), 1 200 ticks",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    if temoin then
      -- reglage de carte fo-war-lots-minerai (interface war_setting : prefixe fo-war-) eteint avant tout releve
      ctx.check(ctx.call("war_setting", "fo-war-lots-minerai", false) ~= nil, "regle L9 eteinte (temoin)")
    end
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    -- le treillis grandit jusqu'au rayon 5 (+-160 tuiles) : tous ces chunks sont generes d'avance (le plan attend les chunks manquants)
    s.request_to_generate_chunks({ 0, 0 }, 7)
    s.force_generate_chunk_requests()
    ctx.prepare_area(-100, -100, 100, 100, "grass-1")
    st.put = {
      A = put(s, "uranium-ore", block(24, 24, 5, 2), 12000),
      B = put(s, "uranium-ore", block(-32, 24, 5, 2), 9900),
      C = put(s, "iron-ore", block(22, -30, 5, 4), 60000),
      D = put(s, "iron-ore", block(-34, -30, 5, 4), 45000),
      E = put(s, "coal", block(52, -3, 6, 5), 100),
      F = put(s, "iron-ore", block(-62, 6, 4, 2), 50000)
        + put(s, "crude-oil", { { -60, -5 }, { -56, 0 }, { -52, 5 } }, 300000),
    }
    ctx.log(string.format("%s terrain : tuiles posees A %d, B %d, C %d, D %d, E %d, F %d", TAG, st.put.A, st.put.B, st.put.C, st.put.D, st.put.E, st.put.F))
    ctx.check(st.put.A == 10 and st.put.B == 10 and st.put.C == 20 and st.put.D == 20 and st.put.E == 30 and st.put.F == 8 + 3,
      "les six lots de minerai sont poses (10, 10, 20, 20, 30, 11)")
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    stock_chest(chest)
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 3 }) == true, "plan directeur active")
    st.t0 = game.tick
    st.ids = demander(ctx)
    st.reenabled = 0
    ctx.log(string.format("%s %d fabrique(s) demandee(s) des l'init : projets %s", TAG, #st.ids, table.concat(st.ids, ",")))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    -- 0. le cerveau a eteint le plan directeur (rien a servir) : il est rallume, les demandes refaites (les lots sont releves de nouveau)
    if t % 30 == 0 and not ctx.remote("fo-ia1d", "report", "player") then
      ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 3 })
      st.ids = demander(ctx)
      st.reenabled = (st.reenabled or 0) + 1
      ctx.log(string.format("%s plan directeur eteint par le cerveau au tick %d : rallume (%d fois), %d fabrique(s) redemandee(s)", TAG, e.tick, st.reenabled, #st.ids))
      return
    end
    -- 1. classement, une fois la file d'evaluation vide (ou au plus a T_CLASS)
    if not st.class_done and t >= 120 and (t % 20 == 0) then
      local r = ctx.remote("fo-ia1d", "report", "player")
      if r and ((r.queue or 1) == 0 or t >= T_CLASS) then
        st.class_done = t
        local lay = ctx.remote("fo-ia1d", "layout", "player")
        st.class = {}
        for _, want in ipairs({ { "A", 1, 1 }, { "B", -1, 1 }, { "C", 1, -1 }, { "D", -1, -1 }, { "E", 2, 0 }, { "F", -2, 0 } }) do
          local l = lot_of(lay, want[2], want[3])
          st.class[want[1]] = l and (l.state .. (l.reason and (":" .. l.reason) or "")) or "absent"
        end
        local rep = lots_report(ctx)
        st.reserved_at_class = rep and rep.keys or {}
        ctx.log(string.format("%s classement au tick %d (file %s) : A=%s B=%s C=%s D=%s E=%s F=%s ; reserves {%s} ; lots %s", TAG, e.tick, tostring(r.queue),
          st.class.A, st.class.B, st.class.C, st.class.D, st.class.E, st.class.F, table.concat(st.reserved_at_class, " "),
          (function() local o = {} for _, k in ipairs(sorted_keys(r.lots)) do o[#o + 1] = k .. "=" .. r.lots[k] end return table.concat(o, " ") end)()))
      end
    end
    if temoin then return end
    -- 2. l'evenement (un banc ne ferme pas de porte) : tous les releves precedents sont a refaire, puis refaits
    if st.class_done and not st.event_t and t >= T_EVENT then
      local before = lots_report(ctx)
      local ok = ctx.remote("fo-ia1d", "lots_minerai", "player", "event", "banc")
      local after = lots_report(ctx)
      st.event_t, st.event_tick = t, e.tick
      st.stale_at_event = after and after.stale or -1
      st.resurveyed_before = before and before.resurveyed or 0
      ctx.log(string.format("%s evenement au tick %d : accepte=%s, lots au releve en retard %s (avant %s)", TAG, e.tick, tostring(ok), tostring(st.stale_at_event),
        tostring(before and before.stale)))
    end
    if st.event_t and not st.queue_t and t > st.event_t then
      local rep = lots_report(ctx)
      -- tous les lots a refaire sont dans la file d'evaluation (remis par Build.think) : le compteur de lots remis a la file a rattrape le retard
      if rep and rep.resurveyed - st.resurveyed_before >= (st.stale_at_event or 0) then
        st.queue_t = t
        ctx.log(string.format("%s %d lot(s) remis a la file %d ticks apres l'evenement", TAG, rep.resurveyed - st.resurveyed_before, t - st.event_t))
      end
    end
    if st.event_t and not st.refait_t and (t - st.event_t) % 10 == 0 then
      local rep = lots_report(ctx)
      if rep and rep.stale == 0 and (t - st.event_t) > 0 then
        st.refait_t = t
        st.resurveyed = rep.resurveyed
        ctx.log(string.format("%s releve refait au tick %d (+%d ticks) : %d lot(s) remis a la file, plus aucun en retard", TAG, e.tick, t - st.event_t,
          rep.resurveyed - st.resurveyed_before))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local c = st.class or {}
    if temoin then
      -- TEMOIN : la regle eteinte, le classement d'avant (seuil unique de 24 tuiles)
      local rep = lots_report(ctx)
      ctx.check(st.class_done ~= nil, "le treillis est releve avant le classement", st.class_done)
      ctx.check(c.A == "libre" and c.B == "libre", "TEMOIN : 10 tuiles d'uranium (120 000 comme 99 000) : libres, comme avant le lot", tostring(c.A) .. " / " .. tostring(c.B))
      ctx.check(c.C == "libre" and c.D == "libre", "TEMOIN : 20 tuiles de fer (1 200 000 comme 900 000) : libres, comme avant le lot", tostring(c.C) .. " / " .. tostring(c.D))
      ctx.check(c.E == "gisement:coal", "TEMOIN : 30 tuiles de charbon : gisement (le seuil de 24 tuiles d'avant)", c.E)
      ctx.check(c.F == "libre", "TEMOIN : lot F libre", c.F)
      ctx.check(rep ~= nil and rep.on == false and rep.reserved == 0 and rep.events == 0 and rep.resurveyed == 0,
        "TEMOIN : regle eteinte, aucune reservation, aucun evenement, aucun releve refait", rep and (tostring(rep.on) .. "/" .. rep.reserved .. "/" .. rep.events) or "nil")
      ctx.log(string.format("%s TEMOIN classement A=%s B=%s C=%s D=%s E=%s F=%s", TAG, tostring(c.A), tostring(c.B), tostring(c.C), tostring(c.D), tostring(c.E), tostring(c.F)))
      return
    end
    -- C4.1, C4.2 : le classement
    ctx.check(st.class_done ~= nil, "le treillis est releve avant le classement", st.class_done)
    ctx.check(c.A == "gisement:uranium-ore", "C4.1 : 10 tuiles d'uranium a 120 000 : gisement (avant : libre)", c.A)
    ctx.check(c.B == "libre", "C4.1 : 10 tuiles d'uranium a 99 000 : reste libre", c.B)
    ctx.check(c.C == "gisement:iron-ore", "C4.2 : 20 tuiles de fer, plus de 1 000 000 en tout : gisement par la somme", c.C)
    ctx.check(c.D == "libre", "C4.2 : 20 tuiles de fer, 900 000 en tout : libre", c.D)
    ctx.check(c.E == "gisement:coal", "30 tuiles de charbon : gisement par les tuiles (la regle d'avant)", c.E)
    ctx.check(c.F == "libre", "C4.2 : le petrole brut n'entre pas dans la somme (400 000 de fer + 3 x 300 000 de petrole) : libre", c.F)
    -- la réservation : A, C, E seulement
    local rk = {}
    for _, k in ipairs(st.reserved_at_class or {}) do rk[k:match("^([^=]+)")] = k:match("=(.+)$") end
    ctx.check(rk["1:1"] == "uranium-ore" and rk["1:-1"] == "iron-ore" and rk["2:0"] == "coal",
      "les lots A, C et E sont RESERVES au minerai (marque l.reserved) des le classement", table.concat(st.reserved_at_class or {}, " "))
    ctx.check(rk["-1:1"] == nil and rk["-1:-1"] == nil and rk["-2:0"] == nil, "les lots B, D et F ne sont pas reserves")
    -- C4.3 : le relevé est refait
    local rep = lots_report(ctx)
    ctx.check(st.event_t ~= nil and (st.stale_at_event or 0) >= 30, "C4.3 : apres l'evenement, les lots releves avant lui sont a refaire", st.stale_at_event)
    ctx.check(st.queue_t ~= nil and st.queue_t - (st.event_t or 0) <= 130, "C4.3 : tous les lots a refaire sont remis a la file en moins de 2 passes de Build.think (130 ticks)",
      st.queue_t and (st.queue_t - st.event_t) or "jamais")
    ctx.check(st.refait_t ~= nil and st.refait_t - (st.event_t or 0) <= 700, "C4.3 : le releve est refait (au budget d'evaluation du plan) en moins de 700 ticks", st.refait_t and (st.refait_t - st.event_t) or "jamais")
    ctx.check(rep ~= nil and rep.stale == 0 and rep.events == 1, "C4.3 : plus aucun lot en retard, un seul evenement compte", rep and (rep.stale .. "/" .. rep.events) or "nil")
    ctx.check(rep ~= nil and rep.resurveyed >= (st.stale_at_event or 0), "C4.3 : tous les lots en retard ont ete remis a la file", rep and rep.resurveyed or "nil")
    local fin = {}
    for _, k in ipairs(rep and rep.keys or {}) do fin[k:match("^([^=]+)")] = k:match("=(.+)$") end
    ctx.check(fin["1:1"] == "uranium-ore" and fin["1:-1"] == "iron-ore" and fin["2:0"] == "coal" and fin["-1:1"] == nil and fin["-1:-1"] == nil and fin["-2:0"] == nil,
      "la reservation survit au releve refait (A, C, E gardes ; B, D, F toujours libres)", rep and table.concat(rep.keys, " ") or "nil")
    -- C4.4 : aucune fabrique sur un lot de gisement
    local lay = ctx.remote("fo-ia1d", "layout", "player")
    local state_of = {}
    for _, l in ipairs(lay and lay.lots or {}) do state_of[l.i .. ":" .. l.j] = l.state end
    local planned, bad = 0, 0
    for _, id in ipairs(st.ids or {}) do
      local pr = ctx.remote("fo-ia1d", "status", "player", id)
      ctx.log(string.format("%s projet %d : etat %s %s, %d partie(s)", TAG, id, tostring(pr and pr.state), tostring(pr and pr.reason or ""), pr and #(pr.parts or {}) or 0))
      for _, pt in ipairs(pr and pr.parts or {}) do
        if pt.kind == "module" then
          planned = planned + 1
          local lk = tostring(pt.lot)
          if state_of[lk] == "gisement" or rk[lk] then bad = bad + 1 end
          ctx.log(string.format("%s fabrique %d : lot %s (%s)", TAG, id, lk, tostring(state_of[lk])))
        end
      end
    end
    -- Le plan d'une fabrique attend le releve du couloir de ses poteaux (essais de 4 chunks de plus, reason « masques ») : il ne rend pas
    -- toujours sa reponse en 1 150 ticks. Alors le controle est VIDE et le dit : il n'entre ni dans les OK ni dans les ECHEC (la preuve
    -- de C4.4 en jeu est alors la ligne [FO-LOTS-MINERAI] « modules sur un lot de gisement » des bancs longs, protocole de C4.5).
    if planned >= 1 then
      ctx.check(bad == 0, "C4.4 : 0 fabrique sur un lot de gisement ou reserve (" .. bad .. " sur " .. planned .. ")", bad)
    else
      ctx.log(string.format("%s C4.4 NON PROUVE dans ce banc : aucune fabrique planifiee en %d ticks (plans en attente du couloir des poteaux)", TAG, CHECK))
    end
    ctx.log(string.format("%s BILAN DU PLAN : classement A=%s B=%s C=%s D=%s E=%s F=%s ; %d fabrique(s) planifiee(s), %d sur un lot de minerai", TAG,
      tostring(c.A), tostring(c.B), tostring(c.C), tostring(c.D), tostring(c.E), tostring(c.F), planned, bad))
  end,
}
end
