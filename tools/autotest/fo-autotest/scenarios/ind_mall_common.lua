--[[
  Lot INDUSTRIE I6 « choix » (31/10) : banc du CHOIX DYNAMIQUE DE MALL contre le moteur réel (PLAN INDUSTRIE §1, §2, §7 ligne I6).
  Deux scénarios partagent ce fichier :

    ind-mall    (mod livré)      : une faction financée reçoit des objets à fabriquer en petites quantités (cinq objets de recettes à
                                   1 entrée, sous une demi-machine chacun), des pièces au coffre d'équipe et sa première décision de la
                                   capitalisation est HÂTÉE (fo-ind, hasten). Chaîne attendue : demande (Ml.want) -> Id.decide ->
                                   UN BLOC de mall (une machine par objet, 4 voies communes) -> Auto.submit -> Build.request -> plan
                                   directeur -> PNJ -> machines en marche -> coffres de sortie inscrits à la collecte, BARRE posée.
                                   Témoin : l'autre faction ne reçoit aucune demande, elle ne pose aucun bloc.
    ind-jetable (copie jetable)  : même chose sur une copie du mod qui ajoute (tools/autotest/ind/jetable_mall.py) une machine
                                   inventée « fo-i6-machine » (catégorie neuve, 4 × 4) et trois objets inventés à 2, 3 et 4 entrées
                                   (« fo-i6-vis », « fo-i6-aile », « fo-i6-piece ») : le bloc doit les poser sur la machine inventée, sans
                                   une ligne de code qui connaisse ce mod. Sur le mod livré, il ne fait rien (« prototypes de test absents »).
  Lancement (par la file) : banc.py --out <archive> --qui IND-I6 -- <ticks> ind-mall <source>
                            banc.py --out <archive> --qui IND-I6 -- <ticks> ind-jetable <copie jetable>
  Journal : [FO-IND-MALL] (ce banc) et [FO-MALL] (le mod).
]]

local MIN = 3600

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local function set_setting(ctx, name, value)
  local v = ctx.call("war_setting", name, value)
  ctx.check(v == value, "reglage " .. name .. " = " .. tostring(value), tostring(v))
end

local PARTS = {
  { "assembling-machine-1", 12 }, { "assembling-machine-2", 24 }, { "inserter", 80 }, { "long-handed-inserter", 40 },
  { "fast-inserter", 30 }, { "wood", 200 }, { "transport-belt", 300 }, { "iron-chest", 30 }, { "wooden-chest", 10 }, { "small-electric-pole", 60 },
  { "medium-electric-pole", 40 }, { "copper-plate", 3000 }, { "stone-brick", 600 }, { "coal", 1500 },
}

local MALL = {
  ["ind-mall"] = {
    items = { { "iron-stick", 1.0 }, { "pipe", 1.0 }, { "iron-chest", 1.0 }, { "copper-cable", 1.0 }, { "firearm-magazine", 1.0 } },
    machine_proto = nil,
  },
  ["ind-jetable"] = {
    items = { { "fo-i6-vis", 1.0 }, { "fo-i6-aile", 1.0 }, { "fo-i6-piece", 1.0 } },
    machine_proto = "fo-i6-machine",
    extra = { { "fo-i6-machine", 12 } },
  },
}

