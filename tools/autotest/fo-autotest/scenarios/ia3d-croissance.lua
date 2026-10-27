--[[
  Lot IA3-d (docs/IA_ATTENDUS.md A7, « ils ne scalent pas ») : partie LONGUE de mesure de la croissance des factions.
  4 factions, 100 soldats au plus, plafond fo-war-workers = 30 (D-14 « 30 dès l'époque 1 »), départ fo-npc-start = 8
  (D-18), Paisible, sans compagnons, sans financement, 2 h (432 000 ticks). Mêmes relevés minute qu'IA3-DIAG
  (scenarios/ia3d_common.lua : « minute M | <équipe> … pnj N/max … ») ; le mod écrit en plus chaque minute la règle
  d'effectif de chaque faction (« [FO-EFFECTIF] » : raisons, travail en attente, bras libres, fer).
  Lancement : banc.py … -- 432000 ia3d-croissance <source>. Journal : [FO-IA3D-CROISSANCE].
  Contrôles (fin de partie) : relevés écrits ; chaque faction vivante à la fin a dépassé son effectif de départ au moins
  une fois ; effectif moyen des minutes 90 à 119 au-dessus du départ pour au moins la moitié des factions vivantes ;
  plafond jamais dépassé ; agents riches ≤ fo-agents-max (300).
  NB : « ia3d-* » est aussi le préfixe des scénarios d'IA3-DIAG (ia3d-default, ia3d-reduit, ia3d-trente) ; celui-ci est
  du lot IA3-d (effectif).
]]
local START, CAP = 8, 30
local sc = require("scenarios/ia3d_common")("default")
sc.base = nil -- pas la base « default » du banc (war_start(4, 100, 10), 50 compagnons) : plafond 30, sans compagnons
sc.description = "IA3-d : croissance des factions (4 factions, 8 PNJ au depart, plafond 30, Paisible, 2 h)"
local init0, tick0, finish0 = sc.init, sc.tick, sc.finish

sc.init = function(ctx)
  local w = ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", CAP)
  ctx.check(w == CAP, "fo-war-workers regle a " .. CAP .. " (plafond)", w)
  local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
  ctx.check(ok == true, "difficulte Paisible imposee avant la guerre", tostring(ok))
  local started = ctx.call("war_start", 4, 100)
  ctx.check(started == true, "guerre lancee : 4 factions, 100 soldats, ouvriers par le reglage", tostring(started))
  ctx.call("profiler", true)
  init0(ctx) -- variante « default » d'IA3-DIAG : rien de plus, puis les réglages au journal
  local rows = ctx.remote("fo-ia1", "teams") or {}
  local parts = {}
  for _, r in ipairs(rows) do parts[#parts + 1] = r.key .. " " .. r.n .. "/" .. r.max end
  ctx.check(#rows == 4, "4 factions au depart, " .. START .. " PNJ chacune", table.concat(parts, ", "))
end

sc.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick % 3600 ~= 0 or e.tick == 0 then return end
  local st = ctx.state()
  st.eff = st.eff or {}
  local m = e.tick / 3600
  local rows = ctx.remote("fo-ia1", "teams") or {}
  for _, r in ipairs(rows) do
    local s = st.eff[r.key] or { max = 0, sum_last = 0, n_last = 0, over = false, first = r.n }
    st.eff[r.key] = s
    if r.n > s.max then s.max = r.n end
    if r.n > CAP then s.over = true end
    if m >= 90 and m <= 119 then s.sum_last, s.n_last = s.sum_last + r.n, s.n_last + 1 end
    s.alive = m
  end
end

sc.finish = function(ctx)
  finish0(ctx)
  local st = ctx.state()
  local rows = ctx.remote("fo-ia1", "teams") or {}
  local alive, grew, above, over = 0, 0, 0, false
  local parts = {}
  for _, r in ipairs(rows) do
    local s = (st.eff or {})[r.key]
    if s then
      alive = alive + 1
      local mean = s.n_last > 0 and s.sum_last / s.n_last or 0
      if s.max > START then grew = grew + 1 end
      if mean > START then above = above + 1 end
      if s.over then over = true end
      parts[#parts + 1] = string.format("%s max %d moy90-119 %.1f fin %d/%d", r.key, s.max, mean, r.n, r.max)
    end
  end
  ctx.log("effectifs : " .. table.concat(parts, " ; "))
  ctx.check(alive > 0 and grew == alive, "chaque faction vivante a depasse son effectif de depart", table.concat(parts, " ; "))
  ctx.check(alive > 0 and above * 2 >= alive, "effectif moyen des minutes 90 a 119 au-dessus du depart (au moins la moitie)",
    above .. " sur " .. alive)
  ctx.check(not over, "plafond jamais depasse")
  local p = ctx.remote("fo-ia1", "path") or {}
  ctx.check((p.agents or 0) <= 300, "agents riches <= fo-agents-max (300)", p.agents)
end

return sc
