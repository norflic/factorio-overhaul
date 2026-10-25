-- Scénario greffé du lot A5-ESSAI (25/10) : MASQUE D'ÉQUIPE de la mitrailleuse sur de petites pièces, ESSAI sur les
-- âges 3, 9 et 15, à 3 intensités. Sur une COPIE JETABLE du mod seulement (tools/autotest/a5/a5_masques.py jetable :
-- prototypes a5-gun-eNN-iXX, copies des niveaux 5, 17 et 29 avec la couche de masque) ; sur le mod livré, les
-- prototypes d'essai manquent et le contrôle le dit (les témoins sont posés quand même).
--   & "<racine>\fo-captures.bat" a5-equipe "<copie jetable>"
-- Par âge, une grille de 3 rangées (forces) × 4 colonnes (TÉMOIN sans masque = le niveau du mod, puis intensités 25,
-- 40 et 60 %), têtes orientées pareil (orientation écrite, sans cible, F122), munitions chargées (pas d'alerte).
-- Forces : « player » (couleur par défaut), « fo-scarlet » et « fo-azure » avec custom_color = couleurs des factions
-- (shared/faction/config.lua) ; la couleur d'une force créée SANS custom_color est relue et écrite au journal (le mod
-- livré n'en pose pas aux factions).
-- Captures : chaque grille de jour et de nuit, zooms 1 et 2. Table : fo-shots/a5-equipe-sites.tsv.

local X0, Y0 = -2600, -3000
local AGES = { { age = 3, n = 5, px = 6, py = 6 }, { age = 9, n = 17, px = 8, py = 8 }, { age = 15, n = 29, px = 11, py = 10 } }
local INTENS = { 25, 40, 60 }
local FORCES = { { "player", nil }, { "fo-scarlet", { r = 0.85, g = 0.18, b = 0.16, a = 1 } },
  { "fo-azure", { r = 0.20, g = 0.45, b = 0.95, a = 1 } } }
local ORIENT = 0.375

local function origine(i)
  local y = Y0
  for k = 1, i - 1 do y = y + 3 * AGES[k].py + 8 end
  return X0, y
end

return {
  description = "A5 : masque d'equipe sur petites pieces, ages 3, 9, 15 x 3 intensites x 3 forces (copie jetable)",
  base = nil,
  check_tick = 120,
  shots_delay = 150,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites = {}
    local xa, ya = origine(1)
    local xb, yb = origine(#AGES)
    ctx.prepare_area(xa - 12, ya - 12, xa + 4 * 11 + 12, yb + 3 * 10 + 12, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { xa - 200, ya - 200 }, { xa + 4 * 11 + 200, yb + 3 * 10 + 200 } } })) do
      en.destroy()
    end
    local manque = {}
    for _, f in ipairs(FORCES) do
      local force = game.forces[f[1]] or game.create_force(f[1])
      if f[2] then force.custom_color = f[2] end
      for _, g in ipairs({ "enemy" }) do
        force.set_cease_fire(g, true)
        game.forces[g].set_cease_fire(force, true)
      end
    end
    if not game.forces["fo-a5-sans"] then game.create_force("fo-a5-sans") end
    for i, A in ipairs(AGES) do
      local x0, y0 = origine(i)
      for r, f in ipairs(FORCES) do
        for c = 0, #INTENS do
          local nom = c == 0 and ("fo-lvl-gun-" .. A.n) or string.format("a5-gun-e%02d-i%02d", A.age, INTENS[c])
          local t = nil
          if game.entity_prototypes[nom] then
            t = s.create_entity({ name = nom, position = { x0 + c * A.px, y0 + (r - 1) * A.py }, force = f[1] })
          else
            manque[#manque + 1] = nom
          end
          if t then
            pcall(function() t.orientation = ORIENT end)
            pcall(function() t.insert({ name = "firearm-magazine", count = 10 }) end)
          end
          st.sites[#st.sites + 1] = { age = A.age, force = f[1], nom = nom, intensite = c == 0 and 0 or INTENS[c], t = t,
            x = t and t.position.x or 0, y = t and t.position.y or 0 }
        end
      end
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.t then poses = poses + 1 end end
    ctx.check(#manque == 0, "prototypes d'essai presents (copie jetable)", #manque == 0 and "36" or table.concat(manque, " "))
    ctx.check(poses == #st.sites, "tourelles posees (3 ages x 3 forces x 4)", poses .. " / " .. #st.sites)
  end,

  finish = function(ctx)
    local st = ctx.state()
    local l = {}
    for _, nm in ipairs({ "player", "fo-scarlet", "fo-azure", "fo-a5-sans", "enemy", "neutral" }) do
      local f = game.forces[nm]
      if f then
        local c, cc = f.color, f.custom_color
        l[#l + 1] = string.format("%s=(%.3f,%.3f,%.3f,%.3f)%s", nm, c.r, c.g, c.b, c.a or -1,
          cc and string.format(" custom(%.2f,%.2f,%.2f,%.2f)", cc.r, cc.g, cc.b, cc.a or -1) or "")
      end
    end
    ctx.log("couleurs des forces (LuaForce.color) : " .. table.concat(l, " "))
    local ok, tourne = 0, 0
    for _, c in ipairs(st.sites) do
      if c.t and c.t.valid then
        ok = ok + 1
        if math.abs(c.t.orientation - ORIENT) > 0.02 then tourne = tourne + 1 end
      end
    end
    ctx.check(ok == #st.sites, "tourelles toujours la", ok .. " / " .. #st.sites)
    ctx.check(tourne == 0, "orientation tenue", tourne .. " tourelle(s) tournee(s)")
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tage\tzoom\tnuit\tx\ty\tpx\tpy" }
    for i, A in ipairs(AGES) do
      local x0, y0 = origine(i)
      local cx, cy = x0 + 1.5 * A.px, y0 + A.py - 0.6
      for _, z in ipairs({ 1, 2 }) do
        for _, nuit in ipairs({ false, true }) do
          local nm = string.format("a5-e%02d-z%d-%s", A.age, z, nuit and "nuit" or "jour")
          local w, h = math.floor(4 * A.px * 32 * z), math.floor(3 * A.py * 32 * z)
          add(nm, cx, cy, z, nuit and 0.5 or 0, { res = { w, h }, info = false, aa = true })
          L[#L + 1] = string.format("%s\t%d\t%d\t%d\t%.4f\t%.4f\t%d\t%d", nm, A.age, z, nuit and 1 or 0, cx, cy, A.px, A.py)
        end
      end
    end
    local S = { "site\tage\tforce\tnom\tintensite\tx\ty" }
    for _, c in ipairs(st.sites) do
      S[#S + 1] = string.format("%s\t%d\t%s\t%s\t%d\t%.4f\t%.4f", c.nom .. "@" .. c.force, c.age, c.force, c.nom,
        c.intensite, c.x, c.y)
    end
    game.write_file("fo-shots/a5-equipe-captures.tsv", table.concat(L, "\n") .. "\n", false)
    game.write_file("fo-shots/a5-equipe-sites.tsv", table.concat(S, "\n") .. "\n", false)
  end,
}
