--[[
  Lot BALISES-TEINTE (décision du DC, 10/11) : couleur des balises d'après les familles de leurs modules.
    §1 shared/content/modules_teintes.lua : couleurs du DC (hex du lot ART-MODULES), famille lue à la table `effect` (la plus
       forte composante UTILE décide ; égalité → ordre fixe ; consommation positive = malus, pas une famille), teinte d'une
       balise (une famille → sa couleur ; mélange → moyenne pondérée ; vide → couleur d'âge inchangée), comptes, égalité ;
    §2 mutants : chacun refusé par les MÊMES détecteurs (famille au max sans signe, égalité renversée, moyenne non pondérée,
       vide → noir) ;
    §3 câblage textuel : prototypes/modules.lua (table partagée, couche lumineuse `secondary`), script/team/hygiene.lua (require,
       appel à chaque tranche), script/team/balises_teinte.lua (type du moteur, prototype, pas de `global`, journal).
  Usage : lua5.2 tests/modules_teintes_test.lua   (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function section(name) print("== " .. name) end
local function near(a, b) return math.abs(a - b) < 1e-3 end
local function same(c, r, g, b) return c ~= nil and near(c.r, r) and near(c.g, g) and near(c.b, b) end

local Mt = require("shared.content.modules_teintes")

---------------------------------------------------------------------------------------------------
-- Détecteurs partagés par §1 et §2.
---------------------------------------------------------------------------------------------------
local E = function(s, p, c) return { speed = { bonus = s }, productivity = { bonus = p }, consumption = { bonus = c } } end
local FAM_CASES = {
  { e = E(0.20, nil, 0.12), want = "speed", why = "vitesse palier 1 (énergie +12 % = malus)" },
  { e = E(1.10, nil, 0.66), want = "speed", why = "vitesse palier 10" },
  { e = E(-0.025, 0.10, 0.06), want = "productivity", why = "productivité palier 1 (malus de vitesse ignoré)" },
  { e = E(-0.075, 0.55, 0.33), want = "productivity", why = "productivité palier 10" },
  { e = E(nil, nil, -0.30), want = "consumption", why = "efficacité : seule la consommation NÉGATIVE compte" },
  { e = E(0.10, 0.10, nil), want = "speed", why = "égalité vitesse = productivité : ordre fixe, vitesse" },
  { e = E(nil, 0.10, -0.10), want = "productivity", why = "égalité productivité = efficacité : ordre fixe, productivité" },
  { e = E(0.05, nil, -0.50), want = "consumption", why = "la plus forte composante utile décide, pas l'ordre" },
  { e = E(nil, nil, 0.50), want = nil, why = "seulement un malus d'énergie : aucune famille" },
  { e = {}, want = nil, why = "table vide : aucune famille" },
  { e = nil, want = nil, why = "nil : aucune famille" },
  { e = { speed = 0.3 }, want = "speed", why = "bonus donné nu (nombre) accepté" },
}
local function run_fam(famille)
  local bad = {}
  for i, c in ipairs(FAM_CASES) do
    local got = famille(c.e)
    if got ~= c.want then bad[#bad + 1] = string.format("cas %d (%s) : %s au lieu de %s", i, c.why, tostring(got), tostring(c.want)) end
  end
  return bad
end

local AGE = { r = 0.2, g = 0.2, b = 0.5 }
local TEINTE_CASES = {
  { f = { "speed" }, want = { 0.000, 0.898, 1.000 }, why = "une balise de vitesse : cyan #00E5FF" },
  { f = { "productivity", "productivity" }, want = { 1.000, 0.620, 0.106 }, why = "deux de productivité : ambre #FF9E1B" },
  { f = { "consumption" }, want = { 0.122, 0.910, 0.541 }, why = "efficacité : émeraude #1FE88A" },
  { f = { "speed", "productivity" }, want = { 0.500, 0.759, 0.553 }, why = "mélange 1/1 : moyenne" },
  { f = { "speed", "speed", "speed", "productivity" }, want = { 0.250, 0.8285, 0.7765 }, why = "mélange 3/1 : moyenne PONDÉRÉE" },
  { f = { "speed", "pollution", "speed" }, want = { 0.000, 0.898, 1.000 }, why = "entrée hors familles ignorée" },
  { f = {}, want = "age", why = "vide : couleur d'âge inchangée" },
  { f = nil, want = "age", why = "nil : couleur d'âge inchangée" },
}
local function run_teinte(teinte)
  local bad = {}
  for i, c in ipairs(TEINTE_CASES) do
    local got = teinte(c.f, AGE)
    local ok
    if c.want == "age" then ok = (got == AGE) else ok = same(got, c.want[1], c.want[2], c.want[3]) end
    if not ok then bad[#bad + 1] = string.format("cas %d (%s)", i, c.why) end
  end
  return bad
end

---------------------------------------------------------------------------------------------------
section("§1 règle")
---------------------------------------------------------------------------------------------------
check(same(Mt.couleur("speed"), 0, 229 / 255, 1), "couleur vitesse = #00E5FF")
check(same(Mt.couleur("productivity"), 1, 158 / 255, 27 / 255), "couleur productivité = #FF9E1B")
check(same(Mt.couleur("consumption"), 31 / 255, 232 / 255, 138 / 255), "couleur efficacité = #1FE88A")
check(same(Mt.couleur("effectivity"), 31 / 255, 232 / 255, 138 / 255), "alias effectivity (M.ORDER) → consumption")
check(Mt.couleur("pollution") == nil, "famille inconnue → nil")
local c1 = Mt.couleur("speed"); c1.r = 9
check(Mt.COULEURS.speed.r == 0, "Mt.couleur rend une copie (la table partagée n'est pas touchée)")
check(#Mt.FAMILLES == 3 and Mt.FAMILLES[1] == "speed" and Mt.FAMILLES[2] == "productivity" and Mt.FAMILLES[3] == "consumption",
  "ordre fixe des familles : vitesse, productivité, efficacité")
local bad = run_fam(Mt.famille)
check(#bad == 0, "Mt.famille : " .. table.concat(bad, " ; "))
bad = run_teinte(Mt.teinte)
check(#bad == 0, "Mt.teinte : " .. table.concat(bad, " ; "))
local n = Mt.compte({ "speed", "speed", "consumption", nil, "pollution" })
check(n.speed == 2 and n.productivity == 0 and n.consumption == 1 and n.total == 3 and n.familles == 2, "Mt.compte : comptes, total, familles")
check(Mt.meme({ r = 0.5, g = 0.5, b = 0.5 }, { r = 0.5 + 1 / 1000, g = 0.5, b = 0.5 }), "Mt.meme : bruit sous 1/255 = même couleur")
check(not Mt.meme({ r = 0.5, g = 0.5, b = 0.5 }, { r = 0.5 + 2 / 255, g = 0.5, b = 0.5 }), "Mt.meme : écart de 2/255 = couleur changée")
check(Mt.meme(nil, nil) and not Mt.meme(nil, AGE), "Mt.meme : nil")
-- Déterminisme : mêmes modules dans un autre ordre → même couleur.
local a = Mt.teinte({ "speed", "productivity", "consumption", "speed" })
local b = Mt.teinte({ "consumption", "speed", "speed", "productivity" })
check(same(a, b.r, b.g, b.b), "déterminisme : l'ordre des modules ne change pas la couleur")

---------------------------------------------------------------------------------------------------
section("§2 mutants")
---------------------------------------------------------------------------------------------------
-- Mutant 1 : la plus forte composante en VALEUR ABSOLUE (une consommation positive ferait un module d'efficacité).
local function m_sans_signe(effect)
  if type(effect) ~= "table" then return nil end
  local best, bg = nil, 0
  for _, fam in ipairs(Mt.FAMILLES) do
    local e = effect[fam]; local v = type(e) == "table" and e.bonus or e
    if type(v) == "number" and math.abs(v) > bg then best, bg = fam, math.abs(v) end
  end
  return best
end
-- Mutant 2 : égalité tranchée par le DERNIER (>=).
local function m_egalite_renversee(effect)
  if type(effect) ~= "table" then return nil end
  local best, bg = nil, 0
  for _, fam in ipairs(Mt.FAMILLES) do
    local e = effect[fam]; local v = type(e) == "table" and e.bonus or e
    if type(v) == "number" then
      local g = (fam == "consumption") and math.max(-v, 0) or math.max(v, 0)
      if g > 0 and g >= bg then best, bg = fam, g end
    end
  end
  return best
end
-- Mutant 3 : moyenne des familles PRÉSENTES (non pondérée par le nombre de modules).
local function m_non_ponderee(familles, defaut)
  local n = Mt.compte(familles)
  if n.total == 0 then return defaut end
  local r, g, b = 0, 0, 0
  for _, fam in ipairs(Mt.FAMILLES) do
    if n[fam] > 0 then local c = Mt.COULEURS[fam]; r, g, b = r + c.r, g + c.g, b + c.b end
  end
  return { r = r / n.familles, g = g / n.familles, b = b / n.familles }
end
-- Mutant 4 : balise vide → noir au lieu de la couleur d'âge.
local function m_vide_noir(familles, defaut)
  local n = Mt.compte(familles)
  if n.total == 0 then return { r = 0, g = 0, b = 0 } end
  return Mt.teinte(familles, defaut)
end
check(#run_fam(m_sans_signe) > 0, "mutant « famille au max sans signe » refusé")
check(#run_fam(m_egalite_renversee) > 0, "mutant « égalité renversée » refusé")
check(#run_teinte(m_non_ponderee) > 0, "mutant « moyenne non pondérée » refusé")
check(#run_teinte(m_vide_noir) > 0, "mutant « vide → noir » refusé")

---------------------------------------------------------------------------------------------------
section("§3 câblage textuel")
---------------------------------------------------------------------------------------------------
local function read(path) local f = io.open(path, "rb"); if not f then return nil end; local s = f:read("*a"); f:close(); return s end
local function has(src, pat) return src ~= nil and src:find(pat, 1, true) ~= nil end
local proto = read("prototypes/modules.lua")
check(has(proto, 'require("shared.content.modules_teintes")'), "prototypes/modules.lua lit la table partagée")
check(has(proto, "Mt.couleur(family)") and has(proto, "t.secondary ="), "prototypes/modules.lua : couche lumineuse (secondary) = couleur de la famille")
check(proto ~= nil and not has(proto, "item.beacon_tint = table.deepcopy(ic.beacon_tint)") and select(2, proto:gsub("item%.beacon_tint = teinte_balise%(ic, family%)", "")) == 2,
  "prototypes/modules.lua : les deux teintes (vanilla, paliers 4 à 10) passent par teinte_balise")
local hy = read("script/team/hygiene.lua")
check(has(hy, 'require("script.team.balises_teinte")'), "hygiene.lua requiert balises_teinte (hors évènement, F24)")
check(has(hy, "Balises.step(f, surface, tick, slice)"), "hygiene.lua appelle Balises.step à chaque tranche")
local bt = read("script/team/balises_teinte.lua")
check(has(bt, 'require("shared.content.modules_teintes")'), "balises_teinte.lua lit la table partagée")
check(has(bt, "module_effect"), "balises_teinte.lua lit la famille au prototype (module_effect)")
check(has(bt, "get_module_inventory"), "balises_teinte.lua lit l'inventaire de modules")
check(has(bt, "rendering.draw_light") and has(bt, "rendering.set_color") and has(bt, "rendering.destroy"), "balises_teinte.lua : pose, recolore, retire")
check(has(bt, "[FO-BALISES]"), "balises_teinte.lua : journal [FO-BALISES]")
check(bt ~= nil and not bt:find("%f[%w_]global%f[^%w_]"), "balises_teinte.lua ne nomme pas `global`")
check(bt ~= nil and not bt:find("%f[%w_]os%.clock%f[^%w_]") and not bt:find("game%.tick_paused"), "balises_teinte.lua : aucun temps mesuré")
for _, path in ipairs({ "shared/content/modules_teintes.lua", "script/team/balises_teinte.lua" }) do
  local f, err = loadfile(path)
  check(f ~= nil, "loadfile " .. path .. " : " .. tostring(err))
end

print(string.format("[MODULES-TEINTES] BILAN : %d OK, %d ECHEC", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
