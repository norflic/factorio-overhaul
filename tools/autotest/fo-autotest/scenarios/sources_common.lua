--[[
  Lot MINAGE-MAIN (8/11) : micro-banc du registre des coffres de SORTIE et de la tournée « fetch » (retour du DC, 0.6.65 : « ils minent à la
  main du fer alors qu'ils ont des milliers de fer dans les coffres de la fonderie »). Critères ÉCRITS AVANT : fo-logs/2026-11-08_MINAGE-MAIN/CRITERES.md.
  Scène (équipe du joueur, comme collecte-fer) : coffre d'équipe posé, puis, dès qu'elle compte au moins 4 PNJ (ou au tick 1800), à T0 :
    - équipe réduite à 3 PNJ, plaques de fer du coffre retirées (fer libre 0) : les minages de fer viennent d'eux-mêmes ;
    - une SORTIE posée comme le ferait le joueur : coffre S (2 000 plaques de fer) à ~55 tuiles à l'est du QG + un bras qui y dépose (posé APRÈS
      le coffre, événement script_raised_built) ;
    - une ENTRÉE : coffre E (2 000 plaques) à ~55 tuiles à l'ouest + un bras qui en retire (la règle du DC : « un coffre dont un bras retire » n'est
      pas une sortie) ;
    - fenêtre de 3 700 ticks ; relevé toutes les 300 ticks.
  Contrôles (LOT, règle allumée) : K1 le registre compte S et pas E (sorties = 1) ; K2 le fer arrive au QG (>= 300) et S perd au moins 300 plaques ;
  K3 E reste intact (2 000) ; K4 aucun programme de minage de fer n'est laissé passer après T0 + 900 ticks (garde : hand['iron-ore'].ok inchangé) ;
  K5 au moins une tournée « fetch » réussie. TÉMOIN (règle coupée à T0) : mêmes mesures sans contrôle K1 à K5, à lire dans RESULTAT (minages de fer
  faits, fer au QG) : il montre ce que la scène donnait avant le lot.
  Lancement (par la file, quand le lead lève le gel) : banc.py --out <archive> --qui MINAGEMAIN -- 5800 minage-sources <source>
  Journal : [FO-MINAGE-SOURCES] (le mod écrit [FO-SOURCES] et [FO-MAIN]).
]]

local EVERY = 300
local WINDOW = 3700
local T_MAX = 1800
local CHECK = 5600
local HOLD_AFTER = 900
local PLATE, ORE = "iron-plate", "iron-ore"
local CU_PLATE, CU_ORE = "copper-plate", "copper-ore"

local function chest_of(ctx)
  return ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
end

local function plates_at(ctx, pos)
  local c = ctx.surface().find_entity("iron-chest", pos)
  return (c and c.valid) and c.get_inventory(defines.inventory.chest).get_item_count(PLATE) or -1
end

--- Pose un coffre garni et un bras voisin NON orienté (deux temps : la cible d'un bras posé dans le même tick que son coffre n'est lue qu'au tick
--- suivant ; banc 12 h 40 : aucune orientation trouvée au tick de la pose). Rend le coffre et le bras ; orient() les relie ensuite.
local function place_pair(ctx, at, plates)
  local s = ctx.surface()
  local p = s.find_non_colliding_position("iron-chest", at, 20, 1) or at
  local chest = s.create_entity({ name = "iron-chest", position = p, force = "player", raise_built = true })
  if not chest then return nil end
  chest.get_inventory(defines.inventory.chest).insert({ name = PLATE, count = plates })
  local ins
  for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
    local q = { x = chest.position.x + d[1], y = chest.position.y + d[2] }
    if s.can_place_entity({ name = "inserter", position = q, force = "player" }) then
      ins = s.create_entity({ name = "inserter", position = q, force = "player" })
      if ins then break end
    end
  end
  return chest, ins
end

