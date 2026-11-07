--[[
  EFFONDREMENT (parade du kit offert, décision du lead, 7/11 vers 19 h 05) : micro-banc MOTEUR, aucun code du mod n'y touche.
  Le kit offert d'une recrue gratuite reste-t-il dans le corps d'un personnage SANS joueur, et où le retirer ?
    (a) un personnage sans joueur tué laisse un character-corpse avec ses armes, ses munitions et son inventaire principal ;
    (b) un objet retiré des inventaires du personnage PENDANT on_entity_died manque bien à son corps ;
    (c) repli : on_post_entity_died rend l'unit_number et le corps (corpses), dont l'inventaire character_corpse se vide par script.
  Quatre personnages nus de la force player, posés à l'écart du départ (sans guerre) ; kit : pistol 1, firearm-magazine 10. A, B, C
  portent aussi iron-plate 5 (la cargaison) ; D ne porte que le kit. Tick 120 : tués par dégâts (force enemy), comme sous un campeur.
    A : rien de retiré (témoin) ; B, D : kit retiré pendant on_entity_died ; C : kit retiré du corps pendant on_post_entity_died.
  Tick 180 : relevé des corps. Critères ÉCRITS AVANT : fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md, « Parade du kit offert ».
  Lancement (par la file) : banc.py --out <archive> --qui EFFONDREMENT -- 300 kit-cadavre <source>
]]

local T_SETUP, T_KILL, T_CHECK = 60, 120, 180
local GUN, AMMO, CARGO = "pistol", "firearm-magazine", "iron-plate"
local LABELS = { "A", "B", "C", "D" }
local CHAR_FILTER = { { filter = "type", type = "character" } }

-- État des gestionnaires (pas de ctx dans un gestionnaire) : global du mod de test (F35 : propre à ce mod).
local function g()
  global.kitcad = global.kitcad or { who = {}, seq = {}, removed = {}, post = {}, expired = 0 }
  return global.kitcad
end

local function take(inv, name, n)
  if not (inv and inv.valid) then return 0 end
  return inv.remove({ name = name, count = n })
end

script.on_event(defines.events.on_entity_died, function(e)
  local en = e.entity
  if not (en and en.valid) then return end
  local s = g()
  local label = s.who[en.unit_number]
  if not label then return end
  s.seq[label] = (s.seq[label] or "") .. "D"
  if label == "B" or label == "D" then
    s.removed[label] = { gun = take(en.get_inventory(defines.inventory.character_guns), GUN, 1),
      ammo = take(en.get_inventory(defines.inventory.character_ammo), AMMO, 10) }
  end
end, CHAR_FILTER)

