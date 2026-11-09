--[[
  Micro-banc « purete-micro » du lot PURETE-TAPIS (8/11, retour du DC en jouant la 0.6.71 : « des convoyeurs s'injectent sur les lignes d'input
  destinées aux circuits verts ») : le garde-fou de pureté (shared/team/purete.lua, script/team/purete.lua) contre le moteur réel.
  ÉCRIT LE 8/11 PENDANT LE GEL, NON JOUÉ : à lancer par la file (banc.py ... -- 2000 purete-micro <source>) après « fin de gel » seulement.

  Terrain : un champ d'herbe autour de (15, 5). Une SORTIE D'ASSEMBLEUR RÉELLE : coffre (plaques + engrenages) -> bras -> assembleur (recette
  du tapis) -> bras -> tapis B de (13, 6) à (17, 6) vers l'est ; la queue de B verse sur la tuile (18, 6).
  Deux lignes d'ENTRÉE d'un autre objet (circuits électroniques), nourries par le banc à leur première tuile :
    - R1 : colonne x = 18, de (18, 2) à (18, 8), vers le sud : elle passe sur (18, 6), la tuile où B verse (le cas du DC) ;
    - R2 : colonne x = 20, de (20, 2) à (20, 8) : à deux tuiles de la queue de B.
  Contrôles AVANT la pose (monde lu par le garde) : R1 refusée (« etranger_pointe_vers » en (18, 6)), R2 admise, la tuile (18, 6) interdite à l'A*,
  un tracé qui piétine B refusé (« croisement_sans_souterrain »), le même tracé par une paire souterraine admis.
  Puis les deux colonnes sont POSÉES comme le ferait un poseur sans garde, et le banc compte, au tick 1800, les objets étrangers sur chacune :
  R1 en reçoit (le défaut du DC, preuve du mal), R2 aucun.
  Variante « temoin » : la règle est éteinte (remote fo-purete set_enabled false) : R1 est « admise » (le garde ne voit rien), ce qui prouve que le
  refus de la variante principale vient bien de la règle.
  Journal : [FO-PURETE-MICRO(-TEMOIN)] + [FO-PURETE] du mod.
]]

local CIRC = "electronic-circuit"
local BUF = 1e8

