-- Scénario greffé du lot MOD-1 (24/10) : MIGRATION d'une partie 0.4.15 (modules déjà posés, additionnés) vers les
-- modules MULTIPLICATIFS. Double source SEULEMENT (tools/autotest/README.md §1.1) :
--   $env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-24_MOD1\src-0.4.15"     (= git archive 4fba886 + feuilles D-6)
--   & "<racine>\fo-autotest.bat" nopause 200 mod1-migration "<source MOD-1>"
--   $env:FO_CREATE_SRC = $null
-- À la création (0.4.15) : machines posées SANS raise_built, modules insérés (valeurs 0.4.15 : vitesse +20, +30,
-- +50 %). Au chargement par MOD-1 : on_configuration_changed (contenu changé, F130) → recensement, balises posées
-- pour les machines qui en ont besoin, effets RECALCULÉS avec les nouvelles valeurs (vitesse +50, +80, +110 %).

-- Lot MOD-3 (D-17) : attendus aux valeurs de D-17 (vitesse +20, +30, +40 % ; productivité +10 % multipliée,
-- énergie 60 % du bonus) : le contrôle (finish) tourne avec la source du banc.

local X, Y = 4000.5, 4600.5
local S1, S2, S3 = "speed-module", "speed-module-2", "speed-module-3"
local VAL = {
  [S1] = { speed = 0.2, consumption = 0.12 }, [S2] = { speed = 0.3, consumption = 0.18 }, [S3] = { speed = 0.4, consumption = 0.24 },
  ["productivity-module"] = { speed = -0.05, consumption = 0.06, productivity = 0.10 },
  ["effectivity-module"] = { consumption = -0.3 },
}
local CAS = {
  { id = "am2-2xS3", m = "assembling-machine-2", dx = 0, mods = { S3, S3 } },
  { id = "am3-4xS1", m = "assembling-machine-3", dx = 6, mods = { S1, S1, S1, S1 } },
  { id = "foreuse-3xS2", m = "electric-mining-drill", dx = 12, mods = { S2, S2, S2 }, ore = true },
  { id = "niveau10-2xS2", m = "fo-lvl-assembler-10", dx = 18.5, dy = 0.5, mods = { S2, S2 } },
  { id = "am2-1xS1", m = "assembling-machine-2", dx = 26, mods = { S1 } },
  { id = "am2-vide", m = "assembling-machine-2", dx = 32, mods = {} },
  { id = "am2-prod+eff", m = "assembling-machine-2", dx = 38, mods = { "productivity-module", "effectivity-module" } },
}

local function attendu(mods)
  local ps, pc, ss, sc = 1, 1, 0, 0
  for _, n in ipairs(mods) do
    local v = VAL[n]
    if v.speed then ps = ps * (1 + v.speed); ss = ss + v.speed end
    if v.consumption then pc = pc * math.max(0.2, 1 + v.consumption); sc = sc + v.consumption end
  end
  local ts, tc = math.floor(ps * 100 + 0.5), math.floor(pc * 100 + 0.5)
  return (ts - 100) / 100, (tc - 100) / 100, math.abs((ts - 100) / 100 - ss) > 0.004 or math.abs((tc - 100) / 100 - sc) > 0.004
end

return {
  description = "MOD-1 : migration d'une partie 0.4.15 (modules poses, additionnes) vers les modules multiplicatifs",
  base = nil,
  check_tick = 120,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    ctx.check(game.entity_prototypes["fo-mm-balise"] == nil, "carte creee SANS les modules multiplicatifs (source 0.4.15)",
      "fo-mm-balise " .. tostring(game.entity_prototypes["fo-mm-balise"] ~= nil))
    ctx.prepare_area(X - 12, Y - 12, X + 50, Y + 12, "grass-1")
    ctx.power(X + 20, Y)
    st.cas = {}
    local bad = {}
    for _, c in ipairs(CAS) do
      local px, py = X + c.dx, Y + (c.dy or 0)
      if c.ore then
        for tx = -3, 3 do for ty = -3, 3 do s.create_entity({ name = "iron-ore", position = { px + tx, py + ty }, amount = 1000000 }) end end
      end
      local m = s.create_entity({ name = c.m, position = { px, py }, force = "player" }) -- SANS raise_built
      local n = 0
      if m then
        local inv = m.get_module_inventory()
        for _, nm in ipairs(c.mods) do n = n + inv.insert({ name = nm, count = 1 }) end
        ctx.log(string.format("CREATION %s : %s, %d emplacement(s), %d module(s), speed_bonus %.4f", c.id, m.name, #inv, n, m.speed_bonus))
      end
      if not m or n ~= #c.mods then bad[#bad + 1] = c.id end
      st.cas[#st.cas + 1] = { id = c.id, m = m, mods = c.mods }
    end
    ctx.check(#bad == 0, "machines 0.4.15 posees avec leurs modules", table.concat(bad, " ; "))
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.check(remote.interfaces["fo-modules"] ~= nil, "partie rechargee par MOD-1 (interface fo-modules)")
    local stats = remote.call("fo-modules", "stats")
    ctx.log("STATS " .. serpent.line(stats))
    ctx.check((stats.migrated or 0) >= 1, "migration jouee (on_configuration_changed)", serpent.line(stats))
    for _, c in ipairs(st.cas) do
      local m = c.m
      if not (m and m.valid) then
        ctx.fail("migration " .. c.id, "machine absente")
      else
        local want_s, want_c, besoin = attendu(c.mods)
        local inv = m.get_module_inventory()
        local stt = remote.call("fo-modules", "state", m)
        local bb = m.bounding_box
        local nb = s.count_entities_filtered({ name = "fo-mm-balise", area = { { bb.left_top.x, bb.left_top.y }, { bb.right_bottom.x, bb.right_bottom.y } } })
        local want_p = 0
        for _, n in ipairs(c.mods) do want_p = want_p + (VAL[n].productivity or 0) end   -- un seul module de productivité ici
        local ok = inv.get_item_count() == #c.mods and math.abs(m.speed_bonus - want_s) < 0.005
          and math.abs(m.consumption_bonus - want_c) < 0.005 and math.abs(m.productivity_bonus - want_p) < 0.005
          and stt.tracked and nb == (besoin and 1 or 0)
        ctx.check(ok, "migration " .. c.id .. " : modules gardes, produit avec les nouvelles valeurs, balise " .. (besoin and "posee" or "absente"),
          string.format("%s, %d emplacement(s), %d module(s) ; speed_bonus %.4f (attendu %.4f) ; consumption_bonus %.4f (attendu %.4f) ; productivity_bonus %.4f (attendu %.4f) ; suivie %s ; balises %d",
            m.name, #inv, inv.get_item_count(), m.speed_bonus, want_s, m.consumption_bonus, want_c, m.productivity_bonus, want_p, tostring(stt.tracked), nb))
      end
    end
  end,
}
