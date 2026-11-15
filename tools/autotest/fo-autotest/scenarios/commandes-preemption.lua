-- Lot c4b (preuve du CHANTIER 4 du DC, en moteur réel) : un ordre Maj+A posé PENDANT un chantier entrepreneur qui n'est pas un ordre, sur
-- la partie des jalons (votre équipe fondée d'office + 4 factions ; carte du DC : banc.py --carte-max --mgs tools/autotest/carte_dc_mgs.json).
-- Condition (pas une minute fixe) : à partir de 20 min, le premier relevé (chaque seconde) où l'équipe « player » a un chantier entrepreneur
-- vivant SANS ordre (interface fo-commande etat.ent) ; filet : 40 min. L'ordre vise le fer le plus proche du QG à 40 tuiles au moins des
-- avant-postes et des champs ; refus de la bande (aucun réseau, champ plein) : ordre annulé, gisement suivant (4 essais).
-- Mesures (ticks depuis l'ordre, lues dans l'état du mod, script/gui/commande.lua et script/team/migration_champ.lua) : réveil de
-- l'entrepreneur (t_ent), suspension du chantier d'avant (t_susp), première tâche émise (jalon tache), premier ouvrier en route, première pose
-- SUR le gisement (maja_0916 : poses nouvelles seulement), reprise du chantier suspendu. Ensuite, à 30 min au plus tôt et 2 min après Maj+A :
-- Maj+Z (zone du QG), Maj+E (avant-poste le plus proche -> QG), Maj+R (60 tuiles du QG) : tâche, route, pose.
-- banc.py --carte-max --mgs tools/autotest/carte_dc_mgs.json --graine 123456789 --qui c4b -- 217000 commandes-preemption <source>
local base = require("scenarios/jalons_common")(60)
local TAG = "[FO-PREEMPTION] "
local T_MIN, T_FILET, T_ZER = 20 * 3600, 40 * 3600, 30 * 3600

local function S(ctx)
  local st = ctx.state()
  st.pre = st.pre or { tries = 0, mine = {}, excl = {} }
  return st.pre
end
local function etat(ctx) return ctx.remote("fo-commande", "etat") end
local function sec(v) return v and string.format("%d ticks (%.1f s)", v, v / 60) or "jamais" end

local function iron_names()
  local out = {}
  for name, _ in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } })) do
    if name:find("iron", 1, true) then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

