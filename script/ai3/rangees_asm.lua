--- Lot RANGEES-ASM : exécutant d'un ordre « chaine » de la capitalisation (règle pure : shared/ai3/rangees_asm.lua).
--- Une hausse de la demande d'un objet AGRANDIT la rangée en attente de la même recette au lieu d'ouvrir un îlot ; une
--- rangée neuve est dimensionnée sur la demande (5 machines au moins quand elle le justifie) et posée près des autres.
local Ra = require("shared.ai3.rangees_asm")
local Build = require("script.team.build")

local RaRt = {}

--- Modules de l'automatisation (f.team.ia3e.mods) de cet objet et de ce générateur : { { id, n, state } }.
function RaRt.existing(f, item, gen, arg)
  local st = f and f.team and f.team.ia3e
  local out = {}
  for _, m in ipairs(st and st.mods or {}) do
    if m.product == item and m.gen == gen then
      local b = Build.brief(f, m.id)
      out[#out + 1] = { id = m.id, n = tonumber(m.args and m.args[arg]) or 0, state = b and b.state or "refuse", m = m }
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

--- fit(rate) -> gabarit, args (ou nil, objets manquants) ; submit(g, args, near) -> ids ou nil, raison ; factor : repli (1, 1/2…).
--- Rend false (règle non applicable : gabarit sans extension, ancien chemin), ou la liste des ids de modules, ou nil, raison.
function RaRt.execute(f, o, meth, fit, submit, factor)
  local g1, a1 = fit(1e-6)
  if not (g1 and g1.ext and g1.ext.arg and g1.ext.max) then return false end
  local arg = g1.ext.arg
  local nom1 = (g1.nominal[o.item] or 0) * 60 / math.max(1, tonumber(a1[arg]) or 1)
  local ex = RaRt.existing(f, o.item, meth.gen, arg)
  local d = Ra.decide({ rate = o.rate or 0, nom1 = nom1, n_max = g1.ext.max, existing = ex })
  log(Ra.line(f.key or "player", o.item, o.rate, d))
  if d.action == "refus" then return nil, "rangees : " .. tostring(d.why) end
  if d.action == "agrandir" then
    local g, args = fit(d.n * nom1 - 1e-6)
    if g and (tonumber(args[arg]) or 0) > d.from and Build.resize_waiting(f, d.target, args) then
      for _, e in ipairs(ex) do
        if e.id == d.target then
          e.m.args = args
          e.m.rate = (e.m.rate or 0) + (o.rate or 0)
          e.m.rate_nom = (g.nominal[o.item] or 0) * 60
        end
      end
      log(string.format("[FO-RANGEES-ASM] %s : %s module %d agrandi de %d a %d machine(s) (memes tapis, un seul quai)",
        f.key or "player", tostring(o.item), d.target, d.from, args[arg]))
      return { d.target }
    end
    log(string.format("[FO-RANGEES-ASM] %s : %s refus d'agrandir le module %d (%s) : nouvelle rangee", f.key or "player",
      tostring(o.item), d.target, g and "plus en attente" or "objets impossibles"))
    d.near = d.target
  end
  local n = math.max(1, math.floor(d.n * (factor or 1) + 1e-9))
  local g, args = fit(n * nom1 - 1e-6)
  if not g then return nil, "objets impossibles : " .. table.concat(args or {}, ",") end
  return submit(g, args, center_of(f, d.near))
end

return RaRt
