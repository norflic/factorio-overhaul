--[[
  Lot TV-PILOTE, point V88 : la TABLE défaut -> signal -> levier (shared/ai3/defauts.lua) et son appel par la boucle de décision. Banc HORS JEU.
  Lancement, depuis la racine du mod : lua5.2 tests/defauts_test.lua
    1. forme de la table, un levier = du code qui existe (le fragment est cherché dans son fichier) ;
    2. COUVERTURE : chaque statut du moteur (liste complète de defines.entity_status, API 1.1.91) est routé ou déclaré « pas une panne » avec sa
       raison ; chaque cause de la confirmation (Cf.CAUSE_*) est dans la table ;
    3. le routage (Df.route) : par défaut, cause inconnue écrite, déterministe, lignes du journal ;
    4. l'APPEL : le relevé de la capitalisation lit la table (CONF_CAUSE vient de Df.FAULTS), appelle Pil.defauts, Pil.note au repli ;
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
local function load_df(mutate)
  local src = slurp("shared/ai3/defauts.lua")
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@shared/ai3/defauts.lua")
  if not fn then return nil, err end
  return fn()
end

-- Liste COMPLÈTE de defines.entity_status (doc-html/runtime-api.json de la 1.1.91).
local ENGINE = { "cant_divide_segments", "charging", "closed_by_circuit_network", "disabled", "disabled_by_control_behavior", "disabled_by_script",
  "discharging", "fluid_ingredient_shortage", "full_output", "fully_charged", "item_ingredient_shortage", "launching_rocket", "low_input_fluid",
  "low_power", "low_temperature", "marked_for_deconstruction", "missing_required_fluid", "missing_science_packs", "networks_connected",
  "networks_disconnected", "no_ammo", "no_fuel", "no_ingredients", "no_input_fluid", "no_minable_resources", "no_modules_to_transmit", "no_power",
  "no_recipe", "no_research_in_progress", "normal", "not_connected_to_rail", "not_plugged_in_electric_network", "opened_by_circuit_network",
  "out_of_logistic_network", "preparing_rocket_for_launch", "recharging_after_power_outage", "turned_off_during_daytime", "waiting_for_source_items",
  "waiting_for_space_in_destination", "waiting_for_target_to_be_built", "waiting_for_train", "waiting_to_launch_rocket", "working" }

local function copy_faults(Df)
  local out = {}
  for i, f in ipairs(Df.FAULTS) do
    local x = {}
    for k, v in pairs(f) do x[k] = v end
    x.statuses = {}
    for j, st in ipairs(f.statuses) do x.statuses[j] = st end -- copie profonde : le test ne doit pas salir la table reelle
    out[i] = x
  end
  return out
end

local function battery(Df)
  -- 1. forme
  local bad = Df.validate()
  check(#bad == 0, "1 : table bien formee (" .. table.concat(bad, " ; ") .. ")")
  check(#Df.FAULTS >= 9, "1 : au moins 9 defauts (" .. #Df.FAULTS .. ")")
  local names = {}
  for name in pairs(Df.LEVERS) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    for _, pr in ipairs(Df.LEVERS[name]) do
      local src = slurp(pr[1])
      check(src:find(pr[2], 1, true) ~= nil, "1 : levier " .. name .. " : « " .. pr[2] .. " » existe dans " .. pr[1])
    end
  end
  local c1 = copy_faults(Df)
  c1[1].lever = "inconnu"
  check(#Df.validate(c1) > 0, "1 : levier inconnu refuse")
  local c2 = copy_faults(Df)
  c2[2].cause = c2[1].cause
  check(#Df.validate(c2) > 0, "1 : cause en double refusee")
  local c3 = copy_faults(Df)
  c3[1].signal = ""
  check(#Df.validate(c3) > 0, "1 : signal vide refuse")
  local lv = {}
  for k, v in pairs(Df.LEVERS) do lv[k] = v end
  lv.energie = {}
  check(#Df.validate(Df.FAULTS, lv) == 1, "1 : levier sans code cite refuse (et lui seul)")
  local c4 = copy_faults(Df)
  c4[2].statuses[#c4[2].statuses + 1] = c4[1].statuses[1]
  check(#Df.validate(c4) > 0, "1 : statut en double refuse")
  -- 2. couverture des statuts du moteur
  local routed = Df.status_cause()
  local seen = {}
  for _, st in ipairs(ENGINE) do
    local r, nf = routed[st], Df.NOT_FAULT[st]
    check((r ~= nil) ~= (nf ~= nil), "2 : statut " .. st .. " : route (" .. tostring(r) .. ") OU declare « pas une panne » (" .. tostring(nf) .. "), jamais les deux ni aucun")
    seen[st] = true
  end
  for _, st in ipairs(names) do end
  for st in pairs(routed) do check(seen[st], "2 : statut route inconnu du moteur : " .. st) end
  for st in pairs(Df.NOT_FAULT) do check(seen[st], "2 : statut « pas une panne » inconnu du moteur : " .. st) end
  local f = io.open("doc-html/runtime-api.json", "rb")
  if f then
    local doc = f:read("*a") f:close()
    for _, st in ipairs(ENGINE) do
      check(doc:find('"name":"' .. st .. '"', 1, true) ~= nil or doc:find('"name": "' .. st .. '"', 1, true) ~= nil, "2 : doc-html : " .. st)
    end
  end
  -- les causes de la confirmation
  local Cf = require("shared.ai3.confirmation")
  for _, c in ipairs({ Cf.CAUSE_NONE, Cf.CAUSE_UNREAD, Cf.CAUSE_LOST }) do check(Df.lookup(c) ~= nil, "2 : cause de la confirmation « " .. c .. " » dans la table") end
  check(Df.lookup("sortie") and Df.lookup("sortie").lever == "collecte" and Cf.KEEP.sortie == true, "2 : sortie pleine : levier collecte, capacite gardee (Cf.KEEP)")
  check(Df.lookup("courant").lever == "energie" and Df.lookup("entree").lever == "amont", "2 : courant -> energie, entree -> amont")
  check(Df.lookup("chantier occupe") ~= nil and Df.lookup("chantier occupe").lever == "relance", "2 : chantier occupe -> relance")
  -- 3. routage
  local ev = {
    { cause = "courant", item = "a", id = 1 }, { cause = "courant", item = "b", id = 2 }, { cause = "courant", item = "a", id = 3 },
    { cause = "sortie", item = "c", id = 4 }, { cause = "rien produit", item = "d", id = 5 },
    { cause = "cause-nouvelle", item = "e", id = 6 }, { cause = nil, item = "f", id = 7 }, { cause = "", id = 8 },
  }
  local r = Df.route(ev)
  check(r.total == 8, "3 : tous les evenements comptes (" .. r.total .. ")")
  check(#r.rows == 3 and r.rows[1].cause == "courant" and r.rows[1].n == 3 and r.rows[1].lever == "energie", "3 : courant : 3 unites vers le levier energie")
  check(table.concat(r.rows[1].items, ",") == "a,b", "3 : objets tries sans doublon")
  check(r.rows[2].cause == "rien produit" and r.rows[3].cause == "sortie", "3 : triees par cause")
  check(#r.unrouted == 2 and r.unrouted[1].cause == "(aucune)" and r.unrouted[1].n == 2 and r.unrouted[2].cause == "cause-nouvelle",
    "3 : cause inconnue ou absente NON ROUTEE, jamais ignoree")
  local r2 = Df.route(ev)
  check(Df.signature(r) == Df.signature(r2) and Df.signature(r) == "courant=3,rien produit=1,sortie=1,?(aucune)=2,?cause-nouvelle=1",
    "3 : deterministe : " .. Df.signature(r))
  check(#Df.route(nil).rows == 0 and Df.route({}).total == 0, "3 : aucun evenement : rien")
  local line = Df.line("emerald", r.rows[1], 12.5)
  check(line:find("[FO-DEFAUT] emerald : courant -> ", 1, true) == 1 and line:find("levier energie", 1, true) and line:find("3 unite(s) [a b]", 1, true),
    "3 : ligne [FO-DEFAUT] : " .. line)
  local lu = Df.line_unrouted("emerald", r.unrouted[2], 1)
  check(lu:find("defaut sans levier « cause-nouvelle »", 1, true) and lu:find("(a ajouter a Df.FAULTS)", 1, true), "3 : ligne d'un defaut sans levier : " .. lu)
  local st = Df.status_cause()
  check(st.no_power == "courant" and st.full_output == "sortie" and st.no_recipe == "recette" and st.no_minable_resources == "gisement epuise",
    "3 : table statut -> cause (no_minable_resources = gisement epuise) ")
end

local Df0 = assert(load_df())
battery(Df0)

-- 4. L'appel par la boucle de décision (lecture du texte du runtime : le relevé de la capitalisation).
do
  local cap = slurp("script/ai3/capitalisation.lua")
  check(cap:find('local Df = require("shared.ai3.defauts")', 1, true) ~= nil, "4 : la capitalisation requiert la table")
  check(cap:find("for _, fault in ipairs(Df.FAULTS) do", 1, true) ~= nil and cap:find('{ "courant", { "no_power"', 1, true) == nil,
    "4 : CONF_CAUSE est construit depuis Df.FAULTS (plus de seconde liste de statuts)")
  check(cap:find("Pil.defauts(f, cs, cfr, tick, minutes(f, tick))", 1, true) ~= nil, "4 : le releve de la confirmation appelle Pil.defauts")
  check(cap:find('Pil.note(cs, "chantier occupe", o.item)', 1, true) ~= nil, "4 : le repli d'un plan refuse note le defaut « chantier occupe »")
  local pil = slurp("script/ai3/pilotage.lua")
  check(pil:find("Df.route(events)", 1, true) ~= nil and pil:find("Df.line(key, row, mn)", 1, true) ~= nil and pil:find("Df.line_unrouted(key, row, mn)", 1, true) ~= nil,
    "4 : Pil.defauts route, ecrit chaque defaut et chaque defaut sans levier")
end

-- 5. Mutants
local MUTANTS = {
  { "statut de sortie pleine oublie", '"full_output", "waiting_for_space_in_destination"', '"waiting_for_space_in_destination"' },
  { "courant sans levier connu", 'lever = "energie", effect', 'lever = "inconnu", effect' },
  { "cause inconnue ignoree", "bucket = un[c] or { cause = c, n = 0, set = {} }", "bucket = { cause = c, n = 0, set = {} }" },
  { "evenement sans cause range avec les autres", 'if type(c) ~= "string" or c == "" then c = "(aucune)" end', 'if type(c) ~= "string" or c == "" then c = "courant" end' },
  { "tri des causes retire", "for _, c in ipairs(sorted_keys(map)) do", "for c in pairs(map) do" },
  { "objets non tries", "b.items, b.set = sorted_keys(b.set), nil", "b.items, b.set = {}, nil" },
  { "statut en double accepte", 'if seen_s[st] then bad[#bad + 1] = who .. " : statut en double « " .. st .. " »" end', "" },
  { "levier sans code accepte", 'if type(levers[name]) ~= "table" or #levers[name] == 0 then', "if false then" },
  { "gisement epuise lu comme entree", 'statuses = { "no_minable_resources" }', "statuses = {}" },
}
local killed = 0
quiet = true
local p0 = passes
for _, m in ipairs(MUTANTS) do
  local mod = load_df({ m[2], m[3] })
  local dead = false
  if not mod then
    dead = true
  else
    local fb = failures
    local ok = pcall(battery, mod)
    if not ok or failures > fb then dead = true end
    failures = fb
  end
  if dead then killed = killed + 1 else quiet = false; check(false, "5 : mutant survivant : " .. m[1]); quiet = true end
end
quiet = false
passes = p0
check(killed == #MUTANTS, string.format("5 : mutants refuses %d / %d", killed, #MUTANTS))

print(string.format("[DEFAUTS] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
