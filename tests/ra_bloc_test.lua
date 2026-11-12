--[[
  Lot LOURD (suite du point 2, cible 0.6.63 ; décision du lead du 8/11) : coût DÉCLARÉ au jeton (script/core/lourd.lua) du DÉBUT du
  raccordement (script/team/raccord.lua, Ra.step) quand il passe par le chemin d'un bloc du registre des génératrices
  (script/team/generateurs.lua, lot X10-S4). Monde : une équipe (force « p17 ») et une autre (« autre »), 60 génératrices chacune, boîte
  des chunks de 76 × 76 (la ligne de 76 de la sauvegarde du DC), un plan de 40 machines.
    R1. Six cas, chacun mesuré sur UN début de relevé (tick 3 600) : le registre sert ; Gens.ENABLED faux ; racine absente (registre pas
        armé) ; surface « nounit » ; équipe « nounit » ; surface pas encore relevée. Pour chacun : coût déclaré, recherches du moteur
        (sur toute la surface, par zone, chunks couverts, entités examinées) et instructions Lua (debug.sethook, une par instruction :
        mod à part, banc à part ; déterministe, jamais un temps).
    R2. Le coût SUIT ce qui est vraiment relevé : 32 seulement si le début ne fait AUCUNE recherche sur toute la surface ni par zone ; une
        recherche par zone (bande) : coût = chunks de la zone ; une recherche sur toute la surface : tout le budget (coût absent).
    Mutants (prédicat ignoré : 32 dès Gens.ready() ; toujours 32 par le chemin d'un bloc) : ils DOIVENT être vus.
  AVANT et APRÈS : chaque cas est joué avec la règle de la 0.6.62 (texte de la source rendu à la 1re bande) puis avec la source.
  Usage : lua5.2 tests/ra_bloc_test.lua [--avant] (--avant : imprime la table seule, sans les contrôles)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end
local AVANT = arg and arg[1] == "--avant"

log = function() end
defines = defines or {}
defines.events = defines.events or { on_chunk_generated = 34 }

local store, inits, loads, configs = {}, {}, {}, {}
package.loaded["script.core.events"] = { on = function() end, on_nth_tick = function() end,
  on_init = function(fn) inits[#inits + 1] = fn end, on_load = function(fn) loads[#loads + 1] = fn end,
  on_configuration_changed = function(fn) configs[#configs + 1] = fn end }
package.loaded["script.core.storage"] = {
  declare = function(name, init) store[name] = store[name] or init() end,
  ns = function(name) return store[name] end,
}

local FORCES = { p17 = { name = "p17" }, autre = { name = "autre" } }
game = { tick = 0, forces = FORCES }

---------------------------------------------------------------------------------------------------
-- Monde : génératrices (unit_number, force objet), surface qui compte ses recherches
---------------------------------------------------------------------------------------------------
local W = { ents = {}, n = 0 }
local function add(name, type_, x, y, force, net)
  W.n = W.n + 1
  local e = { name = name, type = type_, position = { x = x, y = y }, force = FORCES[force], unit_number = 1000 + W.n, valid = true,
    electric_network_id = net, box = { x - 1.5, y - 1.5, x + 1.5, y + 1.5 } }
  W.ents[#W.ents + 1] = e
  return e
end
for i = 0, 59 do
  add("steam-engine", "generator", -300 + (i % 12) * 200 + 0.5, -300 + math.floor(i / 12) * 400 + 0.5, "p17", 1 + i % 3)
  add("steam-engine", "generator", -290 + (i % 12) * 200 + 0.5, -290 + math.floor(i / 12) * 400 + 0.5, "autre", 10 + i % 2)
end
for i = 0, 39 do add("assembling-machine-1", "assembling-machine", 40 + (i % 8) * 4, 40 + math.floor(i / 8) * 4, "p17", 1) end

local function has_type(t, ty)
  if t == nil then return true end
  if type(t) == "string" then return t == ty end
  for _, x in ipairs(t) do if x == ty then return true end end
  return false
end
local M -- mesures du moteur (recherches)
local function fname(f) return type(f) == "table" and f.name or f end
local surface = {
  index = 1, valid = true,
  find_entities_filtered = function(q)
    local out = {}
    if q.area then
      local a = q.area
      M.zones = M.zones + 1
      M.chunks = M.chunks + (a[2][1] - a[1][1]) * (a[2][2] - a[1][2]) / 1024
    elseif not q.position then
      M.surface = M.surface + 1
    end
    for _, e in ipairs(W.ents) do
      M.examined = M.examined + 1
      if e.valid and (q.force == nil or e.force.name == fname(q.force)) and has_type(q.type, e.type) then
        local ok = true
        if q.area then
          local a = q.area
          ok = e.box[1] <= a[2][1] and e.box[3] >= a[1][1] and e.box[2] <= a[2][2] and e.box[4] >= a[1][2]
        end
        if ok then out[#out + 1] = e end
      end
    end
    return out
  end,
}
local BOX = { x0 = -10, y0 = -10, x1 = 65, y1 = 65 }
-- Lot TESTS-VERTS : script/team/raccord.lua requiert (par zone_equipe, UPS-HYGIENE a9010348) script/team/boite_chunks.lua, dont
-- on_init relève les chunks de game.surfaces (POULS, c03b7f67) : la surface rend les deux coins de BOX.
surface.get_chunks = function()
  local cs, i = { { x = BOX.x0, y = BOX.y0 }, { x = BOX.x1, y = BOX.y1 } }, 0
  return function() i = i + 1 return cs[i] end
end
game.surfaces = { surface }

local function team()
  local ents2 = {}
  for i = 0, 39 do ents2[#ents2 + 1] = { name = "assembling-machine-1", x = 40 + (i % 8) * 4, y = 40 + math.floor(i / 8) * 4, built = true, part = i % 4 } end
  return { key = "p17", force = "p17", build = { order = { 1, 2 }, plant = 1, opts = {}, occ = {}, projects = {
    [1] = { id = 1, state = "fini", ents = { { name = "steam-engine", x = -299.5, y = -299.5, built = true } }, parts = {} },
    [2] = { id = 2, state = "fini", ents = ents2, parts = {} },
  } } }
end

---------------------------------------------------------------------------------------------------
-- Chargement (source éventuellement changée : mutant) et un cas
---------------------------------------------------------------------------------------------------
local function mutated(path, subs)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  for _, x in ipairs(subs or {}) do
    local a, b = src:find(x[1], 1, true)
    assert(a, "mutant : texte absent de " .. path .. " : " .. x[1])
    assert(not src:find(x[1], b + 1, true), "mutant : texte present plusieurs fois : " .. x[1])
    src = src:sub(1, a - 1) .. x[2] .. src:sub(b + 1)
  end
  return src
end

local MODS = { "script.team.raccord", "script.team.generateurs", "script.core.lourd", "script.team.pouls_jeton", "script.team.reseau_vivant" }
local function load_mods(mut)
  for _, m in ipairs(MODS) do package.loaded[m] = nil; package.preload[m] = nil end
  if mut then
    local src = mutated(mut[2], mut[3])
    package.preload[mut[1]] = function(name) return assert(load(src, "=" .. mut[2]))(name) end
  end
  store, inits, loads, configs = {}, {}, {}, {}
  local Ra = require("script.team.raccord")
  local Gens = require("script.team.generateurs")
  return Ra, Gens
end

--- Joue le cas `case` : rend { cost, declared (vrai si un coût a été passé), surface, zones, chunks, examined, mod, banc }.
local function run_case(case, mut)
  local Ra, Gens = load_mods(mut)
  M = { surface = 0, zones = 0, chunks = 0, examined = 0 }
  if case ~= "racine absente" then for _, fn in ipairs(inits) do fn() end end
  if case == "ENABLED faux" then Gens.ENABLED = false end
  if case ~= "racine absente" and case ~= "ENABLED faux" and case ~= "surface pas encore relevee" then
    Gens.list(surface, "p17", { "generator" }) -- (registre relevé une fois, hors mesure : le régime d'une partie)
  end
  local S = store.gens
  if case == "surface nounit" then S.nounit[1] = true end
  if case == "equipe nounit" then S.by[1].p17.nounit = true end
  for _, e in ipairs(W.ents) do e.valid = true end
  local f = team()
  local got = { declared = false }
  local api = { request = function() return nil end, prio = 50, champ_live = false, box = function() return BOX end,
    jeton = { take = function(t, who, per, cost)
      if who == "p17:ra" and got.cost == nil and not got.declared then got.cost, got.declared = cost, true end
      return true
    end } }
  game.tick = 0
  Ra.step(api, f, surface, 0) -- (état du relevé créé ; début à R.PERIOD)
  M = { surface = 0, zones = 0, chunks = 0, examined = 0 }
  local nmod, nbanc = 0, 0
  game.tick = 3600
  debug.sethook(function()
    local src = debug.getinfo(2, "S").source
    if src:find("tests", 1, true) then nbanc = nbanc + 1 else nmod = nmod + 1 end
  end, "", 1)
  Ra.step(api, f, surface, 3600)
  debug.sethook()
  got.surface, got.zones, got.chunks, got.examined, got.mod, got.banc = M.surface, M.zones, M.chunks, M.examined, nmod, nbanc
  got.cyc = f.build.raccord and (f.build.raccord.cyc ~= nil or f.build.raccord.lj ~= nil)
  return got
end

local CASES = { "registre sert", "ENABLED faux", "racine absente", "surface nounit", "equipe nounit", "surface pas encore relevee" }

--- R2 : le coût déclaré suit ce que le début a vraiment relevé.
local function follows(r)
  if r.surface > 0 then return r.cost == nil end            -- recherche sur toute la surface : tout le budget
  if r.zones > 0 then return r.cost == r.chunks end         -- bande : chunks de la zone
  return r.cost == 32                                       -- registre : aucune recherche
end

-- AVANT : la règle de la 0.6.62 (coût de la 1re bande, même par le chemin d'un bloc), reconstituée par le texte de la source (aucun appel
-- de Gens.serves) ; APRÈS : la source telle quelle.
local AVANT_SRC = { "script.team.raccord", "script/team/raccord.lua",
  { { "        cost = Gens.serves(surface, f.force, GEN_TYPES) and Ra.COUT_REGISTRE or nil",
      "        cost = box and Ra.cout(box.y0, box.y1 + 1, box.x1 + 1 - box.x0) or nil" } } }

---------------------------------------------------------------------------------------------------
local res, av = {}, {}
print(string.format("%-28s %15s %9s %6s %7s %9s %17s %13s", "cas", "cout av -> ap", "surface", "zones", "chunks", "examinees",
  "instr mod av -> ap", "instr banc ap"))
for _, c in ipairs(CASES) do
  local r0 = run_case(c, AVANT_SRC)
  local r = run_case(c)
  av[c], res[c] = r0, r
  print(string.format("%-28s %15s %9d %6d %7.0f %9d %17s %13d", c,
    (r0.declared and tostring(r0.cost) or "-") .. " -> " .. (r.declared and tostring(r.cost) or "-"), r.surface, r.zones, r.chunks,
    r.examined, r0.mod .. " -> " .. r.mod, r.banc))
end
if not AVANT then
  for _, c in ipairs(CASES) do
    local r = res[c]
    check(r.cyc and follows(r), string.format("R2 %s : coût déclaré %s (avant : %s) ; relevé : %d recherche(s) sur toute la surface, %d par zone (%.0f chunks) ; instructions du mod %d (avant : %d)",
      c, tostring(r.cost), tostring(av[c].cost), r.surface, r.zones, r.chunks, r.mod, av[c].mod))
  end
  check(res["registre sert"].cost == 32 and res["registre sert"].surface == 0 and res["registre sert"].zones == 0,
    "R2 : le registre sert : aucune recherche du moteur, coût 32")
  local seen0 = false
  for _, c in ipairs(CASES) do if not follows(av[c]) then seen0 = true end end
  check(seen0, "R2 : la règle d'avant (0.6.62) ne suit PAS ce qui est relevé (coût de la 1re bande sans bande) : le contrôle la distingue")
  local MUT = {
    { "prédicat ignoré : 32 dès que le registre est prêt", "script.team.raccord", "script/team/raccord.lua",
      { { "Gens.serves(surface, f.force, GEN_TYPES)", "Gens.ready()" } } },
    { "prédicat ignoré : toujours 32 par le chemin d'un bloc", "script.team.raccord", "script/team/raccord.lua",
      { { "Gens.serves(surface, f.force, GEN_TYPES) and Ra.COUT_REGISTRE or nil", "Ra.COUT_REGISTRE" } } },
  }
  for _, m in ipairs(MUT) do
    local seen = false
    for _, c in ipairs(CASES) do
      local r = run_case(c, { m[2], m[3], m[4] })
      if not follows(r) then seen = true end
    end
    check(seen, "mutant " .. m[1] .. " : vu")
  end
end
print(string.format("[RA-BLOC] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
