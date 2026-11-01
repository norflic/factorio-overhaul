-- Sonde du lot RB-3 (1/11) : ce que le moteur donne des prototypes d'une unite et de son kit (lien kit -> unite, caracteristiques lues).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB23 -- 60 rb-sonde <source>
local function try(f) local ok, v = pcall(f) return ok and v or nil end

return {
  description = "RB-3 : sonde des prototypes d'unite (items_to_place_this, attack_parameters, degats lisibles ?)",
  base = nil,
  check_tick = 30,

  init = function(ctx)
    local up = game.entity_prototypes["fo-robot-player-steam-trotter"]
    local kit = game.item_prototypes["fo-robot-kit-steam-trotter"]
    ctx.check(up ~= nil and kit ~= nil, "unite et kit charges par le jeu")
    if not (up and kit) then return end
    local pr = kit.place_result
    ctx.log("kit.place_result = " .. tostring(pr and pr.name))
    ctx.check(pr ~= nil and pr.name == up.name, "le kit pose l'unite du joueur (place_result)", tostring(pr and pr.name))
    local items = up.items_to_place_this
    ctx.log("items_to_place_this = " .. tostring(items and items[1] and items[1].name) .. " (" .. tostring(items and #items) .. ")")
    ctx.check(items ~= nil and items[1] ~= nil and items[1].name == kit.name, "items_to_place_this de l'unite donne le kit")
    ctx.log(string.format("type=%s max_health=%s speed=%s vision=%s", up.type, tostring(up.max_health), tostring(up.speed), tostring(up.vision_distance)))
    local cb = up.collision_box
    ctx.log(string.format("collision_box = (%s,%s)-(%s,%s)", tostring(cb.left_top.x), tostring(cb.left_top.y), tostring(cb.right_bottom.x), tostring(cb.right_bottom.y)))
    local ap = up.attack_parameters
    ctx.check(ap ~= nil, "attack_parameters lisible")
    if ap then
      ctx.log(string.format("attack: type=%s range=%s min_range=%s cooldown=%s damage_modifier=%s", tostring(ap.type), tostring(ap.range),
        tostring(ap.min_range), tostring(ap.cooldown), tostring(ap.damage_modifier)))
      local at = ap.ammo_type
      ctx.log("ammo_type = " .. tostring(at and at.category) .. " target_type=" .. tostring(at and at.target_type))
      local act = at and at.action
      local d1 = act and act[1]
      ctx.log("action[1].type = " .. tostring(d1 and d1.type) .. " ; delivery = " .. tostring(d1 and d1.action_delivery and d1.action_delivery[1] and d1.action_delivery[1].type))
      local te = d1 and d1.action_delivery and d1.action_delivery[1] and d1.action_delivery[1].target_effects
      for i, e in ipairs(te or {}) do
        local dmg = try(function() return e.damage end)
        ctx.log(string.format("target_effects[%d].type = %s ; damage lisible = %s ; amount = %s", i, tostring(e.type), tostring(dmg ~= nil),
          tostring(dmg and dmg.amount)))
      end
      ctx.check(true, "sonde ecrite (voir le journal)")
    end
    local sp = game.entity_prototypes["spidertron"]
    ctx.log("spidertron : type=" .. tostring(sp and sp.type) .. " max_health=" .. tostring(sp and sp.max_health))
  end,

  tick = function() end,
  finish = function() end,
}
