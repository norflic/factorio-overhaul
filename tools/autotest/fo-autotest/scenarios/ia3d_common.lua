--[[
  Lot IA3-DIAG (25/10) : CHRONOLOGIE MESURÉE des équipes de PNJ (« pourquoi les PNJ sont lents et séquentiels »).
  Scénario de MESURE seulement : il ne change rien au jeu (lecture par le moteur et par l'interface « fo-ia1 »).

  Variantes (fichiers ia3d-<variante>.lua) :
    default : la partie `default` du banc (base « default » : 4 factions, 100 soldats, 10 ouvriers, Paisible) ;
    reduit  : la partie du guide du DC (comme `pnj-reduit` : Facile, 2 factions, 30 soldats, 4 ouvriers, coffre d'équipe) ;
    trente  : comme `reduit`, mais 30 ouvriers au plus par faction (fo-war-workers = 30).

  Relevé chaque seconde (60 ticks), par équipe (factions vivantes, puis votre équipe si elle existe), SUR LES CORPS
  « character » de sa force (aucun accès au `global` du mod) :
    - fab      : le PNJ fabrique (file non vide) ; une SÉANCE de fabrication (fabrications enchaînées, trous de 3 s au
                 plus) est attribuée à la catégorie de sa DERNIÈRE recette (le programme d'une tâche « craft » fabrique
                 les intermédiaires d'abord, l'objet demandé en dernier) : recherche, armee, recrue, munitions,
                 batiments, autre ;
    - mine     : minage à la main ;
    - marche   : en marche (marche-qg : à QG_R = 22 tuiles ou moins du QG ; les cases des PNJ au QG sont à 7 à
                 19 tuiles du coffre, les avant-postes à 40 tuiles et plus) ;
    - arret-qg : immobile à 22 tuiles ou moins du QG sans fabriquer (« attend au coffre ») ;
    - arret-loin : immobile ailleurs (garde de fond, action sur place, bloqué).
  Toutes les 5 s : tâches des PNJ par l'interface « fo-ia1 » (team_status : tâche en cours ou inactif, fond).
  Chaque minute, une ligne par équipe :
    minute M | <equipe> tech T soldats S pnj N | taches {…} | activite {…} | fab {…} | stock … | produit … | livre …
  (taches, activite et fab en PNJ-minutes sur la minute ; produit : cumul des statistiques de production de la force).
  Journal : [FO-IA3D-<VARIANTE>]. Contrôle unique en fin de partie : au moins 100 relevés par minute écrits.
]]

local MIN = 3600
local SAMPLE = 60
local STATUS_EVERY = 300
local GAP_MAX = 3 -- relevés sans fabrication tolérés dans une séance
local QG_R = 22

local CAT = {
  ["automation-science-pack"] = "recherche", ["logistic-science-pack"] = "recherche", ["military-science-pack"] = "recherche",
  ["pistol"] = "recrue",
  ["submachine-gun"] = "armee", ["light-armor"] = "armee", ["heavy-armor"] = "armee", ["grenade"] = "armee",
  ["piercing-rounds-magazine"] = "armee", ["shotgun"] = "armee", ["shotgun-shell"] = "armee",
  ["firearm-magazine"] = "munitions",
  ["burner-mining-drill"] = "batiments", ["stone-furnace"] = "batiments", ["iron-chest"] = "batiments",
  ["gun-turret"] = "batiments", ["stone-wall"] = "batiments", ["wooden-chest"] = "batiments",
}

local STOCK = {
  { "iron-plate", "fer" }, { "copper-plate", "cuivre" }, { "coal", "charbon" }, { "stone", "pierre" },
  { "iron-ore", "minfer" }, { "copper-ore", "mincuivre" },
  { "steel-plate", "acier" }, { "stone-brick", "brique" }, { "iron-gear-wheel", "engr" }, { "electronic-circuit", "circ" },
  { "automation-science-pack", "rouge" }, { "logistic-science-pack", "vert" }, { "military-science-pack", "mil" },
  { "firearm-magazine", "chargeur" }, { "piercing-rounds-magazine", "perforant" }, { "grenade", "grenade" },
  { "pistol", "pistolet" }, { "submachine-gun", "smg" }, { "light-armor", "armure" }, { "burner-mining-drill", "foreuse" },
  { "stone-furnace", "four" }, { "gun-turret", "tourelle" },
}
local PRODUCED = {
  { "iron-plate", "fer" }, { "copper-plate", "cuivre" }, { "steel-plate", "acier" }, { "stone-brick", "brique" },
  { "automation-science-pack", "rouge" }, { "logistic-science-pack", "vert" }, { "military-science-pack", "mil" },
  { "firearm-magazine", "chargeur" }, { "pistol", "pistolet" }, { "submachine-gun", "smg" }, { "grenade", "grenade" },
}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function fmt_bucket(b, div)
  local out = {}
  for _, k in ipairs(sorted_keys(b or {})) do out[#out + 1] = string.format("%s:%.2f", k, b[k] / div) end
  return "{" .. table.concat(out, " ") .. "}"
end

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if not chest then return false end
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  return true
end

return function(variant)
local TAG_CHECK = 431000

local function teams_now(ctx)
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  if not ok or type(rows) ~= "table" then return {} end
  return rows
end

local function hq_of(s, row)
  local name = row.key == "player" and "fo-team-chest" or "fo-faction-hq"
  local e = s.find_entities_filtered({ name = name, force = row.force, limit = 1 })[1]
  return e
end

local function bucket(st, key)
  st.cur = st.cur or {}
  local b = st.cur[key]
  if not b then
    b = { act = {}, fab = {}, task = {}, samples = 0, status_samples = 0 }
    st.cur[key] = b
  end
  return b
end

local function add(t, k, n) t[k] = (t[k] or 0) + (n or 1) end

local function sample(ctx, st, tick)
  local s = ctx.surface()
  st.hq = st.hq or {}
  st.sess = st.sess or {}
  for _, row in ipairs(st.rows or {}) do
    local key = row.key
    local hqp = st.hq[key]
    local b = bucket(st, key)
    b.samples = b.samples + 1
    local chars = s.find_entities_filtered({ type = "character", force = row.force })
    local seen = {}
    for _, c in ipairs(chars) do
      if c.valid then
        local uid = c.unit_number
        seen[uid] = true
        local p = c.position
        local d = hqp and math.sqrt((p.x - hqp.x) ^ 2 + (p.y - hqp.y) ^ 2) or 999
        local sess = st.sess[uid]
        if c.crafting_queue_size > 0 then
          local q = c.crafting_queue
          local r = q and q[1] and q[1].recipe or "?"
          if not sess then
            sess = { n = 0, gap = 0, last = r, team = key }
            st.sess[uid] = sess
          end
          sess.n = sess.n + 1
          sess.gap = 0
          sess.last = r
          add(b.act, "fab")
        else
          if sess then
            sess.gap = sess.gap + 1
            if sess.gap > GAP_MAX then
              add(bucket(st, sess.team).fab, CAT[sess.last] or ("autre:" .. sess.last), sess.n)
              st.sess[uid] = nil
            end
          end
          if c.mining_state and c.mining_state.mining then
            add(b.act, "mine")
          elseif c.walking_state and c.walking_state.walking then
            add(b.act, d <= QG_R and "marche-qg" or "marche")
          elseif d <= QG_R then
            add(b.act, "arret-qg")
          else
            add(b.act, "arret-loin")
          end
        end
      end
    end
  end
  -- Séances des PNJ disparus : attribuées et fermées.
  for _, uid in ipairs(sorted_keys(st.sess)) do
    local sess = st.sess[uid]
    local alive = false
    for _, row in ipairs(st.rows or {}) do if row.key == sess.team then alive = true end end
    if not alive then st.sess[uid] = nil end
  end
  if tick % STATUS_EVERY == 0 then
    for _, row in ipairs(st.rows or {}) do
      local ok, status = pcall(remote.call, "fo-ia1", "team_status", row.key)
      if ok and type(status) == "table" then
        local b = bucket(st, row.key)
        b.status_samples = b.status_samples + 1
        for _, n in ipairs(status.npcs or {}) do
          local k = n.task or "inactif"
          if n.fond then k = k .. "(fond)" end
          add(b.task, k)
        end
      end
    end
  end
end

local function minute_line(ctx, st, tick)
  local s = ctx.surface()
  local m = math.floor(tick / MIN)
  for _, row in ipairs(st.rows or {}) do
    local key = row.key
    local b = bucket(st, key)
    local hq = hq_of(s, row)
    local stock = {}
    if hq and hq.valid then
      local inv = hq.get_inventory(defines.inventory.chest)
      local cont = inv and inv.get_contents() or {}
      for _, it in ipairs(STOCK) do stock[#stock + 1] = it[2] .. "=" .. (cont[it[1]] or 0) end
    end
    local prod = {}
    local force = game.forces[row.force]
    if force then
      local ps = force.item_production_statistics
      for _, it in ipairs(PRODUCED) do prod[#prod + 1] = it[2] .. "=" .. ps.get_input_count(it[1]) end
    end
    local d = row.delivered or {}
    local speed = 0
    local chars = s.find_entities_filtered({ type = "character", force = row.force })
    for _, c in ipairs(chars) do speed = speed + (c.character_crafting_speed_modifier or 0) end
    ctx.log(string.format("minute %d | %s tech %d soldats %d pnj %d/%d | taches %s | activite %s | fab %s | stock %s | produit %s | livre fer=%d cuivre=%d charbon=%d | vitesse_fab +%.2f",
      m, key, row.tech or 0, row.soldiers or 0, row.n or 0, row.max or 0,
      fmt_bucket(b.task, math.max(1, b.status_samples)), fmt_bucket(b.act, 60), fmt_bucket(b.fab, 60),
      table.concat(stock, " "), table.concat(prod, " "), d["iron-plate"] or 0, d["copper-plate"] or 0, d["coal"] or 0,
      #chars > 0 and speed / #chars or 0))
  end
  st.cur = {}
  st.lines = (st.lines or 0) + 1
end

local function refresh_rows(ctx, st)
  local s = ctx.surface()
  st.rows = teams_now(ctx)
  st.hq = {}
  for _, row in ipairs(st.rows) do
    local hq = hq_of(s, row)
    if hq and hq.valid then st.hq[row.key] = { x = hq.position.x, y = hq.position.y } end
  end
end

local INIT = {
  default = function(ctx)
    -- base « default » : war_start(4, 100, 10), 50 compagnons, Paisible (control.lua du banc).
  end,
  reduit = function(ctx)
    local ok = ctx.remote("fo-pvp", "set_difficulty", "easy")
    ctx.check(ok == true, "difficulte Facile imposee avant la guerre", tostring(ok))
    local started = ctx.call("war_start", 2, 30, 4)
    ctx.check(started == true, "guerre lancee : 2 factions, 30 soldats, 4 ouvriers", tostring(started))
    ctx.check(place_team_chest(ctx), "coffre d'equipe pose")
    ctx.call("profiler", true)
  end,
  trente = function(ctx)
    local ok = ctx.remote("fo-pvp", "set_difficulty", "easy")
    ctx.check(ok == true, "difficulte Facile imposee avant la guerre", tostring(ok))
    local w = ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", 30)
    ctx.check(w == 30, "fo-war-workers regle a 30", w)
    local started = ctx.call("war_start", 2, 30, 30)
    ctx.check(started == true, "guerre lancee : 2 factions, 30 soldats, 30 ouvriers", tostring(started))
    ctx.check(place_team_chest(ctx), "coffre d'equipe pose")
    ctx.call("profiler", true)
  end,
}

return {
  description = "IA3-DIAG : chronologie mesuree des equipes de PNJ (" .. variant .. ", 2 h)",
  base = variant == "default" and "default" or nil,
  check_tick = TAG_CHECK,

  init = function(ctx)
    INIT[variant](ctx)
    local cfg = {}
    for _, n in ipairs({ "fo-npc-start", "fo-war-workers", "fo-recruit-idle-max", "fo-player-team-npc-max", "fo-war-factions" }) do
      local v = settings.global[n] and settings.global[n].value
      cfg[#cfg + 1] = n .. "=" .. tostring(v)
    end
    ctx.log("reglages " .. table.concat(cfg, " "))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick % SAMPLE ~= 0 then return end
    if not st.rows or e.tick % MIN == 0 then
      if st.rows and e.tick > 0 then minute_line(ctx, st, e.tick) end
      refresh_rows(ctx, st)
    end
    sample(ctx, st, e.tick)
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check((st.lines or 0) >= 100, "releves par minute ecrits", st.lines)
  end,
}
end
