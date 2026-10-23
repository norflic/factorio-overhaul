-- Scénario greffé du lot A1 (23/10) : expériences E67 et E70 sur la tête d'une mitrailleuse, en moteur réel.
-- À LANCER SUR LA COPIE JETABLE (tools/autotest/a1/jetable.py), qui seule a les prototypes de test :
--   py -3.9 tools/autotest/a1/jetable.py --dest <dossier neuf>
--   & "<racine>\fo-autotest.bat" nopause 1000 a1-tourelle "<dossier neuf>"
--   & "<racine>\fo-captures.bat" a1-tourelle "<dossier neuf>"      (images de E70)
-- Sur le mod livré, le scénario s'arrête à l'init : « prototypes de test absents ».
--
-- E67 : durée réelle de preparing. 5 variantes (en-tête de a1_jetable_data.lua) x 4 répliques, chacune seule (64 tuiles
-- d'écart) ; au tick 60, une mitrailleuse ennemie SANS munitions apparaît à 8 tuiles à l'EST de chaque tourelle.
-- Mesures par tourelle : premier tick où l'orientation de la tête quitte sa valeur initiale (fin de la levée : la tête
-- ne tourne qu'une fois levée), premier tick où la cible perd des points de vie (premier tir).
--
-- E70 : orientation imposée et convention des directions. 8 directions (N, NE, E, SE, S, SO, O, NO), cible à 4 tuiles
-- (diagonales : 4, 4). Groupes :
--   G1 flèche, munitions, cible NEUTRE (coffre indestructible) imposée par shooting_target ;
--   G2 flèche, SANS munitions, même cible neutre imposée ;
--   G3 mitrailleuse vanilla, munitions, cible neutre imposée ;
--   G4 flèche, munitions, cible HOSTILE (gros ver ennemi, cessez-le-feu de l'ennemi envers le joueur ; la balle de 5
--      ne passe presque pas sa résistance physique), visée AUTOMATIQUE (référence : la tourelle vise d'elle-même) ;
--      sites à 64 tuiles d'écart ;
--   G5 flèche, munitions, AUCUNE cible : écriture directe de `orientation`.
-- Attendu si la convention est « 0 = nord, sens horaire » (doc RealOrientation) : orientation = j/8 pour la direction j.
-- Captures (session avec images) : chaque site de G4 et G5, NE et E de G1 et G2, au zoom 2 : la flèche numérotée dit
-- quelle image (0 à 63) le moteur dessine ; image k = flèche tournée de k x 360/64 degrés dans le sens horaire depuis
-- le haut ; ROUGE = tête levée (prepared, attacking), BLEUE = tête repliée (folded, preparing, folding).

local T0 = 60
local CHECK = 900
local E67 = { "a1-e67-v5", "a1-e67-i1", "a1-e67-r5", "a1-e67-i1-lent", "a1-e67-v5-lent" }
local REPL = 4
local DIRS = { { "N", 0, -4 }, { "NE", 4, -4 }, { "E", 4, 0 }, { "SE", 4, 4 }, { "S", 0, 4 }, { "SO", -4, 4 },
  { "O", -4, 0 }, { "NO", -4, -4 } }
local GROUPES = {
  { id = "G1", proto = "a1-e70-fleche", ammo = true, cible = "neutre", y = 1200, pas = 16 },
  { id = "G2", proto = "a1-e70-fleche", ammo = false, cible = "neutre", y = 1240, pas = 16 },
  { id = "G3", proto = "gun-turret", ammo = true, cible = "neutre", y = 1280, pas = 16 },
  { id = "G4", proto = "a1-e70-fleche", ammo = true, cible = "hostile", y = 1320, pas = 64 },
  { id = "G5", proto = "a1-e70-fleche", ammo = true, cible = "ecrite", y = 1360, pas = 16 },
}
local X0 = 1000
local ECHANT = { [T0] = true, [T0 + 1] = true, [T0 + 2] = true, [T0 + 5] = true, [T0 + 10] = true, [T0 + 20] = true,
  [T0 + 40] = true, [T0 + 80] = true, [T0 + 160] = true, [300] = true, [600] = true, [CHECK] = true }

local function ori(e)
  local ok, v = pcall(function() return e.orientation end)
  if ok then return v end
  return nil, v
end

local function attendu(dx, dy)
  local o = math.atan2(dx, -dy) / (2 * math.pi)
  if o < 0 then o = o + 1 end
  return o
end

local function ecart(a, b)
  local d = math.abs(a - b) % 1
  return math.min(d, 1 - d)
end

local function fmt(v)
  if v == nil then return "nil" end
  return string.format("%.5f", v)
end

return {
  description = "A1 : E67 (duree reelle de preparing) et E70 (shooting_target impose, origine et sens des directions)",
  base = nil,
  check_tick = CHECK,
  shots_delay = 320,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    local manque = {}
    for _, n in ipairs({ "a1-e67-v5", "a1-e67-i1", "a1-e67-r5", "a1-e67-i1-lent", "a1-e67-v5-lent", "a1-e70-fleche" }) do
      if not game.entity_prototypes[n] then manque[#manque + 1] = n end
    end
    if #manque > 0 then
      ctx.fail("prototypes de test presents (copie jetable tools/autotest/a1/jetable.py)", table.concat(manque, ", "))
      return
    end
    ctx.ok("prototypes de test presents", "5 variantes E67 + a1-e70-fleche")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", true) -- les cibles ennemies n'ont pas de munitions ; par sûreté
    ctx.log("player ennemi de enemy : " .. tostring(game.forces.player.get_cease_fire("enemy") == false))

    -- E67
    st.e67 = {}
    local i = 0
    for _, n in ipairs(E67) do
      for r = 1, REPL do
        local x, y = X0 + 64 * i, 1000
        i = i + 1
        ctx.prepare_area(x - 16, y - 16, x + 20, y + 16, "grass-1")
        local t = s.create_entity({ name = n, position = { x, y }, force = "player" })
        if t then t.insert({ name = "firearm-magazine", count = 20 }) end
        st.e67[#st.e67 + 1] = { nom = n, r = r, t = t, x = x, y = y }
      end
    end
    -- E70
    st.e70 = {}
    for _, g in ipairs(GROUPES) do
      for j, d in ipairs(DIRS) do
        local x, y = X0 + g.pas * (j - 1), g.y
        ctx.prepare_area(x - 8, y - 8, x + 8, y + 8, "grass-1")
        local t = s.create_entity({ name = g.proto, position = { x, y }, force = "player" })
        if t and g.ammo then t.insert({ name = "firearm-magazine", count = 20 }) end
        st.e70[#st.e70 + 1] = { g = g.id, cible = g.cible, dir = d[1], j = j - 1, dx = d[2], dy = d[3], t = t,
          x = x, y = y, att = attendu(d[2], d[3]), echant = {} }
      end
    end
    -- aucune entité ennemie naturelle près des sites
    local n_en = 0
    for _, e in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 40, 960 }, { X0 + 64 * 21, 1400 } } })) do
      e.destroy()
      n_en = n_en + 1
    end
    ctx.log("entites ennemies naturelles retirees : " .. n_en)
    local poses = 0
    for _, c in ipairs(st.e67) do if c.t then poses = poses + 1 end end
    for _, c in ipairs(st.e70) do if c.t then poses = poses + 1 end end
    ctx.check(poses == #st.e67 + #st.e70, "tourelles posees", poses .. " / " .. (#st.e67 + #st.e70))
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    local t = e.tick
    if t == T0 then
      for _, c in ipairs(st.e67) do
        if c.t and c.t.valid then
          c.o0 = ori(c.t)
          c.cible = s.create_entity({ name = "gun-turret", position = { c.x + 8, c.y }, force = "enemy" })
          c.pv0 = c.cible and c.cible.health
        end
      end
      for _, c in ipairs(st.e70) do
        if c.t and c.t.valid then
          c.o0 = ori(c.t)
          local pos = { c.x + c.dx, c.y + c.dy }
          if c.cible == "neutre" then
            c.ent = s.create_entity({ name = "wooden-chest", position = pos, force = "neutral" })
          elseif c.cible == "hostile" then
            -- gros ver : 750 PV, résistance physique « decrease 10 » : la balle de 5 ne l'entame presque pas
            c.ent = s.create_entity({ name = "big-worm-turret", position = pos, force = "enemy" })
          end
          if c.ent and c.cible == "neutre" then c.ent.destructible = false end
          if c.cible == "neutre" then
            local ok, err = pcall(function() c.t.shooting_target = c.ent end)
            c.ecrit = ok and "ok" or tostring(err)
          elseif c.cible == "ecrite" then
            local ok, err = pcall(function() c.t.orientation = c.att end)
            c.ecrit = ok and "ok" or tostring(err)
          end
        end
      end
    end
    if t >= T0 and t <= CHECK then
      for _, c in ipairs(st.e67) do
        if c.t and c.t.valid then
          local o = ori(c.t)
          if not c.t_tourne and o and c.o0 and math.abs(o - c.o0) > 1e-9 then c.t_tourne = t end
          if not c.t_tir and c.cible and c.cible.valid and c.cible.health < c.pv0 then c.t_tir = t end
          if not c.t_tir and c.cible and not c.cible.valid then c.t_tir = t end
        end
      end
      for _, c in ipairs(st.e70) do
        if c.t and c.t.valid then
          local o = ori(c.t)
          if o and not c.t_vise and ecart(o, c.att) < 1 / 256 then c.t_vise = t end
          if ECHANT[t] then
            local cib = nil
            pcall(function() cib = c.t.shooting_target end)
            c.echant[#c.echant + 1] = string.format("t%d=%s%s", t, fmt(o), cib and "" or "(sans cible)")
          end
          if t == CHECK then
            c.o_fin = o
            local cib = nil
            pcall(function() cib = c.t.shooting_target end)
            c.cible_fin = cib and cib.valid and (cib.name .. "@" .. cib.position.x .. "," .. cib.position.y) or "aucune"
            local inv = c.t.get_inventory(defines.inventory.turret_ammo)
            c.munitions_fin = inv and inv.get_item_count("firearm-magazine") or -1
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    -- E67
    ctx.log("E67 : variante ; replique ; orientation initiale ; tick ou la tete commence a tourner (depuis T0=" .. T0 ..
      ") ; tick du premier tir (depuis T0) ; PV cible")
    local par = {}
    for _, c in ipairs(st.e67) do
      local dt_t = c.t_tourne and (c.t_tourne - T0) or nil
      local dt_f = c.t_tir and (c.t_tir - T0) or nil
      ctx.log(string.format("E67 %-16s r%d o0=%s tourne=%s tir=%s pv=%s", c.nom, c.r, fmt(c.o0), tostring(dt_t),
        tostring(dt_f), tostring(c.cible and c.cible.valid and c.cible.health or "detruite")))
      par[c.nom] = par[c.nom] or { tourne = {}, tir = {} }
      if dt_t then table.insert(par[c.nom].tourne, dt_t) end
      if dt_f then table.insert(par[c.nom].tir, dt_f) end
    end
    local tous = true
    for _, n in ipairs(E67) do
      local p = par[n]
      ctx.log(string.format("E67 BILAN %-16s tourne apres [%s] ticks ; premier tir apres [%s] ticks", n,
        table.concat(p.tourne, ","), table.concat(p.tir, ",")))
      if #p.tir < REPL then tous = false end
    end
    ctx.check(tous, "E67 : chaque tourelle a tire sur sa cible", "")
    -- E70
    ctx.log("E70 : groupe ; direction ; orientation attendue (0 = nord, sens horaire) ; ecriture ; tick vise ; " ..
      "orientation finale ; cible finale ; munitions ; echantillons")
    local lisible = true
    for _, c in ipairs(st.e70) do
      if c.o_fin == nil then lisible = false end
      ctx.log(string.format("E70 %s %-2s att=%s ecrit=%s vise=%s fin=%s cible=%s mun=%s | %s", c.g, c.dir, fmt(c.att),
        tostring(c.ecrit), tostring(c.t_vise and (c.t_vise - T0) or nil), fmt(c.o_fin), tostring(c.cible_fin),
        tostring(c.munitions_fin), table.concat(c.echant, " ")))
    end
    ctx.check(lisible, "E70 : orientation de la tete lisible (LuaEntity.orientation) sur les 40 tourelles", "")
    local function groupe_ok(id)
      local n, ok = 0, 0
      for _, c in ipairs(st.e70) do
        if c.g == id then
          n = n + 1
          if c.o_fin and ecart(c.o_fin, c.att) < 1 / 256 then ok = ok + 1 end
        end
      end
      return ok, n
    end
    for _, id in ipairs({ "G4", "G1", "G2", "G3", "G5" }) do
      local ok, n = groupe_ok(id)
      ctx.log(string.format("E70 %s : %d / %d tetes sur l'orientation attendue (0 = nord, sens horaire)", id, ok, n))
    end
    local ok4, n4 = groupe_ok("G4")
    ctx.check(ok4 == n4, "E70 G4 (visee automatique) : orientation = j/8 pour la direction j (0 = nord, sens horaire)",
      ok4 .. " / " .. n4)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    for _, c in ipairs(st.e70) do
      -- G4 et G5 : les 8 directions ; G1 et G2 (cible imposée refusée au premier passage) : NE et E seulement
      if c.g == "G4" or c.g == "G5" or ((c.g == "G1" or c.g == "G2") and (c.j == 1 or c.j == 2)) then
        add(string.format("e70-%s-%s-%s", c.g, c.j, c.dir), c.x + c.dx / 2, c.y + c.dy / 2 - 0.5, 2, 0,
          { res = { 448, 448 }, info = false, aa = false })
      end
    end
  end,
}
