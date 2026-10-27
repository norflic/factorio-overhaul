--[[
  Lot IA-G « le cerveau général » : partie de MESURE (la partie « default » d'IA3-DIAG : 4 factions, 100 soldats,
  10 ouvriers dont 8 au départ, Paisible ; cerveau par besoins allumé par défaut) avec les relevés par minute
  d'ia3d_common, plus les contrôles du cerveau général à `check_tick` :
    1. catalogue lu dans les prototypes (interface « fo-iag ») ;
    2. chaque faction vivante a CHOISI elle-même au moins 2 technologies (décisions [FO-CERVEAU]) ;
    3. chaque faction a RECHERCHÉ au moins une technologie choisie (force.technologies[...].researched) ;
    4. cibles A1 (docs/IA_ATTENDUS.md) : paliers 1 / 2 / 3 (interface « fo-ia3c ») atteints en ≤ 6 / 12 / 25 min, en
       MÉDIANE des factions (un contrôle par palier ; un palier jamais atteint compte comme « jamais ») ;
    5. variante « jetable » (copie aux DONNÉES CHANGÉES, tools/autotest/iag/jetable.py) : les données changées sont
       lues (recettes et prérequis), la pierre est une ressource NÉCESSAIRE (ressources clés déduites), et une faction
       qui a choisi le pack vert a d'abord recherché son prérequis nouveau.
  Variantes : iag-partie (normale), iag-jetable (copie jetable). Journal : [FO-IA3D-DEFAULT] (relevés) et les
  contrôles du banc.
]]

