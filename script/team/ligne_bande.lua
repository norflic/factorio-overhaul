--[[
  LIGNE ÉLECTRIQUE DE BANDE, partie moteur (lot RACCORD-BANDE 2 ; règle pure : shared/team/ligne_bande.lua). Partie neuve 0.6.72 : le réseau alimenté
  est à 163-281 tuiles des gisements, le raccord local d'une bande (shared/team/champ_raccord.lua) ne peut rien trouver. Un joueur tire une LIGNE de
  poteaux de la centrale au gisement : c'est un projet du plan directeur à part (site « ligne_bande »), posé par les PNJ comme tout chantier.

    LB.ensure(f, surface, band, fail, wire, pole)  appelé par le raccord d'une bande qui n'a trouvé aucune chaîne locale : demande LA ligne de
        l'avant-poste (une seule, partagée par ses bandes) ou suit celle qui existe. Rend vrai, raison (la bande attend) ou faux, raison.
    Build.SITES.ligne_bande                        le planificateur du site : UN tronçon de ligne par passe (shared/team/ligne_bande.lua, Lb.step), le
        terrain lu chunk par chunk au moteur (comme Far.line) ; le projet reste « en attente » entre deux passes (branche « loin » de build.lua).

  État : spec.lg du projet de ligne (nombres), p.lgs (état de la recherche : nombres et tables de nombres), f.build.lignes[oid] = { pid, tries }.
  Cache de chunks LOCAL (jamais dans global), perdu au chargement : la recherche relit les chunks, rien d'autre. Journal [FO-LIGNE-BANDE].
]]

local P = require("shared.team.plan")
local Lb = require("shared.team.ligne_bande")
local Cl = require("shared.team.centrale_loin")

local LB = {}

LB.LOGS = 40            -- lignes de journal au plus par équipe
LB.LINE_MIN = 40        -- tuiles : en dessous, le refus du raccord local est un refus de terrain, pas une distance
LB.LINE_FAR = 100       -- tuiles : au-delà, aucun palier local n'y mène : la ligne est demandée sans les essayer
LB.TRIES = 3            -- demandes de ligne au plus par avant-poste (projets refusés)
LB.CACHE_TTL = 3600     -- ticks de vie du cache de chunks d'une ligne
LB.POLL = 600           -- ticks d'attente d'une bande pendant que sa ligne se construit

local floor, sqrt = math.floor, math.sqrt

local CACHE = {} -- [pid] = { tick, chunks = { ["cx:cy"] = { water, blocked, clear } | false } }

local function say(f, text)
  local b = f.build
  b.lignes_logs = (b.lignes_logs or 0) + 1
  if b.lignes_logs <= LB.LOGS then log(string.format("[FO-LIGNE-BANDE] %s : %s", f.key or "player", text)) end
end

local function chunks_of(p, tick)
  local c = CACHE[p.id]
  if not c or tick - c.tick > LB.CACHE_TTL then
    c = { tick = tick, chunks = {} }
    CACHE[p.id] = c
  end
  return c
end

