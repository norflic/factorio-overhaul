--[[
  Lot BLOCAGE-COMBUSTIBLE : test hors jeu de shared/team/ravitaillement.lua (charbon des coffres propres d'un avant-poste, verdict d'une
  tournee courte, journal [FO-RAVITAILLEMENT]).
    §1 quota sur place ; §2 verdict d'une tournee ; §3 cadence du journal ; §4 cablage (texte) ; §5 aucun nom d'objet du jeu ;
    §6 mutants : chaque regle faussee est vue.
  Usage, depuis la racine du mod :   lua5.2 tests/ravitaillement_test.lua
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/ravitaillement.lua"

local function read(p)
  local h = assert(io.open(p, "rb"))
  local s = h:read("*a")
  h:close()
  return s
end
local SRC = read(PATH)

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[RAVITAILLEMENT] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end

local function suite(Rv)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  -- §1 quota : ce qui manque aux bruleurs apres ce que le porteur a deja, entier, jamais negatif
  c("quota : besoin 1310, rien porte -> 1310", Rv.onsite_quota(1310, 0) == 1310)
  c("quota : besoin 1310, 300 portes -> 1010", Rv.onsite_quota(1310, 300) == 1010)
  c("quota : porte >= besoin -> 0 (rien a prendre sur place)", Rv.onsite_quota(100, 100) == 0 and Rv.onsite_quota(100, 400) == 0)
  c("quota : besoin nul ou absent -> 0", Rv.onsite_quota(0, 0) == 0 and Rv.onsite_quota(nil, nil) == 0 and Rv.onsite_quota(-5, 0) == 0)
  c("quota : donnee illisible (NaN, texte) -> traitee comme 0", Rv.onsite_quota(0 / 0, 0) == 0 and Rv.onsite_quota("x", 0) == 0)
  c("quota : fraction arrondie vers le bas", Rv.onsite_quota(10.7, 0) == 10)
  -- §2 verdict
  c("verdict : plus aucun bruleur bas -> ok", Rv.cause({ low_after = 0, need = 100, carried = 0, took = 0, left = 50, skipped = true, stock = 0 }) == "ok")
  c("verdict : du combustible RESTE dans les coffres propres alors que le ramassage l'ecarte -> ramassage_ecarte",
    Rv.cause({ low_after = 126, need = 1310, carried = 300, took = 0, left = 1000, skipped = true, stock = 9000 }) == "ramassage_ecarte")
  c("verdict : combustible reste mais ramassage permis -> pas ramassage_ecarte (porte insuffisant)",
    Rv.cause({ low_after = 5, need = 1310, carried = 300, took = 0, left = 1000, skipped = false, stock = 9000 }) == "porte_insuffisant")
  c("verdict : coffre du QG sans combustible libre -> coffre_sans_charbon",
    Rv.cause({ low_after = 30, need = 400, carried = 100, took = 0, left = 0, skipped = false, stock = 20 }) == "coffre_sans_charbon")
  c("verdict : le QG en avait assez mais le porteur n'en avait pas pris assez -> porte_insuffisant",
    Rv.cause({ low_after = 30, need = 400, carried = 100, took = 0, left = 0, skipped = false, stock = 5000 }) == "porte_insuffisant")
  c("verdict : besoin couvert par le porte et le ramasse mais des bruleurs restent bas -> autre",
    Rv.cause({ low_after = 3, need = 100, carried = 80, took = 40, left = 0, skipped = false, stock = 5000 }) == "autre")
  c("verdict : champ absent -> traite comme 0, jamais d'erreur", Rv.cause({ low_after = 1 }) == "autre")
  -- §3 cadence du journal : 6 premieres une a une, puis une sur dix
  local seen = {}
  for n = 1, 40 do if Rv.log_due(n) then seen[#seen + 1] = n end end
  c("journal : tournees 1 a 6 ecrites, puis 16, 26, 36", table.concat(seen, ",") == "1,2,3,4,5,6,16,26,36", table.concat(seen, ","))
  c("journal : rang nul, negatif ou illisible -> rien", Rv.log_due(0) == false and Rv.log_due(-3) == false and Rv.log_due(nil) == false)
  -- §3 bis tournee futile : bruleurs encore bas et rien pose -> pause de 60 s sur la signalisation du manque
  c("futile : bas apres tournee, rien pose -> pause", Rv.pause_until({ low_after = 126, placed = 0, tick = 1000 }) == 1000 + Rv.FUTILE_PAUSE)
  c("futile : rien pose et rien d'autre bas -> pas de pause", Rv.pause_until({ low_after = 0, placed = 0, tick = 1000 }) == nil)
  c("futile : du combustible a ete pose (tournee utile mais courte) -> pas de pause", Rv.pause_until({ low_after = 5, placed = 40, tick = 1000 }) == nil)
  c("pause : court jusqu'a l'echeance exclue", Rv.paused(4600, 4599) == true and Rv.paused(4600, 4600) == false)
  c("pause : absente (nil) -> ne court pas, tick absent -> traite comme 0", Rv.paused(nil, 10) == false and Rv.paused(5, nil) == false)
  c("pause : 60 secondes (3600 ticks)", Rv.FUTILE_PAUSE == 3600)
  -- §3 ter (lot COMBUSTIBLE) fours d'un champ ravitailles a la main : un four a sec entre, un four entre reste tant qu'il est debout
  local function ids(prev, rows) return table.concat(Rv.field_burners(prev, rows), ",") end
  c("champ : amber 314159265, 16 fours tous a sec, aucun connu -> les 16, dans l'ordre du plan", (function()
    local rows = {}
    for i = 16, 1, -1 do rows[#rows + 1] = { id = 100 + i, dry = true } end
    return ids({}, rows) == "116,115,114,113,112,111,110,109,108,107,106,105,104,103,102,101"
  end)())
  c("champ : un four qui tourne et jamais vu a sec n'entre pas", ids({}, { { id = 1, dry = false }, { id = 2, dry = true } }) == "2")
  c("champ : un four deja ravitaille a la main reste, meme plein (sa voie ne le tient pas encore)",
    ids({ [1] = true }, { { id = 1, dry = false }, { id = 2, dry = false } }) == "1")
  c("champ : un four connu absent du releve (detruit) sort", ids({ [1] = true, [9] = true }, { { id = 1, dry = false } }) == "1")
  c("champ : un four releve deux fois n'est compte qu'une fois", ids({}, { { id = 4, dry = true }, { id = 4, dry = true } }) == "4")
  c("champ : aucun four, liste absente ou illisible -> liste vide, jamais d'erreur",
    ids({}, {}) == "" and ids(nil, nil) == "" and ids("x", "y") == "" and ids({}, { "x", { dry = true } }) == "")
  c("champ : dry doit valoir vrai (un etat illisible n'est pas a sec)", ids({}, { { id = 1, dry = "non" }, { id = 2 } }) == "")
  return res
end

local function load_rv(text)
  local chunk = load(text, "=" .. PATH, "t")
  if not chunk then return nil end
  local ok, m = pcall(chunk)
  return ok and m or nil
end

local function run(text)
  local Rv = load_rv(text)
  if not Rv then return { { "module illisible", false } } end
  local okr, res = pcall(suite, Rv)
  if not okr then return { { "suite : " .. tostring(res), false } } end
  return res
end

for _, r in ipairs(run(SRC)) do check(r[1], r[2], r[3]) end

-- §4 cablage (texte)
do
  local op, wk = read("script/faction/outposts.lua"), read("script/team/worker.lua")
  check("cablage : outposts requiert la regle", op:find('require("shared.team.ravitaillement")', 1, true) ~= nil)
  check("cablage : la tournee ecrit [FO-RAVITAILLEMENT] avec le verdict de la regle",
    op:find("[FO-RAVITAILLEMENT]", 1, true) ~= nil and op:find("Rv.cause({", 1, true) ~= nil and op:find("Rv.log_due(o.coal_short)", 1, true) ~= nil)
  check("cablage : le journal ne s'ecrit que pour une tournee courte et une information passee par l'appelant",
    op:find("if info and Rv.log_due(o.coal_short) then", 1, true) ~= nil)
  check("cablage : le ramassage prend le combustible des coffres propres jusqu'au quota meme quand le stock l'ecarte",
    op:find("local collected = collect(sinks, carrier, skip, skip and Rv.onsite_quota(need0, carried0) or 0)", 1, true) ~= nil
    and op:find("elseif name == T.fuel and quota > 0 then", 1, true) ~= nil and op:find("quota = quota - moved", 1, true) ~= nil)
  check("cablage : status ne signale plus le manque pendant la pause d'une tournee futile",
    op:find("if low and Rv.paused(o.futile_until, tick) then low = false end", 1, true) ~= nil
    and op:find("o.futile_until = Rv.pause_until({ low_after = short, placed = placed, tick = tick })", 1, true) ~= nil)
  -- lot COMBUSTIBLE : fours du champ a sec dans la liste des bruleurs de leur avant-poste ; un seul ecrivain (le releve des champs)
  local cp = read("script/team/champ.lua")
  local function count(text, pat) local n, i = 0, 1 while true do local a, b = text:find(pat, i, true) if not a then return n end n, i = n + 1, b + 1 end end
  check("cablage : la liste des bruleurs d'un avant-poste lit les fours de son champ vus a sec",
    op:find("for _, s in ipairs(valid_list(o.champ_burners)) do list[#list + 1] = s end", 1, true) ~= nil)
  check("cablage : le releve des champs ecrit la liste par la regle, pour chaque avant-poste, avant toute sortie",
    cp:find("for _, id in ipairs(Rv.field_burners(prev, fo and fo.rows or {})) do list[#list + 1] = fo.ents[id] end", 1, true) ~= nil
    and cp:find("  Champ.field_burners(f, fours, tick)\n  if #ids == 0 then return end", 1, true) ~= nil)
  check("cablage : un four entre au releve par son etat « sans combustible », seulement s'il a un bruleur",
    cp:find("if ent.burner and ent.unit_number then", 1, true) ~= nil and cp:find("dry = s == S.no_fuel }", 1, true) ~= nil)
  check("cablage : un seul ecrivain de o.champ_burners", count(cp, "o.champ_burners = ") == 1 and count(op, "o.champ_burners = ") == 0)
  check("cablage : l'acte de service passe la force et le stock du combustible",
    wk:find('{ key = f.key or "player", stock = function() return Stock.count(f, T.fuel) end }', 1, true) ~= nil)
end

-- §5 aucun nom d'objet du jeu dans le module (le combustible arrive en donnees)
do
  local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local bad_names = {}
  for _, w in ipairs({ "coal", "iron", "copper", "stone", "wood", "burner", "furnace", "plate", "ore" }) do
    if code:find('"' .. w, 1, true) or code:find("'" .. w, 1, true) then bad_names[#bad_names + 1] = w end
  end
  check("pur : aucun nom d'objet du jeu dans le code du module", #bad_names == 0, table.concat(bad_names, ","))
  check("pur : aucun pairs ni os.clock ni game dans le module", not code:find("pairs%(") and not code:find("os%.clock") and not code:find("game%."))
end

-- §6 mutants : chaque regle faussee doit etre vue par la suite
local function mutant(name, from, to)
  local a, b = SRC:find(from, 1, true)
  if not a then check("mutant « " .. name .. " » : motif trouve dans le module", false, from) return end
  local text = SRC:sub(1, a - 1) .. to .. SRC:sub(b + 1)
  local seen_fail = false
  for _, r in ipairs(run(text)) do if r[2] ~= true then seen_fail = true break end end
  check("mutant « " .. name .. " » refuse par la suite", seen_fail)
end
mutant("quota sans le porte", "local q = num(need) - num(carried)", "local q = num(need)")
mutant("quota negatif possible", "if q < 0 then return 0 end", "")
mutant("quota non entier", "return q - q % 1", "return q")
mutant("verdict ok jamais rendu", 'if num(a.low_after) <= 0 then return "ok" end', "")
mutant("ramassage ecarte ignore", 'if num(a.left) > 0 and a.skipped == true then return "ramassage_ecarte" end', "")
mutant("ramassage ecarte sans le drapeau", "if num(a.left) > 0 and a.skipped == true then", "if num(a.left) > 0 then")
mutant("coffre sans charbon confondu", 'then return "coffre_sans_charbon" end', 'then return "porte_insuffisant" end')
mutant("six premieres du journal", "Rv.LOG_FIRST = 6", "Rv.LOG_FIRST = 2")
mutant("une sur dix du journal", "Rv.LOG_EVERY = 10", "Rv.LOG_EVERY = 1")
mutant("pause sans rien pose exigee", "and num(a.placed) <= 0 then", "then")
mutant("pause jamais", "if num(a.low_after) > 0 and num(a.placed) <= 0 then return num(a.tick) + Rv.FUTILE_PAUSE end", "")
mutant("pause eternelle", "return num(tick) < until_tick", "return true")
mutant("pause d'une seconde", "Rv.FUTILE_PAUSE = 3600", "Rv.FUTILE_PAUSE = 60")
mutant("rang nul ecrit", "if n <= 0 then return false end", "")
mutant("champ : four a sec jamais pris", "(r.dry == true or prev[r.id] == true)", "(prev[r.id] == true)")
mutant("champ : four connu oublie des qu'il a du combustible", "(r.dry == true or prev[r.id] == true)", "(r.dry == true)")
mutant("champ : tous les fours pris", "(r.dry == true or prev[r.id] == true)", "true")
mutant("champ : doublons gardes", "not seen[r.id] and ", "")
mutant("champ : fours connus gardes sans releve", "for i = 1, #rows do", "for id in next, prev do keep[#keep + 1] = id end for i = 1, #rows do")

print(string.format("[RAVITAILLEMENT] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
