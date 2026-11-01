--[[
  Scénario GREFFÉ « calcul-v2-migration » (lot CALCUL-V2, 30/10) : MIGRATION d'une sauvegarde 0.6.27 (chaîne du calcul v1 :
  centres à baie usée) vers le centre modulaire. DOUBLE SOURCE SEULEMENT (tools/autotest/README.md §1.1) :
    py -3.9 -B tools/autotest/banc.py --out <archive> --creation "<racine>\fo-logs\2026-10-30_CALCUL-V2\src-0.6.27\factorio-overhaul"
       --qui CALCUL-V2 -- 400 calcul-v2-migration <source CALCUL-V2>
  (src-0.6.27 = git archive a539f5e3 + feuilles D-6, à GARDER.)

  À la création (0.6.27) : technologies v1 recherchées, vitesse de recherche 1 ; 3 centres v1 posés (raise_built) sur leurs
  3 recettes, garnis (2 baies de serveurs + 3 000 eau ; 3 baies d'accélérateurs + 3 000 eau ; 1 processeur quantique +
  6 000 eau + 300 hélium-3), sous courant ; un coffre avec 5 baies de serveurs et 2 baies d'accélérateurs (objets v1).
  Au chargement (CALCUL-V2) : on_configuration_changed et migrations/calcul-v2.lua.
  Contrôles : centres sur le refroidissement à l'eau glacée ; baies rendues DANS leurs emplacements (2 CPU, 3 GPU) ; le
  processeur quantique au sol ; le coffre garde ses 7 baies (objet devenu module SOUS LE MÊME NOM, H-CV2-6) ; compagnons ;
  technologies neuves accordées, recettes v2 ouvertes ; vitesse de recherche = base 0.6.27 exacte (aucun calcul : CPU et
  GPU sans mémoire) ; une baie de mémoire posée → le calcul suit la règle.
]]

local X0, Y0 = 7400, 3000
local CHECK = 300
local T_MEM, T_READ = 120, 260
local V1 = {
  { key = "classique", r = "fo-compute-classic", items = { { "fo-server-blade", 2 } }, fluids = { { "water", 3000 } } },
  { key = "accelere", r = "fo-compute-accelerated", items = { { "fo-gpu-blade", 3 } }, fluids = { { "water", 3000 } } },
  { key = "quantique", r = "fo-compute-quantum", items = { { "fo-quantum-processor", 1 } },
    fluids = { { "water", 6000 }, { "fo-helium-3", 300 } } },
}
local TECHS = { "fo-chip-foundry", "fo-data-centers", "fo-gpu-computing", "fo-regolith-degassing", "fo-quantum-computing" }

local function count_on_ground(s, name, x, y)
  local n = 0
  for _, e in ipairs(s.find_entities_filtered({ type = "item-entity", area = { { x - 8, y - 8 }, { x + 8, y + 8 } } })) do
    if e.stack and e.stack.valid_for_read and e.stack.name == name then n = n + e.stack.count end
  end
  return n
end

