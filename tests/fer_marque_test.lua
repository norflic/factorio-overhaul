--[[
  Lot FER-MARQUE : banc HORS JEU. Lancement : lua5.2 tests/fer_marque_test.lua (racine du mod).
  Diagnostic : fo-logs/2026-10-30_MATIN/DIAG-FER-EQUIPE.md (verif-guide 0.6.24, graine 1618033988 : seul gisement de fer marqué par des
  cases MOBILES, porte « wait » sans fin, mode survie sans droit de le rouvrir).

    1. D.exact_parts (shared/ai3/danger.lua) : fixe + morts + mobile = D.danger_exact, sur 400 points de cartes tirées (RNG maison) ;
    2. Fa.goal / Fa.decide (shared/team/famine.lua) : le but marqué seulement par des cases mobiles part après Fa.W refus ; nid fixe,
       mort hors calme, équipe hors survie, tâche non productive : prudence d'avant ;
    3. la CHAÎNE du diagnostic rejouée sur la règle pure : 47 min de vagues, refus sans fin AVANT, départ au 3e refus APRÈS ;
    4. D.forget_mobile : un regard vide efface les cases mobiles entières de son disque, rien d'autre ;
    5. le contrôle « livre fer » de verif_guide_common.lua (graine 1618033988 en famine, 271828182 non) ; l'ancien contrôle intact ;
    6. les sources : chaque maillon est branché (porte, escorte, regard, bilan) ; aucun nom d'objet dans shared/team/famine.lua ;
    7. mutants : chaque règle retirée change au moins un fait observé.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SRC = {
  D = read_src("shared/ai3/danger.lua"),
  Sv = read_src("shared/team/survie.lua"),
  Fa = read_src("shared/team/famine.lua"),
  VG = read_src("tools/autotest/fo-autotest/scenarios/verif_guide_common.lua"),
}

--- Charge les modules purs depuis leurs textes (un mutant remplace un texte).
local function load_world(over)
  over = over or {}
  local saved = {}
  for _, n in ipairs({ "shared.ai3.danger", "shared.team.survie", "shared.team.famine" }) do saved[n] = package.loaded[n]; package.loaded[n] = nil end
  local W = {}
  W.D = assert(load(over.D or SRC.D, "@shared/ai3/danger.lua"))()
  W.Sv = assert(load(over.Sv or SRC.Sv, "@shared/team/survie.lua"))()
  package.loaded["shared.team.survie"] = W.Sv
  W.Fa = assert(load(over.Fa or SRC.Fa, "@shared/team/famine.lua"))()
  W.VG = assert(load(over.VG or SRC.VG, "@verif_guide_common.lua"))()(4)
  for n, v in pairs(saved) do package.loaded[n] = v end
  return W
end

local W0 = load_world()
local D, Sv, Fa, VG = W0.D, W0.Sv, W0.Fa, W0.VG

-- RNG maison (déterministe).
local function rng(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return s % n
  end
end

---------------------------------------------------------------------------------------------------
-- Faits observés (les mutants doivent en changer au moins un)
---------------------------------------------------------------------------------------------------
local B = 600
local function facts(Wx)
  local Dx, Fx = Wx.D, Wx.Fa
  local f = {}
  -- 1. décomposition = danger exact
  local r = rng(42)
  local sum_ok, n_mob, n_fix, n_dea = true, 0, 0, 0
  for m = 1, 8 do
    local map = Dx.new()
    local tick = 3600 * (20 + r(40))
    for _ = 1, 6 do Dx.mark_seen(map, r(200) - 100, r(200) - 100, ({ "worm", "spawner", "pack", "turret" })[1 + r(4)], nil, tick - r(3600 * 30)) end
    for _ = 1, 12 do Dx.mark_seen(map, r(200) - 100, r(200) - 100, "unit", nil, tick - r(3600 * 8)) end
    for _ = 1, 4 do Dx.mark_attack(map, r(200) - 100, r(200) - 100, tick - r(3600 * 5)) end
    for _ = 1, 5 do Dx.mark_death(map, r(200) - 100, r(200) - 100, tick - r(3600 * 50), r(3) == 0) end
    for _ = 1, 50 do
      local x, y = r(240) - 120 + 0.5, r(240) - 120 + 0.5
      local p = Dx.exact_parts(map, x, y, tick)
      if p.fixed + p.deaths + p.mobile ~= Dx.danger_exact(map, x, y, tick) then sum_ok = false end
      if p.mobile > 0 then n_mob = n_mob + 1 end
      if p.fixed > 0 then n_fix = n_fix + 1 end
      if p.deaths > 0 then n_dea = n_dea + 1 end
    end
  end
  f.sum_ok = sum_ok
  f.parts_seen = n_mob > 20 and n_fix > 20 and n_dea > 5
  -- 2. Fa.goal
  local function g(on, kind, fixed, deaths, mobile, calm, deaths_n)
    local ok, why = Fx.goal({ on = on, kind = kind, parts = { fixed = fixed, deaths = deaths, mobile = mobile }, calm = calm, B = B, deaths_n = deaths_n })
    return tostring(ok) .. ":" .. tostring(why)
  end
  f.g_diag = g(true, "service", 0, 0, 900)          -- le cas mesuré : danger 900 = D.MOBILE_CAP, seuil 600
  f.g_mine = g(true, "mine", 0, 0, 656)
  f.g_rebuild = g(true, "rebuild", 0, 0, 810)
  f.g_build, f.g_extend = g(true, "build", 0, 0, 729), g(true, "extend", 0, 0, 729)
  f.g_nid = g(true, "service", 800, 0, 900)          -- nid fixe au but
  f.g_nid_faible = g(true, "mine", 15, 0, 900)       -- une menace fixe, même très décrue, garde la prudence
  f.g_mort = g(true, "service", 0, 600, 900, false)  -- mort au but, route non « au calme » (loin ou récente)
  f.g_mort_calme = g(true, "service", 0, 600, 900, true) -- le cas du diagnostic : 1 mort ancienne, tâche proche du QG
  f.g_mort_calme2 = g(true, "service", 0, 1200, 900, true, 2) -- deux morts anciennes au but : ne bloquent pas encore
  f.g_morts_calme = g(true, "service", 0, 1800, 900, true, 3) -- relecture : Fa.DEATHS_MAX morts de l'heure au but, même au calme : prudence
  f.g_off = g(false, "service", 0, 0, 900)
  f.g_def = g(true, "fortify", 0, 0, 900)
  f.g_craft = g(true, "craft", 0, 0, 900)
  f.g_libre = g(true, "service", 0, 0, 590)
  f.g_vide = g(true, "service", 0, 700, 0, false)
  f.g_calme_libre = g(true, "service", 0, 600, 0, true) -- morts « au calme » seules : le but est jugé sans elles (sous le seuil)
  -- 3. Fa.decide
  local function dd(n, free) local a, b = Fx.decide({ n = n, free = free }) return a .. ":" .. b end
  f.d1, f.d2, f.d3, f.d3e, f.d9 = dd(1, 0), dd(2, 5), dd(3, 0), dd(3, 2), dd(9, 1)
  -- 4. chaîne du diagnostic : 47 min, une vague toutes les 5 min remet la marque du gisement (49, -51) ; une tentative toutes les 30 s
  --    (tâche refusée : RETRY_DANGER) ; porte AVANT (goal_free faux : attente sans fin) contre APRÈS (famine).
  local function chain(with_famine)
    local map = Dx.new()
    local gx, gy = 49, -51
    local waits, first_go, n, pass = 0, nil, 0, -1
    for k = 0, 47 * 2 do
      local tick = 12 * 3600 + k * 1800
      if k % 8 == 0 then -- passage d'une vague toutes les 4 min : 6 unités vues remettent la case à D.MOBILE_CAP (900, mesuré)
        for u = 1, 6 do Dx.mark_seen(map, gx + 6, gy + u, "unit", nil, tick) end
      end
      local p = Dx.exact_parts(map, gx, gy, tick)
      local goal_d = p.fixed + p.deaths + p.mobile
      local dec = Dx.gate({ blocked = goal_d >= B, max_d = goal_d, goal_d = goal_d, deaths = 0, far = false },
        { B = B, prudence = 1000, escort_ok = false, survie_deaths = Sv.DEATHS_WAIT })
      if dec == "wait" then
        n = n + 1
        local free = with_famine and Fx.goal({ on = true, kind = "service", parts = p, calm = false, B = B })
        if free and tick < pass then dec, n = "go", 0 -- passe-droit (comportement.lua, M.PASS_TICKS = 5 min)
        elseif free and n > Fx.W then dec = Fx.decide({ n = n, free = 0 }) n = 0 pass = tick + 18000 end
      else
        n = 0
      end
      if dec == "wait" then waits = waits + 1 elseif not first_go then first_go = k end
    end
    return waits, first_go
  end
  f.chain_before_waits, f.chain_before_go = chain(false)
  f.chain_after_waits, f.chain_after_go = chain(true)
  -- 5. D.forget_mobile
  local map = Dx.new()
  Dx.mark_seen(map, 49, -51, "unit", nil, 1000)               -- cases mobiles autour du gisement
  Dx.mark_seen(map, 300, 300, "spawner", nil, 1000)           -- nid lointain
  Dx.mark_death(map, 50, -50, 1000)
  local cells0 = 0
  for _ in pairs(map.cells) do cells0 = cells0 + 1 end
  local cleared_near = Dx.forget_mobile(map, 49, -51, 40, 9)  -- ennemi vu à 9 tuiles : disque de 7 : aucune case entière
  local cleared = Dx.forget_mobile(map, 49, -51, 40, nil)     -- aucun ennemi dans 40 tuiles : disque de 38
  local cells1 = 0
  for _ in pairs(map.cells) do cells1 = cells1 + 1 end
  f.fm_near = cleared_near
  f.fm_cleared = cleared
  f.fm_partial_kept = cells1 > 0 and cells1 == cells0 - cleared and map.n_cells == cells1
  f.fm_goal = Dx.exact_parts(map, 49, -51, 2000).mobile
  f.fm_threats, f.fm_deaths = #map.threats, #map.deaths
  f.clear_on, f.clear_off = Fx.clear(true), Fx.clear(false)
  -- 6. contrôle « livre fer » (verif_guide_common.lua) : diagnostic 1618033988 contre 271828182
  local function run_tr(series)
    local st = {}
    for m = 1, 59 do
      local s = series(m)
      Wx.VG.iron_tranche(st, m, s[1], s[2])
    end
    local bad = 0
    for _, tr in ipairs(st.iron_tr or {}) do if not tr.ok then bad = bad + 1 end end
    return #(st.iron_tr or {}), bad
  end
  -- 1618033988 (DIAG, [M]) : 1 576 à la minute 11 et figé jusqu'à 17, 1 834 à 24, 2 290 à 59 ; fer au stock 0 à 2 après 12 min.
  local function diag(m)
    local d
    if m <= 11 then d = math.floor(1576 * m / 11)
    elseif m <= 17 then d = 1576
    elseif m <= 24 then d = 1576 + math.floor((1834 - 1576) * (m - 17) / 7)
    else d = 1834 + math.floor((2290 - 1834) * (m - 24) / 35) end
    return { d, m <= 11 and 300 or 1 }
  end
  f.tr_diag_n, f.tr_diag_bad = run_tr(diag)
  f.tr_good_n, f.tr_good_bad = run_tr(function(m) return { 372 * m, 40 } end) -- 271828182 : 21 950 en 59 min, stock bas
  f.tr_rich_n, f.tr_rich_bad = run_tr(function(m) return { 1000 + m, 500 } end) -- livre peu, mais le coffre est plein
  f.tr_trickle_n, f.tr_trickle_bad = run_tr(function(m) return { 5 * m, 0 } end) -- un filet (> 0) : FAMINE quand même
  local st = {}
  f.tr_absent = Wx.VG.iron_tranche(st, 10, nil, 0) == nil and st.iron_tr == nil
  return f
end

local F0 = facts(W0)

section("1. D.exact_parts = D.danger_exact")
check(F0.sum_ok, "fixe + morts + mobile = danger exact sur 400 points")
check(F0.parts_seen, "les trois parts sont exercées (cases mobiles, menaces fixes, morts)")

section("2. Fa.goal et Fa.decide")
check(F0.g_diag == "true:mobile", "cas du diagnostic (service, mobile 900, seuil 600) : famine " .. F0.g_diag)
check(F0.g_mine == "true:mobile" and F0.g_build == "true:mobile" and F0.g_extend == "true:mobile", "minage, construction, agrandissement : famine")
check(F0.g_rebuild == "true:mobile", "reconstruction (refusée aux minutes 22 à 48) : famine " .. F0.g_rebuild)
check(F0.g_nid == "false:nid", "nid fixe au but : prudence gardée " .. F0.g_nid)
check(F0.g_nid_faible == "false:nid", "menace fixe décrue au but : prudence gardée " .. F0.g_nid_faible)
check(F0.g_mort == "false:mort", "mort au but hors calme (trajet lointain ou récente) : prudence gardée " .. F0.g_mort)
check(F0.g_mort_calme == "true:mobile", "mort ancienne d'une tâche proche (calme) : ne bloque plus " .. F0.g_mort_calme)
check(F0.g_mort_calme2 == "true:mobile", "deux morts anciennes au but (calme) : ne bloquent pas encore " .. F0.g_mort_calme2)
check(F0.g_morts_calme == "false:morts", "Fa.DEATHS_MAX morts de l'heure au but, même au calme : prudence (pas de marche suicide) " .. F0.g_morts_calme)
check(Fa.DEATHS_MAX == Sv.DEATHS_WAIT, "Fa.DEATHS_MAX = Sv.DEATHS_WAIT")
check(F0.g_off == "false:hors-survie", "équipe hors survie : règle d'avant " .. F0.g_off)
check(F0.g_def == "false:tache" and F0.g_craft == "false:tache", "tâches hors ressources : règle d'avant")
check(F0.g_libre == "false:libre", "but sous le seuil : rien à faire ici " .. F0.g_libre)
check(F0.g_vide == "false:mort", "but au-dessus du seuil par une mort seule : prudence " .. F0.g_vide)
check(F0.g_calme_libre == "false:libre", "morts anciennes d'une tâche proche, sans case mobile : but libre (règle d'avant) " .. F0.g_calme_libre)
check(F0.d1 == "wait:famine-attente" and F0.d2 == "wait:famine-attente", "1er et 2e refus : attente (" .. F0.d1 .. ", " .. F0.d2 .. ")")
check(F0.d3 == "go:famine", "3e refus, aucun soldat libre : départ seul " .. F0.d3)
check(F0.d3e == "escort:famine", "3e refus, 2 soldats libres : escorte " .. F0.d3e)
check(F0.d9 == "go:famine", "1 soldat libre : pas d'escorte, départ " .. F0.d9)
check(Fa.W == Sv.ESCALADE_W, "Fa.W = Sv.ESCALADE_W")

section("3. Chaîne du diagnostic (47 min de vagues)")
print(string.format("  avant : %d attentes sur 95, premier depart %s ; apres : %d attentes, premier depart a la tentative %s",
  F0.chain_before_waits, tostring(F0.chain_before_go), F0.chain_after_waits, tostring(F0.chain_after_go)))
check(F0.chain_before_go == nil and F0.chain_before_waits >= 60, "AVANT : le gisement reste fermé (aucun départ, attentes sans fin)")
check(F0.chain_after_go == 2, "APRÈS : départ au 3e refus (tentative 2)")
check(F0.chain_after_waits < F0.chain_before_waits / 2, "APRÈS : au moins deux fois moins d'attentes")

section("4. Regard : D.forget_mobile")
check(F0.fm_near == 0, "ennemi vu à 9 tuiles : aucune case entière dans le disque, rien d'effacé")
check(F0.fm_cleared > 0, "aucun ennemi dans le regard : cases mobiles effacées (" .. F0.fm_cleared .. ")")
check(F0.fm_partial_kept, "les cases qui débordent du disque restent, compte n_cells juste")
check(F0.fm_goal == 0, "la case du gisement est vide après le regard")
check(F0.fm_threats == 1 and F0.fm_deaths == 1, "menaces fixes et morts : non touchées")
check(F0.clear_on == true and F0.clear_off == false, "effacement en mode survie seulement")

section("5. Contrôle « livre fer » de verif_guide_common.lua")
check(F0.tr_diag_n == 5 and F0.tr_diag_bad >= 2, string.format("graine 1618033988 (diagnostic) : %d tranche(s), %d en famine", F0.tr_diag_n, F0.tr_diag_bad))
check(F0.tr_good_n == 5 and F0.tr_good_bad == 0, "graine 271828182 : 5 tranches, aucune en famine")
check(F0.tr_rich_bad == 0, "livraison faible mais stock de fer plein : pas de famine")
check(F0.tr_trickle_bad == 5, "un filet de fer (> 0) ne suffit pas : famine")
check(F0.tr_absent, "équipe absente : aucune tranche")
check(SRC.VG:find("pw < (st.floor or 8) and iron >= IRON_MIN", 1, true) ~= nil and SRC.VG:find("local IRON_MIN = 100", 1, true) ~= nil
  and SRC.VG:find("local RUN_MAX = 5", 1, true) ~= nil and SRC.VG:find("(st.run_max or 0) < RUN_MAX", 1, true) ~= nil,
  "contrôle « se reconstruit » inchangé (condition, IRON_MIN, RUN_MAX)")
check(SRC.VG:find("#trs >= 1 and bad == 0", 1, true) ~= nil, "le nouveau contrôle exige au moins une tranche close et aucune famine")

section("6. Chaîne dans les sources")
local CO = read_src("script/ai3/comportement.lua")
local SS = read_src("script/team/survie.lua")
check(CO:find('local Fa = require("shared.team.famine")', 1, true) ~= nil, "porte : module famine chargé au chargement (pas en événement)")
check(CO:find("D.exact_parts(t.map, dest.x, dest.y, tick)", 1, true) ~= nil, "porte : parts du but lues")
check(CO:find("Fa.goal({ on = true, kind = task.kind, parts = fam_parts, calm = calm, B = res.B,", 1, true) ~= nil, "porte : Fa.goal appelée avec le calme d'ACTIF")
check(CO:find("deaths_n = D.deaths_near(t.map, { dest }, D.DEATH_R, tick) })", 1, true) ~= nil, "porte : morts de l'heure au but passées à Fa.goal (plafond)")
check(CO:find("if fam then goal_free = true end", 1, true) ~= nil, "porte : le but de famine compte comme libre pour l'escalade")
check(CO:find("if fam_only then decision, why = Fa.decide({ n = w.n, free = free }) end", 1, true) ~= nil, "porte : Fa.decide (départ ou escorte)")
check(CO:find('elseif why ~= "loin" and why ~= "famine" then', 1, true) ~= nil, "escorte refusée en famine : le PNJ part quand même")
check(CO:find("if Fa.clear(Survie.on(f)) then", 1, true) ~= nil and CO:find("D.forget_mobile(t.map, c.x, c.y, r, nd)", 1, true) ~= nil, "regard : cases mobiles vides effacées en survie")
check(CO:find("log(Fa.line(", 1, true) ~= nil and CO:find("log(Fa.keep_line(", 1, true) ~= nil and CO:find("[FO-FAMINE] %s : bilan", 1, true) ~= nil, "journal [FO-FAMINE] : décisions, prudence gardée, bilan")
check(SS:find("function Survie.note_famine(f, cleared)", 1, true) ~= nil and SS:find("departs de famine %d, cases mobiles effacees %d", 1, true) ~= nil, "bilan [FO-SURVIE] : compteurs de famine")
local code = SRC.Fa:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check(not code:find('"[%w%-]*iron[%w%-]*"') and not code:find('"[%w%-]*plate[%w%-]*"') and not code:find('"[%w%-]*ore[%w%-]*"'), "aucun nom d'objet dans shared/team/famine.lua")
check(not code:find("[^i]pairs%("), "shared/team/famine.lua : aucun pairs")

section("7. Mutants")
local function mutate(key, a, b)
  local s, n = SRC[key]:gsub(a:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"), (b:gsub("%%", "%%%%")))
  return s, n
end
local MUTANTS = {
  { "nid ignoré", "Fa", "if fixed > 0 then return false, \"nid\" end", "" },
  { "mort hors calme ignorée", "Fa", "if deaths > 0 and not a.calm then return false, \"mort\" end", "" },
  { "calme ignoré", "Fa", "(a.calm and 0 or deaths)", "deaths" },
  { "plafond de morts retiré", "Fa", "if num(a.deaths_n) >= Fa.DEATHS_MAX then return false, \"morts\" end", "" },
  { "mode survie ignoré", "Fa", "if not a.on then return false, \"hors-survie\" end", "" },
  { "toutes les tâches", "Fa", "if not Fa.KINDS[a.kind] then return false, \"tache\" end", "" },
  { "reconstruction retirée", "Fa", "service = true, rebuild = true }", "service = true }" },
  { "aucune attente", "Fa", "if num(a.n) <= Fa.W then", "if num(a.n) < 0 then" },
  { "jamais d'escorte", "Fa", "if num(a.free) >= Fa.ESCORT_MIN then", "if false then" },
  { "seuil ignoré", "Fa", "if goal < B then return false, \"libre\" end", "" },
  { "effacement hors survie", "Fa", "function Fa.clear(on) return on and true or false end", "function Fa.clear(on) return true end" },
  { "parts sans mobile", "D", "if c then mobile = mobile_now(c, tick) end", "" },
  { "parts sans morts", "D", "if not d.home and dx * dx + dy * dy <= D.DEATH_R * D.DEATH_R then deaths = deaths + death_w(d, tick) end", "" },
  { "regard sans coin éloigné", "D", "if fx * fx + fy * fy <= l2 then", "if true then" },
  { "regard qui ignore l'ennemi vu", "D", "local lim = (nearest and math.min(nearest, r) or r) - 2\n  if lim <= 0 then return 0 end\n  local l2 = lim * lim\n  local n = 0", "local lim = r - 2\n  local l2 = lim * lim\n  local n = 0" },
  { "tranche sans le stock", "VG", "ok = got >= IRON_TRANCHE or (stock or 0) >= IRON_MIN", "ok = got >= IRON_TRANCHE" },
  { "tranche à > 0", "VG", "ok = got >= IRON_TRANCHE or", "ok = got > 0 or" },
}
local function same(a, b)
  for k, v in pairs(a) do if b[k] ~= v then return false end end
  for k, v in pairs(b) do if a[k] ~= v then return false end end
  return true
end
for _, m in ipairs(MUTANTS) do
  local txt, n = mutate(m[2], m[3], m[4])
  if check(n == 1, "mutant « " .. m[1] .. " » appliqué une fois (" .. n .. ")") then
    local ok, Fm = pcall(function() return facts(load_world({ [m[2]] = txt })) end)
    check((not ok) or not same(F0, Fm), "mutant « " .. m[1] .. " » détecté")
  end
end
-- déterminisme : deux passages, mêmes faits
check(same(F0, facts(load_world())), "déterminisme : mêmes faits au second passage")

print(string.format("[FER-MARQUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
