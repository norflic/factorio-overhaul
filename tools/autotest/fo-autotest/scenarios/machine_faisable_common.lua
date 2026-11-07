--[[
  Point (a) du lead, SON banc (décision du lead, 7/11) : il mesure la fonction de (a) dans le cas de la partie du DC, de 85 à
  177 min : un module du plan directeur attend des machines qu'on ne sait pas encore fabriquer (l'assembling-machine-2, ouverte et
  faisable à la main, mais pas d'acier), il tient un emplacement et bloque le plan. MESURÉ dans la partie
  (fo-logs/2026-11-05_PARTIE-DC-ESSAI) : modules en attente d'AM2, puis refus « materiaux introuvables (15 min sans progres) ».
  Le MÊME banc, deux sources :
    témoin (scénario machine-faisable-temoin), sur 5511fd6f, SANS (a) : l'ancien choix (main ou coffre, la machine la plus rapide) ;
    lot    (scénario machine-faisable), sur 94146557, AVEC (a) et son cas limite.
  Mise en place (même départ que champ-manque : 2 factions, Paisible, la première par ordre de clé) :
    1. tick 300 : recette assembling-machine-2 OUVERTE pour la force de la faction ; coffre : acier et AM2 RETIRÉS ; posés : fer,
       cuivre, engrenages, circuits, 10 AM1, bras, tapis, coffres, poteaux et les pièces d'une centrale ; aucun four d'acier ;
    2. dès que la capitalisation existe : DEUX ordres de banc par l'exécutant des ordres (fo-capi bench_order : chaîne d'engrenages
       et packs rouges), comme les modules de la partie ;
    3. la centrale de ces modules, puis les modules eux-mêmes : fantômes ravivés par le banc (fo-ind revive ; BANC SEULEMENT, le
       temps : des PNJ mettent plus de 9 000 ticks à bâtir) ;
    4. relevé toutes les 300 ticks : état de chaque module de banc (fo-ia1d status : état, raison, objets manquants, posées / total)
       et emplacements (fo-capi status : attente de matière).
  Contrôles ÉCRITS AVANT (fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md, « Banc de (a) ») :
    départ (les deux) : faction relevée ; AM2 ouverte, faisable à la main ; acier 0 et AM2 0 au coffre ; deux ordres de banc ouverts ;
    témoin : au moins un module de banc attend « assembling-machine-2 » (objet manquant) ; ce module n'a RIEN posé à la fin ; au
             dernier relevé, au moins un emplacement est en attente de matière ;
    lot    : aucun module de banc n'attend jamais « assembling-machine-2 » ; chaque module de banc a posé au moins une entité à la fin ;
             au dernier relevé, aucun module de banc n'est en attente de matière (« reserve » faute d'objets).
  BILAN attendu : témoin 3 réglages + 1 Paisible + 1 guerre + 4 départ + 3 = 12 OK ; lot 12 OK.
  Lancement (par la file, après le gel) :
    banc.py --out <archive> --qui EFFONDREMENT -- 9600 machine-faisable-temoin <source 5511fd6f + ces scénarios>
    banc.py --out <archive> --qui EFFONDREMENT -- 9600 machine-faisable <source 94146557 + ces scénarios>
  Journal : [FO-MACHINE-FAISABLE] ou [FO-MACHINE-FAISABLE-TEMOIN].
]]

local CHECK = 9500
local EVERY = 300
local REMOVE = { "steel-plate", "assembling-machine-2", "assembling-machine-3", "steel-furnace", "medium-electric-pole" }
local PARTS = { { "iron-plate", 3000 }, { "copper-plate", 1500 }, { "iron-gear-wheel", 200 }, { "electronic-circuit", 200 },
  { "assembling-machine-1", 10 }, { "inserter", 60 }, { "transport-belt", 200 }, { "iron-chest", 30 }, { "small-electric-pole", 150 },
  { "coal", 300 }, { "offshore-pump", 2 }, { "boiler", 2 }, { "steam-engine", 4 }, { "burner-inserter", 4 }, { "pipe", 40 } }
local ORDERS = { { "chaine", "iron-gear-wheel", 60 }, { "packs", "automation-science-pack", 6 } }
local AM2 = "assembling-machine-2"

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

local function lists(missing, name)
  for _, m in ipairs(missing or {}) do if m[1] == name and (m[2] or 0) > 0 then return true end end
  return false
end

local function waits_materials(s)
  return s ~= nil and s.state == "reserve" and #(s.missing or {}) > 0
end

