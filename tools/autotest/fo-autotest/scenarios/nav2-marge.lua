--[[
  Lot NAV2 (3/11) : pourquoi la tournée d'un avant-poste DENSE rend « chemin introuvable (no_path) » (partie lot-271828182 du lot
  CHARBON-MAIN : Écarlate, avant-poste de charbon 1 de 29 foreuses, 90 no_path de tournée ; but libre pour le corps, sol sans eau).

  Hypothèse : le mod demande ses chemins avec la boîte du corps ÉLARGIE de 0,15 tuile par côté (script/agents/nav.lua,
  C.PATH_BBOX_PAD) : 0,7 tuile de large. Entre deux foreuses à combustion voisines (boîtes de 1,4) il reste 0,6 tuile, entre une
  foreuse et un coffre 0,45 : le corps (0,4) y passe, la boîte élargie non. Un but au milieu d'un champ dense est alors fermé pour
  le pathfinder.

  Banc de MESURE (moteur réel, aucun changement du mod hormis la commande de banc bench_extend) : un gisement de charbon de rayon 9,
  un avant-poste de votre équipe agrandi jusqu'au plein (Outposts.build puis Outposts.extend, la pose réelle), puis des demandes de
  chemin BRUTES (surface.request_path) depuis 8 points à 22 tuiles vers un point libre au centre du champ, pour 4 réglages :
    K1 marge 0,15, résolution 0, rayon 3 (réglage du mod aujourd'hui pour une tournée) ;
    K2 marge 0,   résolution 0, rayon 3 ;
    K3 marge 0,   résolution 1, rayon 3 ;
    K4 marge 0,15, résolution 0, rayon 7.
  Puis un personnage (prototype du corps des PNJ) suit le premier chemin K2 trouvé (walking_state, 8 directions) : atteint-il le but ?
  Carte du champ (tuiles autour du but) : '#' bloquée pour le corps, '+' bloquée seulement pour la boîte élargie, '.' libre, 'G' but.
  Lancement : banc.py --qui NAV2 -- 1500 nav2-marge <source>.
]]

local TAG = "[FO-NAV2-MARGE]"
local CONFIGS = {
  { key = "K1", pad = 0.15, res = 0, radius = 3 },
  { key = "K2", pad = 0, res = 0, radius = 3 },
  { key = "K3", pad = 0, res = 1, radius = 3 },
  { key = "K4", pad = 0.15, res = 0, radius = 7 },
}
local STARTS = { { 22, 0 }, { -22, 0 }, { 0, 22 }, { 0, -22 }, { 16, 16 }, { -16, 16 }, { 16, -16 }, { -16, -16 } }
local ISSUE_AT = 120
local WALK_UNTIL = 1300
local CHECK = 1400
local BODY = "fo-companion"

local function G() global.nav2 = global.nav2 or { by_id = {}, res = {} } return global.nav2 end

