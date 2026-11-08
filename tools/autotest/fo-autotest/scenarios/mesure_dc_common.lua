--[[
  Lot MESURE-DC (8/11/2026, demande du lead) : relevé d'ÉTAT sur la sauvegarde du DC (autosave1-2121.zip, 255 min, 4 factions, équipe du
  joueur à 30 PNJ) : machines posées et en marche, causes d'arrêt, ce qui manque, recherche, époque, PNJ, plaques. Aucun seuil :
  les contrôles ne portent que sur la plomberie. Critères écrits avant le banc : fo-logs\2026-11-08_MESURE-DC\CRITERES.md.
  MODE "petrole" : allume fo-war-petrole au premier tick (interface existante factorio-overhaul.war_setting) ; MODE "temoin" : rien changé.
  Réutilise scenarios/fonction_common.lua (lignes [FO-FONCTION], relevés toutes les 30 s, fenêtres de 5 min ici).
  Lignes [FO-MESURE-DC] : RECENSEMENT (instantané), MANQUES (cumul de la fenêtre), RECHERCHE, EQUIPE.
  Lancement : banc.py --qui MESURE-DC --sauvegarde <zip> --out <archive> -- 36200 mesure-dc <source>
]]
local Fn = require("scenarios/fonction_common")

local SAMPLE, WIN, SPAN = Fn.SAMPLE, 18000, 36000 -- modifies par ESSAI
local MIN = 3600

local CENSUS = {
  { cls = "foreuse", types = { "mining-drill" } },
  { cls = "four", types = { "furnace" } },
  { cls = "assembleur", types = { "assembling-machine" } },
  { cls = "labo", types = { "lab" } },
}

