--[[
  Lot DEBUG-BLOCS : banc HORS JEU de la règle pure des LIGNES enregistrées (shared/debug/liens.lua). Lancement, depuis la racine du mod :
    lua5.2 tests/debug_liens_test.lua
  Sections :
     1. genres : liaison de quai, tronc de bus, branche de piquage, rapatriement ; un bloc n'est pas une ligne ;
     2. extrémités : tuiles -> centres (+0,5), répartiteur déjà centré, tampon de rapatriement (planifié, réutilisé, point voulu) ;
     3. états : actif, chantier, coupé (a été fini), refusé (cause = p.reason), piquage attente / inerte / coupé avec sa cause ;
     4. refus : le plus récent par extrémité, masqué par une ligne plus récente, plafond par genre ;
     5. tampons : un par coffre d'arrivée, genres et sources, refusés exclus ;
     6. flèches : pointe à l'arrivée, au milieu au-delà de Li.MID, aucune pour une ligne nulle ; couleurs et pointillés ;
     7. coût en INSTRUCTIONS (debug.sethook) de 400 projets dont 200 lignes ;
     8. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Aucun nom du jeu : les objets sont des chaînes opaques.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end

local PATH = "shared/debug/liens.lua"
local function load_mod(mutate)
  local src = slurp(PATH)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then error("texte de mutant introuvable : " .. mutate[1]) end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. PATH)
  if not fn then error(err) end
  return fn()
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

-- projets de référence (copies de f.build : nombres et chaînes)
local function quai(pid, state, extra)
  local p = { pid = pid, state = state, spec = { liaison = { key = "3:q1", item = "objet-a", src = { pid = 7, idx = 1, x = 10, y = 20 }, dock = { pid = 3, idx = 1, x = 30, y = 20 } } } }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end

local function run_all(Li)
  section("1. genres")
  check(Li.kind({ liaison = { key = "k" } }) == "quai", "liaison de quai")
  check(Li.kind({ liaison = { key = "k", bus = true } }) == "bus", "tronc de bus")
  check(Li.kind({ liaison = { key = "k", piquage = true, bus = true } }) == "piquage", "piquage d'abord")
  check(Li.kind({ rapatriement = { key = "k" } }) == "rapatriement", "rapatriement")
  check(Li.kind({ gen = "x" }) == nil and Li.kind(nil) == nil, "un bloc n'est pas une ligne")

  section("2. extrémités")
  local L = Li.lines({ quai(40, "fini") })
  check(#L == 1, "une ligne")
  local l = L[1]
  check(l and near(l.from.x, 10.5) and near(l.from.y, 20.5), "départ = centre du coffre de sortie (10,5 ; 20,5)")
  check(l and near(l.to.x, 30.5) and near(l.to.y, 20.5), "arrivée = centre du coffre d'entrée (30,5 ; 20,5)")
  check(l and l.src_pid == 7 and l.dock_pid == 3 and l.item == "objet-a" and l.key == "3:q1", "bloc source, bloc d'arrivée, objet, clé")
  local pq = { pid = 41, state = "fini", spec = { liaison = { piquage = true, key = "5:q2", item = "objet-b", geo = { x = 12, y = 8.5 }, dock = { pid = 5, idx = 2, x = 15, y = 4 } } } }
  local L2 = Li.lines({ pq }, { piquage = { links = { ["5:q2"] = { split = true } }, quais = { ["5:q2"] = { verdict = "actif", cause = "livre" } } } })
  check(#L2 == 1 and near(L2[1].from.x, 12) and near(L2[1].from.y, 8.5), "piquage : départ au répartiteur, déjà centré")
  check(#L2 == 1 and near(L2[1].to.x, 15.5) and L2[1].src_pid == nil and L2[1].dock_pid == 5, "piquage : arrivée au quai, aucun bloc source (un tapis)")
  local rp = { key = "9:o1", item = "objet-c", src = { pid = 9, idx = 1, x = -40, y = 100 }, point = { x = 2, y = 3 } }
  local r1 = Li.lines({ { pid = 50, state = "chantier", spec = { rapatriement = rp } } })
  check(#r1 == 1 and near(r1[1].from.x, -39.5) and near(r1[1].from.y, 100.5), "rapatriement : départ à la sortie lointaine")
  check(#r1 == 1 and near(r1[1].to.x, 2.5) and near(r1[1].to.y, 3.5), "rapatriement non planifié : le point voulu")
  local r2 = Li.lines({ { pid = 50, state = "fini", spec = { rapatriement = rp }, rap = { tampon_x = 4, tampon_y = 6 } } },
    { rapatriement = { lines = { ["9:o1"] = { pid = 50, arrived = 321 } } } })
  check(#r2 == 1 and near(r2[1].to.x, 4.5) and near(r2[1].to.y, 6.5), "rapatriement planifié : le vrai coffre tampon (p.rap)")
  check(#r2 == 1 and r2[1].arrived == 321 and r2[1].src_pid == 9 and r2[1].dock_pid == nil, "objets arrivés au tampon, bloc source")
  local rp3 = { key = "9:o2", item = "objet-c", src = { pid = 9, idx = 2, x = -40, y = 101 }, point = { x = 2, y = 3 }, reuse = { x = 8, y = 9 } }
  local r3 = Li.lines({ { pid = 51, state = "plan", spec = { rapatriement = rp3 } } })
  check(#r3 == 1 and near(r3[1].to.x, 8.5) and near(r3[1].to.y, 9.5), "rapatriement vers un tampon réutilisé")
  local r4 = Li.lines({ { pid = 52, state = "fini", spec = { rapatriement = rp }, rap = { tampon_x = 4, tampon_y = 6 } } },
    { rapatriement = { lines = { ["9:o1"] = { pid = 50, arrived = 321 } } } })
  check(#r4 == 1 and r4[1].arrived == nil, "compte d'arrivée d'une AUTRE ligne (autre projet) jamais attribué")
  check(#Li.lines({ { pid = 60, state = "fini", spec = { liaison = { key = "z", dock = { x = 1, y = 1 } } } } }) == 0, "ligne sans départ lisible écartée")

  section("3. états")
  check(Li.lines({ quai(40, "fini") })[1].status == "actif", "fini : actif")
  for _, s in ipairs({ "attente", "plan", "reserve", "defrichage", "fantomes", "chantier" }) do
    check(Li.lines({ quai(40, s) })[1].status == "chantier", "jamais fini, « " .. s .. " » : chantier")
  end
  local cut = Li.lines({ quai(40, "chantier", { finished = 1200 }) })[1]
  check(cut.status == "coupe" and cut.cause and cut.cause.kind == "etat" and cut.cause.code == "chantier", "a été fini puis rouvert : coupée, cause = état du projet")
  local ref = Li.lines({ quai(40, "refuse", { reason = "liaison: aucun chemin" }) })[1]
  check(ref.status == "refuse" and ref.cause and ref.cause.kind == "texte" and ref.cause.text == "liaison: aucun chemin", "refusée : cause = p.reason")
  local ab = Li.lines({ quai(40, "fini", { abandoned = true }) })[1]
  check(ab.status == "refuse", "abandonnée : comme refusée")
  check(Li.lines({ quai(40, "refuse") })[1].cause == nil, "refusée sans raison : aucune cause inventée")
  local function pqs(link, q) return Li.lines({ pq }, { piquage = { links = { ["5:q2"] = link }, quais = { ["5:q2"] = q } } })[1] end
  local a = pqs({ split = false }, { verdict = "attente", cause = "repartiteur_a_fabriquer" })
  check(a.status == "attente" and a.cause and a.cause.kind == "piquage" and a.cause.code == "repartiteur_a_fabriquer", "piquage fini sans répartiteur : attente, cause du relevé")
  local i = pqs({ split = true }, { verdict = "inerte", cause = "ne_livre_pas" })
  check(i.status == "inerte" and i.cause.code == "ne_livre_pas", "piquage posé qui ne livre pas : inerte")
  local c = pqs({ split = true, cut = true }, { verdict = "coupe", cause = "remplacement_refuse" })
  check(c.status == "coupe" and c.cause.code == "remplacement_refuse", "piquage coupé : sa cause")
  check(pqs({ split = true }, { verdict = "actif", cause = "livre" }).status == "actif", "piquage actif")
  check(pqs(nil, nil).status == "attente", "piquage fini sans suivi : attente (jamais « actif » inventé)")

  section("4. refus")
  local list = {}
  for k = 1, 3 do list[#list + 1] = quai(40 + k, "refuse", { reason = "r" .. k }) end
  local R = Li.lines(list)
  check(#R == 1 and R[1].pid == 43 and R[1].cause.text == "r3", "trois refus au même quai : le plus récent seul (" .. #R .. ")")
  list[#list + 1] = quai(44, "chantier")
  R = Li.lines(list)
  check(#R == 1 and R[1].pid == 44 and R[1].status == "chantier", "redemandée : le refus ancien disparaît")
  local older_live = { quai(40, "fini"), quai(45, "refuse", { reason = "x" }) }
  R = Li.lines(older_live)
  check(#R == 2, "un refus PLUS RÉCENT qu'une ligne vivante au même quai reste visible")
  local many = {}
  for k = 1, Li.REFUSED_MAX + 3 do
    many[#many + 1] = { pid = 100 + k, state = "refuse", reason = "r", spec = { liaison = { key = "q" .. k, src = { x = k, y = 0 }, dock = { x = k, y = 5 } } } }
  end
  many[#many + 1] = { pid = 200, state = "refuse", reason = "r", spec = { liaison = { key = "b1", bus = true, src = { x = 0, y = 0 }, dock = { x = 9, y = 9 } } } }
  R = Li.lines(many)
  local nq, nb, minpid = 0, 0, math.huge
  for _, x in ipairs(R) do
    if x.kind == "quai" then nq = nq + 1; minpid = math.min(minpid, x.pid) end
    if x.kind == "bus" then nb = nb + 1 end
  end
  check(nq == Li.REFUSED_MAX and minpid == 100 + 4, "plafond des refus par genre : les " .. Li.REFUSED_MAX .. " plus récents (" .. nq .. ", premier " .. minpid .. ")")
  check(nb == 1, "le plafond est par genre : le tronc refusé reste")
  local sorted = true
  for k = 2, #R do if R[k - 1].pid >= R[k].pid then sorted = false end end
  check(sorted, "lignes triées par numéro de projet")

  section("5. tampons")
  local two = { quai(40, "fini"), { pid = 46, state = "fini", spec = { liaison = { key = "3:q1", item = "objet-a", src = { pid = 8, x = 0, y = 0 }, dock = { pid = 3, x = 30, y = 20 } } } },
    { pid = 50, state = "fini", spec = { rapatriement = rp }, rap = { tampon_x = 4, tampon_y = 6 } }, pq, quai(70, "refuse", { reason = "x", spec = { liaison = { key = "z", src = { x = 1, y = 1 }, dock = { x = 90, y = 90 } } } }) }
  local B = Li.buffers(Li.lines(two, { piquage = { links = { ["5:q2"] = { split = true } } } }))
  check(#B == 3, "trois coffres d'arrivée (deux lignes au même quai, refusée exclue) : " .. #B)
  local q30
  for _, b in ipairs(B) do if near(b.x, 30.5) then q30 = b end end
  check(q30 and #q30.sources == 2 and q30.sources[1] == 7 and q30.sources[2] == 8 and #q30.pids == 2, "deux sources triées au même tampon")
  local t4, t15
  for _, b in ipairs(B) do if near(b.x, 4.5) then t4 = b end if near(b.x, 15.5) then t15 = b end end
  check(t4 and t4.kinds[1] == "rapatriement" and t4.sources[1] == 9, "tampon de rapatriement : genre et source")
  check(t15 and t15.tapis == true and #t15.sources == 0, "coffre d'un piquage : source = un tapis")
  check(B[1].x <= B[2].x and B[2].x <= B[3].x, "tampons triés par position")

  section("6. flèches, couleurs, pointillés")
  local h = Li.arrow_head({ x = 0, y = 0 }, { x = 10, y = 0 })
  check(#h == 2 and near(h[1][3], 10) and near(h[2][3], 10) and h[1][1] < 10 and h[2][1] < 10, "pointe À L'ARRIVÉE, tournée vers elle")
  check(near(h[1][2], -h[2][2]) and math.abs(h[1][2]) > 0.1, "pointe symétrique")
  check(#Li.arrow_head({ x = 1, y = 1 }, { x = 1, y = 1 }) == 0, "ligne nulle : pas de pointe")
  local short = Li.arrow_head({ x = 0, y = 0 }, { x = 0.3, y = 0 })
  check(#short == 2 and short[1][1] >= -1e-9, "pointe bornée à la longueur de la ligne")
  check(#Li.arrows({ x = 0, y = 0 }, { x = 10, y = 0 }) == 2, "ligne courte : une pointe")
  local long = Li.arrows({ x = 0, y = 0 }, { x = 40, y = 0 })
  check(#long == 4 and near(long[3][3], 20), "ligne longue : une pointe de plus au milieu")
  check(Li.color({ status = "refuse", kind = "quai" }) == "rouge" and Li.color({ status = "coupe", kind = "bus" }) == "rouge", "cassée ou refusée : rouge")
  check(Li.color({ status = "inerte", kind = "piquage" }) == "orange" and Li.color({ status = "attente", kind = "piquage" }) == "orange", "attente, inerte : orange")
  check(Li.color({ status = "actif", kind = "bus" }) == "bus" and Li.color({ status = "chantier", kind = "quai" }) == "quai", "sinon la couleur du genre")
  check(Li.dashed({ status = "chantier" }) and Li.dashed({ status = "attente" }) and not Li.dashed({ status = "actif" }) and not Li.dashed({ status = "refuse" }),
    "pointillé = la ligne n'existe pas encore en entier")
end

run_all(load_mod())

section("7. coût en instructions")
do
  local Li = load_mod()
  local projects, n = {}, 0
  for k = 1, 400 do
    if k % 2 == 0 then
      local st = ({ "fini", "chantier", "refuse", "fini" })[k % 4 + 1]
      projects[#projects + 1] = quai(k, st, { reason = "r", finished = (k % 3 == 0) and 10 or nil,
        spec = { liaison = { key = "q" .. (k % 50), item = "o", bus = k % 8 == 0, src = { pid = 1, x = k, y = 0 }, dock = { pid = 2, x = 0, y = k } } } })
      n = n + 1
    else
      projects[#projects + 1] = { pid = k, state = "fini", spec = { gen = "x" } }
    end
  end
  local count = 0
  debug.sethook(function() count = count + 1000 end, "", 1000)
  local L = Li.lines(projects, {})
  local B = Li.buffers(L)
  for _, l in ipairs(L) do Li.arrows(l.from, l.to) end
  debug.sethook()
  check(count <= 400000, "400 projets dont " .. n .. " lignes : " .. count .. " instructions (<= 400 000)")
  print(string.format("  400 projets, %d lignes, %d gardées, %d tampons : environ %d instructions", n, #L, #B, count))
end

section("8. mutants")
local MUTANTS = {
  { "centre +0,5 retiré", { "return { x = math.floor(t.x) + 0.5, y = math.floor(t.y) + 0.5 }", "return { x = t.x, y = t.y }" } },
  { "piquage pris pour un bus", { "if lc.piquage then return \"piquage\" end", "" } },
  { "rapatriement ignoré", { "if type(spec.rapatriement) == \"table\" then return \"rapatriement\" end", "" } },
  { "refus sans cause", { "return \"refuse\", (r ~= nil and r ~= \"\") and { kind = \"texte\", text = tostring(r) } or nil", "return \"refuse\", nil" } },
  { "coupée prise pour chantier", { "if p.finished ~= nil then return \"coupe\", { kind = \"etat\", code = tostring(s) } end", "" } },
  { "abandon ignoré", { "if s == \"refuse\" or p.abandoned then", "if s == \"refuse\" then" } },
  { "piquage coupé ignoré", { "if link and link.cut then return \"coupe\", { kind = \"piquage\", code = code or \"remplacement_refuse\" } end", "" } },
  { "piquage sans répartiteur dit actif", { "if not (link and link.split) then return \"attente\", code and code ~= \"ok\" and { kind = \"piquage\", code = code } or nil end", "" } },
  { "piquage inerte ignoré", { "if q and q.verdict == \"inerte\" then return \"inerte\", { kind = \"piquage\", code = code or \"ne_livre_pas\" } end", "" } },
  { "tampon planifié ignoré", { "to = Li.center({ x = rap.tampon_x, y = rap.tampon_y })", "to = nil" } },
  { "tampon réutilisé ignoré", { "to = to or Li.center(rp.reuse) or Li.center(rp.point)", "to = to or Li.center(rp.point)" } },
  { "tous les refus gardés", { "if l.status ~= \"refuse\" or keep_ref[l.pid] then", "if true then" } },
  { "refus masqué jamais", { "and (live_after[l.ek] or 0) < l.pid then", "then" } },
  { "plafond des refus retiré", { "if per_kind[l.kind] <= Li.REFUSED_MAX then keep_ref[l.pid] = true end", "keep_ref[l.pid] = true" } },
  { "plafond global au lieu de par genre", { "per_kind[l.kind] = (per_kind[l.kind] or 0) + 1", "per_kind[l.kind] = (per_kind.tous or 0) + 1; per_kind.tous = per_kind[l.kind]" } },
  { "tampons : refusés gardés", { "if l.status ~= \"refuse\" then\n      local k = string.format", "if true then\n      local k = string.format" } },
  { "pointe au départ", { "local bx, by = to.x - ux * len, to.y - uy * len", "local bx, by = to.x + ux * len, to.y + uy * len" } },
  { "pas de flèche au milieu", { "if dx * dx + dy * dy > Li.MID * Li.MID then", "if false then" } },
  { "refusée pas en rouge", { "if Li.BROKEN[l.status] then return \"rouge\" end", "" } },
  { "chantier en trait plein", { "function Li.dashed(l) return l.status == \"chantier\" or l.status == \"attente\" end", "function Li.dashed(l) return l.status == \"attente\" end" } },
  { "arrivée d'une autre ligne attribuée", { "arrived = rl and rl.pid == p.pid and num(rl.arrived) or nil", "arrived = rl and num(rl.arrived) or nil" } },
}
local killed = 0
for _, m in ipairs(MUTANTS) do
  local p0, f0 = passes, failures
  quiet = true
  local ok, Lm = pcall(load_mod, m[2])
  local died = not ok
  if ok then
    local ok2 = pcall(run_all, Lm)
    died = (not ok2) or failures > f0
  end
  quiet = false
  passes, failures = p0, f0
  if died then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
end
failures = failures + (#MUTANTS - killed)
print(string.format("[DEBUG-LIENS] mutants : %d/%d refuses", killed, #MUTANTS))

print(string.format("[DEBUG-LIENS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
