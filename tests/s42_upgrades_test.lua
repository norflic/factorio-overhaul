--[[
  Lot S42-UPGRADES : banc HORS JEU de la retenue « au calme » de la pile (shared/ai3/pile.lua, Pi.post_calm, Pi.POST_WAITS).
  Lancement, depuis la racine du mod : lua5.2 tests/s42_upgrades_test.lua
    1. un poste sous son minimum qui ATTEND SA MATIÈRE (raisons Pi.POST_WAITS) ne retient plus l'amélioration quand aucun danger n'est
       mesuré (sig.danger == false) ; il retient sous danger mesuré et pour un appelant d'avant ce lot (sig.danger == nil) ;
    2. un poste qui AVANCE (tâche prise, fabrication) retient au calme comme avant ; le poste du QG retient toujours ;
    3. au calme, la défense du poste qui attend sort du noyau du budget : une pièce à refaire payée par le stock passe en parallèle ;
    4. la matière qui manque reste demandée (short, focus) ; la porte laisse passer capital, upgrade et capi ;
    5. Pi.signals : danger lu sur la vue (perte récente, menace tenue, QG menacé, effectif, vague prévue) ;
    6. déterminisme et anti-noms : la règle ne nomme aucun objet du jeu.
]]
package.path = "./?.lua;" .. package.path
local Pi = require("shared.ai3.pile")
local Book = require("shared.team.book")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end