local SHORT = { item_ingredient_shortage = true, no_ingredients = true, missing_science_packs = true, waiting_for_source_items = true }
local names_cache
local function status_name(e)
  if not names_cache then
    names_cache = {}
    for k, v in pairs(defines.entity_status) do names_cache[v] = k end
  end
  local s = e.status
  return s and names_cache[s] or "aucun"
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Texte "k=v k=v" trié par valeur décroissante puis par nom, `top` premiers (0 : tous).
local function top_text(t, top)
  local ks = sorted_keys(t)
  table.sort(ks, function(a, b) if t[a] ~= t[b] then return t[a] > t[b] end return a < b end)
  local parts = {}
  for i = 1, #ks do
    if top and top > 0 and i > top then break end
    parts[#parts + 1] = ks[i] .. "=" .. t[ks[i]]
  end
  return table.concat(parts, " ")
end

local function teams()
  local rows = remote.call("fo-ia1", "teams") or {}
  local forces = { { key = "player", force = "player" } }
  for _, r in ipairs(rows) do if r.key ~= "player" then forces[#forces + 1] = { key = r.key, force = r.force } end end
  return forces, rows
end

local function row_of(rows, key)
  for _, r in ipairs(rows) do if r.key == key then return r end end
  return nil
end

--- Ce qui manque à une machine en pénurie d'ingrédient (stock d'entrée lu dans la machine). Rend une liste de noms.
local function missing_of(e, cls, force)
  local out = {}
  if cls == "assembleur" then
    local r = e.get_recipe()
    if not r then return { "sans-recette" } end
    local inv = e.get_inventory(defines.inventory.assembling_machine_input)
    for _, ing in ipairs(r.ingredients) do
      if ing.type == "item" and (not inv or inv.get_item_count(ing.name) < ing.amount) then out[#out + 1] = ing.name end
    end
    if #out == 0 then out[1] = "autre(" .. r.name .. ")" end
  elseif cls == "labo" then
    local cr = force.current_research
    if not cr then return { "aucune-recherche" } end
    local inv = e.get_inventory(defines.inventory.lab_input)
    for _, ing in ipairs(cr.research_unit_ingredients) do
      if not inv or inv.get_item_count(ing.name) < 1 then out[#out + 1] = ing.name end
    end
    if #out == 0 then out[1] = "autre" end
  elseif cls == "four" then
    local inv = e.get_inventory(defines.inventory.furnace_source)
    if not inv or inv.is_empty() then
      out[1] = "source-vide"
    else
      local c = inv.get_contents()
      local k = sorted_keys(c)
      out[1] = "source-insuffisante:" .. (k[1] or "?")
    end
  end
  return out
end

--- Un relevé de 30 s : cumule, par force, les ingrédients manquants des machines en pénurie.
local function tally_missing(st, s, forces)
  st.tally = st.tally or {}
  for _, f in ipairs(forces) do
    local T = st.tally[f.key]
    if not T then T = {} st.tally[f.key] = T end
    local force = game.forces[f.force]
    if force then
      for _, c in ipairs(CENSUS) do
        if c.cls ~= "foreuse" then
          for _, e in ipairs(s.find_entities_filtered({ force = f.force, type = c.types })) do
            local sn = status_name(e)
            if SHORT[sn] then
              for _, m in ipairs(missing_of(e, c.cls, force)) do
                local k = c.cls .. ":" .. m
                T[k] = (T[k] or 0) + 1
              end
            elseif sn == "fluid_ingredient_shortage" then
              T[c.cls .. ":fluide"] = (T[c.cls .. ":fluide"] or 0) + 1
            end
          end
        end
      end
    end
  end
end

--- Instantané : par force et par classe, posées / en marche / causes d'arrêt.
local function census(ctx, s, forces, label, dt)
  for _, f in ipairs(forces) do
    local parts = {}
    for _, c in ipairs(CENSUS) do
      local n, w, by = 0, 0, {}
      for _, e in ipairs(s.find_entities_filtered({ force = f.force, type = c.types })) do
        if not e.name:find("pumpjack", 1, true) then
          n = n + 1
          local sn = status_name(e)
          if sn == "working" then w = w + 1 else by[sn] = (by[sn] or 0) + 1 end
        end
      end
      parts[#parts + 1] = string.format("%s n=%d marche=%d part=%.0f%% arrets{%s}", c.cls, n, w, n > 0 and 100 * w / n or 0, top_text(by, 0))
    end
    ctx.log(string.format("RECENSEMENT %s (+%.1f min) | %s | %s", label, dt / MIN, f.key, table.concat(parts, " | ")))
  end
end

--- Lot BLOCAGE-SORTIE-2 : le puits de C2 (ouvert ou non, et pourquoi) et l'etat du stock de chaque force a chaque fenetre.
local function sortie_line(ctx, forces, label, dt)
  for _, f in ipairs(forces) do
    local ok, st = pcall(remote.call, "fo-capi", "status", f.key)
    local r = ok and st and st.res or nil
    local pz = r and r.puits or nil
    local okp, pr = pcall(remote.call, "fo-ia1", "collect_probe", f.key)
    local stock = okp and pr and pr.stock or nil
    ctx.log(string.format("SORTIE %s (+%.1f min) | %s | puits=%s threat=%s demande_in=%s reserve_in=%s ordres=%s depense=%s budget=%s | stock cases=%s vides=%s",
      label, dt / MIN, f.key,
      pz and string.format("p=%.2f dormant=%s cap=%.2f", pz.p or 0, tostring(pz.dormant), pz.cap or 0) or "ferme",
      tostring(r and r.threat), tostring(r and r.demande_in), tostring(r and r.reserve_in), tostring(st and st.orders), tostring(r and r.spent),
      tostring(r and r.budget), tostring(stock and stock.slots), tostring(stock and stock.empty)))
  end
end

local function report_window(ctx, s, forces, rows, dt, label)
  local st = ctx.state()
  census(ctx, s, forces, label, dt)
  sortie_line(ctx, forces, label, dt)
  st.tally = st.tally or {}
  st.techset = st.techset or {}
  local centres = {}
  for _, f in ipairs(forces) do
    local ok, res = pcall(remote.call, "factorio-overhaul", "levels_status", f.force)
    centres[f.key] = ok and res and res.cc_level or nil
  end
  for _, f in ipairs(forces) do
    ctx.log(string.format("MANQUES %s (+%.1f min) | %s | %s", label, dt / MIN, f.key, top_text(st.tally[f.key] or {}, 12)))
    st.tally[f.key] = {}
    local force = game.forces[f.force]
    if force then
      local cr = force.current_research
      local packs = {}
      if cr then for _, ing in ipairs(cr.research_unit_ingredients) do packs[#packs + 1] = ing.name end end
      local q = 0
      pcall(function() q = #force.research_queue end)
      local seen = st.techset[f.key]
      local first = (seen == nil)
      seen = seen or {}
      local fresh, total = {}, 0
      for _, name in ipairs(sorted_keys(force.technologies)) do
        local tc = force.technologies[name]
        if tc.researched then
          total = total + 1
          if not seen[name] then
            seen[name] = true
            if not first then fresh[#fresh + 1] = name end
          end
        end
      end
      st.techset[f.key] = seen
      ctx.log(string.format("RECHERCHE %s (+%.1f min) | %s | en_cours=%s progres=%.0f%% paquets{%s} file=%d finies=%d nouvelles{%s}",
        label, dt / MIN, f.key, cr and cr.name or "aucune", 100 * (force.research_progress or 0), table.concat(packs, ","), q, total,
        table.concat(fresh, ",")))
    end
    local r = row_of(rows, f.key)
    if r then
      ctx.log(string.format("EQUIPE %s (+%.1f min) | %s | epoque_centre=%s palier_plan=%s pnj=%d/%d soldats=%d perdus=%d avant_postes=%d fer_stock=%d"
        .. " cumul{fer=%d cuivre=%d charbon=%d pierre=%d minerai_fer=%d minerai_cuivre=%d}",
        label, dt / MIN, f.key, tostring(centres[f.key] or "-"), tostring(r.tech), r.n or 0, r.max or 0, r.soldiers or 0, r.lost or 0,
        r.outposts or 0, r.iron or 0, (r.produced or {})["iron-plate"] or 0, (r.produced or {})["copper-plate"] or 0,
        (r.produced or {})["coal"] or 0, (r.produced or {})["stone"] or 0, (r.produced or {})["iron-ore"] or 0,
        (r.produced or {})["copper-ore"] or 0))
    end
  end
end

return function(MODE, ESSAI, MINUTES)
  if ESSAI then WIN, SPAN = SAMPLE, 2 * SAMPLE end -- essai de plomberie : fenetres de 30 s, 1 min en tout
  if MINUTES then SPAN = MINUTES * MIN end -- lot BLOCAGE-SORTIE-2 : duree choisie par le scenario (fenetres de WIN)
  local S = {
    description = "MESURE-DC : releve d'etat sur la sauvegarde du DC, fo-war-petrole " .. (MODE == "petrole" and "allume" or "laisse tel quel (temoin)"),
    check_tick = -1,
  }

  S.init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.t0 = game.tick
    S.check_tick = st.t0 + SPAN
    local sv = settings.global["fo-war-petrole"]
    st.petrole_avant = sv and sv.value
    if MODE == "petrole" then
      st.petrole_apres = ctx.call("war_setting", "fo-war-petrole", true)
    else
      st.petrole_apres = st.petrole_avant
    end
    ctx.log(string.format("DEPART tick %d (%.1f min de jeu) ; fo-war-petrole avant=%s apres=%s ; mode %s", st.t0, st.t0 / MIN,
      tostring(st.petrole_avant), tostring(st.petrole_apres), MODE))
    local forces, rows = teams()
    ctx.log("forces relevees : " .. #forces)
    Fn.sample_all(st, s, forces, st.t0, rows)
    local techs = {}
    for _, f in ipairs(forces) do techs[#techs + 1] = f.key .. "=" .. Fn.researched(f.force) end
    ctx.log("technologies finies au depart : " .. table.concat(techs, " "))
    -- Etat initial de la recherche et de l'epoque (fenetre 0 : les 'nouvelles' ne sont pas listees au premier appel)
    report_window(ctx, s, forces, rows, 0, "DEPART")
  end

  S.tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local dt = e.tick - st.t0
    if dt <= 0 or dt >= SPAN then return end
    local s = ctx.surface()
    if dt == 600 then
      local forces = teams()
      census(ctx, s, forces, "PLUS10S", dt)
    end
    if dt % SAMPLE == 0 then
      local forces, rows = teams()
      Fn.sample_all(st, s, forces, e.tick, rows)
      tally_missing(st, s, forces)
      if dt % WIN == 0 then
        Fn.report_all(st, s, forces, math.floor(dt / MIN), e.tick, rows)
        report_window(ctx, s, forces, rows, dt, "MIN" .. math.floor(dt / MIN))
      end
    end
  end

  S.finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.t0 ~= nil and st.t0 > 0, "sauvegarde du DC chargee (tick de depart > 0)", st.t0)
    if not st.t0 then return end
    ctx.check(st.petrole_apres == (MODE == "petrole" and true or st.petrole_avant), "fo-war-petrole conforme au mode",
      string.format("avant=%s apres=%s", tostring(st.petrole_avant), tostring(st.petrole_apres)))
    local s = ctx.surface()
    local forces, rows = teams()
    local tick = game.tick
    Fn.sample_all(st, s, forces, tick, rows)
    tally_missing(st, s, forces)
    Fn.report_all(st, s, forces, math.floor(SPAN / MIN), tick, rows)
    report_window(ctx, s, forces, rows, SPAN, "MIN" .. math.floor(SPAN / MIN))
    ctx.check(#forces >= 2, "au moins 2 forces relevees (equipe et factions)", #forces)
  end

  return S
end
