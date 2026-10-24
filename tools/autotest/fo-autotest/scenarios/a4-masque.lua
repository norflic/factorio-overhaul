-- Scénario greffé du lot A4 (24/10) : ESSAI du masque d'équipe de la mitrailleuse. Sur une COPIE JETABLE du mod
-- (tools/autotest/a4/masque_jetable.py : masque de la tête de l'âge 4, flags « mask », apply_runtime_tint) ; sur le mod
-- livré, les captures montrent l'absence de masque (témoin).
--   & "<racine>\fo-captures.bat" a4-masque "<copie jetable>"
--   py -3.9 tools/autotest/a4/masque_images.py "<fo-shots>"
-- Trois forces : « player » (couleur par défaut), « fo-rouge » (custom_color rouge), « fo-bleu » (bleu). Pour chacune :
-- une mitrailleuse VANILLA (masque vanilla, témoin du moteur) et une du niveau 7 (âge 4), tête vers l'est (d16), sans
-- cible, captures zoom 2 de jour. Table : fo-shots/a4-masque-sites.tsv. Contrôles : tourelles posées, couleurs des
-- forces relues (LuaForce.color).

local X0, Y0, PAS = -2400, 3000, 12
local FORCES = { { "player", nil }, { "fo-rouge", { r = 0.9, g = 0.1, b = 0.1, a = 1 } },
  { "fo-bleu", { r = 0.1, g = 0.3, b = 0.95, a = 1 } } }
local NIV = { "gun-turret", "fo-lvl-gun-7" }

return {
  description = "A4 : essai du masque d'equipe (copie jetable), 3 forces x (vanilla, niveau 7)",
  base = nil,
  check_tick = 120,
  shots_delay = 120,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites = {}
    ctx.prepare_area(X0 - 10, Y0 - 10, X0 + 3 * PAS + 10, Y0 + 2 * PAS + 10, "concrete")
    for i, f in ipairs(FORCES) do
      local force = game.forces[f[1]] or game.create_force(f[1])
      if f[2] then force.custom_color = f[2] end
      for j, n in ipairs(NIV) do
        local x, y = X0 + (i - 1) * PAS, Y0 + (j - 1) * PAS
        local t = s.create_entity({ name = n, position = { x, y }, force = force })
        if t then pcall(function() t.orientation = 0.25 end) end
        st.sites[#st.sites + 1] = { force = f[1], nom = n, t = t, x = t and t.position.x or x, y = t and t.position.y or y }
      end
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.t then poses = poses + 1 end end
    ctx.check(poses == #st.sites, "tourelles posees (3 forces x 2)", poses .. " / " .. #st.sites)
  end,

  finish = function(ctx)
    local st = ctx.state()
    local l = {}
    for _, f in ipairs(FORCES) do
      local c = game.forces[f[1]].color
      l[#l + 1] = string.format("%s=(%.2f,%.2f,%.2f)", f[1], c.r, c.g, c.b)
    end
    ctx.log("couleurs des forces (LuaForce.color) : " .. table.concat(l, " "))
    ctx.check(true, "couleurs des forces relues", table.concat(l, " "))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tforce\tnom\tx\ty" }
    for _, c in ipairs(st.sites) do
      local nm = string.format("masque-%s-%s", c.force, c.nom)
      add(nm, c.x, c.y - 1, 2, 0, { res = { 512, 512 }, info = false, aa = false })
      L[#L + 1] = string.format("%s\t%s\t%s\t%.4f\t%.4f", nm, c.force, c.nom, c.x, c.y)
    end
    game.write_file("fo-shots/a4-masque-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