return function(variant, ticks)
  local base = require("scenarios/ia3d_common")("default")
  local CHECK = (ticks or 162000) - 600
  base.check_tick = CHECK
  base.description = "IA-G : cerveau general, partie normale (" .. variant .. ")"
  local finish0 = base.finish
  -- Variante « photo » (session AVEC images, banc.py --captures --visuel="--ticks N") : captures du QG de chaque faction
  -- (laboratoires du QG, fours, coffre) aux minutes SHOTS, zoom 0,6, de jour, infos des entités (mode Alt).
  local SHOTS = { 36000, 72000, 108000 }
  local tick0 = base.tick
  base.tick = function(ctx, e)
    tick0(ctx, e)
    if variant ~= "photo" then return end
    for _, t in ipairs(SHOTS) do
      if e.tick == t then
        local ok, rows = pcall(remote.call, "fo-ia1", "teams")
        local s = ctx.surface()
        local p = game.connected_players[1]
        for _, row in ipairs(ok and rows or {}) do
          if row.key ~= "player" then
            local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
            if hq and hq.valid then
              local name = string.format("iag-%s-%02dmin.png", row.key, math.floor(t / 3600))
              game.take_screenshot({ path = "fo-shots/" .. name, player = p, surface = s, position = hq.position,
                zoom = 0.6, resolution = { 1600, 1200 }, daytime = 0, force_render = true, show_entity_info = true,
                allow_in_replay = true })
              local labs = s.count_entities_filtered({ type = "lab", force = row.force })
              local furn = s.count_entities_filtered({ type = "furnace", force = row.force })
              ctx.log(string.format("capture %s demandee : %s, laboratoires %d, fours %d", name, row.key, labs, furn))
            end
          end
        end
      end
    end
  end

  local function median(list)
    table.sort(list)
    if #list == 0 then return nil end
    return list[math.floor((#list + 1) / 2)]
  end

  base.finish = function(ctx)
    finish0 = finish0 -- les relevés par minute d'ia3d_common : leur contrôle (≥ 100 lignes) ne vaut pas ici
    local st = ctx.state()
    ctx.check((st.lines or 0) >= math.floor(CHECK / 3600) - 2, "releves par minute ecrits", st.lines)
    local okc, catinfo = pcall(remote.call, "fo-iag", "catalogue")
    ctx.check(okc and type(catinfo) == "table" and (catinfo.recipes or 0) > 50 and (catinfo.packs or 0) >= 3,
      "catalogue du cerveau general lu dans les prototypes", okc and catinfo and
      (tostring(catinfo.recipes) .. " recettes, " .. tostring(catinfo.techs) .. " technologies, " .. tostring(catinfo.packs) .. " packs, combustible " .. tostring(catinfo.fuel)) or tostring(catinfo))
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    rows = ok and rows or {}
    local n_fac, n_dec, n_res = 0, 0, 0
    local pal = { {}, {}, {} }
    local jet_order, jet_seen = 0, 0
    for _, row in ipairs(rows) do
      if row.key ~= "player" then
        n_fac = n_fac + 1
        local okg, g = pcall(remote.call, "fo-iag", "status", row.key)
        local force = game.forces[row.force]
        local researched = 0
        local order = {}
        if okg and g then
          if (g.decisions or 0) >= 2 then n_dec = n_dec + 1 end
          for i, h in ipairs(g.history or {}) do
            order[h.tech] = i
            if force and force.technologies[h.tech] and force.technologies[h.tech].researched then researched = researched + 1 end
          end
          ctx.log(string.format("%s : %d decision(s), %d recherchee(s) parmi les choisies, ressources cles %s / %s",
            row.key, g.decisions or 0, researched, g.key and tostring(g.key.top) or "?", g.key and tostring(g.key.fuel) or "?"))
          if variant == "jetable" then
            local opt = g.key and g.key.optional or {}
            ctx.check(g.key ~= nil and not opt.stone, row.key .. " : pierre NECESSAIRE (pack rouge a la brique, ressources cles deduites)",
              g.key and table.concat(g.key.order or {}, ",") or "?")
            if order["logistic-science-pack"] then
              jet_seen = jet_seen + 1
              if order["logistics"] and order["logistics"] < order["logistic-science-pack"] then jet_order = jet_order + 1 end
            end
          end
        end
        if researched >= 1 then n_res = n_res + 1 end
        local okp, s = pcall(remote.call, "fo-ia3c", "status", row.key)
        for k = 1, 3 do
          local t = okp and s and s.paliers and s.paliers[k]
          pal[k][#pal[k] + 1] = t and (t / 3600) or 1e9
        end
      end
    end
    ctx.check(n_fac > 0 and n_dec == n_fac, "chaque faction a choisi au moins 2 technologies elle-meme", n_dec .. "/" .. n_fac)
    ctx.check(n_fac > 0 and n_res == n_fac, "chaque faction a recherche au moins une technologie choisie", n_res .. "/" .. n_fac)
    local target = { 6, 12, 25 }
    for k = 1, 3 do
      local m = median(pal[k])
      local txt = {}
      for _, v in ipairs(pal[k]) do txt[#txt + 1] = v < 1e8 and string.format("%.1f", v) or "jamais" end
      ctx.check(m ~= nil and m <= target[k], string.format("cible A1 : palier %d en mediane <= %d min", k, target[k]),
        table.concat(txt, " "))
    end
    if variant == "jetable" then
      local r = game.recipe_prototypes["iron-gear-wheel"]
      local has_cu = false
      for _, i in ipairs(r and r.ingredients or {}) do if i.name == "copper-plate" then has_cu = true end end
      ctx.check(has_cu, "donnees changees lues : l'engrenage demande du cuivre")
      local rp = game.recipe_prototypes["automation-science-pack"]
      local has_brick = false
      for _, i in ipairs(rp and rp.ingredients or {}) do if i.name == "stone-brick" then has_brick = true end end
      ctx.check(has_brick, "donnees changees lues : le pack rouge demande une brique")
      local t = game.technology_prototypes["logistic-science-pack"]
      ctx.check(t and t.prerequisites["logistics"] ~= nil, "donnees changees lues : le pack vert exige 'logistics'")
      ctx.check(jet_seen == 0 or jet_order == jet_seen, "prerequis nouveau recherche avant le pack vert", jet_order .. "/" .. jet_seen)
    end
  end
  return base
end
