--[[
  Lot EXPERIMENTAUX-PUISSANCE (7/11) : MODULES DES GÉANTS DES FACTIONS, hors jeu. Lua 5.2, depuis la racine du mod :
      lua5.2 tests/xp_modules_factions_test.lua
  QCM-7/11 du DC : modules « posés aussi sur les géants des factions selon leur âge » ; lead : « Prix unique par palier, bonus ajusté selon
  le géant porteur. C'est toi qui l'appelles dans geant.lua, et pour les géants des factions par Armee.hooks.giant_setup » ; emplacements :
  3 au Torique, 4 à l'Héliaste et au Couronné.
  Charge le VRAI script/robots/geant.lua dans un monde bouché (Armee, XpG, moteur), avec les vraies règles (shared/content/robots.lua,
  shared/robots/experimentaux_modules.lua) :
    §1 données : Ro.XP_MODULES 3 / 4 / 4, recopiés sur les géants ;
    §2 pose par une faction (Armee.hooks.giant_setup) : bonus = Mod.bonus_age(âge du géant, emplacements), en fractions, écrit une fois ;
    §3 rien pour un géant du joueur, ni sans les prototypes des modules en jeu, ni deux fois ;
    §4 géant de faction posé AVANT les modules (sauvegarde) : bonus posé au premier balayage des salves, et passé à la cible et à la salve ;
    §5 bonus des géants morts oubliés (XpG.bonus_garder ne reçoit que les vivants) ;
    §6 mutants du script, tous refusés.
]]

package.path = "./?.lua;" .. package.path

local ok, bad = 0, 0
local function check(c, nom, detail)
  if c then ok = ok + 1 else bad = bad + 1; print("[XP-MOD-FACTIONS] ECHEC " .. nom .. " " .. tostring(detail or "")) end
end

