--[[
  Lot ETAGE4 (4/11) : test hors jeu de shared/team/bail.lua (bail des tournées prises).
    §1 progrès : première lecture, autre étape, autre état, déplacement (cumulé), rien ; §2 bail échu (types à bail seulement, seuil) ;
    §3 tournée vivante (libre récente, prise qui progresse ; absente, oubliée, prise sans progrès : non) ; §4 cas mesuré d'Émeraude (41 min
    sans progrès) rejoué pensée par pensée ; §5 câblage (moniteur, pensée d'équipe, worker, journal) ; §6 mutants ; §7 aucun nom d'objet.
  Usage : lua5.2 tests/bail_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/bail.lua")
local function load_bl(src)
  local fn = load(src, "=bl", "t")
  if not fn then return nil end
  local ok, m = pcall(fn)
  return ok and m or nil
end

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[BAIL] ECHEC : " .. name) end
end

local function suite(Bl)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  -- §1 sans but (règle de l'essai 1)
  local p, s = Bl.progress(nil, { pc = 2, state = "walk", x = 10, y = 5 }, 100)
  c("premiere lecture : progres, 0", s == 0 and p.t == 100 and p.pc == 2 and p.state == "walk")
  local p2, s2 = Bl.progress(p, { pc = 2, state = "walk", x = 10.3, y = 5.2 }, 400)
  c("immobile : pas de progres, temps qui court", s2 == 300 and p2.t == 100)
  local p3, s3 = Bl.progress(p2, { pc = 3, state = "walk", x = 10.3, y = 5.2 }, 700)
  c("autre etape : progres", s3 == 0 and p3.t == 700 and p3.pc == 3)
  local p4, s4 = Bl.progress(p3, { pc = 3, state = "step", x = 10.3, y = 5.2 }, 800)
  c("autre etat : progres", s4 == 0 and p4.t == 800)
  local p5, s5 = Bl.progress(p4, { pc = 3, state = "step", x = 10.3 + Bl.MOVE, y = 5.2 }, 900)
  c("sans but : deplacement d'une tuile = progres", s5 == 0 and p5.t == 900)
  local q = { pc = 1, state = "walk", x = 0, y = 0, t = 0 }
  local q1, t1 = Bl.progress(q, { pc = 1, state = "walk", x = 0.6, y = 0 }, 300)
  local q2, t2 = Bl.progress(q1, { pc = 1, state = "walk", x = 1.2, y = 0 }, 600)
  c("sans but : reptation cumulee = progres", t1 == 300 and t2 == 0 and q2.t == 600)
  local _, t3 = Bl.progress(q, { pc = 1, state = "walk", x = 0, y = Bl.MOVE - 0.01 }, 300)
  c("sans but : juste sous une tuile : pas de progres", t3 == 300)
  -- §1 bis avec but (M1) : seule l'approche plus près que jamais compte
  local g0 = Bl.progress(nil, { pc = 3, state = "walk", x = 0, y = 0, gx = 20, gy = 0 }, 0)
  c("avec but : premiere lecture, meilleure distance 20", math.abs((g0.best or -1) - 20) < 1e-9)
  local g1, u1 = Bl.progress(g0, { pc = 3, state = "walk", x = 5, y = 0, gx = 20, gy = 0 }, 300)
  c("avec but : s'approche de 5 tuiles = progres", u1 == 0 and math.abs(g1.best - 15) < 1e-9 and g1.t == 300)
  local g2, u2 = Bl.progress(g1, { pc = 3, state = "walk", x = 5, y = 12, gx = 20, gy = 0 }, 600)
  c("avec but : bouge de 12 tuiles sans s'approcher = PAS de progres (tourne en rond)", u2 == 300 and g2.t == 300)
  local _, u3 = Bl.progress(g2, { pc = 3, state = "walk", x = 1, y = 0, gx = 20, gy = 0 }, 900)
  c("avec but : revient en arriere (plus loin que le meilleur) = pas de progres", u3 == 600)
  local _, u4 = Bl.progress(g1, { pc = 3, state = "walk", x = 5 + Bl.MOVE - 0.01, y = 0, gx = 20, gy = 0 }, 600)
  c("avec but : approche juste sous une tuile = pas de progres", u4 == 300)
  local _, u4b = Bl.progress(g1, { pc = 3, state = "walk", x = 5 + Bl.MOVE, y = 0, gx = 20, gy = 0 }, 600)
  c("avec but : approche d'exactement une tuile = progres", u4b == 0)
  local g5, u5 = Bl.progress(g2, { pc = 3, state = "walk", x = 5, y = 12, gx = 40, gy = 40 }, 1200)
  c("avec but : autre but (point de passage suivant) = progres", u5 == 0 and g5.t == 1200 and g5.gx == 40)
  local _, u6 = Bl.progress(g1, { pc = 3, state = "walk", x = 5, y = 0, gx = 20 + Bl.GOAL_EPS / 2, gy = 0 }, 600)
  c("avec but : but qui bouge d'un rien = meme but", u6 == 300)
  local _, u7 = Bl.progress(g1, { pc = 3, state = "walk", x = 5, y = 0 }, 600)
  c("but perdu (nil) : regle sans but, immobile = pas de progres", u7 == 300)
  -- §2 bail échu
  c("tournee sans progres depuis le bail : echu", Bl.expired("service", Bl.LEASE) == true)
  c("juste sous le bail : non", Bl.expired("service", Bl.LEASE - 1) == false)
  c("fabrication : jamais", Bl.expired("craft", 1e9, 1e9, true) == false)
  c("garde : jamais", Bl.expired("garrison", 1e9, 1e9, true) == false)
  c("bail de 2 min au plus (une tournee normale marche ou agit)", Bl.LEASE <= 2 * 3600 and Bl.LEASE >= 3600)
  c("avant l'acte : tenue maximale echue meme en progressant", Bl.expired("service", 0, Bl.MAX_HOLD, true) == true)
  c("avant l'acte : juste sous la tenue maximale : non", Bl.expired("service", 0, Bl.MAX_HOLD - 1, true) == false)
  c("apres l'acte (retour, travail fait) : la tenue maximale ne coupe pas", Bl.expired("service", 0, 1e9, false) == false)
  c("apres l'acte : sans progres, le bail coupe quand meme", Bl.expired("service", Bl.LEASE, 0, false) == true)
  c("tenue maximale entre le bail et 5 min", Bl.MAX_HOLD >= Bl.LEASE and Bl.MAX_HOLD <= 5 * 3600)
  -- §3 tournée vivante
  local stale = 5 * 3600
  c("libre recente : vivante", Bl.alive("libre", 10, nil, stale) == true)
  c("libre oubliee : non", Bl.alive("libre", stale, nil, stale) == false)
  c("prise qui progresse : vivante", Bl.alive("prise", nil, 0, stale) == true)
  c("prise sans progres depuis le bail : non", Bl.alive("prise", nil, Bl.LEASE, stale) == false)
  c("prise avant l'acte, tenue trop longue : non", Bl.alive("prise", nil, 0, stale, Bl.MAX_HOLD, true) == false)
  c("prise avant l'acte, tenue courte : vivante", Bl.alive("prise", nil, 0, stale, Bl.MAX_HOLD - 1, true) == true)
  c("prise apres l'acte, longue mais progresse : vivante", Bl.alive("prise", nil, 0, stale, 1e9, false) == true)
  c("absente : non", Bl.alive(nil, nil, nil, stale) == false)
  -- §4 Émeraude (fd-croiss-123456789) : prise à 18,7 min, PNJ immobile près de son but ; une pensée toutes les 300 ticks
  local rec, stall, released = nil, 0, nil
  for tick = 67320, 67320 + 41 * 3600, 300 do
    rec, stall = Bl.progress(rec, { pc = 2, state = "walk", x = -179.4, y = 488.6, gx = -175.5, gy = 488.5 }, tick)
    if Bl.expired("service", stall, tick - 67320, true) then released = tick break end
  end
  c("Emeraude : rendue au bail (2 min apres la prise, et non 41 min)", released ~= nil and released - 67320 <= Bl.LEASE + 300)
  -- Tourne autour de son but sans s'approcher (après l'acte : seule l'approche compte) : rendue au bail
  local rec2, st2, rel2 = nil, 0, nil
  local ring = { { 10, 0 }, { 0, 10 }, { -10, 0 }, { 0, -10 } }
  for k = 0, 60 do
    local tick = k * 300
    local pos = ring[(k % 4) + 1]
    rec2, st2 = Bl.progress(rec2, { pc = 3, state = "walk", x = pos[1], y = pos[2], gx = 0, gy = 0 }, tick)
    if Bl.expired("service", st2, 0, false) then rel2 = tick break end
  end
  c("tourne en rond a 10 tuiles du but : rendue au bail", rel2 ~= nil and rel2 <= Bl.LEASE + 300)
  return res
end

local Bl = assert(load_bl(SRC), "module illisible")
for _, r in ipairs(suite(Bl)) do check(r[1], r[2]) end

-- §5 câblage
local M = read("script/team/bail.lua")
local TM = read("script/team/team.lua")
local W = read("script/team/worker.lua")
check("moniteur : progres et bail purs", M:find("Bl.progress(t.prog,", 1, true) ~= nil and M:find("Bl.expired(t.kind, stall, held, t.pre_act)", 1, true) ~= nil and M:find("gx = g and g.x, gy = g and g.y", 1, true) ~= nil)
check("moniteur : etat decrit AVANT d'etre rendu", (M:find("local desc = describe(agent)", 1, true) or 1e9) < (M:find("Worker.release_stuck(agent, f, tick)", 1, true) or 0))
check("moniteur : PNJ disparu -> tache rendue", M:find('"sans PNJ"', 1, true) ~= nil and M:find("Board.finish(f, t, false, tick)", 1, true) ~= nil)
check("moniteur : listes triees", M:find("State.sorted_keys(b.tasks)", 1, true) ~= nil)
check("moniteur : interrupteur de banc", M:find("f.team.bail_regle ~= false", 1, true) ~= nil)
check("pensee d'equipe : bail juste apres la synchronisation", (TM:find("Board.sync(f, plan.tasks", 1, true) or 1e9) < (TM:find("Bail.think(f, tick)", 1, true) or 0)
  and (TM:find("Bail.think(f, tick)", 1, true) or 1e9) < (TM:find("Board.assign(f, tick)", 1, true) or 0))
check("worker : abandon puis degagement", W:find("function Worker.release_stuck", 1, true) ~= nil and W:find('abort(agent, f, tick, "bail")', 1, true) ~= nil
  and W:find("task.bailed = true", 1, true) ~= nil and W:find("finish(agent, f, false, tick)", 1, true) ~= nil)
check("journal [FO-BAIL]", M:find("[FO-BAIL]", 1, true) ~= nil)
check("moniteur : avant l'acte = une etape act a venir", M:find('if steps[i][1] == "act" then return true end', 1, true) ~= nil)
check("moniteur (M2) : le PNJ ne tient plus la tache avant Board.finish",
  (M:find("if agent and agent.task == t then agent.task, agent.steps, agent.pc = nil, nil, nil end", 1, true) or 1e9)
  < (M:find("Board.finish(f, t, false, tick)", 1, true) or 0))

-- §6 mutants
local MUTANTS = {
  { "etape ignoree", "if not prev or prev.pc ~= cur.pc or prev.state ~= cur.state then", "if not prev or prev.state ~= cur.state then" },
  { "etat ignore", "if not prev or prev.pc ~= cur.pc or prev.state ~= cur.state then", "if not prev or prev.pc ~= cur.pc then" },
  { "sans but : deplacement ignore", "if dx * dx + dy * dy >= Bl.MOVE * Bl.MOVE then return fresh(cur, tick) end", "" },
  { "but : tout deplacement compte (essai 1)", "if d <= num(prev.best) - Bl.MOVE then", "if true then" },
  { "but : nouveau but ignore", "if prev.gx == nil or math.abs(num(prev.gx) - num(cur.gx)) + math.abs(num(prev.gy) - num(cur.gy)) > Bl.GOAL_EPS then", "if prev.gx == nil then" },
  { "but : meilleure distance oubliee", "best = d, t = tick }, 0", "best = num(prev.best), t = tick }, 0" },
  { "but : approche stricte", "if d <= num(prev.best) - Bl.MOVE then", "if d < num(prev.best) - Bl.MOVE then" },
  { "temps sans progres remis a zero", "    return prev, tick - num(prev.t)\n  end\n  local dx", "    return prev, 0\n  end\n  local dx" },
  { "bail sur tous les types", "if Bl.KINDS[kind] ~= true then return false end", "" },
  { "bail strict", "if num(stall) >= Bl.LEASE then return true end", "if num(stall) > Bl.LEASE then return true end" },
  { "tenue maximale ignoree", "return pre_act == true and num(held) >= Bl.MAX_HOLD", "return false" },
  { "tenue maximale apres l'acte aussi (essai 2)", "return pre_act == true and num(held) >= Bl.MAX_HOLD", "return num(held) >= Bl.MAX_HOLD" },
  { "bail de 41 min", "Bl.LEASE = 2 * 3600", "Bl.LEASE = 41 * 3600" },
  { "prise toujours vivante (avant ETAGE4)", "if state == \"prise\" then return not Bl.expired(\"service\", stall, held, pre_act) end", "if state == \"prise\" then return true end" },
  { "libre jamais oubliee", "if state == \"libre\" then return num(free_age) < num(stale) end", "if state == \"libre\" then return true end" },
  { "absente vivante", "  return false\nend\n\nreturn Bl", "  return true\nend\n\nreturn Bl" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local mut = load_bl(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local seen = mut == nil
    if not seen then
      local ok, res = pcall(suite, mut)
      if not ok then seen = true else
        for _, r in ipairs(res) do if not r[2] then seen = true break end end
      end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUTANTS, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUTANTS)

-- §7 aucun nom d'objet du jeu dans le module
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
local found = {}
for _, n in ipairs({ "coal", "stone", "iron", "copper", "chest", "furnace", "drill", "plate", "ore" }) do
  if code:find('"' .. n, 1, true) or code:find(n .. '"', 1, true) then found[#found + 1] = n end
end
check("aucun nom d'objet dans le module" .. (#found > 0 and (" : " .. table.concat(found, ",")) or ""), #found == 0)

print(string.format("[BAIL] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