-- Résultats des demandes (abonnement au CHARGEMENT du greffon, F24 ; seul ce scénario s'y abonne dans le mod de test).
script.on_event(defines.events.on_script_path_request_finished, function(e)
  local g = G()
  local r = g.by_id[e.id]
  if not r then return end
  g.by_id[e.id] = nil
  if e.try_again_later then
    r.state = "retry"
    r.retries = (r.retries or 0) + 1
    return
  end
  r.state = e.path and "ok" or "no_path"
  r.n = e.path and #e.path or 0
  if e.path then
    local last = e.path[#e.path].position
    r.end_d = math.sqrt((last.x - g.goal.x) ^ 2 + (last.y - g.goal.y) ^ 2)
    if r.cfg == "K2" and not g.walk_path then
      g.walk_path = {}
      for i, w in ipairs(e.path) do g.walk_path[i] = { x = w.position.x, y = w.position.y } end
      g.walk_start = r.start
    end
  end
end)

local function box_of(name, pad)
  local b = game.entity_prototypes[name].collision_box
  return { { b.left_top.x - pad, b.left_top.y - pad }, { b.right_bottom.x + pad, b.right_bottom.y + pad } }
end

-- Une boîte (centrée en x, y, demi-largeur h) chevauche-t-elle strictement une entité qui heurte le corps (F96 : refiltrer) ?
local function blocked(s, x, y, h)
  for _, e in ipairs(s.find_entities_filtered({ area = { { x - h - 0.01, y - h - 0.01 }, { x + h + 0.01, y + h + 0.01 } }, collision_mask = "player-layer" })) do
    if e.valid and e.type ~= "character" then
      local bb = e.bounding_box
      if bb.left_top.x < x + h and bb.right_bottom.x > x - h and bb.left_top.y < y + h and bb.right_bottom.y > y - h then return true end
    end
  end
  return false
end

local function dir_to(dx, dy)
  local D = defines.direction
  local ax, ay = math.abs(dx), math.abs(dy)
  if ax > 2 * ay then return dx > 0 and D.east or D.west end
  if ay > 2 * ax then return dy > 0 and D.south or D.north end
  if dx > 0 then return dy > 0 and D.southeast or D.northeast end
  return dy > 0 and D.southwest or D.northwest
end

return {
  description = "NAV2 : chemins vers le centre d'un avant-poste dense, boite du corps elargie ou non",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local c0 = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
    local hq = { x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.5 }
    local cc = { x = math.floor(hq.x) + 48, y = math.floor(hq.y) }
    ctx.prepare_area(cc.x - 30, cc.y - 30, cc.x + 30, cc.y + 30, "grass-1")
    local n_c = 0
    for dx = -9, 9 do
      for dy = -9, 9 do
        if dx * dx + dy * dy <= 81 then
          s.create_entity({ name = "coal", position = { cc.x + dx, cc.y + dy }, amount = 20000 })
          n_c = n_c + 1
        end
      end
    end
    local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose", string.format("gisement %d tuiles en (%d, %d)", n_c, cc.x, cc.y))
    if not chest then return end
    local o = ctx.remote("fo-ia1", "bench_outpost", "player", "coal", cc.x, cc.y)
    ctx.check(o ~= nil, "avant-poste de charbon pose", o and (o.drills .. " foreuse(s)") or "nil")
    if not o then return end
    local drills = ctx.remote("fo-ia1", "bench_extend", "player", o.id, 20)
    ctx.check((drills or 0) >= 20, "champ dense (agrandi jusqu'au plein)", tostring(drills) .. " foreuse(s)")
    st.cc, st.oid, st.drills = cc, o.id, drills
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.cc then return end
    local s = ctx.surface()
    local g = G()
    local t = e.tick
    if t == ISSUE_AT - 1 then
      -- but : point libre pour le corps le plus proche du centre du gisement (comme le point d'accès d'une partie : « place libre : oui »)
      local goal = s.find_non_colliding_position(BODY, st.cc, 6, 0.5) or st.cc
      g.goal = { x = goal.x, y = goal.y }
      -- carte du champ autour du but
      local rows = {}
      local nb, np = 0, 0
      for dy = -11, 11 do
        local row = {}
        for dx = -11, 11 do
          local x, y = math.floor(goal.x) + dx + 0.5, math.floor(goal.y) + dy + 0.5
          local ch
          if dx == 0 and dy == 0 then ch = "G"
          elseif blocked(s, x, y, 0.2) then ch = "#" nb = nb + 1
          elseif blocked(s, x, y, 0.35) then ch = "+" np = np + 1
          else ch = "." end
          row[#row + 1] = ch
        end
        rows[#rows + 1] = table.concat(row)
      end
      local ents = {}
      for _, en in ipairs(s.find_entities_filtered({ position = st.cc, radius = 14, force = "player" })) do ents[en.name] = (ents[en.name] or 0) + 1 end
      local parts = {}
      local names = {}
      for k in pairs(ents) do names[#names + 1] = k end
      table.sort(names)
      for _, k in ipairs(names) do parts[#parts + 1] = k .. "=" .. ents[k] end
      ctx.log(string.format("but (%.1f, %.1f), centre (%d, %d), foreuses %d ; entites a 14 tuiles : %s ; centres de tuile bloques pour le corps %d, pour la boite elargie seule %d",
        goal.x, goal.y, st.cc.x, st.cc.y, st.drills or 0, table.concat(parts, " "), nb, np))
      for i, r in ipairs(rows) do ctx.log(string.format("carte %02d %s", i, r)) end
      g.reqs = {}
      for _, c in ipairs(CONFIGS) do
        for i, off in ipairs(STARTS) do
          local sp = s.find_non_colliding_position(BODY, { x = st.cc.x + off[1], y = st.cc.y + off[2] }, 4, 0.5)
          g.reqs[#g.reqs + 1] = { cfg = c.key, pad = c.pad, res = c.res, radius = c.radius, i = i, start = sp and { x = sp.x, y = sp.y }, state = "todo" }
        end
      end
    end
    -- émission : 2 demandes par tick au plus, 8 en vol au plus ; relance d'un « try_again_later »
    if g.reqs and t >= ISSUE_AT then
      local inflight = 0
      for _ in pairs(g.by_id) do inflight = inflight + 1 end
      local sent = 0
      for _, r in ipairs(g.reqs) do
        if sent >= 2 or inflight >= 8 then break end
        if (r.state == "todo" or r.state == "retry") and r.start and (r.retries or 0) < 6 then
          local id = s.request_path({
            bounding_box = box_of(BODY, r.pad),
            collision_mask = game.entity_prototypes[BODY].collision_mask,
            start = r.start, goal = g.goal, force = "player", radius = r.radius,
            pathfind_flags = { cache = false, prefer_straight_paths = true },
            path_resolution_modifier = r.res,
          })
          g.by_id[id] = r
          r.state = "pending"
          sent = sent + 1
          inflight = inflight + 1
        end
      end
    end
    -- marche réelle du corps sur le premier chemin K2 trouvé
    if g.walk_path and not g.walker and t < WALK_UNTIL then
      local w = s.create_entity({ name = BODY, position = g.walk_start, force = "player" })
      if w then
        g.walker = w
        g.wi = 1
        g.walk_t0 = t
        g.walk_best = math.huge
      else
        g.walk_path = nil
        g.walk_fail = "corps non pose"
      end
    end
    local w = g.walker
    if w and w.valid and not g.walk_done then
      local wp = w.position
      local dg = math.sqrt((wp.x - g.goal.x) ^ 2 + (wp.y - g.goal.y) ^ 2)
      if dg < g.walk_best then g.walk_best = dg end
      if dg <= 1.5 then
        g.walk_done = "atteint"
        g.walk_ticks = t - g.walk_t0
        w.walking_state = { walking = false, direction = defines.direction.north }
      elseif t >= WALK_UNTIL then
        g.walk_done = "pas atteint"
        g.walk_ticks = t - g.walk_t0
      else
        local tgt = g.walk_path[g.wi]
        while tgt and (tgt.x - wp.x) ^ 2 + (tgt.y - wp.y) ^ 2 < 0.3 * 0.3 and g.wi < #g.walk_path do
          g.wi = g.wi + 1
          tgt = g.walk_path[g.wi]
        end
        if tgt then
          local dx, dy = tgt.x - wp.x, tgt.y - wp.y
          if dx * dx + dy * dy < 0.3 * 0.3 then
            if g.wi < #g.walk_path then g.wi = g.wi + 1 end
          else
            w.walking_state = { walking = true, direction = dir_to(dx, dy) }
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local g = G()
    if not g.reqs then
      ctx.check(false, "demandes emises", "aucune")
      return
    end
    local by = {}
    for _, c in ipairs(CONFIGS) do by[c.key] = { ok = 0, no = 0, other = 0, n = 0, end_max = 0 } end
    for _, r in ipairs(g.reqs) do
      local b = by[r.cfg]
      if r.state == "ok" then
        b.ok = b.ok + 1
        b.n = b.n + r.n
        if (r.end_d or 0) > b.end_max then b.end_max = r.end_d end
      elseif r.state == "no_path" then b.no = b.no + 1
      else b.other = b.other + 1 end
    end
    local answered = 0
    for _, c in ipairs(CONFIGS) do
      local b = by[c.key]
      answered = answered + b.ok + b.no
      ctx.log(string.format("RESULTAT %s marge=%.2f res=%d rayon=%d : chemins %d / %d, no_path %d, sans reponse %d, points moyens %.0f, fin de chemin au plus a %.1f tuile(s) du but",
        c.key, c.pad, c.res, c.radius, b.ok, #STARTS, b.no, b.other, b.ok > 0 and b.n / b.ok or 0, b.end_max))
    end
    ctx.log(string.format("RESULTAT marche du corps sur un chemin K2 : %s en %s ticks, au plus pres %.1f tuile(s) du but%s",
      tostring(g.walk_done or "non lancee"), tostring(g.walk_ticks or "-"), g.walk_best or -1, g.walk_fail and (" (" .. g.walk_fail .. ")") or ""))
    ctx.check(answered == #g.reqs, "toutes les demandes ont une reponse", string.format("%d / %d", answered, #g.reqs))
  end,
}
