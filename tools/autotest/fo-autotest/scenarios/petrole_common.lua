--[[
  Lot PETROLE (A9 « aller au pétrole, comme un joueur ») : la partie de mesure d'iag-partie (4 factions, Paisible,
  cerveau général) jouée RÉGLAGE fo-war-petrole ALLUMÉ (éteint par défaut, settings/petrole.lua), allongée à 90 à
  120 min. Relevé toutes les 10 min (interface « fo-petrole ») et contrôles à `check_tick` :
    1. réglage allumé ;
    2. au moins une faction a trouvé le pétrole (gisement connu de son exécutant) ;
    3. au moins une faction a POSÉ chevalet, raffinerie et usine chimique (recensement en jeu, find_entities_filtered) ;
    4. au moins une faction a FABRIQUÉ des packs chimiques (statistiques de production de sa force) ;
    5. au moins une faction a RECHERCHÉ une technologie du palier 4 (une technologie qui consomme le pack chimique) ;
    6. chaque site posé vient d'une décision au journal (décisions ≥ 1).
  Les contrôles du cerveau général d'iag_common (paliers A1) restent : ils disent si la recherche souffre.
  Variante « photo » (banc.py --captures --visuel="--ticks N") : capture du site de chaque faction qui en a un.
  Journal : [FO-PETROLE] (décisions, côté mod), [FO-<SCENARIO>] (relevés et contrôles).
]]

local OIL = { "pumpjack", "oil-refinery", "chemical-plant" }
local PACK = "chemical-science-pack"

return function(variant, ticks)
  local base = require("scenarios/iag_common")("partie", ticks)
  local photo = variant:find("photo", 1, true) ~= nil
  local CHECK = (ticks or 432000) - 600
  base.check_tick = CHECK
  base.description = "PETROLE : aller au petrole (reglage fo-war-petrole allume, " .. variant .. ")"
  local init0, tick0, finish0 = base.init, base.tick, base.finish
  base.init = function(ctx)
    init0(ctx)
    local on = ctx.call("war_setting", "fo-war-petrole", true)
    ctx.check(on == true, "reglage fo-war-petrole allume", tostring(on))
  end
  local function factions()
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    local out = {}
    for _, row in ipairs(ok and rows or {}) do if row.key ~= "player" then out[#out + 1] = row end end
    return out
  end
  local function census(s, force)
    local n = {}
    for _, name in ipairs(OIL) do n[name] = s.count_entities_filtered({ name = name, force = force }) end
    return n
  end
  local function tier4(force)
    local f = game.forces[force]
    local out = {}
    if not f then return out end
    local names = {}
    for name in pairs(f.technologies) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local t = f.technologies[name]
      if t.researched then
        for _, ing in ipairs(t.research_unit_ingredients) do if ing.name == PACK then out[#out + 1] = name end end
      end
    end
    return out
  end
  local function report(ctx, tick)
    local s = ctx.surface()
    for _, row in ipairs(factions()) do
      local okp, st = pcall(remote.call, "fo-petrole", "status", row.key)
      st = okp and st or {}
      local n = census(s, row.force)
      local f = game.forces[row.force]
      local made = f and f.item_production_statistics.get_input_count(PACK) or 0
      local prod = {}
      for _, it in ipairs({ "engine-unit", "plastic-bar", "sulfur", "advanced-circuit" }) do
        prod[#prod + 1] = it .. "=" .. (f and f.item_production_statistics.get_input_count(it) or 0)
      end
      local sites = {}
      for _, x in ipairs(st.sites or {}) do
        sites[#sites + 1] = string.format("%s:%s(%s/%s)%s", x.key, tostring(x.state), tostring(x.built), tostring(x.total),
          x.reason and ("<" .. x.reason .. ">") or "")
      end
      ctx.log(string.format("minute %d | %s | connus [%s] | decisions %d | sites [%s] | chevalets %d raffineries %d usines %d | packs chimiques %d | produits [%s] | palier 4 [%s]",
        math.floor(tick / 3600), row.key, table.concat(st.known or {}, " "), st.decisions or 0, table.concat(sites, " "),
        n.pumpjack, n["oil-refinery"], n["chemical-plant"], made, table.concat(prod, " "), table.concat(tier4(row.force), " ")))
    end
  end
  base.tick = function(ctx, e)
    tick0(ctx, e)
    if e.tick % 36000 == 0 and e.tick > 0 then report(ctx, e.tick) end
    if photo and e.tick == CHECK - 300 then
      local s = ctx.surface()
      local p = game.connected_players[1]
      for _, row in ipairs(factions()) do
        local okp, st = pcall(remote.call, "fo-petrole", "status", row.key)
        for _, x in ipairs((okp and st and st.sites) or {}) do
          if (x.built or 0) > 0 then
            local ents = s.find_entities_filtered({ name = OIL, force = row.force })
            local cx, cy, n = 0, 0, 0
            for _, en in ipairs(ents) do cx, cy, n = cx + en.position.x, cy + en.position.y, n + 1 end
            if n > 0 then
              local name = string.format("petrole-%s-%s.png", row.key, x.key)
              game.take_screenshot({ path = "fo-shots/" .. name, player = p, surface = s, position = { cx / n, cy / n },
                zoom = 0.5, resolution = { 1600, 1200 }, daytime = 0, force_render = true, show_entity_info = true,
                allow_in_replay = true })
              ctx.log(string.format("capture %s demandee en (%.0f, %.0f), %d machines du petrole", name, cx / n, cy / n, n))
            end
          end
        end
      end
    end
  end
  base.finish = function(ctx)
    finish0(ctx)
    report(ctx, game.tick)
    local s = ctx.surface()
    local n_known, n_built, n_pack, n_t4, n_dec_ok, n_fac = 0, 0, 0, 0, 0, 0
    local t4list = {}
    for _, row in ipairs(factions()) do
      n_fac = n_fac + 1
      local okp, st = pcall(remote.call, "fo-petrole", "status", row.key)
      st = okp and st or {}
      for _, k in ipairs(st.known or {}) do if k == "crude-oil" then n_known = n_known + 1 end end
      local n = census(s, row.force)
      if n.pumpjack > 0 and n["oil-refinery"] > 0 and n["chemical-plant"] > 0 then n_built = n_built + 1 end
      if (n.pumpjack + n["oil-refinery"] + n["chemical-plant"] == 0) or (st.decisions or 0) >= 1 then n_dec_ok = n_dec_ok + 1 end
      local f = game.forces[row.force]
      if f and f.item_production_statistics.get_input_count(PACK) > 0 then n_pack = n_pack + 1 end
      local t4 = tier4(row.force)
      if #t4 > 0 then n_t4 = n_t4 + 1; t4list[#t4list + 1] = row.key .. ":" .. table.concat(t4, ",") end
      for _, l in ipairs(st.logs or {}) do ctx.log("journal " .. l) end
    end
    ctx.check(n_known >= 1, "au moins une faction a trouve le petrole", n_known .. "/" .. n_fac)
    ctx.check(n_built >= 1, "au moins une faction a pose chevalet, raffinerie et usine chimique", n_built .. "/" .. n_fac)
    ctx.check(n_pack >= 1, "au moins une faction a fabrique des packs chimiques", n_pack .. "/" .. n_fac)
    ctx.check(n_t4 >= 1, "au moins une faction a recherche une technologie du palier 4", n_t4 .. "/" .. n_fac .. " " .. table.concat(t4list, " "))
    ctx.check(n_dec_ok == n_fac, "chaque site pose vient d'une decision au journal", n_dec_ok .. "/" .. n_fac)
  end
  return base
end
