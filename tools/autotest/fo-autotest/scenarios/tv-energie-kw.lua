--[[
  Lot TV-ENERGIE, correctif azure (8/11 ; diagnostic : partie neuve 0.6.64, ordres couvrir cuivre et fer refusés « courant insuffisant (aucune
  centrale possible) » de 26 à 48 min avec 15 026 MU d'épargne, centrale de plus demandée à 32 min) : MICRO-BANC en moteur réel (2 500 ticks).
    (a) le texte du refus de courant d'une centrale FINIE dit les kW (règle réelle, moteur, remote fo-capi kw_probe) ;
    (b) un DÉFICIT de kW (kW retenus + épargne qui dort) fait demander la centrale de plus TOUT DE SUITE (3 relevés de 5 s) : une centrale FINIE
        faite de vraies entités (chaudière et machines à vapeur créées par le banc, déclarées par fo-ia1d bench_plant), les kW retenus datés
        (fo-capi bench_kw) ; PA.watch réel les relève au moteur, demande UNE centrale de plus (pas de seconde tant que la première est ouverte) ;
    (c) la répartition des kW par ordre de manque (règle réelle, kw_probe) : le cuivre reçoit son premier lot avant le second du fer.
  Lancement : banc.py --out <archive> --qui TV-ENERGIE -- 2500 tv-energie-kw <source figée>   Journal : [FO-TV-ENERGIE-KW] ; BILAN automatique.
]]

local function count_gen(report, gen)
  local n = 0
  for _, p in ipairs(report and report.projects or {}) do
    if p.gen == gen then n = n + 1 end
  end
  return n
end

return {
  description = "TV-ENERGIE azure : refus de courant qui dit les kW, deficit de kW = centrale de plus tout de suite, repartition des kW",
  base = nil,
  check_tick = 2000,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(-60, -60, 100, 100, "grass-1")
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      chest.insert({ name = "iron-plate", count = 2000 })
      chest.insert({ name = "coal", count = 400 })
    end
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 4 }) == true, "plan directeur active")
    ctx.check(ctx.has("fo-ia1d", "bench_plant") and ctx.has("fo-capi", "bench_kw") and ctx.has("fo-capi", "kw_probe"),
      "interfaces distantes de banc disponibles (bench_plant, bench_kw, kw_probe)")
    local ents = {}
    local function put(name, x, y)
      local pos = s.find_non_colliding_position(name, { x, y }, 12, 1) or { x, y }
      local e = s.create_entity({ name = name, position = pos, force = "player" })
      if e then ents[#ents + 1] = { name = name, x = e.position.x, y = e.position.y } end
    end
    put("boiler", 40, 40)
    put("steam-engine", 40, 52)
    put("steam-engine", 40, 62)
    st.ents = ents
    ctx.check(#ents == 3, "centrale de vraies entites posee (1 chaudiere, 2 machines a vapeur)", #ents)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 60 then
      st.plant_id = ctx.remote("fo-ia1d", "bench_plant", "player", st.ents)
      local r = ctx.remote("fo-ia1d", "report", "player")
      st.steam0 = count_gen(r, "steam")
      ctx.log(string.format("centrale finie declaree (projet %s), %d projet(s) de centrale", tostring(st.plant_id), st.steam0))
      -- (a) (c) : règle réelle
      local p1 = ctx.remote("fo-capi", "kw_probe", 1800, 1721, 90)
      st.why = p1 and p1.why
      local p2 = ctx.remote("fo-capi", "kw_probe", 1800, 100, 90)
      st.allot, st.order = p2 and p2.allot, p2 and p2.order
      ctx.log("refus : " .. tostring(st.why) .. " ; repartition de 1700 kW : fer " .. tostring(st.allot and st.allot.A) .. ", cuivre " .. tostring(st.allot and st.allot.B))
    end
    -- (b) : les kW retenus, datés d'aujourd'hui, renouvelés toutes les 5 s (valables 2 min)
    if e.tick >= 60 and e.tick % 300 == 0 then
      ctx.remote("fo-capi", "bench_kw", "player", 1170, 10912)
    end
    if e.tick == 1500 then
      local r = ctx.remote("fo-ia1d", "report", "player")
      st.steam1 = count_gen(r, "steam")
      ctx.log(string.format("a 1500 ticks : %d projet(s) de centrale (avant : %s)", st.steam1, tostring(st.steam0)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.why == "courant insuffisant : 1721 kW pris sur 1800 kW (reste 79, il en faut 90)",
      "(a) le refus d'une centrale finie dit les kW, plus « aucune centrale possible »", st.why)
    ctx.check(st.allot and st.allot.A == 17 and st.allot.B == 1 and st.order and st.order[1] == "iron-ore",
      "(c) 1700 kW : le cuivre (1 machine voulue) a son premier lot, le fer prend le reste (17)", st.allot and (tostring(st.allot.A) .. "/" .. tostring(st.allot.B)))
    ctx.check(st.plant_id ~= nil and st.steam0 == 1, "(b) une seule centrale (finie) au depart", st.steam0)
    local r = ctx.remote("fo-ia1d", "report", "player")
    local n = count_gen(r, "steam")
    ctx.check(st.steam1 == 2, "(b) le deficit de kW avec epargne fait demander UNE centrale de plus avant 1500 ticks (3 releves, sans attendre la saturation)", st.steam1)
    ctx.check(n == 2, "(b) toujours UNE seule centrale de plus a la fin (une seule en cours par deficit)", n)
  end,
}