local function teams(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

--- Les entités posées par le module `id` de la faction `key`, d'après le plan : liste de { name, x, y, built }.
local function module_ents(ctx, key, id)
  local lay = ctx.remote("fo-ia1d", "layout", key)
  local out = {}
  for _, e in ipairs(lay and lay.ents or {}) do
    if e.pid == id then out[#out + 1] = e end
  end
  return out
end

return function(name)
  local cfg = MALL[name]
  return {
    description = "INDUSTRIE I6 (" .. name .. ") : demande -> bloc de mall -> plan directeur -> machines -> coffres a la barre",
    check_tick = 9500,
    init = function(ctx)
      local st = ctx.state()
      st.t = {}
      st.jetable = cfg.machine_proto and game.entity_prototypes[cfg.machine_proto] ~= nil
      if cfg.machine_proto and not st.jetable then
        ctx.log("prototypes de test absents (" .. cfg.machine_proto .. ") : ce scenario se joue sur la copie jetable")
        return
      end
      set_setting(ctx, "fo-war-industrie", true)
      set_setting(ctx, "fo-war-ia3e", true)
      set_setting(ctx, "fo-war-capi", true)
      set_setting(ctx, "fo-war-workers", 30)
      local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
      ctx.check(ok == true, "difficulte Paisible imposee avant la guerre", tostring(ok))
      ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
      ctx.check(ctx.call("war_fund", 20000) == 2, "2 factions financees (20000 fer)")
      ctx.call("profiler", true)
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if cfg.machine_proto and not st.jetable then return end
      -- 1. pièces et demande (tick 400, la faction a relevé ses machines au premier relevé de la capitalisation)
      if e.tick == 400 then
        local tm = teams(ctx)
        st.key, st.control = tm[1] and tm[1].key, tm[2] and tm[2].key
        ctx.check(st.key ~= nil and st.control ~= nil, "deux factions relevees")
        if not st.key then return end
        local list = {}
        for _, p in ipairs(PARTS) do list[#list + 1] = p end
        for _, p in ipairs(cfg.extra or {}) do list[#list + 1] = p end
        local put = ctx.remote("fo-ind", "stock", st.key, list)
        ctx.check(put ~= nil, st.key .. " : pieces posees au coffre d'equipe")
        for _, p in ipairs(list) do
          if put and (put[p[1]] or 0) < p[2] then ctx.log(string.format("ATTENTION : %s inseree a %d sur %d", p[1], put[p[1]] or 0, p[2])) end
        end
        for _, w in ipairs(cfg.items) do
          ctx.check(ctx.remote("fo-ind", "want", st.key, w[1], w[2]) == true, st.key .. " : demande de " .. w[1] .. " (" .. w[2] .. "/min)")
        end
        ctx.check(ctx.remote("fo-ind", "lecture") ~= nil, "la lecture des prototypes repond (fo-ind, lecture)")
      end
      -- 2. la décision de la capitalisation est hâtée (elle tombe sinon vers le tick 3 300)
      -- (après 1 000 ticks : le besoin évalué du cerveau, qui borne le stock libre, a relu les pièces posées à 400)
      if st.key and not st.hastened and e.tick >= 1000 and e.tick % 60 == 0 then
        if ctx.remote("fo-ind", "hasten", st.key) == true then
          st.hastened = e.tick
          ctx.log("decision hatee au tick " .. e.tick)
        end
      end
      -- 2 bis. BANC SEULEMENT : le temps. Les PNJ d'une faction à 1 minute de jeu mettent plus de 9 000 ticks à bâtir 55 entités (mesuré :
      -- 54 sur 55 à 9 000 ticks, 29 sur 55 à 9 000 ticks sur une autre passe) ; dès que le plan a posé les fantômes du bloc, le banc les
      -- RAVIVE lui-même, alimente le module (source d'arène à côté d'un poteau bâti) et garnit ses quais d'entrée (le coffre du QG fait la
      -- même chose par les PNJ). Le reste de la chaîne (états du plan directeur, recettes, inscription des sorties, barre) est celui du mod.
      if st.key and e.tick >= 3000 and e.tick % 120 == 0 and not st.done_fini then
        local s0 = ctx.remote("fo-ind", "status", st.key)
        local b0 = s0 and s0.blocs and s0.blocs[1]
        if b0 and (b0.state == "fantomes" or b0.state == "chantier" or b0.state == "raccordement" or b0.state == "fini") then
          local s1 = ctx.surface()
          local ents = module_ents(ctx, st.key, b0.id)
          local revived = ctx.remote("fo-ind", "revive", st.key, b0.id) or 0
          st.revived = (st.revived or 0) + revived
          if not st.powered then
            for _, en in ipairs(ents) do
              if not st.powered and en.name:find("electric%-pole") then
                local real = s1.find_entity(en.name, { en.x, en.y })
                if real and real.valid then
                  for _, d in ipairs({ { 2, 2 }, { -2, 2 }, { 2, -2 }, { -2, -2 }, { 3, 0 }, { 0, 3 }, { -3, 0 }, { 0, -3 } }) do
                    if not st.powered and ctx.power(real.position.x + d[1], real.position.y + d[2], real.force.name) then
                      st.powered = true
                      ctx.log(string.format("source d'arene posee a cote du poteau (%.1f, %.1f)", real.position.x, real.position.y))
                    end
                  end
                end
              end
            end
          end
          if b0.state == "fini" then
            st.done_fini = e.tick
            local s1b = ctx.surface()
            for _, q in ipairs(b0.quais or {}) do
              local ch = s1b.find_entity("iron-chest", { q.x, q.y })
              if ch and ch.valid then ch.insert({ name = q.item, count = 600 }) end
            end
            ctx.log(string.format("bloc %d FINI au tick %d (%d fantome(s) ravives par le banc, %d quai(s) garni(s))", b0.id, e.tick, st.revived or 0, #(b0.quais or {})))
          end
        end
      end
      -- 3. relevé
      if st.key and e.tick % 600 == 0 and e.tick >= 600 then
        local s = ctx.remote("fo-ind", "status", st.key)
        local c = ctx.remote("fo-ind", "status", st.control)
        local rec = { tick = e.tick, blocs = s and s.blocs or {}, control = c and #c.blocs or 0 }
        st.t[#st.t + 1] = rec
        local parts = {}
        for _, b in ipairs(rec.blocs) do
          local miss = {}
          for _, mm in ipairs(b.missing or {}) do miss[#miss + 1] = tostring(mm[1]) .. " " .. tostring(mm[2]) end
          parts[#parts + 1] = string.format("%d:%s:%s:%d/%d%s", b.id, b.kind, b.state, b.built, b.total,
            (#miss > 0 or b.reason) and (" (" .. tostring(b.reason) .. " ; manque " .. table.concat(miss, ", ") .. ")") or "")
        end
        ctx.log(string.format("tick %d : blocs [%s] ; temoin %d bloc(s) ; sig %s", e.tick, table.concat(parts, " "), rec.control,
          tostring(s and s.sig or "?")))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if cfg.machine_proto and not st.jetable then
        ctx.check(true, "scenario de la copie jetable : rien a verifier sur le mod livre")
        return
      end
      ctx.check(st.hastened ~= nil, "la decision de la capitalisation a ete hatee")
      -- les chaines que le journal du DC montrait refusees (« a 3 ingredients », « recherche : » vide) ont une methode, lue dans les prototypes
      if not cfg.machine_proto then
        for _, it in ipairs({ "gun-turret", "piercing-rounds-magazine", "iron-chest", "grenade", "advanced-circuit", "engine-unit" }) do
          local m, why = ctx.remote("fo-ind", "methode", it)
          ctx.check(m ~= nil and (m.gen == "patron" or m.gen == "simple"), "methode de " .. it .. " : " .. tostring(m and (m.gen .. " " .. tostring(m.machine) .. " " .. tostring(m.n_ent) .. " entites") or why))
        end
      end
      local s = ctx.remote("fo-ind", "status", st.key)
      ctx.check(s ~= nil and #s.blocs >= 1, st.key .. " : au moins un bloc demande (" .. tostring(s and #s.blocs or 0) .. ")")
      local c = ctx.remote("fo-ind", "status", st.control)
      ctx.check(c == nil or #c.blocs == 0, "temoin : aucune demande, aucun bloc (" .. tostring(c and #c.blocs or 0) .. ")")
      local b = s and s.blocs[1]
      if not b then return end
      -- le bloc : tous les objets demandés sont dans le module, une machine par objet
      ctx.check(b.kind == "bloc", "le choix est un BLOC partage (" .. tostring(b.kind) .. ")")
      ctx.check(#b.items == #cfg.items, "tous les objets demandes sont dans le bloc (" .. #b.items .. " sur " .. #cfg.items .. ")")
      ctx.check(b.total > 0, "le plan directeur a place le bloc (" .. tostring(b.total) .. " entite(s))")
      ctx.log(string.format("etat final du bloc %d : %s, %d / %d entite(s) bâties", b.id, b.state, b.built, b.total))
      do
        local qs, os_ = {}, {}
        for _, q in ipairs(b.quais or {}) do qs[#qs + 1] = string.format("%s(%.1f,%.1f)", q.item, q.x, q.y) end
        for _, o in ipairs(b.outs or {}) do os_[#os_ + 1] = string.format("(%.1f,%.1f)", o.x, o.y) end
        ctx.log("quais d'entree du plan : " .. table.concat(qs, " ") .. " | sorties inscrites : " .. table.concat(os_, " "))
      end
      local ents = module_ents(ctx, st.key, b.id)
      local machines, built_machines, running = 0, 0, 0
      local s1 = ctx.surface()
      local items = {}
      for _, it in ipairs(b.items) do items[it] = true end
      for _, e2 in ipairs(ents) do
        local proto = game.entity_prototypes[e2.name]
        if proto and proto.type == "assembling-machine" then
          machines = machines + 1
          if e2.built then built_machines = built_machines + 1 end
          local real = s1.find_entity(e2.name, { e2.x, e2.y })
          if real and real.valid then
            local r = real.get_recipe()
            if r and items[r.products[1].name] then running = running + 1 end
          end
        end
      end
      ctx.check(machines == #cfg.items, "une machine par objet dans le plan (" .. machines .. ")")
      ctx.log(string.format("machines : %d au plan, %d batie(s), %d avec la recette d'un objet du bloc", machines, built_machines, running))
      if b.state == "fini" then
        ctx.check(running == #cfg.items, "bloc fini : chaque machine a la recette de son objet (" .. running .. ")")
        -- sorties : les coffres inscrits à la collecte portent la barre
        local bars, filled, total_items, kinds = 0, 0, 0, {}
        local made = {}
        for _, o in ipairs(b.outs or {}) do
          local ch = s1.find_entity("iron-chest", { o.x, o.y })
          if ch and ch.valid then
            local inv = ch.get_inventory(defines.inventory.chest)
            if inv.supports_bar() and inv.get_bar() <= #inv then bars = bars + 1 end
            local c = inv.get_contents()
            local n = 0
            for _, k in ipairs(sorted_keys(c)) do
              if items[k] then n = n + c[k] made[k] = (made[k] or 0) + c[k] end
            end
            if n > 0 then filled = filled + 1 end
            total_items = total_items + n
          end
        end
        for k in pairs(made) do kinds[#kinds + 1] = k end
        ctx.log(string.format("coffres de sortie inscrits : %d ; %d a barre (barre %s), %d garni(s), %d objet(s) du bloc en tout, %d sorte(s) : %s", #(b.outs or {}),
          bars, tostring(b.barre), filled, total_items, #kinds, table.concat(kinds, ",")))
        ctx.check(#(b.outs or {}) >= #cfg.items, "les coffres de sortie du bloc sont inscrits a la collecte (" .. #(b.outs or {}) .. ")")
        ctx.check(bars >= #cfg.items, "les coffres de sortie portent la barre (" .. bars .. ")")
        ctx.check(filled >= 1 and #kinds >= 2, "des objets du bloc sont fabriques et au coffre de sortie (" .. total_items .. " objet(s), " .. #kinds .. " sorte(s))")
      else
        ctx.log("bloc pas fini a la fin du banc (" .. b.state .. ") : machines en marche et coffres non controles")
      end
    end,
  }
end
