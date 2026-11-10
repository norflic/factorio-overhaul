--[[
  Lot POLISSAGE-2 (10/11) : banc hors jeu des bâtiments refaits par le kit tools/render/pieces/batiments (F469 et F476). Lua 5.2,
  racine du mod :
      lua5.2 tests/batiments_test.lua
  prototypes/batiments_visuels.lua est exécuté sur un data.raw de banc (les champs de jeu des huit bâtiments, copiés de leurs
  prototypes) avec les VRAIES feuilles (graphics/batiments/sprites.lua) :
    §1 feuilles (D-6) : chaque bâtiment a ses couches, ses PNG aux dimensions annoncées (bande de lueur pulsée : largeur × PULSE),
       cités par MANIFEST.json ; ancrage « emetteur » au-dessus du pied pour chaque tourelle ;
    §2 gameplay inchangé : hors des champs d'image, chaque prototype est identique à l'octet après habillage (emprise, collision,
       sélection, santé, énergie, catégories, fluides, portée, dégâts) ; l'attaque ne change que l'origine du faisceau ;
    §3 tourelles : socle = corps + ombre ; chaque état de tête = lueur + lumière, UNE direction, bande complète sauf l'état replié
       (première image) ; intensité croissante replié < préparation < prêt < tir ; faisceau parti de l'émetteur (une direction) ;
       tir à projectile non déplacé ; icône neuve + chiffres d'âge gardés ;
    §4 pulsation (feuilles.py) : PULSE triangulaire (monte puis descend), dans ]0, 1], maximum 1 ;
    §5 mutants de prototypes/batiments_visuels.lua et de la table PULSE : chacun refusé ;
    §6 lot POLISSAGE-3 (10/11) : les quatre tourelles à MUNITIONS (Bastion I, tourelle lourde, canon, mortier) : bandes de la tête
       tournante (4 bandes × 16 directions × images, PNG aux dimensions, MANIFEST), 64 directions sur CHAQUE couche de tête, une image
       au repos (première colonne) et les images du tir, socle corps + ombre + lueur, intensité croissante, origine des projectiles
       lue du modèle (bouche), le reste du gameplay identique à l'octet (rotation, déploiement, portée, munitions, douilles) ; mutants ;
    §7 lot VISUELS-DISTINCTS (10/11) : marques des quatre tourelles à munitions (socle, liseré de fonction, motif de toit) distinctes deux
       à deux et PROUVÉES sur les feuilles (teinte de lueur mesurée, IoU des silhouettes de socle) ; mutants.
]]

package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[BATIMENTS] ECHEC : " .. msg) end
end