--- Oriente le bras jusqu'à ce que sa cible (dépôt : drop_target ; retrait : pickup_target) soit le coffre, puis l'annonce comme le ferait le joueur.
--- Rend vrai si orienté ; `tried` dit ce qui a été vu pour chaque direction (diagnostic).
local function orient(ins, chest, role)
  if not (ins and ins.valid and chest and chest.valid) then return false, "absent" end
  local tried = {}
  for _, dir in ipairs({ 0, 2, 4, 6 }) do
    ins.direction = dir
    local target = (role == "feed") and ins.drop_target or ins.pickup_target
    tried[#tried + 1] = string.format("%d:%s", dir, target and target.valid and target.name or "-")
    if target and target.valid and target.unit_number == chest.unit_number then
      script.raise_event(defines.events.script_raised_built, { entity = ins })
      return true, table.concat(tried, " ")
    end
  end
  return false, table.concat(tried, " ")
end

return function(rule_on)
  return {
    description = "MINAGE-MAIN : fer libre 0, une SORTIE (bras qui depose) et une ENTREE (bras qui retire) de 2 000 plaques de fer chacune",
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8 a la fondation")
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      chest.get_inventory(defines.inventory.chest).insert({ name = "coal", count = 400 })
      st.hq = { x = chest.position.x, y = chest.position.y }
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.hq or e.tick < 300 then return end
      if not st.t0 then
        if e.tick % 60 ~= 0 then return end
        local row
        for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do if r.key == "player" then row = r end end
        if (row and row.n >= 4) or e.tick >= T_MAX then
          local hq = st.hq
          local b = ctx.remote("fo-ia1", "bench_sources", "player", 3)
          ctx.check(b ~= nil and b.iron == 0, "scene : 3 PNJ, fer libre 0", b and tostring(b.iron) or "nil")
          local hqc = chest_of(ctx)
          if hqc then hqc.get_inventory(defines.inventory.chest).insert({ name = CU_PLATE, count = 5000 }) end -- le stock couvre le cuivre (constat du DC, 8/11)
          if not rule_on then ctx.remote("fo-ia1", "set_regle_sources", "player", false) end
          local S, sins = place_pair(ctx, { x = hq.x + 55, y = hq.y }, 2000)
          local E, eins = place_pair(ctx, { x = hq.x - 55, y = hq.y }, 2000)
          st.S_ent, st.sins, st.E_ent, st.eins = S, sins, E, eins
          st.S, st.E = S and S.position, E and E.position
          st.t0 = e.tick
          st.s0, st.e0 = st.S and plates_at(ctx, st.S) or -1, st.E and plates_at(ctx, st.E) or -1
          ctx.log(string.format("T0=%d : PNJ gardes %s, sortie S (%.0f,%.0f) %d plaques, entree E (%.0f,%.0f) %d plaques, regle %s", e.tick,
            b and tostring(b.kept) or "?", st.S and st.S.x or 0, st.S and st.S.y or 0, st.s0, st.E and st.E.x or 0, st.E and st.E.y or 0, st.e0, tostring(rule_on)))
        end
        return
      end
      local dt = e.tick - st.t0
      if dt >= 5 and not st.oriented then
        st.oriented = true
        local ok1, d1 = orient(st.sins, st.S_ent, "feed")
        local ok2, d2 = orient(st.eins, st.E_ent, "take")
        ctx.check(ok1, "sortie posee : coffre et bras qui depose", d1)
        ctx.check(ok2, "entree posee : coffre et bras qui retire", d2)
      end
      if dt == HOLD_AFTER then
        local s = ctx.remote("fo-ia1", "sources_state", "player")
        st.hand_at = s and s.hand and s.hand[ORE] and s.hand[ORE].ok or 0
        st.mine_at = s and s.mine_ok or 0
        st.hand_cu_at = s and s.hand and s.hand[CU_ORE] and s.hand[CU_ORE].ok or 0
      end
      if dt <= WINDOW and dt % EVERY == 0 then
        local s = ctx.remote("fo-ia1", "sources_state", "player") or {}
        local h = s.hand and s.hand[ORE] or { ok = 0, no = 0 }
        ctx.log(string.format("t0+%d | regle %s | coffres %d, sorties %d | decision fer [%s] | tournees libres %d prises %d, faites %d, vides %d, rapporte %d | minage fer permis %d barre %d | minages ok %d echec %d | fer QG %d | PNJ %d/%d | S %d E %d",
          dt, tostring(s.rule), s.chests or 0, s.sorties or 0, tostring(s.dec and s.dec[ORE]), s.fetch_free or 0, s.fetch_taken or 0, s.trips or 0, s.empty or 0, s.fetched or 0,
          h.ok, h.no, s.mine_ok or 0, s.mine_fail or 0, s.iron or 0, s.engineers or 0, s.floor or 0, plates_at(ctx, st.S), plates_at(ctx, st.E)))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.t0 then
        ctx.check(false, "T0 a eu lieu (equipe fondee, 4 PNJ au moins)", "tick " .. tostring(CHECK))
        return
      end
      local s = ctx.remote("fo-ia1", "sources_state", "player") or {}
      local h = s.hand and s.hand[ORE] or { ok = 0, no = 0 }
      local sp, ep = plates_at(ctx, st.S), plates_at(ctx, st.E)
      ctx.log(string.format("RESULTAT regle=%s sorties=%s fer_QG=%s S=%d->%d E=%d->%d tournees_faites=%s rapporte=%s vides=%s minage_fer_permis=%d barre=%d permis_apres_%d=%s minages_ok=%s echec=%s fetch_ok=%s fetch_fail=%s",
        tostring(s.rule), tostring(s.sorties), tostring(s.iron), st.s0 or -1, sp, st.e0 or -1, ep, tostring(s.trips), tostring(s.fetched), tostring(s.empty),
        h.ok, h.no, HOLD_AFTER, tostring(h.ok - (st.hand_at or 0)), tostring(s.mine_ok), tostring(s.mine_fail), tostring(s.fetch_ok), tostring(s.fetch_fail)))
      if rule_on then
        ctx.check(s.rule == true and (s.sorties or 0) == 1, "K1 : le registre compte la sortie S et pas l'entree E", string.format("regle %s sorties %s", tostring(s.rule), tostring(s.sorties)))
        ctx.check((s.iron or 0) >= 300 and sp <= (st.s0 or 0) - 300, "K2 : le fer arrive au QG, la sortie S s'est videe d'au moins 300",
          string.format("fer %s S %d->%d", tostring(s.iron), st.s0 or -1, sp))
        ctx.check(ep == st.e0 and ep == 2000, "K3 : l'entree E est intacte", string.format("E %d->%d", st.e0 or -1, ep))
        ctx.check(h.ok - (st.hand_at or 0) == 0, "K4 : aucun programme de minage de fer laisse passer apres T0 + " .. HOLD_AFTER, tostring(h.ok - (st.hand_at or 0)))
        local hc = s.hand and s.hand[CU_ORE] or { ok = 0, no = 0 }
        ctx.check(hc.ok - (st.hand_cu_at or 0) == 0, "K6 : aucun programme de minage de cuivre laisse passer (5 000 plaques de cuivre au coffre)", string.format("permis %d barre %d", hc.ok, hc.no))
        ctx.check((s.fetch_ok or 0) >= 1 and (s.trips or 0) >= 1, "K5 : au moins une tournee fetch reussie", string.format("fetch_ok %s tournees %s", tostring(s.fetch_ok), tostring(s.trips)))
      else
        ctx.log("TEMOIN : regle coupee a T0 ; les controles K1 a K5 ne s'appliquent pas, lire RESULTAT")
      end
    end,
  }
end