--- API GÉNÉRIQUE (méga-fonderie, champs) : demande LA ligne de la clé `key` (un avant-poste, un bloc de fonte...) d'un poteau alimenté `a` { x, y } jusqu'au poteau
--- ou au point `b` { x, y } à alimenter, avec le poteau obtenable `pole` de portée `wire`. Une seule ligne par clé : appelée de nouveau, elle suit la ligne
--- existante et, refusée 3 fois (LB.TRIES), rend faux. Rend vrai, raison (la ligne vit ou vient d'être demandée) ou faux, raison.
function LB.request(f, key, a, b, wire, pole, prio, tick)
  local bd = f.build
  if not (a and b and a.x and b.x) then return false, "ligne : cible inconnue" end
  bd.lignes = bd.lignes or {}
  local k = tostring(key)
  local rec = bd.lignes[k]
  if rec then
    local lp = bd.projects[rec.pid]
    if lp and lp.state ~= "refuse" and not lp.abandoned then
      if lp.state ~= "fini" then return true, string.format("ligne electrique en cours (projet %d, %s)", rec.pid, tostring(lp.state)) end
      rec.fini_seen = (rec.fini_seen or 0) + 1
      if rec.fini_seen <= 4 then return true, string.format("ligne electrique finie (projet %d), raccord au prochain essai", rec.pid) end
      -- finie et la cible n'est toujours pas alimentée après 4 essais : une nouvelle ligne est demandée (depuis le réseau tel qu'il est maintenant)
      bd.lignes[k], rec = nil, nil
    else
      rec.tries = (rec.tries or 0) + 1
      if rec.tries >= LB.TRIES then return false, string.format("ligne electrique refusee %d fois (%s)", rec.tries, tostring(lp and lp.reason)) end
    end
  end
  local spec = { site = "ligne_bande", lg = { oid = key, ax = a.x, ay = a.y, bx = b.x, by = b.y, reach = wire, pole = pole },
    near = { x = b.x, y = b.y }, prio = prio, domain = "infrastructures", lazy_clear = true }
  local pid = LB.Build.request(f, spec)
  if not pid then return false, "ligne : demande refusee" end
  bd.lignes[k] = { pid = pid, tries = rec and rec.tries or 0 }
  say(f, string.format("projet %d : ligne electrique demandee pour %s, du poteau alimente (%.0f, %.0f) a (%.0f, %.0f), %.0f tuiles (portee %.1f) a %.1f min",
    pid, k, a.x, a.y, b.x, b.y, sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2), wire, tick / 3600))
  return true, string.format("ligne electrique demandee (projet %d)", pid)
end

--- Lecture : état de la ligne de la clé. Rend "absente" | "en cours" | "finie" | "refusee", numéro du projet, raison.
function LB.status(f, key)
  local rec = f.build.lignes and f.build.lignes[tostring(key)]
  if not rec then return "absente" end
  local lp = f.build.projects[rec.pid]
  if not lp then return "absente", rec.pid end
  if lp.state == "fini" then return "finie", rec.pid end
  if lp.state == "refuse" or lp.abandoned then return "refusee", rec.pid, lp.reason end
  return "en cours", rec.pid, lp.state
end

--- Demande LA ligne de l'avant-poste d'une bande de champ (raccord de bande) ou suit celle qui existe. fail = { at (poteau de la bande), to (poteau alimenté) }.
function LB.ensure(f, surface, band, fail, wire, pole, tick)
  local cs = band.spec and band.spec.champ
  local oid = cs and cs.oid
  if oid == nil or not (fail and fail.to and fail.at) then return false, "ligne : cible inconnue" end
  return LB.request(f, oid, fail.to, fail.at, wire, pole, band.prio, tick)
end

