--[[
  Lot CORR-CHAMP-MANQUE (EFFONDREMENT, 5/11) : micro-banc de la règle 8 des emplacements (shared/ai3/emplacements.lua) en moteur
  réel. Cas B de la partie du DC rejouée (0.6.51, minutes 11 à 31) : deux modules du plan directeur attendent du fer et tiennent les
  2 emplacements ; tant qu'ils les tiennent, la capitalisation refuse la foreuse électrique de TOUS les minerais (« plan directeur
  occupe »), donc le fer manque toujours.
  Mise en place (même départ que ind-mall : 2 factions, la première par ordre de clé, géographie connue de la graine du banc) :
    1. coffre de la faction : fer et objets de fer RETIRÉS (plaques, minerai, engrenages, circuits, machines, bras, coffres, foreuses,
       laboratoires) ; posés : 900 cuivre (sous Em.PER_SLOT : aucun emplacement de plus par le stock), du charbon et les pièces d'une
       centrale (pompe, chaudières, machines à vapeur, bras à combustion, tapis, poteaux, tuyaux) ;
    2. dès que la capitalisation existe : interrupteur de la règle 8 (fo-capi, manque : allumé au lot, éteint au témoin), puis DEUX
       ordres de banc (fo-capi, bench_order : packs automation-science-pack et chaîne burner-mining-drill, les deux ordres de B) par
       l'exécutant des ordres de la décision : leurs modules attendent leur matière (machines, bras, coffres : pas de fer pour les faire) ;
    3. la centrale demandée par ces modules : le banc ravive ses fantômes (fo-ind, revive ; BANC SEULEMENT, le temps) jusqu'à
       « fini » (sinon toute foreuse est refusée « centrale demandee, pas finie », lot et témoin) ; puis la décision est hâtée ;
    4. relevé toutes les 300 ticks (fo-capi, status) : emplacements, raison du refus de la foreuse de fer, ordres ouverts.
  Contrôles ÉCRITS AVANT (fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md, E3) :
    témoin : après la centrale finie et au moins une décision, la foreuse de fer est refusée « plan directeur occupe », aucun ordre
             sur le minerai de fer, jamais de siège pour le fer ;
    lot    : un relevé montre le siège du fer (iron-plate) ; après la centrale finie et au moins une décision, la foreuse de fer n'est
             plus refusée « plan directeur occupe » ; un ordre sur le minerai de fer est ouvert, jamais plus d'un à la fois (un ordre
             CHAMP tient le siège : relecture du lead, 18 h 10, point 1) ; le plafond des emplacements est inchangé et au plus UN
             module compte au-delà (le siège du complément).
  Lancement (par la file, APRÈS la reprise seulement) :
    banc.py --out <archive> --qui EFFONDREMENT -- 9600 champ-manque-temoin <source>
    banc.py --out <archive> --qui EFFONDREMENT -- 9600 champ-manque <source>
  Journal : [FO-CHAMP-MANQUE] ou [FO-CHAMP-MANQUE-TEMOIN] ; le mod écrit [FO-CAPI-EMPLACEMENTS], [FO-CAPI-COUV], [FO-CAPI].
]]

local CHECK = 9500
local EVERY = 300
local REMOVE = { "iron-plate", "iron-ore", "iron-gear-wheel", "iron-stick", "electronic-circuit", "assembling-machine-1",
  "assembling-machine-2", "inserter", "long-handed-inserter", "fast-inserter", "iron-chest", "steel-chest", "electric-mining-drill",
  "burner-mining-drill", "steel-plate", "lab", "automation-science-pack", "gun-turret", "copper-plate", "burner-inserter",
  "transport-belt" }
local PARTS = { { "copper-plate", 900 }, { "coal", 300 }, { "offshore-pump", 2 }, { "boiler", 2 }, { "steam-engine", 4 },
  { "burner-inserter", 4 }, { "transport-belt", 40 }, { "small-electric-pole", 150 }, { "pipe", 40 } }
local ORDERS = { { "packs", "automation-science-pack", 6 }, { "chaine", "burner-mining-drill", 2 } }

local function set_setting(ctx, name, value)
  local v = ctx.call("war_setting", name, value)
  ctx.check(v == value, "reglage " .. name .. " = " .. tostring(value), tostring(v))
