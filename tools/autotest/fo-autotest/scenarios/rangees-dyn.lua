--[[ Lot RANGEES-ASM (suite, plan accepté le 8/11) : une rangée de câbles FINIE grandit sur place ; sortie sur les deux voies.
  1. coffre de la faction garni (pièces des rangées et de la centrale) ;
  2. ordre de banc (fo-capi, bench_order) chaine copper-cable à 180/min : rangée dynamique (1 machine posée, place de la rangée
     entière réservée, sortie sur deux voies) ;
  3. fantômes de la centrale et de la rangée ravivés par le banc jusqu'à « fini » ; machines de câbles comptées au monde ;
  4. second ordre chaine copper-cable à 360/min : la MÊME rangée (même numéro) rouverte et agrandie sur place ;
  5. ravivée jusqu'à « fini » : plus de machines, même emprise, mêmes quais ; voies du tapis de sortie relevées (hors bilan : il faut du
     courant et du cuivre au quai).
  Journal du mod : [FO-RANGEES-ASM]. Lancement (accord du lead requis, le DC joue) :
    banc.py --out <archive> --qui RANGEES-ASM -- 6000 rangees-dyn <source>
]]
local CHECK = 5900
local EVERY = 120
local ITEM = "copper-cable"
local PARTS = { { "assembling-machine-1", 40 }, { "assembling-machine-2", 20 }, { "fast-inserter", 60 }, { "inserter", 60 },
  { "transport-belt", 400 }, { "small-electric-pole", 100 }, { "medium-electric-pole", 40 }, { "iron-chest", 20 },
  { "copper-plate", 800 }, { "iron-plate", 400 }, { "coal", 300 }, { "offshore-pump", 2 }, { "boiler", 2 }, { "steam-engine", 4 },
  { "pipe", 40 }, { "burner-inserter", 4 } }

local function first_team(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out[1]
end

local function machines(ctx, force)
  local n = 0
  for _, e in ipairs(ctx.surface().find_entities_filtered({ force = force, type = "assembling-machine" })) do
    local r = e.get_recipe()
    if r and r.name == ITEM then n = n + 1 end
  end
  return n
end

local function lanes(ctx, force)
  local l1, l2 = 0, 0
  for _, e in ipairs(ctx.surface().find_entities_filtered({ force = force, type = "transport-belt" })) do
    l1 = l1 + e.get_transport_line(1).get_item_count(ITEM)
    l2 = l2 + e.get_transport_line(2).get_item_count(ITEM)
  end
  return l1, l2
end

return {
  description = "RANGEES-ASM : une rangee de cables finie grandit sur place (meme module, memes quais), sortie sur deux voies",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    for _, s in ipairs({ { "fo-war-ia3e", true }, { "fo-war-capi", true }, { "fo-war-workers", 30 } }) do
      local v = ctx.call("war_setting", s[1], s[2])
      ctx.check(v == s[2], "reglage " .. s[1] .. " = " .. tostring(s[2]), tostring(v))
    end
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible imposee avant la guerre")
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
    st.phase = 0
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 300 then
      local r = first_team(ctx)
      st.key = r and r.key
      local hq = r and ctx.surface().find_entities_filtered({ name = "fo-faction-hq", position = { r.x, r.y }, radius = 12 })[1]
      st.force = hq and hq.valid and hq.force.name or nil
      ctx.check(st.key ~= nil and st.force ~= nil, "faction relevee (" .. tostring(st.key) .. ", force " .. tostring(st.force) .. ")")
      ctx.check(st.key ~= nil and ctx.remote("fo-ind", "stock", st.key, PARTS) ~= nil, "coffre : pieces des rangees et de la centrale")
    end
    if not st.key then return end
    if st.phase == 0 and t > 300 and t % 60 == 0 and ctx.remote("fo-capi", "status", st.key) ~= nil then
      local ids, why = ctx.remote("fo-capi", "bench_order", st.key, "chaine", ITEM, 180)
      st.id = ids and ids[1]
      st.phase = 1
      ctx.log(string.format("ordre 1 chaine %s 180/min -> %s", ITEM, st.id and ("module " .. st.id) or ("refus : " .. tostring(why))))
    end
    if st.id and t % EVERY == 0 and st.phase >= 1 and st.phase ~= 2 then
      local a = ctx.remote("fo-ia3e", "status", st.key)
      if a and a.plant and a.plant_state ~= "fini" then ctx.remote("fo-ind", "revive", st.key, a.plant) end
      ctx.remote("fo-ind", "revive", st.key, st.id)
      local s = ctx.remote("fo-ia1d", "status", st.key, st.id)
      if s and s.state == "fini" then
        local n = machines(ctx, st.force)
        local box = s.parts and s.parts[1]
        if st.phase == 1 then
          st.n1, st.box1, st.q1, st.fini1 = n, box and (box.x .. "," .. box.y .. "," .. box.w .. "x" .. box.h), #(s.quais or {}), t
          ctx.log(string.format("tick %d : rangee %d FINIE, %d machine(s) de %s, emprise %s, %d quai(s)", t, st.id, n, ITEM, tostring(st.box1), st.q1))
          local ids2, why2 = ctx.remote("fo-capi", "bench_order", st.key, "chaine", ITEM, 360)
          st.id2 = ids2 and ids2[1]
          ctx.log(string.format("ordre 2 chaine %s 360/min -> %s", ITEM, st.id2 and ("module " .. st.id2) or ("refus : " .. tostring(why2))))
          st.phase = 3
        elseif st.phase == 3 and n > (st.n1 or 0) then
          st.n2, st.box2, st.q2, st.fini2 = n, box and (box.x .. "," .. box.y .. "," .. box.w .. "x" .. box.h), #(s.quais or {}), t
          ctx.log(string.format("tick %d : rangee %d FINIE de nouveau, %d machine(s), emprise %s, %d quai(s)", t, st.id, n, tostring(st.box2), st.q2))
          st.phase = 4
        end
      end
    end
    if st.phase == 4 and t % 600 == 0 then
      local l1, l2 = lanes(ctx, st.force)
      st.l1, st.l2 = math.max(st.l1 or 0, l1), math.max(st.l2 or 0, l2)
      ctx.log(string.format("tick %d : %s sur les tapis : voie 1 %d, voie 2 %d (hors bilan)", t, ITEM, l1, l2))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.id ~= nil, "ordre 1 : une rangee", tostring(st.id))
    ctx.check(st.fini1 ~= nil and (st.n1 or 0) >= 1, "rangee finie (ravivee par le banc)", tostring(st.n1))
    ctx.check(st.id2 ~= nil and st.id2 == st.id, "ordre 2 : la MEME rangee rouverte, pas un ilot de plus", tostring(st.id) .. " -> " .. tostring(st.id2))
    ctx.check(st.fini2 ~= nil and (st.n2 or 0) > (st.n1 or 0), "rangee agrandie sur place puis finie", tostring(st.n1) .. " -> " .. tostring(st.n2))
    ctx.check(st.box2 ~= nil and st.box2 == st.box1 and st.q2 == st.q1, "meme emprise, memes quais",
      tostring(st.box1) .. " / " .. tostring(st.box2) .. ", quais " .. tostring(st.q1) .. " / " .. tostring(st.q2))
    ctx.log(string.format("voies du tapis de sortie (hors bilan) : voie 1 %s, voie 2 %s", tostring(st.l1), tostring(st.l2)))
  end,
}