--- Le planificateur du site : un tronçon par passe. h = { read_masks }.
local function plan_site(f, surface, p, h)
  local b = f.build
  local lg = p.spec.lg
  local tick = game.tick
  local cc = chunks_of(p, tick)
  local missing, mset = {}, {}
  local function chunk(cx, cy)
    local ck = cx .. ":" .. cy
    local c = cc.chunks[ck]
    if c == nil then
      if surface.is_chunk_generated({ x = cx, y = cy }) then
        local m = h.read_masks(cx * 32, cy * 32, cx * 32 + 32, cy * 32 + 32)
        c = { water = m.water, blocked = m.blocked, clear = m.clear }
        cc.chunks[ck] = c
      else
        c = false -- (non gardé : le chunk peut être généré à la passe suivante)
        if not mset[ck] then mset[ck] = true missing[#missing + 1] = { cx, cy } end
      end
    end
    return c
  end
  local function ground(tx, ty)
    local c = chunk(floor(tx / 32), floor(ty / 32))
    if not c then return nil end
    local k = P.tkey(tx, ty)
    if c.water[k] or c.blocked[k] or b.occ[k] then return nil end
    return c, k
  end
  local function free(x, y, trees)
    local c, k = ground(floor(x), floor(y))
    if not c then return false end
    return trees or not c.clear[k]
  end
  local st = p.lgs
  if not st then
    st = Lb.new({ x = lg.ax, y = lg.ay }, { x = lg.bx, y = lg.by }, lg.reach)
    p.lgs = st
  end
  local shift0, trees0, fails0 = st.shift, st.trees, st.fails
  local status, why = Lb.step(st, { free = free, pole_chain = P.pole_chain,
    opts = function(dist) return { div = 2, max_cells = 200, max_expand = 250, widths = { 1, 2 } } end })
  if status == "more" then
    if #missing > 0 then
      -- terrain non généré : l'essai ne compte pas, les chunks sont demandés, nouvel essai dans Cl.POLL ticks
      st.shift, st.trees, st.fails = shift0, trees0, fails0
      for i = 1, math.min(#missing, 16) do surface.request_to_generate_chunks({ missing[i][1] * 32 + 16, missing[i][2] * 32 + 16 }, 0) end
      p.far_poll = Cl.POLL
      return nil, string.format("ligne de bande : terrain en generation (%d chunk(s))", #missing), "loin"
    end
    p.far_poll = Cl.RETRY
    return nil, string.format("ligne de bande : %d poteau(x), %.0f tuiles restantes", #st.poles, Lb.remaining(st)), "loin"
  end
  if status == "fail" then
    if #missing > 0 then
      st.shift, st.trees, st.fails = shift0, trees0, fails0
      for i = 1, math.min(#missing, 16) do surface.request_to_generate_chunks({ missing[i][1] * 32 + 16, missing[i][2] * 32 + 16 }, 0) end
      p.far_poll = Cl.POLL
      return nil, "ligne de bande : terrain en generation", "loin"
    end
    say(f, string.format("projet %d : ligne refusee : %s", p.id, tostring(why)))
    CACHE[p.id] = nil
    return nil, "ligne impossible : " .. tostring(why)
  end
  -- ligne complète : poteaux, points d'appui, masques des chunks lus
  local ents = {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, c in ipairs(st.poles) do
    local e = { name = lg.pole, x = c.x, y = c.y, dir = 0, role = "liaison" }
    ents[#ents + 1] = e
    x0, y0, x1, y1 = math.min(x0, c.x), math.min(y0, c.y), math.max(x1, c.x), math.max(y1, c.y)
  end
  if #ents == 0 then return nil, "ligne de bande : aucun poteau a poser (deja a portee)" end
  local masks = { water = {}, blocked = {}, clear = {} }
  for ck in pairs(cc.chunks) do
    local c = cc.chunks[ck]
    if c then
      for k in pairs(c.water) do masks.water[k] = true end
      for k in pairs(c.blocked) do masks.blocked[k] = true end
      for k in pairs(c.clear) do masks.clear[k] = true end
    end
  end
  masks.free = function(tx, ty) return not (masks.water[P.tkey(tx, ty)] or masks.blocked[P.tkey(tx, ty)] or b.occ[P.tkey(tx, ty)]) end
  say(f, string.format("projet %d : ligne de %d poteau(x) (portee %.1f) du poteau alimente (%.0f, %.0f) a la bande (%.0f, %.0f), %d troncon(s), %d essai(s) rate(s)%s",
    p.id, #ents, lg.reach, lg.ax, lg.ay, lg.bx, lg.by, st.legs, st.fails, st.trees and ", a travers bois" or ""))
  CACHE[p.id] = nil
  return { key = "ligne:" .. tostring(lg.oid) .. ":" .. p.id, box = { floor(x0), floor(y0), floor(x1), floor(y1) }, ents = ents, quais = {}, outs = {}, masks = masks }
end

--- Les lignes de bande de l'équipe, triées par clé : { { key, pid } } (lu par script/ai3/automatisation.lua : leurs poteaux manquants sont des buts du cerveau).
function LB.projects(f)
  local out = {}
  local lignes = f.build and f.build.lignes
  if not lignes then return out end
  local keys = {}
  for k in pairs(lignes) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local rec = lignes[k]
    local lp = f.build.projects[rec.pid]
    if lp and lp.state ~= "fini" and lp.state ~= "refuse" and not lp.abandoned then out[#out + 1] = { key = k, pid = rec.pid } end
  end
  return out
end

--- Branche le site au plan directeur (appelé une fois par script/team/champ.lua).
function LB.install(Build)
  LB.Build = Build
  Build.SITES = Build.SITES or {}
  Build.SITES.ligne_bande = plan_site
end

return LB
