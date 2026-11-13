--[[
  Lot DEBUG-CERVEAU : écart entre ce que le CERVEAU SAIT d'une zone et son état RÉEL mesuré. Règle PURE (tests/debug_cerveau_test.lua).
  C'est le cœur de la demande du DC (8/11) : « si elle sait régulièrement si cette zone fonctionne ».
  Entrées :
    reads  liste de lectures du cerveau sur cette zone : { src = clé de source, verdict = "marche" | "arret", why = cause ou nil, tick = tick de la
           lecture (nil : date inconnue) }. Une source qui ne lit pas la zone n'y figure pas (liste vide : le cerveau ne la lit jamais).
    real   sortie de Zn.classify (color, cause).
    now    tick courant.
  Sortie : { kind, sev, age, verdict, why, src, stale, text = { clé, ... } } avec :
    kind  accord | croit_marche (le cerveau croit que ça marche, ce n'est pas le cas) | croit_arret (il croit que ça ne marche pas, ça marche) |
          perime (dernière lecture trop vieille pour trancher) | jamais_lu (aucune lecture) | lu_sans_verdict (le cerveau relit la zone mais ne
          garde pas son verdict : avant-postes) | non_applicable (zone en construction : le cerveau la suit par l'état du projet, pas par ses
          machines)
    sev   ok | info | attention | alerte
  Le verdict de la zone, pour le cerveau, est celui de ses lectures non périmées : « arret » si l'une dit arrêt, « marche » si toutes disent marche.
  Une lecture sans date est comptée périmée (fermé par défaut). Aucun nom du jeu, aucun hasard, aucun temps mesuré.
]]

local Ec = {}

Ec.STALE = 2 * 3600 -- ticks : au-delà, une lecture ne compte plus (même seuil que Mq.MAX_AGE, shared/ai3/manque_local.lua)
Ec.KINDS = { "accord", "croit_marche", "croit_arret", "perime", "jamais_lu", "lu_sans_verdict", "non_applicable" }

local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

--- Âge en ticks d'une lecture (nil si la date est inconnue ou postérieure à now).
function Ec.age(read, now)
  if not (type(read) == "table" and finite(read.tick) and finite(now)) then return nil end
  if read.tick > now then return nil end
  return now - read.tick
end

local function newest(reads, now)
  local best, best_age
  for _, r in ipairs(reads) do
    local a = Ec.age(r, now)
    if a ~= nil and (best_age == nil or a < best_age) then best, best_age = r, a end
  end
  return best, best_age
end

function Ec.compare(reads, real, now, stale)
  stale = finite(stale) and stale or Ec.STALE
  reads = type(reads) == "table" and reads or {}
  local color = type(real) == "table" and real.color or "gris"
  if color == "gris" then return { kind = "non_applicable", sev = "ok", text = { "fo-dbg-cerveau.ecart-non_applicable" } } end
  if #reads == 0 then
    local sev = color == "vert" and "info" or "alerte"
    return { kind = "jamais_lu", sev = sev, text = { "fo-dbg-cerveau.ecart-jamais_lu" } }
  end
  -- lectures encore valables
  local fresh, any_stop, stop_read = {}, false, nil
  for _, r in ipairs(reads) do
    local a = Ec.age(r, now)
    if a ~= nil and a <= (finite(r.stale) and r.stale or stale) then -- (s41 zone-aveugle : une lecture périodique porte sa propre péremption)
      fresh[#fresh + 1] = r
      if r.verdict == "arret" and not any_stop then any_stop, stop_read = true, r end
    end
  end
  local last, last_age = newest(reads, now)
  if #fresh == 0 then
    local sev = color == "vert" and "info" or "alerte"
    return { kind = "perime", sev = sev, age = last_age, src = last and last.src, verdict = last and last.verdict, why = last and last.why,
      stale = true, text = { "fo-dbg-cerveau.ecart-perime" } }
  end
  local pick = stop_read or newest(fresh, now)
  local age = Ec.age(pick, now)
  local known = false
  for _, r in ipairs(fresh) do if r.verdict == "marche" or r.verdict == "arret" then known = true break end end
  if not known then
    local sev = color == "vert" and "info" or "attention"
    return { kind = "lu_sans_verdict", sev = sev, age = age, src = pick.src, stale = false, text = { "fo-dbg-cerveau.ecart-lu_sans_verdict" } }
  end
  local verdict = any_stop and "arret" or "marche"
  local out = { age = age, verdict = verdict, why = pick.why, src = pick.src, stale = false }
  if verdict == "marche" and color ~= "vert" then
    out.kind = "croit_marche"
    out.sev = color == "rouge" and "alerte" or "attention"
    out.text = { "fo-dbg-cerveau.ecart-croit_marche" }
  elseif verdict == "arret" and color == "vert" then
    out.kind, out.sev, out.text = "croit_arret", "alerte", { "fo-dbg-cerveau.ecart-croit_arret" }
  else
    out.kind, out.sev, out.text = "accord", "ok", { "fo-dbg-cerveau.ecart-accord" }
  end
  return out
end

--- Les alertes passent devant les attentions, les infos, puis les accords ; à égalité, la clé de la zone (déterminisme).
Ec.SEV_ORDER = { alerte = 1, attention = 2, info = 3, ok = 4 }

function Ec.sort(rows)
  table.sort(rows, function(a, b)
    local sa, sb = Ec.SEV_ORDER[a.sev] or 9, Ec.SEV_ORDER[b.sev] or 9
    if sa ~= sb then return sa < sb end
    return tostring(a.key) < tostring(b.key)
  end)
  return rows
end

return Ec
