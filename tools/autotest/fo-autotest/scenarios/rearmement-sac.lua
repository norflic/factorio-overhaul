--[[
  Lot REARMEMENT (5/11), MESURE d'un fait moteur (aucune règle du mod n'est jugée) : un personnage SANS joueur, pistolet en main, peut-il tirer
  avec les chargeurs de son SAC (inventaire principal) quand son emplacement de munitions est vide, ou quand il vient de le vider ?
  Pourquoi : dans le mod, seul le recrutement remplit l'emplacement (script/team/worker.lua, Worker.recruit, 10 chargeurs) ; `take` écrit dans le
  sac et `deposit_all` le vide au coffre ; l'autodéfense (`defend`) compte les chargeurs de TOUS les inventaires, la porte et la place de marché
  ceux de l'emplacement seul. Le fait dit laquelle des deux lectures est juste.
  Trois personnages (force du joueur, indestructibles), chacun face à un gros biter GELÉ (active = faux : il ne bouge ni ne mord), à 8 tuiles :
    A : emplacement VIDE, 20 chargeurs dans le sac ;
    B : 10 chargeurs dans l'emplacement, 20 dans le sac (se recharge-t-il quand l'emplacement se vide ?) ;
    C : 10 dans l'emplacement, sac vide (témoin : tire 10 chargeurs puis s'arrête).
  Tir forcé toutes les 60 ticks (shooting_state = shooting_enemies, comme defend). Relevé toutes les 300 ticks : emplacement, sac, PV du biter.
  Journal : [FO-REARMEMENT-SAC] ; ligne FAIT par personnage à la fin. Aucun contrôle sur la réponse (c'est la mesure) ; 3 000 ticks.
]]

local AX = 3000
local GUN, AMMO = "pistol", "firearm-magazine"
local CASES = {
  { key = "A", y = -60, slot = 0, bag = 20 },
  { key = "B", y = 0, slot = 10, bag = 20 },
  { key = "C", y = 60, slot = 10, bag = 0 },
}

local function counts(c)
  local e = c.e
  if not (e and e.valid) then return -1, -1 end
  local slot = e.get_inventory(defines.inventory.character_ammo).get_item_count(AMMO)
  local bag = e.get_main_inventory().get_item_count(AMMO)
  return slot, bag
end

local function hp(c) return (c.b and c.b.valid) and c.b.health or -1 end

return {
  description = "REARMEMENT : un PNJ tire-t-il avec les chargeurs de son sac quand l'emplacement est vide ? (mesure d'un fait moteur)",
  check_tick = 3000,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 30, -100, AX + 40, 100, "grass-1")
    st.cases = {}
    for _, k in ipairs(CASES) do
      local e = s.create_entity({ name = "character", position = { AX, k.y }, force = "player" })
      local b = s.create_entity({ name = "big-biter", position = { AX + 8, k.y }, force = "enemy" })
      local c = { key = k.key, e = e, b = b, first_drop = nil, refills = 0 }
      if e then
        e.destructible = false
        e.get_inventory(defines.inventory.character_guns).insert({ name = GUN, count = 1 })
        if k.slot > 0 then e.get_inventory(defines.inventory.character_ammo).insert({ name = AMMO, count = k.slot }) end
        if k.bag > 0 then e.get_main_inventory().insert({ name = AMMO, count = k.bag }) end
      end
      if b then b.active = false end
      c.hp0 = hp(c)
      c.slot0, c.bag0 = counts(c)
      c.last_slot = c.slot0
      st.cases[#st.cases + 1] = c
    end
    ctx.check(#st.cases == 3 and st.cases[1].e ~= nil and st.cases[3].b ~= nil, "3 personnages et 3 gros biters poses")
  end,

  tick = function(ctx, e)
    local t = e.tick
    local st = ctx.state()
    for _, c in ipairs(st.cases or {}) do
      if c.e and c.e.valid and c.b and c.b.valid and t % 60 == 0 then
        c.e.shooting_state = { state = defines.shooting.shooting_enemies, position = c.b.position }
      end
      local slot, bag = counts(c)
      if slot > c.last_slot then c.refills = c.refills + 1 end
      c.last_slot = slot
      if not c.first_drop and hp(c) >= 0 and hp(c) < c.hp0 then c.first_drop = t end
    end
    if t % 300 == 0 and t > 0 then
      local parts = {}
      for _, c in ipairs(st.cases or {}) do
        local slot, bag = counts(c)
        parts[#parts + 1] = string.format("%s emplacement %d sac %d PV %.1f", c.key, slot, bag, hp(c))
      end
      ctx.log(string.format("tick %d : %s", t, table.concat(parts, " | ")))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    for _, c in ipairs(st.cases or {}) do
      local slot, bag = counts(c)
      ctx.log(string.format("FAIT %s : emplacement %d -> %d, sac %d -> %d, remplissages de l'emplacement %d, PV du biter %.1f -> %.1f, " ..
        "premier degat au tick %s", c.key, c.slot0, slot, c.bag0, bag, c.refills, c.hp0, hp(c), tostring(c.first_drop or "jamais")))
    end
    ctx.check(true, "mesure faite (voir les lignes FAIT)")
  end,
}
