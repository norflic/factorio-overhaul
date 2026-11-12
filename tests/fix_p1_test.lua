-- Lot FIX-P1 : quatre failles de l'audit statique (règles pures, sans API Factorio).
--   1. shared/team/bilan_charbon.lua (Bc.drill_counts) + script/team/plafond_charbon.lua : seule une foreuse du combustible qui travaille
--      (ou attend la place de sa sortie) compte dans la capacité ;
--   2. (écartée : la règle F491 du DC retient aussi l'avance ; vérifié ici qu'elle reste entière) ;
--   3. shared/team/centrale.lua : plus de borne C.MAX_REQUESTS sur la partie (C.COOL et C.MAX_REFUSED bornent) ;
--   4. shared/ai3/demande.lua : le puits se ferme net (p = 0) quand le stock ne dort plus.
-- Lancer : lua5.2 tests/fix_p1_test.lua [racine des sources, défaut .]
package.path = "./?.lua;" .. package.path
local ROOT = (...) or "."
local fails, oks = 0, 0
local quiet = false
local function check(c, msg)
  if c then oks = oks + 1 else fails = fails + 1; if not quiet then print("ECHEC : " .. msg) end end
end
local function read(p) local fh = assert(io.open(ROOT .. "/" .. p, "rb")); local s = fh:read("*a"); fh:close(); return s end
local function rule(src, name) return assert(load(src, "=" .. name, "t"))() end

-- statuts de banc : des nombres quelconques, lus comme defines.entity_status (aucune valeur supposée)
local S = { working = 11, waiting_for_space_in_destination = 12, no_minable_resources = 13, disabled_by_script = 14, no_power = 15,
  no_fuel = 16, disabled_by_control_behavior = 17, low_power = 18 }

local function t_charbon(bsrc, psrc)
  local Bc = rule(bsrc, "bilan_charbon")
  check(Bc.drill_counts ~= nil and Bc.drill_counts(S.working, S) == true, "1. foreuse qui travaille : comptée")
  check(Bc.drill_counts ~= nil and Bc.drill_counts(S.waiting_for_space_in_destination, S) == true, "1. foreuse qui attend la place de sa sortie : comptée")
  for _, k in ipairs({ "no_minable_resources", "disabled_by_script", "no_power", "no_fuel", "disabled_by_control_behavior", "low_power" }) do
    check(Bc.drill_counts ~= nil and Bc.drill_counts(S[k], S) == false, "1. foreuse " .. k .. " : pas comptée")
  end
  check(Bc.drill_counts ~= nil and Bc.drill_counts(nil, S) == false, "1. statut illisible : pas comptée")
  -- le relevé en jeu lit le prédicat dans la condition des foreuses du combustible
  local line = psrc:match("\n([^\n]*mp%.products%[1%]%.name == T%.fuel[^\n]*)\n")
  check(line ~= nil and line:find("Bc.drill_counts(e.status, status)", 1, true) ~= nil, "1. plafond_charbon : la foreuse n'entre dans drills que par Bc.drill_counts")
end

local function t_centrale(csrc)
  local C = rule(csrc, "centrale")
  local function n(t)
    local o = { done = 1, pending = 0, refused = 0, hold = false, off = false, boiler_kw = 1800, built = 1 }
    for k, v in pairs(t or {}) do o[k] = v end
    return o
  end
  -- 2. F491 (décision du DC) : aucun déclencheur, avance comprise, ne passe sous C.GROW_LOAD
  local nb, why = C.growth({ saturated = false, sat = 0, def_n = 0 }, n({ load = 0.6, anticipate = true }))
  check(nb == nil and why == C.LOAD_REASON, "2. avance à 60 % mesurés : retenue par F491 (" .. tostring(why) .. ")")
  nb = C.growth({ saturated = false, sat = 0, def_n = 0 }, n({ load = 0.8, anticipate = true }))
  check(nb ~= nil and nb > 0, "2. avance à 80 % mesurés : demandée")
  nb, why = C.growth({ saturated = true, sat = 10, def_n = 0 }, n({ load = 0.5 }))
  check(nb == nil and why == C.LOAD_REASON, "2. saturée sans avance à 50 % : toujours retenue par F491")
  nb, why = C.growth({ saturated = false, sat = 0, def_n = 3 }, n({ load = 0.2, deficit_kw = 5000 }))
  check(nb == nil and why == C.LOAD_REASON, "2. déficit sans avance à 20 % : toujours retenu par F491")
  -- 3. plus de borne sur la partie : 1 000 demandes passées n'empêchent pas la suivante
  nb, why = C.growth({ saturated = true, sat = 10, def_n = 0, requests = 1000 }, n({ load = 0.9 }))
  check(nb ~= nil and nb > 0, "3. 1 000 demandes sur la partie : la croissance continue (" .. tostring(why) .. ")")
  nb = C.growth({ saturated = true, sat = 10, def_n = 0, requests = 15 }, n({ load = 1 }))
  check(nb ~= nil and nb > 0, "3. 15 demandes (l'ancienne borne) : la croissance continue")
  nb, why = C.growth({ saturated = true, sat = 10, def_n = 0, requests = 1000 }, n({ load = 0.9, refused = C.MAX_REFUSED }))
  check(nb == nil and why ~= nil, "3. C.MAX_REFUSED borne toujours")
  nb, why = C.growth({ saturated = true, sat = 10, def_n = 0, requests = 1000 }, n({ load = 0.9, cool = true }))
  check(nb == nil and why ~= nil, "3. C.COOL borne toujours")
