--[[
  MÉGA-FONDERIE, côté RUNTIME (lot MEGA-FONDERIE, tranche 1 ; règle pure : shared/team/mega_fonderie.lua ; conception :
  docs/MEGA_FONDERIE.md). Demande du DC du 8/11, 17 h 50 : « Les foreuses électriques doivent extraire en masse, envoyer les minerais sur
  de très gros bus (plusieurs lignes), qui alimentent ensuite des blocs rectangulaires entiers dédiés uniquement à la fonte ».

  Décision du CERVEAU, factions ET votre équipe : appelée par la capitalisation (script/ai3/capitalisation.lua, Capi.think) à l'étape 11
  de son cycle de 12 pensées (une fois par minute et par équipe ; étape libre jusqu'ici : une seule étape coûteuse par pensée), derrière le
  réglage de carte fo-war-mega-fonderie (settings/mega_fonderie.lua, vrai par défaut). Pour au plus Mega.PER_THINK gisements recensés
  (cs.deps, tour à tour) :
    1. le minerai a-t-il un four de champ (sorte d'avant-poste à four, comme MigChamp.takes) ; caractéristiques lues aux prototypes
       (Champ.data : foreuse, tapis débloqués, four, bras, poteau ; illisibles : refus « donnees : champ : <cause> ») ;
    2. Mf.size (gisement saturé : couverture 1) puis Mf.decide (courant : centrale finie ; crise : survie ou QG menacé) ;
    3. décision neuve : budget de départ (colonnes que le coffre paie, pièces d'une colonne comptées par Mf.col_cost et nommées par
       Champ.data), plan d'un ÉCHANTILLON du bloc (3 colonnes : Mf.sample) contrôlé par Mf.verify ; un plan faux est un refus ;
    4. journal [FO-MEGA] à chaque changement de verdict ou de cause (bloc décidé, taille, voies, fours, refus et cause).
  État : f.mega = { cursor, logs, logs_d, deps = { [id du gisement] = { state, cause, sig, ... nombres } } } : nombres et chaînes seulement,
  jamais d'entité ni de fonction. Lecteurs : Mega.block_for (tranche 2 : pose du bloc, Build.SITES.mega), Mega.summary (bancs).
  TRANCHE 2 (A2) : une décision "decide" ORDONNE le champ du gisement (Mega.order_field : MigChamp.want, bornes de Mp.par_max) : le champ
  est servi d'abord, sans paire exigée, et ses bandes partent EN AVANCE les unes des autres (script/team/migration_champ.lua, ahead_step ;
  règle pure shared/team/mega_pose.lua). La géométrie posée est celle du champ en colonnes alignées (shared/team/champ_colonne.lua).
  Journal [FO-MEGA] ... POSE (champ voulu, ou cause de l'attente : aucun réseau alimenté à portée d'une chaîne de poteaux).
  Aucun nom d'objet ici (tests/iag_test.lua §8 bis) : les noms viennent de Champ.data. Déterminisme : clés triées, aucun temps mesuré.
]]

local Mf = require("shared.team.mega_fonderie")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Stock = require("script.team.stock")
local Champ = require("script.team.champ")
local Mp = require("shared.team.mega_pose")
local MigChamp = require("script.team.migration_champ")
local V = require("shared.faction.valeur") -- lot PAVAGE-GEANT : règle R3 (gisement ouvert plus proche pas plein)

local Mega = {}

Mega.SETTING = "fo-war-mega-fonderie"
Mega.PER_THINK = 2   -- gisements relus au plus par pensée (étape 11 : une fois par minute)
Mega.LOGS = 60       -- lignes [FO-MEGA] d'attente ou de refus au plus par équipe
Mega.LOGS_D = 120    -- lignes [FO-MEGA] de décision au plus par équipe (comptées à part : jamais coupées par les refus)
Mega.POSE_RETRY = 3 * 3600 -- ticks : un champ en attente d'un réseau alimenté n'est redemandé qu'après 3 min
Mega.SAMPLE = 3      -- colonnes du bloc contrôlées (Mf.sample : première, une du milieu, la dernière partielle)

--- Le réglage de carte (absent avant que l'intégrateur requière settings/mega_fonderie.lua : éteint).
function Mega.on()
  local ok, v = pcall(function() return settings.global[Mega.SETTING].value end)
  return ok and v == true
end

local function team_name(f) return f.is_player and "player" or tostring(f.key or f.id or "?") end

local function state_of(f)
  local st = f.mega
  if not st then
    st = { cursor = 0, logs = 0, logs_d = 0, deps = {} }
    f.mega = st
  end
  return st
end

local function say(f, st, text, decision)
  if decision then
    st.logs_d = (st.logs_d or 0) + 1
    if st.logs_d > Mega.LOGS_D then return end
  else
    st.logs = (st.logs or 0) + 1
    if st.logs > Mega.LOGS then return end
  end
  log(text)
end

--- Plaques par minerai de la recette du four de cette sorte d'avant-poste (T.outposts : produit et minerai), 1 si illisible (2 pierres
--- font 1 brique : 0,5). Champ.data donne le débit d'un four en MINERAI ; les plaques et la voie de sortie en ont besoin.
local function yield_of(kind)
  local spec = T.outposts[kind]
  local rec = spec and game.recipe_prototypes[spec.product]
  if not rec then return 1 end
  local pin, pout = 0, 0
  for _, i in ipairs(rec.ingredients or {}) do if i.name == spec.resource then pin = i.amount or 0 end end
  for _, pr in ipairs(rec.products or {}) do
    if pr.name == spec.product then pout = pr.amount or ((pr.amount_min or 0) + (pr.amount_max or 0)) / 2 end
  end
  if pin <= 0 or pout <= 0 then return 1 end
  return pout / pin
end

--- Sorte d'avant-poste dont le réceptacle est un FOUR pour ce minerai (même règle que MigChamp.takes, sans exiger Champ.data : le journal
--- sépare « minerai sans four » de « champ illisible », que MigChamp.takes confond), ou nil.
local function furnace_kind(resource)
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    local proto = spec and spec.resource == resource and game.entity_prototypes[spec.sink]
    if proto and proto.type == "furnace" then return kind end
  end
  return nil
