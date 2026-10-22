--[[
  Scénario GREFFÉ « ht3-migration » (suite H-T3, 22/10) : MIGRATION D'UNE VRAIE SAUVEGARDE 0.4.1 en moteur réel.
  Format : tools/autotest/README.md §4 ; mode d'emploi du double passage : §1.1 du même fichier.

  Hypothèse H-T3 (RD_LOG) : une sauvegarde faite avec 0.4.1 (toutes les mitrailleuses de niveau en 2×2) et
  rechargée avec 0.4.2 (emprise croissante, lot V3-T) migre correctement : par on_configuration_changed quand la
  version monte, par le filet on_nth_tick(30) (Levels.footprints_stale) quand elle ne monte pas.

  Le banc exige DEUX sources du mod (fo-autotest.bat, variable FO_CREATE_SRC) :
  - phase « création » (--create, on_init seulement) avec la source ANCIENNE : init() pose les bâtiments à
    l'ancienne taille, relève tout (positions, numéros, PV, munitions case par case) dans l'état du greffon
    (global du mod de test, donc DANS la sauvegarde) ;
  - phase « benchmark » (--benchmark sur la même carte) avec la source NOUVELLE : tick() contrôle au tick ACT
    (après le filet du tick 30 au plus tard), puis finish() (tick 600) vérifie qu'un second passage n'a rien
    changé.
  Lancée avec une seule source récente, init() le voit (prototype du niveau 7 déjà en 3×3) et échoue : banc
  sans objet.

  Bâtiments posés en 0.4.1 (force « fo-ht3 », mitrailleuses 2×2 à une position entière) :
    libre7   niveau 7 (→ 3×3), place libre                    : reposée à la candidate 1 (nord-ouest)
    libre19  niveau 19 (→ 5×5), endommagée (40 %), munitions perforantes dont une entamée : reposée, candidate 1
    pair13   niveau 13 (→ 4×4, côté pair : déjà sur la grille), 60 %, uranium : même entité, rien à faire
    pair30   niveau 30 (→ 6×6, côté pair), 75 %, munitions : même entité, rien à faire
    coince7  niveau 7, anneau de murs (et un coffre) tout autour : LAISSÉE en place, comptée, journalisée
    eau25    niveau 25 (→ 6×6), anneau d'eau tout autour : LAISSÉE en place
    duoA/B   deux niveau 7 collées (bord à bord) : les deux finissent sans chevauchement
    voisin8  niveau 8 collé à une niveau 6 (bas6, qui ne doit pas bouger) : reposée sans chevaucher bas6
    bas3     niveau 3 seule (2×2 inchangé) : même entité, même position, mêmes PV et munitions
  et un centre de commandement 15 (emprise inchangée) : toujours suivi après la migration.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")
-- Absent de 0.4.1 (phase de création) : require protégé, au chargement (F24).
local has_foot, Foot = pcall(require, "__factorio-overhaul__/shared/levels/footprint")
if not has_foot then Foot = nil end

local FORCE = "fo-ht3"
local G = LV.by_key.gun
local X0, Y0, X1, Y1 = 300, 240, 400, 300
local ACT = 90
local CHECK = 600

local function status() return remote.call("factorio-overhaul", "levels_status", FORCE) end

--- Ce que le moteur passe à on_configuration_changed au chargement de la carte (voie suivie par la migration).
--- Le gestionnaire est enregistré au chargement de CE fichier (F24), donc seulement quand ce scénario est actif ;
--- le mod de test n'en enregistre aucun autre (control.lua). L'événement est appelé pour tous les mods dès qu'un
--- seul change : on y lit les changements de factorio-overhaul. Rien d'autre n'est fait ici.
script.on_configuration_changed(function(data)
  local names, parts = {}, {}
  for name in pairs(data.mod_changes or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local c = data.mod_changes[name]
    parts[#parts + 1] = name .. " " .. tostring(c.old_version) .. " -> " .. tostring(c.new_version)
  end
  local text = string.format("mod_changes { %s } ; mod_startup_settings_changed %s ; migration_applied %s ; jeu %s -> %s",
    table.concat(parts, ", "), tostring(data.mod_startup_settings_changed), tostring(data.migration_applied),
    tostring(data.old_version), tostring(data.new_version))
  global.ht3_config = { text = text, tick = game.tick, overhaul = data.mod_changes and data.mod_changes["factorio-overhaul"] ~= nil }
  log("[FO-HT3-MIGRATION] on_configuration_changed (tick " .. game.tick .. ") : " .. text)
end)

local function test_force()
  local f = game.forces[FORCE] or game.create_force(FORCE)
  for _, other in ipairs({ "player", "enemy" }) do
    f.set_cease_fire(other, true)
    game.forces[other].set_cease_fire(f, true)
  end
  return f
end

--- Côté de la boîte de sélection d'un prototype (tuiles).
local function proto_side(name)
  local p = game.entity_prototypes[name]
  if not p then return nil end
  local b = p.selection_box
  return b.right_bottom.x - b.left_top.x
end

--- Munitions case par case : { "nom:nombre:balles", … } (balles = coups restants du chargeur du dessus).
local function ammo_list(e)
  local out = {}
  local inv = e.get_inventory(defines.inventory.turret_ammo)
  if not inv then return out end
  for k = 1, #inv do
    local s = inv[k]
    if s.valid_for_read then out[#out + 1] = s.name .. ":" .. s.count .. ":" .. tostring(s.ammo) end
  end
  return out
end

local function same_list(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function box_of(e)
  local bb = e.bounding_box
  return { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
end

local function overlap(a, b)
  local eps = 1e-6
  return a.x0 < b.x1 - eps and b.x0 < a.x1 - eps and a.y0 < b.y1 - eps and b.y0 < a.y1 - eps
end

local function fmt_pos(p) return string.format("%g, %g", p.x, p.y) end

--- Ce qui chevauche la boîte de collision de `e` (find_entities_filtered sur la boîte, puis test strict des
--- boîtes ; les types qui ne bloquent jamais un bâtiment sont ignorés, comme Levels.NON_BLOCKING).
local SKIP = { character = true, unit = true, ["item-entity"] = true, ["entity-ghost"] = true, resource = true,
  ["flying-text"] = true, corpse = true }
local function overlapping(e)
  local s, b, out = e.surface, box_of(e), {}
  local mask = e.prototype.collision_mask
  for _, o in ipairs(s.find_entities_filtered({ area = { { b.x0, b.y0 }, { b.x1, b.y1 } } })) do
    if o.valid and o ~= e and not SKIP[o.type] then
      local shared = false
      for layer in pairs(o.prototype.collision_mask or {}) do if mask[layer] then shared = true break end end
      local ob = box_of(o)
      if shared and overlap(b, ob) then
        out[#out + 1] = string.format("%s@%s [%.4f..%.4f x %.4f..%.4f]", o.name, fmt_pos(o.position), ob.x0, ob.x1, ob.y0, ob.y1)
      end
    end
  end
  table.sort(out)
  return out
end

--- Cas posés en phase de création : clé, niveau, position (centre 2×2, entier), attendu, réglages.
local CASES = {
  { key = "libre7", n = 7, x = X0 + 10, y = Y0 + 10, expect = "moved", ammo = { "firearm-magazine", 10 } },
  { key = "libre19", n = 19, x = X0 + 30, y = Y0 + 10, expect = "moved", health = 0.4,
    ammo = { "piercing-rounds-magazine", 37 }, partial = 4 },
  { key = "pair13", n = 13, x = X0 + 50, y = Y0 + 10, expect = "inplace", health = 0.6, ammo = { "uranium-rounds-magazine", 12 } },
  { key = "pair30", n = 30, x = X0 + 70, y = Y0 + 10, expect = "inplace", health = 0.75, ammo = { "firearm-magazine", 50 } },
  { key = "coince7", n = 7, x = X0 + 10, y = Y0 + 35, expect = "kept", ammo = { "firearm-magazine", 6 }, ring = "wall" },
  { key = "eau25", n = 25, x = X0 + 30, y = Y0 + 35, expect = "kept", health = 0.5, ammo = { "piercing-rounds-magazine", 9 }, ring = "water" },
  { key = "duoA", n = 7, x = X0 + 50, y = Y0 + 35, expect = "moved", ammo = { "firearm-magazine", 3 } },
  { key = "duoB", n = 7, x = X0 + 52, y = Y0 + 35, expect = "moved", ammo = { "firearm-magazine", 4 } },
  { key = "bas6", n = 6, x = X0 + 70, y = Y0 + 35, expect = "same", ammo = { "firearm-magazine", 2 } },
  { key = "voisin8", n = 8, x = X0 + 72, y = Y0 + 35, expect = "moved", ammo = { "firearm-magazine", 8 } },
  { key = "bas3", n = 3, x = X0 + 90, y = Y0 + 10, expect = "same", health = 0.9, ammo = { "firearm-magazine", 5 } },
}

--- Anneau d'une tuile autour du carré 2×2 centré en (x, y) (tuiles x - 2 .. x + 1) : coins nord-ouest des tuiles.
local function ring_tiles(x, y)
  local out = {}
  for ty = y - 2, y + 1 do
    for tx = x - 2, x + 1 do
      if tx == x - 2 or tx == x + 1 or ty == y - 2 or ty == y + 1 then out[#out + 1] = { x = tx, y = ty } end
    end
  end
  return out
end

--- Phase benchmark : l'entité finale d'un cas = la mitrailleuse du même nom dont le carré (côté de son prototype,
--- autour de sa position) CONTIENT l'ancien carré 2×2 (la règle de position : le nouveau contient l'ancien).
local function find_final(s, rec)
  local side = proto_side(rec.name)
  local old = Foot.tile_box({ x = rec.x, y = rec.y }, 2)
  local found = {}
  for _, e in ipairs(s.find_entities_filtered({ area = { { rec.x - 8, rec.y - 8 }, { rec.x + 8, rec.y + 8 } }, name = rec.name, force = FORCE })) do
    if Foot.contains(Foot.tile_box(e.position, side), old) then found[#found + 1] = e end
  end
  return found, side
end

return {
  description = "H-T3 : sauvegarde creee par une source ancienne (0.4.1), migree par la source nouvelle",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.version_create = script.active_mods["factorio-overhaul"]
    local side7 = proto_side(LV.name(G, 7))
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", mitrailleuse 7 en "
      .. tostring(side7) .. "x" .. tostring(side7) .. (Foot and " (footprint.lua present)" or " (footprint.lua absent)"))
    if side7 ~= 2 then
      ctx.fail("phase de creation avec une source ANCIENNE (mitrailleuse 7 en 2x2)",
        "mitrailleuse 7 deja en " .. tostring(side7) .. "x" .. tostring(side7) .. " : lancer avec FO_CREATE_SRC = source 0.4.1 (README §1.1)")
      st.invalid = true
      return
    end
    local f = test_force()
    ctx.prepare_area(X0, Y0, X1, Y1, "grass-1")
    local cc = s.create_entity({ name = LV.name(LV.by_key.command, 15), position = { X0 + 90, Y0 + 40 }, force = f, raise_built = true })
    st.cc_unit = cc and cc.unit_number
    st.rec = {}
    local made = 0
    for _, c in ipairs(CASES) do
      local name = LV.name(G, c.n)
      local e = s.create_entity({ name = name, position = { c.x, c.y }, force = f })
      if e then
        made = made + 1
        if c.ammo then e.insert({ name = c.ammo[1], count = c.ammo[2] }) end
        if c.partial then
          local inv = e.get_inventory(defines.inventory.turret_ammo)
          if inv[1].valid_for_read then inv[1].ammo = c.partial end
        end
        if c.health then e.health = e.prototype.max_health * c.health end
        if c.ring == "wall" then
          for i, t in ipairs(ring_tiles(c.x, c.y)) do
            -- Un coffre parmi les murs (« mur ou coffre ») : le 5e de l'anneau (ouest).
            s.create_entity({ name = i == 5 and "iron-chest" or "stone-wall", position = { t.x + 0.5, t.y + 0.5 }, force = f })
          end
        elseif c.ring == "water" then
          local tiles = {}
          for _, t in ipairs(ring_tiles(c.x, c.y)) do tiles[#tiles + 1] = { name = "water", position = { t.x, t.y } } end
          s.set_tiles(tiles)
        end
        st.rec[c.key] = { key = c.key, n = c.n, name = name, x = e.position.x, y = e.position.y, unit = e.unit_number,
          entity = e, ratio = e.get_health_ratio(), ammo = ammo_list(e), expect = c.expect }
        ctx.log(string.format("pose %s : %s en %s, %s, PV %.2f, munitions %s", c.key, name, fmt_pos(e.position),
          "n° " .. e.unit_number, e.get_health_ratio(), table.concat(st.rec[c.key].ammo, " ")))
      end
    end
    ctx.check(made == #CASES and cc ~= nil and status().cc_level == 15,
      "phase de creation (" .. tostring(st.version_create) .. ") : " .. made .. "/" .. #CASES .. " mitrailleuses 2x2 et centre 15 poses",
      "murs, coffre et eau autour de coince7 et eau25")
    local blocked = 0
    for _, c in ipairs(CASES) do
      if c.ring then
        local r = st.rec[c.key]
        if r and r.entity.valid then blocked = blocked + 1 end
      end
    end
    ctx.check(blocked == 2, "anneaux poses sans detruire les mitrailleuses coincees", blocked .. "/2")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if st.invalid or not st.rec then return end
    if not st.first_tick then
      -- Premier tick de la phase benchmark : version chargée, état du relevé, compteurs (la voie
      -- on_configuration_changed a déjà migré ici ; la voie du filet migre au premier tick multiple de 30).
      st.first_tick = e.tick
      local s0 = status()
      st.version_bench = script.active_mods["factorio-overhaul"]
      st.first = { stale = s0.footprints_stale, migrated = s0.migrated, kept = s0.overlap_kept }
      local seen = {}
      for _, c in ipairs(CASES) do
        local r = st.rec[c.key]
        if r and r.entity and r.entity.valid then
          local b = box_of(r.entity)
          seen[#seen + 1] = string.format("%s n°%d en %s boite %.2f..%.2f", c.key, r.unit, fmt_pos(r.entity.position), b.x0, b.x1)
        end
      end
      -- tostring : une source de benchmark ANCIENNE (expérience de contrôle) n'a ni relevé ni ces compteurs.
      local stale = s0.footprints_stale == nil and "absent (source sans emprise croissante)" or (s0.footprints_stale and "PERIME" or "a jour")
      ctx.log(string.format("benchmark : premier tick %d, factorio-overhaul %s (creation %s), releve %s, migrated %s, overlap_kept %s",
        e.tick, tostring(st.version_bench), tostring(st.version_create), stale, tostring(s0.migrated), tostring(s0.overlap_kept)))
      ctx.log("entites d'origine encore valides au premier tick : " .. (#seen > 0 and table.concat(seen, " ; ") or "aucune"))
      -- Voie suivie : la ligne « [FO-LEVELS] mise à jour des emprises » (Levels.repair, on_configuration_changed)
      -- ou « [FO-LEVELS] emprises (filet, sans changement de version) » du journal fait foi ; ceci la complète.
      local cfg = global.ht3_config
      ctx.log("on_configuration_changed au chargement : " .. (cfg and ("APPELE (tick " .. cfg.tick .. ") : " .. cfg.text) or "NON appele"))
    end
    if e.tick ~= st.first_tick + ACT or st.done then return end
    st.done = true
    if not Foot then
      ctx.fail("phase benchmark avec une source NOUVELLE (shared/levels/footprint.lua present)", tostring(st.version_bench))
      return
    end
    local s = ctx.surface()
    local s1 = status()
    st.s1 = s1

    -- Relevé de la sauvegarde écrit et égal à la table du mod chargé.
    local fp = s1.footprints and s1.footprints.gun
    local bad = {}
    for n = 1, G.max do
      if not (fp and fp[n] == LV.footprint(G, n)) then bad[#bad + 1] = n .. ":" .. tostring(fp and fp[n]) end
    end
    ctx.check(s1.footprints_stale == false and #bad == 0,
      "releve global.fo.levels.footprints ecrit et egal a la table (30 niveaux de la mitrailleuse)",
      #bad > 0 and table.concat(bad, " ") or ("2x2 -> 6x6 ; premier tick : releve " .. (st.first.stale and "PERIME (voie du filet)" or "deja a jour")))

    -- Cas un par un.
    local moved, inplace, kept = 0, 0, 0
    st.final = {}
    for _, c in ipairs(CASES) do
      local r = st.rec[c.key]
      local found, side = find_final(s, r)
      local want_side = LV.footprint(G, r.n)
      local fin = found[1]
      if #found ~= 1 then
        ctx.fail(c.key .. " : une seule mitrailleuse finale contient l'ancien carre", #found .. " trouvee(s)")
      else
        st.final[c.key] = { entity = fin, unit = fin.unit_number, x = fin.position.x, y = fin.position.y }
        local same = fin.unit_number == r.unit
        local ammo = ammo_list(fin)
        local ratio = fin.get_health_ratio()
        local detail = string.format("%s n°%d -> n°%d en %s, %dx%d, PV %.3f -> %.3f, munitions %s", fmt_pos({ x = r.x, y = r.y }),
          r.unit, fin.unit_number, fmt_pos(fin.position), side, side, r.ratio, ratio, table.concat(ammo, " "))
        local common = side == want_side and same_list(ammo, r.ammo) and math.abs(ratio - r.ratio) < 0.005
        if c.expect == "moved" then
          moved = moved + 1
          local aligned = Foot.aligned(fin.position, side)
          local ok = common and not same and aligned
          if c.key == "libre7" or c.key == "libre19" then
            local want = Foot.candidates(Foot.tile_box({ x = r.x, y = r.y }, 2), side)[1]
            ok = ok and math.abs(fin.position.x - want.x) < 1e-6 and math.abs(fin.position.y - want.y) < 1e-6
            detail = detail .. " ; candidate 1 attendue en " .. fmt_pos(want)
          end
          ctx.check(ok, c.key .. " (niveau " .. r.n .. ", 2x2 -> " .. side .. "x" .. side .. ") : reposee sur la grille, contient l'ancien carre, munitions case par case et PV en proportion conserves", detail)
        elseif c.expect == "inplace" then
          inplace = inplace + 1
          ctx.check(common and same and fin.position.x == r.x and fin.position.y == r.y,
            c.key .. " (niveau " .. r.n .. ", cote pair " .. side .. ") : meme entite, meme position (deja sur la grille), PV et munitions intacts", detail)
        elseif c.expect == "kept" then
          kept = kept + 1
          local over = overlapping(fin)
          -- Tuiles d'eau sous la boîte (anneau d'eau) : comptées comme chevauchement.
          local b = box_of(fin)
          local water = s.count_tiles_filtered({ area = { { b.x0, b.y0 }, { b.x1, b.y1 } }, collision_mask = "water-tile" })
          if water > 0 then over[#over + 1] = water .. " tuile(s) d'eau" end
          -- Le chevauchement n'est PAS exigé : la boîte de collision (côté − 0,6) d'un 3×3 resté sur un coin de tuile
          -- peut tenir entre les murs de l'anneau ; il est relevé pour le journal (toléré s'il existe).
          ctx.check(common and same and fin.position.x == r.x and fin.position.y == r.y,
            c.key .. " (niveau " .. r.n .. ", aucune place) : LAISSEE en place, en service, contenu intact (chevauchement tolere)",
            detail .. string.format(" ; boite %.4f..%.4f x %.4f..%.4f", b.x0, b.x1, b.y0, b.y1)
              .. " ; chevauche : " .. (#over > 0 and table.concat(over, ", ") or "rien"))
        else
          ctx.check(common and same and side == 2 and fin.position.x == r.x and fin.position.y == r.y,
            c.key .. " (niveau " .. r.n .. ", 2x2 inchange) : n'a pas bouge (meme entite, PV, munitions)", detail)
        end
      end
    end

    -- Aucun chevauchement, sauf les deux laissées faute de place.
    local overs = {}
    for _, c in ipairs(CASES) do
      local f = st.final[c.key]
      if f and c.expect ~= "kept" and f.entity.valid then
        local o = overlapping(f.entity)
        if #o > 0 then overs[#overs + 1] = c.key .. " : " .. table.concat(o, ", ") end
      end
    end
    ctx.check(#overs == 0, "aucun chevauchement (find_entities_filtered sur la boite de chaque mitrailleuse non laissee)",
      #overs > 0 and table.concat(overs, " | ") or (#CASES - 2) .. " boites controlees")
    local da, db = st.final.duoA, st.final.duoB
    ctx.check(da and db and da.entity.valid and db.entity.valid and not overlap(box_of(da.entity), box_of(db.entity)),
      "duo colle : les deux finissent sans se chevaucher",
      da and db and (fmt_pos(da.entity.position) .. " et " .. fmt_pos(db.entity.position)) or "introuvable")

    -- Compteurs du mod (stats.migrated, overlap_kept) et absence d'effet de bord.
    ctx.check(s1.migrated == moved and s1.overlap_kept == kept and s1.resized == moved,
      "compteurs : " .. moved .. " reposee(s) (migrated, resized), " .. kept .. " laissee(s) (overlap_kept) ; " .. inplace .. " deja en place",
      string.format("migrated %d, overlap_kept %d, resized %d", s1.migrated, s1.overlap_kept, s1.resized))
    ctx.check(s1.spilled == 0 and s1.resize_failed == 0 and s1.forced == 0 and s1.ground_left == 0 and s1.fallback == 0,
      "rien renverse, aucun echec de remplacement, aucun placement force",
      string.format("spilled %d, resize_failed %d, forced %d, ground_left %d", s1.spilled, s1.resize_failed, s1.forced, s1.ground_left))
    local items = s.count_entities_filtered({ area = { { X0, Y0 }, { X1, Y1 } }, type = "item-entity" })
    ctx.check(items == 0, "aucun objet au sol dans la zone", items .. " objet(s)")
    ctx.check(s1.cc_level == 15, "centre de commandement 15 toujours suivi", "cc_level " .. tostring(s1.cc_level))
  end,

  finish = function(ctx)
    local st = ctx.state()
    if st.invalid or not st.final then
      ctx.fail("controles de migration joues", st.invalid and "carte invalide" or "tick " .. tostring(st.first_tick) .. "+" .. ACT .. " non atteint")
      return
    end
    -- Second passage : le filet a tourné 17 fois de plus (tick 30 à 600) ; rien ne doit avoir bougé.
    local s2 = status()
    local moved = {}
    for _, c in ipairs(CASES) do
      local f = st.final[c.key]
      if f and not (f.entity.valid and f.entity.unit_number == f.unit and f.entity.position.x == f.x and f.entity.position.y == f.y) then
        moved[#moved + 1] = c.key
      end
    end
    ctx.check(#moved == 0 and s2.migrated == st.s1.migrated and s2.overlap_kept == st.s1.overlap_kept and s2.resized == st.s1.resized
      and s2.footprints_stale == false,
      "second passage sans effet (filet on_nth_tick(30) jusqu'au tick " .. CHECK .. ") : memes entites, memes positions, compteurs inchanges",
      #moved > 0 and ("bouge : " .. table.concat(moved, ", ")) or string.format("migrated %d, overlap_kept %d", s2.migrated, s2.overlap_kept))
    ctx.log(string.format("versions : creation %s, benchmark %s", tostring(st.version_create), tostring(st.version_bench)))
  end,
}
