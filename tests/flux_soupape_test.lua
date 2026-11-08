--[[
  Lot TV-FLUX, point V42 (docs/TODO_VIDEO.md l.108, M32 « la soupape ») : test hors jeu des règles pures branchées par script/ai3/petrole.lua
  (Pet.valve_think) : Fl.valve_reading, Fl.valve_row, Fl.valve_convert (shared/ai3/fluides.lua), avec Fl.valve et Fl.valve_recipe du lot 6.
    §1 la lecture des machines d'un site : cuve la plus pleine, débouchés OUVERTS (machines qui travaillent et mangent le fluide) ;
    §2 la ligne de la recette de surplus lue au relevé, jamais par un nom ;
    §3 la conversion : bornée par le temps (vitesse de la machine), le fluide de la cuve, la place du coffre ;
    §4 la boucle complète (jouet) : cuve qui se remplit sans débouché, soupape ouverte à la K-ième mesure, cuve vidée, soupape refermée,
       la chaîne amont repart ; débouché rouvert = soupape fermée ;
    §5 anti-échelle : aucun nom du jeu dans le bloc ajouté ; §6 mutants (substitution dans la source).
  Lancement, depuis la racine du mod :   lua5.2 tests/flux_soupape_test.lua   -> [FLUX-SOUPAPE] BILAN : N OK, 0 ECHEC(S)
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1 if not quiet then print("[FLUX-SOUPAPE] ECHEC : " .. msg) end end
  return cond
end
local function say(s) if not quiet then print("[FLUX-SOUPAPE] " .. s) end end
local function read_all(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local SRC = read_all("shared/ai3/fluides.lua")

local function suite(Fl, chk)
  -- §1 lecture
  local rows = {
    { out = { { fluid = "fz", amount = 900, capacity = 1000 } }, ins = {}, working = true },                       -- producteur plein à 90 %
    { out = { { fluid = "fz", amount = 950, capacity = 1000 } }, ins = {}, working = false },                      -- second producteur à 95 %
    { out = {}, ins = { "fz" }, working = true },                                                                   -- consommateur qui travaille
    { out = {}, ins = { "fz", "fz" }, working = true },                                                             -- idem, fluide cité deux fois : une fois
    { out = {}, ins = { "fz" }, working = false },                                                                  -- consommateur à l'arrêt : pas un débouché
    { out = { { fluid = "gy", amount = 10, capacity = 0 } }, ins = {}, working = true },                           -- capacité nulle : ignorée
    { out = { { fluid = "hh", amount = 5, capacity = 100 } }, ins = { "orphelin" }, working = true },             -- fluide sans producteur : ignoré
  }
  local rd = Fl.valve_reading(rows)
  chk(#rd == 2 and rd[1].fluid == "fz" and rd[2].fluid == "hh", "§1 fluides relevés, triés : fz et hh (capacité nulle et fluide sans producteur écartés)")
  chk(math.abs(rd[1].fill - 0.95) < 1e-9, "§1 la cuve la plus pleine de fz : 95 %")
  chk(rd[1].outlets == 2 and rd[1].producers == 2, "§1 deux débouchés ouverts (l'arrêté et le doublon ne comptent pas), deux producteurs")
  chk(rd[2].outlets == 0 and math.abs(rd[2].fill - 0.05) < 1e-9, "§1 hh : 5 %, aucun débouché")
  local over = Fl.valve_reading({ { out = { { fluid = "fz", amount = 5000, capacity = 1000 } }, ins = {}, working = false } })
  chk(over[1].fill == 1, "§1 remplissage plafonné à 100 %")
  chk(#Fl.valve_reading(nil) == 0 and #Fl.valve_reading({}) == 0, "§1 aucune machine : aucune lecture")

  -- §2 ligne de la recette de surplus
  local rel = { recipes = {
    ["rec-solide"] = { energy = 2, ingredients = { { type = "fluid", name = "fz", amount = 10 } }, products = { { type = "item", name = "sol", amount = 1 } } },
    ["rec-deux-fluides"] = { energy = 2, ingredients = { { type = "fluid", name = "fz", amount = 10 }, { type = "fluid", name = "autre", amount = 5 } },
      products = { { type = "item", name = "sol", amount = 1 } } },
    ["rec-produit-fluide"] = { energy = 2, ingredients = { { type = "fluid", name = "fz", amount = 10 } }, products = { { type = "fluid", name = "gy", amount = 1 } } },
    ["rec-autre-fluide"] = { energy = 2, ingredients = { { type = "fluid", name = "autre", amount = 10 } }, products = { { type = "item", name = "sol", amount = 1 } } },
    ["aa-remplir"] = { energy = 0.2, ingredients = { { type = "fluid", name = "fz", amount = 50 }, { type = "item", name = "vide", amount = 1 } },
      products = { { type = "item", name = "plein", amount = 1 } } },
    ["rec-sans-fluide"] = { energy = 2, ingredients = { { type = "item", name = "sol", amount = 10 } }, products = { { type = "item", name = "sol2", amount = 1 } } },
    ["rec-aleatoire"] = { energy = 0, ingredients = { { type = "fluid", name = "fz", amount = 20 } },
      products = { { type = "item", name = "sol", amount_min = 1, amount_max = 3, probability = 0.5 }, { type = "item", name = "aaa", amount = 2 } } },
  } }
  local row = Fl.valve_row(rel, "rec-solide", "fz")
  chk(row and row.recipe == "rec-solide" and row.fluid_in == 10 and row.energy == 2 and #row.products == 1 and row.products[1].name == "sol" and row.products[1].amount == 1,
    "§2 ligne lue : 10 unités de fluide, 2 s, 1 objet")
  chk(Fl.valve_row(rel, "rec-deux-fluides", "fz") == nil, "§2 deux fluides en entrée : pas une soupape")
  chk(Fl.valve_row(rel, "rec-produit-fluide", "fz") == nil, "§2 produit fluide : pas une soupape")
  chk(Fl.valve_row(rel, "rec-autre-fluide", "fz") == nil, "§2 mange un autre fluide : refusé")
  chk(Fl.valve_row(rel, "rec-sans-fluide", "fz") == nil, "§2 aucun fluide en entrée : refusé")
  chk(Fl.valve_row(rel, "aa-remplir", "fz") == nil, "§2 un ingrédient solide (contenant vide) : pas une soupape, la soupape ne le paie pas")
  chk(Fl.valve_recipe(rel, "fz") == "rec-aleatoire", "§2 la recette de surplus choisie est la première SANS ingrédient solide (le remplissage d'un contenant, avant par le nom, est écarté)")
  chk(Fl.valve_row(rel, "absente", "fz") == nil and Fl.valve_row(rel, nil, "fz") == nil and Fl.valve_row(nil, "rec-solide", "fz") == nil, "§2 recette absente ou relevé absent : nil")
  local ra = Fl.valve_row(rel, "rec-aleatoire", "fz")
  chk(ra and ra.products[1].name == "aaa" and ra.products[2].name == "sol" and math.abs(ra.products[2].amount - 1) < 1e-9 and ra.energy == 0.05,
    "§2 produits triés, quantité moyenne × probabilité (2 × 0,5 = 1), énergie plancher 0,05 s")

  -- §3 conversion
  local r1 = Fl.valve_row(rel, "rec-solide", "fz")
  local c = Fl.valve_convert(r1, 1, 10000, 1, { sol = 10000 })
  chk(c.crafts == 30 and c.fluid == 300 and c.items[1].name == "sol" and c.items[1].count == 30 and c.limit == "temps", "§3 1 minute, vitesse 1, 2 s : 30 fabrications, borné par le temps")
  c = Fl.valve_convert(r1, 2, 10000, 0.5, { sol = 10000 })
  chk(c.crafts == 30, "§3 vitesse 2 sur une demi-minute : 30 fabrications")
  c = Fl.valve_convert(r1, 1, 95, 1, { sol = 10000 })
  chk(c.crafts == 9 and c.fluid == 90 and c.limit == "fluide", "§3 95 unités de fluide : 9 fabrications (90 unités), borné par le fluide")
  c = Fl.valve_convert(r1, 1, 10000, 1, { sol = 4 })
  chk(c.crafts == 4 and c.items[1].count == 4 and c.limit == "place", "§3 place pour 4 objets : 4 fabrications, borné par la place")
  c = Fl.valve_convert(r1, 1, 10000, 1, {})
  chk(c.crafts == 0 and #c.items == 0 and c.limit == "place", "§3 coffre plein : rien, limite « place »")
  c = Fl.valve_convert(r1, 1, 5, 1, { sol = 100 })
  chk(c.crafts == 0 and c.limit == "fluide", "§3 moins d'une fabrication de fluide : rien, limite « fluide »")
  chk(Fl.valve_convert(r1, 1, 100, 0, { sol = 9 }).crafts == 0 and Fl.valve_convert(r1, 0, 100, 1, { sol = 9 }).crafts == 0
    and Fl.valve_convert(r1, 1, 0, 1, { sol = 9 }).crafts == 0 and Fl.valve_convert(nil, 1, 100, 1, { sol = 9 }).crafts == 0, "§3 durée, vitesse, fluide nuls ou ligne absente : rien")
  chk(Fl.valve_convert(r1, 1, 100, 1, { sol = 9 }).limit == "place" and Fl.valve_convert(r1, 0, 100, 1, { sol = 9 }).limit == "rien", "§3 limites dites")
  local rm = Fl.valve_row(rel, "rec-aleatoire", "fz")
  c = Fl.valve_convert(rm, 1, 1000, 1, { sol = 1000, aaa = 7 })
  chk(c.crafts == 3 and #c.items == 2 and c.items[1].name == "aaa" and c.items[1].count == 6 and c.items[2].name == "sol" and c.items[2].count == 3,
    "§3 deux produits : la place du plus contraint borne (7 ÷ 2 = 3 fabrications)")
  c = Fl.valve_convert(rm, 1, 1000, 1, { sol = 2, aaa = 1000 })
  chk(c.crafts == 2 and c.limit == "place", "§3 deux produits : le second, plus contraint, borne aussi (2 fabrications)")

  -- §4 la boucle complète (jouet) : producteur de 100 unités par mesure dans une cuve de 1 000, un débouché qui s'arrête
  local function sim(outlet_after, steps)
    local st = Fl.valve_new()
    local tank, opened_at, closed_at, open_prev = 800, nil, nil, false
    local conv_total, chest = 0, 0
    local producer_running = true
    local timeline = {}
    for k = 1, steps do
      if producer_running then tank = math.min(1000, tank + 100) end
      local working = (k < outlet_after)
      -- un débouché qui travaille ôte 150 unités par mesure
      if working then tank = math.max(0, tank - 150) end
      local reading = Fl.valve_reading({ { out = { { fluid = "fz", amount = tank, capacity = 1000 } }, ins = {}, working = false },
        { out = {}, ins = { "fz" }, working = working } })
      local rd1 = reading[1]
      local d = Fl.valve(st, "fz", rd1.fill, rd1.outlets, "rec-solide")
      if d.open then
        local cv = Fl.valve_convert(r1, 1, tank, 0.5, { sol = 100000 - chest })
        tank = tank - cv.fluid
        chest = chest + (cv.items[1] and cv.items[1].count or 0)
        conv_total = conv_total + cv.fluid
      end
      if d.open and not open_prev and not opened_at then opened_at = k end
      if open_prev and not d.open and not closed_at then closed_at = k end
      open_prev = d.open
      timeline[#timeline + 1] = { k = k, tank = tank, open = d.open }
    end
    return { opened_at = opened_at, closed_at = closed_at, tank = tank, conv = conv_total, chest = chest, timeline = timeline }
  end
  local s1 = sim(0, 40) -- aucun débouché : la cuve se remplit, la soupape s'ouvre
  chk(s1.opened_at ~= nil and s1.opened_at > Fl.VALVE_K - 1, "§4 sans débouché : la soupape ne s'ouvre qu'à la K-ième mesure pleine (mesure " .. tostring(s1.opened_at) .. ")")
  chk(s1.conv > 0 and s1.chest > 0 and s1.closed_at ~= nil, "§4 sans débouché : du fluide converti en objets, puis la cuve redescend et la soupape se referme")
  local s2 = sim(1000, 40) -- le débouché travaille toujours : la cuve ne dépasse jamais 90 %
  chk(s2.opened_at == nil and s2.conv == 0, "§4 débouché qui travaille : la soupape reste fermée")
  local s3 = sim(15, 60) -- le débouché s'arrête à la mesure 15 : la soupape s'ouvre APRÈS, jamais avant
  chk(s3.opened_at ~= nil and s3.opened_at >= 15 + Fl.VALVE_K - 1, "§4 débouché arrêté à la mesure 15 : ouverture à partir de la mesure " .. tostring(s3.opened_at))
  local det = sim(0, 40)
  chk(#det.timeline == #s1.timeline and det.tank == s1.tank and det.chest == s1.chest, "§4 déterminisme : même entrée, même suite")
end

suite(dofile("shared/ai3/fluides.lua"), check)
say(string.format("suite principale : %d OK, %d ECHEC(S)", pass, fail))

-- §5 anti-échelle
local block = SRC:match("Lot TV%-FLUX %(V42.*$") or ""
check(#block > 1000, "§5 bloc TV-FLUX présent dans la source")
for _, w in ipairs({ "petroleum", "crude", "water", "sulfur", "plastic", "chemical", "pumpjack", "refinery", "solid%-fuel", "fuel", "gas", "iron", "coal" }) do
  check(not block:lower():find(w), "§5 nom du jeu dans le bloc TV-FLUX : " .. w)
end

-- §6 mutants
local function mutate(old, new)
  local i, j = SRC:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  assert(not SRC:find(old, j + 1, true), "mutant : motif ambigu : " .. old)
  return SRC:sub(1, i - 1) .. new .. SRC:sub(j + 1)
end
local MUTANTS = {
  { "débouché sans travail compté", "  for _, r in ipairs(rows or {}) do\n    if r.working then", "  for _, r in ipairs(rows or {}) do\n    if true then" },
  { "débouché compté deux fois", "if by[fl] and not seen[fl] then seen[fl] = true;", "if by[fl] then seen[fl] = true;" },
  { "cuve la plus pleine remplacée par la plus vide", "if fill > e.fill then e.fill = fill end", "if e.producers == 1 or fill < e.fill then e.fill = fill end" },
  { "remplissage non plafonné", "local fill = math.min(1, math.max(0, o.amount / o.capacity))", "local fill = o.amount / o.capacity" },
  { "capacité nulle acceptée", "if type(o.capacity) == \"number\" and o.capacity > 0 and", "if type(o.capacity) == \"number\" and" },
  { "deux fluides en entrée acceptés", "if i.name ~= fluide then return nil end", "" },
  { "produit fluide accepté", "if p.type ~= \"item\" then return nil end", "" },
  { "ingrédient solide accepté par la ligne", "      return nil -- un ingrédient solide (contenant vide...) : la soupape ne le paie pas", "" },
  { "ingrédient solide accepté par le choix", "if takes and fluid_in == 1 and only_item_out and not solid_in then return name end", "if takes and fluid_in == 1 and only_item_out then return name end" },
  { "probabilité ignorée", "if type(p.probability) == \"number\" then a = a * p.probability end", "" },
  { "borne de temps ignorée", "local crafts, limit = by_time, \"temps\"", "local crafts, limit = math.huge, \"temps\"" },
  { "borne de fluide ignorée", "if by_fluid < crafts then crafts, limit = by_fluid, \"fluide\" end", "" },
  { "borne de place ignorée", "if by_room < crafts then crafts, limit = by_room, \"place\" end", "" },
  { "vitesse ignorée", "local by_time = math.floor(speed * 60 * dt_min / row.energy + 1e-9)", "local by_time = math.floor(60 * dt_min / row.energy + 1e-9)" },
  { "place du premier produit seulement", "if p.amount > 0 then by_room = math.min(by_room,", "if p.amount > 0 and by_room == math.huge then by_room = math.min(by_room," },
  { "quantité des objets ignorée", "local n = math.floor(crafts * p.amount + 1e-9)", "local n = crafts" },
  { "fluide pris sans quantité", "return { crafts = crafts, fluid = crafts * row.fluid_in, items = items, limit = limit }", "return { crafts = crafts, fluid = crafts, items = items, limit = limit }" },
  { "énergie sans plancher", "energy = math.max(r.energy or 0.5, 0.05)", "energy = r.energy or 0.5" },
}
local killed, survivors = 0, {}
for _, m in ipairs(MUTANTS) do
  local src = mutate(m[2], m[3])
  local chunk = load(src, "@fluides_mutant")
  local dead = false
  if not chunk then dead = true else
    local f0, p0, q0 = fail, pass, quiet
    quiet = true
    local ok, Fm = pcall(chunk)
    local ran = ok and pcall(suite, Fm, check)
    dead = (not ran) or fail > f0
    fail, pass, quiet = f0, p0, q0
  end
  if dead then killed = killed + 1 else survivors[#survivors + 1] = m[1] end
end
check(#survivors == 0, "§6 mutants survivants : " .. table.concat(survivors, " ; "))
say(string.format("mutants refusés : %d sur %d", killed, #MUTANTS))
print(string.format("[FLUX-SOUPAPE] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", pass, fail, killed, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
