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
    §5 mutants de prototypes/batiments_visuels.lua et de la table PULSE : chacun refusé.
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
  energy_glow_animation = true, attack_parameters = true }
local ETATS = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation" }

local function sans_origine(ap)
  local c = deepcopy(ap)
  c.source_offset, c.source_direction_count = nil, nil
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

local raw, avant, err = habille(SOURCE or "")
check(raw ~= nil, "habillage sans erreur : " .. tostring(err))
local motifs = juge(raw, avant)
for _, s in ipairs(motifs) do check(false, "§2-3 " .. s) end
check(#motifs == 0, "§2-3 les huit bâtiments habillés, gameplay intact")

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
  check(#juge(r, a) > 0, "§5 mutant refusé : " .. nom)
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
-- PULSE
for _, m in ipairs({ { "pulsation plate", "PULSE = (1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)" },
  { "pulsation montante seulement", "PULSE = (0.5, 0.62, 0.76, 0.9, 1.0, 1.0, 1.0, 1.0)" } }) do
  local src = FEUILLES and FEUILLES:gsub("\nPULSE = %([^)]*%)", "\n" .. m[2], 1)
  check(not pulse_ok(pulse_de(src)), "§5 mutant refusé : " .. m[1])
end

print(string.format("[BATIMENTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
