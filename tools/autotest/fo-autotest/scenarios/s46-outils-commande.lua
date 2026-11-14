-- Lot s46 OUTILS-COMMANDE : les quatre outils de commandement joués en moteur réel, sans humain, par l'interface de banc fo-commande
-- (même gestionnaire que la sélection à la souris). Partie du DC (votre équipe fondée d'office, scenarios/verif_guide_common).
--   t≈600  Maj + A (slot 1) sur le gisement de fer le plus proche du QG sans avant-poste ;
--   t≈900  Maj + A en slot 2 (Maj enfoncée) sur un gisement de cuivre (sinon charbon) ;
--   t≈1200 Maj + Z rayon 40 autour du QG ;
--   t≈1500 coffre d'équipe garni de 20 tourelles, Maj + R à 60 tuiles du QG ;
--   Maj + E dès qu'une sortie et un quai finis du même objet existent (essai toutes les 5 min ; à 20 min sans paire, sur deux zones du
--   QG pour lire la cause écrite par le mod).
-- Journal : [FO-CMD-BANC] toutes les 5 min. banc.py --qui s46-outils -- 108400 s46-outils-commande <source>
local base = require("scenarios/verif_guide_common")(30, true)
local TAG = "[FO-CMD-BANC] "
local EVERY = 18000

local function S(ctx)
  local st = ctx.state()
  st.s46 = st.s46 or { mine = {}, gis_ok = {}, turrets = {}, hist = {}, tries = 0 }
  return st.s46
end

local function etat(ctx) return ctx.remote("fo-commande", "etat") end

local function res_names(pat)
  local out = {}
  for name, _ in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } })) do
    if name:find(pat, 1, true) then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

--- Case de minerai la plus proche du QG, à plus de `away` tuiles des points `excl`.
local function nearest(ctx, names, hq, excl, away)
  if #names == 0 then return nil end
  local s = ctx.surface()
  for _, r in ipairs({ 48, 96, 160, 256, 384 }) do
    local best, bd
    for _, e in ipairs(s.find_entities_filtered({ type = "resource", name = names, position = hq, radius = r })) do
      local p = e.position
      local far = true
      for _, q in ipairs(excl) do
        if (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 < away * away then far = false break end
      end
      if far then
        local d = (p.x - hq.x) ^ 2 + (p.y - hq.y) ^ 2
        if not bd or d < bd then best, bd = p, d end
      end
    end
    if best then return best end
  end
  return nil
end

local function order(ctx, outil, slot, x0, y0, x1, y1, label)
  local r = ctx.remote("fo-commande", "ordre", outil, slot, math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1))
  local s = S(ctx)
  ctx.log(string.format("%s : %s slot %d zone (%d,%d)-(%d,%d) a %.1f min : gestionnaire %s, ordre %s, messages %s", label, outil, slot,
    x0, y0, x1, y1, game.tick / 3600, tostring(r.appel), tostring(r.id), table.concat(r.prints or {}, " | ")))
  if r.id then
    local rec = { id = r.id, label = label, tick = game.tick }
    for _, o in ipairs(etat(ctx).orders or {}) do
      if o.id == r.id then rec.kind, rec.x, rec.y, rec.r, rec.outpost, rec.resource = o.kind, o.x, o.y, o.r, o.outpost, o.resource end
    end
    s.mine[#s.mine + 1] = rec
  end
  return r
end

local function turret_item()
  local names = {}
  for name, p in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "ammo-turret" } })) do
    if p.items_to_place_this and p.items_to_place_this[1] then names[#names + 1] = p.items_to_place_this[1].name end
  end
  table.sort(names)
  -- 1er banc (14/11) : « fo-bastion-1 » (premier par le nom) n'est pas la tourelle du stock de défense (T.turret, lue au journal
  -- [FO-FER-SORTIE] : craft:gun-turret) : la tourelle de base d'abord quand elle existe.
  for _, n in ipairs(names) do if n == "gun-turret" then return n end end
  local force = game.forces.player
  for _, n in ipairs(names) do
    local rec = force.recipes[n]
    if rec and rec.enabled then return n end
  end
  return names[1]