local function read(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function png_size(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local h = f:read(24)
  f:close()
  if not h or #h < 24 or h:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
  local function u32(s, i) local a, b, c, d = s:byte(i, i + 3); return ((a * 256 + b) * 256 + c) * 256 + d end
  return u32(h, 17), u32(h, 21)
end

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deepcopy(v) end
  return c
end

local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

---------------------------------------------------------------------------------------------------
-- §1 feuilles
---------------------------------------------------------------------------------------------------
local TOURELLES = { bastion2 = "fo-bastion-2", bastion3 = "fo-bastion-3", bastion4 = "fo-bastion-4", tesla = "fo-tesla-turret",
  laser_lourd = "fo-heavy-laser-turret" }
local ORDRE = { "coffre", "pylone", "cuve", "bastion2", "bastion3", "bastion4", "tesla", "laser_lourd" }

local function pulse_de(src)
  local t = src and src:match("\nPULSE = %(([^)]*)%)")
  if not t then return nil end
  local v = {}
  for x in t:gmatch("[%d%.]+") do v[#v + 1] = tonumber(x) end
  return v
end
local FEUILLES = read("tools/render/pieces/batiments/feuilles.py")
local PULSE = pulse_de(FEUILLES) or {}

local okb, BAT = pcall(dofile, "graphics/batiments/sprites.lua")
check(okb and type(BAT) == "table", "§1 graphics/batiments/sprites.lua lisible (sinon : py -3.9 tools/render/pieces/batiments/feuilles.py)")
BAT = okb and BAT or {}
local man = read("graphics/batiments/MANIFEST.json") or ""
for _, cle in ipairs(ORDRE) do
  local u = BAT[cle]
  check(u and u.main and u.shadow and u.glow and u.icone and u.boite, "§1 " .. cle .. " : couches, icône, boîte")
  local kinds = { "main", "shadow", "glow" }
  if TOURELLES[cle] then kinds[#kinds + 1] = "pulse" end
  for _, k in ipairs(kinds) do
    for _, res in ipairs({ "lr", "hr" }) do
      local d = u and u[k] and u[k][res]
      local pth = d and d.filename:gsub("^__factorio%-overhaul__/", "")
      local w, h
      if pth then w, h = png_size(pth) end
      local largeur = d and (k == "pulse" and d.width * d.frame_count or d.width)
      check(d and w == largeur and h == d.height, "§1 " .. cle .. " " .. k .. " " .. res .. " : PNG présent aux dimensions de sprites.lua")
      check(pth and man:find(pth:match("([^/]+)$"), 1, true) ~= nil, "§1 MANIFEST cite " .. tostring(pth))
      if k == "pulse" and d then
        check(d.frame_count == #PULSE and d.line_length == #PULSE, "§1 " .. cle .. " : bande de " .. #PULSE .. " images (PULSE)")
      end
    end
  end
  if TOURELLES[cle] then
    local em = u and u.ancrages and u.ancrages.emetteur
    check(em and em.fil[1] == 0 and em.fil[2] < -0.5 and em.fil[2] > -3, "§1 " .. cle .. " : émetteur au-dessus du pied (0,5 à 3 tuiles)")
  end
end

---------------------------------------------------------------------------------------------------
-- §1 bis (POLISSAGE-3) : bandes des têtes tournantes
---------------------------------------------------------------------------------------------------
local MUNITIONS = { bastion1 = "fo-bastion-1", lourde = "fo-heavy-gun-turret", canon = "fo-cannon-turret", mortier = "fo-mortar-turret" }
local ORDRE_MUN = { "bastion1", "lourde", "canon", "mortier" }
local IMAGES_TIR = { bastion1 = 2, lourde = 2, canon = 1, mortier = 1 }
for _, cle in ipairs(ORDRE_MUN) do
  local u = BAT[cle]
  check(u and u.main and u.shadow and u.glow and u.icone and u.boite and u.tete, "§1 bis " .. cle .. " : socle (corps, ombre, lueur), tête, icône, boîte")
  check(u and u.directions == 64 and u.rangs and u.rangs * 4 == 64 and u.images == IMAGES_TIR[cle],
    "§1 bis " .. cle .. " : 64 directions en 4 bandes, " .. IMAGES_TIR[cle] .. " image(s) de tir")
  local b = u and u.bouche
  check(b and b.distance > 0.4 and b.distance < 3 and b.centre[1] == 0 and b.centre[2] < -0.1 and b.centre[2] > -2,
    "§1 bis " .. cle .. " : bouche du modèle (distance 0,4 à 3 tuiles, centre au-dessus du pied)")
  for _, k in ipairs({ "main", "shadow", "glow" }) do
    for _, res in ipairs({ "lr", "hr" }) do
      local d = u and u.tete and u.tete[k] and u.tete[k][res]
      check(d and #d.stripes == 4, "§1 bis " .. cle .. " tête " .. k .. " " .. res .. " : 4 bandes")
      for _, f in ipairs(d and d.stripes or {}) do
        local pth = f:gsub("^__factorio%-overhaul__/", "")
        local w, h = png_size(pth)
        check(w == d.width * u.images and h == d.height * u.rangs, "§1 bis " .. pth .. " : " .. u.images .. " × " .. u.rangs .. " images")
        check(man:find(pth:match("([^/]+)$"), 1, true) ~= nil, "§1 bis MANIFEST cite " .. pth)
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- data.raw de banc : champs de jeu des huit bâtiments (forme des prototypes livrés), images d'avant = marqueurs
---------------------------------------------------------------------------------------------------
local function tete_vanilla() return { layers = { { filename = "__base__/x.png", width = 10, height = 10, direction_count = 64 } } } end
local function tourelle(name, ap)
  return { type = "electric-turret", name = name, max_health = 1500, collision_box = { { -0.7, -0.7 }, { 0.7, 0.7 } },
    selection_box = { { -1, -1 }, { 1, 1 } }, minable = { mining_time = 0.5, result = name }, flags = { "placeable-player", "player-creation" },
    energy_source = { type = "electric", buffer_capacity = "801kJ", input_flow_limit = "9600kW", drain = "24kW", usage_priority = "primary-input" },
    rotation_speed = 0.01, preparing_speed = 0.05, folding_speed = 0.05, glow_light_intensity = 0.5, call_for_help_radius = 40,
    base_picture = tete_vanilla(), folded_animation = tete_vanilla(), preparing_animation = tete_vanilla(),
    prepared_animation = tete_vanilla(), folding_animation = tete_vanilla(), energy_glow_animation = tete_vanilla(),
    water_reflection = { pictures = {} },
    icons = { { icon = "__base__/graphics/icons/laser-turret.png", icon_size = 64, icon_mipmaps = 4, tint = { r = 0.7, g = 0.9, b = 1 } },
      { icon = "__base__/graphics/icons/signal/signal_2.png", icon_size = 64, icon_mipmaps = 4, scale = 0.2, shift = { -10, -10 } } },
    attack_parameters = ap }
end
local function beam_ap(beam)
  return { type = "beam", cooldown = 40, range = 28, damage_modifier = 2, source_direction_count = 64, source_offset = { 0, -0.85587225 },
    ammo_type = { category = "laser", energy_consumption = "800kJ",
      action = { type = "direct", action_delivery = { type = "beam", beam = beam, max_length = 30, duration = 40, source_offset = { 0, -1.31439 } } } } }
end
local function banc()
  local raw = { container = {}, ["electric-pole"] = {}, ["assembling-machine"] = {}, ["electric-turret"] = {}, item = {} }
  raw.container["fo-team-chest"] = { type = "container", name = "fo-team-chest", inventory_size = 48, max_health = 350,
    collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } }, selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }, picture = tete_vanilla(),
    icon = "__base__/graphics/icons/steel-chest.png", icon_size = 64 }
  raw["electric-pole"]["fo-ht-pylon"] = { type = "electric-pole", name = "fo-ht-pylon", maximum_wire_distance = 64, supply_area_distance = 2,
    collision_box = { { -0.65, -0.65 }, { 0.65, 0.65 } }, selection_box = { { -1, -1 }, { 1, 1 } }, pictures = tete_vanilla(),
    connection_points = { { wire = { copper = { 0, -3 } }, shadow = { copper = { 2, 0 } } } }, icon = "__base__/x.png", icon_size = 64 }
  raw["assembling-machine"]["fo-reduction-cell"] = { type = "assembling-machine", name = "fo-reduction-cell", crafting_speed = 1,
    crafting_categories = { "fo-electrolysis" }, energy_usage = "6MW", energy_source = { type = "electric", usage_priority = "secondary-input" },
    fluid_boxes = { { production_type = "input", pipe_connections = { { type = "input", position = { 0, -2.5 } } } } },
    collision_box = { { -1.7, -1.7 }, { 1.7, 1.7 } }, selection_box = { { -2, -2 }, { 2, 2 } }, animation = tete_vanilla(),
    shadow = {}, integration_patch = {}, icon = "__base__/x.png", icon_size = 64 }
  for cle, name in pairs(TOURELLES) do
    local ap = cle == "bastion4" and { type = "projectile", cooldown = 90, range = 40, source_direction_count = 0, source_offset = { 0, 0 },
      ammo_type = { category = "laser", action = { type = "direct", action_delivery = { type = "projectile", projectile = "orb", starting_speed = 0.4 } } } }
      or beam_ap(name .. "-beam")
    local t = tourelle(name, ap)
    if cle == "laser_lourd" then t.collision_box, t.selection_box = { { -1.2, -1.2 }, { 1.2, 1.2 } }, { { -1.5, -1.5 }, { 1.5, 1.5 } } end
    raw["electric-turret"][name] = t
    raw.item[name] = { type = "item", name = name, icons = deepcopy(t.icons), stack_size = 50 }
  end
  -- POLISSAGE-3 : tourelles à munitions (forme livrée : --dump-final ammo-turret/<nom>)
  raw["ammo-turret"] = {}
  local D = {
    bastion1 = { hp = 700, c = 0.7, s = 1, rot = 0.015, prep = 0.08, ap = { ammo_category = "bullet", cooldown = 5, range = 20,
      projectile_creation_distance = 1.39375, projectile_center = { 0, -0.0875 }, shell = true },
      icons = { "__base__/graphics/icons/gun-turret.png", "__base__/graphics/icons/signal/signal_1.png" } },
    lourde = { hp = 2000, c = 1.2, s = 1.5, rot = 0.015, prep = 0.08, ap = { ammo_category = "bullet", cooldown = 4, range = 24,
      projectile_creation_distance = 2.090625, projectile_center = { 0, -0.13125 }, shell = true }, icon = "__base__/graphics/icons/gun-turret.png" },
    canon = { hp = 2200, c = 1.2, s = 1.5, rot = 0.006, prep = 0.05, ap = { ammo_category = "cannon-shell", cooldown = 75, range = 32, min_range = 5,
      projectile_creation_distance = 1.9, projectile_center = { 0, -0.9 }, turn_range = 1 },
      icons = { "__base__/graphics/icons/gun-turret.png", "__base__/graphics/icons/tank.png" } },
    mortier = { hp = 1600, c = 1.2, s = 1.5, rot = 0.004, prep = 0.04, prepare_range = 50, ap = { ammo_category = "fo-mortar", cooldown = 120, range = 46,
      min_range = 14, projectile_creation_distance = 1.6, projectile_center = { 0, -0.6 }, turn_range = 1 },
      icons = { "__base__/graphics/icons/artillery-turret.png", "__base__/graphics/icons/explosive-cannon-shell.png" } },
  }
  for cle, name in pairs(MUNITIONS) do
    local d = D[cle]
    local ap = { type = "projectile", ammo_category = d.ap.ammo_category, cooldown = d.ap.cooldown, range = d.ap.range, min_range = d.ap.min_range,
      projectile_creation_distance = d.ap.projectile_creation_distance, projectile_center = d.ap.projectile_center, turn_range = d.ap.turn_range,
      sound = { variations = { { filename = "__base__/sound/fight/heavy-gunshot-1.ogg", volume = 0.6 } } } }
    if d.ap.shell then
      ap.shell_particle = { name = "shell-particle", direction_deviation = 0.1, speed = 0.1, speed_deviation = 0.03, center = { -0.0625, 0 },
        creation_distance = -1.925, starting_frame_speed = 0.2, starting_frame_speed_deviation = 0.1 }
    end
    local t = { type = "ammo-turret", name = name, max_health = d.hp, collision_box = { { -d.c, -d.c }, { d.c, d.c } },
      selection_box = { { -d.s, -d.s }, { d.s, d.s } }, minable = { mining_time = 0.5, result = name }, flags = { "placeable-player", "player-creation" },
      inventory_size = 2, automated_ammo_count = 10, rotation_speed = d.rot, preparing_speed = d.prep, folding_speed = d.prep,
      prepare_range = d.prepare_range, call_for_help_radius = 40, alert_when_attacking = true,
      base_picture = tete_vanilla(), folded_animation = tete_vanilla(), preparing_animation = tete_vanilla(), prepared_animation = tete_vanilla(),
      attacking_animation = tete_vanilla(), folding_animation = tete_vanilla(), water_reflection = { pictures = {} }, attack_parameters = ap }
    if d.icons then
      t.icons = { { icon = d.icons[1], icon_size = 64, icon_mipmaps = 4, tint = { r = 0.8, g = 0.8, b = 0.9 } },
        { icon = d.icons[2], icon_size = 64, icon_mipmaps = 4, scale = 0.3125, shift = { 8, 8 } } }
    else
      t.icon, t.icon_size, t.icon_mipmaps = d.icon, 64, 4
    end
    raw["ammo-turret"][name] = t
    raw.item[name] = { type = "item", name = name, icons = deepcopy(t.icons), icon = t.icon, icon_size = t.icon_size, stack_size = 50 }
  end
  -- MURS-ACIDE : pulvérisateur d'acide (forme livrée : copie du lance-flammes vanilla par prototypes/arsenal_special.lua)
  raw["fluid-turret"] = {}
  local function quatre() return { north = tete_vanilla(), east = tete_vanilla(), south = tete_vanilla(), west = tete_vanilla() } end
  local fa = { type = "fluid-turret", name = "fo-acid-sprayer", max_health = 1500, collision_box = { { -0.7, -1.2 }, { 0.7, 1.2 } },
    selection_box = { { -1, -1.5 }, { 1, 1.5 } }, minable = { mining_time = 0.5, result = "fo-acid-sprayer" },
    flags = { "placeable-player", "player-creation" }, turret_base_has_direction = true, rotation_speed = 0.015, preparing_speed = 0.08,
    folding_speed = 0.08, attacking_speed = 1, ending_attack_speed = 0.2, resistances = { { type = "acid", percent = 100 } },
    fluid_box = { production_type = "input-output", secondary_draw_order = 0, render_layer = "lower-object", base_area = 1,
      pipe_connections = { { position = { -1.5, 1.0 } }, { position = { 1.5, 1.0 } } } },
    fluid_buffer_size = 100, fluid_buffer_input_flow = 250 / 60 / 5, activation_buffer_ratio = 0.25,
    base_picture = quatre(), folded_animation = quatre(), preparing_animation = quatre(), prepared_animation = quatre(),
    attacking_animation = quatre(), ending_attack_animation = quatre(), folding_animation = quatre(),
    gun_animation_render_layer = "object", base_picture_render_layer = "lower-object-above-shadow", water_reflection = { pictures = {} },
    icons = { { icon = "__base__/graphics/icons/flamethrower-turret.png", icon_size = 64, icon_mipmaps = 4 },
      { icon = "__base__/graphics/icons/fluid/sulfuric-acid.png", icon_size = 64, icon_mipmaps = 4, scale = 0.3125, shift = { 8, 8 } } },
    attack_parameters = { type = "stream", cooldown = 4, range = 26, min_range = 4, turn_range = 1 / 3, fire_penalty = 15,
      fluids = { { type = "sulfuric-acid" } }, fluid_consumption = 0.25,
      gun_center_shift = { north = { 0, -1.5063 }, east = { 0.5781, -1.0219 }, south = { 0, -0.725 }, west = { -0.375, -1.1469 } },
      gun_barrel_length = 0.4,
      ammo_type = { category = "fo-acid", action = { type = "direct", action_delivery = { type = "stream", stream = "fo-acid-spray-stream",
        source_offset = { 0.15, -0.5 } } } } } }
  raw["fluid-turret"]["fo-acid-sprayer"] = fa
  raw.item["fo-acid-sprayer"] = { type = "item", name = "fo-acid-sprayer", icons = deepcopy(fa.icons), stack_size = 50 }
  return raw
end

local SOURCE = read("prototypes/batiments_visuels.lua")
check(SOURCE ~= nil, "prototypes/batiments_visuels.lua lisible")

--- Exécute un texte de batiments_visuels.lua sur un banc neuf ; rend raw (habillé), avant (copie d'avant), err.
local function habille(src)
  local raw = banc()
  local avant = deepcopy(raw)
  local env = setmetatable({ data = { raw = raw }, log = function() end }, { __index = _G })
  package.loaded["prototypes.lib"] = nil
  package.loaded["__factorio-overhaul__/graphics/batiments/sprites"] = BAT
  local chunk, err = load(src, "=batiments_visuels", "t", env)
  if not chunk then return nil, nil, err end
  local ok, e2 = pcall(chunk)
  if not ok then return nil, nil, e2 end
  return raw, avant
end

---------------------------------------------------------------------------------------------------
-- §2 gameplay inchangé ; §3 tourelles
---------------------------------------------------------------------------------------------------
local IMAGES = { picture = true, pictures = true, animation = true, idle_animation = true, working_visualisations = true, shadow = true,
  integration_patch = true, map_color = true, friendly_map_color = true, drawing_box = true, water_reflection = true, icon = true,
  icons = true, icon_size = true, icon_mipmaps = true, connection_points = true, base_picture = true, folded_animation = true,
  preparing_animation = true, folding_animation = true, prepared_animation = true, attacking_animation = true,
  energy_glow_animation = true, attack_parameters = true, ending_attack_animation = true }
local ETATS = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation" }

local function sans_origine(ap)
  local c = deepcopy(ap)
  c.source_offset, c.source_direction_count = nil, nil
  c.projectile_center, c.projectile_creation_distance = nil, nil   -- POLISSAGE-3 : origine des projectiles (exacte : §6)
  c.gun_center_shift, c.gun_barrel_length = nil, nil               -- MURS-ACIDE : origine du jet (exacte : §8)
  local d = c.ammo_type and c.ammo_type.action and c.ammo_type.action.action_delivery
  if d then d.source_offset = nil end
  return c
end

--- Contrôles §2 et §3 sur un banc habillé ; rend la liste des motifs de refus (vide = conforme).
local function juge(raw, avant)
  local m = {}
  local function non(c, s) if not c then m[#m + 1] = s end end
  if not raw then return { "habillage en erreur" } end
  for ty, ents in pairs(avant) do
    for name, e0 in pairs(ents) do
      local e1 = raw[ty][name]
      for k, v in pairs(e0) do
        if not IMAGES[k] then non(same(v, e1[k]), name .. " : champ de jeu " .. k .. " changé") end
      end
      for k in pairs(e1) do
        if not IMAGES[k] and e0[k] == nil then non(false, name .. " : champ de jeu " .. k .. " ajouté") end
      end
      if e0.attack_parameters then
        non(same(sans_origine(e0.attack_parameters), sans_origine(e1.attack_parameters)), name .. " : attaque changée hors de son origine")
      end
    end
  end
  for cle, name in pairs(TOURELLES) do
    local e, e0, u = raw["electric-turret"][name], avant["electric-turret"][name], BAT[cle]
    local bp = e.base_picture and e.base_picture.layers
    non(bp and #bp == 2 and bp[1].filename == u.main.lr.filename and bp[2].draw_as_shadow, name .. " : socle = corps + ombre")
    local ks = {}
    for i, f in ipairs(ETATS) do
      local L = e[f] and e[f].layers
      non(L and #L == 2, name .. " : " .. f .. " = lueur + lumière")
      if L and #L == 2 then
        local g, l = L[1], L[2]
        non(g.draw_as_glow and l.draw_as_light and g.blend_mode == "additive", name .. " : " .. f .. " lueur additive et couche de lumière")
        non(g.direction_count == 1 and l.direction_count == 1 and g.hr_version and g.hr_version.direction_count == 1, name .. " : " .. f .. " une direction")
        non(g.filename == u.pulse.lr.filename, name .. " : " .. f .. " lit la bande pulsée")
        local n = f == "folded_animation" and 1 or #PULSE
        non(g.frame_count == n and g.hr_version.frame_count == n, name .. " : " .. f .. " joue " .. n .. " image(s)")
        ks[i] = g.tint and g.tint.r or -1
      end
    end
    for i = 2, #ETATS do non(ks[i] and ks[i - 1] and ks[i] > ks[i - 1], name .. " : intensité croissante " .. ETATS[i - 1] .. " < " .. ETATS[i]) end
    non(e.energy_glow_animation == nil, name .. " : ancienne lueur d'énergie (tête vanilla) retirée")
    local ap, ap0 = e.attack_parameters, e0.attack_parameters
    local em = u.ancrages.emetteur.fil
    if ap0.type == "beam" then
      local d = ap.ammo_type.action.action_delivery
      non(ap.source_direction_count == 1 and same(ap.source_offset, { em[1], em[2] }), name .. " : faisceau parti de l'émetteur, une direction")
      non(same(d.source_offset, { em[1], em[2] }), name .. " : rayon parti de l'émetteur")
    else
      non(same(ap.source_offset, ap0.source_offset) and ap.source_direction_count == ap0.source_direction_count, name .. " : tir à projectile non déplacé")
    end
    for _, p in ipairs({ e, raw.item[name] }) do
      local ic = p.icons
      non(ic and ic[1].icon == u.icone.filename and ic[2] and ic[2].icon == e0.icons[2].icon and #ic == #e0.icons, name .. " : icône neuve + chiffres d'âge")
    end
  end
  return m
end

---------------------------------------------------------------------------------------------------
-- §6 (POLISSAGE-3) tourelles à munitions
---------------------------------------------------------------------------------------------------
local ETATS_MUN = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation" }
local COUCHES_TETE = { { "main" }, { "shadow", "draw_as_shadow" }, { "glow", "draw_as_glow" }, { "glow", "draw_as_light" } }

local function sans_bouche(ap)
  local c = deepcopy(ap)
  c.projectile_center, c.projectile_creation_distance = nil, nil
  return c
end

local function juge_munitions(raw, avant)
  local m = {}
  local function non(c, s) if not c then m[#m + 1] = s end end
  if not raw then return { "habillage en erreur" } end
  for cle, name in pairs(MUNITIONS) do
    local e, e0, u = raw["ammo-turret"][name], avant["ammo-turret"][name], BAT[cle]
    non(same(sans_bouche(e0.attack_parameters), sans_bouche(e.attack_parameters)), name .. " : attaque changée hors de l'origine des projectiles")
    non(e.attack_parameters.projectile_creation_distance == u.bouche.distance
      and same(e.attack_parameters.projectile_center, { u.bouche.centre[1], u.bouche.centre[2] }), name .. " : origine des projectiles = bouche du modèle")
    local bp = e.base_picture and e.base_picture.layers
    non(bp and #bp == 3 and bp[1].filename == u.main.lr.filename and bp[2].draw_as_shadow and bp[3].draw_as_glow, name .. " : socle = corps + ombre + lueur")
    local ks = {}
    for i, f in ipairs(ETATS_MUN) do
      local L = e[f] and e[f].layers
      non(L and #L == 4, name .. " : " .. f .. " = corps, ombre, lueur, lumière")
      local n = f == "attacking_animation" and u.images or 1
      for j, cc in ipairs(COUCHES_TETE) do
        local l = L and L[j]
        local src = u.tete[cc[1]]
        for _, x in ipairs({ l or false, l and l.hr_version or false }) do
          local r = x and (x == l and src.lr or src.hr)
          non(x and x.direction_count == 64, name .. " : " .. f .. " couche " .. j .. " à 64 directions")
          non(x and x.frame_count == n, name .. " : " .. f .. " couche " .. j .. " joue " .. n .. " image(s)")
          non(x and x.stripes and #x.stripes == 4, name .. " : " .. f .. " couche " .. j .. " : 4 bandes")
          for b, st in ipairs(x and x.stripes or {}) do
            non(st.width_in_frames == n and st.height_in_frames == u.rangs and st.filename == r.stripes[b],
              name .. " : " .. f .. " couche " .. j .. " bande " .. b .. " (" .. n .. " colonne(s) lue(s) sur " .. u.images .. ")")
          end
          non(x and (cc[2] == nil or x[cc[2]]), name .. " : " .. f .. " couche " .. j .. " " .. tostring(cc[2]))
        end
      end
      local g = L and L[3]
      ks[i] = g and g.tint and g.tint.r or -1
    end
    for i = 2, #ETATS_MUN do non(ks[i] > ks[i - 1], name .. " : intensité croissante " .. ETATS_MUN[i - 1] .. " < " .. ETATS_MUN[i]) end
    non(e.water_reflection == nil, name .. " : reflet vanilla retiré")
    for _, p in ipairs({ e, raw.item[name] }) do
      local ic, ic0 = p.icons, (p == e and e0 or avant.item[name]).icons or {}
      local ok = ic and ic[1].icon == u.icone.filename and #ic == math.max(1, #ic0)
      for j = 2, #ic0 do ok = ok and ic[j] and ic[j].icon == ic0[j].icon end
      non(ok, name .. " : icône neuve + calques d'aujourd'hui gardés")
    end
  end
  return m
end

---------------------------------------------------------------------------------------------------
-- §8 (MURS-ACIDE, 10/11) : pulvérisateur d'acide. Socle À DIRECTION (quatre images corps + ombre + lueur), tête tournante à 64 directions
-- sur chaque direction de socle et chaque état (fin de tir comprise), décalée du PIVOT de sa sellette, origine du jet = pivot + centre de la
-- bouche du modèle, longueur = distance de la bouche ; le reste identique (juge §2).
---------------------------------------------------------------------------------------------------
local DIRS_ACIDE = { { "north", "n" }, { "east", "e" }, { "south", "s" }, { "west", "w" } }
local ETATS_ACIDE = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "ending_attack_animation" }
local function juge_acide(raw, avant)
  local m = {}
  local function non(c, s) if not c then m[#m + 1] = s end end
  if not raw then return { "habillage en erreur" } end
  local e, u = raw["fluid-turret"]["fo-acid-sprayer"], BAT.acide
  if not u then return { "acide absent de sprites.lua" } end
  for _, dd in ipairs(DIRS_ACIDE) do
    local bp = e.base_picture and e.base_picture[dd[1]] and e.base_picture[dd[1]].layers
    local s = u.socles[dd[2]]
    non(bp and #bp == 3 and bp[1].filename == s.main.lr.filename and bp[1].hr_version.filename == s.main.hr.filename and bp[2].draw_as_shadow
      and bp[3].draw_as_glow, "acide : socle " .. dd[1] .. " = corps + ombre + lueur de sa direction")
    local pv = u.pivots[dd[1]]
    local gc = e.attack_parameters.gun_center_shift and e.attack_parameters.gun_center_shift[dd[1]]
    non(gc and math.abs(gc[1] - (pv[1] + u.bouche.centre[1])) < 1e-9 and math.abs(gc[2] - (pv[2] + u.bouche.centre[2])) < 1e-9,
      "acide : jet " .. dd[1] .. " parti de la bouche du modèle sur sa sellette")
    for _, f in ipairs(ETATS_ACIDE) do
      local L = e[f] and e[f][dd[1]] and e[f][dd[1]].layers
      non(L and #L == 4, "acide : " .. f .. " " .. dd[1] .. " = corps, ombre, lueur, lumière")
      for j, cc in ipairs(COUCHES_TETE) do
        local l = L and L[j]
        local src = u.tete[cc[1]]
        for _, x in ipairs({ l or false, l and l.hr_version or false }) do
          local r = x and (x == l and src.lr or src.hr)
          non(x and x.direction_count == 64 and x.stripes and #x.stripes == 4, "acide : " .. f .. " " .. dd[1] .. " couche " .. j .. " à 64 directions")
          non(x and x.shift and r and math.abs(x.shift[1] - (r.shift[1] + pv[1])) < 1e-9 and math.abs(x.shift[2] - (r.shift[2] + pv[2])) < 1e-9,
            "acide : " .. f .. " " .. dd[1] .. " couche " .. j .. " posée sur la sellette (pivot)")
          non(x and (cc[2] == nil or x[cc[2]]), "acide : " .. f .. " couche " .. j .. " " .. tostring(cc[2]))
        end
      end
    end
  end
  non(math.abs(e.attack_parameters.gun_barrel_length - u.bouche.distance) < 1e-9, "acide : longueur du jet = distance de la bouche")
  non(e.water_reflection == nil, "acide : reflet vanilla retiré")
  for _, p in ipairs({ e, raw.item["fo-acid-sprayer"] }) do
    local ic0 = (p == e and avant["fluid-turret"]["fo-acid-sprayer"] or avant.item["fo-acid-sprayer"]).icons
    non(p.icons and p.icons[1].icon == u.icone.filename and #p.icons == #ic0 and p.icons[2].icon == ic0[2].icon, "acide : icône neuve + calque d'aujourd'hui")
  end
  return m
end

local function juge_tout(r, a)
  local m = juge(r, a)
  for _, x in ipairs(juge_munitions(r, a)) do m[#m + 1] = x end
  for _, x in ipairs(juge_acide(r, a)) do m[#m + 1] = x end
  return m
end

local raw, avant, err = habille(SOURCE or "")
check(raw ~= nil, "habillage sans erreur : " .. tostring(err))
local motifs = juge(raw, avant)
for _, s in ipairs(motifs) do check(false, "§2-3 " .. s) end
check(#motifs == 0, "§2-3 les huit bâtiments habillés, gameplay intact")
local motifs6 = juge_munitions(raw, avant)
for _, s in ipairs(motifs6) do check(false, "§6 " .. s) end
check(#motifs6 == 0, "§6 les quatre tourelles à munitions habillées, gameplay intact hors origine des projectiles")
local motifs8 = juge_acide(raw, avant)
for _, s in ipairs(motifs8) do check(false, "§8 " .. s) end
check(#motifs8 == 0, "§8 pulvérisateur d'acide habillé (socle à direction, tête à 64 directions), gameplay intact hors origine du jet")

---------------------------------------------------------------------------------------------------
-- §4 pulsation
---------------------------------------------------------------------------------------------------
local function pulse_ok(v)
  if not v or #v < 4 then return false end
  local imax, vmax = 1, -1
  for i, x in ipairs(v) do
    if not (x > 0 and x <= 1) then return false end
    if x > vmax then imax, vmax = i, x end
  end
  if vmax ~= 1 then return false end
  for i = 2, imax do if v[i] < v[i - 1] then return false end end
  for i = imax + 1, #v do if v[i] > v[i - 1] then return false end end
  return v[1] < vmax and v[#v] < vmax
end
check(pulse_ok(PULSE), "§4 PULSE triangulaire dans ]0, 1], maximum 1 : " .. table.concat(PULSE, ", "))
check(FEUILLES and not FEUILLES:find("math%.sin") and not FEUILLES:find("math%.cos"), "§4 aucune trigonométrie dans feuilles.py (table précalculée)")

---------------------------------------------------------------------------------------------------
-- §5 mutants
---------------------------------------------------------------------------------------------------
local function mutant(nom, de, vers)
  check(SOURCE and SOURCE:find(de, 1, true) ~= nil, "§5 mutant « " .. nom .. " » : le texte d'origine est là")
  if not SOURCE then return end
  local src = SOURCE:gsub(de:gsub("%p", "%%%0"), (vers:gsub("%%", "%%%%")), 1)
  local r, a = habille(src)
  check(#juge_tout(r, a) > 0, "§5 mutant refusé : " .. nom)
end
mutant("faisceau gardé à 64 directions", "      ap.source_direction_count = 1\n", "")
mutant("tir à projectile déplacé", 'if ap and ap.type == "beam" then', "if ap then")
mutant("tête à 64 directions", "line_length = r.line_length, direction_count = 1,", "line_length = r.line_length, direction_count = 64,")
mutant("chiffres d'âge perdus", "for i = 2, #old do", "for i = 2, 1 do")
mutant("intensité plate", "local k = light and etat.k * 0.5 or etat.k", "local k = 1")
mutant("emprise changée", "    e.drawing_box = boite(u)\n    local ap", "    e.drawing_box = boite(u)\n    e.collision_box = boite(u)\n    local ap")
mutant("lumière absente", "e[f] = { layers = { pulse(u, ETATS[f], false), pulse(u, ETATS[f], true) } }", "e[f] = { layers = { pulse(u, ETATS[f], false) } }")
mutant("tête vanilla gardée", "    e.energy_glow_animation = nil\n", "")
mutant("repli joue la bande", "folded_animation = { k = 0.35, images = 1 },", "folded_animation = { k = 0.35, images = 0 },")
-- §6 (POLISSAGE-3) tourelles à munitions
mutant("tête à 4 directions", "direction_count = u.directions, frame_count = n }", "direction_count = 4, frame_count = n }")
mutant("tir à une image", "local n = etat.tir and u.images or 1", "local n = 1")
mutant("repos lit toutes les colonnes", "bandes[i] = { filename = f, width_in_frames = n,", "bandes[i] = { filename = f, width_in_frames = u.images,")
mutant("origine du tir non lue", "    ap.projectile_creation_distance = u.bouche.distance\n", "")
mutant("ombre de tête absente", 'couche_tete(u, "main", etat, n), couche_tete(u, "shadow", etat, n), couche_tete(u, "glow", etat, n),',
  'couche_tete(u, "main", etat, n), couche_tete(u, "glow", etat, n),')
mutant("rotation changée", "    e.water_reflection = nil\n    e.drawing_box = boite(u)\n    local ap = e.attack_parameters\n",
  "    e.water_reflection = nil\n    e.drawing_box = boite(u)\n    e.rotation_speed = 0.02\n    local ap = e.attack_parameters\n")
mutant("lueur de tête plate", 'local k = kind == "light" and etat.k * 0.5 or etat.k', "local k = 1")
mutant("socle sans lueur", '    if u.glow then socle[#socle + 1] = couche(u.glow, "glow") end\n', "")
mutant("calques d'aujourd'hui perdus (munitions)", "for j = 2, #ancien do", "for j = 2, 1 do")
-- §8 (MURS-ACIDE) pulvérisateur d'acide
mutant("socle d'une seule direction", "      e.base_picture[dd[1]] = { layers = L }", "      e.base_picture = { layers = L }")
mutant("tête non posée sur la sellette", "      l.shift = { l.shift[1] + p[1], l.shift[2] + p[2] }\n", "")
mutant("jet sans la sellette", "{ p[1] + u.bouche.centre[1], p[2] + u.bouche.centre[2] }", "{ u.bouche.centre[1], u.bouche.centre[2] }")
mutant("longueur du jet non lue", "    ap.gun_barrel_length = u.bouche.distance\n", "")
mutant("fin de tir vanilla gardée", "    e.ending_attack_animation = e.attacking_animation\n", "")
mutant("tête du seul socle nord", "      e[etat.champ] = t4", "      e[etat.champ] = t4.north")
mutant("fluide changé", "    e.friendly_map_color = e.map_color\n", "    e.friendly_map_color = e.map_color\n    e.fluid_buffer_size = 50\n")
-- PULSE
for _, m in ipairs({ { "pulsation plate", "PULSE = (1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)" },
  { "pulsation montante seulement", "PULSE = (0.5, 0.62, 0.76, 0.9, 1.0, 1.0, 1.0, 1.0)" } }) do
  local src = FEUILLES and FEUILLES:gsub("\nPULSE = %([^)]*%)", "\n" .. m[2], 1)
  check(not pulse_ok(pulse_de(src)), "§5 mutant refusé : " .. m[1])
end

---------------------------------------------------------------------------------------------------
-- §7 (VISUELS-DISTINCTS, 10/11) : marques des tourelles à munitions. Chacune a son socle (forme), son liseré de fonction (couleur) et
-- son motif de toit, deux à deux distincts (tools/render/pieces/batiments/marques.py) ; les feuilles le PROUVENT : sprites.lua porte la
-- marque recopiée de la table (feuilles à jour) et ses MESURES (teinte de la lueur du socle proche de la couleur déclarée et saturée ;
-- silhouettes de socle de recouvrement IoU <= 0,85) ; aucune autre construction n'est marquée.
---------------------------------------------------------------------------------------------------
local MARQUES_SRC = read("tools/render/pieces/batiments/marques.py")
local function marques_de(src)
  local t = {}
  if not src then return t end
  for nom, forme, r, g, b, toit in src:gmatch('"(%w+)": {"forme": "(%w+)", "lisere": %(([%d.]+), ([%d.]+), ([%d.]+)%), "toit": "(%w+)"') do
    t[nom] = { forme = forme, lisere = { tonumber(r), tonumber(g), tonumber(b) }, toit = toit }
  end
  return t
end
local function teinte(c)
  local r, g, b = c[1], c[2], c[3]
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local d = mx - mn
  if d <= 1e-9 then return 0 end
  local h
  if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
  return 60 * h
end
local function ecart(h1, h2)
  local d = math.abs(h1 - h2) % 360
  return math.min(d, 360 - d)
end
local NOMS_MUNITIONS = {}
for nom in pairs(MUNITIONS) do NOMS_MUNITIONS[#NOMS_MUNITIONS + 1] = nom end
table.sort(NOMS_MUNITIONS)
local SANS_MARQUE = { "bastion2", "bastion3", "bastion4", "tesla", "laser_lourd", "coffre", "pylone", "cuve" }
local function juge_marques(M, B)
  local refus = {}
  local function non(t) refus[#refus + 1] = t end
  local n = NOMS_MUNITIONS
  for _, k in ipairs(n) do
    if not M[k] then non(k .. " sans marque dans marques.py") end
  end
  for i = 1, #n do
    for j = i + 1, #n do
      local a, b = M[n[i]], M[n[j]]
      if a and b then
        if a.forme == b.forme then non("socle partagé " .. n[i] .. "/" .. n[j]) end
        if a.toit == b.toit then non("motif de toit partagé " .. n[i] .. "/" .. n[j]) end
        if ecart(teinte(a.lisere), teinte(b.lisere)) < 45 then non("liserés de teintes trop proches " .. n[i] .. "/" .. n[j]) end
      end
      local ma = B[n[i]] and B[n[i]].marque
      local io = ma and ma.mesure and ma.mesure.iou and ma.mesure.iou[n[j]]
      if not io or io > 0.85 then non("silhouettes de socle confondues ou non mesurées " .. n[i] .. "/" .. n[j] .. " : " .. tostring(io)) end
    end
  end
  for _, k in ipairs(n) do
    local sm, m = B[k] and B[k].marque, M[k]
    if not sm then
      non(k .. " : feuille sans marque (feuilles.py non relancé)")
    elseif m then
      local d = 0
      for c = 1, 3 do d = math.max(d, math.abs((sm.lisere[c] or -1) - m.lisere[c])) end
      if sm.forme ~= m.forme or sm.toit ~= m.toit or d > 1e-3 then non(k .. " : feuilles périmées (marque différente de marques.py)") end
      if not sm.mesure or ecart(sm.mesure.teinte, teinte(m.lisere)) > 30 or sm.mesure.saturation < 0.35 then
        non(k .. " : liseré non rendu (teinte mesurée " .. tostring(sm.mesure and sm.mesure.teinte) .. " pour " .. string.format("%.0f", teinte(m.lisere)) .. ")")
      end
    end
  end
  for _, k in ipairs(SANS_MARQUE) do
    if M[k] or (B[k] and B[k].marque) then non(k .. " marqué : seules les tourelles à munitions portent une marque") end
  end
  return refus
end
local M0 = marques_de(MARQUES_SRC)
check(MARQUES_SRC and #NOMS_MUNITIONS == 4, "§7 marques.py lisible, quatre tourelles à munitions")
local r0 = juge_marques(M0, BAT or {})
check(#r0 == 0, "§7 marques distinctes et rendues : " .. table.concat(r0, " ; "))
if BAT then
  for _, k in ipairs(NOMS_MUNITIONS) do
    local m = BAT[k] and BAT[k].marque
    if m and m.mesure then
      local io = {}
      for _, o in ipairs(NOMS_MUNITIONS) do if m.mesure.iou[o] then io[#io + 1] = o .. " " .. m.mesure.iou[o] end end
      print(string.format("[BATIMENTS] §7 %s : socle %s, toit %s, liseré déclaré %.0f°, mesuré %.1f° (saturation %.2f), IoU %s", k, m.forme, m.toit,
        teinte(m.lisere), m.mesure.teinte, m.mesure.saturation, table.concat(io, ", ")))
    end
  end
end
local function mut_src(nom, f)
  check(#juge_marques(marques_de(f(MARQUES_SRC or "")), BAT or {}) > 0, "§7 mutant refusé : " .. nom)
end
local function mut_bat(nom, f)
  local B = deepcopy(BAT or {})
  local ok = pcall(f, B)
  check(ok and #juge_marques(M0, B) > 0, "§7 mutant refusé : " .. nom)
end
mut_src("liseré constant", function(s) return (s:gsub('"lisere": %b()', '"lisere": (0.098, 0.902, 1.000)')) end)
mut_src("socle partagé", function(s) return (s:gsub('"forme": "%w+"', '"forme": "octo"')) end)
mut_src("toit partagé", function(s) return (s:gsub('"toit": "%w+"', '"toit": "chevron"')) end)
mut_src("tourelle sans marque", function(s) return (s:gsub('\n    "mortier": [^\n]*', "", 1)) end)
mut_bat("liseré non rendu", function(B) B.lourde.marque.mesure.teinte = 190 end)
mut_bat("silhouettes confondues", function(B) B.canon.marque.mesure.iou.mortier = 1 end)
mut_bat("tourelle électrique marquée", function(B) B.bastion2.marque = deepcopy(B.bastion1.marque) end)
mut_bat("feuilles périmées", function(B) B.mortier.marque.forme = "rond" end)
mut_bat("lueur grise", function(B) B.canon.marque.mesure.saturation = 0.05 end)

print(string.format("[BATIMENTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