return {
  description = "CALCUL-V2 : migration d'une sauvegarde 0.6.27 (centres v1 a baie usee) vers le centre modulaire (double source)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local dc = game.entity_prototypes["fo-data-center"]
    ctx.check(dc and (dc.module_inventory_size or 0) == 0, "carte creee par 0.6.27 (centre v1 : aucun emplacement de module)",
      dc and tostring(dc.module_inventory_size) or "absent")
    local f = game.forces.player
    for _, tn in ipairs(TECHS) do f.technologies[tn].researched = true end
    f.technologies["research-speed-1"].researched = true
    st.base = f.laboratory_speed_modifier
    ctx.prepare_area(X0 - 6, Y0 - 10, X0 + 40, Y0 + 12, "refined-concrete")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 120, Y0 - 120 }, { X0 + 160, Y0 + 120 } }, force = "enemy" })) do e.destroy() end
    ctx.power(X0 + 10, Y0 + 9)
    st.centres = {}
    local x = X0
    for i, c in ipairs(V1) do
      local e = s.create_entity({ name = "fo-data-center", position = { x + 2, Y0 }, force = "player", raise_built = true })
      e.set_recipe(c.r)
      local inv = e.get_inventory(defines.inventory.assembling_machine_input)
      for _, it in ipairs(c.items) do inv.insert({ name = it[1], count = it[2] }) end
      for _, fl in ipairs(c.fluids) do e.insert_fluid({ name = fl[1], amount = fl[2] }) end
      st.centres[i] = { key = c.key, e = e, x = x + 2, y = Y0, unit = e.unit_number }
      x = x + 8
    end
    local chest = s.create_entity({ name = "steel-chest", position = { X0 + 30, Y0 + 6 }, force = "player" })
    chest.insert({ name = "fo-server-blade", count = 5 })
    chest.insert({ name = "fo-gpu-blade", count = 2 })
    st.chest = chest
    ctx.log(string.format("CREATION 0.6.27 : 3 centres v1, base de recherche %.4f, coffre 5 + 2 baies", st.base))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == T_MEM then
      local c = st.centres[1].e
      if c and c.valid then st.mem_in = c.get_module_inventory() and c.get_module_inventory().insert({ name = "fo-memory-rack", count = 1 }) or -1 end
    elseif e.tick == T_READ then
      local c = st.centres[1].e
      st.read = c and c.valid and remote.call("fo-calcul", "center", c) or nil
      st.rate = remote.call("fo-calcul", "state", "player").rate
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.check(remote.interfaces["fo-calcul"] and remote.interfaces["fo-calcul"].migrated ~= nil, "partie rechargee par CALCUL-V2 (interface fo-calcul.migrated)")
    local m = remote.call("fo-calcul", "migrated") or {}
    ctx.log("MIGRATION " .. serpent.line(m))
    ctx.check(m.centers == 3 and m.racks_in == 5 and m.spilled == 1, "bilan : 3 centres migres, 5 baies posees, 1 objet au sol",
      serpent.line(m))
    local want = { { "fo-server-blade", 2 }, { "fo-gpu-blade", 3 }, nil }
    for i, c in ipairs(st.centres) do
      local e = c.e
      local ok = e and e.valid and e.unit_number == c.unit
      local r = ok and e.get_recipe()
      local inv = ok and e.get_module_inventory()
      local detail = ok and (tostring(r and r.name) .. " ; " .. serpent.line(inv and inv.get_contents() or {})) or "centre absent"
      local good = ok and r and r.name == "fo-dc-chilled-water" and inv ~= nil
      if good and want[i] then good = inv.get_item_count(want[i][1]) == want[i][2] end
      if good and i == 3 then good = inv.get_item_count() == 0 end
      ctx.check(good, "centre " .. c.key .. " : meme entite, refroidissement a l'eau glacee, baies rendues dans ses emplacements", detail)
      local p = ok and remote.call("fo-calcul", "companion", e)
      ctx.check(p and p.valid, "centre " .. c.key .. " : compagnon d'energie cree")
    end
    local qp = count_on_ground(s, "fo-quantum-processor", st.centres[3].x, st.centres[3].y)
    ctx.check(qp == 1, "processeur quantique rendu au sol pres de son centre (rien de perdu)", qp)
    local chest = st.chest
    local nb, ng = chest and chest.valid and chest.get_item_count("fo-server-blade") or -1, chest and chest.valid and chest.get_item_count("fo-gpu-blade") or -1
    local typ = game.item_prototypes["fo-server-blade"] and game.item_prototypes["fo-server-blade"].type
    ctx.check(nb == 5 and ng == 2 and typ == "module", "H-CV2-6 : le coffre garde ses 7 baies, objet v1 devenu module sous le meme nom",
      string.format("%d + %d, type %s", nb, ng, tostring(typ)))
    local f = game.forces.player
    local techs_ok = f.technologies["fo-wafer-fab"].researched and f.technologies["fo-data-centers-2"].researched
    local rec_ok = f.recipes["fo-rack-cpu"].enabled and f.recipes["fo-dc-chilled-water"].enabled and f.recipes["fo-dc-dilution"].enabled
      and f.recipes["fo-smt-graphics-card"].enabled
    ctx.check(techs_ok and rec_ok, "technologies neuves accordees (fonderie de tranches, grands centres), recettes v2 ouvertes",
      tostring(techs_ok) .. " / " .. tostring(rec_ok))
    -- Calcul : avant la mémoire, CPU et GPU sans mémoire → 0 ; la base de recherche 0.6.27 intacte (à 1e-9 près).
    local rd = st.read
    local want_c = 200 * 1500 / 2300 -- 2 CPU, 1 mémoire : brut 200, chaleur 2 300, passif 1 500 (sans refroidissement)
    ctx.check(st.mem_in == 1 and rd and math.abs(rd.compute - want_c) <= 0.01 * want_c,
      "baie de memoire posee : le calcul du centre suit la regle (2 CPU, 1 memoire, passif)", rd and string.format("%.2f contre %.2f", rd.compute, want_c) or "absent")
    local cs = remote.call("fo-calcul", "state", "player")
    ctx.check(math.abs(f.laboratory_speed_modifier - (st.base + cs.bonus)) < 1e-9,
      "vitesse de recherche = base de la sauvegarde 0.6.27 + bonus du calcul", string.format("%.6f = %.6f + %.6f", f.laboratory_speed_modifier, st.base, cs.bonus))
  end,
}
