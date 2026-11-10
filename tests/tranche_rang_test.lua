--[[
  Lot CC-PLEIN (F503, 10/11/2026) : une TRANCHE de recherche de tracé (wait == "tranche", ligne de rapatriement, script/team/rapatriement.lua)
  n'est pas un plan fini : le projet cède son rang (fin de b.order). Classe B2 (créneau du plan de la passe et jeton du tick repris à chaque
  passe par le même projet) au maillon script/team/build.lua, advance, branche « tranche ».
  Partie 0.6.89 du DC (graine 4271945338, fo-logs/2026-11-10_PLAYTEST-0689) : 7 lignes en recherche dès 17 min (« appel 4 595, 0 noeuds »
  au banc de la sonde), 19 projets en « plan » sans un seul essai de plan (raison vide) jusqu'à 82 min, dont la bande 51 de la migration
  du fer : l'avant-poste reste « plein par migration », 243 PNJ sans tâche.
  Le VRAI code de build.lua est chargé (advance entière, boucle des projets de pulse_team), avec des doublures pour le plan, les jetons et
  la santé de la centrale. Jeton du tick (Tokens.take) : comme le vrai pour un plan (200 unités, plus que la part d'une équipe) : une seule
  grosse opération par tick, et aucune aux ticks où une faction l'a déjà prise (ici une passe sur trois).
    T1. 7 lignes en recherche sans fin devant une bande de champ : la bande a son plan en moins de 20 passes.
    T2. Chaque ligne garde des tranches après le plan de la bande (aucune n'est oubliée ni affamée).
    T3. b.order reste une permutation (aucun doublon, aucun projet perdu) ; l'ordre relatif des autres projets ne change pas.
    T4. Une ligne seule : une tranche à chaque passe accordée (la recherche n'est pas ralentie).
    T5. Un plan d'un autre type qui attend (wait == true, « net ») ne change pas l'ordre (hors du lot).
    Mutants (texte de la source changé) : ils DOIVENT tous être vus.
  Usage : lua5.2 tests/tranche_rang_test.lua
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local QUIET = false
local function check(c, msg)
  if c then ok_n = ok_n + 1 if not QUIET then print("OK     " .. msg) end
  else fail_n = fail_n + 1 if not QUIET then print("ECHEC : " .. msg) end end
end

local fh = assert(io.open(os.getenv("TRANCHE_RANG_SRC") or "script/team/build.lua", "rb")) -- (TRANCHE_RANG_SRC : une autre source, preuve « rouge avant »)
local SRC = fh:read("*a")
fh:close()
local function between(src, a_mark, b_mark)
  local a = assert(src:find(a_mark, 1, true), "repere absent : " .. a_mark)
  local b = assert(src:find(b_mark, a, true), "repere absent : " .. b_mark)
  return src:sub(a, b - 1)
end

--- Monde de doublures. Rend l'API du banc : new_team, pulse(f, tick), calls (essais de plan par projet).
local function build_world(src)
  local adv_src = between(src, "local function advance(f, surface, p, tick)", "--- Lot FACTIONS-BLOQUEES : enlève les tourelles")
  local loop_src = between(src, "  -- 2. projets, dans l'ordre des demandes", "  Profiler.fstop(\"bp:projets\")")
  local W = { calls = {}, slices = {}, logs = {}, ledger = {} }
  local noop = function() end
  local env = {
    Build = { COST_PLAN = 200, NET_WAIT_MAX = 3, NET_WAIT_TICKS = 600, BP_STATE_SCOPE = {},
      TrancheForeuses = { clear = noop }, Rapatriement = { SLICE_WAIT = 2 },
      reserve_suspended = function() return true end }, -- (une bande planifiée attend en réserve : hors du banc)
    Sante = { gate = function() return true end, site_kw = function() return 0 end },
    Profiler = { start = noop, stop = noop, fstart = noop, fstop = noop },
    template_of = function() return nil end,
    sorted_keys = function(t) local k = {} for x in pairs(t) do k[#k + 1] = x end table.sort(k) return k end,
    Mq = { WAIT_TICKS = 60 }, Cl = { RETRY = 600 },
    SCAN = {},
    free_own_turrets = function() return 0, 0, 0 end,
    log = function(s) W.logs[#W.logs + 1] = s end,
    -- jeton du tick : une grosse opération par tick, aucune aux ticks « pris par une faction » (une passe sur trois)
    Tokens = { take = function(_, tick, units)
      if (tick / 5) % 3 == 0 then return false end
      if W.ledger[tick] then return false end
      W.ledger[tick] = units
      return true
    end },
    -- le plan : une ligne cherche sans fin ; les autres projets suivent leur script (W.plan_of[id])
    plan_project = function(f, surface, p)
      W.calls[p.id] = (W.calls[p.id] or 0) + 1
      if p.spec.rapatriement then
        W.slices[p.id] = (W.slices[p.id] or 0) + 1
        return false, "rapatriement: planification en cours (search, appel " .. W.slices[p.id] .. ", 0 noeuds)", "tranche"
      end
      local r = (W.plan_of and W.plan_of[p.id]) or "ok"
      if r == "ok" then p.parts[1] = { key = "champ:1:" .. p.id, lot = "site" } return true end
      if r == "attend" then return false, "champ: bande liee pas encore planifiee", true end
      if r == "net" then return false, "reseau d'un autre projet", "net" end
      return false, "place"
    end,
  }
  setmetatable(env, { __index = _G })
  local chunk_src = adv_src .. "\nlocal function projets(f, surface, tick)\n  local b = f.build\n" .. loop_src .. "\nend\nreturn projets\n"
  local projets = assert(load(chunk_src, "tranche_rang", "t", env))()
  W.pulse = function(f, tick) projets(f, {}, tick) end
  W.new_team = function()
    local b = { projects = {}, order = {}, queue = {}, qhead = 1, stats = { projects_refused = 0 }, occ = {}, lots = {}, net = {}, next_id = 1 }
    return { key = "player", is_player = true, build = b }
  end
  W.add = function(f, spec, state)
    local b = f.build
    local id = b.next_id
    b.next_id = id + 1
    b.projects[id] = { id = id, spec = spec, state = state or "plan", parts = {}, ents = {}, obstacles = {}, quais = {}, outs = {}, wires = {}, stock = {} }
    b.order[#b.order + 1] = id
    return id
  end
  return W
end

local function is_perm(order, n)
  if #order ~= n then return false end
  local seen = {}
  for _, x in ipairs(order) do if seen[x] then return false end seen[x] = true end
  for i = 1, n do if not seen[i] then return false end end
  return true
end

local function battery(src)
  local okw, W = pcall(build_world, src)
  if not okw then check(false, "chargement du code : " .. tostring(W)) return end

  -- T1 + T2 + T3 : 7 lignes devant une bande, 2 projets finis intercalés (rangs à garder)
  local f = W.new_team()
  local done1 = W.add(f, { gen = "steam" }, "fini")
  local raps = {}
  for i = 1, 7 do raps[i] = W.add(f, { rapatriement = { item = "iron-plate" } }, "plan") end
  local done2 = W.add(f, { gen = "smelter" }, "fini")
  local band = W.add(f, { site = "champ", champ = { oid = 1 } }, "plan")
  local planned_at
  for k = 1, 400 do
    W.pulse(f, 5 * k)
    if not planned_at and f.build.projects[band].state ~= "plan" then planned_at = k end
  end
  check(planned_at ~= nil and planned_at <= 20, "T1 : la bande derriere 7 lignes en recherche a son plan en moins de 20 passes (passe " .. tostring(planned_at) .. ")")
  check(W.calls[band] == 1, "T1 : un seul essai de plan pour la bande (accepte) : " .. tostring(W.calls[band]))
  local starved = 0
  for _, r in ipairs(raps) do if (W.slices[r] or 0) < 10 then starved = starved + 1 end end
  check(starved == 0, "T2 : chaque ligne garde ses tranches (au moins 10 en 400 passes chacune ; affamees : " .. starved .. ")")
  check(is_perm(f.build.order, band), "T3 : b.order reste une permutation des " .. band .. " projets")
  local pos = {}
  for i, x in ipairs(f.build.order) do pos[x] = i end
  check(pos[done1] and pos[done2] and pos[band] and pos[done1] < pos[done2] and pos[done2] < pos[band],
    "T3 : l'ordre relatif des projets qui ne cherchent pas un trace est garde")

  -- T4 : une ligne seule
  local W2 = build_world(src)
  local g = W2.new_team()
  local r1 = W2.add(g, { rapatriement = { item = "iron-plate" } }, "plan")
  local granted = 0
  for k = 1, 60 do
    if (k % 3) ~= 0 then granted = granted + 1 end
    W2.pulse(g, 5 * k)
  end
  -- une tranche aux passes accordées où la ligne est en « plan » : elle repasse en plan à la passe suivante (attente de 2 ticks < 5)
  check((W2.slices[r1] or 0) >= math.floor(granted / 2), "T4 : une ligne seule garde le rythme de ses tranches (" .. tostring(W2.slices[r1]) .. " pour " .. granted .. " passes accordees)")
  check(is_perm(g.build.order, 1), "T4 : ordre intact (1 projet)")

  -- T5 : un plan qui attend autrement (wait == true, puis « net ») garde son rang
  local W3 = build_world(src)
  local h = W3.new_team()
  local a = W3.add(h, { site = "champ" }, "plan")
  local c = W3.add(h, { site = "champ" }, "plan")
  W3.plan_of = { [a] = "attend", [c] = "net" }
  for k = 1, 30 do W3.pulse(h, 5 * k) end
  check(h.build.order[1] == a and h.build.order[2] == c, "T5 : un plan en attente (bande liee, reseau) ne change pas l'ordre")
end

print("== code de la branche")
battery(SRC)
local n_ok, n_fail = ok_n, fail_n

-- Mutants : chacun DOIT faire échouer la batterie
local CUT_A = "      for _, x in ipairs(b.order) do if x ~= p.id then order[#order + 1] = x end end\n"
local CUT_B = "      order[#order + 1] = p.id\n"
local CUT_C = "      b.order = order\n"
local function mutate(from, to)
  local s = SRC:gsub("\r\n", "\n")
  local a = s:find(from, 1, true)
  if not a then return nil end
  return s:sub(1, a - 1) .. to .. s:sub(a + #from)
end
local MUTANTS = {
  { "coupe retiree (ordre jamais change)", CUT_C, "" },
  { "rang garde en tete (projet remis devant)", CUT_B .. CUT_C, "      table.insert(order, 1, p.id)\n" .. CUT_C },
  { "projet perdu (non remis dans l'ordre)", CUT_B, "" },
  { "doublon (remis sans etre retire)", CUT_A, "      for _, x in ipairs(b.order) do order[#order + 1] = x end\n" },
  { "ordre des autres renverse", CUT_A, "      for i = #b.order, 1, -1 do local x = b.order[i] if x ~= p.id then order[#order + 1] = x end end\n" },
  { "rang cede aussi par un plan qui attend (wait == true)", "    elseif wait == true then\n      p.state = \"attente\"\n      p.reason = why\n",
    "    elseif wait == true then\n      p.state = \"attente\"\n      p.reason = why\n      local order = {}\n      for _, x in ipairs(b.order) do if x ~= p.id then order[#order + 1] = x end end\n      order[#order + 1] = p.id\n      b.order = order\n" },
}
local seen_n = 0
for _, m in ipairs(MUTANTS) do
  local msrc = mutate(m[2], m[3])
  if not msrc then
    print("ECHEC : mutant sans repere : " .. m[1]); n_fail = n_fail + 1
  else
    local f0 = fail_n
    QUIET = true
    battery(msrc)
    QUIET = false
    local seen = fail_n > f0
    if seen then seen_n = seen_n + 1; print("OK     mutant vu : " .. m[1]) else print("ECHEC : mutant NON vu : " .. m[1]) end
  end
end
ok_n, fail_n = n_ok + seen_n, n_fail + (#MUTANTS - seen_n)
print(string.format("[TRANCHE-RANG] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", ok_n, fail_n, seen_n, #MUTANTS))
if fail_n > 0 then os.exit(1) end