return function(temoin)
  local TAG = temoin and "temoin, SANS (a)" or "lot, AVEC (a)"
  return {
    description = "Point (a) : un module attend une machine qu'on ne sait pas fabriquer (AM2 sans acier) ; bloque-t-il le plan ? (" .. TAG .. ")",
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      st.rel, st.mods = {}, {}
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
      -- 1. la recette AM2 ouverte, le coffre sans acier
      if t == 300 then
        local r = first_team(ctx)
        st.key, st.force = r and r.key, r and r.force
        ctx.check(st.key ~= nil, "faction relevee (" .. tostring(st.key) .. ")")
        if not st.key then return end
        local force = game.forces[st.force]
        local rec = force and force.recipes[AM2]
        if rec then rec.enabled = true end
        ctx.check(rec ~= nil and rec.enabled == true and rec.category == "crafting", "recette " .. AM2 .. " ouverte, faite a la main (categorie crafting)",
          rec and rec.category or "absente")
        local s = ctx.surface()
        local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = st.force, limit = 1 })[1]
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
        ctx.check(inv ~= nil and #short == 0 and inv.get_item_count("steel-plate") == 0 and inv.get_item_count(AM2) == 0,
          "coffre : acier et AM2 retires (0 et 0), fer, cuivre, AM1 et pieces poses",
          "retire {" .. table.concat(removed, ", ") .. "}" .. (#short > 0 and (" ; insere en partie : " .. table.concat(short, " ")) or ""))
        local fur = s.count_entities_filtered({ force = st.force, type = "furnace" })
        ctx.log(string.format("fours de la force au depart : %d (aucun ne fond l'acier : recette steel-plate %s)", fur,
          tostring(force and force.recipes["steel-plate"] and force.recipes["steel-plate"].enabled)))
      end
      -- 2. les deux ordres de banc, dès que la capitalisation existe
      if st.key and not st.orders and t > 300 and t % 60 == 0 then
        if ctx.remote("fo-capi", "status", st.key) ~= nil then
          local ids, got = {}, 0
          for _, o in ipairs(ORDERS) do
            local mids, info = ctx.remote("fo-capi", "bench_order", st.key, o[1], o[2], o[3])
            if mids and #mids > 0 then
              got = got + 1
              for _, id in ipairs(mids) do st.mods[#st.mods + 1] = { id = id, label = o[1] .. " " .. o[2] } end
            end
            ids[#ids + 1] = o[1] .. " " .. o[2] .. " -> " .. (mids and ("modules " .. table.concat(mids, ",")) or ("refus : " .. tostring(info)))
          end
          st.orders = t
          ctx.check(got == #ORDERS, "deux ordres de banc ouverts au plan directeur", table.concat(ids, " ; "))
        end
      end
      -- 3. la centrale, puis les modules de banc : fantômes ravivés par le banc
      if st.orders and t % 120 == 0 then
        local a = ctx.remote("fo-ia3e", "status", st.key)
        if a and a.plant and a.plant_state ~= "fini" then
          st.revived = (st.revived or 0) + (ctx.remote("fo-ind", "revive", st.key, a.plant) or 0)
        elseif a and a.plant_state == "fini" and not st.fini then
          st.fini = t
          ctx.log(string.format("centrale %s FINIE au tick %d", tostring(a.plant), t))
        end
        for _, m in ipairs(st.mods) do
          st.revived = (st.revived or 0) + (ctx.remote("fo-ind", "revive", st.key, m.id) or 0)
        end
      end
      -- 4. relevé
      if st.orders and t % EVERY == 0 then
        local cs = ctx.remote("fo-capi", "status", st.key)
        local sl = (cs and cs.slots) or {}
        local parts = {}
        for _, m in ipairs(st.mods) do
          local s = ctx.remote("fo-ia1d", "status", st.key, m.id)
          if s then
            m.last = s
            if lists(s.missing, AM2) then m.wanted_am2 = m.wanted_am2 or t end
            local miss = {}
            for _, x in ipairs(s.missing or {}) do miss[#miss + 1] = tostring(x[1]) .. " " .. tostring(x[2]) end
            parts[#parts + 1] = string.format("%d %s : %s%s, %d/%d posees, manque {%s}", m.id, m.label, tostring(s.state),
              s.reason and (" (" .. tostring(s.reason) .. ")") or "", s.built or 0, s.total or 0, table.concat(miss, ", "))
          else
            parts[#parts + 1] = string.format("%d %s : projet absent", m.id, m.label)
          end
        end
        st.rel[#st.rel + 1] = { tick = t, materials = sl.materials, counted = sl.counted, cap = sl.cap }
        ctx.log(string.format("tick %d : emplacements %s/%s (attente de matiere %s) ; %s", t, tostring(sl.counted), tostring(sl.cap),
          tostring(sl.materials), table.concat(parts, " | ")))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local endr = st.rel and st.rel[#st.rel]
      local any_am2, blocked, all_built, none_wait = false, false, #st.mods > 0, #st.mods > 0
      for _, m in ipairs(st.mods or {}) do
        local s = m.last
        if m.wanted_am2 then
          any_am2 = true
          if not s or (s.built or 0) == 0 then blocked = true end
        end
        if not s or (s.built or 0) == 0 then all_built = false end
        if waits_materials(s) then none_wait = false end
        ctx.log(string.format("FAIT module %d (%s) : AM2 attendue %s ; dernier etat %s (%s), %s/%s posees", m.id, m.label,
          tostring(m.wanted_am2), tostring(s and s.state), tostring(s and s.reason), tostring(s and s.built), tostring(s and s.total)))
      end
      if temoin then
        ctx.check(any_am2, "temoin : un module de banc attend " .. AM2 .. " (machine qu'on ne sait pas fabriquer)")
        ctx.check(blocked, "temoin : ce module n'a rien pose a la fin (il bloque)")
        ctx.check(endr ~= nil and (endr.materials or 0) >= 1, "temoin : au dernier releve, au moins un emplacement attend sa matiere",
          endr and tostring(endr.materials) or "aucun releve")
      else
        ctx.check(not any_am2, "lot : aucun module de banc n'attend jamais " .. AM2)
        ctx.check(all_built, "lot : chaque module de banc a pose au moins une entite (il ne bloque plus le plan)")
        ctx.check(none_wait, "lot : au dernier releve, aucun module de banc n'attend sa matiere",
          endr and tostring(endr.materials) or "aucun releve")
      end
    end,
  }
end
