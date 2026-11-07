-- Banc hors jeu du lot X10, Q5 (7/11) : explosions de mort des unités recréées par script près d'un joueur. Règle pure
-- (shared/explosions_mort/regles.lua), habillage des prototypes (formes de `dying_explosion` de vanilla et du mod), module
-- de jeu (script/world/explosions_mort.lua) sur un moteur
-- simulé minimal (relevé, près, loin, bornes, témoin actif = false, effets des autres lots ignorés), puis mutants du
-- code (chacun doit être vu).
--   lua5.2 tests/explosions_mort_test.lua      -> [EXPLOSIONS-MORT] BILAN : N OK, 0 ECHEC(S)
package.path = "./?.lua;" .. package.path

local ok, ko = 0, 0
local function check(c, quoi, detail)
  if c then ok = ok + 1 else ko = ko + 1; print("ECHEC  " .. quoi .. (detail and (" : " .. tostring(detail)) or "")) end
end

local function lire(chemin)
  local f = assert(io.open(chemin, "rb"))
  local t = f:read("*a")
  f:close()
  return t
end

local function remplacer(texte, avant, apres)
  local i, j = texte:find(avant, 1, true)
  assert(i, "mutant introuvable : " .. avant)
  return texte:sub(1, i - 1) .. apres .. texte:sub(j + 1)
end