local TURRET, IRON, POLE = "gun-turret", "iron-plate", "small-electric-pole" -- données du banc (la règle n'en nomme aucun)

local function post(why, have, want)
  return { id = "plant", have = have or 0, want = want or 2, why = why, raw = { [IRON] = 80 }, claim = { { TURRET, 2 } } }
end
local function sig_of(why, danger, extra)
  local s = { danger = danger, posts = { post(why) }, raw_need = { [IRON] = { n = 80, prio = 90 } }, sources = { [IRON] = true },
    inputs = {} }
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end
local function run(sig) return Pi.update(Pi.update(Pi.new(), sig, 100), sig, 100 + Pi.CALM_AFTER) end -- s43 regr-fer : attente au calme tenue

-- 1. Poste qui attend sa matière.
for _, why in ipairs({ "manque", "fer", "ressources" }) do
  local st = run(sig_of(why, false))
  check(st.hold == false and st.top == Pi.AMELIORER, "1. calme, poste « " .. why .. " » : l'amélioration n'est plus retenue")
  check(#st.frames >= 1 and st.frames[1].key == "proteger:plant" and st.frames[1].nohold == true,
    "1. calme, poste « " .. why .. " » : le cadre existe toujours, sans retenue")
  check(Pi.describe(st):find("[sans retenue]", 1, true) ~= nil, "1. calme, poste « " .. why .. " » : le journal le dit")
  st = run(sig_of(why, true))
  check(st.hold == true and st.top == Pi.ADAPTER, "1. danger mesuré, poste « " .. why .. " » : la retenue demeure")
  st = run(sig_of(why, nil))
  check(st.hold == true and st.top == Pi.ADAPTER, "1. appelant d'avant (danger nil), poste « " .. why .. " » : la retenue d'avant")
end

-- 2. Poste qui avance : retenue au calme comme avant.
for _, why in ipairs({ "tache", "tache_creee", "fabrication" }) do
  local st = run(sig_of(why, false))
  check(st.hold == true and st.top == Pi.ADAPTER, "2. calme, poste « " .. why .. " » (il avance) : la retenue demeure")
end
do
  local st = run(sig_of("recette", false))
  check(st.blocked == true and st.hold == false, "2. poste « recette » : bloqué comme avant, aucune retenue")
end

do
  local sg = sig_of("manque", false)
  sg.posts[1].id = "hq"
  local st = run(sg)
  check(st.hold == true and st.top == Pi.ADAPTER and st.frames[1].nohold == nil, "2. calme, poste du QG « manque » : le QG retient toujours")
end

-- 3. Budget : au calme, la défense qui attend ne pèse plus au noyau.
do
  local repair = { { key = "r1", item = POLE, value = 1, prio = 60, have = 4, craftable = true, claimed = false } }
  local base = { repair = repair, book = book, avail = { [POLE] = 10 }, upgrades = {} }
  local st = run(sig_of("manque", true, base))
  check(st.hold == true and st.budget and st.budget.core_ok == false, "3. danger : 0 fer, 2 tourelles au noyau : retenue ("
    .. tostring(st.budget and st.budget.why) .. ")")
  st = run(sig_of("manque", false, base))
  check(st.hold == false and st.parallel == true and st.budget and st.budget.core_ok == true,
    "3. calme : le noyau ne compte que la pièce à refaire, payée par le stock : parallèle (" .. tostring(st.budget and st.budget.why) .. ")")
  st = run(sig_of("manque", false, { repair = repair, book = book, avail = {}, upgrades = {} }))
  check(st.top == Pi.ADAPTER, "3. calme : la pièce à refaire garde son cadre « réparer » (sommet adapter)")
end

-- 4. La matière reste demandée ; la porte laisse passer.
do
  local st = run(sig_of("fer", false))
  check(st.short[IRON] ~= nil and st.short[IRON].n == 80 and st.focus[IRON] == true, "4. calme : le manque de fer reste dans short et focus")
  for _, fam in ipairs({ "capital", "upgrade", "capi", "recherche", "foreuses" }) do
    check(Pi.porte(st, fam, nil, false) == true, "4. calme : la famille « " .. fam .. " » passe la porte")
  end
  st = run(sig_of("fer", true))
  for _, fam in ipairs({ "capital", "upgrade", "capi" }) do
    check(Pi.porte(st, fam, nil, false) == false, "4. danger : la famille « " .. fam .. " » reste suspendue")
  end
  check(Pi.porte(st, "reparer", nil, false) == true, "4. danger : réparer n'est jamais suspendu")
end

-- 5. Pi.signals : le danger se lit sur la vue.
do
  local base = { defend = { posts = {} }, raw_need = {} }
  local function danger(view, ctx) return Pi.signals(view, base, nil, nil, ctx, nil).danger end
  check(danger({}, {}) == false, "5. vue calme : danger faux")
  check(danger({}, nil) == false, "5. vue calme sans contexte : danger faux")
  check(danger({ threatened = true }, {}) == true, "5. perte récente près du QG : danger")
  check(danger({ threat_held = true }, {}) == true, "5. menace tenue : danger")
  check(danger({ hq_threat = true }, {}) == true, "5. QG menacé : danger")
  check(danger({ recover_floor = 5, workers = 2 }, {}) == true, "5. effectif sous le plancher : danger")
  check(danger({}, { prevu = { { id = "s", have = 0, want = 2 } } }) == true, "5. vague prévue au-dessus d'une défense : danger")
  check(danger({}, { prevu = {} }) == false, "5. aucune vague prévue : danger faux")
  check(danger({ survie = true }, {}) == false, "5. pénurie seule : pas un danger (c'est un manque de matière)")
end

-- 6. Déterminisme, anti-noms.
do
  local a, b = Pi.describe(run(sig_of("manque", false))), Pi.describe(run(sig_of("manque", false)))
  check(a == b, "6. deux passes identiques rendent le même journal")
  local fh = assert(io.open("shared/ai3/pile.lua", "rb"))
  local src = fh:read("*a")
  fh:close()
  local i = src:find("function Pi.post_calm", 1, true)
  local j = src:find("\nend", i, true)
  local body = src:sub(i, j)
  for _, name in ipairs({ TURRET, IRON, POLE, "steel", "furnace", "belt", "inserter" }) do
    check(body:find(name, 1, true) == nil, "6. Pi.post_calm ne nomme pas « " .. name .. " »")
  end
end

print(string.format("s42_upgrades_test : %d OK, %d ECHEC", passes, failures))
if failures > 0 then os.exit(1) end
