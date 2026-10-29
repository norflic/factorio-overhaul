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

-- Mémoire d'échec par site (graine 1618033988 : un site remis en boucle à l'ouvrier toutes les 35 s pendant toute la partie).
do
  local surf = game.surfaces[war.surface]
  local T0 = 100000
  local site = { x = A.x, y = A.y + 27, resource = "copper-ore", radius = 6 }
  local function give(tick)
    f.prospects = { site }
    return Sites.find(f, surf, tick, "copper-ore")
  end
  f.site_fail, f.stats.site_backoff = nil, nil
  Sites.release(site)
  war.unreachable = {}
  check(give(T0) == site, "1re remise : le site est donné")
  check(give(T0 + 2100) == site, "2e remise sans revendication : donné encore (une seconde chance)")
  check(give(T0 + 4200) == nil, "3e remise sans revendication : écarté")
  check((f.stats.site_backoff or 0) == 1 and #logs("[FO-SITES] ecarte") >= 1, "écart compté et tracé")
  check(give(T0 + 4300) == nil, "écarté : plus donné pendant l'attente (injoignable)")
  check(give(T0 + 4200 + 5 * 3600 - 10) == nil, "toujours écarté juste avant la fin de l'attente (5 min)")
  check(give(T0 + 4200 + 5 * 3600 + 10) == site, "attente finie : un nouvel essai")
  check(give(T0 + 4200 + 5 * 3600 + 2100) == nil, "nouvel échec : écarté de nouveau")
  local until1 = war.unreachable[State.site_key(site)] - (T0 + 4200 + 5 * 3600 + 2100)
  check(until1 == 10 * 3600, "attente doublée (" .. until1 / 3600 .. " min)")
  -- Une revendication (l'ouvrier a franchi les contrôles) remet le compte à zéro.
  f.site_fail, war.unreachable = nil, {}
  check(give(T0 + 900000) == site, "compte neuf : donné")
  Sites.claim(f, site)
  Sites.release(site)
  check(give(T0 + 902000) == site and give(T0 + 904000) == site, "après une revendication : deux remises de plus tolérées")
  -- Faction : même règle sur le choix par valeur.
  local g = war.factions[2]
  g.site_fail, g.prospects = nil, nil
  local cu2 = { x = g.hq_pos.x + 60, y = g.hq_pos.y, resource = "copper-ore", radius = 6, rich = 50000, tiles = 20 }
  local got = {}
  for i = 1, 4 do
    g.prospects = { cu2 }
    got[i] = Sites.find(g, surf, T0 + 910000 + i * 2100, "copper-ore")
  end
  check(got[1] == cu2 and got[2] == cu2 and got[3] == nil, "faction : donné deux fois, puis écarté")
end

---------------------------------------------------------------------------------------------------
-- Lot SITE-PROCHE (29/10) : plancher de valeur, site proche bloqué (suspension du lointain), signal f.site_blocked
-- Constat du DC : Emeraude partait chercher du charbon à 201-357 tuiles pendant que le gisement à 45 tuiles, écarté 30 min
-- pour un ennemi vu une fois, était « injoignable » ; le choix ne refusait jamais un site (valeur -2 083 observée).
---------------------------------------------------------------------------------------------------
section("Site proche bloqué, plancher, signal (lot SITE-PROCHE)")
do
  local surf = game.surfaces[war.surface]
  local g = war.factions[2]
  local ghq = g.hq_pos
  local saved_traits = g.traits
  g.traits = nil -- ambition 1 000 : portée 220 tuiles, valeurs de test indépendantes du caractère tiré
  local TK = 500000
  local function coal(d, rich) return { x = ghq.x - d, y = ghq.y, resource = "coal", radius = 6, rich = rich, tiles = 60 } end
  local function reset()
    war.unreachable, war.claims, war.claim_pos = {}, {}, {}
    g.prospects, g.site_block, g.site_blocked, g.lost_sites, g.site_fail = {}, nil, nil, {}, nil
    for _, k in ipairs({ "plancher", "suspendu", "refus" }) do g.stats[k] = nil end
    g.stats.site_block_logged = nil
  end
  local function nlogs(p) return #logs(p) end

  -- 1. Un site lointain RICHE (valeur -106, au-dessus du plancher), seul : admissible, distance rendue.
  reset()
  local near, far = coal(45, 10000000), coal(201, 10000000)
  g.prospects = { far }
  local n, d = Sites.available(g, "coal", TK)
  check(n == 1 and d == 201, "lointain seul : un site admissible, distance au QG rendue (" .. tostring(n) .. ", " .. tostring(d) .. ")")
  check(g.site_blocked == nil or g.site_blocked.coal == nil, "aucun signal sans site proche bloqué")

  -- 2. Le site proche devient injoignable (hostile, injoignable : même mémoire) : le lointain est SUSPENDU, le signal est
  --    posé, la trace est écrite UNE fois, le site lointain reste en réserve.
  g.prospects = { near, far }
  Sites.mark_unreachable(near, TK)
  n, d = Sites.available(g, "coal", TK)
  check(n == 0 and d == nil, "proche injoignable : le lointain à 201 tuiles est suspendu (" .. tostring(n) .. ")")
  local sig = g.site_blocked and g.site_blocked.coal
  check(sig and sig.why == "injoignable" and sig.d_blocked == 45 and sig.n == 1 and sig.until_tick == TK + 108000,
    "signal f.site_blocked.coal : site proche, motif, échéance, nombre de sites suspendus")
  check(nlogs("[FO-SITES] suspendu tick") == 1 and nlogs("site proche (") == 1, "trace [FO-SITES] suspendu écrite une fois")
  Sites.available(g, "coal", TK + 60)
  check(nlogs("[FO-SITES] suspendu tick") == 1, "pas de nouvelle ligne pour le même blocage")
  local got = Sites.find(g, surf, TK + 60, "coal")
  check(got == nil, "find : aucun ouvrier envoyé au lointain tant que le proche est bloqué")
  check(#g.prospects == 1 and g.prospects[1] == far, "le lointain suspendu reste en réserve, le proche invalide en est retiré")
  n = Sites.available(g, "coal", TK + 120)
  check(n == 0 and (g.site_blocked or {}).coal ~= nil, "la mémoire garde le blocage après le retrait du proche de la réserve")
  check(Sites.best_value(g, TK + 120) == nil, "valeur du meilleur site connu : nil (rien d'admissible pour le chef)")

  -- 3. Fin du blocage : le lointain redevient admissible, le signal tombe, la trace le dit.
  n, d = Sites.available(g, "coal", TK + 108000 + 1)
  check(n == 1 and d == 201, "blocage fini : le lointain est de nouveau admissible")
  check((g.site_blocked or {}).coal == nil and nlogs("[FO-SITES] debloque tick") == 1, "signal retiré et trace [FO-SITES] debloque")
  got = Sites.find(g, surf, TK + 108000 + 1, "coal")
  check(got == far, "find : le lointain est puisé une fois le blocage fini")

  -- 4. Un site proche bloqué d'une AUTRE ressource ne suspend rien.
  reset()
  local cu_near = { x = ghq.x - 45, y = ghq.y, resource = "copper-ore", radius = 6, rich = 10000000, tiles = 60 }
  g.prospects = { cu_near, far }
  Sites.mark_unreachable(cu_near, TK)
  n = Sites.available(g, "coal", TK)
  check(n == 1 and (g.site_blocked == nil or g.site_blocked.coal == nil), "cuivre proche bloqué : le charbon lointain n'est pas suspendu")

  -- 5. Un site à la limite (105 tuiles pour un proche à 45) n'est pas suspendu ; un à 130 l'est.
  reset()
  local mid_ok, mid_far = coal(105, 10000000), coal(130, 10000000)
  g.prospects = { near, mid_ok, mid_far }
  Sites.mark_unreachable(near, TK)
  n, d = Sites.available(g, "coal", TK)
  check(n == 1 and d == 105, "limite 1,5 × d ou d + 60 : le site à 105 reste, celui à 130 est suspendu (" .. tostring(n) .. ", " .. tostring(d) .. ")")

  -- 6. Le plancher : un site de valeur < V.FLOOR n'est ni compté ni puisé, reste en réserve, tracé une fois ; un gisement
  --    de départ garanti (seeded) n'y est pas soumis.
  reset()
  local poor = coal(201, 100000)
  g.prospects = { poor }
  local comp = V.components(poor, Sites.value_ctx(g, TK))
  check(comp.value < V.FLOOR, "site de test sous le plancher (valeur " .. comp.value .. ")")
  n = Sites.available(g, "coal", TK)
  check(n == 0, "sous le plancher : non compté")
  Sites.available(g, "coal", TK + 10)
  check(nlogs("[FO-SITES] plancher tick") == 1 and (g.stats.plancher or 0) == 1, "sous le plancher : tracé une seule fois")
  check(Sites.find(g, surf, TK, "coal") == nil and #g.prospects == 1, "sous le plancher : jamais puisé, gardé en réserve")
  poor.seeded = true
  check(Sites.available(g, "coal", TK) == 1 and Sites.find(g, surf, TK, "coal") == poor, "gisement de départ garanti : hors plancher")

  -- 7. Un site PERDU récemment (revenu à la réserve) compte comme site proche bloqué pour le lointain.
  reset()
  local lost = coal(45, 10000000)
  lost.lost = true
  g.prospects = { lost, far }
  g.lost_sites = { { x = lost.x, y = lost.y, tick = TK - 100 } }
  n = Sites.available(g, "coal", TK)
  local cl = V.components(lost, Sites.value_ctx(g, TK))
  check(g.site_blocked and g.site_blocked.coal and g.site_blocked.coal.why == "perte" and g.site_blocked.coal.d_blocked == 45,
    "site perdu récent : signal motif perte")
  check(n == (cl.value >= V.FLOOR and 1 or 0), "le perdu (valeur " .. cl.value .. ") est lui-même compté s'il est au-dessus du plancher, le lointain est suspendu")
  n = Sites.available(g, "coal", TK + V.LOST_TTL + 1)
  check((g.site_blocked or {}).coal == nil and n == 2, "perte oubliée après V.LOST_TTL : les deux sites admissibles")

  -- 8. Probe : un chunk injoignable est retenu comme site bloqué, même journal de refus plein.
  reset()
  g.stats.refus_logged = 400
  local pc = coal(45, 10000000)
  W.patches[#W.patches + 1] = { x = pc.x, y = pc.y, name = "coal", amount = 500000 }
  Sites.mark_unreachable(pc, game.tick)
  g.site_needs = { coal = 2 }
  g.site_cursor, g.prospect_wide, g.prospect_idle_until, g.scan_idle = 1, nil, 0, false
  Sites.seen_filter = nil
  for _ = 1, 400 do Sites.prospect(g, surf, game.tick) end
  local mem = g.site_block and g.site_block[1]
  check(mem and mem.resource == "coal" and mem.why == "injoignable", "prospection : chunk injoignable retenu bloqué (journal des refus plein)")
  g.stats.refus_logged = nil
  W.patches[#W.patches] = nil

  -- 8 bis. Mémoire des blocages pleine : on oublie le plus LOINTAIN, jamais le proche noté le premier (relecture).
  reset()
  g.site_block = nil
  local nearest = coal(45, 10000000)
  Sites.mark_unreachable(nearest, TK)
  g.prospects = { nearest, coal(201, 10000000) }
  Sites.available(g, "coal", TK) -- le proche injoignable est retenu en premier
  for i = 1, 40 do -- 40 chunks injoignables plus loin (voisinage hostile), tous notés après le proche
    local far_i = { x = ghq.x - 120 - 32 * i, y = ghq.y + 64, resource = "iron-ore", radius = 6, rich = 1000000, tiles = 60 }
    Sites.mark_unreachable(far_i, TK)
    g.prospects[#g.prospects + 1] = far_i
    Sites.available(g, "iron-ore", TK)
  end
  local kept = false
  for _, e in ipairs(g.site_block or {}) do if e.resource == "coal" and e.x == nearest.x then kept = true end end
  check(kept and #g.site_block <= 16, "mémoire pleine : le blocage du site proche est gardé (" .. #(g.site_block or {}) .. " entrées)")
  check(select(1, Sites.available(g, "coal", TK)) == 0, "le charbon lointain reste suspendu après 40 blocages plus loin")

  -- 9. L'équipe du joueur garde la règle d'avant : compte brut, un seul résultat, rien de signalé.
  local pf = { is_player = true, key = "player", prospects = { near, far }, stats = {} }
  check(Sites.available(pf, "coal", TK) == 2 and select(2, Sites.available(pf, "coal", TK)) == nil, "joueur : compte brut, sans distance")
  check(Sites.available(g, nil) == (g.prospects and #g.prospects or 0), "sans ressource : compte brut")
  g.site_blocked, g.site_block = nil, nil
  g.traits = saved_traits
  war.unreachable = {}
end

print(string.format("\n[SITES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
