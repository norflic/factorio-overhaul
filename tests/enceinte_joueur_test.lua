--[[
  Lot PERIMETRE2 (G3, essai 3) : règles pures de l'enceinte de VOTRE équipe dans shared/team/enceinte.lua (E.cut, E.full_ring_ok,
  E.segment_cap_full). Cause mesurée (partie du DC, lot-dc, 0.6.50) : anneau de 794 murs commencé avec 32 murs au stock, segments de 8,
  76 lots écartés, croissance figée, jamais fini. Le branchement (build.lua, space_step et request_segment) est joué par
  tests/enceinte_flux_test.lua §16. Mutants : chacun doit faire échouer au moins un contrôle.
  Usage : lua5.2 tests/enceinte_joueur_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local SRC = read("shared/team/enceinte.lua")
local function load_e(src) return assert(load(src, "@shared.team.enceinte"))() end

local function suite(E)
  local fails, n = {}, 0
  local function check(c, m) n = n + 1 if not c then fails[#fails + 1] = m end end
  local B = { 0, 0, 100, 60 } -- anneau sur x = 0, x = 100, y = 0, y = 60
  check(not E.cut(B, { x0 = 10, y0 = 10, x1 = 33, y1 = 33 }), "lot dedans : pas coupé")
  check(E.cut(B, { x0 = 90, y0 = 10, x1 = 113, y1 = 33 }), "lot à cheval sur le mur est : coupé")
  check(E.cut(B, { x0 = 10, y0 = -10, x1 = 33, y1 = 13 }), "lot à cheval sur le mur nord : coupé")
  check(E.cut(B, { x0 = 100, y0 = 10, x1 = 123, y1 = 33 }), "lot qui commence SUR le mur : coupé")
  check(not E.cut(B, { x0 = 101, y0 = 10, x1 = 124, y1 = 33 }), "lot tout dehors, collé au mur : pas coupé (utilisable)")
  check(not E.cut(B, { x0 = 200, y0 = 200, x1 = 223, y1 = 223 }), "lot tout dehors : pas coupé")
  check(E.cut(B, { x0 = -5, y0 = -5, x1 = 105, y1 = 65 }), "lot qui entoure tout l'anneau : coupé")
  check(E.full_ring_ok(794, 794) and not E.full_ring_ok(793, 794), "anneau payé en entier seulement (794 sur 794)")
  check(not E.full_ring_ok(32, 794), "partie du DC : 32 murs pour un anneau de 794 : pas commencé")
  check(not E.full_ring_ok(10, 0) and not E.full_ring_ok(nil, nil), "anneau vide ou inconnu : jamais")
  check(E.segment_cap_full(100) == 40 and E.segment_cap_full(25) == 25 and E.segment_cap_full(-3) == 0 and E.segment_cap_full(nil) == 0,
    "segment sur tout le stock, 40 au plus")
  check(E.segment_cap_full(100) > E.segment_cap(100), "plus grand que le quart du stock")
  return fails, n
end

local fails, total = suite(load_e(SRC))
for _, m in ipairs(fails) do print("  ECHEC : " .. m) end
local passes, failures = total - #fails, #fails
local function mutate(old, new)
  local a, b = SRC:find(old, 1, true)
  if not a then return nil end
  return SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1)
end
local mutants = {
  { "lots dehors coupés aussi", "return overlap and not E.inside(bounds, r)", "return not E.inside(bounds, r)" },
  { "chevauchement ouvert (bord exclu)", "local overlap = r.x0 <= bounds[3] and r.x1 >= bounds[1]", "local overlap = r.x0 < bounds[3] and r.x1 > bounds[1]" },
  { "anneau payé en partie", "return (need or 0) > 0 and (equiv or 0) >= need", "return (need or 0) > 0 and (equiv or 0) >= need / 4" },
  { "anneau vide accepté", "return (need or 0) > 0 and (equiv or 0) >= need", "return (equiv or 0) >= (need or 0)" },
  { "segment sans plafond", "return math.min(E.SEG_MAX, math.max(0, math.floor(equiv or 0)))", "return math.max(0, math.floor(equiv or 0))" },
  { "segment au quart", "return math.min(E.SEG_MAX, math.max(0, math.floor(equiv or 0)))", "return E.segment_cap(equiv or 0)" },
}
local killed = 0
for _, m in ipairs(mutants) do
  local txt = mutate(m[2], m[3])
  if not txt then failures = failures + 1 print("  ECHEC : mutant « " .. m[1] .. " » : texte introuvable")
  else
    local ok, f = pcall(function() return (suite(load_e(txt))) end)
    if (not ok) or #f > 0 then killed = killed + 1 passes = passes + 1 else failures = failures + 1 print("  ECHEC : mutant « " .. m[1] .. " » non détecté") end
  end
end
print(string.format("[ENCEINTE-JOUEUR] mutants refusés : %d sur %d", killed, #mutants))
print(string.format("[ENCEINTE-JOUEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
