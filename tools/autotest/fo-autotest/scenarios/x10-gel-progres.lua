--[[
  Lot X10-GEL, FAIT MOTEUR pour l'option (ii) du lead (8/11) : écrire `mining_progress` d'une foreuse à l'arrêt (active = false).
    py -3.9 -B tools/autotest/banc.py --qui X10-GEL-F --out <archive> -- 900 x10-gel-progres <source>

  Doc 1.1.91 (doc-html/runtime-api.json, LuaEntity.mining_progress, lecture et écriture) : « a number in range [0,
  mining_target.prototype.mineable_properties.mining_time] ». Le fait à prouver : « aucune fabrication gratuite, et la progression écrite
  est bien reprise ».
  Trois paires de foreuses thermiques identiques (foreuse -> coffre, même minerai, même charbon), posées au même tick, sans aucun lien
  avec le gel (aucun groupe de banc) :
    tick 60  : les 6 foreuses passent active = false ; progression relue (égale dans chaque paire) ; pour la foreuse D de chaque paire,
               écriture mining_progress = p × mining_time, p = 0,10, 0,50, 0,95 ; relue aussitôt ;
    tick 100 : les 6 foreuses repassent active = true ;
    chaque tick : premier minerai déposé au coffre après 100 ;
    tick 880 : bilan : premier dépôt de D au tick attendu (100 + (1 − p) × cycle, ± 2), de la jumelle T au tick attendu depuis sa propre
               progression ; minerais de D = floor(p + 780 / cycle), de T = floor(p_T + 780 / cycle) : aucun minerai de plus que la
               progression écrite n'en donne (pas de fabrication gratuite), la progression écrite est reprise.
]]

local X0, Y0 = 6000, 3000
local PS = { 0.10, 0.50, 0.95 }
local COAL = 10

local function pair_at(s, i, force)
  local out = {}
  for j, tag in ipairs({ "D", "T" }) do
    local px, py = X0 + (i - 1) * 10 + (j - 1) * 5, Y0
    for _, dx in ipairs({ -0.5, 0.5 }) do
      for _, dy in ipairs({ -0.5, 0.5 }) do s.create_entity({ name = "iron-ore", position = { px + dx, py + dy }, amount = 1000 }) end
    end
    local d = s.create_entity({ name = "burner-mining-drill", position = { px, py }, direction = defines.direction.north, force = force })
    local dp = d.drop_position
    local c = s.create_entity({ name = "wooden-chest", position = { math.floor(dp.x) + 0.5, math.floor(dp.y) + 0.5 }, force = force })
    d.insert({ name = "coal", count = COAL })
    out[tag] = { d = d, c = c }
  end
  return out
end

local function ore(c) return c.get_inventory(defines.inventory.chest).get_item_count("iron-ore") end

return {
  description = "X10-GEL fait moteur : mining_progress ecrit sur une foreuse a l'arret",
  check_tick = 880,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local t = e.tick
    if t == 10 then
      ctx.prepare_area(X0 - 10, Y0 - 10, X0 + 40, Y0 + 10, "grass-1")
      if not game.forces["fo-gel-p"] then game.create_force("fo-gel-p") end
      game.forces["fo-gel-p"].set_cease_fire("enemy", true)
      game.forces.enemy.set_cease_fire("fo-gel-p", true)
      st.pairs = {}
      for i = 1, #PS do st.pairs[i] = pair_at(s, i, "fo-gel-p") end
      local mt = game.entity_prototypes["iron-ore"].mineable_properties.mining_time
      local d = st.pairs[1].D.d
      st.mt = mt
      st.cycle = mt / (d.prototype.mining_speed / 60) -- ticks par minerai (vitesse sans bonus)
      ctx.log(string.format("fer : mining_time %.3f ; foreuse : mining_speed %.3f ; cycle %.1f ticks", mt, d.prototype.mining_speed, st.cycle))
    elseif t == 60 then
      st.w = {}
      for i, p in ipairs(PS) do
        local P = st.pairs[i]
        P.D.d.active, P.T.d.active = false, false
        local pd, pt = P.D.d.mining_progress, P.T.d.mining_progress
        local want = p * st.mt
        P.D.d.mining_progress = want
        local back = P.D.d.mining_progress
        st.w[i] = { p0 = pd, pt = pt, want = want, back = back, c0D = ore(P.D.c), c0T = ore(P.T.c) }
        ctx.log(string.format("paire %d : progression avant ecriture D %.4f, T %.4f ; ecrite %.4f, relue %.4f ; coffres %d et %d", i, pd, pt, want, back,
          ore(P.D.c), ore(P.T.c)))
        ctx.check(math.abs(back - want) < 1e-6, "fait : mining_progress ecrit sur une foreuse a l'arret est relu tel quel (p = " .. p .. ")",
          string.format("%.6f / %.6f", back, want))
      end
    elseif t == 100 then
      for i = 1, #PS do st.pairs[i].D.d.active, st.pairs[i].T.d.active = true, true end
    end
    if st.w and t > 100 then
      for i = 1, #PS do
        local P, w = st.pairs[i], st.w[i]
        if not w.firstD and ore(P.D.c) > w.c0D then w.firstD = t end
        if not w.firstT and ore(P.T.c) > w.c0T then w.firstT = t end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local span = 880 - 100
    for i, p in ipairs(PS) do
      local P, w = st.pairs[i], st.w[i]
      local nD, nT = ore(P.D.c) - w.c0D, ore(P.T.c) - w.c0T
      local fD, fT = w.want / st.mt, w.pt / st.mt
      local expD, expT = math.floor(fD + span / st.cycle), math.floor(fT + span / st.cycle)
      local tD, tT = 100 + (1 - fD) * st.cycle, 100 + (1 - fT) * st.cycle
      ctx.log(string.format("paire %d (p = %.2f) : premier depot D au tick %s (attendu %.0f), T au tick %s (attendu %.0f) ; minerais D %d (attendu %d), T %d (attendu %d)",
        i, p, tostring(w.firstD), tD, tostring(w.firstT), tT, nD, expD, nT, expT))
      ctx.check(w.firstD ~= nil and math.abs(w.firstD - tD) <= 2, "fait : la progression ecrite est reprise (premier depot de D au tick attendu, p = " .. p .. ")",
        tostring(w.firstD) .. " / " .. string.format("%.0f", tD))
      ctx.check(nD == expD, "fait : aucune fabrication gratuite (minerais de D = progression ecrite + temps de marche, p = " .. p .. ")", nD .. " / " .. expD)
      ctx.check(nT == expT and w.firstT ~= nil and math.abs(w.firstT - tT) <= 2, "temoin T : depots au rythme de sa propre progression (p = " .. p .. ")",
        nT .. " / " .. expT .. ", premier " .. tostring(w.firstT))
    end
  end,
}
