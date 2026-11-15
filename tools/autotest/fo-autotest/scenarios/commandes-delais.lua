-- Lot commandes-0716 : DÉLAIS des quatre outils de commandement (Maj + A / Z / E / R) joués par le joueur à T + 5 min, en moteur réel
-- et sans écran, sur la partie des jalons (votre équipe fondée d'office + 4 factions, scenarios/jalons_common.lua ; carte du DC par
-- banc.py --carte-max --mgs tools/autotest/carte_dc_mgs.json). Les ordres passent par l'interface de banc fo-commande (MÊME gestionnaire
-- que la sélection à la souris) ; le mod mesure lui-même chaque jalon (script/gui/commande.lua, journal [FO-COMMANDE] « jalon ») :
--   route = premier ouvrier de l'équipe en route vers la zone, ghost = premier plan (fantôme), pose = première entité de l'équipe posée
--   dans la zone après l'ordre, fin = effet complet (gisement : avant-poste posé ; bastion : groupe de tourelles ; liaison : servie).
-- À t = 5 min : Maj + A sur le fer le plus proche sans avant-poste, Maj + Z rayon 41 autour du QG, Maj + R à 60 tuiles du QG, Maj + E
-- (point A puis B) sur une paire sortie / quai finie s'il y en a, sinon sur deux zones du QG ; ensuite, une vraie paire apparue
-- (essai chaque minute) reçoit son propre ordre de liaison, mesuré depuis sa pose. Rien n'est donné à l'équipe (ni tourelle, ni munition).
-- Bilan : [FO-COMMANDE] BANC chaque minute après les ordres, [FO-COMMANDE] BILAN à la fin.
-- banc.py --carte-max --mgs tools/autotest/carte_dc_mgs.json --qui commandes -- 108400 commandes-delais <source>
local base = require("scenarios/jalons_common")(30)
local TAG = "[FO-COMMANDE] "
local T_ORDRE = 5 * 3600

local function S(ctx)
  local st = ctx.state()
  st.cmdd = st.cmdd or { mine = {} }
  return st.cmdd
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
  ctx.log(string.format("%sBANC %s : %s slot %d zone (%d,%d)-(%d,%d) a %.2f min : gestionnaire %s, ordre %s, messages %s", TAG, label, outil,
    slot, x0, y0, x1, y1, game.tick / 3600, tostring(r.appel), tostring(r.id), table.concat(r.prints or {}, " | ")))
  if r.id then table.insert(S(ctx).mine, { id = r.id, label = label, tick = game.tick }) end
  return r
end

local function pair_of(e)
  for _, src in ipairs(e.srcs or {}) do
    if src.item and not src.linked then
      for _, d in ipairs(e.docks or {}) do
        if d.item == src.item and not d.linked then return src, d end
      end
    end
  end
  return nil
end

local function liaison(ctx, a, b, label)
  order(ctx, "fo-cmd-liaison", 1, a.x - 3, a.y - 3, a.x + 3, a.y + 3, label .. " point A")
  order(ctx, "fo-cmd-liaison", 2, b.x - 3, b.y - 3, b.x + 3, b.y + 3, label .. " point B")
end

local function sec(v) return v and string.format("%d s", math.floor(v / 60)) or "jamais" end

