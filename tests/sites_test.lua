--[[
  Tests hors jeu de la détection des gisements (lot SITES, 27/10).
  Usage, depuis la racine du mod :   lua5.2 tests/sites_test.lua

  Cause racine prouvée en moteur réel (trace [FO-SITES], fo-logs/2026-10-27_SITES/trace1) : script/faction/sites.lua
  imposait 40 tuiles entre TOUS les sites, quelle que soit la ressource. Le cuivre de votre équipe, à 27 tuiles du
  charbon retenu au tick 0, était refusé (« espacement »), la pierre à 14 tuiles aussi ; ils partaient chercher à 263
  et 185 tuiles.

  Vérifie :
    1. règle pure (shared/faction/valeur.lua) : 32 tuiles entre ressources différentes acceptées, entre ressources
       identiques refusées ; la distance minimale découle des RAYONS des sites (monotone, bornée à 40) ; ressource
       inconnue : 40 ; 6 mutants de la règle refusés ;
    2. prospection en moteur simulé : cuivre à 27 tuiles du charbon retenu, charbon à 27 tuiles du charbon refusé,
       motif tracé (« [FO-SITES] refus ... espacement ») ;
    3. revendications : un site de ressource différente à 27 tuiles d'une revendication est libre, un site de la même
       ressource est pris ; une ancienne entrée sans ressource est migrée depuis l'avant-poste qui la détient (sans
       avant-poste : prudence, 40 tuiles).
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local V = require("shared.faction.valeur")

---------------------------------------------------------------------------------------------------
section("Règle d'espacement (pure)")
local function rule(V_, label)
  local a = { x = 0, y = 0, resource = "coal", radius = 12 }
  local b_other = { x = 32, y = 0, resource = "copper-ore", radius = 12 }
  local b_same = { x = 32, y = 0, resource = "coal", radius = 12 }
  local ok = {}
  ok[1] = not V_.too_close(a, b_other)   -- 32 tuiles, ressources différentes : accepté
  ok[2] = V_.too_close(a, b_same)        -- 32 tuiles, même ressource : refusé
  ok[3] = V_.too_close({ x = 0, y = 0, resource = "coal", radius = 20 }, { x = 32, y = 0, resource = "stone", radius = 20 })
  -- rayons de 20 + 20 = 40 : 32 tuiles trop près (la distance découle des rayons)
  ok[4] = V_.spacing({ resource = "coal", radius = 8 }, { resource = "stone", radius = 8 }) == 16
  ok[5] = V_.spacing({ resource = "coal", radius = 30 }, { resource = "stone", radius = 30 }) == V_.SPACING_SAME
  ok[6] = V_.spacing({ resource = "coal" }, { resource = "stone" }) == 2 * V_.RADIUS_MIN
  ok[7] = V_.spacing({ resource = "coal", radius = 3 }, { resource = "coal", radius = 3 }) == V_.SPACING_SAME
  ok[8] = V_.spacing({ x = 0, y = 0 }, { resource = "coal", radius = 3 }) == V_.SPACING_SAME -- ressource inconnue : prudence
  ok[9] = not V_.too_close(a, { x = 40, y = 0, resource = "coal", radius = 12 }) -- 40 tuiles même ressource : libre (strict)
  ok[10] = V_.spacing({ resource = "coal", radius = 9 }, { resource = "stone", radius = 9 }) < V_.spacing({ resource = "coal", radius = 10 }, { resource = "stone", radius = 10 })
  for i = 1, 10 do check(ok[i], label .. " : propriété " .. i) end
  return ok
end
rule(V, "règle")

-- Mutants : chacun doit être refusé par au moins une propriété.
local function mutant(name, patch)
  local m = setmetatable({}, { __index = V })
  patch(m)
  local before = failures
  -- compte les échecs sans les imprimer
  local saved_print = print
  print = function() end
  rule(m, name)
  print = saved_print
  local caught = failures > before
  failures = before          -- les échecs des mutants ne comptent pas
  passes = passes + (caught and 1 or 0)
  if not caught then failures = failures + 1; print("  ECHEC : mutant non refusé : " .. name) end
end
mutant("espacement uniforme 40", function(m) m.spacing = function() return 40 end end)
mutant("jamais trop près", function(m) m.too_close = function() return false end end)
mutant("rayons ignorés (12 fixe)", function(m)
  m.spacing = function(a, b) if a.resource == b.resource then return 40 end return 12 end
end)
mutant("sans plafond à 40", function(m)
  m.spacing = function(a, b)
    if a.resource == b.resource then return 40 end
    return V.site_radius(a) + V.site_radius(b)
  end
end)
mutant("même ressource libre", function(m)
  m.spacing = function(a, b) return V.site_radius(a) + V.site_radius(b) end
end)
mutant("ressource inconnue libre", function(m)
  m.spacing = function(a, b)
    if a.resource == nil or b.resource == nil then return 0 end
    return V.spacing(a, b)
  end
end)

---------------------------------------------------------------------------------------------------
section("Prospection et revendications (moteur simulé)")
local function start()
  M.new_game({ seed = 4242, patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
  M.command("fo-war", "start 2 100 10 320")
  return global.fo.war
end

local war = start()
local Sites = require("script.faction.sites")
local State = require("script.faction.state")
local f = war.factions[1]
local hq = f.hq_pos
local W = M.world()

-- Gisements autour du QG : charbon A à 60 tuiles, cuivre à 27 tuiles de A, charbon B à 27 tuiles de A, pierre à 14
-- tuiles de A (rayon des gisements simulés : 6).
local function pos(dx, dy) return { x = math.floor(hq.x + dx) + 0.5, y = math.floor(hq.y + dy) + 0.5 } end
local A = pos(-60, -50)
W.patches[#W.patches + 1] = { x = A.x, y = A.y, name = "coal", amount = 50000 }
W.patches[#W.patches + 1] = { x = A.x, y = A.y + 27, name = "copper-ore", amount = 50000 }
W.patches[#W.patches + 1] = { x = A.x + 27, y = A.y, name = "coal", amount = 50000 }
W.patches[#W.patches + 1] = { x = A.x - 14, y = A.y - 14, name = "stone", amount = 50000 }

local function logs(pattern)
  local out = {}
  for _, l in ipairs(W.logs) do if l:find(pattern, 1, true) then out[#out + 1] = l end end
  return out
end

local function scan(fct, needs)
  Sites.seen_filter = nil -- pas de brouillard dans ce banc (le crochet est celui d IA3-f)
  fct.prospects = {}
  fct.site_needs = needs
  fct.site_cursor, fct.prospect_wide, fct.prospect_idle_until = 1, nil, 0
  fct.scan_idle = false
  for _ = 1, 400 do Sites.prospect(fct, game.surfaces[war.surface], game.tick) end
end

-- site_needs est indexé par ressource (nom du prototype de minerai).
-- (les gisements de départ de la faction, loin de A, sont ignorés : on compte autour de A)
local function count(fct, res)
  local n = 0
  for _, s in ipairs(fct.prospects) do
    if s.resource == res and (s.x - A.x) ^ 2 + (s.y - A.y) ^ 2 < 80 * 80 then n = n + 1 end
  end
  return n
end

scan(f, { coal = 1, ["copper-ore"] = 1, stone = 1 })
check(count(f, "coal") >= 1, "charbon retenu (" .. count(f, "coal") .. ")")
check(count(f, "copper-ore") == 1, "cuivre à 27 tuiles du charbon retenu (" .. count(f, "copper-ore") .. ")")
local coal_site
for _, s in ipairs(f.prospects) do if s.resource == "coal" then coal_site = s end end
check(coal_site and coal_site.radius and coal_site.radius >= 1, "le site porte son rayon (étendue des tuiles lues)")

scan(f, { coal = 2 })
check(count(f, "coal") == 1, "charbon à 27 tuiles d'un charbon retenu : refusé, un seul site de charbon (" .. count(f, "coal") .. ")")
check(#logs("[FO-SITES] refus tick") >= 1 and #logs("motif espacement") >= 1, "refus tracé : motif espacement")

-- Revendications.
local site_coal = { x = A.x, y = A.y, resource = "coal", radius = 6 }
Sites.release(site_coal)
Sites.claim(f, site_coal)
local cu = { x = A.x, y = A.y + 27, resource = "copper-ore", radius = 6 }
local co = { x = A.x + 27, y = A.y, resource = "coal", radius = 6 }
check(Sites.available(f, "copper-ore") >= 0, "contrôle de l'interface")
f.prospects = { cu, co }
local got = Sites.find(f, game.surfaces[war.surface], game.tick, "copper-ore")
check(got == cu, "revendication de charbon : le cuivre à 27 tuiles est libre")
f.prospects = { co }
got = Sites.find(f, game.surfaces[war.surface], game.tick, "coal")
check(got == nil, "revendication de charbon : un autre charbon à 27 tuiles est pris")
Sites.release(site_coal)

-- Ancienne entrée (avant le lot SITES) : position seule, ressource lue sur l'avant-poste qui la détient.
local key = State.site_key(site_coal)
war.claims[key] = f.id
war.claim_pos = war.claim_pos or {}
war.claim_pos[key] = { x = A.x, y = A.y }
f.outposts = f.outposts or {}
f.prospects = { cu }
got = Sites.find(f, game.surfaces[war.surface], game.tick, "copper-ore")
check(got == nil, "ancienne entrée sans ressource ni avant-poste : prudence (cuivre à 27 tuiles pris)")
f.prospects = { cu }
f.outposts[9001] = { pos = { x = A.x, y = A.y }, kind = "coal", drills = 1 }
got = Sites.find(f, game.surfaces[war.surface], game.tick, "copper-ore")
check(got == cu, "ancienne entrée migrée depuis l'avant-poste de charbon : cuivre à 27 tuiles libre")
check(war.claim_pos[key].resource == "coal", "ressource migrée écrite dans claim_pos")
f.prospects = { co }
got = Sites.find(f, game.surfaces[war.surface], game.tick, "coal")
check(got == nil, "entrée migrée : charbon à 27 tuiles toujours pris")
f.outposts[9001] = nil
Sites.release(site_coal)

print(string.format("\n[SITES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
