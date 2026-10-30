--[[
  Scénario GREFFÉ « sc-journal » (piste SCENARIOS, 30/10) : le journal d'époque en moteur réel.

  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui amelio-scenarios -- 700 sc-journal <source>
  (contrôle au tick 600). La source doit charger script/scenario/journal.lua (une ligne dans control.lua, proposée à
  l'intégrateur) : sans elle, le premier contrôle échoue (« interface fo-journal absente »).

  1. Un centre de niveau 1 posé par script pour la force « player » (raise_built) : le relevé périodique annonce
     l'époque 1 (aucun joueur dans un banc : seules l'annonce au journal et l'état comptent).
  2. Deux passages du centre par l'interface du mod (levels_upgrade, coût exact L.cost mis dans le coffre) : le
     crochet Levels.on_replaced annonce l'époque 2 puis 3 DANS LE MÊME TICK ; aucun relevé ne rejoue une annonce.
  3 bis. Un nid ennemi tué par la force player (die) : le jalon de défense compte 1.
  3. Une force de faction sans joueur, avec un centre de niveau 5 : jamais suivie.
  4. Objectifs relus par l'interface, sur les prototypes du jeu chargé : la fumerolle (X0, absente) n'est pas
     proposée à l'époque 5, le tungstène l'est ; pétrole à l'époque 4 ; ilménite et saumure à l'époque 11 ; Porte et
     aucun passage de centre à l'époque 15.
  5. Images (banc.py --captures) : le joueur de la session reçoit les fenêtres comme en partie ; captures de la
     fenêtre de l'époque 1 (relevé), de l'époque 3 (crochet), de l'intro et de l'époque 2 relue (interface open).
]]

local LV = require("__factorio-overhaul__/shared/levels/config")
local CC = LV.by_key.command
local X, Y = 260.5, 260.5
local FX, FY = 300.5, 260.5
local FACTION = "fo-sc-faction"

local function player() return game.connected_players[1] end

local function shot(ctx, p, name)
  local st = ctx.state()
  local r = p.display_resolution
  local w, h = math.min(4096, math.max(640, r.width)), math.min(4096, math.max(360, r.height))
  game.take_screenshot({ path = "fo-shots/x-journal-" .. name .. ".png", player = p, show_gui = true,
    position = { X, Y }, zoom = 1, resolution = { w, h }, daytime = 0, force_render = true, allow_in_replay = true })
  st.shots = (st.shots or 0) + 1
  ctx.log(string.format("capture x-journal-%s.png demandee au tick %d (%d x %d)", name, game.tick, w, h))
end

local function fill(cc, n)
  local inv = cc.get_inventory(defines.inventory.chest)
  for _, c in ipairs(LV.cost(CC, n)) do inv.insert({ name = c[1], count = c[2] }) end
end

local function kinds(list)
  local t = {}
  for _, o in ipairs(list or {}) do t[#t + 1] = o.kind .. (o.name and (":" .. o.name) or "") end
  return table.concat(t, ",")
end

return {
  description = "sc-journal : journal d'epoque (annonces, crochet du centre, factions ignorees, objectifs)",
  base = nil,
  check_tick = 600,
  shots_delay = 650,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.has = remote.interfaces["fo-journal"] ~= nil
    ctx.check(st.has, "interface fo-journal disponible (script/scenario/journal.lua charge)")
    if not st.has then return end
    ctx.prepare_area(X - 12, Y - 12, FX + 12, FY + 12, "grass-1")
    local s0 = remote.call("fo-journal", "status", "player")
    ctx.check(s0.born == "init" and s0.reached == 0, "partie neuve : rien d'annonce", s0.born .. " / " .. s0.reached)
    local cc = s.create_entity({ name = LV.name(CC, 1), position = { X, Y }, force = "player", raise_built = true })
    st.cc = cc
    ctx.check(cc ~= nil, "centre de niveau 1 pose pour la force player")
    local f = game.create_force(FACTION)
    local fcc = s.create_entity({ name = LV.name(CC, 5), position = { FX, FY }, force = f, raise_built = true })
    ctx.check(fcc ~= nil, "centre de niveau 5 pose pour une force de faction sans joueur")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.has then return end
    if e.tick == 300 then
      st.at300 = remote.call("fo-journal", "status", "player")
    elseif e.tick == 400 or e.tick == 450 then
      local n = e.tick == 400 and 2 or 3
      local cc = st.cc
      if not (cc and cc.valid) then st["up" .. n] = { ok = false, reason = "centre invalide" }; return end
      fill(cc, n)
      local r = remote.call("factorio-overhaul", "levels_upgrade", cc)
      if r and r.entity and r.entity.valid then st.cc = r.entity end
      local s = remote.call("fo-journal", "status", "player")
      st["up" .. n] = { ok = r and r.ok, reason = r and r.reason, reached = s.reached, announced = s.announced }
    end
    if e.tick == 520 then
      local sp = ctx.surface().create_entity({ name = "biter-spawner", position = { X, Y + 14 }, force = "enemy" })
      st.nest_killed = sp ~= nil and sp.die(game.forces.player) == true
    end
    local p = player()
    if not p then return end
    if e.tick == 330 then shot(ctx, p, "01-epoque-1")
    elseif e.tick == 480 then shot(ctx, p, "02-epoque-3")
    elseif e.tick == 500 then remote.call("fo-journal", "open", p.index, 0)
    elseif e.tick == 530 then shot(ctx, p, "03-intro")
    elseif e.tick == 550 then remote.call("fo-journal", "open", p.index, 2)
    elseif e.tick == 580 then shot(ctx, p, "04-epoque-2-relue")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.has then return end
    local a = st.at300 or {}
    ctx.check(a.reached == 1 and a.announced == 1, "releve periodique : epoque 1 annoncee", (a.reached or "?") .. " / " .. (a.announced or "?"))
    for _, n in ipairs({ 2, 3 }) do
      local u = st["up" .. n] or {}
      ctx.check(u.ok, "passage du centre vers l'epoque " .. n .. " (levels_upgrade)", tostring(u.reason))
      ctx.check(u.reached == n and u.announced == n, "crochet Levels.on_replaced : epoque " .. n .. " annoncee dans le meme tick",
        tostring(u.reached) .. " / " .. tostring(u.announced))
    end
    local s = remote.call("fo-journal", "status", "player")
    ctx.check(s.reached == 3 and s.announced == 3, "aucune annonce rejouee par les releves suivants", s.reached .. " / " .. s.announced)
    local fs = remote.call("fo-journal", "status", FACTION)
    ctx.check(fs.reached == 0, "force de faction sans joueur : jamais suivie", fs.reached)
    local o5 = remote.call("fo-journal", "objectives", 5)
    local k5 = kinds(o5)
    -- La fumerolle est en jeu depuis RESSOURCES (geothermie, 0.6.22) : elle n'est proposee que si son prototype existe.
    local fum = game.entity_prototypes["fo-fumarole"] ~= nil
    ctx.check(k5:find("resource:fo-tungsten-ore", 1, true) and ((k5:find("fo-fumarole", 1, true) ~= nil) == fum),
      "epoque 5 : tungstene propose, fumerolle proposee si et seulement si elle est en jeu (" .. tostring(fum) .. ")", k5)
    ctx.check(o5[1] and o5[1].kind == "centre" and o5[1].target == 6, "epoque 5 : passage du centre vers 6", k5)
    local k4 = kinds(remote.call("fo-journal", "objectives", 4))
    ctx.check(k4:find("resource:crude-oil", 1, true), "epoque 4 : petrole brut", k4)
    local o4 = remote.call("fo-journal", "objectives", 4, "player")
    local r4
    for _, o in ipairs(o4) do if o.kind == "research" then r4 = o end end
    ctx.check(r4 and r4.total and r4.total >= 10 and r4.research_target == math.ceil(0.6 * r4.total),
      "epoque 4 : objectif de recherche sur les technologies du jeu (60 %)", r4 and (r4.research_target .. " / " .. r4.total) or "absent")
    local k11 = kinds(remote.call("fo-journal", "objectives", 11))
    ctx.check(k11:find("resource:fo-ilmenite", 1, true) and k11:find("resource:fo-brine", 1, true), "epoque 11 : ilmenite et saumure", k11)
    local k15 = kinds(remote.call("fo-journal", "objectives", 15))
    ctx.check(k15 == "cap,defense,gate,threat", "epoque 15 : plafond, nids, Porte, menace (aucun passage)", k15)
    ctx.check(st.nest_killed and s.nests == 1, "jalon de defense : un nid tue par la force player compte 1", tostring(st.nest_killed) .. " / " .. tostring(s.nests))
    ctx.log("objectifs 5 : " .. k5 .. " ; 11 : " .. k11)
    if player() then ctx.check((st.shots or 0) == 4, "4 captures de la fenetre demandees", st.shots) end
  end,

  shots = function(ctx, add)
    add("centre-sol", X, Y, 1, 0)
  end,
}
