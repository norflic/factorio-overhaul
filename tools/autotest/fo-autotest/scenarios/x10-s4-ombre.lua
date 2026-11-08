--[[
  Lot X10-S4 (7/11) : registre des génératrices (script/team/generateurs.lua) EN MOTEUR RÉEL, avec une OMBRE. Chaque lecture du
  registre refait l'ancienne recherche sur toute la surface au même instant, compare et écrit une ligne [FO-GENS-OMBRE].
  Les 6 sites d'appel du mod passent par l'interface distante « fo-x10-gens » (appels) : live_networks, net_read, powered_pole,
  raccord_tous, fuel_burn et nearest_network.
  Attendus écrits avant : fo-logs\2026-11-07_X10\S4_CRITERES.md §3 quater.
  Gestes, tous joués en moteur réel :
    - E1 posée SANS événement avant la première lecture ;
    - E2 par raise_built, E3 par fantôme ravivé (raise_revive), un panneau solaire par raise_built ;
    - E4 posée par un vrai robot (on_robot_built_entity) ;
    - deux réseaux de poteaux (A : E1, E3, panneau ; B : E2), joints au tick 1 000 ;
    - E2 tuée au tick 1 400.
  Lancement : banc.py --out <archive> --qui X10 -- 2500 x10-s4-ombre <source> ; journal : [FO-X10-S4-OMBRE], [FO-GENS-OMBRE].
]]

