--[[
  Lot PERIMETRE2 (demande du lead, 5/11 17 h 55) : FAIT MOTEUR à mesurer avant de poser une porte sur la brèche qu'un couloir d'accès
  (ÉTAGE 5) ouvre dans un anneau de murs : une porte (entité gate) s'ouvre-t-elle devant un PNJ (corps « fo-companion », force du joueur,
  AUCUN joueur) qui marche par commande de script (walking_state, comme script/companion/locomotion.lua) ? Le pathfinder du mod
  (script/core/path_service.lua : request_path SANS can_open_gates) trouve-t-il un chemin à travers une porte fermée ?

  Cadre (aucune pièce du mod en jeu hormis le prototype du corps) : 5 anneaux carrés de murs (11 x 11 tuiles, rayon 5), ouverture au milieu
  du côté OUEST, sur une zone vidée en herbe :
    R0 fermé (aucune ouverture) ; RA porte direction NORD ; RB porte direction EST ; RC brèche de 2 tuiles (ce que fait le mur aujourd'hui
    sur un couloir) ; RE porte direction NORD, témoin des ennemis (un petit mordeur).
  Demandes de chemin (tick 60) du dehors (14 tuiles à l'ouest) au centre, boîte du corps élargie de 0,15 (C.PATH_BBOX_PAD d'une tournée),
  masque du corps, { cache = false, prefer_straight_paths = true } :
    P0 R0, can_open_gates = true ; P1 RA, can_open_gates = false (réglage du mod aujourd'hui) ; P2A RA et P2B RB, can_open_gates = true ;
    P3 RC, can_open_gates = false.
  Marche : un corps « fo-companion » de la force du joueur suit P2A (anneau RA), un autre P2B (RB), par walking_state (8 directions).
  Ennemi : un petit mordeur reçoit go_to_location vers le centre de RE (distraction none).

  BILAN ATTENDU, ÉCRIT AVANT LE BANC (5/11 vers 18 h ; « déduit » = de la doc ou des prototypes, pas encore vu en moteur) :
    cadre : prototypes « gate » et « fo-companion » présents ; 5 anneaux posés (murs comptés) ;
    C1 P0 (anneau fermé) : no_path              (le banc voit une fermeture) ;
    C2 P3 (brèche de 2)  : chemin trouvé        (le banc voit une ouverture) ;
    M1 P1 (porte fermée, can_open_gates false) : no_path      DÉDUIT de la doc de request_path (« can_open_gates : Whether the path
                                                              request can open gates. Defaults to false ») ;
    M2 P2A et P2B (can_open_gates true) : chemin trouvé, qui passe à moins de 0,8 tuile du centre de la porte ;
    M3 marche A et B : la porte est vue OUVERTE (is_opened) pendant la marche, et le corps atteint le centre (1,5 tuile) avant le tick 1 000
                                                              INCONNU : c'est le fait mesuré (personnage sans joueur) ;
    M4 mordeur : la porte de RE n'est JAMAIS vue ouverte ; le mordeur n'est pas dans l'anneau au contrôle    DÉDUIT ;
    tenue : les portes A et B sont fermées avant l'approche (aucun corps à moins de 3 tuiles, activation_distance).
  Soit « [FO-G3-PORTE] BILAN : 13 OK, 0 ECHEC(S) » si tout le déduit tient et que M3 passe (init : 2 ; fin : C1, C2, M1, M2 x 2,
  tenue x 2, M3 x 2, M4 x 2 = 11).
  Décision écrite avant : la porte n'est posée par le mur que si M2, M3 (au moins une direction) et M4 passent ; il faut alors aussi
  can_open_gates = true dans les demandes de chemin des PNJ de votre équipe (script/core/path_service.lua, hors de ce lot : accord du lead).
  Si M3 échoue : la brèche reste (une porte refermerait les PNJ dehors).
  Si M1 donne un chemin : le réglage de path_service suffit tel quel.
  Orientation (déduit : direction nord = porte verticale, barreaux nord-sud, dans un mur nord-sud) : images seulement,
  banc.py --captures --qui PERIMETRE2 -- 1600 g3-porte <source> (une capture par ouverture, au tick 40, avant la marche).
  Lancement sans images : banc.py --out <archive> --qui PERIMETRE2 -- 1600 g3-porte <source>.
]]
local TAG = "[FO-G3-PORTE]"
local BODY = "fo-companion"
local PAD = 0.15
local T_ISSUE = 60
local WALK_UNTIL = 1000
local CHECK = 1500
local R = 5

