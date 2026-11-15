--[[
  Lot C3-BOUCLE (partie du DC 0.9.4, 15/11) : priorité par taille des gisements (shared/ai3/capitalisation.lua Ca.size_held) et son
  branchement dans les options d'extraction ; mutants. Les deux autres coupes du lot ont leurs tests dans tests/vapeur_test.lua (§ 6 bis,
  bande de l'entrepreneur exemptée de la priorité d'alimentation) et tests/electrique_test.lua (§ 8, agrandissement thermique refusé).
  Usage : lua5.2 tests/c3_boucle_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local SRC = read("shared/ai3/capitalisation.lua")

local passes, failures = 0, 0
local function check(c, msg)
  if c then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end

local function load_ca(src)
  local chunk = assert(load(src, "=capitalisation", "t"))
  return chunk()
end

-- gisements de fer de votre équipe à 45 min (journal [FO-CAPI-COUV] de la partie du DC)
local function iron45()
  return {
    { id = "iron-ore@-105,-75", tiles = 2031, free = 111, kappa = 121, usable = true },
    { id = "iron-ore@-2,-28", tiles = 609, free = 3, kappa = 154, usable = true },
    { id = "iron-ore@-137,17", tiles = 2866, free = 212, kappa = 0, usable = true },
    { id = "iron-ore@-31,65", tiles = 1765, free = 130, kappa = 0, usable = true },
    { id = "iron-ore@-44,-151", tiles = 476, free = 35, kappa = 0, usable = true },
  }
end

local function suite(Ca)
  local before = failures
  check(type(Ca.size_held) == "function", "Ca.size_held existe")
  if type(Ca.size_held) ~= "function" then return failures - before end
  local h = Ca.size_held(iron45(), 850)
  check(h["iron-ore@-2,-28"] == "iron-ore@-137,17", "le micro-gisement de 609 tuiles est retenu par le plus grand pas couvert")
  check(h["iron-ore@-105,-75"] == "iron-ore@-137,17" and h["iron-ore@-44,-151"] ~= nil, "tous les plus petits sont retenus")
  check(h["iron-ore@-137,17"] == nil, "le plus grand n'est jamais retenu")
  -- le plus grand couvert au-delà du seuil : le suivant prend la tête
  local e = iron45()
  e[3].kappa = 860
  h = Ca.size_held(e, 850)
  check(h["iron-ore@-105,-75"] == nil and h["iron-ore@-2,-28"] == "iron-ore@-105,-75", "grand couvert a 86 % : le suivant (2031) passe, le micro attend")
  e[3].kappa, e[3].free = 0, 0
  check(Ca.size_held(e, 850)["iron-ore@-105,-75"] == nil, "grand sans place libre : compte couvert")
  e[3].free, e[3].usable = 212, false
  check(Ca.size_held(e, 850)["iron-ore@-105,-75"] == nil, "grand interdit (danger, hors de portee) : ne retient personne")
  local eq = { { id = "a", tiles = 500, free = 5, kappa = 0, usable = true }, { id = "b", tiles = 500, free = 5, kappa = 0, usable = true } }
  h = Ca.size_held(eq, 850)
  check(h.a == nil and h.b == nil, "meme taille : jamais retenus l'un par l'autre (pas d'interblocage)")
  check(next(Ca.size_held({}, 850)) == nil and next(Ca.size_held(nil, 850)) == nil, "liste vide")
  -- seuil par défaut : celui de l'entrepreneur (aucun réglage nouveau)
  local Ent = require("shared.team.entrepreneur")
  local e2 = iron45()
  e2[3].kappa = Ent.CFG.cover_max - 1
  check(Ca.size_held(e2)["iron-ore@-105,-75"] ~= nil, "seuil par defaut = Ent.CFG.cover_max (sous le seuil : retient)")
  e2[3].kappa = Ent.CFG.cover_max
  check(Ca.size_held(e2)["iron-ore@-105,-75"] == nil, "seuil par defaut = Ent.CFG.cover_max (au seuil : libere)")
  check(Ca.SIZE_FIRST == true, "priorite par taille allumee")
  return failures - before
end

print("== 1. Priorite par taille (Ca.size_held)")
local ok, Ca = pcall(load_ca, SRC)
check(ok, "le module se charge")
suite(ok and Ca or {})

print("== 2. Branchement dans les options d'extraction")
check(SRC:find("if free > 0 and not small_by and not Ca.taken(plan, key) then", 1, true) ~= nil, "couvrir : un gisement retenu ne recoit aucun ordre")
check(SRC:find("local blocked = f.danger or f.blocked or no_power or small_by", 1, true) ~= nil, "un gisement retenu compte couvert (le grand peut s'ouvrir)")
check(SRC:find("if held[tostring(f.id)] then goto next_site end", 1, true) ~= nil, "ouvrir : un site plus petit n'est pas ouvert avant le grand")
check(SRC:find('why_open = "taille : gisement plus grand "', 1, true) ~= nil, "un site plus grand s'ouvre quand il retient un gisement ouvert")

print("== 2 bis. Glue electrique : agrandissements refuses au tableau ET dans la vue du cerveau (zero-idle)")
local EL = read("script/team/electrique.lua")
check(EL:find('E.thermal(inputs(v, t.outpost_kind, t.kind == "craft", t.kind == "extend"))', 1, true) ~= nil, "filtre du tableau : tache extend")
check(EL:find("E.thermal(inputs(v, kind, false, ((v.kinds or {})[kind] or 0) > 0))", 1, true) ~= nil, "vue du cerveau : type qui a un avant-poste = agrandissement")
check(EL:find("net = (v.era ~= nil and (v.el_placed or 0) > 0) or nil", 1, true) ~= nil, "reseau en place : ere datee et une electrique posee")

print("== 2 ter. Journal [FO-MIGRATION] : plafond par fenetre de 5 min (les causes de veille restent lisibles)")
local Mg = require("shared.team.migration_champ")
check(Mg.CFG.logs_window == 5 * 3600 and Mg.CFG.logs == 60, "fenetre de 5 min, 60 lignes par fenetre")
local MS = read("script/team/migration_champ.lua")
check(MS:find("if CFG.logs_window and now >= (ms.logs_t or 0) + CFG.logs_window then ms.logs, ms.logs_t = 0, now end", 1, true) ~= nil, "le compteur se rouvre a chaque fenetre")

print("== 3. Mutants")
local mutants = {
  { "plus grand ignore", "if lt == nil or t > lt or", "if lt == nil or t < lt or" },
  { "seuil ignore", "if b.usable and (b.free or 0) > 0 and (b.kappa or 0) < cover_max then", "if b.usable and (b.free or 0) > 0 then" },
  { "places ignorees", "if b.usable and (b.free or 0) > 0 and (b.kappa or 0) < cover_max then", "if b.usable and (b.kappa or 0) < cover_max then" },
  { "interdit ignore", "if b.usable and (b.free or 0) > 0 and (b.kappa or 0) < cover_max then", "if (b.free or 0) > 0 and (b.kappa or 0) < cover_max then" },
  { "meme taille retenue", "if (a.tiles or 0) < lt then held[a.id] = lead end", "if (a.tiles or 0) <= lt and a.id ~= lead then held[a.id] = lead end" },
  { "seuil de l'entrepreneur", "cover_max = cover_max or Ent.CFG.cover_max", "cover_max = cover_max or 1000" },
  { "regle eteinte", "Ca.SIZE_FIRST = true", "Ca.SIZE_FIRST = false" },
}
local killed = 0
for _, mu in ipairs(mutants) do
  local a, b = SRC:find(mu[2], 1, true)
  check(a ~= nil, "mutant applicable : " .. mu[1])
  if a then
    local msrc = SRC:sub(1, a - 1) .. mu[3] .. SRC:sub(b + 1)
    local sp, sf = passes, failures
    local silent = print
    _G.print = function() end
    local okm, M = pcall(load_ca, msrc)
    local res = okm and select(2, pcall(suite, M)) or 1
    _G.print = silent
    passes, failures = sp, sf
    local k = (not okm) or (type(res) ~= "number") or res > 0
    check(k, "mutant refuse : " .. mu[1])
    if k then killed = killed + 1 end
  end
end
print(string.format("[C3-BOUCLE] mutants %d refuses sur %d", killed, #mutants))
print(string.format("[C3-BOUCLE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
