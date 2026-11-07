--[[
  Lot FOREUSES-THERMIQUES : RÉCEPTEUR d'une foreuse sans drop_target. Banc foreuses-dense en moteur réel (7/11, a7a29c11) : 0 remplacement
  sur 328 thermiques ; journal de diagnostic : 20 entrées seulement au relevé, 0 aux premières passes. Depuis B2 (75b584d5), le relevé et
  l'échange ne lisaient plus que drop_target, qui reste nil pour une foreuse posée AVANT son récepteur (Outposts.extend) tant qu'elle n'a
  rien déposé (déduit). Correctif : drop_target s'il est connu, sinon le point de dépôt des DONNÉES dans les réceptacles de l'avant-poste
  (la règle de bbc015f6), par un index des tuiles (coût O(réceptacles) + O(1) par foreuse, celui de B2).

  PREUVE : sur le monde factice (tests/foreuse_monde.lua : 16 paires serrées avec échanges, 3 paires loin), le monde où AUCUNE foreuse n'a
  de drop_target décide EXACTEMENT comme celui où chaque drop_target est connu (global, monde, fils, journal), en passe d'un bloc et en
  tranches. Mutants : chaque lecture de repli retirée.

  Usage, depuis la racine du mod :   lua5.2 tests/foreuse_recepteur_test.lua
]]
package.path = "./?.lua;" .. package.path
local Monde = require("tests.foreuse_monde")

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[FOREUSE-RECEPTEUR] ECHEC : " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "")) end
end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local SRC = read("script/team/foreuse_swap.lua")

local PASSES = 6
local function no_target(W) W.no_targets = true return Monde.build_fer(W) end

local function suite(text)
  local res = {}
  local function c(name, cond, detail) res[#res + 1] = { name, cond and true or false, detail } end
  for _, mode in ipairs({ { false, nil, "bloc" }, { true, 40, "tranches de 40" } }) do
    local okA, A = pcall(Monde.fresh, text, mode[1], mode[2], Monde.build_fer)
    local okB, B = pcall(Monde.fresh, text, mode[1], mode[2], no_target)
    if not (okA and okB) then c(mode[3] .. " : module charge", false, tostring(A) .. " / " .. tostring(B)) return res end
    local okp1, e1 = pcall(Monde.play, A, PASSES)
    local okp2, e2 = pcall(Monde.play, B, PASSES)
    if not (okp1 and okp2) then c(mode[3] .. " : passes jouees", false, tostring(e1) .. " / " .. tostring(e2)) return res end
    local same, where = Monde.compare(Monde.snapshot(A), Monde.snapshot(B))
    c(mode[3] .. " : sans drop_target = avec drop_target (global, monde, fils, journal) sur " .. PASSES .. " passes", same, where)
    local st = B.f.swap or {}
    c(mode[3] .. " : sans drop_target, des electriques posees et des echanges (le cas n'est pas vide)", (st.done or 0) >= 3 and (st.exchanged or 0) >= 1,
      string.format("faites %s, echanges %s", tostring(st.done), tostring(st.exchanged)))
  end
  return res
end

local function run(text)
  local okr, res = pcall(suite, text)
  if not okr then return { { "suite : " .. tostring(res), false } } end
  return res
end
for _, r in ipairs(run(SRC)) do check(r[1], r[2], r[3]) end

local MUT = {
  { "releve sans repli (drop_target seul)", "            local t = receiver_of(d, sink_at)", "            local t = d.drop_target" },
  { "echange sans repli (paires lues par drop_target seul)", "      local tgt = receiver_of(d, l.at)", "      local tgt = d.drop_target" },
  { "repli sur un mauvais point de depot", "  local v = d.name == T.DRILL and T.drill_drop or T.drill_electric.drop", "  local v = T.drill_electric.drop" },
  { "four nourri par une electrique sans drop_target (B1) non reconnu", "        if S.inside(box_of(k), px, py) then return true end", "        if false then return true end" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local a, z = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local seen
    for _, r in ipairs(run(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(z + 1))) do if not r[2] then seen = r[1] break end end
    if seen then
      refused = refused + 1
      print(string.format("[FOREUSE-RECEPTEUR] mutant « %s » refuse par : %s", m[1], seen))
    else
      kept[#kept + 1] = m[1]
    end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUT, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUT)
print(string.format("[FOREUSE-RECEPTEUR] mutants refuses %d/%d", refused, #MUT))
print(string.format("[FOREUSE-RECEPTEUR] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
