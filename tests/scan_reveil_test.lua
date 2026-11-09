--[[
  Lot SCAN-EVENEMENTS (directive du DC du 9/11) : déclencheurs événementiels d'un scan de requalification (script/team/scan_reveil.lua).
    §1 palier de stock : franchi À LA HAUSSE seulement, par pièce de TYPE inserter / transport-belt / assembling-machine (types de prototypes,
       aucun nom), depuis le dernier relevé ; une baisse ne réveille pas mais remet le palier ; déterminisme ;
    §2 énergie : transition vrai → faux de f.build.sante.healthy, et elle seule ; ressource : transition faux → vrai de Famine.team_starved ;
    §3 recherche : on_research_finished réveille chaque équipe de la force (abonnement statique) ; force inconnue : personne ;
    §4 Sr.think : plusieurs causes dans une pensée → un seul réveil (le premier), les autres comptés ; état f.team.scan en données pures ;
    §5 mutants : palier à la baisse qui réveille, seuil « ≥ » au lieu d'un franchissement, type ignoré, transition sans mémoire ;
    §6 câblage textuel : team.lua appelle Build.Hygiene.reveil à E6 ; hygiene.lua consomme St.due / St.ack et journalise [FO-SCAN] ;
       aucun nom d'objet du jeu dans scan_reveil.lua.
  Usage : lua5.2 tests/scan_reveil_test.lua   (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function section(name) print("== " .. name) end

-- Doublures (chargées AVANT le module ; aucune n'est le vrai module)
local subs = {}
package.loaded["script.core.events"] = { on = function(id, fn) subs[id] = fn end }
local factions = {}
package.loaded["script.faction.state"] = {
  alive = function()
    local ids = {}
    for id, f in pairs(factions) do if id ~= "player" and not f.eliminated then ids[#ids + 1] = id end end
    table.sort(ids)
    return ids
  end,
  faction = function(id) return factions[id] end,
}
local starved = {} -- [clé] = famine simulée
package.loaded["script.team.famine_fer"] = { team_starved = function(f) return starved[f.key] == true end }
defines = { events = { on_research_finished = 2 } } -- luacheck: ignore

local Sr = require("script.team.scan_reveil")
local St = require("shared.team.scan_tranches")
check(type(subs[2]) == "function", "abonnement statique à on_research_finished au chargement")

-- Prototypes simulés : l'objet « a » pose un inserter, « b » un transport-belt, « c » une assembling-machine, « d » un four, « e » ne pose rien
local KINDS = { a = "inserter", b = "transport-belt", c = "assembling-machine", d = "furnace" }
Sr.kind_of = function(item) return KINDS[item] end
local function team(key, force) return { key = key, force = force, team = {}, build = { sante = { healthy = true } } } end

---------------------------------------------------------------------------------------------------
section("§1 palier de stock : à la hausse seulement, par type, depuis le dernier relevé")
---------------------------------------------------------------------------------------------------
check(Sr.CFG.step == 50, "pas de 50 unités")
check(Sr.palier(0, 50) == 0 and Sr.palier(49, 50) == 0 and Sr.palier(50, 50) == 1 and Sr.palier(149, 50) == 2, "palier = quotient par le pas")
local f = team(1, "f1")
local st = Sr.state(f)
check(st == f.team.scan and type(st.stock) == "table" and st.reveils == 0, "état créé au premier usage dans f.team.scan")
local up = Sr.stock_crossings(st, { a = 12, b = 30, c = 0, d = 500, e = 999 })
check(#up == 0 and st.stock.a == 0 and st.stock.d == nil and st.stock.e == nil, "sous le palier : rien ; le four et l'objet sans entité ne sont pas suivis")
up = Sr.stock_crossings(st, { a = 50, b = 30 })
check(#up == 1 and up[1] == "a" and st.stock.a == 1, "a passe 50 : palier 1 franchi à la hausse")
up = Sr.stock_crossings(st, { a = 73, b = 49 })
check(#up == 0, "a à 73 : même palier, rien")
up = Sr.stock_crossings(st, { a = 20, b = 49 })
check(#up == 0 and st.stock.a == 0, "a redescend à 20 : pas de réveil, palier remis à 0")
up = Sr.stock_crossings(st, { a = 51, b = 100, c = 150 })
check(#up == 3 and up[1] == "a" and up[2] == "b" and up[3] == "c", "trois pièces montent : liste triée a, b, c")
up = Sr.stock_crossings(st, { a = 51, b = 100 })
check(#up == 0 and st.stock.c == 3, "c absent du stock : son palier est gardé (pas de baisse comptée sans relevé)")
up = Sr.stock_crossings(st, {})
check(#up == 0, "stock vide : rien")
-- première observation d'un stock déjà haut : réveil (requalification due)
local f0 = team(9, "f9")
up = Sr.stock_crossings(Sr.state(f0), { a = 120 })
check(#up == 1, "première observation avec 120 bras : palier 2 franchi depuis 0")
-- déterminisme : deux équipes, même suite de stocks, mêmes réponses
local g1, g2 = Sr.state(team(2, "x")), Sr.state(team(3, "y"))
local same = true
for _, s in ipairs({ { a = 10 }, { a = 60, b = 50 }, { a = 10 }, { a = 55 } }) do
  local u1, u2 = Sr.stock_crossings(g1, s), Sr.stock_crossings(g2, s)
  if #u1 ~= #u2 then same = false end
  for i = 1, #u1 do if u1[i] ~= u2[i] then same = false end end
end
check(same, "même suite de stocks : mêmes franchissements")

---------------------------------------------------------------------------------------------------
section("§2 énergie (vrai → faux) et ressource (faux → vrai)")
---------------------------------------------------------------------------------------------------
local e = {}
check(not Sr.energy_cut(e, nil) and e.healthy == nil, "santé inconnue : rien, rien gardé")
check(not Sr.energy_cut(e, false) and e.healthy == false, "première lecture déjà en panne : pas une transition")
check(not Sr.energy_cut(e, true) and e.healthy == true, "retour à la santé : rien")
check(Sr.energy_cut(e, false) == true and e.healthy == false, "vrai → faux : coupure")
check(not Sr.energy_cut(e, false), "faux → faux : rien (pas de réveil en boucle)")
check(not Sr.energy_cut(e, nil) and e.healthy == false, "lecture absente : l'état gardé ne bouge pas")
local r = {}
check(not Sr.resource_cut(r, true) and r.starved == true, "première lecture déjà en famine : pas une transition")
check(not Sr.resource_cut(r, false) and r.starved == false, "sortie de famine : rien")
check(Sr.resource_cut(r, true) == true, "faux → vrai : rupture")
check(not Sr.resource_cut(r, true), "vrai → vrai : rien")

---------------------------------------------------------------------------------------------------
section("§3 recherche finie : réveil de chaque équipe de la force")
---------------------------------------------------------------------------------------------------
local fa, fb, fp = team(2, "f1"), team(5, "f3"), team("player", "player")
factions[2], factions[5], factions.player = fa, fb, fp
check(Sr.research_done({ valid = true, name = "f3" }, 1000) == 1 and fb.team.scan.wake.why == "recherche" and fb.team.scan.wake.tick == 1000,
  "force f3 : l'équipe 5 réveillée (recherche, tick 1000)")
check(fa.team.scan == nil and fp.team.scan == nil, "les autres équipes : rien")
subs[2]({ research = { force = { valid = true, name = "player" } }, tick = 1200 })
check(fp.team.scan and fp.team.scan.wake.why == "recherche", "par l'événement : votre équipe (force player) réveillée")
check(Sr.research_done({ valid = true, name = "inconnue" }, 1300) == 0, "force sans équipe : personne")
check(Sr.research_done(nil, 1300) == 0 and Sr.research_done({ valid = false, name = "f3" }, 1300) == 0, "force nulle ou invalide : personne")
check(Sr.research_done({ valid = true, name = "f3" }, 1400) == 0 and fb.team.scan.wake.n == 2 and fb.team.scan.wake.tick == 1000,
  "second réveil avant service : compté (n = 2), le premier gardé, pas « nouveau »")

---------------------------------------------------------------------------------------------------
section("§4 Sr.think : trois causes, un réveil ; état pur")
---------------------------------------------------------------------------------------------------
local fc = team(7, "f7")
check(Sr.think(fc, { a = 10 }, 100) == nil and fc.team.scan.healthy == true and fc.team.scan.starved == false, "première pensée : rien, états relevés")
fc.build.sante.healthy = false
starved[7] = true
check(Sr.think(fc, { a = 60 }, 400) == "stock" and fc.team.scan.wake.why == "stock" and fc.team.scan.wake.n == 3 and fc.team.scan.reveils == 1,
  "stock + energie + ressource dans la même pensée : réveil « stock » posé, 3 causes comptées, 1 réveil")
St.ack(fc.team.scan, 420, "stock")
check(Sr.think(fc, { a = 60 }, 700) == nil, "rien de neuf : pas de réveil")
fc.build.sante.healthy = true
starved[7] = false
check(Sr.think(fc, { a = 60 }, 1000) == nil, "retour à la normale : pas de réveil")
fc.build.sante.healthy = false
check(Sr.think(fc, { a = 60 }, 1300) == "energie", "nouvelle coupure : réveil « energie »")
check(Sr.think(team(8, "f8"), nil, 10) == nil, "stock absent : rien, pas d'erreur")
check(Sr.think({ key = 1 }, {}, 10) == nil, "équipe sans f.team : rien")
local function pure(t)
  for k, v in pairs(t) do
    local tv = type(v)
    if tv == "table" then if not pure(v) then return false end
    elseif tv ~= "number" and tv ~= "boolean" and tv ~= "string" then return false end
    if type(k) == "function" or type(k) == "userdata" then return false end
  end
  return true
end
check(pure(fc.team.scan) and pure(fb.team.scan), "f.team.scan : nombres, booléens, chaînes")

---------------------------------------------------------------------------------------------------
section("§5 mutants (mêmes détecteurs)")
---------------------------------------------------------------------------------------------------
--- Détecteur du palier : la suite 10 → 60 → 10 → 55 doit donner exactement 2 franchissements (60 et 55), aucun à la baisse.
local function crossings_of(fn)
  local s, n = { stock = {} }, 0
  for _, q in ipairs({ { a = 10 }, { a = 60 }, { a = 10 }, { a = 55 }, { a = 55 } }) do n = n + #fn(s, q) end
  return n
end
check(crossings_of(Sr.stock_crossings) == 2, "règle : 2 franchissements")
local function mut_baisse(s, stock) -- mutant : tout changement de palier réveille
  local up = {}
  for item, q in pairs(stock) do
    local p = Sr.palier(q, 50)
    if p ~= (s.stock[item] or 0) then up[#up + 1] = item end
    s.stock[item] = p
  end
  return up
end
check(crossings_of(mut_baisse) ~= 2, "mutant « la baisse réveille aussi » refusé")
local function mut_seuil(s, stock) -- mutant : seuil « au-dessus de 50 » sans mémoire
  local up = {}
  for item, q in pairs(stock) do if q >= 50 then up[#up + 1] = item end end
  return up
end
check(crossings_of(mut_seuil) ~= 2, "mutant « seuil sans franchissement » refusé (réveil à chaque pensée)")
local function mut_type(s, stock) -- mutant : le type n'est pas regardé
  local up = {}
  for item, q in pairs(stock) do
    local p = Sr.palier(q, 50)
    if p > (s.stock[item] or 0) then up[#up + 1] = item end
    s.stock[item] = p
  end
  return up
end
check(#mut_type({ stock = {} }, { d = 500 }) > 0 and #Sr.stock_crossings({ stock = {} }, { d = 500 }) == 0, "mutant « type ignoré » refusé (le four réveille)")
local function mut_sans_memoire(s, healthy) return healthy == false end -- mutant : toute panne lue réveille
local seq, n_rule, n_mut = { true, false, false, false }, 0, 0
local s1, s2 = {}, {}
for _, h in ipairs(seq) do
  if Sr.energy_cut(s1, h) then n_rule = n_rule + 1 end
  if mut_sans_memoire(s2, h) then n_mut = n_mut + 1 end
end
check(n_rule == 1 and n_mut == 3, "mutant « transition sans mémoire » refusé (3 réveils pour une coupure)")

---------------------------------------------------------------------------------------------------
section("§6 câblage textuel")
---------------------------------------------------------------------------------------------------
local function slurp(p) local h = io.open(p, "rb") local s = h and h:read("*a") h:close() return s end
local team_src, hy_src, sr_src = slurp("script/team/team.lua"), slurp("script/team/hygiene.lua"), slurp("script/team/scan_reveil.lua")
check(team_src:find("Build.Hygiene.reveil(f, stock, tick)", 1, true) ~= nil, "team.lua : E6 appelle Build.Hygiene.reveil(f, stock, tick)")
check(select(2, team_src:gsub("Hygiene%.reveil", "")) == 1, "team.lua : un seul appel")
check(hy_src:find("function Hy.reveil(f, stock, tick) return Sr.think(f, stock, tick) end", 1, true) ~= nil, "hygiene.lua : Hy.reveil → Sr.think")
check(hy_src:find("St.due(sc, t0, Hy.CFG, rank)", 1, true) ~= nil and hy_src:find("St.ack(sc, t0, why)", 1, true) ~= nil, "hygiene.lua consomme St.due puis St.ack")
check(hy_src:find('"[FO-SCAN] %s : reveil (%s) a %.1f min"', 1, true) ~= nil, "hygiene.lua : journal [FO-SCAN] <équipe> : reveil (<cause>) a X.X min")
check(hy_src:find("Events.on(defines.events.on_tick", 1, true) ~= nil and sr_src:find("Events.on(defines.events.on_research_finished", 1, true) ~= nil, "abonnements statiques au niveau du module")
check(not sr_src:find("fast%-inserter") and not sr_src:find("transport%-belt\"%s*%]") and not sr_src:find("assembling%-machine%-%d"), "scan_reveil.lua : aucun nom d'objet du jeu (types de prototypes seulement)")
check(not sr_src:find("game%.tick%s*%-") and not sr_src:find("os%.clock") and not hy_src:find("os%.clock"), "aucune décision sur un temps mesuré")

print(string.format("scan_reveil_test : %d OK, %d ECHEC", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
