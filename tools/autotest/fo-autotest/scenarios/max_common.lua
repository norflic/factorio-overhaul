--[[
  Lot CARTE-MAX (directive du DC, 9/11) : « configurer la génération de la nouvelle carte de test avec la taille et la richesse des
  gisements de ressources au MAXIMUM ». Module de banc (aucun fichier du mod touché), lu par scenarios/etape1-max.lua et
  scenarios/etape1-max-court.lua.

  POURQUOI PAR SCÉNARIO. fo-autotest.bat crée la carte avec `--create ... --map-gen-seed S` sans fichier de réglages de carte
  (ligne 277) et ne doit pas être modifié pendant que des bancs tournent. Or le scénario greffé joue son `init` PENDANT la
  création de la carte (on_init), avant toute génération lointaine : à ce moment seuls les chunks du départ existent. Le moteur
  permet (runtime-api, LuaSurface::map_gen_settings) de changer les réglages d'une surface « sans la régénérer
  rétroactivement » et donne les moyens de le faire à la main (delete_chunk). On fait donc :
    1. réglages : pour TOUTE ressource (catégorie « resource » de game.autoplace_control_prototypes : fer, cuivre, charbon,
       pierre, uranium, pétrole brut et celles du mod `fo-*`), size = 6 et richness = 6 (600 %, maximum de l'écran de carte) ;
       la fréquence est inchangée ; les autres contrôles (eau, ennemis, arbres) aussi ;
    2. les chunks déjà générés sont effacés (delete_chunk) puis régénérés avec les nouveaux réglages, même rayon : le résultat est
       celui d'une carte créée avec ces réglages ;
    3. les garanties de monnaies du mod (script/world/guarantee.lua) avaient posé leurs sites dans ces chunks : on les « oublie »
       (remote fo-monde.forget) pour que le filet périodique les repose sur le terrain neuf.
  RELEVÉ (tick `at`, après la fondation des QG) : pour votre équipe et chaque faction, tuiles de minerai et quantité par
  ressource dans un rayon R autour du QG, sur la carte max ET sur une surface de RÉFÉRENCE de même graine aux réglages d'origine
  (surface « carte-max-defaut », créée au relevé puis effacée) : le facteur se lit dans la ligne [FO-CARTE-MAX].
]]

local M = {}

M.TAG = "[FO-CARTE-MAX] "
M.SIZE, M.RICHNESS = 6, 6
M.R = 150 -- rayon du relevé autour de chaque QG
M.REF = "carte-max-defaut"

local floor = math.floor

--- Noms triés des contrôles d'autoplacement de catégorie « resource ».
function M.resource_controls()
  local names = {}
  for n, p in pairs(game.autoplace_control_prototypes) do
    if p.category == "resource" then names[#names + 1] = n end
  end
  table.sort(names)
  return names
end

--- Noms triés des prototypes d'entité de type « resource ».
function M.resource_entities()
  local names = {}
  for n in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } })) do names[#names + 1] = n end
  table.sort(names)
  return names
end

local function copy_controls(c)
  local out = {}
  for k, v in pairs(c) do out[k] = { frequency = v.frequency, size = v.size, richness = v.richness } end
  return out
end

--- Diagnostic : entités de ressource sur toute la surface et dans un rayon de 150 autour de (0, 0).
local function census(ctx, s, label)
  local parts = {}
  for _, n in ipairs(M.resource_entities()) do
    local all = s.count_entities_filtered({ name = n })
    local near = s.count_entities_filtered({ name = n, position = { 0, 0 }, radius = 150 })
    if all > 0 then parts[#parts + 1] = string.format("%s %d (rayon 150 : %d)", n, all, near) end
  end
  ctx.log(M.TAG .. "recensement " .. label .. " : " .. table.concat(parts, " | "))
end

--- Applique les réglages max à la surface 1 et régénère ses chunks. À appeler AVANT toute génération lointaine.
--- Écrit dans `st` : avant (réglages d'origine, copie), chunks, rayon, controles.
function M.apply(ctx, st)
  local s = ctx.surface()
  local mgs = s.map_gen_settings
  st.seed = mgs.seed
  st.before = copy_controls(mgs.autoplace_controls)
  st.mgs_ref = { seed = mgs.seed, width = mgs.width, height = mgs.height, starting_area = mgs.starting_area,
    peaceful_mode = mgs.peaceful_mode, autoplace_controls = copy_controls(mgs.autoplace_controls) }
  local names = M.resource_controls()
  st.controls = names
  local parts = {}
  for _, n in ipairs(names) do
    local c = mgs.autoplace_controls[n] or { frequency = 1, size = 1, richness = 1 }
    local p = game.autoplace_control_prototypes[n]
    local after = { frequency = c.frequency, size = M.SIZE, richness = p.richness and M.RICHNESS or c.richness }
    mgs.autoplace_controls[n] = after
    parts[#parts + 1] = string.format("%s f%.2f s%.2f r%.2f -> f%.2f s%.2f r%.2f", n, c.frequency, c.size, c.richness,
      after.frequency, after.size, after.richness)
  end
  ctx.log(M.TAG .. "reglages de carte (graine " .. tostring(mgs.seed) .. ") : " .. table.concat(parts, " | "))
  -- Chunks existants (au départ de la création) : effacés puis régénérés au même rayon.
  local list, rmax = {}, 0
  for pos in s.get_chunks() do
    list[#list + 1] = { x = pos.x, y = pos.y }
    rmax = math.max(rmax, math.abs(pos.x), math.abs(pos.y))
  end
  census(ctx, s, "AVANT")
  s.map_gen_settings = mgs
  for _, c in ipairs(list) do s.delete_chunk(c) end
  s.request_to_generate_chunks({ 0, 0 }, rmax + 1)
  s.force_generate_chunk_requests()
  census(ctx, s, "APRES")
  local after = 0
  for _ in s.get_chunks() do after = after + 1 end
  st.chunks_avant, st.chunks_apres, st.rayon = #list, after, rmax
  -- Relecture : les réglages sont bien ceux demandés ?
  local back = s.map_gen_settings.autoplace_controls
  local ok = true
  for _, n in ipairs(names) do
    local c = back[n]
    if not (c and c.size == M.SIZE) then ok = false end
  end
  st.relu_ok = ok
  ctx.log(M.TAG .. string.format("chunks du depart : %d effaces puis regeneres (rayon %d chunks), %d apres ; reglages relus %s",
    #list, rmax, after, tostring(ok)))
  -- Les garanties de monnaies redeviennent « à traiter » (le filet périodique les repose sur le terrain neuf).
  if ctx.has("fo-monde", "forget") then
    local n = 0
    for _, spec in ipairs(ctx.remote("fo-monde", "specs") or {}) do
      if ctx.remote("fo-monde", "forget", spec.key) then n = n + 1 end
    end
    st.forgotten = n
    ctx.log(M.TAG .. "garanties oubliees (reposees par le filet) : " .. n)
  end
end

--- Tuiles de minerai et quantité par entité de ressource dans le rayon R autour de pos.
local function stats(s, pos, names)
  local out = {}
  for _, n in ipairs(names) do
    local ents = s.find_entities_filtered({ name = n, position = pos, radius = M.R })
    local amt = 0
    for _, e in ipairs(ents) do amt = amt + e.amount end
    out[n] = { n = #ents, amt = amt }
  end
  return out
end

local function hq_of(s, force) return s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1] end

--- Positions des QG (votre équipe : coffre d'équipe, sinon point de départ de la force), triées par clé. { { key, x, y }, ... }
--- Les factions se lisent aux QG eux-mêmes (fo-faction-hq, clé = nom de la force sans « fo- ») : les lignes de fo-ia1.teams sont
--- encore vides aux ticks 1500 à 2700 d'une carte neuve (micro-2, diag).
function M.sites(s)
  local out = {}
  local chest = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
  if chest then
    out[#out + 1] = { key = "equipe", x = chest.position.x, y = chest.position.y }
  else
    local sp = game.forces.player.get_spawn_position(s)
    out[#out + 1] = { key = "equipe", x = sp.x, y = sp.y }
  end
  for _, hq in ipairs(s.find_entities_filtered({ name = "fo-faction-hq" })) do
    out[#out + 1] = { key = (hq.force.name:gsub("^fo%-", "")), x = hq.position.x, y = hq.position.y }
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

--- Diagnostic : ce que voient les recherches de QG (coffre, lignes de fo-ia1.teams, QG par force).
function M.diag(ctx, s)
  local rows = remote.call("fo-ia1", "teams") or {}
  local parts = {}
  for _, r in ipairs(rows) do
    parts[#parts + 1] = string.format("%s/%s hq=%d", tostring(r.key), tostring(r.force),
      #s.find_entities_filtered({ name = "fo-faction-hq", force = r.force }))
  end
  ctx.log(M.TAG .. string.format("diag sites : coffres player %d, hq toutes forces %d, lignes teams %d : %s",
    #s.find_entities_filtered({ name = "fo-team-chest", force = "player" }),
    s.count_entities_filtered({ name = "fo-faction-hq" }), #rows, table.concat(parts, " ; ")))
end

--- Relevé max contre référence ; `st.releve` reçoit les totaux. Rend vrai si fait.
function M.releve(ctx, st)
  local s = ctx.surface()
  local sites = M.sites(s)
  if #sites == 0 then M.diag(ctx, s); return false end
  local names = M.resource_entities()
  -- Surface de référence : mêmes graine et réglages que la carte d'origine.
  if game.surfaces[M.REF] then game.delete_surface(M.REF) end
  local ref = game.create_surface(M.REF, st.mgs_ref)
  for _, p in ipairs(sites) do ref.request_to_generate_chunks({ p.x, p.y }, floor(M.R / 32) + 2) end
  ref.force_generate_chunk_requests()
  local tot = { max_n = {}, max_a = {}, ref_n = {}, ref_a = {} }
  for _, p in ipairs(sites) do
    local m, d = stats(s, { p.x, p.y }, names), stats(ref, { p.x, p.y }, names)
    local parts = {}
    for _, n in ipairs(names) do
      if m[n].n > 0 or d[n].n > 0 then
        parts[#parts + 1] = string.format("%s tuiles %d/%d (x%.2f) quantite %d/%d (x%.2f)", n, m[n].n, d[n].n,
          m[n].n / math.max(1, d[n].n), m[n].amt, d[n].amt, m[n].amt / math.max(1, d[n].amt))
      end
      tot.max_n[n] = (tot.max_n[n] or 0) + m[n].n
      tot.ref_n[n] = (tot.ref_n[n] or 0) + d[n].n
      tot.max_a[n] = (tot.max_a[n] or 0) + m[n].amt
      tot.ref_a[n] = (tot.ref_a[n] or 0) + d[n].amt
    end
    ctx.log(M.TAG .. string.format("releve QG %s (%.0f, %.0f) rayon %d, carte max / reference : %s", p.key, p.x, p.y, M.R,
      table.concat(parts, " ; ")))
  end
  game.delete_surface(M.REF)
  st.releve = tot
  return true
end

--- Contrôles (finish). Les 4 minerais de base : au moins `fmin` fois la quantité de la référence, sur l'ensemble des QG.
function M.checks(ctx, st, fmin)
  ctx.check(st.relu_ok == true, "reglages max relus sur nauvis (taille 600 % de toutes les ressources)", tostring(st.relu_ok))
  ctx.check((st.chunks_apres or 0) >= (st.chunks_avant or 1) and (st.chunks_avant or 0) > 0,
    "chunks du depart regeneres", tostring(st.chunks_avant) .. " -> " .. tostring(st.chunks_apres))
  local t = st.releve
  ctx.check(t ~= nil, "releve max / reference fait", tostring(t ~= nil))
  if not t then return end
  for _, n in ipairs({ "iron-ore", "copper-ore", "coal", "stone" }) do
    local f = t.max_a[n] / math.max(1, t.ref_a[n])
    local ft = t.max_n[n] / math.max(1, t.ref_n[n])
    ctx.log(M.TAG .. string.format("TOTAL %s : tuiles %d / %d (x%.2f), quantite %d / %d (x%.2f)", n, t.max_n[n], t.ref_n[n], ft,
      t.max_a[n], t.ref_a[n], f))
    ctx.check(f >= fmin, string.format("%s : quantite autour des QG au moins x%.1f la reference", n, fmin), string.format("x%.2f", f))
  end
end

return M
