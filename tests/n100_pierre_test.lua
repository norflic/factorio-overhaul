-- n100-pierre (interblocage B5, banc n099-joueur-2, graine 4251870853) : la pile restait SUSPENDUE « noyau non couvert (manque stone) »
-- (azure de 48 à 89 min, 0 assembleur) : la matière qui manquait au noyau (budget.missing) n'était lue que par le journal ; la porte
-- refusait la bande de cette matière même (« projet 9 (capi, stone) : reserve au coffre suspendue, stone hors des cadres ouverts et sans
-- manque »), la garde anti-dispersion la retenait (« minerai brut sans manque mesure »), le plafond du QG la gardait au tampon.
-- Coupe (shared/ai3/pile.lua, Pi.update) : noyau non couvert -> la matière qui manque devient un manque de la pile (short, focus, cadre
-- « produire »), comme ceux du planificateur. Usage : lua5.2 tests/n100_pierre_test.lua (depuis la racine du mod)
package.path = "./?.lua;" .. package.path
local Pi = require("shared.ai3.pile")
local Book = require("shared.team.book")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("[N100-PIERRE] ECHEC : " .. msg) end end

-- Données du banc (la règle n'en nomme aucune) : un four se fait de pierre (fixtures), la tourelle de fer et de cuivre.
local TURRET, IRON, COPPER, FURNACE, STONE = "gun-turret", "iron-plate", "copper-plate", "stone-furnace", "stone"
check(next(book:plan({ { FURNACE, 1 } }, {}).raw) ~= nil and (book:plan({ { FURNACE, 1 } }, {}).raw[STONE] or 0) > 0,
  "fixtures : le four se paie en pierre")

local function sig(over)
  local s = { posts = { { id = "hq", have = 0, want = 2, why = "fabrication", raw = {}, claim = { { TURRET, 2 } } } },
    sources = { [IRON] = true, [COPPER] = true, [STONE] = true }, inputs = {}, book = book,
    avail = { [IRON] = 5000, [COPPER] = 1000, [STONE] = 40 },
    upgrades = { { key = "capital:x", cost = { { IRON, 100 } } } },
    plan_growth = { { FURNACE, 20 } } } -- une bande du champ attend 20 fours (100 pierres, 110 avec la marge)
  for k, v in pairs(over or {}) do s[k] = v end
  return s
end

local function battery(PiM, verbose)
  local fails = 0
  local function ck(c, msg) if not c then fails = fails + 1 end if verbose then check(c, msg) end end
  -- 1. Le symptôme : noyau non couvert par la seule pierre ; la retenue demeure (intention CHAMP-0916 gardée) …
  local st = PiM.new()
  PiM.update(st, sig(), 100)
  ck(st.hold and st.budget and not st.budget.core_ok and (st.budget.missing[STONE] or 0) > 0,
    "1. bande qui attend ses fours, pierre au stock 40 : noyau non couvert, la retenue demeure")
  -- … mais la pierre qui manque devient un manque de la pile : demandée (short), cadre ouvert (focus), cadre « produire »
  ck(st.short and st.short[STONE] and st.short[STONE].n == math.ceil(st.budget.missing[STONE]) and st.short[STONE].prio == PiM.INJECT_PRIO,
    "1. la pierre qui manque au noyau entre au manque de la pile, à la priorité des rangs R0/R1")
  ck(st.focus and st.focus[STONE] == true, "1. la pierre est au cadre ouvert (focus)")
  local has_frame = false
  for _, fr in ipairs(st.frames or {}) do if fr.key == "produire:" .. STONE and fr.exec then has_frame = true end end
  ck(has_frame, "1. un cadre « produire:stone » avec une voie (source connue)")
  -- 2. La porte laisse passer l'investissement qui produit la pierre (la bande de la pierre, famille capi), pas le reste
  ck(select(1, PiM.porte(st, "capi", STONE, false)), "2. la bande de la pierre passe la porte pendant la retenue")
  ck(not select(1, PiM.porte(st, "capital", "autre", false)), "2. un capital qui ne produit pas ce qui manque reste suspendu")
  -- 3. Un manque déjà porté par le planificateur garde sa quantité et sa priorité
  local st3 = PiM.new()
  PiM.update(st3, sig({ raw_need = { [STONE] = { n = 7, prio = 90 } } }), 100)
  ck(st3.short[STONE] and st3.short[STONE].n == 7 and st3.short[STONE].prio == 90, "3. manque du planificateur inchangé (7 à 90)")
  -- 4. Noyau couvert (assez de pierre) : rien n'est ajouté, parallèle comme avant
  local st4 = PiM.new()
  PiM.update(st4, sig({ avail = { [IRON] = 5000, [COPPER] = 1000, [STONE] = 500 } }), 100)
  ck(not st4.hold and st4.parallel and not (st4.short or {})[STONE], "4. pierre suffisante : parallèle, aucun manque de pierre")
  -- 5. Couvert une fois seulement (marge) : la marge n'est pas un manque
  local st5 = PiM.new()
  PiM.update(st5, sig({ upgrades = {}, avail = { [IRON] = 5000, [COPPER] = 1000, [STONE] = 150 } }), 100)
  ck(st5.budget and st5.budget.core_ok and not (st5.short or {})[STONE], "5. noyau couvert, marge seule qui manque : aucun manque ajouté")
  -- 5 bis. Une plaque de la fonderie qui manque au noyau n'est pas ajoutée (sa voie est la fonderie ; CHAMP-0916 gardé)
  local st6 = PiM.new()
  PiM.update(st6, sig({ inputs = { [IRON] = "iron-ore" }, avail = { [IRON] = 10, [COPPER] = 1000, [STONE] = 40 } }), 100)
  ck(st6.hold and (st6.budget.missing[IRON] or 0) > 0 and not (st6.short or {})[IRON] and not (st6.focus or {})[IRON]
    and (st6.short or {})[STONE] ~= nil, "5 bis. fer et pierre manquent : la pierre entre au manque, la plaque de fer non")
  -- 6. Déterminisme : deux passages identiques, mêmes cadres dans le même ordre
  local a, b = PiM.new(), PiM.new()
  PiM.update(a, sig(), 100) PiM.update(b, sig(), 100)
  local ka, kb = {}, {}
  for _, fr in ipairs(a.frames) do ka[#ka + 1] = fr.key end
  for _, fr in ipairs(b.frames) do kb[#kb + 1] = fr.key end
  ck(table.concat(ka, ",") == table.concat(kb, ","), "6. déterminisme des cadres")
  return fails
end

battery(Pi, true)

-- 7. Câblage : le cerveau donne pile.short à E.raw (manque mesuré : porte, garde anti-dispersion, plafond du QG, croissance)
local fh = assert(io.open("shared/ai3/cerveau.lua", "rb")); local C = fh:read("*a"); fh:close()
check(C:find("for _, k in ipairs(sorted_keys(pile.short)) do P.short_raw(E, pile_proj, k, pile.short[k].n, pile.short[k].prio) end", 1, true) ~= nil,
  "7. cerveau : pile.short entre au manque de la pensée (E.raw)")
local fp = assert(io.open("shared/ai3/pile.lua", "rb")); local PS = fp:read("*a"); fp:close()
check(not PS:find("\"" .. STONE .. "\"", 1, true) and not PS:find("\"" .. FURNACE .. "\"", 1, true), "7. la pile ne nomme aucun objet du jeu")

-- 8. Mutant : la coupe retirée, la batterie échoue
local function slurp(p) local h = assert(io.open(p, "rb")) local s = h:read("*a") h:close() return s end
local src = slurp("shared/ai3/pile.lua")
local from = "if n > 0 and not short[item] and not (sig.inputs or {})[item] then"
local i, j = src:find(from, 1, true)
check(i ~= nil, "mutant : texte de la coupe trouvé")
if i then
  local m = src:sub(1, i - 1) .. "if false then" .. src:sub(j + 1)
  local tmp = require("tests.depot").tmpname()
  local h = assert(io.open(tmp, "wb")) h:write(m) h:close()
  local ok, mod = pcall(dofile, tmp)
  os.remove(tmp)
  check(ok, "mutant : charge")
  if ok then check(battery(mod, false) > 0, "mutant refusé : la matière qui manque au noyau n'est plus un manque de la pile") end
end

print(string.format("[N100-PIERRE] %d OK, %d ECHEC(S)", ok_n, fail_n))
if fail_n > 0 then os.exit(1) end
