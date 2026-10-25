--[[
  Lot IA3-f (exploration sous brouillard) : outils communs des scénarios greffés ia3-brouillard*.lua (format :
  tools/autotest/README.md §4). Requis au CHARGEMENT par chaque scénario, jamais pendant un événement (F24).

  Partie : 4 factions en Normal (comme ia0-normal : war_start(4, 100, 10), biters en cessez-le-feu avec le seul
  joueur), 60 min. À REQ_TICK (5 min), l'étape « explore » du cerveau est jouée pour chaque faction : demande de
  « crude-oil » par l'interface « fo-ia3f » (le nouveau cerveau d'IA3-c l'émettra de lui-même). Relevé toutes les 10 s
  (interface fo-ia3f) ; une ligne par minute et par faction.

  Mesures (critères du lot, docs/IA3_CERVEAU.md §6.2) :
    - pétrole trouvé moins de 30 min après l'étape explore, pour chaque faction vivante ;
    - aucun avant-poste ni site en réserve dans un secteur JAMAIS VU ;
    - morts d'éclaireurs : au plus 1 par heure et par faction ;
    - 2e avant-poste de fer et 1er site de fer hors départ : dates, comparées au scénario « -avant » (brouillard coupé,
      comportement d'avant le lot, même source, même graine).
]]

local C = {}

C.REQ_TICK = 5 * 3600
C.WINDOW = 30 * 3600
C.RES = "crude-oil"

function C.start(ctx, fog)
  local on = ctx.remote("fo-ia3f", "set_fog", fog)
  ctx.check(on == fog, "brouillard " .. (fog and "actif" or "coupe (avant le lot)"), tostring(on))
  local ok = ctx.remote("fo-pvp", "set_difficulty", "normal")
  ctx.check(ok == true, "difficulte Normal imposee avant la guerre")
  game.forces.player.set_cease_fire("enemy", true)
  game.forces.enemy.set_cease_fire("player", true)
  local started = ctx.call("war_start", 4, 100, 10)
  ctx.check(started == true, "guerre lancee (4 factions)", tostring(started))
  ctx.call("profiler", true)
  ctx.call("reset_stats")
end

local function report_of(status, key)
  for _, r in ipairs(status.teams or {}) do if r.key == key then return r end end
  return nil
end
C.report_of = report_of

local function found_tick(r, res)
  for _, x in ipairs(r.found or {}) do if x.res == res then return x.t end end
  return nil
end

function C.poll(ctx, e, fog)
  if e.tick % 600 ~= 0 or e.tick == 0 then return end
  local st = ctx.state()
  st.fac = st.fac or {}
  local status = ctx.remote("fo-ia3f", "status")
  local pvp = ctx.remote("fo-pvp", "status")
  if fog and e.tick >= C.REQ_TICK and not st.requested then
    st.requested = e.tick
    for _, f in ipairs(pvp.factions) do
      local rec = st.fac[f.key] or {}
      st.fac[f.key] = rec
      rec.req = ctx.remote("fo-ia3f", "request", f.key, C.RES)
      rec.req_tick = e.tick
      ctx.log(string.format("etape explore : %s demande %s au tick %d -> %s", f.key, C.RES, e.tick, tostring(rec.req)))
    end
  end
  for _, f in ipairs(pvp.factions) do
    local rec = st.fac[f.key] or {}
    st.fac[f.key] = rec
    rec.alive_tick = e.tick
    local r = report_of(status, f.key)
    if r then
      rec.sectors, rec.deaths, rec.flees, rec.missions = r.sectors or 0, r.deaths or 0, r.flees or 0, r.missions or 0
      rec.audit_bad, rec.audit_ok, rec.tour = r.audit_bad or 0, r.audit_ok or 0, r.tour
      rec.tour_done_at = r.tour_done_at
      local t = found_tick(r, C.RES)
      if t and not rec.oil then rec.oil = t end
      local iron = r.outposts_at and r.outposts_at.iron or {}
      rec.iron1, rec.iron2 = iron[1], iron[2]
      rec.iron_site = r.site_at and r.site_at["iron-ore"] or nil
      rec.outposts = 0
      for _, list in pairs(r.outposts_at or {}) do rec.outposts = rec.outposts + #list end
      if fog then
        local unseen = 0
        for _, s in ipairs(ctx.remote("fo-ia3f", "prospects", f.key)) do
          if not s.seen and not s.seeded then unseen = unseen + 1 end
        end
        rec.unseen_max = math.max(rec.unseen_max or 0, unseen)
      end
    end
  end
  if e.tick % 3600 == 0 then
    local parts = {}
    for _, f in ipairs(pvp.factions) do
      local rec = st.fac[f.key]
      parts[#parts + 1] = string.format("%s secteurs=%s petrole=%s fer2=%s site_fer=%s ap=%s missions=%s fuites=%s morts=%s",
        f.key, tostring(rec.sectors), rec.oil and string.format("%.1f", rec.oil / 3600) or "-",
        rec.iron2 and string.format("%.1f", rec.iron2 / 3600) or "-", rec.iron_site and string.format("%.1f", rec.iron_site / 3600) or "-",
        tostring(rec.outposts), tostring(rec.missions), tostring(rec.flees), tostring(rec.deaths))
    end
    ctx.log(string.format("minute %d | regards %d | %s", e.tick / 3600, status.stats and status.stats.looks or 0,
      table.concat(parts, " ; ")))
  end
end

--- Ligne de mesure finale (lue par l'analyse avant / après) et contrôles communs.
function C.finish(ctx, fog)
  local st = ctx.state()
  local keys = {}
  for k in pairs(st.fac or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local r = st.fac[k]
    ctx.log(string.format("MESURE %s %s : fer2=%s site_fer=%s fer1=%s petrole=%s (demande %s, %s) morts=%s fuites=%s missions=%s secteurs=%s tour=%s (%s) audit=%s/%s vivante_tick=%s",
      fog and "apres" or "avant", k, tostring(r.iron2), tostring(r.iron_site), tostring(r.iron1), tostring(r.oil), tostring(r.req_tick),
      tostring(r.req), tostring(r.deaths), tostring(r.flees), tostring(r.missions), tostring(r.sectors), tostring(r.tour),
      tostring(r.tour_done_at), tostring(r.audit_ok), tostring(r.audit_bad), tostring(r.alive_tick)))
  end
  ctx.check(#keys == 4, "4 factions suivies", #keys)
  return keys
end

return C
