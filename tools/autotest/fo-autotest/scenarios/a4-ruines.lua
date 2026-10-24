-- Scénario greffé du lot A4 (24/10) : RESTES et EXPLOSION de la mitrailleuse à la taille de l'emprise (déclarés par le
-- lot A2 : ctx.declare « -restes » et « -explosion », agrandis par kit.scale × emprise / 2 ; jamais vus en destruction).
--   & "<racine>\fo-autotest.bat" nopause 1300 a4-ruines "<source>"     (contrôles, sans images)
--   & "<racine>\fo-captures.bat" a4-ruines "<source>"                   (captures, sans son)
--   py -3.9 tools/autotest/a4_ruines_images.py "<fo-shots>"            (taille des restes mesurée sur les captures)
--
-- Une mitrailleuse par taille d'emprise : niveau 1 (vanilla, 2 × 2), 3 (âge 2, 2 × 2), 7 (3 × 3), 13 (4 × 4), 19 (5 × 5),
-- 25 (6 × 6), chacune deux fois : sur un sol de laboratoire BLANC uniforme (mesure de la taille des restes) et sur de
-- l'herbe (aspect). Détruite par LuaEntity.die() (reste et explosion du prototype, comme une vraie destruction).
-- Banc sans images : toutes détruites au tick 100. Session avec images : « avant », puis chaque tourelle détruite 17
-- ticks avant sa première capture d'explosion (deux instants : 17 et 27 ticks après die() ; l'explosion et le reste
-- n'apparaissent que RETARD = 13 ticks après die(), fait constaté au banc), attente, restes de jour et de nuit.
-- Contrôles : prototype de chaque niveau et son reste (« fo-lvl-gun-N-restes » dès que l'emprise dépasse 2 × 2, vanilla
-- sinon) ; dans les 120 ticks qui suivent la destruction (rien au tick même : fait constaté), l'entité explosion
-- attendue apparaît et un seul reste est posé, au nom attendu (premier tick relevé dans le journal) ;
-- au contrôle (tick 1 200), le reste est toujours là. Table : fo-shots/a4-ruines-sites.tsv.

local X0, Y0, PAS, DY = -2400, -3000, 20, 24
local NIVEAUX = { 1, 3, 7, 13, 19, 25 }
local SOLS = { "lab-white", "grass-1" }
local CHECK = 1200
local RES = { 640, 640 }
local RETARD = 13      -- ticks entre die() et l'apparition de l'explosion et du reste (banc du 24/10, 12 tourelles)
local ATTENTE = 9      -- captures d'attente (10 ticks chacune) : l'explosion vanilla dure 60 à 82 ticks

local function nom(n) return n == 1 and "gun-turret" or ("fo-lvl-gun-" .. n) end

local function attendus(n)
  local p = game.entity_prototypes[nom(n)]
  local sb = p.selection_box
  local cote = sb.right_bottom.x - sb.left_top.x
  local restes, explosion = "gun-turret-remnants", "gun-turret-explosion"
  if cote > 2.01 then restes, explosion = nom(n) .. "-restes", nom(n) .. "-explosion" end
  return restes, explosion, cote
end

