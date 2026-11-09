--[[
  PURETE, côté RUNTIME (règle pure : shared/team/purete.lua ; lot PURETE-TAPIS, retour du DC du 8/11 en jouant la 0.6.71 : « Une ligne d'output
  ne doit jamais fusionner avec une ligne d'input qui attend un objet différent. »). Rien de décisionnel ici : ce fichier LIT le moteur (tapis,
  répartiteurs, souterrains et leurs fantômes, de TOUTES les forces) et le plan de l'équipe (tapis des projets, objet déclaré de leur ligne),
  appelle la règle, et écrit le journal [FO-PURETE].

  Services :
    - Pur.fronts(f, surface, item, p, opts) -> function(x, y) -> vrai si la tuile (x, y) est interdite à une ligne de `item` parce qu'un tapis
      ÉTRANGER y verse (cause b) ; à brancher dans le `cost` de l'A* (cost nil = coût infini). Lecture paresseuse par chunk (cache LOCAL, jamais
      dans global). opts.world_only : sans les tapis du plan (les poseurs qui ont déjà leur garde des tapis du plan : liaison, rapatriement).
    - Pur.check_route(f, surface, p, module, tiles, item, targets, opts) -> ok, raison : la preuve complète d'un tracé (causes a, b, c, d) contre
      une lecture FRAÎCHE du monde autour du tracé et le plan ; un refus est journalisé ; targets = { [tkey] = true } (tuile où la dernière tuile
      peut verser), opts.own = { [tkey] = true } (tuiles de notre projet, pas encore réservées).
    - Pur.front_ok(f, surface) -> function(x, y) -> faux si un tapis du monde ou du plan occupe la tuile (devant la queue d'un gabarit, P.fit).
    - Pur.feeding(surface, x, y, dir) -> liste des tapis du monde (toutes forces) qui versent sur (x, y) en regardant la direction `dir`.
  Réglage de banc : Pur.set_enabled(false) rend tout inerte (les anciens gardes restent).
  Mémoire : caches LOCAUX (vides à chaque chargement) ; rien dans global sauf les compteurs de f.build.stats.purete, créés à la demande.
]]

local P = require("shared.team.plan")
local Pu = require("shared.team.purete")
local Conv = require("script.team.convoyeurs")
local State = require("script.faction.state") -- (interface de banc seulement ; require interdit pendant un événement, F24)

local Pur = {}

Pur.ENABLED = true
Pur.LOGS = 60               -- lignes [FO-PURETE] au plus par équipe (hors bilan)
Pur.BILAN_TICKS = 18000     -- un bilan par équipe et par tranche de 5 minutes
Pur.TTL = 120               -- ticks : vie d'un chunk lu au moteur
Pur.CACHE_MAX = 300         -- chunks gardés au plus par surface
Pur.AREA_MAX = 200          -- côté de la zone lue au plus pour la preuve d'un tracé (relais de centrale au-delà : pas de preuve, le garde de l'A* reste)

function Pur.set_enabled(on) Pur.ENABLED = on and true or false end

local tkey = Pu.tkey
local floor, ceil = math.floor, math.ceil
local TYPES = { "transport-belt", "underground-belt", "splitter" } -- types de prototype des pièces qui portent des objets

