--[[
  Lot TV-PILOTE, point W04 : l'INVENTAIRE des gardes (shared/ai3/gardes.lua) contre les gardes RÉELLES. Banc HORS JEU. Lancement, depuis la
  racine du mod : lua5.2 tests/gardes_inventaire_test.lua
  Pour chaque entrée du tableau : (a) une SONDE appelle la vraie garde avec sa mesure manquante, (b) le résultat est comparé à l'état écrit
  (ferme : refusé ET le texte rendu contient le fragment `refus` ; ouvre-voulu : pas de retenue, la raison est écrite), (c) un mutant par
  famille de garde (le texte de la règle est remplacé : la sonde doit échouer). Le tableau et les sondes se correspondent un pour un.
  Aucun nom du jeu : des chaînes opaques.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end

--- Charge un module en remplaçant un morceau de son texte (mutant) ; sans `mutate`, le module d'origine.
local function load_mod(path, mutate)
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

local Gd = require("shared.ai3.gardes")

local PATHS = {
  Pf = "shared/ai3/plafonds.lua", Pe = "shared/ai3/portes_extension.lua", S = "shared/team/sante_centrale.lua",
  Fx = "shared/team/flux.lua", D = "shared/ai3/danger.lua", Ic = "shared/team/ilots_croissance.lua",
  Lm = "shared/team/lot_minerai.lua", Pl = "shared/ai3/palier.lua", Cf = "shared/ai3/confirmation.lua",
  Pi = "shared/ai3/pile.lua", B = "shared/ai3/buts.lua", Sa = "shared/ai3/saturation.lua", Q = "shared/team/quotas.lua",
}

local function has(text, frag) return type(text) == "string" and text:find(frag, 1, true) ~= nil end

--- SONDES : id -> function(M) rendant (ferme, texte). ferme = la garde a REFUSÉ faute de mesure ; texte = la raison rendue (peut être "").
--- Une garde « ouvre-voulu » rend ferme = false.
local PROBES = {
  ["Pf.input"] = function(M)
    local v, why = M.Pf.input(nil, "x")
    return v == nil, why
  end,
  ["Pf.fits"] = function(M)
    local ok, why = M.Pf.fits({ demand = nil, posed = 0, open = 0, n_posed = 0, n_open = 0 }, { rate = 1, n = 1 }, "x")
    return ok == false, why
  end,
  ["Pf.fits_item"] = function(M)
    local ok, why = M.Pf.fits_item({}, "x", { rate = 1, n = 1 })
    return ok == false, why
  end,
  ["Pf.open_room"] = function(M)
    local room, why = M.Pf.open_room(nil, 16)
    return room == 0, why
  end,
  ["Pf.power_missing"] = function(M)
    local why = M.Pf.power_missing({})
    return why ~= nil, why
  end,
  ["Pf.kind_room"] = function(M)
    local room, why = M.Pf.kind_room("labos", 5, nil)
    return room == 0, why
  end,
  ["Pe.transport"] = function(M)
    local closed, cause = M.Pe.transport(M.Pe.new(), {})
    return closed == true, cause
  end,
  ["Pe.site_room"] = function(M)
    local room, _, why = M.Pe.site_room(nil, 0)
    return room == 0, why
  end,
  ["S.admit"] = function(M)
    local ok, why = M.S.admit({}, { plant_done = true, used = 0, committed = 0 }, 700, 100)
    return ok == false, why
  end,
  ["Fx.drop_service"] = function(M)
    local old = M.Fx.ENABLE.keep_drop
    M.Fx.ENABLE.keep_drop = true
    local d, why = M.Fx.drop_service(nil, true)
    M.Fx.ENABLE.keep_drop = old
    return d == false, why
  end,
  ["D.gate"] = function(M)
    local d, why = M.D.gate({}, { B = 600, prudence = 1000, escort_ok = false })
    return d == "wait", why
  end,
  ["Ic.gate"] = function(M)
    local ok, why = M.Ic.gate({ islands = 1, max = 4, unwalled = 0, unguarded = 0, outside_busy = 0, main_busy = false })
    return ok == false, why
  end,
  ["Lm.allows"] = function(M)
    local ok, why = M.Lm.allows(nil, "extraction")
    return ok == false, why
  end,
  ["Lm.states_for"] = function(M)
    local l = M.Lm.states_for(nil)
    return type(l) == "table" and #l == 0, ""
  end,
  ["Pl.stable"] = function(M)
    local ok, why = M.Pl.stable({ crise = false, bras_libres = 1 }) -- manques absent
    return ok == false, why
  end,
  ["Cf.engage"] = function(M)
    local ok, why = M.Cf.engage(M.Cf.new(), { item = "x" }, 10)
    return ok == false, why
  end,
  ["Cf.step"] = function(M)
    local r, why = M.Cf.step(M.Cf.new(), {}, nil)
    return r == nil, why
  end,
  ["Cf.counts"] = function(M)
    return M.Cf.counts(M.Cf.new(), "u1") == false, ""
  end,
  ["Pi.allows"] = function(M)
    return M.Pi.allows(nil, "capital") == false, "" -- ferme = a retenu
  end,
  ["B.saturated"] = function(M)
    return M.B.saturated({ stock = {}, need = {}, workers = 8 }, "objet-a") == true, "" -- ferme = a retenu (saturé)
  end,
  ["Sa.holds"] = function(M)
    return M.Sa.holds(1e9, 100, nil, 10) == false, "" -- ferme = a rendu « pas saturé » sur une mesure absente
  end,
  ["Qt.feed_ok"] = function(M)
    return M.Q.feed_ok({ outs = { { cap = 100 } } }, nil) == false, "" -- ferme = a retenu l'alimentation
  end,
  ["Q.filter"] = function(M)
    return M.Q.filter ~= nil, "" -- la garde existe encore (fermé = présente)
  end,
}

--- Compare l'état écrit au résultat de la sonde. Rend ok, message.
local function judge(g, M)
  local probe = PROBES[g.id]
  if not probe then return false, "aucune sonde" end
  local okp, closed, text = pcall(probe, M)
  if not okp then return false, "la sonde plante : " .. tostring(closed) end
  if g.etat == "ferme" then
    if not closed then return false, "devrait FERMER sur la mesure absente" end
    if g.refus ~= "" and not has(text, g.refus) then return false, "refus sans « " .. g.refus .. " » : " .. tostring(text) end
    return true
  elseif g.etat == "ouvre-voulu" then
    if closed then return false, "ne devrait pas retenir (decision ecrite : ouvre-voulu)" end
    return true
  else -- retiree : la garde ne doit plus exister
    if closed then return false, "garde retiree encore presente" end
    return true
  end
end

local function load_all(mut)
  local M = {}
  for k, p in pairs(PATHS) do
    local m, err
    if mut and mut[1] == k then m, err = load_mod(p, mut[2]) else m, err = load_mod(p) end
    if not m then return nil, k .. " : " .. tostring(err) end
    M[k] = m
  end
  return M
end

local M0 = assert(load_all())

-- 1. Forme du tableau.
local bad = Gd.validate()
check(#bad == 0, "1 : tableau bien forme (" .. table.concat(bad, " ; ") .. ")")
check(#Gd.LIST >= 23, "1 : au moins 23 gardes inventoriees (" .. #Gd.LIST .. ")")
local counts = Gd.counts()
check(counts.total == #Gd.LIST and counts.ferme + counts["ouvre-voulu"] + counts.retiree == counts.total, "1 : decompte par etat")
check(Gd.summary():find("garde(s) inventoriee(s)", 1, true) ~= nil, "1 : ligne de journal")
-- Le tableau et les sondes se correspondent un pour un.
local by_id = {}
for _, g in ipairs(Gd.LIST) do by_id[g.id] = true end
for _, g in ipairs(Gd.LIST) do check(PROBES[g.id] ~= nil, "1 : sonde pour " .. g.id) end
for id in pairs(PROBES) do check(by_id[id], "1 : entree pour la sonde " .. id) end
-- Les fichiers cites existent.
for _, g in ipairs(Gd.LIST) do
  local f = io.open(g.file, "rb")
  check(f ~= nil, "1 : fichier de " .. g.id .. " : " .. g.file)
  if f then f:close() end
end

-- 2. Chaque garde réelle fait ce que le tableau écrit.
for _, g in ipairs(Gd.LIST) do
  local ok, msg = judge(g, M0)
  check(ok, "2 : " .. g.id .. " (" .. g.etat .. ") : " .. tostring(msg))
end

-- 3. Formes invalides refusees par Gd.validate (le tableau ne se corrompt pas en silence).
local function copy_list()
  local c = {}
  for i, g in ipairs(Gd.LIST) do
    local x = {}
    for k, v in pairs(g) do x[k] = v end
    c[i] = x
  end
  return c
end
do
  local l = copy_list(); l[2].id = l[1].id
  check(#Gd.validate(l) > 0, "3 : id en double refuse")
  l = copy_list(); l[1].etat = "ouvert"
  check(#Gd.validate(l) > 0, "3 : etat inconnu refuse")
  l = copy_list(); l[1].refus = nil
  check(#Gd.validate(l) > 0, "3 : garde fermee sans refus ecrit refusee")
  l = copy_list()
  for _, g in ipairs(l) do if g.etat == "ouvre-voulu" then g.raison = nil end end
  check(#Gd.validate(l) > 0, "3 : garde ouverte sans raison ecrite refusee")
  l = copy_list(); l[1].polarite = "autre"
  check(#Gd.validate(l) > 0, "3 : polarite inconnue refusee")
  l = copy_list(); l[1].lot = ""
  check(#Gd.validate(l) > 0, "3 : lot absent refuse")
end

-- 4. Mutants : une garde qui s'ouvre sur sa mesure absente est vue par sa sonde.
local MUTANTS = {
  { "Pf", "entree absente lue comme 0", 'if v == nil then return nil, "entree absente : " .. name end', "if v == nil then return 0 end" },
  { "Pf", "registre absent : objet admis", 'return Pf.fits(ledger and ledger[item], add, item)', 'return ledger and ledger[item] == nil or Pf.fits(ledger and ledger[item], add, item)' },
  { "Pf", "ordres ouverts absents : places", 'if type(open) ~= "table" then return 0, "ordres ouverts : entree absente" end', 'if type(open) ~= "table" then open = {} end' },
  { "Pf", "courant absent : garde ouverte", 'local _, why = Pf.input(pw.have_kw, "power.have_kw")', 'local _, why = 0, nil' },
  { "Pe", "mesure du transport absente : porte ouverte", 'if not w or not idle or not free then return nil, nil, "mesure absente" end', "if false then return nil, nil, 'x' end" },
  { "Pe", "place de chantier sur mesure absente", "if b == nil or o == nil then return 0, 0,", "if false then return 0, 0," },
  { "S", "centrale finie sans capacite : admise", "if c.plant_done then return hold(", "if false then return hold(" },
  { "Fx", "rangee absente : tournee retiree", [[if type(o) ~= "table" or type(o.stuck) ~= "number" or o.stuck ~= o.stuck then return false, "sorties non mesurees : tournee gardee" end]], "o = o or {}" },
  { "D", "danger non lu : go", [[if type(info) ~= "table" or (info.max_d == nil and info.goal_d == nil and info.deaths == nil and info.blocked == nil) then]], "if false then" },
  { "Ic", "menace absente : pas de menace", [[if type(info[k]) ~= "boolean" then return false, "mesure absente : " .. k end]], "" },
  { "Lm", "role absent : ouvert", [[if role ~= "minerai" and role ~= "general" then return false, "role absent ou inconnu (garde fermee)" end]], "" },
  { "Lm", "sorte absente : un etat essaye", "for _, set in ipairs(Lm.STATES[kind] or {}) do", "for _, set in ipairs(Lm.STATES[kind] or { {} }) do" },
  { "Pl", "manques absents lus comme 0", "local m, h = num(a.manques), num(a.bras_libres)", "local m, h = num(a.manques) or 0, num(a.bras_libres)" },
  { "Cf", "intention sans id acceptee", [[if type(it) ~= "table" or not valid_id(it.id) then return false, "intention sans id valide" end]], "" },
  { "Cf", "tick absent : le pas avance", [[if not finite(tick) then return nil, "tick absent" end
  obs = obs or {}]], "tick = tick or 0\n  obs = obs or {}" },
  { "Pi", "pile absente : toutes retenues", "if not st or not st.hold then return true end", "if not st then return false end if not st.hold then return true end" },
  { "B", "objet absent du stock : sature", "local have, thr = s.stock[item] or 0, B.SAT_FACTOR * need", "local have, thr = s.stock[item] or math.huge, B.SAT_FACTOR * need" },
  { "Sa", "sans fonte mesuree : pas sature", "if drain and drain > 0 and stock - drain * (h or Sa.H) < threshold then return false, \"pente\" end",
    "if stock - (drain or math.huge) * (h or Sa.H) < threshold then return false, \"pente\" end" },
  { "Q", "coffre non compte : alimentation coupee", "if cap <= 0 then return true end", "if cap <= 0 then return false end" },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local M, err = load_all({ m[1], { m[3], m[4] } })
  local dead = false
  if not M then
    quiet = false
    check(false, "4 : mutant « " .. m[2] .. " » : " .. tostring(err))
    quiet = true
  else
    for _, g in ipairs(Gd.LIST) do
      local ok = judge(g, M)
      if not ok then dead = true break end
    end
  end
  if dead then killed = killed + 1 else quiet = false; check(false, "4 : mutant survivant : " .. m[2]); quiet = true end
end
quiet = false
check(killed == #MUTANTS, string.format("4 : mutants refuses %d / %d", killed, #MUTANTS))

print(string.format("[GARDES-INVENTAIRE] %s", Gd.summary()))
print(string.format("[GARDES-INVENTAIRE] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