local function G() global.g3porte = global.g3porte or { by_id = {}, reqs = {}, walk = {} } return global.g3porte end

-- Résultats des demandes (abonnement au CHARGEMENT du greffon, F24).
script.on_event(defines.events.on_script_path_request_finished, function(e)
  local g = G()
  local r = g.by_id[e.id]
  if not r then return end
  g.by_id[e.id] = nil
  if e.try_again_later then r.state = "retry" r.retries = (r.retries or 0) + 1 return end
  r.state = e.path and "ok" or "no_path"
  r.n = e.path and #e.path or 0
  if e.path then
    r.path = {}
    local best = math.huge
    for i, w in ipairs(e.path) do
      r.path[i] = { x = w.position.x, y = w.position.y }
      if r.gate then
        local d = math.sqrt((w.position.x - r.gate.x) ^ 2 + (w.position.y - r.gate.y) ^ 2)
        if d < best then best = d end
      end
    end
    r.gate_d = best
  end
end)

local function dir_to(dx, dy)
  local D = defines.direction
  local ax, ay = math.abs(dx), math.abs(dy)
  if ax > 2 * ay then return dx > 0 and D.east or D.west end
  if ay > 2 * ax then return dy > 0 and D.south or D.north end
  if dx > 0 then return dy > 0 and D.southeast or D.northeast end
  return dy > 0 and D.southwest or D.northwest
end

-- anneau carré de murs centré sur la tuile (cx, cy) ; ouverture au milieu du côté ouest : "ferme", "porte" (dir), "breche"
local function ring(s, cx, cy, kind, dir)
  local n, gate = 0, nil
  for x = cx - R, cx + R do
    for y = cy - R, cy + R do
      if x == cx - R or x == cx + R or y == cy - R or y == cy + R then
        local open = x == cx - R and (y == cy or (kind == "breche" and y == cy + 1))
        if open and kind == "porte" then
          gate = s.create_entity({ name = "gate", position = { x + 0.5, y + 0.5 }, direction = dir, force = "player" })
        elseif not (open and kind ~= "ferme") then
          if s.create_entity({ name = "stone-wall", position = { x + 0.5, y + 0.5 }, force = "player" }) then n = n + 1 end
        end
      end
    end
  end
  return n, gate
end