local function shape(ctx)
  local s = ctx.surface()
  s.request_to_generate_chunks({ 15, 5 }, 3)
  s.force_generate_chunk_requests()
  for _, e in ipairs(s.find_entities_filtered({ area = { { -20, -30 }, { 60, 40 } }, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -30, 39 do for x = -20, 59 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
end

local function belts(s, x0, y0, x1, y1, dir)
  local n = 0
  local dx = x1 > x0 and 1 or (x1 < x0 and -1 or 0)
  local dy = y1 > y0 and 1 or (y1 < y0 and -1 or 0)
  local x, y = x0, y0
  while true do
    if s.create_entity({ name = "transport-belt", position = { x + 0.5, y + 0.5 }, direction = dir, force = "player" }) then n = n + 1 end
    if x == x1 and y == y1 then break end
    x, y = x + dx, y + dy
  end
  return n
end

--- Tracé { x, y, dir } en colonne vers le sud de y0 à y1.
local function column(x, y0, y1)
  local t = {}
  for y = y0, y1 do t[#t + 1] = { x = x, y = y, dir = defines.direction.south } end
  return t
end

local function foreign_on(s, x, y0, y1)
  local n, mine = 0, 0
  for y = y0, y1 do
    local b = s.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, name = "transport-belt", limit = 1 })[1]
    if b then
      for i = 1, 2 do
        for name, c in pairs(b.get_transport_line(i).get_contents()) do
          if name == CIRC then mine = mine + c else n = n + c end
        end
      end
    end
  end
  return n, mine
end

return function(variant)
  local TAG = "purete-micro" .. (variant == "temoin" and "-temoin" or "")
  local WITH = variant ~= "temoin"
  return {
    description = "PURETE-TAPIS : une sortie d'assembleur contre une ligne d'entree d'un autre objet (" .. variant .. ")",
    base = nil,
    check_tick = 1900,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      shape(ctx)
      ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active")
      -- courant : interface electrique + poteau moyen couvrant l'assembleur et ses deux bras
      st.eei = s.create_entity({ name = "electric-energy-interface", position = { 14, 10 }, force = "player" })
      if st.eei then st.eei.electric_buffer_size = BUF; st.eei.power_production = 0; st.eei.power_usage = 0; st.eei.energy = BUF end
      local pole = s.create_entity({ name = "medium-electric-pole", position = { 10.5, 9.5 }, force = "player" })
      ctx.check(st.eei ~= nil and pole ~= nil, "arene alimentee")
      -- la sortie d'assembleur : coffre -> bras -> assembleur (tapis) -> bras -> tapis B
      local src = s.create_entity({ name = "iron-chest", position = { 7.5, 6.5 }, force = "player" })
      if src then
        src.insert({ name = "iron-plate", count = 400 })
        src.insert({ name = "iron-gear-wheel", count = 400 })
      end
      local arm_in = s.create_entity({ name = "inserter", position = { 8.5, 6.5 }, direction = defines.direction.east, force = "player" })
      local asm = s.create_entity({ name = "assembling-machine-2", position = { 10.5, 6.5 }, force = "player" })
      if asm then asm.set_recipe("transport-belt") end
      local arm_out = s.create_entity({ name = "inserter", position = { 12.5, 6.5 }, direction = defines.direction.east, force = "player" })
      ctx.check(src and arm_in and asm and arm_out, "sortie d'assembleur reelle posee (coffre, bras, assembleur, bras)")
      ctx.check(belts(s, 13, 6, 17, 6, defines.direction.east) == 5, "tapis B de sortie pose (5 tuiles, vers l'est, queue en (17, 6))")

      -- contrôles AVANT la pose des colonnes du banc
      local function check(tiles, targets)
        return ctx.remote("fo-purete", "check", "player", tiles, CIRC, targets or { { 18, 9 } })
      end
      if not WITH then ctx.check(ctx.remote("fo-purete", "set_enabled", false) == false, "regle eteinte (temoin)") end
      local r1 = check(column(18, 2, 8))
      ctx.check(r1 ~= nil, "interface fo-purete joignable")
      if r1 then
        if WITH then
          ctx.check(r1.ok == false and tostring(r1.why):find("etranger_pointe_vers", 1, true) ~= nil,
            "R1 (colonne x = 18, sur la tuile ou B verse) refusee : etranger_pointe_vers", tostring(r1.why))
          ctx.check(tostring(r1.why):find("17, 6", 1, true) ~= nil, "le refus cite le tapis etranger (17, 6), la queue de B", tostring(r1.why))
        else
          ctx.check(r1.ok == true, "temoin : R1 n'est pas refusee (regle eteinte)", tostring(r1.why))
        end
      end
      local r2 = check(column(20, 2, 8))
      ctx.check(r2 ~= nil and r2.ok == true, "R2 (colonne x = 20, a deux tuiles de la queue de B) admise", r2 and tostring(r2.why))
      if WITH then
        ctx.check(ctx.remote("fo-purete", "forbidden", "player", CIRC, 18, 6) == true, "la tuile (18, 6) est interdite a l'A*")
        ctx.check(ctx.remote("fo-purete", "forbidden", "player", CIRC, 18, 5) == false and ctx.remote("fo-purete", "forbidden", "player", CIRC, 19, 6) == false,
          "les tuiles voisines restent libres")
        -- piétiner B : tracé vers le sud par (15, 6), sur le tapis de sortie
        local r3 = check(column(15, 2, 9))
        ctx.check(r3 ~= nil and r3.ok == false and tostring(r3.why):find("croisement_sans_souterrain", 1, true) ~= nil,
          "un trace qui piétine B est refuse : croisement_sans_souterrain", r3 and tostring(r3.why))
        -- la même traversée par une paire souterraine sous B : (15, 4) entrée, (15, 8) sortie
        local ug = { { x = 15, y = 2, dir = 4 }, { x = 15, y = 3, dir = 4 }, { x = 15, y = 4, dir = 4, ug = "input" }, { x = 15, y = 8, dir = 4, ug = "output" },
          { x = 15, y = 9, dir = 4 } }
        local r4 = check(ug, { { 15, 10 } })
        ctx.check(r4 ~= nil and r4.ok == true, "la meme traversee par une paire souterraine est admise", r4 and tostring(r4.why))
      end

      -- pose NAÏVE des deux colonnes (comme un poseur sans garde), nourries en circuits a leur premiere tuile
      ctx.check(belts(s, 18, 2, 18, 8, defines.direction.south) == 7, "R1 posee (7 tuiles)")
      ctx.check(belts(s, 20, 2, 20, 8, defines.direction.south) == 7, "R2 posee (7 tuiles)")
      st.t0 = game.tick
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local s = ctx.surface()
      local t = e.tick - st.t0
      if st.eei and st.eei.valid then st.eei.energy = BUF end
      if t % 20 == 0 and t < 1700 then
        for _, x in ipairs({ 18, 20 }) do
          local b = s.find_entities_filtered({ position = { x + 0.5, 2.5 }, radius = 0.4, name = "transport-belt", limit = 1 })[1]
          if b then
            local l = b.get_transport_line(1)
            if l.can_insert_at_back() then l.insert_at_back({ name = CIRC, count = 1 }) end
          end
        end
      end
      -- sortie d'assembleur : en plus de l'assembleur reel (diagnostic au journal), le banc depose lui-meme des tapis sur la premiere tuile de B (le premier
      -- passage, 21 OK sur 22, a montre un assembleur sans sortie visible : le mal ne doit pas dependre de lui)
      if t % 10 == 0 and t < 1700 then
        local bb = s.find_entities_filtered({ position = { 13.5, 6.5 }, radius = 0.4, name = "transport-belt", limit = 1 })[1]
        if bb then
          for i = 1, 2 do
            local l = bb.get_transport_line(i)
            if l.can_insert_at_back() then l.insert_at_back({ name = "transport-belt", count = 1 }) end
          end
        end
      end
      if t % 300 == 0 then
        local am = s.find_entities_filtered({ position = { 10.5, 6.5 }, radius = 0.5, name = "assembling-machine-2", limit = 1 })[1]
        ctx.log(string.format("[%s] t=%d : assembleur %s, %s fabrication(s) finie(s)", TAG, t, am and am.status and tostring(am.status) or "?", am and tostring(am.products_finished) or "?"))
        local f1, m1 = foreign_on(s, 18, 2, 8)
        local f2, m2 = foreign_on(s, 20, 2, 8)
        ctx.log(string.format("[%s] t=%d : R1 %d circuit(s) %d etranger(s) | R2 %d circuit(s) %d etranger(s)", TAG, t, m1, f1, m2, f2))
      end
    end,

    finish = function(ctx)
      local s = ctx.surface()
      local f1, m1 = foreign_on(s, 18, 2, 8)
      local f2, m2 = foreign_on(s, 20, 2, 8)
      ctx.check(f1 > 0, "preuve du mal : la colonne R1 posee sans garde a recu des objets etrangers du tapis B (" .. f1 .. ")")
      ctx.check(f2 == 0, "R2, a deux tuiles de la queue de B, n'a recu aucun objet etranger (" .. f2 .. ")")
      ctx.check(m2 > 0, "R2 porte bien ses circuits (" .. m2 .. ")")
      local rep = ctx.remote("fo-purete", "report", "player")
      if WITH then
        ctx.check(rep ~= nil and rep.refused >= 2 and rep.why and (rep.why.etranger_pointe_vers or 0) >= 1, "compteurs du garde : refus par cause", rep and tostring(rep.refused))
      else
        ctx.check(rep == nil or rep.refused == 0, "temoin : aucun refus compte", rep and tostring(rep.refused))
      end
      ctx.log(string.format("[%s] BILAN : R1 %d etranger(s) %d circuit(s), R2 %d etranger(s) %d circuit(s)", TAG, f1, m1, f2, m2))
    end,
  }
end
