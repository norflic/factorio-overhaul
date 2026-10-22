--[[
  Scénario GREFFÉ « t2-defense » (suite « défense dense », 22/10) : MIGRATION D'UNE VRAIE LIGNE DE DÉFENSE en moteur
  réel. Modèle : scenarios/t2-migration.lua ; format : tools/autotest/README.md §4 ; double source : §1.1 du même
  fichier (FO_CREATE_SRC = export de 0.4.2, où seule la mitrailleuse grandit, ou de 0.4.1, où rien ne grandit).

  Pourquoi : les essais précédents ont joué une usine dense (E50) et des défenses ISOLÉES (E46), jamais une vraie
  ligne de défense, celle que le Directeur Créatif bâtit dans ses parties : beaucoup de mitrailleuses et de lasers
  côte à côte derrière un mur continu, un bras par mitrailleuse qui la nourrit depuis un convoyeur de munitions,
  des poteaux entre les tourelles, les lasers sur le réseau.

  Phase « création » (source ancienne) : init() pose, à l'ANCIENNE taille (lue sur le prototype chargé : mitrailleuse
  2×2 en 0.4.1, 3×3 aux niveaux 7 à 12 et 4×4 aux 13 à 18 en 0.4.2 ; laser 2×2 dans les deux), pour la force
  « fo-def » (en guerre avec « enemy ») :
    - un MUR continu de deux rangées (mur de niveau 7) ;
    - trois tronçons de tourelles, alignées par l'ARRIÈRE (contre la rangée des bras, comme un joueur les aligne sur
      son convoyeur) :
        A « compact » : M7 L7 M7 L7 M8 L8 M8 L8, jointives, la plus profonde contre le mur ;
        C « haut niveau » : M13 L13 M25 L25 M13, jointives, la plus profonde contre le mur ;
        B « aéré » : les 8 tourelles de A, une colonne libre avant chacune, une rangée libre devant la plus profonde ;
    - derrière chaque mitrailleuse : un bras (au centre de son arrière) qui prend sur le convoyeur et dépose dans la
      tourelle, et un poteau moyen à côté ; derrière chaque laser : un poteau moyen ; un poteau de liaison entre deux
      tronçons ; une interface électrique vanilla (500 GW) et son poteau à l'ouest : un VRAI réseau de poteaux ;
    - par tronçon, un convoyeur de munitions perforantes, garni à la pose ; pendant le benchmark, sa TÊTE est
      regarnie par script (amont simulé : le convoyeur plein qui vient de l'usine) ; tout le reste (convoyeur, bras,
      tourelle) est le vrai mécanisme du moteur ;
    - mitrailleuses VIDES de munitions (la sauvegarde est écrite au tick 0, sans un seul tick joué : toute munition
      trouvée après la migration est arrivée par le bras et le convoyeur) ; victimes, dégâts et PV entamés posés sur
      chaque tourelle (contenu à conserver).
  Phase « benchmark » (source 0.4.3) :
    - tick ACT : classement de chaque tourelle (REPOSÉE, DÉJÀ EN PLACE, LAISSÉE hors grille ou chevauchante, MÊME
      taille), attentes NOMINATIVES par tronçon et par version de création, chevauchements relevés, compteurs du mod,
      journal attendu (comparé hors jeu : tools/autotest/ht3_journal.py --tag FO-T2-DEFENSE) ; lasers reliés au
      réseau des poteaux et chargés ;
    - tick FEED : chaque mitrailleuse a des munitions, et son bras la vise (dépôt) ;
    - ticks des VAGUES (3) : un biter moyen posé devant chaque tourelle, à portée ;
    - tick CHECK (finish) : chaque tourelle a TIRÉ après la migration (dégâts en hausse), ennemis tués, mitrailleuses
      encore nourries, lasers encore sur le réseau, filet sans effet.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")
local has_foot, Foot = pcall(require, "__factorio-overhaul__/shared/levels/footprint")
if not has_foot then Foot = nil end

local ACT = 90
local FEED = 170
local WAVES = { 200, 380, 560 }
local CHECK = 1100
local X0, Y0, X1, Y1 = 290, 230, 420, 300
local YW = Y0 + 30            -- rangée nord du mur (tuile) ; l'ennemi vient du nord
local F_DEF = "fo-def"
local AMMO = "piercing-rounds-magazine"
local G, LZ, WL = LV.by_key.gun, LV.by_key.laser, LV.by_key.wall
local N, E, S, W = defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west

