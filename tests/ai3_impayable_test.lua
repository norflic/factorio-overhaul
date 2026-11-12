--[[
  Lot RB-FLUIDE (1/11) : la recherche IMPAYABLE d'une équipe (shared/ai3/impayable.lua), règle pure, aucun nom d'objet (noms inventés).
    §1 arrêt : seuil exact de ticks sans unité payée, recherche faite ou déjà lâchée, grâce ; packs qui manquaient (triés) ;
    §2 pause : la recherche lâchée est écartée jusqu'à la fin de la pause, puis revient ;
    §3 retour anticipé : quand chaque pack retenu est au stock pour Im.UNITS unités (ou le reste, s'il est plus court), jamais sur une seule ;
    §4 rien d'autre de payable : la plus ancienne revient, `grace` posée, nettoyée à son terme ;
    §5 SIMULATION de laboratoire sur 3 h : (a) une recherche impayable et une payable : le laboratoire passe à la payable après la durée d'arrêt,
       revient quand le pack est produit, SANS osciller ; (b) rien de payable : au plus un arrêt par pause, le laboratoire n'est jamais oisif plus
       d'une décision ; (c) le pack produit puis consommé : un seul va-et-vient ;
    §6 aucun nom, aucun pairs décisionnel ; §7 mutants.
  Usage : lua5.2 tests/ai3_impayable_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SRC = read("shared/ai3/impayable.lua")

local function load_src(src)
  local f, e = load(src, "=impayable", "t")
  if not f then return nil, e end
  local ok, M = pcall(f)
  if not ok then return nil, M end
  return M
end

local MIN = 3600

local function suite(Im)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end

  -- §1 Arrêt.
  local lab = { tech = "t1", started = 1000, paid_tick = 5000 }
  check(Im.idle(lab, 5000 + 100) == 100, "§1 durée sans unité payée depuis la dernière unité")
  check(Im.idle({ tech = "t1", started = 700 }, 1000) == 300, "§1 sans unité payée : depuis le début")
  check(Im.idle(nil, 10) == nil and Im.idle({}, 10) == nil, "§1 pas de recherche : nil")
  check(Im.should_stall(lab, 5000 + Im.STALL, false, nil) == false, "§1 à la durée exacte : pas encore")
  check(Im.should_stall(lab, 5000 + Im.STALL + 1, false, nil) == true, "§1 au-delà de la durée : arrêt")
  check(Im.should_stall(lab, 5000 + Im.STALL + 1, true, nil) == false, "§1 recherche faite : jamais")
  check(Im.should_stall({ tech = "t1", started = 0, stalled = true }, 99999999, false, nil) == false, "§1 déjà lâchée : pas une seconde fois")
  check(Im.should_stall(lab, 5000 + Im.STALL + 1, false, 5000 + Im.STALL + 2) == false, "§1 sous la grâce : pas d'arrêt")
  check(Im.should_stall(lab, 5000 + Im.STALL + 2, false, 5000 + Im.STALL + 2) == true, "§1 grâce finie : arrêt")
  local m = Im.missing({ { "pz", 2 }, { "pa", 1 }, { "pm", 1 } }, { pz = 1, pa = 5, pm = 0 })
  check(#m == 2 and m[1] == "pm" and m[2] == "pz", "§1 packs qui manquent : sous le coût d'une unité, triés")
  check(#Im.missing({ { "pa", 1 } }, { pa = 1 }) == 0, "§1 pack au stock pour une unité : rien ne manque")

  -- §2 Pause.
  local st = {}
  Im.stall(st, "t1", 1000, { "pz" })
  local ing = function() return { { "pz", 2 } } end
  local rem = function() return 10 end
  check(Im.active(st, 1000 + 10, ing, rem, {}).t1 == true, "§2 écartée pendant la pause")
  check(Im.active(st, 1000 + Im.PAUSE - 1, ing, rem, {}).t1 == true, "§2 écartée jusqu'à la dernière tick de la pause")
  check(Im.active(st, 1000 + Im.PAUSE, ing, rem, {}).t1 == nil and st.stalled.t1 == nil and st.stall_packs.t1 == nil, "§2 la pause finie l'efface")

  -- §3 Retour anticipé.
  st = {}
  Im.stall(st, "t1", 0, { "pz", "pm" })
  local ing2 = function() return { { "pz", 2 }, { "pm", 1 }, { "pa", 1 } } end
  check(Im.active(st, 10, ing2, rem, { pz = 2, pm = 1 }).t1 == true, "§3 une seule unité au stock : elle reste écartée")
  check(Im.active(st, 10, ing2, rem, { pz = 10, pm = 4 }).t1 == true, "§3 un des packs sous 5 unités : elle reste écartée")
  check(Im.active(st, 10, ing2, rem, { pz = 10, pm = 5 }).t1 == nil, "§3 chaque pack retenu pour 5 unités : elle revient")
  st = {}
  Im.stall(st, "t1", 0, { "pz" })
  check(Im.active(st, 10, ing2, function() return 2 end, { pz = 4 }).t1 == nil, "§3 reste de 2 unités : 2 unités de pack suffisent")
  st = {}
  Im.stall(st, "t1", 0, {})
  check(Im.active(st, 10, ing2, rem, { pz = 99 }).t1 == true, "§3 aucun pack retenu (cause inconnue) : pas de retour anticipé")
  check(Im.released({ stall_packs = {} }, "tx", ing2(), {}, 5) == false, "§3 recherche inconnue : pas de retour")

  -- §4 Rien d'autre de payable.
  st = {}
  Im.stall(st, "ta", 1000, { "pz" })
  Im.stall(st, "tb", 500, { "pz" })
  Im.stall(st, "tc", 500, { "pz" })
  local back = Im.lift(st, 2000)
  check(back == "tb" and st.stalled.tb == nil and st.stall_packs.tb == nil, "§4 la plus ancienne revient (fin de pause la plus proche, puis le nom)")
  check(st.grace.tb == 2000 + Im.PAUSE, "§4 grâce posée pour une pause")
  check(st.stalled.ta ~= nil and st.stalled.tc ~= nil, "§4 les autres restent écartées")
  check(Im.lift({}, 5) == nil, "§4 rien à rendre : nil")
  check(Im.expire_grace(st, 2000 + Im.PAUSE - 1) == 0 and st.grace.tb ~= nil, "§4 grâce gardée avant son terme")
  check(Im.expire_grace(st, 2000 + Im.PAUSE) == 1 and st.grace.tb == nil, "§4 grâce nettoyée à son terme")

  -- §5 Simulation d'un laboratoire (décision toutes les minutes). Un seul pack manque à la recherche A ; B est payable.
  local function simulate(opts)
    local s = { stalled = {}, stall_packs = {}, grace = {} }
    local stock = { pa = 100 }              -- pack payable toujours là
    local lab_s = { tech = nil }
    local order = opts.order                -- recherches par préférence
    local specs = { A = { ing = { { "pz", 2 } }, count = 10 }, B = { ing = { { "pa", 1 } }, count = 10 } }
    local done, started, switches, stalls, idle_ticks, longest, cur_since = {}, 0, 0, 0, 0, 0, 0
    for tick = 0, opts.hours * 60 * MIN, MIN do
      if opts.produce and tick >= opts.produce[1] and tick < opts.produce[2] then stock.pz = (stock.pz or 0) + 1 end
      -- avancement : une unité par minute si le pack est au stock
      if lab_s.tech and not done[lab_s.tech] then
        local sp = specs[lab_s.tech]
        local ok = true
        for _, g in ipairs(sp.ing) do if (stock[g[1]] or 0) < g[2] then ok = false end end
        if ok then
          for _, g in ipairs(sp.ing) do stock[g[1]] = stock[g[1]] - g[2] end
          lab_s.paid = lab_s.paid + 1
          lab_s.paid_tick = tick
          if lab_s.paid >= sp.count then done[lab_s.tech] = true end
        end
      end
      -- décision
      Im.expire_grace(s, tick)
      if Im.should_stall(lab_s, tick, lab_s.tech and done[lab_s.tech], lab_s.tech and s.grace[lab_s.tech]) then
        Im.stall(s, lab_s.tech, tick, Im.missing(specs[lab_s.tech].ing, stock))
        lab_s.stalled = true
        stalls = stalls + 1
      end
      local disabled = Im.active(s, tick, function(t) return specs[t].ing end, function(t) return specs[t].count end, stock)
      local function pick()
        if lab_s.tech and not done[lab_s.tech] and not lab_s.stalled then return lab_s.tech end
        for _, t in ipairs(order) do
          if not done[t] and not disabled[t] then return t end
        end
        return nil
      end
      local want = pick()
      if not want then
        local l = Im.lift(s, tick)
        if l then
          disabled[l] = nil
          if lab_s.tech == l then lab_s.stalled = nil end
          want = pick() or l
        end
      end
      if want ~= lab_s.tech then
        if want then
          lab_s = { tech = want, paid = 0, started = tick }
          switches = switches + 1
          cur_since = tick
        else
          lab_s = { tech = nil }
        end
      end
      if not lab_s.tech then idle_ticks = idle_ticks + MIN end
      -- durée sur une même recherche, comptée seulement tant qu'une AUTRE recherche payable attend (sinon rester dessus est le bon choix)
      local alt = false
      for _, t in ipairs(order) do
        if t ~= lab_s.tech and not done[t] then
          local ok = true
          for _, g in ipairs(specs[t].ing) do if (stock[g[1]] or 0) < g[2] then ok = false end end
          if ok then alt = true end
        end
      end
      if lab_s.tech and alt then longest = math.max(longest, tick - cur_since) end
    end
    return { done = done, switches = switches, stalls = stalls, idle = idle_ticks, longest = longest, stalled_left = next(s.stalled) ~= nil }
  end
  -- (a) A impayable (préférée), B payable ; le pack de A est produit entre 60 et 90 min (assez pour 10 unités de 2)
  local ra = simulate({ order = { "A", "B" }, hours = 3, produce = { 60 * MIN, 90 * MIN } })
  check(ra.done.B == true and ra.done.A == true, "§5a les deux recherches sont faites : B pendant l'attente, A quand son pack existe")
  check(ra.switches <= 4, "§5a au plus 4 changements de recherche, sans oscillation (" .. ra.switches .. ")")
  check(ra.longest <= Im.STALL + 2 * MIN + 30 * MIN * 2, "§5a aucune recherche ne tient le laboratoire au-delà de la durée d'arrêt (+ son travail) : " .. ra.longest)
  local rb = simulate({ order = { "A", "B" }, hours = 3 })
  check(rb.done.B == true and rb.done.A == nil, "§5a' sans pack produit : B faite, A jamais faite mais le laboratoire n'est pas tenu")
  check(rb.longest < 40 * MIN, "§5a' la plus longue durée sur une même recherche reste sous 40 min (" .. rb.longest .. ")")
  -- (b) rien de payable : A seule, jamais produite
  local rc = simulate({ order = { "A" }, hours = 3 })
  check(rc.stalls <= 3 * 60 * MIN / Im.PAUSE + 1, "§5b au plus un arrêt par pause (" .. rc.stalls .. ")")
  check(rc.idle <= 2 * MIN, "§5b le laboratoire n'est jamais oisif plus d'une décision (" .. rc.idle .. ")")
  -- (c) pack produit en petite quantité (2 unités) : pas de va-et-vient
  local rd = simulate({ order = { "A", "B" }, hours = 3, produce = { 30 * MIN, 31 * MIN } })
  check(rd.switches <= 5, "§5c un pack qui ne suffit pas ne fait pas osciller (" .. rd.switches .. ")")
  -- §8 Lot LABOS-ARRET (B4) : la recherche lâchée retient des PACKS ; les autres recherches qui demandent un de ces packs sont écartées avec elle
  -- (fo-logs/2026-11-12_PACK-OSCILLE : 63 lâchers sur 86 suivis d'une recherche qui attendait le MÊME pack, 223 min de laboratoire sur 424).
  check(type(Im.blocked_by_packs) == "function", "§8 Im.blocked_by_packs existe")
  if type(Im.blocked_by_packs) == "function" then
    local ING8 = { ta = { { "pr", 1 }, { "pv", 1 } }, tb = { { "pr", 1 } }, tc = { { "pv", 2 } }, td = { { "pv", 1 }, { "pr", 3 } } }
    local function ing8(t) return ING8[t] or {} end
    local techs8 = { "ta", "tb", "tc", "td" }
    local st8 = {}
    Im.stall(st8, "ta", 100, { "pr" })
    local act8 = Im.active(st8, 200, ing8, function() return 10 end, {})
    local b8 = Im.blocked_by_packs(st8, act8, techs8, ing8)
    check(b8.tb == true and b8.td == true and b8.ta == true, "§8 les recherches qui demandent le pack retenu sont écartées")
    check(b8.tc == nil, "§8 une recherche sans le pack retenu reste choisissable")
    local e8 = Im.blocked_by_packs(st8, act8, techs8, ing8, "tb")
    check(e8.tb == nil and e8.td == true, "§8 l'exception (recherche de la défense) n'est jamais écartée")
    check(next(Im.blocked_by_packs(st8, {}, techs8, ing8)) == nil, "§8 aucune recherche lâchée active : rien d'écarté")
    local back8 = Im.active(st8, 300, ing8, function() return 10 end, { pr = 5 })
    check(next(Im.blocked_by_packs(st8, back8, techs8, ing8)) == nil, "§8 le pack revenu au stock lève l'écart")
    -- Choix simulé (ordre de préférence tb, td, tc) après un lâcher sur « pr » : le suivant n'attend plus le même pack.
    local st9 = {}
    Im.stall(st9, "ta", 0, Im.missing(ing8("ta"), { pv = 4 }))
    local act9 = Im.active(st9, 1, ing8, function() return 10 end, { pv = 4 })
    local dis9 = Im.blocked_by_packs(st9, act9, techs8, ing8)
    for t in next, act9 do dis9[t] = true end
    local pick
    for _, t in ipairs({ "tb", "td", "tc" }) do if not dis9[t] and not pick then pick = t end end
    check(pick == "tc", "§8 après un lâcher sur un pack, la recherche suivante n'en a pas besoin (" .. tostring(pick) .. ")")
  end
  return pass, fail, msgs
end

local Im = assert(load_src(SRC))
local pass, fail, msgs = suite(Im)
local function check6(c, m)
  if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
end
local function strip(src) return (src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")) end
local code = strip(SRC)
local strings = {}
for s in code:gmatch('"([^"\n]*)"') do strings[#strings + 1] = s end
check6(#strings == 0, "§6 aucune chaîne dans la règle : " .. table.concat(strings, " | "))
check6(not code:find("[^i_%w]pairs%s*%(") and not code:find("math%.random") and not code:find("os%.time") and not code:find("os%.clock")
  and not code:find("game%."), "§6 ni pairs, ni hasard, ni horloge, ni API du jeu")
for _, m in ipairs(msgs) do print("[AI3-IMPAYABLE] ECHEC " .. m) end

local MUT = {
  { "arrêt au seuil exact", "return Im.idle(lab, tick) > Im.STALL", "return Im.idle(lab, tick) >= Im.STALL" },
  { "arrêt jamais", "return Im.idle(lab, tick) > Im.STALL", "return false" },
  { "recherche faite relâchée", "if not (lab and lab.tech) or done or lab.stalled then return false end", "if not (lab and lab.tech) or lab.stalled then return false end" },
  { "déjà lâchée relâchée", "if not (lab and lab.tech) or done or lab.stalled then return false end", "if not (lab and lab.tech) or done then return false end" },
  { "grâce ignorée", "if grace ~= nil and tick < grace then return false end", "" },
  { "grâce au terme exclu", "if grace ~= nil and tick < grace then return false end", "if grace ~= nil and tick <= grace then return false end" },
  { "pack au stock pour une unité compté manquant", "if (stock[ing[1]] or 0) < ing[2] then out[#out + 1] = ing[1] end", "if (stock[ing[1]] or 0) <= ing[2] then out[#out + 1] = ing[1] end" },
  { "packs manquants non triés", "  table.sort(out)\n  return out\nend\n\n--- Lâche", "  return out\nend\n\n--- Lâche" },
  { "pause trop courte", "st.stalled[tech] = tick + Im.PAUSE", "st.stalled[tech] = tick + 1" },
  { "pause jamais finie", "if tick >= st.stalled[t] or Im.released", "if Im.released" },
  { "retour sur une seule unité", "local units = min(Im.UNITS, math.max(1, remaining or Im.UNITS))", "local units = 1" },
  { "reste ignoré", "local units = min(Im.UNITS, math.max(1, remaining or Im.UNITS))", "local units = Im.UNITS" },
  { "retour dès un pack", "if (stock[p] or 0) < (need[p] or 1) * units then return false end\n  end\n  return true", "if (stock[p] or 0) >= (need[p] or 1) * units then return true end\n  end\n  return false" },
  { "retour sans pack retenu", "if not packs or #packs == 0 then return false end", "if not packs then return false end" },
  { "retour jamais", "if tick >= st.stalled[t] or Im.released(st, t, ingredients_of(t), stock, remaining_of(t)) then", "if tick >= st.stalled[t] then" },
  { "lift : la plus récente", "if best == nil or st.stalled[t] < st.stalled[best] then best = t end", "if best == nil or st.stalled[t] >= st.stalled[best] then best = t end" },
  { "lift sans grâce", "  st.grace[best] = tick + Im.PAUSE\n", "" },
  { "lift sans retrait", "  st.stalled[best] = nil\n  if st.stall_packs then st.stall_packs[best] = nil end\n  st.grace = st.grace or {}", "  st.grace = st.grace or {}" },
  { "grâce jamais nettoyée", "if tick >= st.grace[t] then", "if false then" },
  { "packs retenus ignorés", "for _, p in ipairs((st.stall_packs or {})[t] or {}) do held[p] = true end", "" },
  { "exception écartée", "if t ~= except then", "if true then" },
  { "tout écarté", "if held[ing[1]] then out[t] = true break end", "out[t] = true break" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif absent)"
  else
    local mod = load_src(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local f2 = 1
    if mod then
      local ok, _, ff = pcall(suite, mod)
      f2 = ok and ff or 1
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[AI3-IMPAYABLE] ECHEC §7 mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[AI3-IMPAYABLE] mutants refusés : %d sur %d", refused, #MUT))
print(string.format("[AI3-IMPAYABLE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
