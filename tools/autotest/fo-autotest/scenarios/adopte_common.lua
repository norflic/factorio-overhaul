--[[
  Lot ADOPTE : machines posées à la main, vues par les PNJ de votre équipe (script/team/adopte.lua). Le joueur de test pose
  (create_entity, force « player ») deux fours isolés à 20 tuiles du coffre d'équipe, puis un four SUR LIGNE (tapis à côté,
  témoin intact), un four hors du rayon et un autre isolé ; chaque pose passe par le gestionnaire de pose du mod
  (interface fo-adopte.built : le moteur interdit à un script de lever on_built_entity, doc de LuaBootstrap.raise_event).
  Le coffre est garni de minerai de fer SANS plaque : le cerveau veut des plaques, ses tournées de fonte servent les fours.
  Mesuré sur les ENTITÉS (combustible, entrée, produits fabriqués), pas sur le registre : « servi » veut dire qu'un PNJ y a
  mis du combustible et du minerai.
  Paramètre ON : réglage fo-war-adopte allumé (le jeu) ou éteint (témoin : le comportement d'avant).
  Lancement : `banc.py ... -- 1600 adopte-manuel <source>` ; témoin : `adopte-manuel-temoin` ; journal : [FO-ADOPTE-MANUEL].
]]
return function(ON)
local TAG = "[FO-ADOPTE-MANUEL] "
local PLACE, LAB, CHECK = 120, 400, 1500

local function put(s, name, x, y)
  local p = s.find_non_colliding_position(name, { x = x, y = y }, 8, 1)
  if not p then return nil end
  return s.create_entity({ name = name, position = p, force = "player" })
end

local function furnace_state(e)
  if not (e and e.valid) then return { valid = false } end
  local fuel = e.get_fuel_inventory().get_item_count()
  local src = e.get_inventory(defines.inventory.furnace_source).get_item_count()
  local out = e.get_inventory(defines.inventory.furnace_result).get_item_count()
  return { valid = true, fuel = fuel, src = src, out = out, made = e.products_finished or 0 }
end

local function served(f) return f.valid and (f.fuel > 0 or f.src > 0 or f.out > 0 or f.made > 0) end

