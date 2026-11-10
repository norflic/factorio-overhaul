-- Lot BANDE-FIN-TAPIS (F475) : une bande presque finie dont la réserve a fui (objets rapportés au coffre par un PNJ rappelé,
-- tué, en fuite) relit ses manques en chantier comme une ligne de bande ou un projet rouvert : sans cela p.missing restait vide
-- depuis la fin de la réserve, le cerveau ne fabriquait rien pour elle (automatiser.lua : want_kit sur g.missing) et le PNJ
-- échouait « stock » en boucle (graine 123456789, TOURELLE-A : bande -30 du joueur à 341/365 de 38,7 à 90 min, 24 tapis).
-- Le test joue le TEXTE RÉEL de build.lua (garde de l'état, refresh_missing, needs_of) dans un environnement simulé, puis les
-- mêmes scènes sous mutants du texte : chaque mutant doit être refusé.
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local SRC = read("script/team/build.lua")

local function plain_find(s, pat) return s:find(pat, 1, true) end

--- Morceaux du texte réel : needs_of, refresh_missing, et le bloc de garde de l'état (de son commentaire au premier « end » qui suit
--- refresh_missing). Rend la fonction `step(f, p, tick)` et des compteurs, ou nil + raison.
local function build_env(src)
  local a = plain_find(src, "local function needs_of(p)")
  local b = plain_find(src, "--- Stock LIBRE du coffre")
  local c1 = plain_find(src, "--- Lot INTEG-RECONSTRUCTION (D6)")
  local d = plain_find(src, "--- Lot QGSURVIE (règle 1")
  local g0 = plain_find(src, "-- lot RACCORD-BANDE 2 : une LIGNE de bande (p.spec.lg)")
  if not (a and b and c1 and d and g0) then return nil, "ancres absentes" end
  local g1 = src:find("refresh_missing%(f, p%)\n%s*end\n", g0)
  if not g1 then return nil, "fin du bloc de garde absente" end
  local g2 = src:find("end\n", g1 + #"refresh_missing(f, p)")
  local guard = src:sub(g0, g2 + 3)
  local chunk = src:sub(a, b - 1) .. "\n" .. src:sub(c1, d - 1) .. "\nreturn function(f, p, tick)\n" .. guard .. "\nend"
  local st = { chest = {}, free = {}, free_calls = 0 }
  local env = {
    ipairs = ipairs, pairs = pairs, math = math, table = table, type = type, tostring = tostring,
    bump = function(t, k, n) t[k] = (t[k] or 0) + (n or 1) end,
    sorted_keys = function(t) local ks = {} for k in pairs(t) do ks[#ks + 1] = k end table.sort(ks) return ks end,
    Stock = { count = function(_, it) return st.chest[it] or 0 end },
    free_stock = function() st.free_calls = st.free_calls + 1 return st.free end,
    T = { fuel = "fuel" }, Rr = { SUBST_FUEL = 5 },
  }
  local fn, err = load(chunk, "=build_bande_fin", "t", env)
  if not fn then return nil, err end
  local ok, step = pcall(fn)
  if not ok then return nil, step end
  return step, st
end

local function band(built, total, unbuilt_item)
  local ents = {}
  for i = 1, total do
    ents[i] = { item = (i > built) and unbuilt_item or "pole", built = i <= built }
  end
  return ents
end

local function miss_of(p)
  local m = {}
  for _, x in ipairs(p.missing or {}) do m[x[1]] = x[2] end
  return m
end

--- Les scènes ; rend la liste des contrôles { ok, message }.
local function scenes(src)
  local out = {}
  local function c(ok, m) out[#out + 1] = { ok and true or false, m } end
  local step, st = build_env(src)
  if not step then c(false, "texte réel chargé (" .. tostring(st) .. ")") return out end
  -- 1. L'état exact du banc : bande ordinaire (ni rouverte ni ligne), chantier, 341/365, 24 tapis à poser, réserve vidée, coffre vide.
  local f = {}
  local p = { id = 4, state = "chantier", spec = { champ = { pr = -30 } }, stock = {}, missing = {}, ents = band(341, 365, "tapis") }
  st.chest, st.free = { tapis = 0 }, { tapis = 0 }
  step(f, p, 1000)
  c(miss_of(p).tapis == 24 and #p.missing == 1, "bande ordinaire en chantier, réserve vidée : 24 tapis manquants dits au cerveau")
  -- 2. Cadence : une fois par seconde ; dans la seconde, rien n'est relu.
  st.chest, st.free = { tapis = 5 }, { tapis = 5 }
  step(f, p, 1030)
  c(miss_of(p).tapis == 24, "dans la seconde : manques non relus (cadence de 60 ticks)")
  step(f, p, 1060)
  c(miss_of(p).tapis == 19, "la seconde suivante : le coffre libre compte (24 - 5)")
  -- 3. Le coffre brut ne compte pas : objets promis à une tâche prise.
  st.chest, st.free = { tapis = 9 }, { tapis = 0 }
  step(f, p, 1120)
  c(miss_of(p).tapis == 24, "objets du coffre promis à une tâche : non comptés (stock libre)")
  -- 4. Réserve du projet : ce qui y reste couvre le besoin, aucun manque ; le stock libre n'est pas lu (coût).
  local q = { id = 9, state = "chantier", spec = {}, stock = { tapis = 24 }, missing = {}, ents = band(341, 365, "tapis") }
  st.free_calls = 0
  step(f, q, 1000)
  c(#q.missing == 0, "réserve couvrante : aucun manque")
  c(st.free_calls == 0, "réserve couvrante : le stock libre n'est pas relu")
  -- 5. Fantômes et défrichage aussi ; réserve et fini non (reserve() tient la réserve, un projet fini n'a rien à poser).
  for _, s in ipairs({ "fantomes", "defrichage" }) do
    local r = { id = 10, state = s, spec = {}, stock = {}, missing = {}, ents = band(10, 12, "tapis") }
    st.chest, st.free = {}, {}
    step(f, r, 2000)
    c(miss_of(r).tapis == 2, "état " .. s .. " : manques relus")
  end
  for _, s in ipairs({ "reserve", "fini" }) do
    local r = { id = 11, state = s, spec = {}, stock = {}, missing = { { "x", 1 } }, ents = band(10, 12, "tapis") }
    step(f, r, 2000)
    c(#r.missing == 1 and r.missing[1][1] == "x", "état " .. s .. " : la garde ne touche pas les manques")
  end
  -- 6. Les deux cas d'avant gardent leur conduite : ligne de bande et projet rouvert.
  local lg = { id = 12, state = "chantier", spec = { lg = {} }, stock = {}, missing = {}, ents = band(29, 32, "pole") }
  step(f, lg, 3000)
  c(miss_of(lg).pole == 3, "ligne de bande (RACCORD-BANDE 2) : manques relus comme avant")
  local ro = { id = 13, state = "fantomes", reopened = 1, spec = {}, stock = {}, missing = {}, ents = band(5, 8, "tapis") }
  step(f, ro, 3000)
  c(miss_of(ro).tapis == 3, "projet rouvert (INTEG-RECONSTRUCTION D6) : manques relus comme avant")
  return out
end

-- §1 : le texte réel
local base = scenes(SRC)
for _, r in ipairs(base) do check(r[1], r[2]) end

-- §2 : le cerveau fabrique pour un chantier qui manque (want_kit sur g.missing en chantier)
do
  local au = read("shared/ai3/automatiser.lua")
  check(plain_find(au, 'state == "chantier") and g.missing and #g.missing > 0 then') ~= nil,
    "automatiser.lua : le manque d'un chantier devient un kit à fabriquer (want_kit)")
end

-- §3 : mutants du texte de build.lua (chacun doit faire échouer au moins une scène)
local function refused(mut)
  local src2, n = mut(SRC)
  if n == 0 then return false, "mutant sans effet" end
  for _, r in ipairs(scenes(src2)) do if not r[1] then return true end end
  return false
end
local MUTANTS = {
  { "garde d'avant (rouvert ou ligne seulement)", function(s) return s:gsub("if tick >= %(p%.miss_next or 0%) and %(p%.state == \"defrichage\"",
      "if (p.reopened or (p.spec and p.spec.lg)) and tick >= (p.miss_next or 0) and (p.state == \"defrichage\"", 1) end },
  { "chantier oublié", function(s) return s:gsub('or p%.state == "fantomes" or p%.state == "chantier"%) then\n    p%.miss_next',
      'or p.state == "fantomes") then\n    p.miss_next', 1) end },
  { "cadence jamais échue", function(s) return s:gsub("if tick >= %(p%.miss_next or 0%) and", "if tick < (p.miss_next or 0) and", 1) end },
  { "cadence supprimée", function(s) return s:gsub("p%.miss_next = tick %+ 60", "p.miss_next = tick", 1) end },
  { "réserve du projet ignorée", function(s) return s:gsub("local function refresh_missing%(f, p%)(.-)local want = need%[it%] %- %(p%.stock%[it%] or 0%)",
      "local function refresh_missing(f, p)%1local want = need[it]", 1) end },
  { "coffre brut au lieu du stock libre", function(s) return s:gsub("local function refresh_missing%(f, p%)(.-)local have = math%.min%(Stock%.count%(f, it%), free%[it%] or 0%)",
      "local function refresh_missing(f, p)%1local have = Stock.count(f, it)", 1) end },
  { "stock libre relu même sans manque", function(s) return s:gsub("local function refresh_missing%(f, p%)\n  local need = needs_of%(p%)\n  local free\n",
      "local function refresh_missing(f, p)\n  local need = needs_of(p)\n  local free = free_stock(f)\n", 1) end },
}
local nm = 0
for _, m in ipairs(MUTANTS) do
  local ok = refused(m[2])
  if ok then nm = nm + 1 end
  check(ok, "mutant refusé : " .. m[1])
end

-- §4 : forme du texte touché (aucun nom du jeu, pas de pairs dans la garde)
do
  local g0 = plain_find(SRC, "-- lot RACCORD-BANDE 2 : une LIGNE de bande (p.spec.lg)")
  local g = SRC:sub(g0, g0 + 1200)
  check(not g:find("[^i]pairs%(") and not g:find("math%.random"), "garde : ni pairs ni hasard")
end

print(string.format("[BANDE-FIN] BILAN : %d OK, %d ECHEC(S) (%d mutants refusés sur %d)", pass, fail, nm, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
