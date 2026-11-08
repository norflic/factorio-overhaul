--[[
  Lot DEBUG-CERVEAU : CAPTURES de la vue « Cerveau » (session AVEC images, un joueur connecté). Même guerre que `default` (base "default").
  Lancement : banc.py --captures --visuel="--no-atlas-cache --ticks 9700" --qui DEBUG-CERVEAU -- 9600 dbg-cerveau-photo <source>.
  Déroulement : à 9 100 la vue s'ouvre sur l'équipe qui a le plus de zones ; les LIGNES FICTIVES (remote « demo », Lec.demo_projects : jamais écrites dans
  f.build) s'ajoutent aux vraies zones pour contrôler le dessin d'une liaison, d'un piquage en chantier, d'une demande refusée et d'un rapatriement quand la
  partie n'en a pas encore ; les captures (show_gui) montrent la carte, la fenêtre et le panneau du PNJ. Fichiers : fo-shots/x-dbgc-*.png.
  Sans joueur (banc sans images) : le scénario n'agit pas. Journal : [FO-DBG-CERVEAU-PHOTO].
]]

local T_OPEN, T_LAST = 9100, 9560

local function shot(ctx, p, name, pos, zoom)
  local st = ctx.state()
  local r = p.display_resolution
  local w, h = math.min(4096, math.max(640, r.width)), math.min(4096, math.max(360, r.height))
  game.take_screenshot({ path = "fo-shots/x-dbgc-" .. name .. ".png", player = p, show_gui = true, position = pos, zoom = zoom,
    resolution = { w, h }, daytime = 0, force_render = true, allow_in_replay = true })
  st.shots = (st.shots or 0) + 1
  ctx.log(string.format("capture x-dbgc-%s.png demandee au tick %d (%d x %d, zoom %.2f, position %.0f,%.0f)", name, game.tick, w, h, zoom, pos.x, pos.y))
end

local function call(fn, ...)
  local ok, res = pcall(remote.call, "fo-dbg-cerveau", fn, ...)
  if not ok then return nil, tostring(res) end
  return res
end

local function bbox(lignes)
  local x0, y0, x1, y1
  for _, l in ipairs(lignes or {}) do
    if l.x0 then
      x0 = math.min(x0 or l.x0, l.x0); y0 = math.min(y0 or l.y0, l.y0)
      x1 = math.max(x1 or l.x1, l.x1); y1 = math.max(y1 or l.y1, l.y1)
    end
  end
  return x0, y0, x1, y1
end

return {
  description = "DEBUG-CERVEAU : captures de la vue Cerveau (zones, entrees et sorties, lignes, panneau du PNJ)",
  base = "default",
  check_tick = T_LAST + 20,
  shots_delay = T_LAST + 100,

  tick = function(ctx, e)
    local st = ctx.state()
    local p = game.connected_players[1]
    if not p then
      if not st.no_player then
        st.no_player = true
        ctx.log("aucun joueur connecte (banc sans images) : les captures se prennent en session avec images")
      end
      return
    end
    if e.tick == T_OPEN then
      local res, err = call("probe_all", 40)
      if not res then ctx.log("ERREUR probe_all : " .. tostring(err)) st.erreur = err return end
      local best
      for _, t in ipairs(res) do
        if t.key ~= "player" and (best == nil or t.zones > best.zones) then best = t end
      end
      best = best or res[1]
      st.fid = tonumber(best.id) or best.id
      st.team_key = best.key
      ctx.log(string.format("equipe observee : %s (id %s), %d zone(s)", tostring(best.key), tostring(best.id), best.zones))
      call("demo", true)
      st.opened = call("open", p.index, st.fid) == true
    elseif e.tick == T_OPEN + 130 and st.fid ~= nil then
      call("refresh", p.index)
    elseif e.tick == T_OPEN + 200 and st.fid ~= nil then
      if call("state", p.index) == nil then st.opened = call("open", p.index, st.fid) == true end
      local s = call("state", p.index)
      st.state = s
      local x0, y0, x1, y1 = bbox(s and s.lignes)
      if x0 then
        local w, h = math.max(20, x1 - x0), math.max(14, y1 - y0)
        local r = p.display_resolution
        local zoom = math.min(1, 0.85 * r.height / ((h + 16) * 32), 0.55 * r.width / ((w + 16) * 32))
        st.center = { x = (x0 + x1) / 2 + (w * 0.15), y = (y0 + y1) / 2 }
        st.zoom_all = math.max(0.12, zoom)
        shot(ctx, p, "01-carte-ensemble", st.center, st.zoom_all)
        st.first = s.lignes[1]
      else
        ctx.log("aucune zone avec rectangle : pas de capture de la carte")
      end
    elseif e.tick == T_OPEN + 215 and st.first and st.first.x0 then
      local z = st.first
      shot(ctx, p, "02-zone-de-pres", { x = (z.x0 + z.x1) / 2 + 4, y = (z.y0 + z.y1) / 2 }, 0.6)
      call("select", p.index, z.key)
      call("refresh", p.index)
    elseif e.tick == T_OPEN + 260 and st.first and st.first.x0 then
      local z = st.first
      shot(ctx, p, "03-zone-choisie-detail", { x = (z.x0 + z.x1) / 2 + 4, y = (z.y0 + z.y1) / 2 }, 0.5)
    elseif e.tick == T_OPEN + 280 and st.fid ~= nil then
      local npc = call("first_npc", st.fid)
      local id, pos = npc and npc.id, npc and { x = npc.x, y = npc.y }
      st.npc = id
      if id and call("watch_npc", p.index, id) then
        ctx.log("panneau du PNJ ouvert pour l'agent " .. tostring(id))
      else
        ctx.log("aucun PNJ de cette equipe avec un corps valide")
      end
      st.npc_pos = pos
    elseif e.tick == T_OPEN + 330 and st.npc and st.npc_pos then
      shot(ctx, p, "04-pnj-panneau", st.npc_pos, 0.8)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if st.no_player then
      ctx.check(true, "sans joueur : rien a faire (le scenario ne tourne qu'en session avec images)")
      return
    end
    ctx.check(st.erreur == nil, "aucune erreur Lua", st.erreur or "")
    ctx.check(st.opened == true, "la vue s'est ouverte", tostring(st.opened))
    ctx.check((st.shots or 0) >= 3, "au moins 3 captures demandees", tostring(st.shots or 0))
    ctx.check(st.state ~= nil and #(st.state.lignes or {}) >= 1, "la vue montre au moins une zone", tostring(st.state and #(st.state.lignes or {})))
  end,

  shots = function(ctx, add) end,
}
