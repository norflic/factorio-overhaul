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
    (après le filet du tick 30 au plus tard), puis finish() (tick 600) vérifie que le filet est resté sans
    effet une fois le relevé à jour (garde footprints_stale faux : migrate_footprints n'est PAS rejoué ; un vrai
    rechargement d'une carte déjà migrée n'est pas joué par ce banc).
  Lancée avec une seule source récente, init() le voit (prototype du niveau 7 déjà en 3×3) et échoue : banc
  sans objet.

  Journal (correction du correcteur H-T3, défaut 1) : le mod de test ne lit pas le journal du moteur. Le
  scénario écrit donc ce que le journal DOIT contenir (lignes « JOURNAL ATTENDU ») et
  tools/autotest/ht3_journal.py le compare, hors jeu, aux lignes [FO-LEVELS] de benchmark.log (une ligne
  « laissé en place » par bâtiment laissé, une seule ligne de bilan, de la voie attendue). Critère du passage :
  BILAN du scénario sans échec ET ht3_journal.py à 0.

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
  Défense type (correction du correcteur H-T3, défaut 4) : force « player », posée avec raise_built (comme à la
  main), derrière une ligne de murs ouverte, nourrie par un bras à combustible (burner-inserter, au sud, qui
  dépose vers le nord) :
    defense7 niveau 7, murs une tuile devant (une rangée libre), bras nourri par un CONVOYEUR : reposée à la
             candidate 1 (nord-ouest), sans chevaucher murs ni bras ; le bras vise la NOUVELLE tourelle
             (drop_target) et la nourrit encore (munitions en hausse entre le tick ACT et le tick 600) ;
    rempart7 niveau 7, murs COLLÉS devant, bras nourri par un COFFRE : aucune candidate libre (murs au nord,
             bras au sud) : LAISSÉE en place, journalisée ; le bras la nourrit encore.
  Les ennemis à moins de 48 tuiles de la zone sont retirés à la création (les tourelles « player » ne tirent
  pas : munitions comparables).
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
  -- Défense type (force « player », raise_built) : wall = rangée des murs (dy depuis la position), feed = source
  -- du bras (convoyeur ou coffre) ; 2 chargeurs au départ (le bras complète jusqu'à automated_ammo_count = 10).
  { key = "defense7", n = 7, x = X0 + 10, y = Y0 + 52, expect = "moved", force = "player", ammo = { "firearm-magazine", 2 },
    wall = -3, feed = "belt" },
  { key = "rempart7", n = 7, x = X0 + 30, y = Y0 + 52, expect = "kept", force = "player", ammo = { "firearm-magazine", 2 },
    wall = -2, feed = "chest" },
}

