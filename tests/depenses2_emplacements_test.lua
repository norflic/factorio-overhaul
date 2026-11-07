--[[
  Lot DEPENSES2, essai 4 (c) : siège du COMPLÉMENT du stock qui dort (shared/ai3/emplacements.lua, règle 7). Quand un produit des
  fonderies dort et qu'un autre ne dort pas, Em.COMP_SLOTS emplacement de plus est réservé aux modules qui produisent celui qui ne
  dort pas ; jamais plus d'un siège. Mutants de code et de constante.
  Usage : lua5.2 tests/depenses2_emplacements_test.lua (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path

local passes, failures, quiet = 0, 0, false
local function check(c, msg)
  if c then passes = passes + 1 else failures = failures + 1 if not quiet then print("[DEPENSES2-EMPL] ECHEC : " .. msg) end end
end
local fh = assert(io.open("shared/ai3/emplacements.lua", "rb"))
local SRC = fh:read("*a")
fh:close()
local function load_em(src) return assert(load(src, "=emplacements"))() end

local NAMES = { "fer", "cuivre" }
local function mat(key) return { key = key, states = { "attente" }, opened = 0 } end

local function suite(Em)
  -- complément
  local c = Em.complement(NAMES, { fer = true })
  check(c ~= nil and c.cuivre == true and c.fer == nil, "le fer dort : complément = le cuivre")
  check(Em.complement(NAMES, { fer = true, cuivre = true }) == nil, "tout dort : aucun complément")
  check(Em.complement(NAMES, {}) == nil and Em.complement(NAMES, nil) == nil, "rien ne dort : aucun complément")
  -- emplacements pleins, le fer dort : un siège de plus pour le cuivre seulement
  local s = Em.slots({ base = 2, plates = { 5000, 300 }, mods = { mat("a"), mat("b") }, tick = 100, names = NAMES, sleeping = { fer = true } })
  check(s.busy and s.room == 0, "emplacements ordinaires pleins (2 sur 2)")
  check(s.room_comp == 1, "siège du complément : 1 (" .. tostring(s.room_comp) .. ")")
  check(Em.comp_ok(s, "cuivre") and not Em.comp_ok(s, "fer"), "le siège va au cuivre, pas au fer qui dort")
  check(s.why:find("complement du stock qui dort (cuivre)", 1, true) ~= nil, "journal : complément nommé (" .. s.why .. ")")
  -- un module ouvert dans le siège est compté : plus de siège
  local s3 = Em.slots({ base = 2, plates = { 5000, 300 }, mods = { mat("a"), mat("b"), mat("c") }, tick = 100, names = NAMES, sleeping = { fer = true } })
  check(s3.room_comp == 0 and not Em.comp_ok(s3, "cuivre"), "jamais plus d'un siège (3 modules : 0)")
  -- rien ne dort : la règle d'avant
  local s0 = Em.slots({ base = 2, plates = { 5000, 300 }, mods = { mat("a"), mat("b") }, tick = 100, names = NAMES, sleeping = {} })
  check(s0.comp == nil and s0.room_comp == s0.room and not Em.comp_ok(s0, "cuivre"), "rien ne dort : aucun siège de plus")
  local sn = Em.slots({ base = 2, plates = { 5000, 300 }, mods = { mat("a"), mat("b") }, tick = 100 })
  check(sn.comp == nil and sn.room_comp == 0 and sn.why:find("complement", 1, true) == nil, "appel d'avant (sans names ni sleeping) : inchangé")
  -- avec un stock riche (Em.extra) : le siège s'ajoute au plafond
  local sr = Em.slots({ base = 2, plates = { 5000, 1500 }, mods = { mat("a"), mat("b") }, tick = 100, names = NAMES, sleeping = { fer = true } })
  check(sr.cap == 3 and sr.room == 1 and sr.room_comp == 2, "stock riche : plafond 3, libres 1, siège du complément 2")
  -- Relecture (point 4) : les décisions du runtime (capitalisation.lua : foreuses « plan directeur occupe », siège d'un ordre, décompte)
  check(Em.drill_refused(s, "fer") and not Em.drill_refused(s, "cuivre"), "foreuse : le fer qui dort refusé, le cuivre servi par le siège")
  check(Em.drill_refused(s3, "cuivre"), "foreuse : siège pris, le cuivre refusé lui aussi")
  check(not Em.drill_refused(sr, "fer") and not Em.drill_refused(nil, "fer"), "foreuse : emplacement libre ou aucun relevé : jamais refusée")
  check(Em.order_seat(0, 1, s.comp, "cuivre") == "complement" and Em.order_seat(0, 1, s.comp, "fer") == nil,
    "ordre : plein, le cuivre prend le siège, le fer est refusé")
  check(Em.order_seat(0, 1, s.comp, nil) == nil, "ordre qui n'est pas une foreuse (chaîne) : refusé quand c'est plein")
  check(Em.order_seat(2, 3, s.comp, "fer") == "ordinaire" and Em.order_seat(nil, nil, nil, "fer") == "libre", "ordre : place ordinaire, ou aucun plafond")
  check(Em.order_seat(0, 0, s.comp, "cuivre") == nil, "ordre : siège déjà pris dans la décision : refusé")
  local r1, c1 = Em.take(0, 1, 1)
  check(r1 == -1 and c1 == 0 and Em.order_seat(r1, c1, s.comp, "cuivre") == nil, "décompte : un module envoyé prend le siège, le suivant est refusé")
  local r2, c2 = Em.take(nil, nil, 2)
  check(r2 == nil and c2 == nil, "décompte sans plafond : rien")
end

suite(load_em(SRC))
local function mutant(name, old, new, const)
  local src = SRC
  if old then
    local i = src:find(old, 1, true)
    if not i then check(false, "mutant introuvable : " .. name) return end
    src = src:sub(1, i - 1) .. new .. src:sub(i + #old)
  end
  local before, pb = failures, passes
  quiet = true
  local ok = pcall(function() local Em = load_em(src) if const then const(Em) end suite(Em) end)
  quiet = false
  local caught = (not ok) or failures > before
  failures, passes = before, pb
  check(caught, "mutant détecté : " .. name)
end
mutant("aucun siège", nil, nil, function(Em) Em.COMP_SLOTS = 0 end)
mutant("deux sièges", nil, nil, function(Em) Em.COMP_SLOTS = 2 end)
mutant("complément sans rien qui dort", "if any_sleep and any_comp then return comp end", "if any_comp then return comp end")
mutant("complément qui dort aussi", "if (sleeping or {})[n] then any_sleep = true else", "if (sleeping or {})[n] then any_sleep = true comp[n] = true else")
mutant("siège sans compte", "and (sl.room_comp or 0) > 0", "")
mutant("siège ouvert à tout produit", "sl.comp[product] == true", "true")
mutant("siège sans plafond", "room_comp = math.max(0, cap + Em.COMP_SLOTS - counted)", "room_comp = cap + Em.COMP_SLOTS")
mutant("foreuse : siège ignoré", "return sl ~= nil and sl.busy == true and not Em.comp_ok(sl, product)", "return sl ~= nil and sl.busy == true")
mutant("ordre : siège à tout produit", "comp ~= nil and product ~= nil and comp[product] == true and (room_comp or 0) > 0 then return \"complement\"", "(room_comp or 0) > 0 then return \"complement\"")
mutant("ordre : siège sans compte", "comp[product] == true and (room_comp or 0) > 0 then", "comp[product] == true then")
mutant("décompte du siège oublié", "room_comp ~= nil and room_comp - n or nil", "room_comp")
print(string.format("[DEPENSES2-EMPL] BILAN : %d OK, %d ECHEC(S) (dont 11 mutants)", passes, failures))
os.exit(failures == 0 and 0 or 1)