end

local function first_team(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out[1]
end

local function busy_iron(why)
  return type(why) == "string" and why:find("plan directeur occupe", 1, true) == 1
end

local function has(list, x)
  for _, v in ipairs(list or {}) do if v == x then return true end end
  return false
end

return function(temoin)
  return {
    description = "CORR-CHAMP-MANQUE : deux modules attendent du fer, le champ du fer a-t-il son siege ? (" ..
      (temoin and "temoin, regle 8 eteinte" or "lot") .. ")",
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      st.rel = {}
      set_setting(ctx, "fo-war-ia3e", true)
      set_setting(ctx, "fo-war-capi", true)
      set_setting(ctx, "fo-war-workers", 30)
      local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
      ctx.check(ok == true, "difficulte Paisible imposee avant la guerre", tostring(ok))
      ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
      ctx.call("profiler", true)
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      local t = e.tick
      -- 1. le coffre de la faction : plus de fer, du cuivre, les pièces de la centrale
      if t == 300 then
        local r = first_team(ctx)
        st.key = r and r.key
        ctx.check(st.key ~= nil, "faction relevee (" .. tostring(st.key) .. ")")
        if not st.key then return end
        local s = ctx.surface()
        local hq = s.find_entities_filtered({ name = "fo-faction-hq", position = { r.x, r.y }, radius = 12 })[1]
        local inv = hq and hq.valid and hq.get_inventory(defines.inventory.chest)
        local removed = {}
        if inv then
          for _, n in ipairs(REMOVE) do
            local c = inv.get_item_count(n)
            if c > 0 then removed[#removed + 1] = n .. " " .. inv.remove({ name = n, count = c }) end
          end
        end
        local put = ctx.remote("fo-ind", "stock", st.key, PARTS)
        local short = {}
        for _, p in ipairs(PARTS) do if not put or (put[p[1]] or 0) < p[2] then short[#short + 1] = p[1] end end
        ctx.check(inv ~= nil and put ~= nil and #short == 0 and inv.get_item_count("iron-plate") == 0,
          "coffre : fer retire, cuivre et pieces de centrale poses", "retire {" .. table.concat(removed, ", ") .. "}" ..
          (#short > 0 and (" ; insere en partie : " .. table.concat(short, " ")) or ""))
        local left = {}
        local cont = inv and inv.get_contents() or {}
        local names = {}
        for n in pairs(cont) do names[#names + 1] = n end
        table.sort(names)
        for _, n in ipairs(names) do left[#left + 1] = n .. "=" .. cont[n] end
        ctx.log("coffre apres la mise en place : " .. table.concat(left, " "))
      end
      -- 2. interrupteur, puis les deux ordres de banc, dès que la capitalisation existe
      if st.key and not st.orders and t > 300 and t % 60 == 0 then
        if ctx.remote("fo-capi", "status", st.key) ~= nil then
          ctx.check(ctx.remote("fo-capi", "manque", st.key, not temoin) == true,
            "regle 8 " .. (temoin and "eteinte (temoin)" or "allumee (lot)"))
          local ids, got = {}, 0
          for _, o in ipairs(ORDERS) do
            local mids, info = ctx.remote("fo-capi", "bench_order", st.key, o[1], o[2], o[3])
            if mids and #mids > 0 then got = got + 1 end
            ids[#ids + 1] = o[1] .. " " .. o[2] .. " -> " .. (mids and ("modules " .. table.concat(mids, ",")) or ("refus : " .. tostring(info)))
          end
          st.orders = t
          ctx.check(got == #ORDERS, "deux ordres de banc ouverts au plan directeur", table.concat(ids, " ; "))
        end
      end
      -- 3. la centrale : fantômes ravivés par le banc jusqu'à « fini », puis décision hâtée
      if st.orders and not st.fini and t % 120 == 0 then
        local a = ctx.remote("fo-ia3e", "status", st.key)
        if a and a.plant then
          if a.plant_state == "fini" then
            st.fini = t
            local cs = ctx.remote("fo-capi", "status", st.key)
            st.dec_fini = cs and cs.decisions or 0
            st.hastened = ctx.remote("fo-ind", "hasten", st.key) == true
            ctx.log(string.format("centrale %d FINIE au tick %d (%d fantome(s) ravives par le banc) ; decision hatee : %s", a.plant, t,
              st.revived or 0, tostring(st.hastened)))
          else
            st.revived = (st.revived or 0) + (ctx.remote("fo-ind", "revive", st.key, a.plant) or 0)
          end
        end
      end
      -- 4. relevé
      if st.orders and t % EVERY == 0 then
        local cs = ctx.remote("fo-capi", "status", st.key)
        if cs then
          local sl = cs.slots or {}
          local iron_orders = {}
          for _, o in ipairs(cs.open or {}) do
            if o.resource == "iron-ore" then iron_orders[#iron_orders + 1] = tostring(o.key) .. ":" .. tostring(o.kind) end
          end
          local why = cs.drill_why and cs.drill_why["iron-ore"] or nil
          local rec = { tick = t, cap = sl.cap, counted = sl.counted, materials = sl.materials, comp = sl.comp or {}, why_iron = why,
            iron_orders = iron_orders, decisions = cs.decisions or 0, after = st.fini ~= nil }
          st.rel[#st.rel + 1] = rec
          ctx.log(string.format("tick %d : emplacements %s/%s (attente de matiere %s), siege {%s} ; foreuse de fer : %s ; ordres fer [%s] ; decisions %d%s",
            t, tostring(sl.counted), tostring(sl.cap), tostring(sl.materials), table.concat(rec.comp, " "), why and ('"' .. why .. '"') or "accordee",
            table.concat(iron_orders, ", "), rec.decisions, st.fini and " (centrale finie)" or ""))
          if not st.cap0 and sl.cap then st.cap0 = sl.cap end
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      ctx.check(st.fini ~= nil, "centrale finie (ravivee par le banc) avant la fin", tostring(st.fini))
      local last, seat, iron_order, after_dec = nil, false, false, false
      local max_over, max_iron = 0, 0
      for _, r in ipairs(st.rel or {}) do
        if has(r.comp, "iron-plate") then seat = true end
        if #r.iron_orders > 0 then iron_order = true end
        if #r.iron_orders > max_iron then max_iron = #r.iron_orders end
        if r.after and r.decisions > (st.dec_fini or 0) then after_dec = true last = r end
        if r.cap and r.counted then max_over = math.max(max_over, r.counted - r.cap) end
      end
      local endr = st.rel and st.rel[#st.rel]
      ctx.check(endr ~= nil and (endr.materials or 0) >= 2, "les deux modules de banc attendent toujours leur matiere a la fin",
        endr and tostring(endr.materials) or "aucun releve")
      ctx.check(after_dec, "au moins une decision apres la centrale finie", string.format("decisions %s -> %s", tostring(st.dec_fini),
        tostring(endr and endr.decisions)))
      if temoin then
        ctx.check(last ~= nil and busy_iron(last.why_iron), "temoin : foreuse de fer refusee « plan directeur occupe »",
          last and tostring(last.why_iron) or "aucun releve apres decision")
        ctx.check(not iron_order, "temoin : aucun ordre sur le minerai de fer")
        ctx.check(not seat, "temoin : jamais de siege pour le fer")
      else
        ctx.check(seat, "lot : siege du fer (iron-plate) au releve des emplacements")
        ctx.check(last ~= nil and not busy_iron(last.why_iron), "lot : foreuse de fer plus refusee « plan directeur occupe »",
          last and tostring(last.why_iron or "accordee") or "aucun releve apres decision")
        ctx.check(iron_order, "lot : un ordre sur le minerai de fer est ouvert")
        -- relecture du lead (18 h 10, point 1) : un ordre CHAMP tient le siège ; jamais deux ordres du fer ouverts à la fois sur un siège
        ctx.check(max_iron <= 1, "lot : jamais plus d'un ordre sur le minerai de fer ouvert a la fois (siege unique)", "au plus " .. max_iron)
        ctx.check(endr ~= nil and endr.cap == st.cap0 and max_over <= 1,
          "lot : plafond inchange et au plus un module au-dela (siege du complement)",
          string.format("plafond %s -> %s, au-dela %d", tostring(st.cap0), tostring(endr and endr.cap), max_over))
      end
    end,
  }
end