--- Nombre total de munitions (chargeurs) d'une liste « nom:nombre:balles » et noms différents de `want`.
local function ammo_total(list, want)
  local n, other = 0, {}
  for _, s in ipairs(list) do
    local name, count = s:match("^(.-):(%d+):")
    n = n + (tonumber(count) or 0)
    if name ~= want then other[#other + 1] = s end
  end
  return n, other
end

--- Défense type autour de la mitrailleuse 2×2 centrée en (x, y) (tuiles x - 1 .. x, y - 1 .. y) : ligne de murs
--- de 10 tuiles à la rangée y + c.wall, bras à combustible en tuile (x - 1, y + 1) qui prend au sud (tuile
--- (x - 1, y + 2) : convoyeur ou coffre) et dépose au nord, dans la tourelle (1.1 : un bras « regarde » sa prise,
--- direction sud). Renvoie le bras et sa source.
local function build_defense(s, c, force)
  local walls = 0
  for tx = c.x - 5, c.x + 4 do
    if s.create_entity({ name = "stone-wall", position = { tx + 0.5, c.y + c.wall + 0.5 }, force = force, raise_built = true }) then
      walls = walls + 1
    end
  end
  local ins = s.create_entity({ name = "burner-inserter", position = { c.x - 0.5, c.y + 1.5 },
    direction = defines.direction.south, force = force, raise_built = true })
  if ins then ins.get_fuel_inventory().insert({ name = "coal", count = 20 }) end
  local src, fed = nil, 0
  if c.feed == "belt" then
    src = s.create_entity({ name = "transport-belt", position = { c.x - 0.5, c.y + 2.5 },
      direction = defines.direction.east, force = force, raise_built = true })
    if src then
      for line = 1, 2 do
        local tl = src.get_transport_line(line)
        for _ = 1, 4 do
          if tl.insert_at_back({ name = c.ammo[1], count = 1 }) then fed = fed + 1 end
        end
      end
    end
  else
    src = s.create_entity({ name = "iron-chest", position = { c.x - 0.5, c.y + 2.5 }, force = force, raise_built = true })
    if src then fed = src.insert({ name = c.ammo[1], count = 20 }) end
  end
  return ins, src, walls, fed
end

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
  for _, e in ipairs(s.find_entities_filtered({ area = { { rec.x - 8, rec.y - 8 }, { rec.x + 8, rec.y + 8 } }, name = rec.name, force = rec.force or FORCE })) do
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
    -- Défense type en force « player » : aucun ennemi à portée (munitions comparables d'un tick à l'autre).
    local foes = 0
    for _, en in ipairs(s.find_entities_filtered({ area = { { X0 - 48, Y0 - 48 }, { X1 + 48, Y1 + 48 } }, force = "enemy" })) do
      if en.valid then en.destroy(); foes = foes + 1 end
    end
    ctx.log("ennemis retires autour de la zone : " .. foes)
    local cc = s.create_entity({ name = LV.name(LV.by_key.command, 15), position = { X0 + 90, Y0 + 40 }, force = f, raise_built = true })
    st.cc_unit = cc and cc.unit_number
    st.rec = {}
    local made = 0
    for _, c in ipairs(CASES) do
      local name = LV.name(G, c.n)
      local cf = c.force and game.forces[c.force] or f
      local e = s.create_entity({ name = name, position = { c.x, c.y }, force = cf, raise_built = c.force ~= nil })
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
          entity = e, ratio = e.get_health_ratio(), ammo = ammo_list(e), expect = c.expect, force = c.force }
        ctx.log(string.format("pose %s : %s en %s, %s, PV %.2f, munitions %s", c.key, name, fmt_pos(e.position),
          "n° " .. e.unit_number, e.get_health_ratio(), table.concat(st.rec[c.key].ammo, " ")))
        if c.feed then
          local ins, src, walls, fed = build_defense(s, c, cf)
          local r = st.rec[c.key]
          r.inserter, r.feed = ins, src
          r.ammo_count = ammo_total(r.ammo, c.ammo[1])
          ctx.log(string.format("defense %s (force %s) : %d murs en rangee %d, bras %s (prise %s, depot %s), %s avec %d chargeur(s)",
            c.key, cf.name, walls, c.y + c.wall, ins and ("n° " .. ins.unit_number) or "ABSENT",
            ins and fmt_pos(ins.pickup_position) or "-", ins and fmt_pos(ins.drop_position) or "-",
            src and src.name or "source ABSENTE", fed))
          ctx.check(ins ~= nil and src ~= nil and walls == 10 and fed > 0 and e.valid,
            c.key .. " : defense type posee (10 murs, bras a combustible, " .. c.feed .. " garni)",
            string.format("murs %d, bras %s, source %s, %d chargeur(s)", walls, tostring(ins ~= nil), tostring(src ~= nil), fed))
        end
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
        if c.feed then
          -- Défense nourrie : le bras a pu ajouter des chargeurs depuis le chargement ; munitions conservées =
          -- même type seulement, et au moins autant qu'à la sauvegarde.
          local total, other = ammo_total(ammo, c.ammo[1])
          common = side == want_side and #other == 0 and total >= r.ammo_count and math.abs(ratio - r.ratio) < 0.005
          detail = detail .. string.format(" ; chargeurs %d -> %d (bras)", r.ammo_count, total)
        end
        if c.expect == "moved" then
          moved = moved + 1
          local aligned = Foot.aligned(fin.position, side)
          local ok = common and not same and aligned
          if c.key == "libre7" or c.key == "libre19" or c.key == "defense7" then
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

    -- Défense type : le bras vise la mitrailleuse FINALE (reposée ou laissée) et prend toujours à sa source.
    for _, c in ipairs(CASES) do
      local r, f = st.rec[c.key], st.final[c.key]
      if c.feed and f then
        local ins = r.inserter
        local dt = ins and ins.valid and ins.drop_target
        local pt = ins and ins.valid and ins.pickup_target
        f.ammo_act = ammo_total(ammo_list(f.entity), c.ammo[1])
        ctx.check(dt ~= nil and dt == f.entity and pt ~= nil and r.feed and r.feed.valid and pt == r.feed,
          c.key .. " : le bras vise la mitrailleuse finale (drop_target) et prend a sa source (pickup_target)",
          string.format("depot %s -> %s n°%s ; prise %s ; %d chargeur(s) au tick %d",
            ins and ins.valid and fmt_pos(ins.drop_position) or "-", dt and dt.name or "rien", dt and tostring(dt.unit_number) or "-",
            pt and pt.name or "rien", f.ammo_act, e.tick))
      end
    end

    -- Aucun chevauchement, sauf les mitrailleuses laissées faute de place.
    local overs = {}
    for _, c in ipairs(CASES) do
      local f = st.final[c.key]
      if f and c.expect ~= "kept" and f.entity.valid then
        local o = overlapping(f.entity)
        if #o > 0 then overs[#overs + 1] = c.key .. " : " .. table.concat(o, ", ") end
      end
    end
    ctx.check(#overs == 0, "aucun chevauchement (find_entities_filtered sur la boite de chaque mitrailleuse non laissee)",
      #overs > 0 and table.concat(overs, " | ") or (#CASES - kept) .. " boites controlees")
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

    -- Ce que le journal du moteur DOIT contenir (comparé hors jeu par tools/autotest/ht3_journal.py) : une ligne
    -- « [FO-LEVELS] emprise : <nom> en <x>, <y> laissé en place » par mitrailleuse laissée, et UNE ligne de
    -- bilan de la voie suivie (relevé déjà à jour au premier tick : on_configuration_changed → Levels.repair ;
    -- relevé périmé : le filet on_nth_tick(30)). Positions au format du mod (tostring d'un nombre).
    for _, c in ipairs(CASES) do
      local r = st.rec[c.key]
      if c.expect == "kept" then
        ctx.log("JOURNAL ATTENDU : laisse " .. r.name .. " en " .. tostring(r.x) .. ", " .. tostring(r.y))
      end
    end
    ctx.log(string.format("JOURNAL ATTENDU : bilan %d %d %d voie %s", moved, inplace, kept, st.first.stale and "filet" or "repair"))
  end,

  finish = function(ctx)
    local st = ctx.state()
    if st.invalid or not st.final then
      ctx.fail("controles de migration joues", st.invalid and "carte invalide" or "tick " .. tostring(st.first_tick) .. "+" .. ACT .. " non atteint")
      return
    end
    -- Filet sans effet une fois le relevé à jour : il a tourné encore 17 fois (tick 30 à 600) et son garde
    -- (footprints_stale) est resté faux, donc migrate_footprints n'a PAS été rejoué ; rien ne doit avoir bougé.
    -- Ce n'est pas une seconde migration d'une carte déjà migrée (rechargement réel : non joué par ce banc).
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
      "filet sans effet une fois le releve a jour (garde footprints_stale faux jusqu'au tick " .. CHECK .. ") : memes entites, memes positions, compteurs inchanges",
      #moved > 0 and ("bouge : " .. table.concat(moved, ", ")) or string.format("migrated %d, overlap_kept %d", s2.migrated, s2.overlap_kept))
    -- Défense type : le bras a continué de nourrir la mitrailleuse finale après la migration (tick ACT → CHECK).
    for _, c in ipairs(CASES) do
      local r, f = st.rec[c.key], st.final[c.key]
      if c.feed and f and f.ammo_act then
        local now = f.entity.valid and ammo_total(ammo_list(f.entity), c.ammo[1]) or -1
        local ins = r.inserter
        ctx.check(now > f.ammo_act and ins and ins.valid and ins.drop_target == f.entity,
          c.key .. " : le bras nourrit encore la mitrailleuse finale (chargeurs en hausse du tick " .. (st.first_tick + ACT) .. " au tick " .. CHECK .. ")",
          string.format("%d -> %d chargeur(s)", f.ammo_act, now))
      end
    end
    ctx.log(string.format("versions : creation %s, benchmark %s", tostring(st.version_create), tostring(st.version_bench)))
  end,
}