---------------------------------------------------------------------------------------------------
-- Lecture du moteur
---------------------------------------------------------------------------------------------------
local function add_rec(out, e, ghost)
  if not e.valid then return end
  local ty = ghost and e.ghost_type or e.type
  local dir = e.direction
  if ty == "splitter" then
    local bb = e.bounding_box -- un répartiteur occupe deux tuiles : chacune verse devant elle
    for y = floor(bb.left_top.y + 0.01), ceil(bb.right_bottom.y - 0.01) - 1 do
      for x = floor(bb.left_top.x + 0.01), ceil(bb.right_bottom.x - 0.01) - 1 do
        out[#out + 1] = { x = x, y = y, dir = dir, kind = "splitter" }
      end
    end
  else
    local kind = "belt"
    if ty == "underground-belt" then
      if ghost then kind = "ug" else kind = (e.belt_to_ground_type == "input") and "ug_in" or "ug_out" end
    end
    out[#out + 1] = { x = floor(e.position.x), y = floor(e.position.y), dir = dir, kind = kind }
  end
end

--- Tapis, souterrains et répartiteurs du monde (posés et fantômes, toutes forces) d'une zone [x0, x1) x [y0, y1). Liste d'enregistrements.
local function read_recs(surface, x0, y0, x1, y1)
  local out = {}
  local area = { { x0, y0 }, { x1, y1 } }
  for _, e in ipairs(surface.find_entities_filtered({ area = area, type = TYPES })) do add_rec(out, e, false) end
  for _, e in ipairs(surface.find_entities_filtered({ area = area, type = "entity-ghost", ghost_type = TYPES })) do add_rec(out, e, true) end
  return out
end

--- Tapis du monde qui versent sur la tuile (x, y) (lecture fraîche, toutes forces) : tuiles voisines tournées vers elle.
function Pur.feeding(surface, x, y)
  local out = {}
  for _, r in ipairs(read_recs(surface, x - 1, y - 1, x + 2, y + 2)) do
    local v = Pu.DV[r.dir]
    if v and Pu.outputs(r) and r.x + v[1] == x and r.y + v[2] == y then out[#out + 1] = r end
  end
  return out
end

-- Cache LOCAL des chunks de 32 x 32 (avec une marge d'une tuile : un tapis juste hors du chunk qui verse dedans y est lu aussi).
local ENG = {}
local function eng_chunk(surface, cx, cy)
  local si = surface.index or 0 -- (une doublure de banc hors jeu n'a pas d'index)
  local sc = ENG[si]
  if not sc then sc = { n = 0, by = {} }; ENG[si] = sc end
  local ck = tkey(cx, cy)
  local e = sc.by[ck]
  if e and game.tick - e.tick < Pur.TTL then return e end
  if not e then
    sc.n = sc.n + 1
    if sc.n > Pur.CACHE_MAX then sc.n, sc.by = 1, {} end
  end
  local x0, y0 = cx * 32, cy * 32
  local byk, fronts = {}, {}
  for _, r in ipairs(read_recs(surface, x0 - 1, y0 - 1, x0 + 33, y0 + 33)) do
    byk[tkey(r.x, r.y)] = r
    local v = Pu.DV[r.dir]
    if v and Pu.outputs(r) then
      local k = tkey(r.x + v[1], r.y + v[2])
      local l = fronts[k]
      if not l then l = {}; fronts[k] = l end
      l[#l + 1] = r
    end
  end
  e = { tick = game.tick, byk = byk, fronts = fronts }
  sc.by[ck] = e
  return e
end

---------------------------------------------------------------------------------------------------
-- Lecture du plan
---------------------------------------------------------------------------------------------------
local BELTSET
local function belt_set()
  if BELTSET then return BELTSET end
  local s = {}
  if type(Conv.belts) == "function" then -- (une doublure de banc hors jeu n'a que choose : le motif « belt » des noms prend le relais)
    for _, b in ipairs(Conv.belts()) do s[b.name] = true end
  end
  BELTSET = s
  return s
end

local function plan_kind(e)
  if e.type == "input" then return "ug_in" end
  if e.type == "output" then return "ug_out" end
  if e.piq then return "splitter" end
  if belt_set()[e.name] then return "belt" end
  if type(e.name) == "string" and e.name:find("belt", 1, true) then return "belt" end -- pièce de gabarit inconnue des données, comme les anciens gardes
  return nil
end

--- Objet déclaré de la ligne d'une pièce de projet (liaison, rapatriement) ; nil si le projet ne le dit pas (gabarit, ligne de foreuses…).
local function declared(q, e)
  if type(e.carries) == "string" or type(e.carries) == "table" then return e.carries end -- une pièce peut déclarer son objet (ou sa liste d'objets, un par voie)
  local sp = q.spec
  if e.role == "liaison-tapis" and sp then
    local lc = sp.liaison or sp.rapatriement
    if lc and type(lc.item) == "string" then return lc.item end
  end
  return nil
end

local DEAD = { refuse = true }

-- Tapis d'UN projet, par tuile (cache LOCAL à clés faibles, refait quand le nombre de pièces change) : lu seulement pour les projets que la
-- recherche touche (b.occ donne le projet d'une tuile), jamais en entier pour toute l'équipe (200 projets de 120 pièces = 1,2 M d'instructions).
local PIDX = setmetatable({}, { __mode = "k" })
local function pidx(q)
  local ents = q.ents or {}
  local c = PIDX[q]
  if c and c.n == #ents then return c.recs end
  local recs = {}
  for _, e in ipairs(ents) do
    local kind = plan_kind(e)
    if kind then
      local dir = e.dir or 0
      if kind == "splitter" then
        local ok, tiles = pcall(P.tiles_of, e)
        if ok then
          for _, t in ipairs(tiles) do recs[tkey(t[1], t[2])] = { x = t[1], y = t[2], dir = dir, kind = kind, item = declared(q, e) } end
        end
      else
        local x, y = floor(e.x), floor(e.y)
        recs[tkey(x, y)] = { x = x, y = y, dir = dir, kind = kind, item = declared(q, e) }
      end
    end
  end
  PIDX[q] = { n = #ents, recs = recs }
  return recs
end

--- Tapis du plan (projet de l'équipe autre que `p`, ni refusé ni abandonné) à la tuile de clé k, ou nil.
local function plan_rec(b, p, k)
  local id = b.occ[k]
  if not id or (p and id == p.id) then return nil end
  local q = b.projects[id]
  if not q or q.abandoned or DEAD[q.state] then return nil end
  return pidx(q)[k]
end

local DIRS = { 0, 2, 4, 6 }
--- Un tapis du plan verse-t-il sur la tuile (x, y) ? (le plan prend toute pièce qui verse : jamais d'objet comparé, comme les anciens gardes)
local function plan_pours(b, p, x, y)
  local occ, DV = b.occ, Pu.DV
  for i = 1, 4 do
    local d = DIRS[i]
    local v = DV[d]
    local k = (x - v[1] + 1048576) * 2097152 + (y - v[2] + 1048576)
    if occ[k] then -- (la tuile voisine appartient à un projet : son tapis la regarde-t-il vers nous ?)
      local r = plan_rec(b, p, k)
      if r and r.dir == d and Pu.outputs(r) then return true end
    end
  end
  return false
end

---------------------------------------------------------------------------------------------------
-- Journal et compteurs
---------------------------------------------------------------------------------------------------
local function stats_of(f)
  local st = f.build and f.build.stats
  if not st then return nil end
  st.purete = st.purete or { checks = 0, refused = 0, tails = 0, why = {}, slot = 0, logs = 0 }
  st.purete.why = st.purete.why or {}
  return st.purete
end

local function bilan(f, c)
  local slot = floor(game.tick / Pur.BILAN_TICKS)
  if slot == c.slot then return end
  c.slot = slot
  local keys, causes = {}, {}
  for k in next, c.why do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do causes[#causes + 1] = string.format("%s %d", k, c.why[k]) end
  log(string.format("[FO-PURETE] %s : bilan a %.1f min : %d trace(s) controle(s), %d refuse(s), %d place(s) de gabarit ecartee(s) pour une queue contre un tapis ; causes [%s]",
    f.key or "player", game.tick / 3600, c.checks, c.refused, c.tails, table.concat(causes, ", ")))
end

local function say(f, c, line)
  c.logs = (c.logs or 0) + 1
  if c.logs <= Pur.LOGS then log(line) end
end

---------------------------------------------------------------------------------------------------
-- Services
---------------------------------------------------------------------------------------------------
local NONE = function() return false end

function Pur.fronts(f, surface, item, p, opts)
  if not Pur.ENABLED then return NONE end
  local b = f.build
  local with_plan = not (opts and opts.world_only)
  local lx, ly, lf -- chunk courant (coin et table des tuiles visées) : l'A* demande des tuiles voisines, le plus souvent du même chunk
  return function(x, y)
    local k = (x + 1048576) * 2097152 + (y + 1048576) -- (Pu.tkey, en ligne : appelé pour chaque tuile de chaque recherche)
    if with_plan and plan_pours(b, p, x, y) then return true end
    if lx == nil or x < lx or x >= lx + 32 or y < ly or y >= ly + 32 then
      local cx, cy = floor(x / 32), floor(y / 32)
      lx, ly = cx * 32, cy * 32
      lf = eng_chunk(surface, cx, cy).fronts
    end
    local srcs = lf[k]
    if srcs then
      for _, r in ipairs(srcs) do
        if Pu.foreign(r, item) then return true end
      end
    end
    return false
  end
end

function Pur.front_ok(f, surface)
  if not Pur.ENABLED then return nil end
  local b = f.build
  local c = stats_of(f)
  local seen = {}
  local lx, ly, lb -- chunk courant (voir Pur.fronts) : P.fit demande des milliers de tuiles voisines
  return function(x, y)
    local k = (x + 1048576) * 2097152 + (y + 1048576)
    local r
    if b.occ[k] then r = plan_rec(b, nil, k) end
    if not r then
      if lx == nil or x < lx or x >= lx + 32 or y < ly or y >= ly + 32 then
        local cx, cy = floor(x / 32), floor(y / 32)
        lx, ly = cx * 32, cy * 32
        lb = eng_chunk(surface, cx, cy).byk
      end
      r = lb[k]
    end
    if r then
      if c and not seen[k] then
        seen[k] = true
        c.tails = c.tails + 1
        bilan(f, c)
        say(f, c, string.format("[FO-PURETE] %s gabarit : place ecartee, la queue d'un tapis du gabarit verserait sur un tapis (%s) en (%d, %d)",
          f.key or "player", Pu.label(r), x, y))
      end
      return false
    end
    return true
  end
end

--- Preuve d'un tracé. Rend vrai, ou faux et la raison (texte pour la raison de refus du projet).
function Pur.check_route(f, surface, p, module, tiles, item, targets, opts)
  if not Pur.ENABLED or not tiles or #tiles == 0 then return true end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, t in ipairs(tiles) do
    if t.x < x0 then x0 = t.x end
    if t.x > x1 then x1 = t.x end
    if t.y < y0 then y0 = t.y end
    if t.y > y1 then y1 = t.y end
  end
  if x1 - x0 > Pur.AREA_MAX or y1 - y0 > Pur.AREA_MAX then return true end
  local eng = {}
  for _, r in ipairs(read_recs(surface, x0 - 1, y0 - 1, x1 + 2, y1 + 2)) do eng[tkey(r.x, r.y)] = r end
  local b = f.build
  local function lookup(x, y)
    local k = tkey(x, y)
    local pr, er = plan_rec(b, p, k), eng[k]
    if pr and er then return { x = x, y = y, dir = er.dir, kind = er.kind, item = pr.item } end -- géométrie du moteur, objet déclaré du plan
    return pr or er
  end
  local own = (opts and opts.own) or {}
  local ok, bad = Pu.check(tiles, item, lookup, { targets = targets or {}, own = own })
  local c = stats_of(f)
  if c then
    c.checks = c.checks + 1
    if not ok then
      c.refused = c.refused + 1
      for _, r in ipairs(bad) do c.why[r.cause] = (c.why[r.cause] or 0) + 1 end
    end
    bilan(f, c)
  end
  if ok then return true end
  local r = bad[1]
  if c then say(f, c, Pu.line(string.format("%s %s projet %s", f.key or "player", module, tostring(p and p.id or "?")), r)) end
  return false, string.format("purete: %s (objet %s contre %s en %d, %d)", r.cause, tostring(r.mine), tostring(r.other), r.wx, r.wy)
end

---------------------------------------------------------------------------------------------------
-- Interface de BANC (jamais appelée par le mod) : le micro-scénario « purete-micro » (tools/autotest/fo-autotest/scenarios/purete_micro_common.lua)
---------------------------------------------------------------------------------------------------
local function team_of_key(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

if remote and remote.add_interface then
  remote.add_interface("fo-purete", {
    --- Preuve d'un tracé : tiles = { {x, y, dir, ug}, ... }, targets = { {x, y}, ... }. Rend { ok, causes = { "cause", ... }, why }.
    check = function(key, tiles, item, targets)
      local f = team_of_key(key)
      if not (f and f.build and type(tiles) == "table") then return nil end
      local t = {}
      for _, x in ipairs(targets or {}) do t[tkey(x[1], x[2])] = true end
      local before = stats_of(f)
      local n0 = before and before.refused or 0
      local ok, why = Pur.check_route(f, game.surfaces[1], nil, "banc", tiles, item, t, nil)
      return { ok = ok, why = why, refused = (stats_of(f) or {}).refused ~= n0 }
    end,
    --- La tuile (x, y) est-elle interdite à une ligne de `item` ?
    forbidden = function(key, item, x, y)
      local f = team_of_key(key)
      if not (f and f.build) then return nil end
      return Pur.fronts(f, game.surfaces[1], item, nil)(x, y)
    end,
    --- Compteurs { checks, refused, tails, why = { cause = n } } de l'équipe.
    report = function(key)
      local f = team_of_key(key)
      return f and f.build and stats_of(f) or nil
    end,
    set_enabled = function(on) Pur.set_enabled(on) return Pur.ENABLED end,
  })
end

return Pur