end

local function t_demande(dsrc)
  local Dm = rule(dsrc, "demande")
  local c = { science = { { item = "x", mu = 1 } }, equipement = {} }
  local st = Dm.new()
  local dormant = { stock_mu = 60000, free_mu = 50000, Y = 500, cands = c, research = true }
  for _ = 1, 30 do Dm.step(st, dormant) end
  check(st.p > 0, "4. stock qui dort 30 cycles : puits ouvert (p = " .. tostring(st.p) .. ")")
  local awake = { stock_mu = 1500, free_mu = 500, Y = 500, cands = c, research = true }
  local o = Dm.step(st, awake)
  check(not o.dormant and o.p == 0 and st.p == 0, "4. le stock ne dort plus : puits fermé net dès le premier cycle (p = " .. tostring(o.p) .. ")")
  check(#o.sinks == 0, "4. puits fermé : aucun puits")
  for _ = 1, 3 do o = Dm.step(st, dormant) end
  check(o.dormant and o.p > 0, "4. le stock se rendort : le puits rouvre")
end

local function all(srcs)
  t_charbon(srcs.b, srcs.p); t_centrale(srcs.c); t_demande(srcs.d)
end

local SRC = { b = read("shared/team/bilan_charbon.lua"), p = read("script/team/plafond_charbon.lua"),
  c = read("shared/team/centrale.lua"), d = read("shared/ai3/demande.lua") }
all(SRC)
local base_fails = fails

-- Mutants : chacun doit faire échouer la batterie
local COOL_LINE = "  if n.cool then return nil, \"pause apres une centrale refusee ou abandonnee\" end\n"
local mutants = {
  { "b", "1. la foreuse en attente de place ne compte plus", " or status == S.waiting_for_space_in_destination", "" },
  { "b", "1. toute foreuse compte", "return S ~= nil and status ~= nil and (status == S.working or status == S.waiting_for_space_in_destination)", "return true" },
  { "b", "1. la foreuse à sec compte", "(status == S.working or", "(status == S.working or status == S.no_minable_resources or" },
  { "p", "1. le relevé n'appelle plus le prédicat", " and Bc.drill_counts(e.status, status) then", " then" },
  -- (P0-CENTRALE, 80305871 : la garde F491 laisse passer une demande engagée au-delà de la capacité, C.engaged_over : repères suivis)
  { "c", "2. l'avance contourne F491", "C.engaged_over(n.engaged_kw, n.cap_kw) then", "C.engaged_over(n.engaged_kw, n.cap_kw) and not n.anticipate then" },
  { "c", "2. la garde F491 tombe pour tous", "n.load ~= nil and n.load < C.GROW_LOAD and not C.engaged_over(n.engaged_kw, n.cap_kw) then", "false then" },
  { "c", "3. la borne C.MAX_REQUESTS revient", COOL_LINE, COOL_LINE .. "  if (st.requests or 0) >= C.MAX_REQUESTS then return nil, \"trop de demandes\" end\n" },
  { "c", "3. une borne de 15 revient", COOL_LINE, COOL_LINE .. "  if (st.requests or 0) >= 15 then return nil, \"x\" end\n" },
  { "d", "4. la décroissance de 5 % revient", "    p = 0 -- lot FIX-P1", "    p = p * (1000 - Dm.DECAY) / 1000 -- " },
  { "d", "4. le puits ne se ferme jamais", "    p = 0 -- lot FIX-P1", "    p = p -- " },
}
local killed = 0
for _, m in ipairs(mutants) do
  local src = SRC[m[1]]
  local a, b = src:find(m[3], 1, true)
  if not a then
    print("ECHEC : mutant '" .. m[2] .. "' : motif introuvable"); base_fails = base_fails + 1
  else
    local ms = {}; for k, v in pairs(SRC) do ms[k] = v end
    ms[m[1]] = src:sub(1, a - 1) .. m[4] .. src:sub(b + 1)
    local f0 = fails
    quiet = true
    local ok = pcall(all, ms)
    quiet = false
    if fails > f0 or not ok then killed = killed + 1 else print("ECHEC : mutant survivant : " .. m[2]); base_fails = base_fails + 1 end
    fails = f0
  end
end
print(string.format("[FIX-P1] %d mutant(s) refusé(s) sur %d", killed, #mutants))
print(string.format("[FIX-P1] BILAN : %d OK, %d ECHEC(S)", oks, base_fails))
os.exit(base_fails == 0 and 0 or 1)