local function far_from(p, list, d)
  for _, q in ipairs(list) do
    if (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 < d * d then return false end
  end
  return true
end

local function pick_iron(ctx, st, s)
  local excl = {}
  for _, op in ipairs(st.outposts or {}) do excl[#excl + 1] = { x = op.x, y = op.y } end
  for _, fl in ipairs(st.fields or {}) do excl[#excl + 1] = { x = fl.x, y = fl.y } end
  for _, q in ipairs(s.excl) do excl[#excl + 1] = q end
  local hq, names = st.hq, iron_names()
  if #names == 0 then return nil end
  for _, r in ipairs({ 96, 160, 256, 384 }) do
    local best, bd
    for _, e in ipairs(ctx.surface().find_entities_filtered({ type = "resource", name = names, position = hq, radius = r })) do
      local p = e.position
      if far_from(p, excl, 40) then
        local d = (p.x - hq.x) ^ 2 + (p.y - hq.y) ^ 2
        if not bd or d < bd or (d == bd and (p.x < best.x or (p.x == best.x and p.y < best.y))) then best, bd = p, d end
      end
    end
    if best then return best end
  end
  return nil
end

local function order(ctx, outil, slot, x0, y0, x1, y1, label)
  local r = ctx.remote("fo-commande", "ordre", outil, slot, math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1))
  ctx.log(string.format("%s%s : %s slot %d zone (%d,%d)-(%d,%d) a %.2f min (tick %d) : ordre %s, messages %s", TAG, label, outil, slot, x0, y0, x1, y1,
    game.tick / 3600, game.tick, tostring(r.id), table.concat(r.prints or {}, " | ")))
  if r.id then table.insert(S(ctx).mine, { id = r.id, label = label, tick = game.tick }) end
  return r
end

local function order_row(st, id)
  for _, o in ipairs(st.orders or {}) do if o.id == id then return o end end
  return nil
end
local function delay_row(st, id)
  for _, d in ipairs(st.delais or {}) do if d.id == id then return d end end
  return nil
end

local function place_a(ctx, s, st)
  local p = pick_iron(ctx, st, s)
  if not p then
    ctx.log(TAG .. "Maj+A : aucun gisement de fer libre")
    s.a_given_up = true
    return
  end
  s.tries = s.tries + 1
  s.excl[#s.excl + 1] = { x = p.x, y = p.y }
  local ent = st.ent or {}
  s.busy = { pid = ent.pid, state = ent.state, ordre = ent.ordre, wait = ent.wait }
  local r = order(ctx, "fo-cmd-gisement", 1, p.x - 8, p.y - 8, p.x + 8, p.y + 8, string.format("Maj+A fer (essai %d)", s.tries))
  s.a = r.id and { id = r.id, tick = game.tick, x = p.x, y = p.y, ent_pid = ent.pid } or nil
  ctx.log(string.format("%sMaj+A pose : chantier entrepreneur au moment de l'ordre : projet %s (etat %s, ordre %s, attente %s)", TAG, tostring(ent.pid),
    tostring(ent.state), tostring(ent.ordre), tostring(ent.wait)))
end

local function zer(ctx, s, st)
  local hq = st.hq
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
  local op0, od
  for _, op in ipairs(st.outposts or {}) do
    local d = (op.x - hq.x) ^ 2 + (op.y - hq.y) ^ 2
    if d > 30 * 30 and (not od or d < od) then op0, od = op, d end
  end
  local a = op0 and { x = op0.x, y = op0.y } or { x = hq.x - 20, y = hq.y }
  order(ctx, "fo-cmd-liaison", 1, a.x - 3, a.y - 3, a.x + 3, a.y + 3, "Maj+E point A")
  order(ctx, "fo-cmd-liaison", 2, hq.x - 3, hq.y - 3, hq.x + 3, hq.y + 3, "Maj+E point B (QG)")
end

local function report(ctx, word)
  local s = S(ctx)
  local st = etat(ctx)
  for _, m in ipairs(s.mine) do
    local d, o = delay_row(st, m.id), order_row(st, m.id)
    local t0 = m.tick
    ctx.log(string.format("%s%s minute %.0f : ordre %d (%s) : reveil entrepreneur %s, suspension %s, tache %s, route %s, plan %s, pose %s, fin %s ; poses %s ; champ %s (%s)",
      TAG, word, game.tick / 3600, m.id, m.label, sec(o and o.t_ent and (o.t_ent - t0) or (s.a and s.a.id == m.id and s.a.t_ent)),
      sec(o and o.t_susp and (o.t_susp - t0) or (s.a and s.a.id == m.id and s.a.t_susp)), sec(d and d.tache), sec(d and d.route), sec(d and d.ghost),
      sec(d and d.pose), sec(d and d.fin), tostring(d and d.n_new), tostring(o and o.band_fid), tostring(o and o.band_msg)))
  end
  if s.a then
    ctx.log(string.format("%s%s : chantier suspendu %s, reprise %s", TAG, word, tostring(s.a.ent_pid), s.a.resume and sec(s.a.resume - s.a.tick) or "jamais"))
  end
end

local init0, tick0 = base.init, base.tick
base.description = "c4b : ordre Maj+A pendant un chantier entrepreneur (suspension, reveil, tache, pose, reprise) puis Maj+Z/E/R apres 30 min"
base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.has("fo-commande", "ordre") and ctx.has("fo-commande", "etat"), "interface de banc fo-commande presente")
end
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick % 60 ~= 0 or e.tick < T_MIN then return end
  local s = S(ctx)
  local st = etat(ctx)
  if not (st.equipe and st.hq) then return end
  local ent = st.ent or {}
  if not s.a and not s.a_given_up then
    local busy = ent.pid ~= nil and not ent.ordre and ent.state ~= nil and ent.state ~= "fini"
    if busy or e.tick >= T_FILET then
      if not busy then ctx.log(TAG .. "filet de 40 min : aucun chantier entrepreneur sans ordre vu, ordre pose quand meme") end
      place_a(ctx, s, st)
    end
    return
  end
  if s.a then
    local o = order_row(st, s.a.id)
    -- bande refusée (aucun réseau, champ plein) dans les 20 s : annulé, gisement suivant
    if o and not o.band_fid and o.band_msg and o.band_msg:find("refus", 1, true) and e.tick - s.a.tick >= 1200 and not s.a.t_ent and s.tries < 4 then
      ctx.log(string.format("%sMaj+A ordre %d : bande refusee (%s) : annule, gisement suivant", TAG, s.a.id, o.band_msg))
      order(ctx, "fo-cmd-gisement", 3, s.a.x - 8, s.a.y - 8, s.a.x + 8, s.a.y + 8, "annulation")
      s.a = nil
      return
    end
    if o and o.t_ent and not s.a.t_ent then s.a.t_ent = o.t_ent - s.a.tick end
    if o and o.t_susp and not s.a.t_susp then s.a.t_susp = o.t_susp - s.a.tick end
    if s.a.ent_pid and not s.a.resume and ent.pid == s.a.ent_pid and not ent.ordre then
      s.a.resume = e.tick
      ctx.log(string.format("%sreprise du chantier suspendu %d a %.1f min (%s apres l'ordre)", TAG, s.a.ent_pid, e.tick / 3600, sec(e.tick - s.a.tick)))
    end
  end
  if s.a and not s.zer and e.tick >= T_ZER and e.tick >= s.a.tick + 7200 then
    s.zer = true
    zer(ctx, s, st)
  end
  if e.tick % 3600 == 0 then report(ctx, "BANC") end
end
base.finish = function(ctx)
  report(ctx, "BILAN")
  local s = S(ctx)
  local st = etat(ctx)
  ctx.check(s.a ~= nil and s.busy and s.busy.pid ~= nil and not s.busy.ordre, "Maj+A pose pendant un chantier entrepreneur sans ordre",
    s.busy and tostring(s.busy.pid) or "aucun")
  ctx.check(s.a ~= nil and s.a.t_susp ~= nil and s.a.t_susp <= 300, "Maj+A : chantier d'avant suspendu en 300 ticks au plus", s.a and sec(s.a.t_susp))
  ctx.check(s.a ~= nil and s.a.t_ent ~= nil and s.a.t_ent <= 300, "Maj+A : entrepreneur reveille en 300 ticks au plus", s.a and sec(s.a.t_ent))
  ctx.check(s.a ~= nil and s.a.resume ~= nil, "chantier suspendu repris", s.a and s.a.resume and sec(s.a.resume - s.a.tick))
  for _, m in ipairs(s.mine) do
    local d = delay_row(st, m.id)
    if m.label ~= "annulation" and m.label ~= "Maj+E point A" then
      ctx.check(d ~= nil and d.tache ~= nil and d.tache <= 300, "ordre " .. m.label .. " : premiere tache en 300 ticks au plus", d and sec(d.tache))
    end
  end
end
return base
