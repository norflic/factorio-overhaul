--[[
  Lot CC-PRIO-LIGNES (F532, 11/11/2026) : une LIGNE DE RAPATRIEMENT ne prend pas au coffre ce qui MANQUE aux bandes de champ actives.
  Classe B4 (priorités contradictoires sans arbitre unique) au maillon script/team/build.lua, `reserve` : le coffre est servi au premier
  lecteur (chaque projet en réserve relu une fois par seconde, à sa phase) ; une ligne (objectif d'investissement) prenait les tapis et les
  bras d'une bande de champ (banc C4, graine 271828182 : à 31 min la bande manque 145 tapis contre 29 sans les lignes ; 1 348 plaques
  livrées de 31 à 40 min contre 6 803). La famille spec.champ passe avant la famille spec.rapatriement (shared/team/rapatriement.lua,
  Rp.libre_pour). Le VRAI `reserve` de build.lua est chargé, avec des doublures pour le coffre.
    T1. Coffre court : la ligne lue AVANT la bande ne prend aucun tapis ni bras que la bande attend ; la bande les prend ensuite.
    T2. Surplus : la ligne prend ce qui dépasse le manque de la bande (elle n'est pas gelée).
    T3. Un projet qui n'est pas une ligne (bande, fonderie) est servi comme avant (stock libre entier).
    T4. Bande finie, refusée ou encore au plan (p.missing périmé) : rien ne lui est gardé.
    T5. Bande en chantier progressif (p.missing relu) : son manque est gardé ; deux bandes : manques additionnés.
    T6. Une ligne ne cède rien à une autre ligne (entre lignes : premier lecteur, comme avant).
    T7. Objet que les bandes ne demandent pas (coffre de tampon) : la ligne le prend entier ; `free` du coffre jamais modifié.
    T8. Flux de 10 tapis/s, 1 bande (145) et 2 lignes (200 chacune) lues avant elle : la bande est servie en moins de 16 s ; les deux
        lignes finissent ensuite (aucune famine).
    T9. Câblage : build.lua charge le module (champ de Build) et `reserve` passe le stock libre par Rp.libre_pour.
    Mutants (texte de la source changé) : ils DOIVENT tous être vus.
  Usage : lua5.2 tests/cc_prio_lignes_test.lua     (CC_PRIO_SRC : une autre source de build.lua, preuve « rouge avant »)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local QUIET = false
local function check(c, msg)
  if c then ok_n = ok_n + 1 if not QUIET then print("OK     " .. msg) end
  else fail_n = fail_n + 1 if not QUIET then print("ECHEC : " .. msg) end end
end
local function slurp(p)
  local fh = assert(io.open(p, "rb"))
  local s = fh:read("*a")
  fh:close()
  return (s:gsub("\r\n", "\n"))
end
local BSRC = slurp(os.getenv("CC_PRIO_SRC") or "script/team/build.lua")
local RSRC = slurp(os.getenv("CC_PRIO_RP") or "shared/team/rapatriement.lua")

local function between(src, a_mark, b_mark)
  local a = assert(src:find(a_mark, 1, true), "repere absent : " .. a_mark)
  local b = assert(src:find(b_mark, a, true), "repere absent : " .. b_mark)
  return src:sub(a, b - 1)
end

--- Monde : coffre (stock), projets ; rend reserve(f, p) du vrai code et le module Rp.
local function build_world(bsrc, rsrc)
  local Rp = assert(load(rsrc, "rapatriement", "t", setmetatable({}, { __index = _G })))()
  local res_src = between(bsrc, "local function reserve(f, p)", "--- Lot CC-PETROLE : objets de T")
  local W = {}
  local env = {
    Build = { RpPart = Rp },
    sorted_keys = function(t) local k = {} for x in pairs(t) do k[#k + 1] = x end table.sort(k) return k end,
    bump = function(t, k, n) t[k] = (t[k] or 0) + n end,
    needs_of = function(p) return p.need end,
    free_stock = function(f) return f.chest end, -- (la vue du coffre elle-même : la règle ne doit pas la modifier)
    Stock = {
      count = function(f, it) return f.real[it] or 0 end,
      remove = function(f, it, n) local h = f.real[it] or 0 local g = math.min(h, n) f.real[it] = h - g f.chest[it] = f.real[it] return g end,
    },
  }
  setmetatable(env, { __index = _G })
  W.reserve = assert(load(res_src .. "\nreturn reserve\n", "reserve", "t", env))()
  W.Rp = Rp
  W.team = function(chest)
    local real, view = {}, {}
    for k, v in pairs(chest) do real[k] = v view[k] = v end
    return { key = "player", real = real, chest = view, build = { projects = {}, order = {}, next_id = 1 } }
  end
  W.add = function(f, spec, state, need, missing)
    local b = f.build
    local id = b.next_id
    b.next_id = id + 1
    b.projects[id] = { id = id, spec = spec, state = state, need = need, stock = {}, missing = missing }
    b.order[#b.order + 1] = id
    return b.projects[id]
  end
  return W
end

local LINE = function() return { rapatriement = { item = "iron-plate" } } end
local BAND = function() return { site = "champ", champ = { oid = 1, pr = "iron-ore" } } end

local function battery(bsrc, rsrc)
  local okw, W = pcall(build_world, bsrc, rsrc)
  if not okw then check(false, "chargement du code : " .. tostring(W)) return end
  local okr, err = pcall(function()
    -- T1 : coffre court, ligne lue avant la bande
    local f = W.team({ ["transport-belt"] = 100, inserter = 50 })
    local band = W.add(f, BAND(), "reserve", { ["transport-belt"] = 145, inserter = 58 }, { { "inserter", 58 }, { "transport-belt", 145 } })
    local line = W.add(f, LINE(), "reserve", { ["transport-belt"] = 200, inserter = 40 }, nil)
    W.reserve(f, line)
    check((line.stock["transport-belt"] or 0) == 0 and (line.stock.inserter or 0) == 0,
      "T1 : la ligne ne prend aucun tapis ni bras attendus par la bande (pris : " .. tostring(line.stock["transport-belt"]) .. " tapis, " .. tostring(line.stock.inserter) .. " bras)")
    W.reserve(f, band)
    check(band.stock["transport-belt"] == 100 and band.stock.inserter == 50, "T1 : la bande lue ensuite prend tout le coffre (100 tapis, 50 bras)")
    check(#line.missing == 2, "T1 : la ligne garde ses manques (le cerveau les fabrique) : " .. #line.missing)

    -- T2 : surplus
    local g = W.team({ ["transport-belt"] = 300 })
    W.add(g, BAND(), "reserve", { ["transport-belt"] = 145 }, { { "transport-belt", 145 } })
    local l2 = W.add(g, LINE(), "reserve", { ["transport-belt"] = 200 }, nil)
    W.reserve(g, l2)
    check(l2.stock["transport-belt"] == 155, "T2 : la ligne prend le surplus (300 - 145 = 155) : " .. tostring(l2.stock["transport-belt"]))

    -- T3 : un projet qui n'est pas une ligne
    local h = W.team({ ["transport-belt"] = 100 })
    W.add(h, BAND(), "reserve", { ["transport-belt"] = 145 }, { { "transport-belt", 145 } })
    local b2 = W.add(h, BAND(), "reserve", { ["transport-belt"] = 80 }, nil)
    local smel = W.add(h, { gen = "smelter" }, "reserve", { ["transport-belt"] = 10 }, nil)
    W.reserve(h, b2)
    W.reserve(h, smel)
    check(b2.stock["transport-belt"] == 80 and smel.stock["transport-belt"] == 10, "T3 : une bande et une fonderie sont servies sur le stock libre entier")

    -- T4 : bandes finie, refusée, au plan : rien gardé
    for _, st in ipairs({ "fini", "refuse", "plan", "attente" }) do
      local k = W.team({ ["transport-belt"] = 100 })
      W.add(k, BAND(), st, { ["transport-belt"] = 145 }, { { "transport-belt", 145 } })
      local l4 = W.add(k, LINE(), "reserve", { ["transport-belt"] = 60 }, nil)
      W.reserve(k, l4)
      check(l4.stock["transport-belt"] == 60, "T4 : bande « " .. st .. " » (manque perime) : la ligne prend ses 60 tapis : " .. tostring(l4.stock["transport-belt"]))
    end

    -- T5 : chantier progressif + deux bandes additionnées
    local m = W.team({ ["transport-belt"] = 100 })
    W.add(m, BAND(), "chantier", { ["transport-belt"] = 30 }, { { "transport-belt", 30 } })
    W.add(m, BAND(), "reserve", { ["transport-belt"] = 50 }, { { "transport-belt", 50 } })
    local l5 = W.add(m, LINE(), "reserve", { ["transport-belt"] = 200 }, nil)
    W.reserve(m, l5)
    check(l5.stock["transport-belt"] == 20, "T5 : deux bandes (chantier 30 + reserve 50) : la ligne prend 20 tapis : " .. tostring(l5.stock["transport-belt"]))

    -- T6 : entre lignes, rien n'est cédé
    local n = W.team({ ["transport-belt"] = 100 })
    W.add(n, LINE(), "reserve", { ["transport-belt"] = 90 }, { { "transport-belt", 90 } })
    local l6 = W.add(n, LINE(), "reserve", { ["transport-belt"] = 70 }, nil)
    W.reserve(n, l6)
    check(l6.stock["transport-belt"] == 70, "T6 : une ligne ne cede rien a une autre ligne : " .. tostring(l6.stock["transport-belt"]))

    -- T7 : objet hors des manques ; free non modifié
    local q = W.team({ ["transport-belt"] = 100, ["wooden-chest"] = 4 })
    W.add(q, BAND(), "reserve", { ["transport-belt"] = 145 }, { { "transport-belt", 145 } })
    local l7 = W.add(q, LINE(), "reserve", { ["wooden-chest"] = 2, ["transport-belt"] = 1 }, nil)
    local view = { ["transport-belt"] = 100, ["wooden-chest"] = 4 }
    local out = W.Rp.libre_pour(l7.spec, view, q.build.projects, q.build.order)
    check(view["transport-belt"] == 100 and view["wooden-chest"] == 4 and out ~= view, "T7 : `free` du coffre jamais modifie (nouvelle table)")
    check(W.Rp.libre_pour({ gen = "smelter" }, view, q.build.projects, q.build.order) == view, "T7 : hors ligne, `free` rendu tel quel")
    W.reserve(q, l7)
    check(l7.stock["wooden-chest"] == 2 and (l7.stock["transport-belt"] or 0) == 0, "T7 : coffre de tampon pris, tapis garde pour la bande")

    -- T8 : flux de 10 tapis par seconde ; lignes lues avant la bande à chaque seconde
    local s = W.team({})
    local bd = W.add(s, BAND(), "reserve", { ["transport-belt"] = 145 }, { { "transport-belt", 145 } })
    local la = W.add(s, LINE(), "reserve", { ["transport-belt"] = 200 }, nil)
    local lb = W.add(s, LINE(), "reserve", { ["transport-belt"] = 200 }, nil)
    local band_at, lines_at
    for sec = 1, 120 do
      s.real["transport-belt"] = (s.real["transport-belt"] or 0) + 10
      s.chest["transport-belt"] = s.real["transport-belt"]
      if la.state == "reserve" then if W.reserve(s, la) then la.state = "fantomes" end end
      if lb.state == "reserve" then if W.reserve(s, lb) then lb.state = "fantomes" end end
      if bd.state == "reserve" then if W.reserve(s, bd) then bd.state = "fantomes" band_at = sec end end
      if not lines_at and la.state ~= "reserve" and lb.state ~= "reserve" then lines_at = sec end
    end
    check(band_at ~= nil and band_at <= 16, "T8 : la bande (145 tapis) est servie en moins de 16 s malgre 2 lignes lues avant elle (s " .. tostring(band_at) .. ")")
    check(lines_at ~= nil and lines_at <= 60, "T8 : les deux lignes finissent ensuite, sans famine (s " .. tostring(lines_at) .. ")")
  end)
  if not okr then check(false, "batterie interrompue : " .. tostring(err)) end
  -- T9 : câblage
  check(bsrc:find('Build.RpPart = require("shared.team.rapatriement")', 1, true) ~= nil, "T9 : build.lua charge shared/team/rapatriement.lua en champ de Build (pas de locale)")
  local okb, res = pcall(between, bsrc, "local function reserve(f, p)", "--- Lot CC-PETROLE : objets de T")
  check(okb and res:find("Build.RpPart.libre_pour(p.spec, free_stock(f), f.build.projects, f.build.order)", 1, true) ~= nil, "T9 : reserve passe le stock libre par Rp.libre_pour")
end

print("== code de la branche")
battery(BSRC, RSRC)
local n_ok, n_fail = ok_n, fail_n

local function mutate(src, from, to)
  local a = src:find(from, 1, true)
  if not a then return nil end
  return src:sub(1, a - 1) .. to .. src:sub(a + #from)
end
-- { nom, "b" (build.lua) ou "r" (module), avant, après }
local MUTANTS = {
  { "coupe retiree (reserve lit le coffre entier)", "b", "local free = Build.RpPart.libre_pour(p.spec, free_stock(f), f.build.projects, f.build.order)", "local free = free_stock(f)" },
  { "toute la famille cede (pas seulement les lignes)", "r", "if not (type(spec) == \"table\" and spec.rapatriement ~= nil) then return free end", "if not (type(spec) == \"table\") then return free end" },
  { "etat ignore (manque perime d'une bande finie garde)", "r", "q.spec.champ and Rp.BANDE_ACTIVE[q.state] and q.missing", "q.spec.champ and q.missing" },
  { "famille des bandes ignoree (une ligne cede aux lignes)", "r", "q.spec.champ and Rp.BANDE_ACTIVE[q.state] and q.missing", "Rp.BANDE_ACTIVE[q.state] and q.missing" },
  { "manque non soustrait", "r", "math.max(0, (free[it] or 0) - owed[it])", "(free[it] or 0)" },
  { "manques ecrases au lieu d'additionnes", "r", "(owed[m[1]] or 0) + (m[2] or 0)", "(m[2] or 0)" },
  { "coffre modifie en place", "r", "local out = setmetatable({}, { __index = free })", "local out = free" },
  { "chantier progressif oublie", "r", "reserve = true, defrichage = true, fantomes = true, chantier = true", "reserve = true" },
  { "garde totale (la ligne ne prend plus rien)", "r", "  if #keys == 0 then return free end\n", "  if #keys == 0 then return setmetatable({}, { __index = function() return 0 end }) end\n" },
  { "objet garde a zero (tout le manque, meme au-dela du coffre)", "r", "math.max(0, (free[it] or 0) - owed[it])", "0" },
}
local seen_n = 0
for _, m in ipairs(MUTANTS) do
  local b2, r2 = BSRC, RSRC
  if m[2] == "b" then b2 = mutate(BSRC, m[3], m[4]) else r2 = mutate(RSRC, m[3], m[4]) end
  if not (b2 and r2) then
    print("ECHEC : mutant sans repere : " .. m[1]); n_fail = n_fail + 1
  else
    local f0 = fail_n
    QUIET = true
    battery(b2, r2)
    QUIET = false
    if fail_n > f0 then seen_n = seen_n + 1; print("OK     mutant vu : " .. m[1]) else print("ECHEC : mutant NON vu : " .. m[1]) end
  end
end
ok_n, fail_n = n_ok + seen_n, n_fail + (#MUTANTS - seen_n)
print(string.format("[CC-PRIO-LIGNES] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", ok_n, fail_n, seen_n, #MUTANTS))
if fail_n > 0 then os.exit(1) end