local X0, Y0 = 900, 900
local RY = 200 -- zone des robots, loin des réseaux A et B (le poteau d'alimentation du banc couvre 64 tuiles)
local POLE = "medium-electric-pole"
local READS = { 40, 100, 400, 800, 1200, 1600, 2000, 2300 }
local SITES = { "raccord:live_networks", "reseau_vivant:net_read", "champ:powered_pole", "champ:raccord_tous", "migration_champ:fuel_burn",
  "petrole:nearest_network" }

local function put(s, name, x, y, raise)
  return s.create_entity({ name = name, position = { x, y }, force = "player", raise_built = raise or nil })
end

local function nets_of(list)
  local seen, n = {}, 0
  for _, e in ipairs(list) do
    if e and e.valid and e.electric_network_id and not seen[e.electric_network_id] then
      seen[e.electric_network_id] = true
      n = n + 1
    end
  end
  return n
end

local function has(list, u)
  for _, v in ipairs(list or {}) do if v == u then return true end end
  return false
end

return {
  description = "X10-S4 : registre des génératrices en moteur réel, ombre contre l'ancienne recherche, 6 sites d'appel",
  check_tick = 2400,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local t = e.tick
    if t == 5 then
      ctx.prepare_area(X0 - 8, Y0 - 8, X0 + 56, Y0 + 24, "grass-1")
      ctx.prepare_area(X0, Y0 + RY - 24, X0 + 48, Y0 + RY + 24, "grass-1")
      -- E1 : SANS événement, avant toute lecture (le relevé complet doit la voir)
      st.e1 = put(s, "steam-engine", X0 + 1.5, Y0 + 2.5)
      st.pa = put(s, POLE, X0 + 4.5, Y0 + 2.5)
      st.pb = put(s, POLE, X0 + 43.5, Y0 + 2.5)
      ctx.check(st.e1 ~= nil and st.pa ~= nil and st.pb ~= nil, "E1 et les poteaux A et B poses")
    elseif t == 30 then
      ctx.check(remote.interfaces["fo-x10-gens"] ~= nil, "interface fo-x10-gens du mod presente")
      remote.call("fo-x10-gens", "ombre", true)
    elseif t == 60 then
      st.e2 = put(s, "steam-engine", X0 + 40.5, Y0 + 2.5, true)
      st.e2u = st.e2 and st.e2.unit_number
      local g = s.create_entity({ name = "entity-ghost", inner_name = "steam-engine", position = { X0 + 7.5, Y0 + 2.5 }, force = "player",
        expires = false })
      if g then
        local _, ent = g.revive({ raise_revive = true })
        st.e3 = ent
      end
      st.sol = put(s, "solar-panel", X0 + 4.5, Y0 + 6.5, true)
      -- robots : roboport alimenté par le poteau du banc, coffre de stockage avec la machine, fantôme de E4
      ctx.power(X0 + 24, Y0 + RY + 5, "player")
      st.rport = put(s, "roboport", X0 + 24, Y0 + RY, true)
      if st.rport then st.rport.insert({ name = "construction-robot", count = 10 }) end
      st.store = put(s, "logistic-chest-storage", X0 + 27.5, Y0 + RY + 0.5, true)
      if st.store then st.store.insert({ name = "steam-engine", count = 1 }) end
      st.g4 = s.create_entity({ name = "entity-ghost", inner_name = "steam-engine", position = { X0 + 15.5, Y0 + RY + 0.5 }, force = "player",
        expires = false })
      ctx.check(st.e2 ~= nil and st.e3 ~= nil and st.sol ~= nil and st.rport ~= nil and st.store ~= nil and st.g4 ~= nil,
        "E2 (raise_built), E3 (raise_revive), panneau, roboport, coffre et fantome de E4 poses")
    elseif t == 850 then
      st.nets_avant = nets_of({ st.e1, st.e3, st.sol, st.e2 })
    elseif t == 1000 then
      -- jonction des réseaux A et B : poteaux tous les 8 tuiles, fils posés explicitement
      local prev = st.pa
      for _, x in ipairs({ 12.5, 20.5, 28.5, 36.5 }) do
        local p = put(s, POLE, X0 + x, Y0 + 2.5, true)
        if p and prev then p.connect_neighbour(prev) end
        prev = p
      end
      if prev and st.pb then prev.connect_neighbour(st.pb) end
    elseif t == 1100 then
      st.nets_apres = nets_of({ st.e1, st.e3, st.sol, st.e2 })
    elseif t == 1400 then
      if st.e2 and st.e2.valid then st.e2.die() end
    end
    for _, r in ipairs(READS) do
      if t == r then remote.call("fo-x10-gens", "appels", "player", X0 + 4.5, Y0 + 2.5, POLE) end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local b = remote.call("fo-x10-gens", "bilan", "player")
    local low = {}
    for _, k in ipairs(SITES) do
      if (b.sites[k] or 0) < #READS then low[#low + 1] = k .. "=" .. tostring(b.sites[k] or 0) end
    end
    ctx.check(b.pret == true and b.ombre == true, "registre pret et ombre allumee")
    ctx.check(#low == 0 and b.erreurs == 0, "les 6 sites d'appel lus a chacune des " .. #READS .. " lectures, sans erreur",
      "lectures " .. b.lectures .. ", erreurs " .. b.erreurs .. (#low > 0 and (", trop peu : " .. table.concat(low, " ")) or ""))
    ctx.check(b.lectures >= #SITES * #READS and b.ecarts == 0, "0 ecart registre / ancienne recherche (listes, ordre, reseaux)",
      b.ecarts .. " ecart(s) sur " .. b.lectures .. " lecture(s)")
    local p = b.poses
    ctx.check((p.script_raised_built or 0) >= 2 and (p.script_raised_revive or 0) >= 1 and (p.on_robot_built_entity or 0) >= 1,
      "poses par raise_built, raise_revive et robot", string.format("raise_built %d, raise_revive %d, robot %d, joueur %d",
        p.script_raised_built or 0, p.script_raised_revive or 0, p.on_robot_built_entity or 0, p.on_built_entity or 0))
    local e4 = s.find_entity("steam-engine", { X0 + 15.5, Y0 + RY + 0.5 })
    ctx.check(st.e1 and st.e1.valid and has(b.registre, st.e1.unit_number), "E1 (posee sans evenement, avant toute lecture) au registre")
    ctx.check(e4 ~= nil and has(b.registre, e4.unit_number), "E4 (posee par un robot) au registre")
    ctx.check(st.e2u ~= nil and not has(b.registre, st.e2u), "E2 (tuee) retiree du registre")
    ctx.check((st.nets_avant or 0) >= 2 and (st.nets_apres or 99) < (st.nets_avant or 0), "vrais reseaux : A et B distincts, puis joints",
      "avant " .. tostring(st.nets_avant) .. ", apres " .. tostring(st.nets_apres))
  end,
}