return {
  description = "ADOPTE : fours poses a la main, vus par les PNJ de l'equipe (" .. (ON and "adoption allumee" or "TEMOIN, adoption coupee") .. ")",
  check_tick = CHECK,

  init = function(ctx)
    ctx.call("war_setting", "fo-war-adopte", ON)
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
    local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    if chest then
      -- minerai de fer, pas de plaque : le cerveau veut des plaques et les tournees de fonte les demandent aux fours
      for _, it in ipairs({ { "iron-ore", 300 }, { "copper-plate", 100 }, { "coal", 400 }, { "stone", 100 }, { "pistol", 3 },
        { "firearm-magazine", 60 }, { "burner-mining-drill", 4 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    ctx.state().chest = chest
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local chest = st.chest
    if not (chest and chest.valid) then return end
    local s = ctx.surface()
    local c = chest.position
    if e.tick == PLACE then
      st.api = remote.interfaces["fo-adopte"] ~= nil
      st.f = {
        a = put(s, "stone-furnace", c.x + 20, c.y - 8),
        b = put(s, "stone-furnace", c.x + 20, c.y + 8),
        far = put(s, "stone-furnace", c.x + 90, c.y),
      }
      local line = put(s, "stone-furnace", c.x - 20, c.y + 10)
      if line then
        st.f.line = line
        -- un tapis a cote (a l'est du four) : le four fait partie d'une ligne du joueur
        s.create_entity({ name = "transport-belt", position = { x = line.position.x + 2, y = line.position.y }, force = "player" })
      end
      local n = 0
      for _, k in ipairs({ "a", "b", "far", "line" }) do
        local ent = st.f[k]
        if ent then
          n = n + 1
          if st.api then remote.call("fo-adopte", "built", ent) end
        end
        ctx.log(TAG .. string.format("pose %s : %s", k, ent and string.format("(%.1f, %.1f)", ent.position.x, ent.position.y) or "IMPOSSIBLE"))
      end
      ctx.check(n == 4, "4 fours poses a la main", n)
      ctx.check(not ON or st.api, "interface fo-adopte presente (adoption allumee)")
    end
    -- Laboratoire isole et coffre de stock a cote du coffre d'equipe (l'etat du cerveau existe apres la premiere pensee).
    if e.tick == LAB then
      st.lab = put(s, "lab", c.x - 20, c.y - 16)
      st.annex = put(s, "iron-chest", c.x + 6, c.y + 8)
      for _, k in ipairs({ "lab", "annex" }) do
        if st[k] and st.api then remote.call("fo-adopte", "built", st[k]) end
        ctx.log(TAG .. string.format("pose %s : %s", k, st[k] and string.format("(%.1f, %.1f)", st[k].position.x, st[k].position.y) or "IMPOSSIBLE"))
      end
      ctx.check(st.lab ~= nil and st.annex ~= nil, "laboratoire et coffre poses a la main")
    end
    -- Session avec images : un VRAI joueur existe, il pose le four de sa main (cursor_stack + build_from_cursor) : c'est le
    -- gestionnaire on_built_entity du mod qui est joue, sans l'interface fo-adopte.built.
    if e.tick == PLACE + 30 and #game.connected_players > 0 then
      local pl = game.connected_players[1]
      local want = s.find_non_colliding_position("stone-furnace", { x = c.x + 20, y = c.y + 24 }, 8, 1)
      if want and pl.character then
        pl.teleport({ x = want.x - 3, y = want.y }, s)
        pl.cursor_stack.set_stack({ name = "stone-furnace", count = 1 })
        local ok = pl.can_build_from_cursor({ position = want })
        if ok then pl.build_from_cursor({ position = want }) end
        st.real = { pos = want, ok = ok }
        st.f.real = s.find_entities_filtered({ name = "stone-furnace", position = want, radius = 1.5, limit = 1 })[1]
        ctx.log(TAG .. string.format("VRAI joueur : four pose de la main en (%.1f, %.1f) : %s", want.x, want.y, tostring(st.f.real ~= nil)))
      else
        ctx.log(TAG .. "VRAI joueur : pas de personnage ou pas de place, pose reelle non jouee")
      end
    end
    if e.tick > PLACE and e.tick % 300 == 0 then
      local parts = {}
      for _, k in ipairs({ "a", "b", "line", "far", "real" }) do
        local fs = furnace_state(st.f and st.f[k])
        parts[#parts + 1] = string.format("%s[comb %s src %s sortie %s faits %s]", k, tostring(fs.fuel), tostring(fs.src), tostring(fs.out), tostring(fs.made))
        if served(fs) and not (st.first and st.first[k]) then
          st.first = st.first or {}
          st.first[k] = e.tick
        end
      end
      local stat = st.api and remote.call("fo-adopte", "status") or nil
      ctx.log(TAG .. string.format("tick %d | %s | adoptes %s", e.tick, table.concat(parts, " "), stat and (stat.listed .. "/" .. stat.n) or "-"))
    end
  end,

  -- Images (session avec images) : les fours poses, servis (a, b, real) et le four sur tapis (line) laisse tel quel.
  shots_delay = CHECK + 60,
  shots = function(ctx, add)
    local chest = ctx.state().chest
    if chest and chest.valid then
      add("adopte-fours-est", chest.position.x + 24, chest.position.y + 12, 0.6)
      add("adopte-four-ligne", chest.position.x - 20, chest.position.y + 10, 0.9)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local F = st.f or {}
    local fa, fb, fl, ff = furnace_state(F.a), furnace_state(F.b), furnace_state(F.line), furnace_state(F.far)
    local stat = st.api and remote.call("fo-adopte", "status") or { listed = 0, n = 0 }
    if ON then
      local want_n = 4 + ((st.real and st.f.real) and 1 or 0)
      ctx.check(stat.listed == want_n and stat.n == want_n, want_n .. " fours adoptes exactement (a, b" .. (want_n == 5 and ", real : pose de la main, evenement on_built_entity reel" or "") .. ")", stat.listed .. "/" .. stat.n)
      ctx.check(served(fa) and served(fb), "les 2 fours isolés sont servis par les PNJ (combustible ou minerai ou produits)",
        string.format("a %s/%s/%s/%s b %s/%s/%s/%s", fa.fuel, fa.src, fa.out, fa.made, fb.fuel, fb.src, fb.out, fb.made))
      ctx.check(fa.fuel > 0 and fb.fuel > 0, "combustible mis aux 2 fours", fa.fuel .. " / " .. fb.fuel)
      ctx.check((fa.made + fb.made + fa.out + fb.out + fa.src + fb.src) > 0, "au moins un four a recu du minerai (entree) ou fabrique",
        string.format("faits %d sortie %d entree %d", fa.made + fb.made, fa.out + fb.out, fa.src + fb.src))
    else
      ctx.check(not served(fa) and not served(fb), "TEMOIN : adoption coupee, aucun four isole n'est servi",
        string.format("a %s/%s/%s/%s b %s/%s/%s/%s", fa.fuel, fa.src, fa.out, fa.made, fb.fuel, fb.src, fb.out, fb.made))
    end
    if ON then
      local chest = st.chest
      local counted = false
      for _, a in ipairs(game.surfaces[1].find_entities_filtered({ position = chest.position, radius = 15, name = "iron-chest", force = "player" })) do
        if st.annex and a == st.annex then counted = true end
      end
      ctx.check(st.annex and st.annex.valid and counted, "le coffre pose de la main est toujours la (annexe adoptee, jamais demolie)")
      ctx.check(st.lab and st.lab.valid, "le laboratoire pose de la main est toujours la")
    end
    ctx.check(fl.valid and not served(fl), "four sur tapis : intact, ni combustible, ni entree, ni sortie prise",
      string.format("%s/%s/%s/%s", fl.fuel, fl.src, fl.out, fl.made))
    ctx.check(ff.valid and not served(ff), "four hors du rayon : intact",
      string.format("%s/%s/%s/%s", ff.fuel, ff.src, ff.out, ff.made))
    for _, k in ipairs({ "a", "b", "line", "far", "real" }) do
      if F[k] or k ~= "real" then ctx.check(F[k] and F[k].valid, "four " .. k .. " du joueur toujours la (jamais demoli)") end
    end
  end,
}
end