local function copie(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copie(v) end
  return c
end

-- ===================================================================================================================
-- 1. Règle pure : chaque vérification rend le nombre d'écarts (0 attendu sur le module livré, > 0 sur un mutant).
-- ===================================================================================================================
local function verifier_regles(M, chk)
  local n0 = 0
  local function c(cond, quoi, d) if not cond then n0 = n0 + 1 end; if chk then chk(cond, quoi, d) end end
  c(M.RAYON == 224, "rayon 224 tuiles (3 840 px au zoom 0,3)", M.RAYON)
  c(M.RELEVE == 60, "releve toutes les 60 ticks", M.RELEVE)
  c(M.TYPES[1] == "unit" and #M.TYPES == 1, "type unit seul (pas turret : nos tourelles experimentales en sont)")
  -- formes de dying_explosion
  local n = M.noms_explosion("small-biter-die")
  c(n and #n == 1 and n[1] == "small-biter-die", "chaine")
  n = M.noms_explosion({ "a-die", "b-die" })
  c(n and #n == 2 and n[1] == "a-die" and n[2] == "b-die", "liste de chaines")
  n = M.noms_explosion({ name = "big-explosion" })
  c(n and #n == 1 and n[1] == "big-explosion", "{ name }")
  n = M.noms_explosion({ { name = "x" }, "y" })
  c(n and #n == 2 and n[1] == "x" and n[2] == "y", "liste mixte")
  c(M.noms_explosion({ name = "x", offset = { 0, 1 } }) == nil, "decalage : laisse au moteur")
  c(M.noms_explosion({ { name = "x", offset = { 1, 0 } } }) == nil, "decalage dans une liste : laisse au moteur")
  c(M.noms_explosion("") == nil, "nom vide refuse")
  c(M.noms_explosion("a|b") == nil, "nom portant | refuse")
  c(M.noms_explosion({}) == nil, "liste vide refusee")
  c(M.noms_explosion(nil) == nil and M.noms_explosion(3) == nil, "nil et nombre refuses")
  -- identifiant aller-retour
  c(M.effect_id({ "a-die" }) == "fo-mort|a-die", "identifiant d'un nom", M.effect_id({ "a-die" }))
  local r = M.noms(M.effect_id({ "a-die", "b-die" }))
  c(r and #r == 2 and r[1] == "a-die" and r[2] == "b-die", "aller-retour de deux noms")
  c(M.noms("fo-tir") == nil and M.noms("fo-xp|rayon") == nil and M.noms(nil) == nil, "identifiants des autres lots ignores")
  c(M.noms("fo-mort|") == nil, "identifiant sans nom ignore")
  c(M.noms("x-fo-mort|a") == nil, "prefixe en tete seulement")
  -- effet ajouté, existant gardé devant
  local e = M.avec_effet(nil, { "a" })
  c(#e == 1 and e[1].type == "script" and e[1].effect_id == "fo-mort|a", "effet seul")
  local feu = { type = "create-fire", entity_name = "fire-flame", initial_ground_flame_count = 2 }
  e = M.avec_effet(feu, { "a" })
  c(#e == 2 and e[1] == feu and e[2].type == "script", "effet unique existant garde devant")
  e = M.avec_effet({ feu, { type = "create-entity", entity_name = "z" } }, { "a" })
  c(#e == 3 and e[1] == feu and e[2].entity_name == "z" and e[3].effect_id == "fo-mort|a", "liste existante gardee")
  -- habillage d'un prototype
  local p = { type = "unit", name = "small-biter", dying_explosion = "small-biter-die" }
  local h = M.habiller(p)
  c(h and h[1] == "small-biter-die" and p.dying_explosion == nil, "habille : dying_explosion retire")
  c(p.dying_trigger_effect and p.dying_trigger_effect[1].effect_id == "fo-mort|small-biter-die", "habille : effet script")
  c(M.habiller(p) == nil and #p.dying_trigger_effect == 1, "deuxieme habillage sans effet (idempotent)")
  local ig = { type = "unit", name = "ignee", dying_explosion = "blood-explosion-big", dying_trigger_effect = { copie(feu) } }
  M.habiller(ig)
  c(#ig.dying_trigger_effect == 2 and ig.dying_trigger_effect[1].type == "create-fire", "Ignee : le feu reste (du jeu)")
  local dec = { type = "unit", name = "d", dying_explosion = { name = "x", offset = { 0, -1 } } }
  c(M.habiller(dec) == nil and dec.dying_explosion ~= nil and dec.dying_trigger_effect == nil, "decalage : inchange")
  -- proximité (Tchebychev, bornes comprises, même surface)
  local J = { { s = 1, x = 0, y = 0 } }
  c(M.proche(J, 1, 224, 0, 224), "borne est comprise")
  c(M.proche(J, 1, -224, 224, 224), "coin compris (Tchebychev)")
  c(not M.proche(J, 1, 224.5, 0, 224), "au-dela de la borne : loin")
  c(not M.proche(J, 1, 0, -300, 224), "loin au nord")
  c(not M.proche(J, 2, 0, 0, 224), "autre surface : loin")
  c(M.proche({ { s = 2, x = 0, y = 0 }, { s = 1, x = 1000, y = 0 } }, 1, 900, 0, 224), "deuxieme joueur proche")
  c(M.proche(nil, 1, 9999, 9999, 224), "sans releve : proche (comme vanilla)")
  c(M.proche({}, 1, 9999, 9999, 224), "aucun joueur connecte : proche (bancs sans joueur inchanges)")
  return n0
end

local M = require("shared.explosions_mort.regles")
check(verifier_regles(M, check) == 0, "regles livrees : 0 ecart")

-- ===================================================================================================================
-- 2. Formes réelles de `dying_explosion` dans les prototypes de vanilla et du mod (lus dans les sources).
-- ===================================================================================================================
local vus = {
  "small-biter-die", "medium-biter-die", "big-biter-die", "behemoth-biter-die", "small-spitter-die",
  "blood-explosion-big", "big-explosion", "explosion", "massive-explosion",
}
for _, nom in ipairs(vus) do
  local p = { dying_explosion = nom }
  check(M.habiller(p) ~= nil and p.dying_explosion == nil, "forme chaine habillee : " .. nom)
end
-- robots.lua:303 : u.dying_explosion = class == "G" and "big-explosion" or "explosion" (chaîne) ; faction.lua:181 :
-- « blood-explosion-big » (chaîne) ; enemies.lua:120 : feu de l'Ignée dans dying_trigger_effect (gardé, vu en 1).

-- ===================================================================================================================
-- 3. Module de jeu sur un moteur simulé minimal.
-- ===================================================================================================================
local function charger_jeu(texte_jeu)
  local H = { effet = {}, nth = {} }
  local ST = {}
  package.loaded["script.core.events"] = {
    on = function(id, fn) H.effet[#H.effet + 1] = fn end,
    on_nth_tick = function(n, fn) H.nth[#H.nth + 1] = { n = n, fn = fn } end,
  }
  package.loaded["script.core.storage"] = {
    declare = function(ns, init) ST[ns] = init() end,
    ns = function(ns) return ST[ns] end,
  }
  local crees = {}
  local surfaces = {}
  for i = 1, 2 do
    surfaces[i] = { index = i, create_entity = function(t)
      crees[#crees + 1] = { s = i, name = t.name, x = t.position.x, y = t.position.y }
      return {}
    end }
  end
  local W = { joueurs = {} }
  _G.defines = { events = { on_script_trigger_effect = 42 } }
  _G.remote = { add_interface = function(nom, t) H.remote = t end }
  _G.game = {
    get_surface = function(i) return surfaces[i] end,
  }
  setmetatable(_G.game, { __index = function(_, k)
    if k == "connected_players" then
      local out = {}
      for i, j in ipairs(W.joueurs) do out[i] = { position = { x = j.x, y = j.y }, surface = surfaces[j.s] } end
      return out
    end
  end })
  local chunk = assert(load(texte_jeu, "=script/world/explosions_mort.lua"))
  chunk()
  package.loaded["script.core.events"], package.loaded["script.core.storage"] = nil, nil
  local J = {}
  function J.joueurs(l) W.joueurs = l end
  function J.releve() for _, h in ipairs(H.nth) do h.fn({ tick = 60 }) end end
  function J.effet(e) for _, fn in ipairs(H.effet) do fn(e) end end
  J.crees, J.H, J.ST = crees, H, ST
  return J
end

local function verifier_jeu(texte_jeu, chk)
  local n0 = 0
  local function c(cond, quoi, d) if not cond then n0 = n0 + 1 end; if chk then chk(cond, quoi, d) end end
  local J = charger_jeu(texte_jeu)
  c(#J.H.effet == 1 and #J.H.nth == 1 and J.H.nth[1].n == 60, "abonnements : un effet, un releve a 60 ticks")
  local s = J.ST.explosions_mort
  c(s and s.actif == true and s.joueurs == nil, "etat initial : actif, sans releve")
  -- avant le premier relevé : comme vanilla (créée)
  J.effet({ effect_id = "fo-mort|small-biter-die", surface_index = 1, target_position = { x = 5000, y = 0 } })
  c(#J.crees == 1 and J.crees[1].name == "small-biter-die" and J.crees[1].x == 5000, "sans releve : explosion creee")
  J.joueurs({ { s = 1, x = 0, y = 0 } })
  J.releve()
  c(s.joueurs and #s.joueurs == 1, "releve : un joueur")
  J.effet({ effect_id = "fo-mort|small-biter-die", surface_index = 1, target_position = { x = 100, y = -224 } })
  c(#J.crees == 2 and J.crees[2].y == -224, "a la borne : creee au point de la mort")
  J.effet({ effect_id = "fo-mort|blood-explosion-big", surface_index = 1, target_position = { x = 600, y = 0 } })
  c(#J.crees == 2 and s.loin == 1, "loin : rien, compte")
  J.effet({ effect_id = "fo-mort|a-die|b-die", surface_index = 1, source_position = { x = 10, y = 10 } })
  c(#J.crees == 4 and J.crees[3].name == "a-die" and J.crees[4].name == "b-die", "deux noms, point source")
  J.effet({ effect_id = "fo-mort|a-die", surface_index = 2, target_position = { x = 0, y = 0 } })
  c(#J.crees == 4 and s.loin == 2, "autre surface : loin")
  J.effet({ effect_id = "fo-tir", surface_index = 1, target_position = { x = 0, y = 0 } })
  J.effet({ effect_id = "fo-xp|rayon", surface_index = 1, target_position = { x = 0, y = 0 } })
  c(#J.crees == 4 and s.loin == 2, "effets des autres lots ignores")
  J.effet({ effect_id = "fo-mort|a-die", surface_index = 1, source_entity = { valid = true, position = { x = 3, y = 4 } } })
  c(#J.crees == 5 and J.crees[5].x == 3, "point repris de l'entite source")
  J.effet({ effect_id = "fo-mort|a-die", surface_index = 1, source_entity = { valid = false } })
  c(#J.crees == 5 and s.sans_point == 1, "sans point : rien, compte")
  -- témoin de banc : partout
  J.H.remote.actif(false)
  J.effet({ effect_id = "fo-mort|a-die", surface_index = 1, target_position = { x = 9000, y = 0 } })
  c(#J.crees == 6 and s.loin == 2, "actif = false : creee partout (temoin)")
  J.H.remote.actif(true)
  J.effet({ effect_id = "fo-mort|a-die", surface_index = 1, target_position = { x = 9000, y = 0 } })
  c(#J.crees == 6 and s.loin == 3, "actif = true : loin de nouveau")
  -- le joueur bouge : effet seulement au relevé suivant (état de jeu, pas la position du moment)
  J.joueurs({ { s = 1, x = 9000, y = 0 } })
  J.effet({ effect_id = "fo-mort|a-die", surface_index = 1, target_position = { x = 9000, y = 0 } })
  c(#J.crees == 6, "avant le releve suivant : position relevee, pas la position du moment")
  J.releve()
  J.effet({ effect_id = "fo-mort|a-die", surface_index = 1, target_position = { x = 9000, y = 0 } })
  c(#J.crees == 7, "apres le releve : proche")
  -- aucun joueur connecté : comme vanilla
  J.joueurs({})
  J.releve()
  J.effet({ effect_id = "fo-mort|a-die", surface_index = 1, target_position = { x = -7000, y = 0 } })
  c(#J.crees == 8, "aucun joueur connecte : creee (bancs sans joueur inchanges)")
  local st = J.H.remote.stats()
  c(st.crees == 8 and st.loin == 4 and st.sans_point == 1 and st.joueurs == 0 and st.ratees == 0, "stats de l'interface",
    string.format("crees %d loin %d sans_point %d joueurs %d", st.crees, st.loin, st.sans_point, st.joueurs))
  -- espace « explosions_mort » absent (sauvegarde d'avant le lot, avant son on_configuration_changed ; moteur réel, 7/11 : le
  -- on_init d'un mod ajouté passe avant) : interface et événements sans erreur, rien de créé
  J.ST.explosions_mort = nil
  local ok1, s2 = pcall(J.H.remote.stats)
  c(ok1 and s2 and s2.crees == 0 and s2.joueurs == -1, "stats sans espace : sans erreur, a zero", tostring(s2))
  c(pcall(J.H.remote.actif, false) and pcall(J.H.remote.releve), "actif et releve sans espace : sans erreur")
  local n_avant = #J.crees
  c(pcall(J.effet, { effect_id = "fo-mort|a-die", surface_index = 1, target_position = { x = 0, y = 0 } })
    and #J.crees == n_avant, "mort sans espace : sans erreur, rien de cree")
  return n0
end

local TEXTE_REGLES = lire("shared/explosions_mort/regles.lua")
local TEXTE_JEU = lire("script/world/explosions_mort.lua")
check(verifier_jeu(TEXTE_JEU, check) == 0, "module de jeu livre : 0 ecart")

-- ===================================================================================================================
-- 4. Mutants : chacun doit être VU (au moins un écart).
-- ===================================================================================================================
local function charger_regles(texte)
  return assert(load(texte, "=shared/explosions_mort/regles.lua"))()
end
local MUT_REGLES = {
  { "borne exclue", "x <= j.x + r", "x < j.x + r" },
  { "sans joueur : loin", "if joueurs == nil or #joueurs == 0 then return true end", "if joueurs == nil then return true end" },
  { "surface ignoree", "if j.s == s and", "if true and" },
  { "existant perdu", "if dte.type ~= nil then return { dte, eff } end", "if dte.type ~= nil then return { eff } end" },
  { "dying_explosion garde", "  p.dying_explosion = nil\n", "" },
  { "decalage accepte", "if k ~= \"name\" then return nil end", "if false then return nil end" },
  { "prefixe non controle", "effect_id:sub(1, #M.PREFIXE) ~= M.PREFIXE", "false" },
  { "rayon 96 (celui des tirs)", "M.RAYON = 224", "M.RAYON = 96" },
  { "tourelles reprises (type turret)", "M.TYPES = { \"unit\" }", "M.TYPES = { \"turret\", \"unit\" }" },
}
for _, mu in ipairs(MUT_REGLES) do
  local Mm = charger_regles(remplacer(TEXTE_REGLES, mu[2], mu[3]))
  check(verifier_regles(Mm, nil) > 0, "mutant vu (regles) : " .. mu[1])
end
local MUT_JEU = {
  { "temoin ignore", "if s.actif and not M.proche", "if not M.proche" },
  { "rayon des tirs", "M.RAYON) then", "96) then" },
  { "releve ignore", "if s.actif and not M.proche(s.joueurs,", "if s.actif and not M.proche(nil," },
  { "point source ignore", "local pos = e.target_position or e.source_position", "local pos = e.target_position" },
  { "un seul nom", "for i = 1, #noms do", "for i = 1, 1 do" },
  { "stats sans garde (erreur du 7/11 en moteur reel)", "    if not s then return { actif = nil,", "    if false then return { actif = nil," },
  { "actif sans garde", "    if s then s.actif = v and true or false end", "    s.actif = v and true or false" },
}
for _, mu in ipairs(MUT_JEU) do
  check(verifier_jeu(remplacer(TEXTE_JEU, mu[2], mu[3]), nil) > 0, "mutant vu (jeu) : " .. mu[1])
end

print(string.format("[EXPLOSIONS-MORT] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
