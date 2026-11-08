--- Lot RANGEES-ASM : exécutant d'un ordre « chaine » de la capitalisation (règle pure : shared/ai3/rangees_asm.lua).
--- Une hausse de la demande d'un objet AGRANDIT une rangée de la même recette (en attente : gabarit refait plus long ; dynamique et
--- finie : machines en attente rendues au chantier, script/team/rangee_dyn.lua) au lieu d'ouvrir un îlot ; une rangée neuve est
--- dimensionnée sur la demande (5 machines au moins quand elle le justifie), posée près des autres, dynamique (spec.rangee) et, pour
--- une recette qu'une voie bornerait sous 5 machines, à sortie sur deux voies (G.simple, voies = 2). Réglage fo-war-rangee-dyn
--- (Build.Rangee.on) : éteint, ni rangée dynamique ni deux voies (comportement de la première version du lot).
local Ra = require("shared.ai3.rangees_asm")
local Build = require("script.team.build")
local Conv = require("script.team.convoyeurs") -- tapis des données (vitesse, recette débloquée)
local Mod = require("shared.team.modules") -- voie du tapis du modèle (Mod.LANE_RATE)

-- objets/s par voie pour une vitesse de prototype (belt_speed, tuiles/tick) : 60 ticks/s × 4 objets par tuile et par voie = 240
-- (0,03125 × 240 = 7,5/s, la voie du tapis du modèle)
local Rg_LANE_PER_SPEED = 240

local RaRt = {}

local CHANTIER = { plan = true, reserve = true, defrichage = true, fantomes = true, chantier = true, bloque = true }