--- Ce que le moteur passe à on_configuration_changed (voie de la migration), journalisé.
script.on_configuration_changed(function(data)
  local names, parts = {}, {}
  for name in pairs(data.mod_changes or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local c = data.mod_changes[name]
    parts[#parts + 1] = name .. " " .. tostring(c.old_version) .. " -> " .. tostring(c.new_version)
  end
  global.t2d_config = { text = table.concat(parts, ", "), tick = game.tick }
  log("[FO-T2-DEFENSE] on_configuration_changed (tick " .. game.tick .. ") : mod_changes { " .. table.concat(parts, ", ") .. " }")
end)

local function fmt(p) return string.format("%g, %g", p.x, p.y) end

--- Côté (tuiles) d'un prototype, lu sur sa boîte de sélection, arrondi.
local function proto_side(name)
  local b = game.entity_prototypes[name].selection_box
  return math.floor(b.right_bottom.x - b.left_top.x + 0.5)
end

local function box_of(e)
  local bb = e.bounding_box
  return { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
end

local function overlap(a, b)
  local eps = 1e-6
  return a.x0 < b.x1 - eps and b.x0 < a.x1 - eps and a.y0 < b.y1 - eps and b.y0 < a.y1 - eps
end

local SKIP = { character = true, unit = true, ["item-entity"] = true, ["entity-ghost"] = true, resource = true,
  ["flying-text"] = true, corpse = true }

--- Ce qui chevauche la boîte de collision de `e` (couches partagées, test strict des boîtes) : liste triée de
--- noms (« nom@x, y ») et table nom → nombre.
local function overlapping(e)
  local s, b, out, by_name = e.surface, box_of(e), {}, {}
  local mask = e.prototype.collision_mask
  for _, o in ipairs(s.find_entities_filtered({ area = { { b.x0, b.y0 }, { b.x1, b.y1 } } })) do
    if o.valid and o ~= e and not SKIP[o.type] then
      local shared = false
      local layers = {}
      for layer in pairs(o.prototype.collision_mask or {}) do layers[#layers + 1] = layer end
      table.sort(layers)
      for _, layer in ipairs(layers) do if mask[layer] then shared = true break end end
      if shared and overlap(b, box_of(o)) then
        out[#out + 1] = o.name .. "@" .. fmt(o.position)
        by_name[o.name] = (by_name[o.name] or 0) + 1
      end
    end
  end
  table.sort(out)
  return out, by_name
end

--- Contenu qui doit survivre à la migration : victimes, dégâts, PV (les munitions, elles, arrivent par le bras).
local function content(e)
  return string.format("victimes=%d,degats=%.1f,PV=%.3f", e.kills, e.damage_dealt, e.get_health_ratio())
end

local function ammo_of(e)
  local inv = e.valid and e.type == "ammo-turret" and e.get_inventory(defines.inventory.turret_ammo)
  return inv and inv.get_item_count() or 0
end

local function belt_items(list)
  local n = 0
  for _, b in ipairs(list) do
    if b.valid then n = n + b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count() end
  end
  return n
end

--- Tronçons, d'ouest en est. gap : rangées libres entre le mur et la tourelle la plus profonde ; spacing : colonnes
--- libres avant chaque tourelle.
local SECTIONS = {
  { key = "A", gap = 0, spacing = 0, list = { { "gun", 7 }, { "laser", 7 }, { "gun", 7 }, { "laser", 7 }, { "gun", 8 }, { "laser", 8 }, { "gun", 8 }, { "laser", 8 } } },
  { key = "C", gap = 0, spacing = 0, list = { { "gun", 13 }, { "laser", 13 }, { "gun", 25 }, { "laser", 25 }, { "gun", 13 } } },
  { key = "B", gap = 1, spacing = 1, list = { { "gun", 7 }, { "laser", 7 }, { "gun", 7 }, { "laser", 7 }, { "gun", 8 }, { "laser", 8 }, { "gun", 8 }, { "laser", 8 } } },
}
local SECTION_GAP = 5 -- colonnes libres entre deux tronçons (un poteau de liaison au milieu)

--- Attente nominative du classement d'une tourelle (règle de position, shared/levels/footprint.lua), selon que sa
--- taille change (sinon « same ») et sa place dans la ligne. Raisonnement (alignement par l'arrière, la plus profonde
--- contre le mur ; tout agrandissement doit contenir l'ancien carré, donc prendre une rangée devant ou derrière ET une
--- colonne à gauche ou à droite) :
---   A : une tourelle qui grandit est coincée entre ses voisines (colonnes), le mur (devant, si elle est la plus
---       profonde) et la rangée des bras et poteaux (derrière) : LAISSÉE ; sauf le DERNIER laser quand il a une rangée
---       libre devant (création 0.4.2 : lasers 2×2 moins profonds que les mitrailleuses 3×3) : la colonne libre à
---       l'est (entre deux tronçons) le laisse grandir : REPOSÉ ;
---   C : coincées (la dernière tourelle est une mitrailleuse : en 0.4.2 elle ne grandit pas ; en 0.4.1 elle touche le
---       mur et les bras) : LAISSÉES ;
---   B : une colonne libre à gauche de chaque tourelle et une rangée libre devant : toutes REPOSÉES (vers le
---       nord-ouest, la première candidate libre de l'ordre de préférence).
local function expected(section, k, count, grows, side0)
  if not grows then return "same" end
  if section == "B" then return "moved" end
  if section == "A" and k == count and side0 < 3 then
    return "depth" -- résolu à la pose : REPOSÉ si une rangée libre est devant (tourelle moins profonde que le tronçon)
  end
  return "kept"
end

return {
  description = "Suite defense : ligne de defense dense (mur, mitrailleuses et lasers jointifs, bras, convoyeur, poteaux) creee par une source ancienne, migree par 0.4.3, puis attaquee",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.version_create = script.active_mods["factorio-overhaul"]
    st.init_tick = game.tick
    local l7 = proto_side(LV.name(LZ, 7))
    local g7 = proto_side(LV.name(G, 7))
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. " au tick " .. game.tick .. ", laser 7 en " .. l7 .. "x" .. l7
      .. ", mitrailleuse 7 en " .. g7 .. "x" .. g7)
    if l7 ~= 2 then
      ctx.fail("phase de creation avec une source 0.4.1 ou 0.4.2 (laser 7 en 2x2)", "laser 7 deja en " .. l7 .. "x" .. l7 .. " : lancer avec FO_CREATE_SRC")
      st.invalid = true
      return
    end
    ctx.prepare_area(X0, Y0, X1, Y1, "grass-1")
    local foes = 0
    for _, en in ipairs(s.find_entities_filtered({ area = { { X0 - 64, Y0 - 64 }, { X1 + 64, Y1 + 64 } }, force = "enemy" })) do
      if en.valid then en.destroy(); foes = foes + 1 end
    end
    ctx.log("ennemis retires autour de la zone : " .. foes)
    local def = game.forces[F_DEF] or game.create_force(F_DEF)
    def.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire(def, false)

    st.rec, st.belts, st.poles, st.inserters, st.walls = {}, {}, {}, {}, 0
    local refused = {}
    local function make(t)
      -- Table écrite en entier ici (tools/api_lint.py contrôle les champs d'un appel à table littérale).
      local e = s.create_entity({ name = t.name, position = t.position, direction = t.direction, force = def, raise_built = true })
      if not e then refused[#refused + 1] = t.name .. "@" .. fmt({ x = t.position[1], y = t.position[2] }) end
      return e
    end
    local function pole(x, y)
      local p = make({ name = "medium-electric-pole", position = { x, y } })
      if p then st.poles[#st.poles + 1] = p end
      return p
    end

    -- Géométrie : abscisse de départ, puis chaque tronçon à la suite.
    local x = X0 + 16
    local x_first = x
    local belt_x0 = {}
    for si, sec in ipairs(SECTIONS) do
      local depth = 0
      for _, it in ipairs(sec.list) do depth = math.max(depth, proto_side(LV.name(LV.by_key[it[1]], it[2]))) end
      local row_i = YW + 2 + sec.gap + depth -- rangée des bras et des poteaux
      sec.row_i, sec.depth, sec.x_start = row_i, depth, x
      for k, it in ipairs(sec.list) do
        local family = LV.by_key[it[1]]
        local name = LV.name(family, it[2])
        local side = proto_side(name)
        x = x + sec.spacing
        local tx, ty = x, row_i - side
        local cx, cy = tx + side / 2, ty + side / 2
        local e = make({ name = name, position = { cx, cy } })
        if e then
          e.kills = 2 + k
          e.damage_dealt = 100 * k
          e.health = e.prototype.max_health * 0.75
        end
        local back = tx + math.floor((side - 1) / 2) + 0.5 -- colonne centrale de l'arrière
        local ins
        if family.key == "gun" then
          -- Bras : prend au sud (convoyeur), dépose au nord (dans la tourelle) ; poteau à côté.
          ins = make({ name = "inserter", position = { back, row_i + 0.5 }, direction = S })
          if ins then st.inserters[#st.inserters + 1] = ins end
          pole(back + 1, row_i + 0.5)
        else
          pole(back, row_i + 0.5)
        end
        -- L'attente se calcule au tick ACT : la NOUVELLE taille n'est connue que de la source du benchmark.
        if e then
          st.rec[#st.rec + 1] = { key = sec.key .. k .. "-" .. (family.key == "gun" and "M" or "L") .. it[2], section = sec.key, name = e.name,
            family = family.key, x = e.position.x, y = e.position.y, unit = e.unit_number, entity = e, side0 = side,
            content = content(e), force = F_DEF, inserter = ins, k = k, count = #sec.list, depth = depth }
        end
        x = x + side
      end
      sec.x_end = x
      -- Convoyeur de munitions (vers l'est), du bord ouest du tronçon - 1 à son bord est.
      local by = row_i + 1.5
      local list = {}
      for bx = sec.x_start - 1, sec.x_end - 1 do
        local b = make({ name = "transport-belt", position = { bx + 0.5, by }, direction = E })
        if b then list[#list + 1] = b; st.belts[#st.belts + 1] = b end
      end
      -- Garni à la pose (3 par voie et par tuile). L'AMONT (le convoyeur plein qui vient de l'usine du joueur) est
      -- simulé : la tête du convoyeur est regarnie par script toutes les 15 ticks (tick()). Premier essai : un coffre
      -- infini et un bras en tête (0,83 objet/s) ne suffisaient pas à 11 mitrailleuses en combat (5 à sec).
      for _, b in ipairs(list) do
        for lane = 1, 2 do
          local tl = b.get_transport_line(lane)
          for _ = 1, 3 do tl.insert_at_back({ name = AMMO, count = 1 }) end
        end
      end
      st.heads = st.heads or {}
      st.heads[#st.heads + 1] = list[1]
      belt_x0[si] = sec.x_start - 1
      -- Poteau de liaison vers le tronçon suivant (dans la rangée des bras, au milieu de l'intervalle).
      if si < #SECTIONS then pole(sec.x_end + 1.5, row_i + 0.5) end
      x = sec.x_end + SECTION_GAP
    end
    local x_last = x - SECTION_GAP
    -- Source : interface électrique vanilla (500 GW) et son poteau, à l'ouest du premier tronçon.
    local a = SECTIONS[1]
    local eei = make({ name = "electric-energy-interface", position = { a.x_start - 5, a.row_i } })
    if eei then eei.power_production = 1e9; eei.electric_buffer_size = 1e10 end
    st.eei = eei
    pole(a.x_start - 3.5, a.row_i + 0.5)
    -- Raccord explicite des poteaux voisins (le moteur raccorde déjà ceux posés par script : vérifié par le réseau).
    local wires = 0
    for i = 2, #st.poles do
      local p, q = st.poles[i], st.poles[i - 1]
      if p.valid and q.valid then
        local d = math.sqrt((p.position.x - q.position.x) ^ 2 + (p.position.y - q.position.y) ^ 2)
        if d <= 9 and p.connect_neighbour(q) then wires = wires + 1 end
      end
    end
    -- Mur continu : deux rangées de mur de niveau 7, d'un bout à l'autre de la ligne.
    for wx = x_first - 8, x_last + 6 do
      for wy = YW, YW + 1 do
        if make({ name = LV.name(WL, 7), position = { wx + 0.5, wy + 0.5 } }) then st.walls = st.walls + 1 end
      end
    end
    st.line = { x0 = x_first - 8, x1 = x_last + 6 }
    st.belt0_create = belt_items(st.belts)

    local guns, lasers = 0, 0
    for _, r in ipairs(st.rec) do if r.family == "gun" then guns = guns + 1 else lasers = lasers + 1 end end
    ctx.check(#st.rec == 21 and #refused == 0, "phase de creation (" .. tostring(st.version_create) .. ") : ligne de defense posee a l'ancienne taille",
      string.format("%d tourelles (%d mitrailleuses, %d lasers), %d murs, %d bras de tourelle, %d poteaux (%d raccords ajoutes), %d convoyeurs (%d munitions), refus : %s",
        #st.rec, guns, lasers, st.walls, #st.inserters, #st.poles, wires, #st.belts, st.belt0_create, #refused > 0 and table.concat(refused, " ") or "aucun"))
    local fed = 0
    for _, r in ipairs(st.rec) do fed = fed + ammo_of(r.entity) end
    ctx.check(fed == 0, "mitrailleuses vides a la creation (toute munition vue apres la migration vient du bras)", fed .. " munition(s)")
    for _, sec in ipairs(SECTIONS) do
      ctx.log(string.format("troncon %s : x %d a %d, profondeur %d, rangee des bras %d, ecart au mur %d, colonnes libres %d", sec.key, sec.x_start, sec.x_end,
        sec.depth, sec.row_i, sec.gap, sec.spacing))
    end
    for _, r in ipairs(st.rec) do
      ctx.log(string.format("pose %s : %s en %s, n° %d, %dx%d ; %s", r.key, r.name, fmt(r), r.unit, r.side0, r.side0, r.content))
    end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if st.invalid or not st.rec then return end
    local s = ctx.surface()
    if not st.first_tick then
      st.first_tick = e.tick
      local s0 = ctx.call("levels_status", F_DEF)
      st.version_bench = script.active_mods["factorio-overhaul"]
      st.first_stale = s0.footprints_stale
      local cfg = global.t2d_config
      ctx.log(string.format("benchmark : premier tick %d (creation au tick %s), factorio-overhaul %s (creation %s), releve %s, migrated %s, overlap_kept %s ; on_configuration_changed %s",
        e.tick, tostring(st.init_tick), tostring(st.version_bench), tostring(st.version_create),
        s0.footprints_stale == nil and "absent" or (s0.footprints_stale and "PERIME" or "a jour"), tostring(s0.migrated), tostring(s0.overlap_kept),
        cfg and ("APPELE (tick " .. cfg.tick .. ") : " .. cfg.text) or "NON appele"))
    end
    local t = e.tick - st.first_tick
    -- Amont simulé : la tête de chaque convoyeur est regarnie (une munition par voie au plus, s'il y a la place).
    if e.tick % 15 == 0 then
      for _, h in ipairs(st.heads or {}) do
        if h.valid then
          for lane = 1, 2 do
            local tl = h.get_transport_line(lane)
            if tl.can_insert_at_back() then tl.insert_at_back({ name = AMMO, count = 1 }); st.supplied = (st.supplied or 0) + 1 end
          end
        end
      end
    end

    if t == ACT and not st.done_act then
      st.done_act = true
      if not Foot then
        ctx.fail("phase benchmark avec une source 0.4.3 (footprint.lua present)")
        return
      end
      local s1 = ctx.call("levels_status", F_DEF)
      st.s1 = s1
      -- Classement de chaque tourelle.
      local count = { moved = 0, inplace = 0, kept = 0 }
      local by_section, ov_total, offgrid, wrong = {}, {}, 0, {}
      st.final = {}
      for _, r in ipairs(st.rec) do
        local family, n = LV.parse(r.name)
        local side = LV.footprint(family, n)
        r.want = expected(r.section, r.k, r.count, side ~= r.side0, r.side0)
        if r.want == "depth" then r.want = (r.side0 < r.depth) and "moved" or "kept" end
        local old = Foot.tile_box({ x = r.x, y = r.y }, r.side0)
        local fin
        if r.entity.valid then
          fin = r.entity
        else
          for _, c in ipairs(s.find_entities_filtered({ area = { { r.x - 8, r.y - 8 }, { r.x + 8, r.y + 8 } }, name = r.name, force = r.force })) do
            if c.unit_number ~= r.unit and Foot.contains(Foot.tile_box(c.position, side), old) then fin = c end
          end
        end
        if not fin then
          ctx.fail(r.key .. " : tourelle introuvable apres la migration")
        else
          local over, by_name = overlapping(fin)
          local aligned = Foot.aligned(fin.position, side)
          local kind
          if side == r.side0 then kind = "same"
          elseif fin.unit_number ~= r.unit then kind = "moved"
          elseif aligned and #over == 0 then kind = "inplace"
          else kind = "kept" end
          if kind ~= "same" then count[kind] = count[kind] + 1 end
          if not aligned then offgrid = offgrid + 1 end
          for name, c in pairs(by_name) do ov_total[name] = (ov_total[name] or 0) + c end
          by_section[r.section] = by_section[r.section] or {}
          by_section[r.section][kind] = (by_section[r.section][kind] or 0) + 1
          local cnow = content(fin)
          st.final[r.key] = { entity = fin, unit = fin.unit_number, x = fin.position.x, y = fin.position.y, kind = kind, overlaps = #over,
            kills0 = fin.kills, damage0 = fin.damage_dealt }
          local ok_kind = (kind == "moved" and aligned and #over == 0 and Foot.contains(Foot.tile_box(fin.position, side), old))
            or kind == "inplace" or kind == "kept" or (kind == "same" and fin.unit_number == r.unit and fin.position.x == r.x and fin.position.y == r.y)
          if kind ~= r.want then wrong[#wrong + 1] = r.key .. "=" .. kind .. "/" .. r.want end
          ctx.check(ok_kind and cnow == r.content, r.key .. " (" .. r.name .. ", " .. r.side0 .. "x" .. r.side0 .. " -> " .. side .. "x" .. side .. ") : " .. kind
            .. ", victimes, degats et PV conserves" .. (kind == "moved" and ", sur la grille, sans chevauchement" or ""),
            string.format("%s -> %s en %s ; %s ; contenu %s ; chevauche : %s", fmt(r), kind, fmt(fin.position), aligned and "sur la grille" or "HORS grille",
              cnow == r.content and "IDENTIQUE" or ("DIFFERENT (" .. r.content .. " / " .. cnow .. ")"), #over > 0 and table.concat(over, ", ") or "rien"))
        end
      end
      st.count = count
      ctx.check(#wrong == 0, "chaque tourelle reposee, laissee ou inchangee comme la regle le fixe (attentes nominatives par troncon et par version de creation)",
        #wrong > 0 and table.concat(wrong, " ") or (#st.rec .. " tourelles conformes"))
      local secs = {}
      for _, sec in ipairs(SECTIONS) do
        local b = by_section[sec.key] or {}
        secs[#secs + 1] = string.format("%s : %d reposee(s), %d laissee(s), %d deja en place, %d de meme taille", sec.key, b.moved or 0, b.kept or 0, b.inplace or 0, b.same or 0)
      end
      local ovn = {}
      for name in pairs(ov_total) do ovn[#ovn + 1] = name end
      table.sort(ovn)
      for i, name in ipairs(ovn) do ovn[i] = name .. " x" .. ov_total[name] end
      st.summary = string.format("%s ; HORS GRILLE : %d tourelle(s) ; chevauchements (paires vues depuis les tourelles) : %s", table.concat(secs, " | "), offgrid,
        #ovn > 0 and table.concat(ovn, ", ") or "aucun")
      ctx.log("LIGNE DE DEFENSE : " .. st.summary)
      -- Compteurs du mod.
      ctx.check(s1.migrated == count.moved and s1.overlap_kept == count.kept and s1.resized == count.moved,
        string.format("compteurs : %d reposee(s) (migrated, resized), %d laissee(s) (overlap_kept) ; %d deja en place", count.moved, count.kept, count.inplace),
        string.format("migrated %d, overlap_kept %d, resized %d", s1.migrated, s1.overlap_kept, s1.resized))
      ctx.check(s1.spilled == 0 and s1.resize_failed == 0 and s1.forced == 0 and s1.ground_left == 0,
        "rien renverse, aucun echec de remplacement, aucun placement force",
        string.format("spilled %d, resize_failed %d, forced %d, ground_left %d", s1.spilled, s1.resize_failed, s1.forced, s1.ground_left))
      local items = s.count_entities_filtered({ area = { { X0, Y0 }, { X1, Y1 } }, type = "item-entity" })
      ctx.check(items == 0, "aucun objet au sol dans la zone", items .. " objet(s)")
      local walls = s.count_entities_filtered({ area = { { X0, Y0 }, { X1, Y1 } }, name = LV.name(WL, 7), force = F_DEF })
      ctx.check(walls == st.walls, "mur continu intact (aucun mur retire par la migration)", walls .. "/" .. st.walls)
      -- Lasers sur le réseau des POTEAUX (même réseau que l'interface), tampon chargé.
      local net = st.eei and st.eei.valid and st.eei.electric_network_id
      local bad = {}
      for _, r in ipairs(st.rec) do
        local f = st.final[r.key]
        if f and r.family == "laser" then
          local en = f.entity
          if not (en.valid and en.is_connected_to_electric_network() and en.electric_network_id == net and en.energy > 0) then
            bad[#bad + 1] = string.format("%s(%s, reseau %s, %.0f J)", r.key, f.kind, tostring(en.valid and en.electric_network_id), en.valid and en.energy or -1)
          end
        end
      end
      ctx.check(net ~= nil and #bad == 0, "lasers relies au reseau des poteaux (celui de l'interface) et charges, laisses et reposes compris",
        #bad > 0 and table.concat(bad, ", ") or ("10 lasers, reseau " .. tostring(net)))
      -- Journal attendu (comparé hors jeu).
      for _, r in ipairs(st.rec) do
        local f = st.final[r.key]
        if f and f.kind == "kept" then ctx.log("JOURNAL ATTENDU : laisse " .. r.name .. " en " .. tostring(r.x) .. ", " .. tostring(r.y)) end
      end
      ctx.log(string.format("JOURNAL ATTENDU : bilan %d %d %d voie %s", count.moved, count.inplace, count.kept, st.first_stale and "filet" or "repair"))
      if count.kept > 0 then ctx.log(string.format("JOURNAL ATTENDU : message %s %d 0", F_DEF, count.kept)) end
      ctx.check(s1.stacked == 0, "aucun doublon superpose herite dans cette carte (Levels.find_stacked)", "stacked " .. tostring(s1.stacked))
      st.belt_act = belt_items(st.belts)
    end

    if t == FEED and st.final and not st.done_feed then
      st.done_feed = true
      -- Munitions arrivées APRÈS la migration (mitrailleuses vides à la sauvegarde, écrite au tick 0) : par le bras.
      local bad, txt = {}, {}
      for _, r in ipairs(st.rec) do
        local f = st.final[r.key]
        if f and r.family == "gun" then
          local g = f.entity
          local a = ammo_of(g)
          local i = r.inserter
          local aimed = i and i.valid and i.drop_target and i.drop_target.valid and i.drop_target.unit_number == g.unit_number
          if not (g.valid and a > 0 and aimed) then bad[#bad + 1] = r.key .. "(" .. f.kind .. ", " .. a .. ", bras " .. (aimed and "vise" or "NE VISE PAS") .. ")" end
          txt[#txt + 1] = r.key .. "(" .. f.kind .. ")=" .. a
        end
      end
      st.feed_txt = table.concat(txt, " ")
      ctx.check(#bad == 0, "chaque mitrailleuse nourrie APRES la migration par son bras depuis le convoyeur (reposees et laissees comprises), le bras vise la tourelle",
        (#bad > 0 and ("en defaut : " .. table.concat(bad, ", ") .. " ; ") or "") .. st.feed_txt)
    end

    for wi, wt in ipairs(WAVES) do
      if t == wt and st.final then
        st.waves = st.waves or {}
        if not st.waves[wi] then
          -- Vague : un ennemi devant chaque tourelle, à 9 tuiles au nord du mur (à portée de toutes : mitrailleuse
          -- 18 tuiles et plus, laser 24 et plus, depuis le centre).
          local made = 0
          -- Premier essai : une 3e vague de grands biters (375 PV) n'était pas finie 340 ticks plus tard (20 vivants).
          local unit = "medium-biter"
          for _, r in ipairs(st.rec) do
            local f = st.final[r.key]
            if f then
              if s.create_entity({ name = unit, position = { f.x, YW - 9 + 0.5 }, force = "enemy" }) then made = made + 1 end
            end
          end
          st.waves[wi] = made
          st.spawned = (st.spawned or 0) + made
          local alive = s.count_entities_filtered({ area = { { X0 - 40, Y0 - 40 }, { X1 + 40, Y1 + 40 } }, force = "enemy", type = "unit" })
          ctx.log(string.format("vague %d (tick %d) : %d %s poses devant la ligne ; ennemis vivants dans la zone : %d", wi, e.tick, made, unit, alive))
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if st.invalid or not st.final then
      ctx.fail("controles de la ligne de defense joues", st.invalid and "carte invalide" or "tick ACT non atteint")
      return
    end
    -- Lot V3-T3 (correction, défaut 13 ; JOURNAL SEULEMENT, hors bilan) : « libérer la place » en plan seul (rien n'est
    -- posé) sur chaque bâtiment laissé par la migration : combien deviennent libérables sans rien démonter à la main ?
    if ctx.has("factorio-overhaul", "levels_free_room") then
      local n, ok, parts = 0, 0, {}
      for _, r in ipairs(st.rec) do
        local f = st.final[r.key]
        if f and f.kind == "kept" and f.entity.valid then
          n = n + 1
          local d = ctx.call("levels_free_room", f.entity, nil, { dry = true })
          if d.ok then ok = ok + 1 end
          local sig = {}
          for i, x in ipairs(d.signalled or {}) do if i <= 3 then sig[#sig + 1] = tostring(x.name) .. "(" .. tostring(x.why) .. ")" end end
          parts[#parts + 1] = r.key .. "=" .. tostring(d.reason) .. (d.ok and ("[" .. #d.marks .. "m," .. #d.ghosts .. "f]") or ("{" .. table.concat(sig, ",") .. "}"))
        end
      end
      ctx.log(string.format("LIBERER LA PLACE (plan seul, hors bilan) : %d liberable(s) sur %d laisse(s) : %s", ok, n, table.concat(parts, " ")))
    end
    local s = ctx.surface()
    -- Filet sans effet une fois le relevé à jour.
    local s2 = ctx.call("levels_status", F_DEF)
    local moved = {}
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if f and not (f.entity.valid and f.entity.unit_number == f.unit and f.entity.position.x == f.x and f.entity.position.y == f.y) then
        moved[#moved + 1] = r.key
      end
    end
    ctx.check(#moved == 0 and s2.migrated == st.s1.migrated and s2.overlap_kept == st.s1.overlap_kept and s2.resized == st.s1.resized
      and s2.footprints_stale == false,
      "filet sans effet une fois le releve a jour (jusqu'au tick " .. CHECK .. ") : memes tourelles, memes positions, compteurs inchanges",
      #moved > 0 and ("bouge ou detruite : " .. table.concat(moved, ", ")) or string.format("migrated %d, overlap_kept %d", s2.migrated, s2.overlap_kept))
    -- TIR réel après la migration : chaque tourelle a fait des dégâts.
    local silent, txt, kills, dmg = {}, {}, 0, 0
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if f and f.entity.valid then
        local dk, dd = f.entity.kills - f.kills0, f.entity.damage_dealt - f.damage0
        kills, dmg = kills + dk, dmg + dd
        if dd <= 0 then silent[#silent + 1] = r.key .. "(" .. f.kind .. ")" end
        txt[#txt + 1] = string.format("%s(%s)=%.0f/%d", r.key, f.kind, dd, dk)
      elseif f then
        silent[#silent + 1] = r.key .. "(DETRUITE)"
      end
    end
    ctx.log("TIR apres migration (degats/victimes par tourelle) : " .. table.concat(txt, " "))
    ctx.check(#silent == 0, "chaque tourelle a TIRE apres la migration (degats en hausse), laissees hors grille et reposees comprises",
      (#silent > 0 and ("muettes : " .. table.concat(silent, ", ") .. " ; ") or "") .. string.format("%d tourelles, degats %.0f, victimes %d", #st.rec, dmg, kills))
    local alive = s.count_entities_filtered({ area = { { X0 - 40, Y0 - 40 }, { X1 + 40, Y1 + 40 } }, force = "enemy", type = "unit" })
    ctx.check((st.spawned or 0) > 0 and alive == 0 and kills >= (st.spawned or 0),
      "ennemis poses a portee apres la migration : tous tues par la ligne", string.format("%d poses en %d vagues, %d tues (victimes des tourelles), %d encore vivants",
        st.spawned or 0, #(st.waves or {}), kills, alive))
    -- Mitrailleuses encore nourries après le combat ; convoyeurs consommés et regarnis.
    local dry = {}
    local atxt = {}
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if f and r.family == "gun" then
        local a = ammo_of(f.entity)
        if a <= 0 then dry[#dry + 1] = r.key end
        atxt[#atxt + 1] = r.key .. "=" .. a
      end
    end
    ctx.check(#dry == 0, "mitrailleuses encore nourries apres le combat", (#dry > 0 and ("a sec : " .. table.concat(dry, ", ") .. " ; ") or "") .. table.concat(atxt, " "))
    local lost = {}
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if f and r.family == "laser" and not (f.entity.valid and f.entity.is_connected_to_electric_network() and f.entity.energy > 0) then lost[#lost + 1] = r.key end
    end
    ctx.check(#lost == 0, "lasers encore sur le reseau et charges apres le combat", #lost > 0 and table.concat(lost, ", ") or "10 lasers")
    local walls = s.count_entities_filtered({ area = { { X0, Y0 }, { X1, Y1 } }, name = LV.name(WL, 7), force = F_DEF })
    ctx.log(string.format("convoyeurs : %d munitions a la creation, %d au tick ACT, %d au tick CHECK, %d ajoutees en tete (amont simule) ; murs debout %d/%d",
      st.belt0_create, st.belt_act or -1, belt_items(st.belts), st.supplied or 0, walls, st.walls))
    ctx.log("LIGNE DE DEFENSE (rappel) : " .. tostring(st.summary))
    ctx.log(string.format("versions : creation %s, benchmark %s", tostring(st.version_create), tostring(st.version_bench)))
  end,

  shots = function(ctx, add)
    add("defense-ouest", X0 + 34, YW + 2, 1.0, 0)
    add("defense-est", X0 + 78, YW + 2, 1.0, 0)
  end,
  shots_delay = 100,
}