local function lire(p)
  local f = assert(io.open(p, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = lire("script/robots/geant.lua")

local Ro = require("shared.content.robots")
local Mod = require("shared.robots.experimentaux_modules")

--- Monde bouché autour de geant.lua (source éventuellement mutée). `modules_en_jeu` : prototypes des modules présents.
local function monde(source, modules_en_jeu)
  local W = { bonus = {}, poses = {}, garder = {}, cibles = {}, salves = {}, logs = {}, ents = {}, ledger = {}, factions = {}, nth = {} }
  _G.defines = { events = setmetatable({}, { __index = function(_, k) return k end }), inventory = { spider_ammo = 1 } }
  _G.log = function(m) W.logs[#W.logs + 1] = m end
  _G.remote = { add_interface = function() end }
  local eq = {}
  if modules_en_jeu then
    for _, m in ipairs(Mod.MODULES) do eq[m.name] = { name = m.name } end
  end
  _G.game = { equipment_prototypes = eq }
  local XpG = {
    bonus_de = function(un) return W.bonus[un] end,
    set_bonus = function(un, p, f)
      if not W.ents[un] then return false end
      W.bonus[un] = { portee = p, puissance = f }
      W.poses[#W.poses + 1] = un
      return true
    end,
    bonus_garder = function(vivants)
      local copie = {}
      for i, un in ipairs(vivants) do copie[i] = un end
      W.garder[#W.garder + 1] = copie
      local nb = {}
      for _, un in ipairs(vivants) do nb[un] = W.bonus[un] end
      W.bonus = nb
    end,
    zone_active = function() return false end,
    cible = function(u, r, b)
      W.cibles[#W.cibles + 1] = { un = u.unit_number, b = b }
      return { position = { x = 0, y = 0 } }
    end,
    salve = function(u, un, r, pos, tick, b) W.salves[#W.salves + 1] = { un = un, b = b } end,
  }
  local salves_t = {}
  local Armee = {
    hooks = {},
    S = function() return { ledger = W.ledger } end,
    table_of = function(n) if n == "salves" then return salves_t end return {} end,
    entity = function(un) return W.ents[un] end,
    enabled = function() return true end,
  }
  local pre = {
    ["script.core.events"] = { on = function() end, on_nth_tick = function(n, f) W.nth[n] = f end },
    ["script.robots.armee"] = Armee,
    ["shared.faction.config"] = { factions = { { key = "scarlet", color = { r = 1, g = 0, b = 0 } } } },
    ["shared.robots.modele"] = {
      units_with = function(ledger, id)
        local out = {}
        for _, e in ipairs(ledger) do if e.id == id then out[#out + 1] = e.un end end
        return out
      end,
    },
    ["script.robots.experimentaux_geants"] = XpG,
    ["script.faction.state"] = { by_force = function(name) return W.factions[name] end },
  }
  for k, v in pairs(pre) do package.loaded[k] = v end -- monde de test : l'ordre ne compte pas
  local chunk = assert(load(source, "=geant.lua"))
  local Geant = chunk()
  W.Geant, W.Armee = Geant, Armee
  W.factions["fo-scarlet"] = { key = "scarlet" }
  return W
end

--- Un géant `id` (toroid, heliast, crowned) de la force `force`, inscrit au registre.
local function geant(W, un, id, force)
  local inv = { get_item_count = function() return 1000 end, insert = function() return 0 end }
  local u = {
    valid = true, unit_number = un, name = Ro.proto_name(force == "player" and Ro.PLAYER_OWNER or "scarlet", Ro.robot(id)),
    force = { name = force }, position = { x = 0, y = 0 }, get_inventory = function() return inv end,
  }
  W.ents[un] = u
  W.ledger[#W.ledger + 1] = { un = un, id = id }
  return u
end

local function proche(a, b) return math.abs(a - b) < 1e-9 end

-- §1 données
check(Ro.XP_MODULES.toroid == 3 and Ro.XP_MODULES.heliast == 4 and Ro.XP_MODULES.crowned == 4, "§1 emplacements 3 / 4 / 4 (lead, 7/11)")
check(Ro.robot("toroid").xp_modules == 3 and Ro.robot("heliast").xp_modules == 4 and Ro.robot("crowned").xp_modules == 4,
  "§1 emplacements recopiés sur les géants")
check(Ro.proto_name("scarlet", Ro.robot("toroid")) == Ro.proto_name(Ro.PLAYER_OWNER, Ro.robot("toroid")),
  "§1 un géant de faction a le prototype du joueur : la faction se lit à la force (prémisse du script)")

-- §2 pose par une faction
local function scenario_pose(source, en_jeu)
  local W = monde(source, en_jeu)
  local f = W.factions["fo-scarlet"]
  local poses = {}
  for k, id in ipairs({ "toroid", "heliast", "crowned" }) do
    local u = geant(W, 100 + k, id, "fo-scarlet")
    W.Armee.hooks.giant_setup(u, f)
    poses[id] = W.bonus[u.unit_number]
  end
  return W, poses
end
local W, poses = scenario_pose(SRC, true)
local justes = 0
for _, id in ipairs({ "toroid", "heliast", "crowned" }) do
  local r = Ro.robot(id)
  local att = Mod.bonus_age(r.age, Ro.XP_MODULES[id])
  local b = poses[id]
  if b and proche(b.portee, att.portee) and proche(b.puissance, att.puissance) then justes = justes + 1 end
end
check(justes == 3, "§2 bonus = Mod.bonus_age(âge du géant, emplacements) pour les 3 géants", justes)
check(W.Armee.hooks.giant_setup == W.Geant.setup, "§2 branché au crochet Armee.hooks.giant_setup")
check(poses.heliast and poses.heliast.puissance > 0 and poses.toroid.puissance > 0, "§2 bonus non nul (âges 13 à 15 au-delà du premier palier)")
check(#W.poses == 3 and #W.logs >= 3 and W.logs[#W.logs]:find("[FO-XP] modules du geant 103 crowned (faction scarlet, age 15)", 1, true) ~= nil,
  "§2 une écriture et une ligne de journal par géant", W.logs[#W.logs])
W.Geant.setup(W.ents[101], W.factions["fo-scarlet"])
check(#W.poses == 3, "§3 posé une seule fois (un 2e appel n'écrit rien)")

-- §3 joueur, prototypes absents
local Wj = monde(SRC, true)
local uj = geant(Wj, 7, "heliast", "player")
Wj.Armee.hooks.giant_setup(uj, nil)
Wj.nth[30]({ tick = 30 })
check(#Wj.poses == 0 and Wj.bonus[7] == nil, "§3 géant du joueur : aucun module (ni à la pose, ni au balayage)")
local _, poses0 = scenario_pose(SRC, false)
check(poses0.toroid == nil and poses0.heliast == nil and poses0.crowned == nil, "§3 prototypes des modules absents : aucun bonus")

-- §4 géant de faction posé avant les modules
local Wm = monde(SRC, true)
geant(Wm, 9, "toroid", "fo-scarlet")
Wm.nth[30]({ tick = 60 })
local att = Mod.bonus_age(13, 3)
check(Wm.bonus[9] and proche(Wm.bonus[9].puissance, att.puissance) and #Wm.poses == 1, "§4 bonus posé au premier balayage des salves")
check(#Wm.cibles == 1 and Wm.cibles[1].b == Wm.bonus[9] and #Wm.salves == 1 and Wm.salves[1].b == Wm.bonus[9],
  "§4 le bonus est passé à la cible ET à la salve du même balayage")
Wm.nth[30]({ tick = 90 })
check(#Wm.poses == 1, "§4 pas de 2e écriture aux balayages suivants")

-- §5 morts oubliés
local Wd = monde(SRC, true)
geant(Wd, 11, "toroid", "fo-scarlet")
geant(Wd, 12, "heliast", "fo-scarlet")
Wd.nth[30]({ tick = 30 })
Wd.ents[11] = nil
Wd.nth[30]({ tick = 60 })
local g = Wd.garder[#Wd.garder]
check(g and #g == 1 and g[1] == 12 and Wd.bonus[11] == nil and Wd.bonus[12] ~= nil, "§5 bonus des géants morts oubliés, vivants gardés")

-- §5 bis XpG.bonus_garder et set_bonus réels (source) : liste des vivants, rien par pairs
local SXG = lire("script/robots/experimentaux_geants.lua")
check(SXG:find("for _, un in ipairs(vivants) do nb[un] = s.bonus_ro[un] end", 1, true) ~= nil
  and SXG:find("s.bonus_ro[unit_number] = { portee = tonumber(portee) or 0, puissance = tonumber(puissance) or 0 }", 1, true) ~= nil,
  "§5 bis bonus_garder garde les vivants de la liste ; set_bonus écrit bonus_ro des géants de robotsjeu")

-- §6 mutants
local function refuse(nom, old, new, essai)
  local s, n = SRC:gsub(old:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (new:gsub("%%", "%%%%")))
  if n ~= 1 then
    check(false, "§6 mutant introuvable : " .. nom)
    return
  end
  local okm, passe = pcall(essai, s)
  check(not (okm and passe), "§6 mutant refusé : " .. nom)
end
local function essai_pose(s)
  local Wx, px = scenario_pose(s, true)
  for _, id in ipairs({ "toroid", "heliast", "crowned" }) do
    local r = Ro.robot(id)
    local a = Mod.bonus_age(r.age, Ro.XP_MODULES[id])
    if not (px[id] and proche(px[id].portee, a.portee) and proche(px[id].puissance, a.puissance)) then return false end
  end
  return #Wx.poses == 3
end
local function essai_joueur(s)
  local Wx = monde(s, true)
  local u = geant(Wx, 7, "heliast", "player")
  Wx.Armee.hooks.giant_setup(u, nil)
  Wx.nth[30]({ tick = 30 })
  return #Wx.poses == 0
end
local function essai_absents(s)
  local _, px = scenario_pose(s, false)
  return px.toroid == nil and px.heliast == nil and px.crowned == nil
end
local function essai_migration(s)
  local Wx = monde(s, true)
  geant(Wx, 9, "toroid", "fo-scarlet")
  Wx.nth[30]({ tick = 60 })
  return Wx.bonus[9] ~= nil and #Wx.salves == 1 and Wx.salves[1].b == Wx.bonus[9]
end
local function essai_une_fois(s)
  local Wx = scenario_pose(s, true)
  Wx.Geant.setup(Wx.ents[101], Wx.factions["fo-scarlet"])
  Wx.nth[30]({ tick = 30 })
  return #Wx.poses == 3
end
local function essai_morts(s)
  local Wx = monde(s, true)
  geant(Wx, 11, "toroid", "fo-scarlet")
  geant(Wx, 12, "heliast", "fo-scarlet")
  Wx.nth[30]({ tick = 30 })
  Wx.ents[11] = nil
  Wx.nth[30]({ tick = 60 })
  return Wx.bonus[11] == nil and Wx.bonus[12] ~= nil
end
refuse("âge de la faction au lieu de celui du géant (+1)", "Mod.bonus_age(r.age, r.xp_modules)", "Mod.bonus_age(r.age + 1, r.xp_modules)", essai_pose)
refuse("un emplacement de plus", "Mod.bonus_age(r.age, r.xp_modules)", "Mod.bonus_age(r.age, r.xp_modules + 1)", essai_pose)
refuse("pourcents au lieu de fractions", "XpG.set_bonus(un, b.portee, b.puissance)", "XpG.set_bonus(un, b.pct.portee, b.pct.puissance)", essai_pose)
refuse("portée et puissance inversées", "XpG.set_bonus(un, b.portee, b.puissance)", "XpG.set_bonus(un, b.puissance, b.portee)", essai_pose)
refuse("joueur servi aussi", "if not (f and r and (r.xp_modules or 0) > 0) then return nil end", "if not (r and (r.xp_modules or 0) > 0) then return nil end", essai_joueur)
refuse("faction lue au nom du prototype", "f = f or State.by_force(u.force.name)", "f = f or (Ro.parse_unit(u.name) ~= Ro.PLAYER_OWNER and {} or nil)", essai_migration)
refuse("sans garde des prototypes", "if not game.equipment_prototypes[Mod.MODULES[1].name] then return nil end", "", essai_absents)
refuse("pose sans le crochet", "  if f then Geant.modules(u, f) end\n", "", essai_pose)
refuse("pas de rattrapage au balayage", "if not XpG.bonus_de(un) then Geant.modules(u) end", "", essai_migration)
refuse("rattrapage après la lecture du bonus", "          if not XpG.bonus_de(un) then Geant.modules(u) end\n          local b = XpG.bonus_de(un)",
  "          local b = XpG.bonus_de(un)\n          if not XpG.bonus_de(un) then Geant.modules(u) end", essai_migration)
refuse("réécrit à chaque appel", "if not un or XpG.bonus_de(un) then return nil end", "if not un then return nil end", essai_une_fois)
refuse("morts jamais oubliés", "  XpG.bonus_garder(vivants)\n", "", essai_morts)
refuse("vivants mal comptés", "        vivants[#vivants + 1] = un\n", "", essai_morts)

-- forme
check(not SRC:gsub("ipairs%(", ""):find("[^i]pairs%("), "forme : aucun pairs dans geant.lua")

print(string.format("[XP-MOD-FACTIONS] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and 0 or 1)