script.on_event(defines.events.on_post_entity_died, function(e)
  local s = g()
  local label = e.unit_number and s.who[e.unit_number]
  if not label then return end
  s.seq[label] = (s.seq[label] or "") .. "P"
  local names, corpse = {}, nil
  for _, c in ipairs(e.corpses or {}) do
    if c.valid then
      names[#names + 1] = c.name .. "/" .. c.type
      if c.type == "character-corpse" then corpse = c end
    end
  end
  s.post[label] = { unit = e.unit_number, n = #(e.corpses or {}), names = table.concat(names, ","), has_corpse = corpse ~= nil }
  if label == "C" and corpse then
    local inv = corpse.get_inventory(defines.inventory.character_corpse)
    s.removed.C = { gun = take(inv, GUN, 1), ammo = take(inv, AMMO, 10) }
  end
end, CHAR_FILTER)

script.on_event(defines.events.on_character_corpse_expired, function(e)
  local s = g()
  s.expired = s.expired + 1
  log(string.format("[FO-KIT-CADAVRE] corps expire au tick %d (%s)", e.tick, e.corpse and e.corpse.valid and
    string.format("%.1f,%.1f", e.corpse.position.x, e.corpse.position.y) or "invalide"))
end)

local function contents_text(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = k .. "=" .. t[k] end
  return "{" .. table.concat(out, " ") .. "}"
end

local function corpse_at(surface, pos)
  local list = surface.find_entities_filtered({ type = "character-corpse", position = pos, radius = 2 })
  return list[1], #list -- (8 tuiles entre deux personnages : un corps au plus ; relevé seulement)
end

return {
  description = "EFFONDREMENT : le kit offert reste-t-il dans le corps d'un personnage sans joueur, et ou le retirer ?",
  base = nil,
  check_tick = T_CHECK,

  init = function(ctx)
    g()
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    local s = ctx.surface()
    if t == T_SETUP then
      local c = game.forces.player.get_spawn_position(s)
      st.ents, st.pos, st.made = {}, {}, 0
      for i, label in ipairs(LABELS) do
        local want = { x = c.x + 40 + 8 * i, y = c.y + 40 }
        local p = s.find_non_colliding_position("character", want, 10, 0.5)
        local en = p and s.create_entity({ name = "character", position = p, force = "player" })
        if en then
          local ok = en.get_inventory(defines.inventory.character_guns).insert({ name = GUN, count = 1 }) == 1
          ok = en.get_inventory(defines.inventory.character_ammo).insert({ name = AMMO, count = 10 }) == 10 and ok
          if label ~= "D" then ok = en.get_inventory(defines.inventory.character_main).insert({ name = CARGO, count = 5 }) == 5 and ok end
          if ok then st.made = st.made + 1 end
          st.ents[label], st.pos[label] = en, { x = en.position.x, y = en.position.y }
          g().who[en.unit_number] = label
        end
      end
    elseif t == T_KILL then
      st.killed = 0
      for _, label in ipairs(LABELS) do
        local en = st.ents and st.ents[label]
        if en and en.valid then
          en.damage(10000, "enemy", "physical")
          if not en.valid then st.killed = st.killed + 1 end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local k = g()
    ctx.check(st.made == 4 and st.killed == 4, "4 personnages poses, garnis et tues (par degats)",
      string.format("garnis %s, tues %s", tostring(st.made), tostring(st.killed)))
    local got = {}
    for _, label in ipairs(LABELS) do
      local pos = st.pos and st.pos[label]
      local corpse, n = nil, 0
      if pos then corpse, n = corpse_at(s, pos) end
      local inv = corpse and corpse.get_inventory(defines.inventory.character_corpse)
      local cont = inv and inv.get_contents() or {}
      got[label] = { corpse = corpse ~= nil, cont = cont }
      local post = k.post[label] or {}
      local rm = k.removed[label] or {}
      ctx.log(string.format("%s : corps %s (%d a 2 tuiles) %s ; evenements %s ; retire pistolet %s chargeurs %s ; post-mort : unit %s, corps rendus %s [%s]",
        label, corpse and "oui" or "non", n, contents_text(cont), tostring(k.seq[label]), tostring(rm.gun), tostring(rm.ammo),
        tostring(post.unit), tostring(post.n), tostring(post.names)))
    end
    local function kit_gone(c) return (c[GUN] or 0) == 0 and (c[AMMO] or 0) == 0 end
    local A, B, C = got.A, got.B, got.C
    ctx.check(A.corpse and A.cont[GUN] == 1 and A.cont[AMMO] == 10 and A.cont[CARGO] == 5,
      "(a) A : character-corpse avec pistol 1, firearm-magazine 10, iron-plate 5", contents_text(A.cont))
    local rb = k.removed.B or {}
    ctx.check(rb.gun == 1 and rb.ammo == 10, "(b) B : 1 pistolet et 10 chargeurs retires pendant on_entity_died",
      string.format("pistolet %s, chargeurs %s", tostring(rb.gun), tostring(rb.ammo)))
    ctx.check(B.corpse and kit_gone(B.cont) and B.cont[CARGO] == 5, "(b) B : corps sans pistolet ni chargeur, iron-plate 5 garde",
      (B.corpse and "" or "pas de corps ") .. contents_text(B.cont))
    local pc = k.post.C or {}
    ctx.check(pc.has_corpse == true and pc.unit ~= nil and k.who[pc.unit] == "C",
      "(c) C : on_post_entity_died rend l'unit_number de C et un character-corpse", tostring(pc.names))
    ctx.check(C.corpse and kit_gone(C.cont) and C.cont[CARGO] == 5, "(c) C : apres retrait, corps sans pistolet ni chargeur, iron-plate 5 garde",
      (C.corpse and "" or "pas de corps ") .. contents_text(C.cont))
    local order_ok, seqs = true, {}
    for _, label in ipairs(LABELS) do
      seqs[#seqs + 1] = label .. "=" .. tostring(k.seq[label])
      if k.seq[label] ~= "DP" then order_ok = false end
    end
    ctx.check(order_ok, "ordre : on_entity_died avant on_post_entity_died, pour les 4", table.concat(seqs, " "))
    ctx.log(string.format("hors bilan : D (kit seul, retire pendant on_entity_died) : corps %s %s ; corps expires %d",
      got.D.corpse and "oui" or "non", contents_text(got.D.cont), k.expired))
  end,
}
