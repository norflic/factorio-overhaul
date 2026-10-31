--[[
  Banc « ind-treillis » du lot INDUSTRIE I3 (31/10) : le treillis du plan directeur vers un gisement de cuivre, sans PNJ ni centrale
  (le plan seul, 20 000 ticks au plus : chaîne déclencheur -> décision -> action -> effet de shared/team/treillis.lua).

  Terrain : un couloir de 300 × 200 tuiles autour de l'axe QG -> gisement est VIDÉ (ressources, arbres, rochers, falaises, nids) et
  refait en herbe ; le coffre d'équipe (le QG de votre équipe) est en (0, 0), le plan directeur allumé au rayon 3, « seul ».
  Variantes (scénarios ind-treillis-proche, -loin, -vide) :
    proche : cuivre à 35 tuiles du QG, dans un lot où le charbon est plus abondant (l'état du lot ne retient que le charbon :
             le cas d'Ambre, 3 198 refus « hors du treillis » du journal du DC en 0.6.27) ;
    loin   : cuivre à 200 tuiles (anneau 7, le plafond ordinaire est 5) ;
    vide   : aucun cuivre dans les 12 anneaux (le treillis ne doit PAS grandir pour rien).
  Demande : une fonderie de cuivre à tapis (feed = « tapis », comme l'automatisation) toutes les 1 800 ticks tant qu'elle est refusée
  (le repli du cerveau), au plus 8 fois. Le coffre porte de quoi poser foreuses, tapis, fours (rien n'est bâti avant la fin du plan
  qui compte ici : état du projet, rayon, causes comptées).
  Contrôles : voir les checks de chaque variante. Journal : [FO-IND-TREILLIS-<VARIANTE>] + [FO-TREILLIS] du mod.
  Lancement : banc.py ... -- 20000 ind-treillis-<variante> <source>
]]

local MIN = 3600
local T_ENABLE_WAIT = 120
local RETRY = 1800
local TRIES = 8
local CHECK = 20000

local function sorted_keys(t)
  local k = {}
  for x in pairs(t or {}) do k[#k + 1] = x end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  return k
end

local function kv(t)
  local parts = {}
  for _, k in ipairs(sorted_keys(t)) do parts[#parts + 1] = k .. "=" .. tostring(t[k]) end
  return table.concat(parts, " ")
end

local function disc(s, name, cx, cy, r, amount, skip)
  local n = 0
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r and not (skip and skip(cx + dx, cy + dy)) then
        if s.create_entity({ name = name, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = amount }) then n = n + 1 end
      end
    end
  end
  return n
end

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 2000 }, { "copper-plate", 600 }, { "coal", 1500 }, { "stone", 200 },
    { "electric-mining-drill", 30 }, { "stone-furnace", 30 }, { "transport-belt", 900 }, { "inserter", 120 },
    { "fast-inserter", 20 }, { "burner-inserter", 10 }, { "medium-electric-pole", 120 }, { "big-electric-pole", 30 },
    { "iron-chest", 20 }, { "pistol", 10 }, { "firearm-magazine", 200 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

--- Le couloir : x de −60 à 300, y de −100 à 100, vidé puis refait en herbe ; chunks générés avant.
local function shape(ctx, variant)
  local s = ctx.surface()
  s.request_to_generate_chunks({ 120, 0 }, 11)
  s.force_generate_chunk_requests()
  local area = { { -60, -100 }, { 300, 100 } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -100, 99 do for x = -60, 299 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
  -- le cuivre NATUREL des 12 anneaux (700 tuiles de côté) disparaît aussi : la sonde du plan doit ne voir que celui du banc
  s.request_to_generate_chunks({ 0, 0 }, 13)
  s.force_generate_chunk_requests()
  local natural = 0
  for _, e in ipairs(s.find_entities_filtered({ area = { { -360, -360 }, { 360, 360 } }, name = "copper-ore" })) do
    if e.valid then e.destroy() natural = natural + 1 end
  end
  local info = { natural = natural }
  if variant == "proche" then
    -- lot (1, 1) : x et y de 16 à 40 ; le charbon (disque de 5, ~80 tuiles) l'emporte sur le cuivre (disque de 3, ~28 tuiles)
    info.coal = disc(s, "coal", 22, 22, 5, 3000)
    info.copper = disc(s, "copper-ore", 35, 35, 3, 4000)
    info.target = { x = 35, y = 35 }
  elseif variant == "loin" then
    info.copper = disc(s, "copper-ore", 200, 0, 9, 4000)
    info.target = { x = 200, y = 0 }
  end
  -- du fer près du QG pour que le plan ait une autre ressource à voir (aucun rôle dans les contrôles)
  info.iron = disc(s, "iron-ore", -40, -40, 6, 4000)
  return info
end

local function copper_part(r, id)
  for _, p in ipairs(r.projects or {}) do
    if p.id == id then return p end
  end
  return nil
end

return function(variant)
  local TAG = "ind-treillis-" .. variant
  return {
    description = "INDUSTRIE I3 : treillis vers un gisement de cuivre (" .. variant .. ")",
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      st.info = shape(ctx, variant)
      ctx.log(string.format("terrain %s : charbon %s tuiles, cuivre %s tuiles (%d naturelles retirees), fer %s tuiles", variant, tostring(st.info.coal), tostring(st.info.copper), st.info.natural, tostring(st.info.iron)))
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      stock_chest(chest)
      local ok = ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 3 })
      ctx.check(ok == true, "plan directeur active")
      st.t0 = game.tick
      st.tries, st.ids = 0, {}
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local t = e.tick - st.t0
      if t < T_ENABLE_WAIT then return end
      -- la demande, puis le repli du cerveau : une nouvelle demande 1 800 ticks après un refus
      local last = st.ids[#st.ids]
      local need = false
      if not last then
        need = true
      else
        local pr = ctx.remote("fo-ia1d", "status", "player", last)
        if pr and pr.state == "refuse" and t - (st.last_t or 0) >= RETRY and st.tries < TRIES then need = true end
        -- « acceptée » : le plan est fait (la demande neuve est « attente », puis « plan » tant que le plan n'a pas rendu sa réponse)
        if pr and pr.state ~= "refuse" and pr.state ~= "attente" and pr.state ~= "plan" and not st.accepted then
          st.accepted = { t = t, tick = e.tick, state = pr.state, parts = pr.parts }
          ctx.log(string.format("[%s] demande %d acceptee au tick %d (+%d s) : etat %s, %d partie(s)", TAG, last, e.tick, math.floor(t / 60), pr.state, #(pr.parts or {})))
        end
      end
      if need and not st.accepted then
        local id = ctx.remote("fo-ia1d", "request", "player", { gen = "smelter", args = { "stone-furnace", "copper-ore", 2 }, feed = "tapis" })
        if id then -- (nil : l'equipe n'a pas encore son plan directeur ; rien n'est compte)
          st.tries = st.tries + 1
          st.last_t = t
          st.ids[#st.ids + 1] = id
          ctx.log(string.format("[%s] demande %d (essai %d) au tick %d", TAG, id, st.tries, e.tick))
        end
      end
      if t > 0 and t % MIN == 0 then
        local r = ctx.remote("fo-ia1d", "report", "player")
        if r then
          local last_p = copper_part(r, st.ids[#st.ids] or -1)
          ctx.log(string.format("[%s] minute %d | rayon %d | file %d | lots %s | treillis {%s} | differes %s | dernier projet %s", TAG, math.floor(t / MIN), r.radius, r.queue,
            kv(r.lots), kv(r.treillis), tostring(r.ungen_deferred), last_p and (last_p.state .. (last_p.reason and (" " .. last_p.reason) or "")) or "-"))
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local r = ctx.remote("fo-ia1d", "report", "player")
      ctx.check(r ~= nil, "rapport du plan directeur")
      if not r then return end
      local last = st.ids[#st.ids]
      local pr = last and ctx.remote("fo-ia1d", "status", "player", last)
      ctx.log(string.format("[%s] BILAN DU PLAN : rayon %d, %d demande(s), accepte=%s, treillis {%s}, differes %d (retablis %s), dernier projet %s %s", TAG, r.radius, st.tries,
        st.accepted and ("tick " .. st.accepted.tick .. " etat " .. st.accepted.state) or "non", kv(r.treillis), r.ungen_deferred or 0, "-",
        pr and pr.state or "?", pr and pr.reason or ""))
      for _, p in ipairs(r.projects or {}) do
        ctx.log(string.format("[%s] projet %d : %s %s, %d partie(s)", TAG, p.id, p.state, p.reason or "", #(p.parts or {})))
      end
      local tr = r.treillis or {}
      if variant == "proche" then
        ctx.check(st.accepted ~= nil, "cuivre a 35 tuiles (lot ou le charbon l'emporte) : la fonderie est planifiee")
        ctx.check(r.radius <= 5, "le treillis n'a pas grandi au-dela du rayon ordinaire pour un gisement voisin (rayon " .. r.radius .. ")")
        local drills = false
        for _, pt in ipairs(st.accepted and st.accepted.parts or {}) do if pt.kind == "foreuses" then drills = true end end
        ctx.check(drills, "la fonderie a ses foreuses (tapis) : partie 'foreuses' au plan")
        ctx.check(st.tries <= 3, "au plus 3 demandes (" .. st.tries .. ")")
      elseif variant == "loin" then
        ctx.check(st.accepted ~= nil, "cuivre a 200 tuiles (anneau 7) : la fonderie est planifiee apres croissance du treillis")
        ctx.check(r.radius >= 7 and r.radius <= 12, "le treillis a grandi jusqu'au gisement, pas au-dela du plafond (rayon " .. r.radius .. ")")
        local grew = 0
        for _, k in ipairs(sorted_keys(tr)) do if k:find("^hors_grandir:grandir") or k:find("^trop_loin_bord:grandir") then grew = grew + tr[k] end end
        ctx.check(grew >= 1 and grew <= 2, "croissance d'un coup (1 ou 2 fois, " .. grew .. ")")
        local drills = false
        for _, pt in ipairs(st.accepted and st.accepted.parts or {}) do
          if pt.kind == "foreuses" then
            drills = true
            ctx.check(math.abs(pt.x - 200) <= 40 and math.abs(pt.y) <= 40, string.format("foreuses posees au gisement (%d, %d)", pt.x, pt.y))
          end
        end
        ctx.check(drills, "la fonderie a ses foreuses (tapis)")
      else
        ctx.check(st.accepted == nil, "aucun cuivre : la fonderie est refusee")
        ctx.check(r.radius <= 5, "le treillis ne grandit pas au-dela du rayon ordinaire pour rien (rayon " .. r.radius .. ")")
        local n = 0
        for _, k in ipairs(sorted_keys(tr)) do if k:find("^aucun_gisement:refuser") then n = n + tr[k] end end
        ctx.check(n >= 1, "cause comptee : aucun_gisement (" .. n .. ")")
      end
      if variant ~= "proche" then ctx.check(next(tr) ~= nil, "causes de refus comptees par le plan (b.stats.treillis)") end
    end,
  }
end
