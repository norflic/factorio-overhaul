--[[
  Sprint s43 (sonde-charbon) : SONDE du combustible du QG, par minute et par équipe, SANS plafond (le compteur « coffre du QG SANS charbon
  libre » du mod est plafonné à Cc.LOGS lignes par équipe et double avec les centrales à deux coffres : il ne mesure pas une pénurie).
  Enveloppe un scénario de banc (table { tick, finish, ... }) sans rien changer à son déroulé : chaque minute (1 à `minutes`), une ligne
    [FO-SONDE-CHARBON] minute=M equipe=K source=S combustible_qg=N charbon_qg=N
  - source « stock » : champ `fuel` du remote fo-ia1 « teams » (Stock.count du mod : coffre du QG + annexes, combustible T.fuel) ;
    source « qg » (version du mod sans ce champ, ex. v0.7.96) : objets du seul coffre du QG (entité fo-faction-hq ou fo-team-chest) dont le
    prototype a une valeur de combustion ; les deux sources ne se comparent pas entre elles (annexes) ;
  - charbon_qg : objets nommés CHARBON (le banc nomme ; hors cerveau) au coffre du QG seul.
  Usage : return require("scenarios/sonde_charbon")(require("scenarios/pavage_common")(60, "partie"), 60)
  Lecture : tools/autotest/sonde_charbon.py <archive> [...] (minutes à 0, moyenne, minimum par équipe).
]]

local TAG = "[FO-SONDE-CHARBON] "
local MIN = 3600
local CHARBON = "coal"

return function(scen, minutes)
  local tick0, finish0 = scen.tick, scen.finish
  local fuel = nil -- noms des objets combustibles (cache local, prototypes seulement)

  local function fuel_names()
    if fuel then return fuel end
    fuel = {}
    for name, p in pairs(game.item_prototypes) do if (p.fuel_value or 0) > 0 then fuel[#fuel + 1] = name end end
    table.sort(fuel)
    return fuel
  end

  local function hq_of(s, force)
    return s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
      or s.find_entities_filtered({ name = "fo-team-chest", force = force, limit = 1 })[1]
  end

  local function probe(ctx, minute)
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    if not ok then return end
    local s = ctx.surface()
    for _, r in ipairs(rows or {}) do
      local hq = hq_of(s, r.force)
      local coal = hq and hq.valid and hq.get_item_count(CHARBON) or -1
      local src, n = "stock", r.fuel
      if type(n) ~= "number" then
        src, n = "qg", 0
        if hq and hq.valid then for _, name in ipairs(fuel_names()) do n = n + hq.get_item_count(name) end else n = -1 end
      end
      log(TAG .. string.format("minute=%d equipe=%s source=%s combustible_qg=%d charbon_qg=%d", minute, tostring(r.key), src, n, coal))
    end
  end

  scen.tick = function(ctx, e)
    if tick0 then tick0(ctx, e) end
    if e.tick > 0 and e.tick % MIN == 0 and e.tick <= (minutes or 60) * MIN then
      local ok, err = pcall(probe, ctx, e.tick / MIN)
      if not ok then ctx.state().sonde_err = tostring(err); log(TAG .. "ERREUR " .. tostring(err)) end
    end
  end

  scen.finish = function(ctx)
    if finish0 then finish0(ctx) end
    ctx.check(ctx.state().sonde_err == nil, "sonde du charbon sans erreur Lua", ctx.state().sonde_err or "")
  end

  return scen
end
