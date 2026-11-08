--[[
  Lot X10-S4, Gens.serves (demande de perf3 pour la 0.6.63) : prédicat en lecture seule, vrai EXACTEMENT quand Gens.list servirait depuis
  le registre (script/team/generateurs.lua), sans aucune recherche sur la surface.

  Critères, écrits avant le code :
  S1. Pour chaque cas, serves(surface, force, types) appelé AVANT Gens.list vaut « Gens.list n'a fait aucun find_entities_filtered ».
      Cas : registre éteint ; pas armé ; type non tenu ; surface jamais relevée (puis relevée : sert) ; surface illisible (entité sans
      unit_number) ; seau de la force illisible (pose sans unit_number), et une autre force de la même surface qui sert ; force sans
      seau (sert) ; liste de types vide ; type en chaîne.
  S2. Sans effet : l'espace « gens » identique avant et après serves (sérialisé), aucune ligne de journal, aucun relevé compté.
  S3. Mutants (source changée) : chacun casse S1 dans au moins un cas.
  Moteur de bouchons, aucun jeu. Lancement, depuis la racine du mod : lua5.2 tests/x10_s4_serves_test.lua
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("  ECHEC : " .. msg) end
end

local logs = {}
function log(s) logs[#logs + 1] = s end

-- Sérialisation triée (comparaison d'état ; les entités par leur numéro).
local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  if v.__ent then return "E" .. tostring(v.unit_number) end
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k]) end
  return "{" .. table.concat(out, ",") .. "}"
end

local SRC
do
  local fh = assert(io.open("script/team/generateurs.lua", "rb"))
  SRC = fh:read("*a")
  fh:close()
end

--- Charge une instance NEUVE du registre (source donnée), sur un moteur de bouchons neuf. Rend Gens, le monde et ses commandes.
local function fresh(src, kept)
  local store, inits, configs = kept or {}, {}, {}
  package.loaded["script.core.events"] = { on = function() end, on_init = function(fn) inits[#inits + 1] = fn end,
    on_load = function() end, on_configuration_changed = function(fn) configs[#configs + 1] = fn end }
  package.loaded["script.core.storage"] = {
    declare = function(name, init) if store[name] == nil then store[name] = init() end end,
    ns = function(name) return store[name] end,
  }
  defines = { events = {} }
  local W = { finds = 0, ents = {} }
  local function surface(index)
    return { index = index, find_entities_filtered = function(q)
      W.finds = W.finds + 1
      local want = {}
      for _, t in ipairs(type(q.type) == "string" and { q.type } or q.type) do want[t] = true end
      local out = {}
      for _, e in ipairs(W.ents) do
        if e.valid and e.surface.index == index and want[e.type] and (q.force == nil or q.force == e.force.name) then out[#out + 1] = e end
      end
      return out
    end }
  end
  W.s1, W.s2, W.s3 = surface(1), surface(2), surface(3)
  local forces = { player = { name = "player" }, enemy = { name = "enemy" }, f1 = { name = "f1" } }
  game = { forces = forces, surfaces = { W.s1, W.s2, W.s3 } }
  local n = 0
  function W.ent(sf, force, etype, nounit)
    n = n + 1
    local e = { __ent = true, valid = true, surface = sf, force = forces[force], type = etype, unit_number = (not nounit) and (100 + n) or nil,
      electric_network_id = 1 }
    W.ents[#W.ents + 1] = e
    return e
  end
  local Gens = assert(load(src, "=script/team/generateurs.lua"))("script.team.generateurs")
  function W.init() for _, fn in ipairs(inits) do fn() end end
  W.store = store
  return Gens, W
end

-- Un cas : serves avant, puis Gens.list compté. Rend (serves, recherches de list).
local function probe(Gens, W, sf, force, types)
  local s = Gens.serves(sf, force, types)
  local before = W.finds
  Gens.list(sf, force, types)
  return s, W.finds - before
end

--- Joue tous les cas sur une source ; rend la liste { nom, serves, recherches }.
local function cases(src)
  local res = {}
  local function rec(name, s, f) res[#res + 1] = { name, s, f } end
  -- registre éteint
  do
    local G, W = fresh(src)
    W.init()
    W.ent(W.s1, "f1", "generator")
    G.ENABLED = false
    rec("éteint", probe(G, W, W.s1, "f1", { "generator" }))
  end
  -- pas armé (avant on_init)
  do
    local G, W = fresh(src)
    W.ent(W.s1, "f1", "generator")
    rec("pas armé", probe(G, W, W.s1, "f1", { "generator" }))
  end
  -- pas armé, registre déjà relevé (sauvegarde chargée, module rechargé avant on_load)
  do
    local G, W = fresh(src)
    W.init()
    W.ent(W.s1, "f1", "generator")
    G.list(W.s1, "f1", { "generator" }) -- relevé
    local G2 = fresh(src, W.store) -- (les surfaces de W comptent les recherches dans W)
    rec("pas armé, registre relevé", probe(G2, W, W.s1, "f1", { "generator" }))
  end
  -- type non tenu, surface jamais relevée puis relevée, liste vide, chaîne, force sans seau
  do
    local G, W = fresh(src)
    W.init()
    W.ent(W.s1, "f1", "generator")
    W.ent(W.s1, "player", "solar-panel")
    rec("type non tenu", probe(G, W, W.s1, "f1", { "container" }))
    rec("surface jamais relevée", probe(G, W, W.s1, "f1", { "generator" }))
    rec("surface relevée", probe(G, W, W.s1, "f1", { "generator" }))
    rec("autre force, surface relevée", probe(G, W, W.s1, "player", { "solar-panel", "generator" }))
    rec("types vides", probe(G, W, W.s1, "f1", {}))
    rec("type en chaîne", probe(G, W, W.s1, "f1", "generator"))
    rec("tenu puis non tenu", probe(G, W, W.s1, "f1", { "generator", "boiler" }))
    game.forces.neuve = { name = "neuve" }
    rec("force sans seau", probe(G, W, W.s1, "neuve", { "generator" }))
    rec("force sans seau, seau créé", probe(G, W, W.s1, "neuve", { "generator" }))
  end
  -- surface illisible (entité tenue sans unit_number au relevé)
  do
    local G, W = fresh(src)
    W.init()
    W.ent(W.s2, "f1", "generator", true)
    W.ent(W.s2, "player", "generator")
    G.list(W.s2, "player", { "generator" }) -- relevé de la surface (illisible)
    rec("surface illisible", probe(G, W, W.s2, "player", { "generator" }))
  end
  -- seau illisible (pose sans unit_number après le relevé), autre force de la même surface
  do
    local G, W = fresh(src)
    W.init()
    W.ent(W.s3, "f1", "generator")
    W.ent(W.s3, "player", "generator")
    G.list(W.s3, "f1", { "generator" }) -- relevé
    G.built({ created_entity = W.ent(W.s3, "f1", "generator", true) }, "on_built_entity")
    rec("seau illisible", probe(G, W, W.s3, "f1", { "generator" }))
    rec("autre force, seau lisible", probe(G, W, W.s3, "player", { "generator" }))
  end
  return res
end

-- S1 ---------------------------------------------------------------------------------------------------
local res = cases(SRC)
local served, not_served = 0, 0
for _, r in ipairs(res) do
  local name, s, f = r[1], r[2], r[3]
  if s then served = served + 1 else not_served = not_served + 1 end
  check((s == true) == (f == 0) and type(s) == "boolean",
    string.format("S1 : %s : serves %s, %d recherche(s) dans Gens.list", name, tostring(s), f))
end
print(string.format("[X10-S4-SERVES] %d cas : %d servis par le registre, %d par l'ancienne recherche", #res, served, not_served))
check(served >= 6 and not_served >= 6, "S1 : les deux réponses sont couvertes (" .. served .. " / " .. not_served .. ")")

-- S2 : sans effet ----------------------------------------------------------------------------------------
do
  local G, W = fresh(SRC)
  W.init()
  W.ent(W.s1, "f1", "generator")
  local probes = {
    function() return G.serves(W.s1, "f1", { "generator" }) end, -- surface jamais relevée
    function() return G.serves(W.s1, "f1", { "container" }) end, -- type non tenu (type_set écrirait une ligne)
    function() return G.serves(W.s1, "inconnue", { "generator" }) end,
  }
  local s0, l0, n0, f0 = ser(W.store), #logs, G.stats.scans, W.finds
  for _, p in ipairs(probes) do p() end
  G.list(W.s1, "f1", { "generator" }) -- relevé
  local s1, n1, f1 = ser(W.store), G.stats.scans, W.finds
  local l1 = #logs
  for _, p in ipairs(probes) do p() end
  check(ser(W.store) == s1 and #logs == l1 and G.stats.scans == n1 and W.finds == f1,
    "S2 : serves sans effet sur un registre relevé (état, journal, relevés, recherches)")
  check(s0 ~= s1 and n1 == n0 + 1 and f1 == f0 + 1 and l0 == l1,
    "S2 : avant le relevé, serves n'avait rien écrit ni relevé (le relevé vient de Gens.list seul)")
end

-- S3 : mutants -----------------------------------------------------------------------------------------
local function mutate(subs)
  local src = SRC
  for _, s in ipairs(subs) do
    local a, b = src:find(s[1], 1, true)
    assert(a, "mutant : texte absent : " .. s[1])
    src = src:sub(1, a - 1) .. s[2] .. src:sub(b + 1)
  end
  return src
end
local MUTANTS = {
  { "surface illisible ignorée", { { "  if S.nounit and S.nounit[idx] then return false end\n", "" } } },
  { "seau illisible ignoré", { { "  return not (b and b.nounit)\n", "  return true\n" } } },
  { "type non vérifié", { { "    if not TRACKED[t] then return false end\n", "" } } },
  { "surface non relevée servie", { { "  if not bs then return false end\n", "  if not bs then return true end\n" } } },
  { "pas armé servi", { { "  if not (Gens.ENABLED and armed) then return false end\n", "  if not Gens.ENABLED then return false end\n" } } },
}
for _, m in ipairs(MUTANTS) do
  local okm, r = pcall(cases, mutate(m[2]))
  local seen = not okm
  if okm then
    for _, x in ipairs(r) do if (x[2] == true) ~= (x[3] == 0) then seen = true end end
  end
  check(seen, "S3 : mutant « " .. m[1] .. " » vu")
end

print(string.format("[X10-S4-SERVES] BILAN : %d OK%s", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or ""))
os.exit(fail_n == 0 and 0 or 1)