end

--- Colonnes que le coffre paie : pour chaque sorte de pièce d'une colonne pleine (Mf.col_cost), le stock BRUT du nom lu par Champ.data
--- divisé par le besoin ; le plus petit. Une sorte sans nom n'entre pas (elle sera fabriquée par le cerveau à la pose).
local function budget_cols(f, z, names)
  local cc = Mf.col_cost(z)
  local by_kind = { four = names.furnace, bras = names.arm, poteau = names.pole, coffre = names.chest,
    tapis = names.belts and names.belts[z.belt] or nil }
  local best = nil
  for _, kind in ipairs({ "bras", "coffre", "four", "poteau", "tapis" }) do
    local need, name = cc[kind] or 0, by_kind[kind]
    if need > 0 and name then
      local n = math.floor(Stock.count(f, name) / need)
      if not best or n < best then best = n end
    end
  end
  return best or 0
end

--- Un gisement recensé `dep` { id, resource, tiles, ... } : décision et journal. ctx = { power, crisis }, on = réglage.
local function consider(f, st, dep, tick, ctx, on)
  local rec = st.deps[dep.id]
  local dl = { id = dep.id, res = dep.resource, tiles = dep.tiles or 0 }
  local kind = on and furnace_kind(dep.resource) or nil
  local data, names, z, zwhy, fu
  if kind then
    data, names = Champ.data(f, kind)
    if not data then zwhy = "champ : " .. tostring(names)
    elseif not data.furnace then zwhy = "champ sans four"
    else
      local d = data.furnace
      fu = { size = d.size, rate = d.rate, fuel = d.fuel, fuel_rate = d.fuel_rate, yield = yield_of(kind) }
      z, zwhy = Mf.size({ tiles = dep.tiles or 0, cover = 1, drill = data.drill, belts = data.belts, furnace = fu,
        inserter = data.inserter, pole = data.pole })
    end
  end
  -- R3 (lot PAVAGE-GEANT) : un gisement ouvert plus proche du QG, du même minerai, pas plein (shared/faction/valeur.lua, V.unfull_distance)
  local hq = f.hq_pos or { x = 0, y = 0 }
  local d_unfull = V.unfull_distance(ctx.deps, dep.resource, hq, { x = dep.cx, y = dep.cy })
  local nearer = not V.admissible({ seeded = true, d_hq = math.sqrt((dep.cx - hq.x) ^ 2 + (dep.cy - hq.y) ^ 2) }, nil, d_unfull)
  local action, cause = Mf.decide({ on = on, smeltable = kind ~= nil, size = z, size_why = zwhy, power = ctx.power == true,
    crisis = ctx.crisis == true, sig = rec and rec.sig or nil, nearer = nearer })
  local extra = nil
  if action == "decider" then
    -- taille de départ au budget, puis plan d'un échantillon contrôlé : un plan faux ne se décide pas
    z = Mf.size({ tiles = dep.tiles or 0, cover = 1, drill = data.drill, belts = data.belts, furnace = fu,
      inserter = data.inserter, pole = data.pole, budget_cols = budget_cols(f, z, names) })
    local sm = Mf.sample(z, Mega.SAMPLE)
    local pl = Mf.block(sm)
    local bad = Mf.verify(pl, sm)
    if #bad > 0 then
      action, cause = "refuser", "plan faux : " .. bad[1]
    else
      extra = string.format("plan verifie sur %d colonne(s) (%d entites), tapis %s, four %s", sm.cols, #pl.ents,
        tostring(names.belts and names.belts[z.belt]), tostring(names.furnace))
    end
  end
  rec = rec or {}
  st.deps[dep.id] = rec
  rec.tick, rec.res = tick, dep.resource
  -- un minerai sans four de champ le restera (prototypes) : le curseur ne le relit plus (partie géants du 9/11, K1 : 20 gisements dont 11 de charbon
  -- ou de pierre relus deux par minute retardaient de 6 min la première décision des factions)
  rec.static = (on and kind == nil) and true or nil
  if action == "decider" then
    rec.state, rec.sig, rec.decided = "decide", Mf.signature(z), tick
    rec.lines, rec.cols, rec.furnaces, rec.ncol, rec.drills = z.lines, z.cols, z.furnaces, z.ncol, z.drills
    rec.ore, rec.plates, rec.combustible, rec.w, rec.h, rec.start, rec.belt = z.ore, z.plates, z.combustible, z.w, z.h, z.start, z.belt
  elseif action == "garder" then
    rec.state = "decide"
  elseif action == "attendre" then
    rec.state = rec.sig and "decide-attente" or "attente"
  else
    rec.state, rec.sig = "refuse", nil
  end
  local verdict = (action == "decider" and "DECIDE") or (action == "garder" and "GARDE") or (action == "attendre" and "ATTENTE") or "REFUS"
  -- « garder » après « decider » : même état, aucune ligne ; après une attente, la ligne dit le retour
  local key = (action == "decider" or action == "garder") and "decide" or (verdict .. ":" .. cause)
  if action == "decider" or key ~= rec.last then
    rec.last, rec.cause = key, cause
    say(f, st, Mf.line(team_name(f), dl, verdict, cause, action == "decider" and z or nil, extra, tick / 3600), action == "decider")
  end
  return action