local function releve(ctx, c)
  local s = ctx.surface()
  local r = 1 + c.cote
  local ex = s.find_entities_filtered({ type = "explosion", area = { { c.x - r, c.y - r }, { c.x + r, c.y + r } } })
  local noms = {}
  for _, x in ipairs(ex) do noms[#noms + 1] = x.name end
  table.sort(noms)
  local co = s.find_entities_filtered({ type = "corpse", area = { { c.x - r, c.y - r }, { c.x + r, c.y + r } } })
  local cn = {}
  for _, x in ipairs(co) do cn[#cn + 1] = x.name end
  table.sort(cn)
  return noms, cn
end

--- Destruction par die() ; relevé des explosions et des restes AU TICK MÊME (premier passage, 24/10 : rien n'y est
--- encore, ni explosion ni reste) puis à chaque tick jusqu'à 120 ticks après (tick()).
local function tuer(ctx, c)
  if not (c.t and c.t.valid) then return end
  c.mort = game.tick
  c.t.die()
  local noms, cn = releve(ctx, c)
  c.meme_tick = string.format("explosions=[%s],restes=[%s]", table.concat(noms, ","), table.concat(cn, ","))
end

return {
  description = "A4 : restes et explosion de la mitrailleuse a la taille de l'emprise (2x2 a 6x6), destruction reelle",
  base = nil,
  check_tick = CHECK,
  shots_delay = 300,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    st.sites = {}
    game.map_settings.enemy_expansion.enabled = false
    for j, sol in ipairs(SOLS) do
      for i, n in ipairs(NIVEAUX) do
        local x, y = X0 + (i - 1) * PAS, Y0 + (j - 1) * DY
        ctx.prepare_area(x - PAS / 2, y - DY / 2, x + PAS / 2, y + DY / 2, sol)
        local t = s.create_entity({ name = nom(n), position = { x, y }, force = "player" })
        local restes, explosion, cote = attendus(n)
        st.sites[#st.sites + 1] = { n = n, sol = sol, t = t, x = t and t.position.x or x, y = t and t.position.y or y,
          cote = cote, restes = restes, explosion = explosion }
      end
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.t then poses = poses + 1 end end
    ctx.check(poses == #st.sites, "tourelles posees (6 tailles x 2 sols)", poses .. " / " .. #st.sites)
    -- prototypes : reste et explosion de chaque niveau 1 à 30
    local ok, l = 0, {}
    for n = 1, 30 do
      local p = game.entity_prototypes[nom(n)]
      local restes, explosion, cote = attendus(n)
      local cn = {}
      for k in pairs(p.corpses or {}) do cn[#cn + 1] = k end
      table.sort(cn)
      local pe = game.entity_prototypes[explosion]
      local pr = game.entity_prototypes[restes]
      if cn[1] == restes and #cn == 1 and pe and pe.type == "explosion" and pr and pr.type == "corpse" then ok = ok + 1 end
      l[#l + 1] = string.format("%d:%gx%g/%s", n, cote, cote, cn[1] or "-")
    end
    ctx.log("niveau : emprise / reste du prototype : " .. table.concat(l, " "))
    ctx.check(ok == 30, "prototypes : reste (corpse) et explosion attendus aux 30 niveaux (copies declarees des que "
      .. "l'emprise depasse 2x2)", ok .. " / 30")
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    if e.tick == 100 and #game.connected_players == 0 and not st.morts then
      -- banc sans images : toutes détruites au tick 100
      for _, c in ipairs(st.sites) do tuer(ctx, c) end
      st.tues = true
    end
    if st.morts and st.morts[e.tick] then
      for _, i in ipairs(st.morts[e.tick]) do tuer(ctx, st.sites[i]) end
      st.tues = true
    end
    -- relevé à chaque tick jusqu'à 120 ticks après la mort : premier tick où l'explosion, puis le reste, existent
    for _, c in ipairs(st.sites) do
      if c.mort and e.tick > c.mort and e.tick <= c.mort + 120 and not (c.explosion_ok and c.restes_ok) then
        local noms, cn = releve(ctx, c)
        for _, n in ipairs(noms) do
          if n == c.explosion and not c.explosion_ok then c.explosion_ok, c.t_exp = true, e.tick - c.mort end
        end
        if #cn > 0 and not c.restes_ok then
          c.restes_mort = table.concat(cn, ",")
          c.restes_ok = #cn == 1 and cn[1] == c.restes
          c.t_reste = e.tick - c.mort
        end
        c.explosions = (c.explosions or "") .. ((#noms > 0 and not c.vu_exp) and table.concat(noms, ",") or "")
        if #noms > 0 then c.vu_exp = true end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    local exp_ok, mort_ok, reste_ok, l = 0, 0, 0, {}
    for _, c in ipairs(st.sites) do
      if c.explosion_ok then exp_ok = exp_ok + 1 end
      if c.restes_ok then mort_ok = mort_ok + 1 end
      local r = 1 + c.cote
      local co = s.find_entities_filtered({ type = "corpse", area = { { c.x - r, c.y - r }, { c.x + r, c.y + r } } })
      local present = #co == 1 and co[1].name == c.restes
      if present then reste_ok = reste_ok + 1 end
      l[#l + 1] = string.format("%d/%s:mort=%s,meme_tick:%s,ensuite:explosions=[%s](+%s),restes=[%s](+%s),au_controle=%s",
        c.n, c.sol, tostring(c.mort), tostring(c.meme_tick), tostring(c.explosions), tostring(c.t_exp),
        tostring(c.restes_mort), tostring(c.t_reste), present and co[1].name or "?")
    end
    ctx.log("destruction (niveau/sol : tick, explosions trouvees, restes poses, reste au controle) : " .. table.concat(l, " "))
    ctx.check(exp_ok == #st.sites, "explosion du prototype (\"-explosion\" des 3x3) apparue dans les 120 ticks qui suivent la destruction",
      exp_ok .. " / " .. #st.sites)
    ctx.check(mort_ok == #st.sites, "un seul reste pose, au nom attendu (\"-restes\" des 3x3)", mort_ok .. " / " .. #st.sites)
    ctx.check(reste_ok == #st.sites, "reste toujours la au tick " .. CHECK, reste_ok .. " / " .. #st.sites)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    local L = { "capture\tetat\tniveau\tsol\tcote\tx\ty\ttick_mort_prevu" }
    local idx = 0
    local function cap(nm, c, etat, nuit, z)
      idx = idx + 1
      add(nm, c.x, c.y, z or 2, nuit and 0.5 or 0, { res = RES, info = false, aa = false })
      L[#L + 1] = string.format("%s\t%s\t%d\t%s\t%g\t%.4f\t%.4f\t%s", nm, etat, c.n, c.sol, c.cote, c.x, c.y,
        tostring(c.mort_prevu or ""))
    end
    for _, c in ipairs(st.sites) do cap(string.format("avant-n%02d-%s", c.n, c.sol), c, "avant") end
    st.morts = {}
    for i, c in ipairs(st.sites) do
      -- la capture « explosion-a » de ce site sera la (idx + 1)-ième, prise au tick game.tick + 10 × idx
      c.mort_prevu = game.tick + 10 * idx - RETARD - 4
      st.morts[c.mort_prevu] = st.morts[c.mort_prevu] or {}
      table.insert(st.morts[c.mort_prevu], i)
      cap(string.format("explosion-a-n%02d-%s", c.n, c.sol), c, "mort+17")
      cap(string.format("explosion-b-n%02d-%s", c.n, c.sol), c, "mort+27")
    end
    for k = 1, ATTENTE do
      idx = idx + 1
      add(string.format("attente-%d", k), X0, Y0 - 40, 1, 0, { res = { 64, 64 }, info = false })
    end
    for _, c in ipairs(st.sites) do cap(string.format("restes-n%02d-%s", c.n, c.sol), c, "restes") end
    for _, c in ipairs(st.sites) do
      if c.sol ~= "lab-white" then cap(string.format("restes-nuit-n%02d-%s", c.n, c.sol), c, "restes-nuit", true) end
    end
    game.write_file("fo-shots/a4-ruines-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