local function rows(ctx)
  local s = S(ctx)
  local by = {}
  for _, d in ipairs(etat(ctx).delais or {}) do by[d.id] = d end
  local out = {}
  for _, m in ipairs(s.mine) do
    local d = by[m.id]
    if d then out[#out + 1] = { m = m, d = d } end
  end
  return out
end

local function report(ctx, word)
  for _, x in ipairs(rows(ctx)) do
    local d, m = x.d, x.m
    ctx.log(string.format("%s%s minute %.0f : ordre %d (%s, %s) en (%d, %d) r%d : route %s, plan %s, pose %s, fin %s ; entites posees %d",
      TAG, word, game.tick / 3600, d.id, d.kind, m.label, d.x, d.y, d.r, sec(d.route), sec(d.ghost), sec(d.pose), sec(d.fin), d.n_new or 0))
  end
end

local init0, tick0 = base.init, base.tick
base.description = "commandes-0716 : delais des outils Maj+A/Z/E/R joues a 5 min (premier ouvrier en route, premiere pose, effet complet)"
base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.has("fo-commande", "ordre") and ctx.has("fo-commande", "etat"), "interface de banc fo-commande presente")
end
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick % 60 ~= 0 or e.tick < T_ORDRE then return end
  local s = S(ctx)
  local st = etat(ctx)
  if not (st.equipe and st.hq) then
    if e.tick == T_ORDRE then ctx.log(TAG .. "BANC : aucune equipe ou aucun QG a 5 min, ordres differes") end
    return
  end
  local hq = st.hq
  if not s.done then
    s.done = true
    local excl = {}
    for _, op in ipairs(st.outposts or {}) do excl[#excl + 1] = { x = op.x, y = op.y } end
    local p = nearest(ctx, res_names("iron"), hq, excl, 40)
    -- 1er banc : une zone de 32 tuiles sur le gisement mêlé de la carte du DC donnait un ordre de CHARBON (majorité) : zone de 16 tuiles
    -- (la zone de 32 tuiles est gardée en second ordre : gisement mêlé, refusé 25 min au 1er banc pour « espacement » avec le site de fer)
    if p then
      order(ctx, "fo-cmd-gisement", 1, p.x - 8, p.y - 8, p.x + 8, p.y + 8, "Maj+A fer")
      order(ctx, "fo-cmd-gisement", 2, p.x - 16, p.y - 16, p.x + 16, p.y + 16, "Maj+A gisement mele (zone 32)")
    else ctx.log(TAG .. "BANC Maj+A : aucun gisement de fer sans avant-poste") end
    order(ctx, "fo-cmd-amelioration", 1, hq.x - 29, hq.y - 29, hq.x + 29, hq.y + 29, "Maj+Z QG")
    local sf = ctx.surface()
    local best, bn
    for _, d in ipairs({ { 60, 0 }, { 0, 60 }, { -60, 0 }, { 0, -60 }, { 42, 42 }, { -42, 42 }, { -42, -42 }, { 42, -42 } }) do
      local c = { hq.x + d[1], hq.y + d[2] }
      local res = sf.count_entities_filtered({ position = c, radius = 14, type = "resource" })
      local own = sf.count_entities_filtered({ position = c, radius = 14, force = "player" })
      local okw, water = pcall(sf.count_tiles_filtered, { position = c, radius = 14, collision_mask = "water-tile" })
      local score = res + (okw and water or 0) * 4 + own
      if not bn or score < bn then best, bn = c, score end
    end
    order(ctx, "fo-cmd-bastion", 1, best[1] - 10, best[2] - 10, best[1] + 10, best[2] + 10, "Maj+R a 60 tuiles")
    local a, b = pair_of(st)
    if a then liaison(ctx, a, b, "Maj+E paire"); s.pair = true
    else liaison(ctx, { x = hq.x - 20, y = hq.y }, { x = hq.x + 20, y = hq.y }, "Maj+E QG (aucune paire finie)") end
    return
  end
  if not s.pair and e.tick % 3600 == 0 then
    local a, b = pair_of(st)
    if a then liaison(ctx, a, b, "Maj+E paire apparue"); s.pair = true end
  end
  if e.tick % 3600 == 0 then report(ctx, "BANC") end
end
base.finish = function(ctx)
  report(ctx, "BILAN")
  local by = {}
  for _, x in ipairs(rows(ctx)) do by[x.d.kind] = by[x.d.kind] or x.d end
  for _, k in ipairs({ "gisement", "amelioration", "bastion", "liaison" }) do
    local d = by[k]
    ctx.check(d ~= nil, "ordre " .. k .. " pose a 5 min")
    ctx.check(d ~= nil and d.route ~= nil and d.route <= 3600, "ordre " .. k .. " : premier ouvrier en route en moins de 60 s", d and sec(d.route))
  end
end
return base
