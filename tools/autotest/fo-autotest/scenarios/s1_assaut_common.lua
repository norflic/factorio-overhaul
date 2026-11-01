--[[
  Lot S1 SURVIE (QG qui meurt avec du stock) : un QG dont les tourelles sont VIDES, un coffre qui a assez de chargeurs pour les remplir
  en partie (30 pour 4 tourelles : le tout ou rien d'avant en exigeait 80), deux vagues. Mesure de la 0.6.32 (Écarlate) : fer 0, 7 tourelles
  comptées 4 018 PV sans un chargeur, QG détruit à 79,9 min.
  Déroulé (votre équipe : le QG d'une faction suit la même règle, shared/team/survie_qg.lua) :
    - tick 0 : coffre d'équipe en (2000, 0) avec 120 fer, 200 cuivre, 30 chargeurs, 8 pistolets ; 4 mitrailleuses de QG VIDES ;
    - tick 600 : une vague de 1 500 PV est posée dans la mémoire de l'équipe (remote fo-s1, note_wave : le fait que la calibration
      enregistre quand une vague non prévue passe ; la première version du banc la jouait en vrai, 8 moyens déchiqueteurs détruisaient
      le coffre en 0,7 min tourelles vides, ce qui ne dit rien du péril) puis un relevé immédiat de la prévision ;
    - le QG entre en péril à la pensée suivante (script/team/survie_qg.lua), les tourelles vides sont remplies avec les 30 chargeurs ;
    - tick 6 000 : la vague 2 (30 petits biters, 450 PV) ; tick 9 000 : contrôle.
  Mesures : péril entré (f.team.s1), vagues en mémoire, chargeurs dans les tourelles avant la vague 2, tourelles vivantes, déchiqueteurs tués
  et PNJ perdus à la vague 2. `opts.expect` (vrai : le code du lot) exige l'entrée en péril ET des tourelles chargées avant la vague 2 ;
  le TÉMOIN (code d'avant, même scénario) ne fait que mesurer. Journal : [FO-S1-ASSAUT].
]]

local AX = 2000
local NOTE, WAVE2, OBS_END = 600, 6000, 9000

return function(opts)
return {
  description = opts.description,
  check_tick = OBS_END,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 60, -150, AX + 200, 150, "grass-1")
    local chest = s.create_entity({ name = "fo-team-chest", position = { AX, 0 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      for _, it in ipairs({ { "iron-plate", 120 }, { "copper-plate", 200 }, { "pistol", 8 }, { "firearm-magazine", 30 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    st.turrets = {}
    for _, p in ipairs({ { 8, -8 }, { 8, 8 }, { -8, -8 }, { -8, 8 } }) do
      local tu = s.create_entity({ name = "gun-turret", position = { AX + p[1], p[2] }, force = "player", raise_built = true })
      if tu then
        st.turrets[#st.turrets + 1] = tu
        if remote.interfaces["fo-s1"] then ctx.remote("fo-s1", "own_turret", "player", tu) end
      end
    end
    ctx.check(#st.turrets == 4, "4 mitrailleuses de QG posees (vides)")
  end,

  tick = function(ctx, e)
    local t = e.tick
    local st = ctx.state()
    local s = ctx.surface()
    local function wave(n, label)
      st.biters = st.biters or {}
      local mine = {}
      for j = 1, n do
        local p = s.find_non_colliding_position("small-biter", { x = AX + 75, y = (j - n / 2 - 0.5) * 4 }, 6, 0.5)
        local b = p and s.create_entity({ name = "small-biter", position = p, force = "enemy" })
        if b then
          b.set_command({ type = defines.command.attack_area, destination = { x = AX, y = 0 }, radius = 25, distraction = defines.distraction.by_enemy })
          mine[#mine + 1] = b
        end
      end
      st.biters[label] = mine
      ctx.log(string.format("%s : %d dechiqueteurs", label, #mine))
    end
    if t == NOTE then
      -- (le code d'avant n'a pas l'interface fo-s1 : le témoin n'a ni mémoire des vagues ni péril, la vague 2 vient quand même)
      st.noted = remote.interfaces["fo-s1"] and ctx.remote("fo-s1", "note_wave", "player", "qg", 1500) or false
      ctx.remote("fo-prevision", "relook", "player")
      ctx.log("vague de 1500 PV posee dans la memoire de l'equipe : " .. tostring(st.noted))
    elseif t == WAVE2 - 1 then
      -- Avant la vague 2 : chargeurs dans les tourelles, état du péril, vagues gardées.
      local ammo, alive = 0, 0
      for _, tu in ipairs(st.turrets or {}) do
        if tu.valid then
          alive = alive + 1
          ammo = ammo + tu.get_inventory(defines.inventory.turret_ammo).get_item_count()
        end
      end
      st.ammo_before, st.alive_before = ammo, alive
      local pv = ctx.remote("fo-prevision", "status", "player")
      st.pv_before = pv
      st.start_ids = {}
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do st.start_ids[#st.start_ids + 1] = a.id end
      ctx.log(string.format("avant la vague 2 : %d tourelle(s) vivante(s), %d chargeur(s) en tout, vagues gardees %s, peril %s", alive, ammo,
        tostring(pv and pv.waves and #pv.waves or "?"), tostring(pv and pv.s1 and pv.s1.entries or "?")))
    elseif t == WAVE2 then
      wave(30, "vague2")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local alive_pnj = {}
    for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do alive_pnj[a.id] = true end
    local lost = 0
    for _, id in ipairs(st.start_ids or {}) do if not alive_pnj[id] then lost = lost + 1 end end
    local b2 = (st.biters or {}).vague2 or {}
    local alive_b = 0
    for _, b in ipairs(b2) do if b.valid then alive_b = alive_b + 1 end end
    local tur, ammo = 0, 0
    for _, tu in ipairs(st.turrets or {}) do
      if tu.valid then tur = tur + 1; ammo = ammo + tu.get_inventory(defines.inventory.turret_ammo).get_item_count() end
    end
    local pv = ctx.remote("fo-prevision", "status", "player")
    local peril_n = pv and pv.s1 and pv.s1.entries or 0
    local pvb = st.pv_before
    local entered_before = pvb and pvb.s1 and (pvb.s1.entries or 0) or 0
    ctx.log(string.format("FAIT peril entre %d fois (avant la vague 2 : %d), vagues gardees %d, chargeurs avant la vague 2 %d (tourelles %d), " ..
      "a la fin %d tourelle(s) vivante(s) et %d chargeur(s) ; vague 2 : %d / %d tues ; PNJ au depart de la vague 2 %d, perdus %d",
      peril_n, entered_before, pv and pv.waves and #pv.waves or 0, st.ammo_before or -1, st.alive_before or -1, tur, ammo,
      #b2 - alive_b, #b2, #(st.start_ids or {}), lost))
    ctx.check(#b2 >= 24, "la vague 2 est nee (au moins 24 petits biters)", #b2)
    if opts.expect then
      ctx.check(st.noted == true, "la vague de 1500 PV est entree dans la memoire de l'equipe", tostring(st.noted))
      local reserve = pv and pv.s1 and pv.s1.reserve_said or 0
      ctx.check(reserve >= 30, "la reserve de chargeurs voulue d'apres la vague recue est montee (>= 30 pour 1500 PV)", reserve)
      ctx.check(entered_before >= 1, "le QG est entre en peril avant la vague 2 (s1.entries)", entered_before)
      ctx.check((st.ammo_before or 0) >= 20, "les tourelles du QG ont ete remplies avec le stock incomplet avant la vague 2", st.ammo_before)
      ctx.check(tur >= 3, "au moins 3 des 4 tourelles tiennent la vague 2", tur)
    end
  end,
}
end