end

--- Tranche 2 (A2) : une décision `rec` sur le gisement recensé `dep` ordonne son champ au passage de la migration (une fois par minute : la
--- cible reste « voulue » CFG.want_ttl). Lecteurs de rec.field et rec.pose : Mega.summary (bancs), le journal. Rend le numéro du champ ou nil.
local function order_field(f, st, dep, rec, tick)
  -- un champ qui attend un réseau alimenté n'est redemandé que toutes les Mega.POSE_RETRY ticks (la recherche du poteau alimenté le plus proche, rayon
  -- Champ.CFG.chain_r, coûte au moteur ; mesuré au banc : 13 ms au premier appel d'une pensée chargée)
  if rec.pose_next and tick < rec.pose_next then return rec.field end
  local fid, produced = MigChamp.want(f, dep, tick, Mp.par_max(rec))
  local key = fid and "champ" or ("attente:" .. tostring(produced))
  rec.pose_next = (not fid) and (tick + Mega.POSE_RETRY) or nil
  rec.field = fid
  if fid then rec.produced = produced or 0 end
  if key ~= rec.pose_key then
    rec.pose_key = key
    local dl = { id = dep.id, res = dep.resource, tiles = dep.tiles or 0 }
    say(f, st, Mf.line(team_name(f), dl, "POSE", fid and string.format("champ %s voulu, %d bande(s) en vol au plus", tostring(fid), Mp.par_max(rec))
      or ("champ en attente : " .. tostring(produced)), nil, nil, tick / 3600), true)
  end
  return fid
