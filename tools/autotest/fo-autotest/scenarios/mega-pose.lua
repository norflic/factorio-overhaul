--[[ Lot MEGA-FONDERIE, tranche 2 (A2) : micro-banc de la POSE par bandes EN AVANCE (critères K1, K2 en partie ; chaîne : docs/MEGA_FONDERIE.md).
  Dispositif de mega-decision (centrale revivee par le banc, gisement de fer de 1 000 tuiles a 90 tuiles a l'est du QG) PLUS :
    - le coffre de l'equipe garni des pieces et du fer d'une dizaine de bandes (le banc ne mesure pas la fabrication, mais la POSE) ;
    - des la centrale finie : fo-capi bench_mega (decision + ordre du champ par MigChamp.want, plafond Mp.par_max) renouvele toutes les 1 800
      ticks ; les fantomes de TOUS les projets sont ravives par le banc (comme un PNJ), les projets du plan font le reste ;
    - releve toutes les 120 ticks : projets de bande en vol en meme temps (etat chantier, fantomes ou raccordement), foreuses electriques posees.
  Controles : K1 (decision), champ voulu (field), au moins une bande posee, PARALLELISME (au moins 2 projets de bande en vol a un meme instant,
  et jamais plus que le plafond), foreuses posees. Journal du mod : [FO-MEGA] POSE, [FO-MIGRATION] « EN AVANCE ».
  Lancement : banc.py --out <archive> --qui mega-fonderie -- 12000 mega-pose <source>
]]
local CHECK = 11900
local EVERY = 120
local PARTS = { { "assembling-machine-1", 40 }, { "inserter", 80 },
  { "transport-belt", 400 }, { "small-electric-pole", 100 }, { "iron-chest", 20 }, { "wood", 100 },
  { "copper-plate", 400 }, { "iron-plate", 1500 }, { "coal", 400 }, { "offshore-pump", 2 }, { "boiler", 2 }, { "steam-engine", 4 },
  { "pipe", 40 }, { "burner-inserter", 4 }, { "stone-furnace", 60 } }

local function first_team(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out[1]
end

local function force_of(key) return game.forces["fo-" .. key] or game.forces[key] end

local function fill_quais(ctx, s, amount)
  for _, q in ipairs((s and s.quais) or {}) do
    local c = ctx.surface().find_entities_filtered({ position = { q.x, q.y }, radius = 0.4, type = "container", limit = 1 })[1]
    if c and c.valid and q.item and c.get_item_count(q.item) < amount then c.insert({ name = q.item, count = amount }) end
  end
end

--- Gisement de fer elliptique (demi-axes a, b) centré en (cx, cy) : ressources déjà là retirées, tuiles d'eau évitées. Rend la boîte et
--- le nombre de tuiles posées.
local function lay_patch(s, cx, cy, a, b)
  local box = { x0 = cx - a - 1, y0 = cy - b - 1, x1 = cx + a + 1, y1 = cy + b + 1, resource = "iron-ore" }
  for _, r in ipairs(s.find_entities_filtered({ area = { { box.x0, box.y0 }, { box.x1, box.y1 } }, type = "resource" })) do r.destroy() end
  local n = 0
  for x = cx - a, cx + a do
    for y = cy - b, cy + b do
      local dx, dy = (x - cx) / a, (y - cy) / b
      if dx * dx + dy * dy <= 1 and not s.get_tile(x, y).collides_with("water-tile") then
        if s.create_entity({ name = "iron-ore", position = { x + 0.5, y + 0.5 }, amount = 5000 }) then n = n + 1 end
      end
    end
  end
  return box, n
end


local BAND_PARTS = { { "electric-mining-drill", 150 }, { "stone-furnace", 200 }, { "inserter", 400 }, { "transport-belt", 3000 },
  { "small-electric-pole", 300 }, { "medium-electric-pole", 60 }, { "iron-chest", 60 }, { "iron-plate", 9000 }, { "copper-plate", 2000 },
  { "coal", 3000 }, { "electronic-circuit", 400 }, { "iron-gear-wheel", 600 } }
local PAR_CAP = 3

return {
  description = "MEGA-FONDERIE A2 : bandes d'un gisement a mega-fonderie decidee posees EN AVANCE les unes des autres",
  check_tick = CHECK,

  init = function(ctx)
    for _, s in ipairs({ { "fo-war-ia3e", true }, { "fo-war-capi", true }, { "fo-war-mega-fonderie", true }, { "fo-war-workers", 30 } }) do
      local v = ctx.call("war_setting", s[1], s[2])
      ctx.check(v == s[2], "reglage " .. s[1] .. " = " .. tostring(s[2]), tostring(v))
    end
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible imposee avant la guerre")
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 300 then
      local r = first_team(ctx)
      st.key = r and r.key
      local force = st.key and force_of(st.key)
      local hq = force and ctx.surface().find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
      ctx.check(hq ~= nil, "faction et QG releves (" .. tostring(st.key) .. ")")
      if not hq then return end
      if force.technologies["automation"] then force.technologies["automation"].researched = true end
      st.box, st.tiles = lay_patch(ctx.surface(), math.floor(hq.position.x) + 90, math.floor(hq.position.y), 25, 13)
      ctx.log(string.format("gisement de fer pose : %d tuiles, boite (%d, %d)-(%d, %d)", st.tiles, st.box.x0, st.box.y0, st.box.x1, st.box.y1))
      ctx.check(ctx.remote("fo-ind", "stock", st.key, PARTS) ~= nil, "coffre : pieces de la rangee et de la centrale")
      local got = ctx.remote("fo-ind", "stock", st.key, BAND_PARTS) or {}
      local txt = {}
      for _, p in ipairs(BAND_PARTS) do txt[#txt + 1] = p[1] .. " " .. tostring(got[p[1]]) .. "/" .. p[2] end
      ctx.log("coffre : pieces des bandes inserees : " .. table.concat(txt, ", "))
    end
    if not st.key or not st.box then return end
    if t == 600 then
      local id, info = ctx.remote("fo-ind", "row", st.key, "iron-gear-wheel", 30)
      ctx.log("rangee d'engrenages (pour la centrale) -> " .. tostring(id) .. " (" .. tostring(info) .. ")")
    end
    if t > 600 and t % EVERY == 0 then
      local a = ctx.remote("fo-ia3e", "status", st.key)
      if a and a.plant and a.plant_state ~= "fini" then ctx.remote("fo-ind", "revive", st.key, a.plant) end
      if a and a.plant then fill_quais(ctx, ctx.remote("fo-ia1d", "status", st.key, a.plant), 200) end
      local fin = a and a.plant_state == "fini"
      if fin and not st.plant_fini then st.plant_fini = t end
      if st.plant_fini and (t - st.plant_fini) % 1800 < EVERY then
        local res = ctx.remote("fo-capi", "bench_mega", st.key, st.box)
        for _, rec in pairs((res and res.deps) or {}) do
          if rec.res == "iron-ore" and (rec.lines or 0) > 0 then st.rec = rec end
        end
        if not st.decided then
          st.decided = t
          ctx.log(string.format("tick %d : centrale FINIE ; decision : %s (%s) ; champ voulu : %s", t, tostring(st.rec and st.rec.state), tostring(st.rec and st.rec.cause),
            tostring(st.rec and st.rec.field)))
        end
      end
      if st.decided then
        -- les fantomes de tous les projets (le banc remplace les PNJ), puis le releve des bandes en vol
        local inflight, listing = 0, {}
        for pid = 1, 90 do
          local s = ctx.remote("fo-ia1d", "status", st.key, pid)
          if s and pid > 2 then
            if s.state ~= "fini" and s.state ~= "refuse" and (s.total or 0) >= 10 then
              if s.state == "chantier" or s.state == "fantomes" or s.state == "raccordement" then inflight = inflight + 1 end
            end
            listing[#listing + 1] = pid .. ":" .. tostring(s.state) .. ":" .. tostring(s.built) .. "/" .. tostring(s.total)
          end
          if s and s.state ~= "fini" then ctx.remote("fo-ind", "revive", st.key, pid) end
          if s and s.state ~= "refuse" then fill_quais(ctx, s, 200) end
        end
        st.max_inflight = math.max(st.max_inflight or 0, inflight)
        if t % 600 < EVERY then
          local n = ctx.surface().count_entities_filtered({ area = { { st.box.x0 - 4, st.box.y0 - 4 }, { st.box.x1 + 4, st.box.y1 + 4 } },
            name = "electric-mining-drill", force = force_of(st.key) })
          ctx.log(string.format("diag tick %d : %d projet(s) de bande en vol (max %d), %d foreuse(s) electrique(s) posee(s) sur le gisement ; projets : %s", t, inflight,
            st.max_inflight, n, table.concat(listing, " ", 1, math.min(#listing, 14))))
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local r = st.rec
    local n = st.key and st.box and ctx.surface().count_entities_filtered({ area = { { st.box.x0 - 4, st.box.y0 - 4 }, { st.box.x1 + 4, st.box.y1 + 4 } },
      name = "electric-mining-drill", force = force_of(st.key) }) or 0
    ctx.check(st.plant_fini ~= nil, "centrale finie avant la decision", tostring(st.plant_fini))
    ctx.check(r ~= nil and r.state == "decide", "K1 : mega-fonderie DECIDEE", r and (tostring(r.state) .. " : " .. tostring(r.cause)) or "aucune decision")
    ctx.check(r ~= nil and r.field ~= nil, "le champ du gisement est VOULU (field)", r and tostring(r.field) or "-")
    ctx.check(n >= 4, "des foreuses electriques sont posees sur le gisement", tostring(n))
    ctx.check((st.max_inflight or 0) >= 2, "PARALLELISME : au moins 2 projets de bande en vol au meme instant", tostring(st.max_inflight))
    ctx.check((st.max_inflight or 0) <= PAR_CAP + 2, "jamais plus de bandes en vol que le plafond (+ projets du reseau du charbon)", tostring(st.max_inflight))
  end,
}
