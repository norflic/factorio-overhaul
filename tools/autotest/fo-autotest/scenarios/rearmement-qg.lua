--[[
  Lot REARMEMENT, banc court (critère §2 de fo-logs/2026-11-05_REARMEMENT/CRITERES.md) : les armes des PNJ vidées sont-elles rechargées au dépôt
  au QG, pour votre équipe ET pour une faction (parité) ?
    - tick 0 : coffre de votre équipe en (2000, 0) avec 200 chargeurs ; guerre lancée (2 factions, 4 ouvriers chacune) ;
    - tick 600 : le scénario VIDE l'emplacement des munitions de tous les personnages de votre force et de la première faction (lecture au
      moteur : find_entities_filtered type « character », par force ; aucun état du mod n'est touché) ;
    - tick 600 + 4 min : contrôle par force : au moins 3 personnages armés (pistolet) sur 4 ont au moins 10 chargeurs dans l'emplacement.
  Témoin (règle d'avant, T.rearm_on = faux) : les armes restent vides (moteur simulé, tests/rearmement_moteur_test.lua §2). Journal :
  [FO-REARMEMENT-QG] (et [FO-REARMEMENT] du mod).
]]

local AX = 2000
local EMPTY, CHECK = 600, 600 + 4 * 3600
local GUN, AMMO = "pistol", "firearm-magazine"

local function chars_of(force)
  return game.surfaces[1].find_entities_filtered({ type = "character", force = force })
end

local function arms(force)
  local out = { n = 0, gun = 0, full = 0, empty = 0 }
  for _, e in ipairs(chars_of(force)) do
    if e.valid then
      out.n = out.n + 1
      if e.get_inventory(defines.inventory.character_guns).get_item_count(GUN) > 0 then
        out.gun = out.gun + 1
        local c = e.get_inventory(defines.inventory.character_ammo).get_item_count(AMMO)
        if c >= 10 then out.full = out.full + 1 end
        if c == 0 then out.empty = out.empty + 1 end
      end
    end
  end
  return out
end

local function empty_guns(force)
  local n = 0
  for _, e in ipairs(chars_of(force)) do
    if e.valid then
      local inv = e.get_inventory(defines.inventory.character_ammo)
      local c = inv.get_item_count(AMMO)
      if c > 0 then n = n + inv.remove({ name = AMMO, count = c }) end
    end
  end
  return n
end

return {
  description = "REARMEMENT : armes des PNJ videes puis rechargees au depot au QG (votre equipe et une faction)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 60, -150, AX + 200, 150, "grass-1")
    local chest = s.create_entity({ name = "fo-team-chest", position = { AX, 0 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 200 }, { "coal", 200 }, { "stone", 200 }, { GUN, 8 }, { AMMO, 200 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    st.started = ctx.call("war_start", 2, 5, 4)
    ctx.check(st.started == true, "guerre lancee (2 factions, 4 ouvriers chacune)")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == EMPTY then
      -- la première faction : la force « fo-* » qui a des personnages, dans l'ordre des noms
      local names = {}
      for name, _ in pairs(game.forces) do
        if name:sub(1, 3) == "fo-" and #chars_of(name) > 0 then names[#names + 1] = name end
      end
      table.sort(names)
      st.fac = names[1]
      st.removed_p = empty_guns("player")
      st.removed_f = st.fac and empty_guns(st.fac) or 0
      ctx.log(string.format("armes videes au tick %d : votre equipe %d chargeurs, faction %s %d chargeurs", e.tick, st.removed_p,
        tostring(st.fac), st.removed_f))
    elseif e.tick > EMPTY and (e.tick - EMPTY) % 3600 == 0 then
      local p, f = arms("player"), st.fac and arms(st.fac) or { n = 0, gun = 0, full = 0, empty = 0 }
      ctx.log(string.format("minute %.0f apres : votre equipe %d/%d a 10 ou plus (%d vides) ; faction %d/%d (%d vides)", (e.tick - EMPTY) / 3600,
        p.full, p.gun, p.empty, f.full, f.gun, f.empty))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local p, f = arms("player"), st.fac and arms(st.fac) or { n = 0, gun = 0, full = 0, empty = 0 }
    ctx.log(string.format("FAIT : votre equipe %d/%d a 10 ou plus, %d vides ; faction %s %d/%d, %d vides", p.full, p.gun, p.empty,
      tostring(st.fac), f.full, f.gun, f.empty))
    ctx.check((st.removed_p or 0) > 0 and (st.removed_f or 0) > 0, "les armes des deux equipes ont ete videes", (st.removed_p or 0) .. "/" .. (st.removed_f or 0))
    ctx.check(p.gun > 0 and p.full * 4 >= p.gun * 3, "votre equipe : au moins 3 PNJ armes sur 4 a 10 chargeurs ou plus", p.full .. "/" .. p.gun)
    ctx.check(f.gun > 0 and f.full * 4 >= f.gun * 3, "faction : au moins 3 PNJ armes sur 4 a 10 chargeurs ou plus", f.full .. "/" .. f.gun)
  end,
}