end

--- Courant de l'équipe, lu À L'INSTANT (partie 1618033988, scarlet, 117 à 119 min : une 2e centrale demandée sort Auto.plant_state de « fini » et la
--- décision repassait en « aucun reseau qui produit » alors que 4 centrales donnaient 3 890 kW ; le champ cessait d'être voulu). Un réseau est là si la
--- capitalisation dit « centrale finie » OU si le suivi de santé du réseau (f.build.sante.healthy, relevé toutes les quelques secondes par
--- script/team/reseau_vivant.lua, aussi lu par la migration du champ) le dit sain. Une panne réelle (aucune centrale finie ET réseau malsain) reste vue.
function Mega.power(f, ctx)
  if ctx and ctx.power == true then return true end
  local sv = f and f.build and f.build.sante
  return sv ~= nil and sv.healthy == true
end

--- Une étape de décision (capitalisation, étape 11). cs = f.team.capi (cs.deps : gisements recensés) ; ctx = { power, crisis }.
--- Rend le nombre de gisements relus.
function Mega.think(f, cs, tick, ctx)
  if not (f and cs and cs.deps) then return 0 end
  local on = Mega.on()
  if not on then return 0 end -- réglage éteint : rien de lu, rien d'écrit (pas de refus au journal)
  local st = state_of(f)
  -- un refus ou une attente d'un gisement qui n'est plus recensé est oublié (état borné) ; une décision est gardée (la pose la lira)
  for _, id in ipairs(State.sorted_keys(st.deps)) do
    local rec = st.deps[id]
    if not cs.deps[id] and (rec.state == "refuse" or rec.state == "attente") then st.deps[id] = nil end
  end
  local ids = State.sorted_keys(cs.deps)
  if #ids == 0 then return 0 end
  local power = Mega.power(f, ctx)
  local deps = {} -- R3 (lot PAVAGE-GEANT) : gisements recensés, couverture mesurée et verdict « plein » de la capitalisation
  for _, id in ipairs(ids) do deps[#deps + 1] = cs.deps[id] end
  -- le curseur avance sur la liste ENTIÈRE et saute les gisements « statiques » (minerai sans four) : il lit Mega.PER_THINK gisements vivants
  local n, scanned = 0, 0
  while n < Mega.PER_THINK and scanned < #ids do
    st.cursor = (st.cursor or 0) % #ids + 1
    scanned = scanned + 1
    local dep = cs.deps[ids[st.cursor]]
    local known = st.deps[dep.id]
    if not (known and known.static) then
      consider(f, st, dep, tick, { power = power, crisis = ctx and ctx.crisis, deps = deps }, on)
      local rec = st.deps[dep.id]
      if rec and rec.state == "decide" then order_field(f, st, dep, rec, tick) end
      n = n + 1
    end
  end
  return n
end

--- Lot MEGA-FONDERIE, tranche 2 (pose) : la décision d'un gisement, ou nil. Lecture seule.
function Mega.block_for(f, dep_id)
  local st = f and f.mega
  local rec = st and st.deps and st.deps[dep_id]
  if rec and (rec.state == "decide" or rec.state == "decide-attente") then return rec end
  return nil
end

--- Résumé pour les bancs : nombres seulement.
function Mega.summary(f)
  local out = { decided = 0, refused = 0, waiting = 0, furnaces = 0, lines = 0, fields = 0 }
  local st = f and f.mega
  for _, id in ipairs(State.sorted_keys(st and st.deps or {})) do
    local rec = st.deps[id]
    if rec.state == "decide" or rec.state == "decide-attente" then
      out.decided = out.decided + 1
      out.furnaces, out.lines = out.furnaces + (rec.furnaces or 0), out.lines + (rec.lines or 0)
      if rec.field then out.fields = out.fields + 1 end
    elseif rec.state == "refuse" then out.refused = out.refused + 1
    else out.waiting = out.waiting + 1 end
  end
  return out
end

return Mega