return {
  description = "PERIMETRE2 : une porte s'ouvre-t-elle devant un PNJ sans joueur ? chemin a travers une porte fermee",
  base = nil,
  check_tick = CHECK,
  shots_delay = 40,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.check(game.entity_prototypes["gate"] ~= nil and game.entity_prototypes[BODY] ~= nil, "cadre : prototypes gate et " .. BODY .. " presents")
    local c0 = game.forces.player.get_spawn_position(s)
    local bx, by = math.floor(c0.x) + 80, math.floor(c0.y)
    ctx.prepare_area(bx - 30, by - 20, bx + 190, by + 20, "grass-1")
    local D = defines.direction
    st.rings = {
      { key = "R0", cx = bx, cy = by, kind = "ferme" },
      { key = "RA", cx = bx + 40, cy = by, kind = "porte", dir = D.north },
      { key = "RB", cx = bx + 80, cy = by, kind = "porte", dir = D.east },
      { key = "RC", cx = bx + 120, cy = by, kind = "breche" },
      { key = "RE", cx = bx + 160, cy = by, kind = "porte", dir = D.north },
    }
    local walls, gates = 0, 0
    for _, rg in ipairs(st.rings) do
      local n, gate = ring(s, rg.cx, rg.cy, rg.kind, rg.dir)
      rg.walls, rg.gate = n, gate
      walls = walls + n
      if gate then gates = gates + 1 end
    end
    -- 40 tuiles de pourtour par anneau : 40 murs (fermé), 39 (porte), 38 (brèche)
    ctx.check(walls == 40 + 39 + 39 + 38 + 39 and gates == 3, "cadre : 5 anneaux poses", string.format("%d murs, %d porte(s)", walls, gates))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.rings then return end
    local s = ctx.surface()
    local g = G()
    local t = e.tick
    local by = {}
    for _, rg in ipairs(st.rings) do by[rg.key] = rg end
    if t == T_ISSUE then
      local function req(key, rk, open)
        local rg = by[rk]
        local sp = s.find_non_colliding_position(BODY, { x = rg.cx - 14 + 0.5, y = rg.cy + 0.5 }, 3, 0.5)
        g.reqs[#g.reqs + 1] = { key = key, ring = rk, open = open, start = sp and { x = sp.x, y = sp.y }, goal = { x = rg.cx + 0.5, y = rg.cy + 0.5 },
          gate = { x = rg.cx - R + 0.5, y = rg.cy + 0.5 }, state = "todo" }
      end
      req("P0", "R0", true)
      req("P1", "RA", false)
      req("P2A", "RA", true)
      req("P2B", "RB", true)
      req("P3", "RC", false)
      -- ennemi devant RE
      local rge = by.RE
      local b = s.create_entity({ name = "small-biter", position = { rge.cx - 12 + 0.5, rge.cy + 0.5 }, force = "enemy" })
      if b then
        b.set_command({ type = defines.command.go_to_location, destination = { x = rge.cx + 0.5, y = rge.cy + 0.5 }, radius = 1,
          distraction = defines.distraction.none })
        st.biter = b
      end
    end
    -- émission (et relance d'un try_again_later)
    if t >= T_ISSUE then
      local box = game.entity_prototypes[BODY].collision_box
      for _, r in ipairs(g.reqs) do
        if (r.state == "todo" or r.state == "retry") and r.start and (r.retries or 0) < 6 then
          local id = s.request_path({
            bounding_box = { { box.left_top.x - PAD, box.left_top.y - PAD }, { box.right_bottom.x + PAD, box.right_bottom.y + PAD } },
            collision_mask = game.entity_prototypes[BODY].collision_mask,
            start = r.start, goal = r.goal, force = "player", radius = 1, can_open_gates = r.open,
            pathfind_flags = { cache = false, prefer_straight_paths = true },
          })
          g.by_id[id] = r
          r.state = "pending"
        end
      end
    end
    -- tenue et ouverture des portes, chaque tick
    for _, rk in ipairs({ "RA", "RB", "RE" }) do
      local rg = by[rk]
      if rg.gate and rg.gate.valid then
        if rg.gate.is_opened() or rg.gate.is_opening() then
          rg.opened = rg.opened or t
        end
      end
    end
    -- marche des corps sur P2A et P2B
    for _, r in ipairs(g.reqs) do
      if (r.key == "P2A" or r.key == "P2B") and r.state == "ok" and t < WALK_UNTIL then
        local w = g.walk[r.key]
        if not w then
          local body = s.create_entity({ name = BODY, position = r.start, force = "player" })
          w = { body = body, i = 1, t0 = t, best = math.huge, closed_before = by[r.ring].gate and by[r.ring].gate.valid and by[r.ring].gate.is_closed() }
          g.walk[r.key] = w
        end
        local body = w.body
        if body and body.valid and not w.done then
          local p = body.position
          local dg = math.sqrt((p.x - r.goal.x) ^ 2 + (p.y - r.goal.y) ^ 2)
          if dg < w.best then w.best = dg end
          if dg <= 1.5 then
            w.done, w.ticks = "atteint", t - w.t0
            body.walking_state = { walking = false, direction = defines.direction.north }
          else
            local tgt = r.path[w.i]
            while tgt and (tgt.x - p.x) ^ 2 + (tgt.y - p.y) ^ 2 < 0.09 and w.i < #r.path do
              w.i = w.i + 1
              tgt = r.path[w.i]
            end
            if tgt then body.walking_state = { walking = true, direction = dir_to(tgt.x - p.x, tgt.y - p.y) } end
          end
        end
      end
    end
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.rings then return end
    for _, rg in ipairs(st.rings) do
      add("g3-porte-" .. rg.key, rg.cx - R + 0.5, rg.cy + 0.5, 2, 0, { res = { 640, 640 }, info = false })
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local g = G()
    if not st.rings then ctx.check(false, "anneaux poses", "aucun") return end
    local by, rq = {}, {}
    for _, rg in ipairs(st.rings) do by[rg.key] = rg end
    for _, r in ipairs(g.reqs) do rq[r.key] = r end
    for _, r in ipairs(g.reqs) do
      ctx.log(string.format("%s %s (%s, can_open_gates %s) : %s, %d point(s), au plus pres de l'ouverture %.2f tuile(s)", TAG, r.key, r.ring,
        tostring(r.open), tostring(r.state), r.n or 0, r.gate_d or -1))
    end
    for _, k in ipairs({ "P2A", "P2B" }) do
      local w = g.walk[k]
      local rg = by[rq[k].ring]
      ctx.log(string.format("%s marche %s : %s en %s ticks, au plus pres %.2f ; porte fermee avant : %s, vue ouverte au tick %s", TAG, k,
        tostring(w and w.done or "pas atteint"), tostring(w and w.ticks or "-"), w and w.best or -1, tostring(w and w.closed_before),
        tostring(rg.opened)))
    end
    local b = st.biter
    local re = by.RE
    local inside = b and b.valid and math.abs(b.position.x - (re.cx + 0.5)) < R and math.abs(b.position.y - (re.cy + 0.5)) < R
    ctx.log(string.format("%s mordeur : %s, porte de RE vue ouverte au tick %s, porte valide %s", TAG,
      b and b.valid and string.format("en (%.1f, %.1f)", b.position.x, b.position.y) or "absent", tostring(re.opened), tostring(re.gate and re.gate.valid)))
    ctx.check(rq.P0.state == "no_path", "C1 anneau ferme : no_path", tostring(rq.P0.state))
    ctx.check(rq.P3.state == "ok", "C2 breche de 2 tuiles : chemin", tostring(rq.P3.state))
    ctx.check(rq.P1.state == "no_path", "M1 porte fermee, can_open_gates false : no_path (deduit)", tostring(rq.P1.state))
    for _, k in ipairs({ "P2A", "P2B" }) do
      local r = rq[k]
      ctx.check(r.state == "ok" and (r.gate_d or 99) < 0.8, "M2 " .. k .. " can_open_gates true : chemin par la porte",
        string.format("%s, %.2f tuile(s)", tostring(r.state), r.gate_d or -1))
    end
    for _, k in ipairs({ "P2A", "P2B" }) do
      local w = g.walk[k]
      local rg = by[rq[k].ring]
      ctx.check(w ~= nil and w.closed_before == true, "tenue " .. k .. " : porte fermee avant l'approche", tostring(w and w.closed_before))
      ctx.check(rg.opened ~= nil and w ~= nil and w.done == "atteint", "M3 " .. k .. " : porte ouverte devant le PNJ et centre atteint",
        string.format("ouverte %s, %s", tostring(rg.opened), tostring(w and w.done)))
    end
    ctx.check(re.opened == nil, "M4 la porte ne s'ouvre jamais devant le mordeur", tostring(re.opened))
    ctx.check(not inside, "M4 le mordeur n'est pas dans l'anneau", tostring(inside))
  end,
}