--- Modules de l'automatisation (f.team.ia3e.mods) de cet objet et de ce générateur : { { id, n, n_max, state, grow, m } }.
function RaRt.existing(f, item, gen, arg, dyn)
  local st = f and f.team and f.team.ia3e
  local out = {}
  for _, m in ipairs(st and st.mods or {}) do
    if m.product == item and m.gen == gen then
      local b = Build.brief(f, m.id)
      local state = b and b.state or "refuse"
      local e = { id = m.id, n = tonumber(m.args and m.args[arg]) or 0, state = state, m = m }
      local r = b and b.rangee
      if r and dyn then
        e.n, e.n_max = r.n, r.n_max
        if state == "fini" and r.held > 0 then e.grow = "dyn"
        elseif CHANTIER[state] then e.grow = "chantier" end
      end
      out[#out + 1] = e
    end
  end
  return out
end

local function center_of(f, id)
  local b = id and Build.brief(f, id)
  local pt = b and b.parts and b.parts[1]
  if not pt then return nil end
  return { x = pt.x + pt.w / 2, y = pt.y + pt.h / 2 }
end

--- Méthode de gabarit « simple » avec `voies` (1 ou 2) et, facultatif, un tapis des données { name, lane } (arguments 4 et 5 de G.simple).
local function variant(meth, voies, belt)
  local m2 = {}
  for k, v in pairs(meth) do m2[k] = v end
  local a = {}
  for i = 1, 3 do a[i] = (meth.args or {})[i] end
  a[4] = voies
  a[5] = belt
  m2.args = a
  return m2
end

--- Variantes du moins cher au plus cher : la méthode telle quelle, deux voies, puis chaque tapis plus rapide DÉBLOQUÉ (lu aux données :
--- vitesse du prototype, recette débloquée, script/team/convoyeurs.lua ; aucun nom écrit ici), une puis deux voies.
local function variants(f, meth)
  local out = { meth }
  if meth.gen ~= "simple" then return out end
  out[#out + 1] = variant(meth, 2, nil)
  local ok, belts = pcall(Conv.belts)
  local ok2, usable = pcall(Conv.usable, f)
  if not (ok and ok2 and belts and usable) then return out end
  for _, bt in ipairs(belts) do
    local lane = (bt.speed or 0) * Rg_LANE_PER_SPEED
    if lane > Mod.LANE_RATE + 1e-9 and usable(bt.name) then
      local belt = { name = bt.name, lane = lane }
      out[#out + 1] = variant(meth, 1, belt)
      out[#out + 1] = variant(meth, 2, belt)
    end
  end
  return out
end

local function grow_waiting(f, o, d, ex, g, args, arg)
  if not (g and (tonumber(args[arg]) or 0) > d.from and Build.resize_waiting(f, d.target, args)) then return false end
  for _, e in ipairs(ex) do
    if e.id == d.target then e.m.args, e.m.rate, e.m.rate_nom = args, (e.m.rate or 0) + (o.rate or 0), (g.nominal[o.item] or 0) * 60 end
  end
  log(string.format("[FO-RANGEES-ASM] %s : %s module %d agrandi de %d a %d machine(s) (memes tapis, un seul quai)",
    f.key or "player", tostring(o.item), d.target, d.from, args[arg]))
  return true
end

local function grow_built(f, o, d, ex, nom1, tick)
  local moved, why = Build.Rangee.grow(f, d.target, d.n, tick)
  if moved <= 0 then return false, why end
  for _, e in ipairs(ex) do
    if e.id == d.target then
      local m = e.m
      local a = {}
      for i, v in ipairs(m.args or {}) do a[i] = v end
      m.args = a
      m.rate, m.rate_nom = (m.rate or 0) + (o.rate or 0), d.n * nom1
      -- le module redevient OUVERT (suivi ordinaire : manques, chantier) ; rouvert, il n'est jamais annulé (Build.cancel le refuse)
      m.state, m.reason, m.missing, m.reopened_at = "reserve", "rangee : agrandissement", {}, tick
    end
  end
  return true
end

--- fit(meth, rate) -> gabarit, args (ou nil, objets manquants) ; submit(meth, g, args, near) -> ids ou nil, raison ;
--- factor : repli (1, 1/2…). Rend false (règle non applicable : gabarit sans extension, ancien chemin), la liste des ids, ou nil, raison.
function RaRt.execute(f, o, meth, fit, submit, factor, tick)
  local g1, a1 = fit(meth, 1e-6)
  if not (g1 and g1.ext and g1.ext.arg and g1.ext.max) then return false end
  local dyn = Build.Rangee.on()
  if dyn and g1.ext.max < Ra.MIN_ROW then
    local vs = variants(f, meth)
    local fits, maxes = {}, {}
    for i, mv in ipairs(vs) do
      if i == 1 then fits[i] = { g1, a1 } else fits[i] = { fit(mv, 1e-6) } end
      local gv = fits[i][1]
      maxes[i] = (gv and gv.ext and gv.ext.arg == g1.ext.arg) and gv.ext.max or nil
    end
    local i = Ra.pick(maxes)
    if i and i > 1 then
      meth, g1, a1 = vs[i], fits[i][1], fits[i][2]
      log(string.format("[FO-RANGEES-ASM] %s : %s gabarit %s voie(s)%s : borne %d (une voie du tapis du modele : %d)", f.key or "player",
        tostring(o.item), tostring(meth.args[4]), meth.args[5] and (", tapis " .. tostring(meth.args[5].name)) or "", maxes[i], maxes[1] or 0))
    end
  end
  local arg = g1.ext.arg
  local nom1 = (g1.nominal[o.item] or 0) * 60 / math.max(1, tonumber(a1[arg]) or 1)
  local ex = RaRt.existing(f, o.item, meth.gen, arg, dyn)
  local d = Ra.decide({ rate = o.rate or 0, nom1 = nom1, n_max = g1.ext.max, existing = ex })
  log(Ra.line(f.key or "player", o.item, o.rate, d))
  if d.action == "refus" then return nil, "rangees : " .. tostring(d.why) end
  if d.action == "agrandir" then
    local ok, why
    if d.mode == "dyn" then ok, why = grow_built(f, o, d, ex, nom1, tick)
    else
      local g, args = fit(meth, d.n * nom1 - 1e-6)
      ok = grow_waiting(f, o, d, ex, g, args, arg)
      why = g and "plus en attente" or "objets impossibles"
    end
    if ok then return { d.target } end
    log(string.format("[FO-RANGEES-ASM] %s : %s refus d'agrandir le module %d (%s) : nouvelle rangee", f.key or "player",
      tostring(o.item), d.target, tostring(why)))
    d.near = d.target
    d.n = math.min(g1.ext.max, d.k >= Ra.JUSTIFY and math.max(d.k, Ra.MIN_ROW) or d.k)
  end
  local n = math.max(1, math.floor(d.n * (factor or 1) + 1e-9))
  local g, args = fit(meth, n * nom1 - 1e-6)
  if not g then return nil, "objets impossibles : " .. table.concat(args or {}, ",") end
  return submit(meth, g, args, center_of(f, d.near), dyn)
end

return RaRt