end

local function report(ctx)
  local s = S(ctx)
  local e = etat(ctx)
  local orders = {}
  for _, o in ipairs(e.orders or {}) do orders[#orders + 1] = string.format("#%d %s (%d,%d) r%d%s", o.id, o.kind, o.x, o.y, o.r, o.done and (" " .. o.done) or "") end
  local hist = {}
  for _, h in ipairs(e.hist or {}) do hist[#hist + 1] = "#" .. h.id .. " " .. h.text end
  ctx.log(TAG .. string.format("minute %d | QG %s | ordres vivants %d : %s | traces : %s | avant-postes %d | quais %d sorties %d",
    math.floor(game.tick / 3600), e.hq and (math.floor(e.hq.x) .. "," .. math.floor(e.hq.y)) or "-", #(e.orders or {}), table.concat(orders, " ; "),
    table.concat(hist, " ; "), #(e.outposts or {}), #(e.docks or {}), #(e.srcs or {})))
  for _, m in ipairs(s.mine) do
    if m.x then
      local best, bd
      for _, op in ipairs(e.outposts or {}) do
        if m.kind ~= "gisement" or op.kind == m.outpost then
          local d = math.sqrt((op.x - m.x) ^ 2 + (op.y - m.y) ^ 2)
          if not bd or d < bd then best, bd = op, d end
        end
      end
      ctx.log(TAG .. string.format("  ordre %d (%s, %s) zone (%d,%d) r%d : avant-poste le plus proche %s a %s tuiles du centre (%s foreuses)%s%s", m.id,
        m.label, tostring(m.kind), m.x, m.y, m.r, best and ("#" .. tostring(best.id) .. " " .. tostring(best.kind)) or "aucun",
        bd and string.format("%.0f", bd) or "-", best and tostring(best.drills) or "-",
        s.gis_ok[m.id] and string.format(" ; DANS la zone avec foreuses a %.1f min", s.gis_ok[m.id]) or "",
        m.kind == "bastion" and string.format(" ; tourelles dans la zone %d (max %d)", s.turrets[m.id] or 0, s.turrets_max and s.turrets_max[m.id] or 0) or ""))
    end
  end
end

local function minute_watch(ctx)
  local s = S(ctx)
  local e = etat(ctx)
  for _, h in ipairs(e.hist or {}) do s.hist[h.id] = h.text end
  s.turrets_max = s.turrets_max or {}
  for _, m in ipairs(s.mine) do
    if m.kind == "gisement" and not s.gis_ok[m.id] then
      for _, op in ipairs(e.outposts or {}) do
        local d2 = (op.x - m.x) ^ 2 + (op.y - m.y) ^ 2
        if op.kind == m.outpost and (op.drills or 0) > 0 and d2 <= (m.r + 16) ^ 2 then
          s.gis_ok[m.id] = game.tick / 3600
          s.gis_op = s.gis_op or {}
          s.gis_op[m.id] = string.format("avant-poste #%s (%d foreuses) a %.0f tuiles du centre", tostring(op.id), op.drills, math.sqrt(d2))
          ctx.log(string.format("gisement : ordre %d servi a %.1f min : %s", m.id, s.gis_ok[m.id], s.gis_op[m.id]))
          break
        end
      end
    elseif m.kind == "bastion" then
      local n = ctx.surface().count_entities_filtered({ position = { m.x, m.y }, radius = m.r, force = "player", type = "ammo-turret" })
      s.turrets[m.id] = n
      if n > (s.turrets_max[m.id] or 0) then s.turrets_max[m.id] = n end
    end
  end
end

local function try_liaison(ctx, force_zone)
  local s = S(ctx)
  local e = etat(ctx)
  s.tries = s.tries + 1
  local pick
  for _, src in ipairs(e.srcs or {}) do
    if src.item and not src.linked then
      for _, d in ipairs(e.docks or {}) do
        if d.item == src.item and not d.linked then pick = { src = src, dock = d } break end
      end
    end
    if pick then break end
  end
  if not pick and not force_zone then
    ctx.log(string.format("liaison : essai %d a %.1f min : aucune paire sortie / quai finis du meme objet (quais %d, sorties %d)", s.tries,
      game.tick / 3600, #(e.docks or {}), #(e.srcs or {})))
    return false
  end
  local a, b
  if pick then a, b = pick.src, pick.dock
  else
    s.liaison_forcee = true
    a, b = { x = e.hq.x - 20, y = e.hq.y }, { x = e.hq.x + 20, y = e.hq.y }
    ctx.log("liaison : aucune paire en 20 min : ordre pose sur deux zones du QG pour lire la cause ecrite par le mod")
  end
  order(ctx, "fo-cmd-liaison", 1, a.x - 3, a.y - 3, a.x + 3, a.y + 3, "Maj+E point A")
  order(ctx, "fo-cmd-liaison", 2, b.x - 3, b.y - 3, b.x + 3, b.y + 3, "Maj+E point B")
  s.liaison_done = true
  return true
end

local init0, tick0 = base.init, base.tick
base.description = "s46 outils : Maj+A/Z/E/R joues par l'interface fo-commande, preuve des ordres en moteur"
base.check_tick = 108000
base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.has("fo-commande", "ordre") and ctx.has("fo-commande", "etat"), "interface de banc fo-commande presente")
end
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick % 60 ~= 0 then return end
  local s = S(ctx)
  local st = etat(ctx)
  if not (st.equipe and st.hq) then return end
  local hq = st.hq
  if e.tick >= 600 and not s.a1 then
    s.a1 = true
    local excl = {}
    for _, op in ipairs(st.outposts or {}) do excl[#excl + 1] = { x = op.x, y = op.y } end
    local p = nearest(ctx, res_names("iron"), hq, excl, 40)
    if p then order(ctx, "fo-cmd-gisement", 1, p.x - 16, p.y - 16, p.x + 16, p.y + 16, "Maj+A fer")
    else ctx.log("Maj+A fer : aucun gisement de fer sans avant-poste trouve") end
  end
  if e.tick >= 900 and not s.a2 then
    s.a2 = true
    local excl = {}
    for _, op in ipairs(st.outposts or {}) do excl[#excl + 1] = { x = op.x, y = op.y } end
    for _, m in ipairs(s.mine) do if m.x then excl[#excl + 1] = { x = m.x, y = m.y } end end
    local p = nearest(ctx, res_names("copper"), hq, excl, 40)
    local lab = "Maj+A (slot 2) cuivre"
    if not p then p, lab = nearest(ctx, res_names("coal"), hq, excl, 40), "Maj+A (slot 2) charbon" end
    if p then order(ctx, "fo-cmd-gisement", 2, p.x - 16, p.y - 16, p.x + 16, p.y + 16, lab)
    else ctx.log("Maj+A slot 2 : aucun gisement de cuivre ni de charbon trouve") end
  end
  if e.tick >= 1200 and not s.z then
    s.z = true
    order(ctx, "fo-cmd-amelioration", 1, hq.x - 29, hq.y - 29, hq.x + 29, hq.y + 29, "Maj+Z QG")
  end
  if e.tick >= 1500 and not s.r then
    s.r = true
    local chest = ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
    local item = turret_item()
    local put = (chest and item) and chest.insert({ name = item, count = 20 }) or 0
    ctx.log(string.format("coffre d'equipe : %d %s inseres (coffre %s)", put, tostring(item), tostring(chest ~= nil)))
    s.put = put
    -- 3e banc : diagnostic de ce qui occupe chaque point à 60 tuiles du QG (2e banc : (66, 6) refusé, « aucun emplacement libre »),
    -- puis le point au moins de minerai (aucune tourelle n'est posée sur une ressource : règle du mod)
    local sf = ctx.surface()
    local best, bn
    for _, d in ipairs({ { 60, 0 }, { 0, 60 }, { -60, 0 }, { 0, -60 }, { 42, 42 }, { -42, 42 }, { -42, -42 }, { 42, -42 } }) do
      local c = { hq.x + d[1], hq.y + d[2] }
      local function cnt(ty) return sf.count_entities_filtered({ position = c, radius = 14, type = ty }) end
      local res, tree, rock = cnt("resource"), cnt("tree"), cnt("simple-entity")
      local own = sf.count_entities_filtered({ position = c, radius = 14, force = "player" })
      local okw, water = pcall(sf.count_tiles_filtered, { position = c, radius = 14, collision_mask = "water-tile" })
      if not okw then water = 0 end
      ctx.log(string.format("bastion : point (%d, %d) rayon 14 : minerai %d, arbres %d, rochers et decors %d, entites de l'equipe %d, eau %d",
        c[1], c[2], res, tree, rock, own, water))
      local score = res + water * 4 + own
      if not bn or score < bn then best, bn = c, score end
    end
    order(ctx, "fo-cmd-bastion", 1, best[1] - 10, best[2] - 10, best[1] + 10, best[2] + 10, "Maj+R a 60 tuiles")
  end
  -- 3e banc : la cause « munitions » (chargeurs du coffre trop bas pour le lot) : le coffre est remis à 200 chargeurs chaque minute
  if s.r and e.tick % 3600 == 0 then
    local chest = ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
    local ammo = "firearm-magazine"
    if chest and game.item_prototypes[ammo] then
      local have = chest.get_item_count(ammo)
      if have < 200 then
        local put = chest.insert({ name = ammo, count = 200 - have })
        s.ammo_put = (s.ammo_put or 0) + put
        ctx.log(string.format("coffre d'equipe : %d chargeur(s) remis (avait %d) a %.1f min", put, have, game.tick / 3600))
      end
    end
  end
  if e.tick >= 1800 and not s.liaison_done and e.tick % EVERY == 0 then try_liaison(ctx, e.tick >= 72000) end
  if e.tick % 3600 == 0 then minute_watch(ctx) end
  if e.tick % EVERY == 0 then report(ctx) end
end
base.finish = function(ctx)
  minute_watch(ctx)
  report(ctx)
  local s = S(ctx)
  local by = {}
  for _, m in ipairs(s.mine) do
    by[m.kind] = by[m.kind] or {}
    table.insert(by[m.kind], m)
  end
  local gis = by.gisement or {}
  ctx.check(#gis == 2, "Maj+A : deux ordres de gisement acceptes (slot 1 et slot 2 Maj enfoncee)", #gis)
  for _, m in ipairs(gis) do
    ctx.check(s.gis_ok[m.id] ~= nil and s.gis_ok[m.id] <= 30, string.format("Maj+A ordre %d (%s) : avant-poste de l'equipe DANS la zone avec foreuses avant 30 min", m.id, m.label),
      s.gis_ok[m.id] and (string.format("%.1f min : ", s.gis_ok[m.id]) .. tostring(s.gis_op and s.gis_op[m.id])) or "jamais")
  end
  local am = (by.amelioration or {})[1]
  ctx.check(am ~= nil, "Maj+Z : ordre d'amelioration accepte")
  ctx.check(am ~= nil and s.hist[am.id] ~= nil, "Maj+Z : prise en compte ecrite", am and tostring(s.hist[am.id]))
  local bs = (by.bastion or {})[1]
  ctx.check(bs ~= nil, "Maj+R : ordre de bastion accepte", s.put)
  ctx.check(bs ~= nil and (s.turrets_max and s.turrets_max[bs.id] or 0) > 0, "Maj+R : tourelles posees dans la zone du bastion",
    bs and (s.turrets_max and s.turrets_max[bs.id] or 0))
  local li = (by.liaison or {})[1]
  ctx.check(li ~= nil, "Maj+E : ordre de liaison accepte (point A puis B)", s.liaison_forcee and "zones du QG (aucune paire finie)" or "paire finie")
  ctx.check(li ~= nil and s.hist[li.id] ~= nil, "Maj+E : prise en compte ou cause de refus ecrite", li and tostring(s.hist[li.id]))
end
return base
