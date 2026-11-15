--[[
  Lot MAJA-097 : ordre Maj+A, première entité dans la zone à +1 492 s (banc INTEG-096-ordres, graine 123456789, ordre au tick 72060 sur
  (44, -36) rayon 11). Deux maillons coupés :
    1. la bande -13 du champ 100001, demandée AVANT l'ordre et encore en réserve, était attachée par l'ordre et se posait hors de la zone :
       Mg.order_swap (shared/team/migration_champ.lua) désigne la bande de la zone qui la remplace (ent_order_swap, script/team/migration_champ.lua) ;
    2. la bande de l'ordre attendait le plancher commun de son kit (tapis 102/152) avec 13 fours et 40 poteaux au coffre : Cp.ready_order
       (shared/team/chantier_progressif.lua) la fait partir dès une pièce réservée (spec.ordre).
  Usage : lua5.2 tests/maja097_test.lua (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local function read(p) local fh = assert(io.open(p, "rb")) local s = fh:read("*a") fh:close() return s end
local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end end

local MG_SRC = read("shared/team/migration_champ.lua")
local CP_SRC = read("shared/team/chantier_progressif.lua")

-- scène du banc : cadre axe x, bandes de pas 8 (numéro = début de la bande en travers de l'axe)
local ORDER = { -13, -61, -53, -45, -37, -29, -21 }
local OD = { x = 44, y = -36, r = 11 }

local function suite_swap(Mg)
  local before = failures
  check(type(Mg.order_swap) == "function", "Mg.order_swap existe")
  if type(Mg.order_swap) ~= "function" then return failures - before end
  local c = Mg.order_swap(ORDER, "x", OD, -13, {})
  check(c[1] == -37, "bande -13 hors du cercle : la bande -37 (milieu -33, la plus proche du centre -36) la remplace (" .. tostring(c[1]) .. ")")
  check(#c == 4 and c[2] == -45 and c[3] == -29 and c[4] == -53, "candidates : seulement les bandes qui coupent le cercle, la plus proche d'abord")
  local none = Mg.order_swap(ORDER, "x", OD, -37, {})
  check(#none == 0, "bande en vol dans la zone : aucune bascule")
  local sk = Mg.order_swap(ORDER, "x", OD, -13, { [-37] = true })
  check(sk[1] == -45, "une bande posée ou écartée (skip) n'est jamais choisie")
  local far = Mg.order_swap(ORDER, "x", { x = 0, y = 900, r = 5 }, -13, {})
  check(#far == 0, "aucune bande ne coupe le cercle : la bande en vol reste")
  check(#Mg.order_swap(ORDER, "x", nil, -13, {}) == 0, "sans ordre : rien")
  local y = Mg.order_swap({ 100, 116, 132 }, "y", { x = 120, y = 0, r = 2 }, 100, {})
  check(y[1] == 116, "axe y : la coordonnée en travers est x")
  return failures - before
end

-- bord du cercle : la bande -21 couvre [-21, -13), le cercle [-47, -25] : elle ne le coupe pas ; la bande -29 [-29, -21) le coupe
local function suite_edge(Mg)
  local before = failures
  local e = Mg.order_swap(ORDER, "x", OD, -21, {})
  check(e[1] == -37, "bande -21 hors du cercle : bascule vers -37")
  local t = Mg.order_swap(ORDER, "x", OD, -29, {})
  check(#t == 0, "bande -29 [-29, -21) coupe le cercle [-47, -25] : reste")
  return failures - before
end

local KIT = { ["a-foreuse"] = 8, ["b-bras"] = 33, ["c-coffre"] = 7, ["d-poteau"] = 40, ["e-four"] = 13, ["f-tapis"] = 152 }
local STOCK = { ["d-poteau"] = 40, ["e-four"] = 13 } -- au coffre à l'ordre (banc : 53/253)
local LEAD = { ["a-foreuse"] = true }

local function view(ordre, extra)
  local s = { champ = { oid = 100001, pr = -37 }, ordre = ordre or nil }
  for k, v in pairs(extra or {}) do s[k] = v end
  return { state = "reserve", spec = s, need = KIT, stock = STOCK, lead = LEAD }
end

local function suite_cp(Cp)
  local before = failures
  check(type(Cp.ready_order) == "function", "Cp.ready_order existe")
  local ok0 = Cp.go(view(false))
  check(ok0 == false, "bande ordinaire : attend son plancher (0 foreuse, 0 tapis) comme avant")
  local ok1, d1 = Cp.go(view(true))
  check(ok1 == true, "bande d'un ORDRE : part avec les 53 pièces au coffre (fours, poteaux)")
  check(d1 and d1.pieces == 53 and d1.total == 253, "détail : 53/253 pièces")
  local empty = view(true); empty.stock = {}
  check(Cp.go(empty) == false, "bande d'un ordre sans aucune pièce au coffre : attend (rien à poser)")
  check(Cp.go(view(true, { degel = { oid = 1 } })) == false, "bande d'un ordre qui dégèle des paires : garde du dégel (voie entière)")
  local dg = view(true, { degel = { oid = 1 } }); dg.degele = true
  check(Cp.go(dg) == true, "dégel fait : la bande d'ordre part")
  check(Cp.go(view(true, { champ = { oid = 1, pr = 1, coal = 1 } })) == false, "réseau du charbon : tout-ou-rien gardé")
  local ro = view(true); ro.reopened = 2
  check(Cp.go(ro) == false, "projet rouvert : Rr.partial_go le couvre")
  return failures - before
end

print("== 1. Règles pures")
local Mg = assert(load(MG_SRC, "=migration_champ"))()
local Cp = assert(load(CP_SRC, "=chantier_progressif"))()
suite_swap(Mg)
suite_edge(Mg)
suite_cp(Cp)

print("== 2. Branchement")
local MS = read("script/team/migration_champ.lua")
check(MS:find("ent_order_swap(f, ms, tick) -- lot MAJA-097", 1, true) ~= nil, "l'ordre de l'entrepreneur bascule la bande hors zone avant d'attacher")
check(MS:find("local cands = Mg.order_swap(st.order, st.frame.axis, { x = od.x, y = od.y, r = od.r, x0 = od.x0, y0 = od.y0, x1 = od.x1, y1 = od.y1 }, st.band_key, skip)", 1, true) ~= nil, "bascule par la règle pure")
check(MS:find('if pr and Build.cancel(f, old, "ordre: bande hors de la zone de l\'ordre") then', 1, true) ~= nil, "annulation seulement après un plan de bande lu")
check(MS:find("begin_band(f, surface, ms, o, st, survey_field(f, o), tick, nil, { pr = pr, bd = bd })", 1, true) ~= nil, "demande immédiate de la bande de la zone")
check(MS:find("local pr = pre and pre.pr or nil", 1, true) ~= nil, "begin_band accepte la bande choisie")
check(select(2, MS:gsub("p%.spec%.ordre", "")) >= 2, "spec.ordre posé aux deux attaches (order et follow)")
check(read("script/team/build.lua"):find("prog, pd = Build.Cp.go({ state = p.state, reopened = p.reopened, degele = p.degele, spec = p.spec,", 1, true) ~= nil,
  "build.lua passe spec (spec.ordre) à Cp.go")

print("== 3. Mutants")
local function silent_run(fn, M)
  local sp, sf = passes, failures
  local pr = print; _G.print = function() end
  local ok, res = pcall(fn, M)
  _G.print = pr
  passes, failures = sp, sf
  return (not ok) or type(res) ~= "number" or res > 0
end
local mutants = {
  { MG_SRC, suite_edge, "bande en vol dans la zone ignorée", "if touches(cur) then return out end", "" },
  { MG_SRC, suite_swap, "cercle ignoré", "if x ~= cur and not skip[x] and touches(x) then", "if x ~= cur and not skip[x] then" },
  { MG_SRC, suite_edge, "règle retirée (coupe absente)", "  if not (od and od.x and od.y and cur ~= nil) then return out end", "  do return out end" },
  { CP_SRC, suite_cp, "départ d'ordre retiré (coupe absente)", "return Cp.ready_order(p.need or {}, p.stock or {}) -- lot MAJA-097", "-- (mutant)" },
  { CP_SRC, suite_cp, "garde du dégel perdue", "and not s.ext and not (s.degel and not p.degele) then", "and not s.ext then" },
}
local killed = 0
for _, mu in ipairs(mutants) do
  local src = mu[1]
  local a, b = src:find(mu[4], 1, true)
  check(a ~= nil, "mutant applicable : " .. mu[3])
  if a then
    local ok, Mm = pcall(function() return assert(load(src:sub(1, a - 1) .. mu[5] .. src:sub(b + 1), "=m"))() end)
    local k = (not ok) or silent_run(mu[2], Mm)
    check(k, "mutant refusé : " .. mu[3])
    if k then killed = killed + 1 end
  end
end
print(string.format("[MAJA-097] mutants %d refuses sur %d", killed, #mutants))
print(string.format("[MAJA-097] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
