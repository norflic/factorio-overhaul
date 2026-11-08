--[[
  Lot TV-PILOTE, point D02 : la LISTE MINIMALE d'amorçage écrite en code (shared/team/amorce_kit.lua) contre le compteur d'amorce
  (shared/ai3/amorce.lua, Am.kit_report). Banc HORS JEU. Lancement, depuis la racine du mod : lua5.2 tests/amorce_kit_test.lua
    1. la liste est EXPLICITE et vient des données du départ réel (T.kits.worker, T.start_hq_turrets, T.turret), rien d'autre ;
    2. elle correspond au départ que donne la fondation (F.grant) pour les deux équipes : ni plus, ni moins ;
    3. Am.kit_report : lignes, totaux par ouvrier, objets fournis à la main HORS liste, tri, bornes, entrées absentes fermées ;
    4. branchement : le relevé de la capitalisation appelle Pil.kit (journal [FO-AMORCE]) ;
    5. mutants.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end
local function load_src(path, mutate)
  local src = slurp(path)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. path)
  if not fn then return nil, err end
  return fn()
end

local T = require("shared.team.config")
local F = require("shared.team.fondation")

local function battery(Am, K)
  -- 1. la liste
  check(type(K.MINIMAL) == "table" and #K.MINIMAL == #T.kits.worker + 1, "1 : la liste = l'equipement de l'ouvrier de depart + les tourelles de QG (" .. #K.MINIMAL .. ")")
  for i, it in ipairs(T.kits.worker) do
    local el = K.MINIMAL[i]
    check(el.item == it[1] and el.n == it[2] and el.per == "ouvrier" and el.why ~= "", "1 : element " .. i .. " vient de T.kits.worker : " .. tostring(el.item))
  end
  local tur = K.MINIMAL[#K.MINIMAL]
  check(tur.item == T.turret and tur.n == T.start_hq_turrets and tur.per == "equipe", "1 : les tourelles de QG viennent de T.turret et T.start_hq_turrets")
  check(next(T.start_kit) == nil and T.start_smelters == 0, "1 : le depart reel n'a ni objet au coffre ni four (T.start_kit vide) : la liste ne doit pas en ajouter")
  check(#K.COMPUTED == 2, "1 : ce qui est CALCULE (materiel des projets, amorce des cycles) est dit a part")
  check(K.BENCH == T.start_kit_generous, "1 : le kit genereux d'avant est reserve aux bancs")
  local tot = K.totals(8)
  check(tot[T.kits.worker[1][1]] == T.kits.worker[1][2] * 8 and tot[T.turret] == T.start_hq_turrets, "1 : totaux pour 8 ouvriers")
  -- 2. la fondation donne exactement cela
  for _, is_player in ipairs({ true, false }) do
    local g = F.grant(is_player, false, false)
    local got = {}
    for _, it in ipairs(g.worker_kit or {}) do got[it[1]] = (got[it[1]] or 0) + it[2] end
    for _, it in ipairs(g.chest or {}) do got["coffre:" .. it[1]] = it[2] end
    local ok = true
    for _, it in ipairs(T.kits.worker) do if got[it[1]] ~= it[2] then ok = false end end
    check(ok, "2 : F.grant (" .. (is_player and "votre equipe" or "faction") .. ") : equipement de l'ouvrier = la liste")
    check(g.hq_turrets == tur.n, "2 : F.grant : tourelles de QG = " .. tur.n .. " (" .. tostring(g.hq_turrets) .. ")")
    local extra = false
    for k in pairs(got) do if k:sub(1, 7) == "coffre:" then extra = true end end
    check(not extra and g.smelters == 0, "2 : F.grant : aucun objet au coffre, aucun four : rien que la liste n'ignore")
  end
  -- 3. rapport
  local st = { amorce = { hand = { [K.MINIMAL[1].item] = 4, [K.MINIMAL[2].item] = 60, ["piece-x"] = 40, ["piece-y"] = 25, ["piece-z"] = 9, ["piece-w"] = 40 } } }
  local rep = Am.kit_report(st, K.MINIMAL, 8)
  check(rep ~= nil and #rep.rows == #K.MINIMAL, "3 : une ligne par element de la liste")
  check(rep.rows[1].listed == T.kits.worker[1][2] * 8 and rep.rows[1].hand == 4, "3 : total par ouvrier x 8 et compteur d'amorce lu : " .. tostring(rep.rows[1].listed) .. "/" .. tostring(rep.rows[1].hand))
  check(rep.rows[#rep.rows].listed == T.start_hq_turrets, "3 : les tourelles ne se multiplient pas par ouvrier")
  check(#rep.extra == 3 and rep.extra[1].item == "piece-w" and rep.extra[2].item == "piece-x" and rep.extra[3].item == "piece-y",
    "3 : fournis a la main HORS liste, du plus au moins fourni (egalite : nom), sous 10 ignore : " .. #rep.extra)
  check(rep.text:find("kit minimal : ", 1, true) == 1 and rep.text:find("piece-w 40, piece-x 40, piece-y 25", 1, true), "3 : texte : " .. rep.text)
  local none = Am.kit_report({ amorce = { hand = {} } }, K.MINIMAL, 8)
  check(none.text:find("hors liste : aucun", 1, true), "3 : rien hors liste : « aucun »")
  check(#Am.kit_report(st, K.MINIMAL, 8, { max_extra = 1 }).extra == 1, "3 : borne du nombre d'objets hors liste")
  local r0, why0 = Am.kit_report(st, nil, 8)
  check(r0 == nil and why0:find("absent", 1, true), "3 : liste absente : fermee, raison ecrite")
  local r1, why1 = Am.kit_report(st, K.MINIMAL, nil)
  check(r1 == nil and why1:find("ouvriers", 1, true), "3 : ouvriers de depart absents : fermee (jamais 0 par defaut)")
  r1 = Am.kit_report(st, K.MINIMAL, 0 / 0)
  check(r1 == nil, "3 : NaN : fermee")
  r1 = Am.kit_report(nil, K.MINIMAL, 8)
  check(r1 ~= nil and r1.rows[1].hand == 0 and #r1.extra == 0, "3 : mall absent : compteur 0, rien hors liste")
  check(Am.kit_report(st, K.MINIMAL, 8).text == Am.kit_report(st, K.MINIMAL, 8).text, "3 : deterministe")
end

local Am0 = assert(load_src("shared/ai3/amorce.lua"))
local K0 = assert(load_src("shared/team/amorce_kit.lua"))
battery(Am0, K0)

-- 4. branchement
do
  local cap = slurp("script/ai3/capitalisation.lua")
  check(cap:find("Pil.kit(f, cs, ml, tick, minutes(f, tick))", 1, true) ~= nil, "4 : le releve de la capitalisation appelle Pil.kit")
  local pil = slurp("script/ai3/pilotage.lua")
  check(pil:find("Am.kit_report(ml, Kit.MINIMAL, start)", 1, true) ~= nil and pil:find("[FO-AMORCE] %s : %s a %.1f min", 1, true) ~= nil,
    "4 : Pil.kit compare la liste minimale au compteur et ecrit [FO-AMORCE]")
  check(pil:find("rep.text == cs.kit_sig", 1, true) ~= nil and pil:find("Pil.KIT_EVERY", 1, true) ~= nil, "4 : une ligne seulement quand le rapport change, toutes les 10 min")
  local am = slurp("shared/ai3/amorce.lua")
  check(am:find('require%("shared.team') == nil, "4 : amorce.lua (shared/ai3) ne require aucune donnee nommee de shared/team")
end

-- 5. mutants
local MUTANTS = {
  { "Am", "shared/ai3/amorce.lua", "total multiplie meme pour l'equipe", 'local total = (el.per == "ouvrier") and (el.n or 0) * w or (el.n or 0)', "local total = (el.n or 0) * w" },
  { "Am", "shared/ai3/amorce.lua", "compteur d'amorce ignore", "hand = Am.supplied(st, el.item)", "hand = 0" },
  { "Am", "shared/ai3/amorce.lua", "liste absente = aucun kit", 'if type(minimal) ~= "table" then return nil, "kit minimal absent" end', "minimal = minimal or {}" },
  { "Am", "shared/ai3/amorce.lua", "ouvriers absents = 0", 'if w == nil then return nil, "ouvriers de depart absents" end', "w = w or 0" },
  { "Am", "shared/ai3/amorce.lua", "hors liste: l'objet de la liste compte aussi", "if not listed[it] and", "if" },
  { "Am", "shared/ai3/amorce.lua", "seuil hors liste retire", "(hand[it] or 0) >= min_extra", "(hand[it] or 0) >= 0" },
  { "Am", "shared/ai3/amorce.lua", "tri inverse", "if a.hand ~= b.hand then return a.hand > b.hand end", "if a.hand ~= b.hand then return a.hand < b.hand end" },
  { "Am", "shared/ai3/amorce.lua", "borne ignoree", "while #extra > max_extra do extra[#extra] = nil end", "" },
  { "K", "shared/team/amorce_kit.lua", "tourelles oubliees", "K.MINIMAL[#K.MINIMAL + 1] = { item = T.turret", "local _ = { item = T.turret" },
  { "K", "shared/team/amorce_kit.lua", "equipement ouvrier oublie", "for _, it in ipairs(T.kits.worker) do", "for _, it in ipairs({}) do" },
  { "K", "shared/team/amorce_kit.lua", "tourelles par ouvrier", 'per = "equipe", why = "tourelles', 'per = "ouvrier", why = "tourelles' },
}
local killed = 0
quiet = true
local p0 = passes
for _, m in ipairs(MUTANTS) do
  local Am, K = Am0, K0
  local mod, err = load_src(m[2], { m[4], m[5] })
  local dead = false
  if not mod then
    quiet = false
    check(false, "5 : mutant « " .. m[3] .. " » : " .. tostring(err))
    quiet = true
  else
    if m[1] == "Am" then Am = mod else K = mod end
    local fb = failures
    local ok = pcall(battery, Am, K)
    if not ok or failures > fb then dead = true end
    failures = fb
  end
  if dead then killed = killed + 1 else quiet = false; check(false, "5 : mutant survivant : " .. m[3]); quiet = true end
end
quiet = false
passes = p0
check(killed == #MUTANTS, string.format("5 : mutants refuses %d / %d", killed, #MUTANTS))

print(string.format("[AMORCE-KIT] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
