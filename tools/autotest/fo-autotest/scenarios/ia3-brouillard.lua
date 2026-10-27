--[[
  Lot IA3-f : EXPLORATION SOUS BROUILLARD (factions), 60 min, Normal, 4 factions. Lancement :
  « fo-autotest.bat nopause 216000 ia3-brouillard <source> », sur 5 graines (FO_MAP_SEED : 20261020 par défaut,
  271828182, 1618033988, 314159265, 577215664). Témoin « avant le lot » : ia3-brouillard-avant (même partie, brouillard
  coupé). Outils et mesures : scenarios/ia3f_common.lua. Journal du mod : « [FO-IA3F] ».
  Critères (docs/IA3_CERVEAU.md §6.2) : 0 site pris dans un secteur jamais vu ; pétrole trouvé moins de 30 min après
  l'étape explore (chaque faction vivante) ; morts d'éclaireurs au plus 1 par heure et par faction ; 2e gisement de fer
  au plus 5 min plus tard qu'avant le lot (comparaison des lignes « MESURE » des deux scénarios, hors bilan).
]]
local C = require("scenarios/ia3f_common")

local CHECK = 214000

return {
  description = "IA3-f : exploration sous brouillard des factions (petrole demande a 5 min), Normal, 60 min",
  base = nil,
  check_tick = CHECK,

  init = function(ctx) C.start(ctx, true) end,

  tick = function(ctx, e) C.poll(ctx, e, true) end,

  finish = function(ctx)
    local st = ctx.state()
    local keys = C.finish(ctx, true)
    local late, deaths, unseen, bad, tours, missing = {}, {}, {}, {}, {}, {}
    for _, k in ipairs(keys) do
      local r = st.fac[k]
      local alive_min = (r.alive_tick or 0) / 3600
      if r.req_tick then
        local alive_window = (r.alive_tick or 0) >= r.req_tick + C.WINDOW
        if r.oil then
          local d = math.max(0, r.oil - r.req_tick)
          if d > C.WINDOW then late[#late + 1] = string.format("%s %.1f min", k, d / 3600) end
        elseif alive_window then
          missing[#missing + 1] = k
        end
      end
      -- Au plus 1 par heure de partie (arrondi à l'heure supérieure : 1 sur la partie de 60 min).
      if (r.deaths or 0) > math.max(1, math.ceil(alive_min / 60)) then deaths[#deaths + 1] = k .. "=" .. tostring(r.deaths) end
      if (r.unseen_max or 0) > 0 then unseen[#unseen + 1] = k .. "=" .. r.unseen_max end
      if (r.audit_bad or 0) > 0 then bad[#bad + 1] = k .. "=" .. r.audit_bad end
      if r.tour ~= "done" then tours[#tours + 1] = k .. "=" .. tostring(r.tour) end
    end
    ctx.check(st.requested ~= nil, "etape explore jouee pour chaque faction a 5 min", st.requested)
    ctx.check(#missing == 0 and #late == 0, "petrole trouve moins de 30 min apres l'etape explore (chaque faction vivante)",
      (#missing + #late == 0) and "toutes" or ("absent : " .. table.concat(missing, ", ") .. " ; tard : " .. table.concat(late, ", ")))
    ctx.check(#bad == 0, "aucun avant-poste dans un secteur jamais vu", #bad == 0 and "0" or table.concat(bad, ", "))
    ctx.check(#unseen == 0, "aucun site en reserve dans un secteur jamais vu", #unseen == 0 and "0" or table.concat(unseen, ", "))
    ctx.check(#deaths == 0, "morts d'eclaireurs : au plus 1 par heure et par faction", #deaths == 0 and "ok" or table.concat(deaths, ", "))
    ctx.check(#tours == 0, "tour du proprietaire fait par chaque faction", #tours == 0 and "ok" or table.concat(tours, ", "))
  end,
}
