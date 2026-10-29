--[[
  Lot CORR-RESEAU : test hors jeu de la santé de la centrale (shared/team/reseau_sante.lua).
    §1 chaque cas de la table de décision (centrale pas finie, saine, pièces perdues site sûr / ennemis à portée / site dangereux,
       production nulle, îlots) ; §2 persistance du danger et des essais ; §3 déménagement compté ; §4 déterminisme ;
    §5 aucun nom d'objet de jeu ; §6 mutants : chaque règle retirée est vue.
  Usage : lua5.2 tests/reseau_sante_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/reseau_sante.lua")
local function load_s(src)
  local fn, err = load(src, "=sante", "t")
  assert(fn, err)
  return fn()
end
local S = load_s(SRC)

local function inp(t)
  local base = { fini = true, missing = {}, present = { source = 2, gen = 4, eau = 1 }, prod_kw = 900, demand_kw = 500, dry = 0,
    islands = 0, uncovered = 0, enemies = 0, lost_links = 0 }
  for k, v in pairs(t or {}) do base[k] = v end
  return base
end

-- §1 table de décision
local a = S.decide(inp({ fini = false }), S.new())
check(a == "attendre", "pas finie : attendre")
a = S.decide(inp(), S.new())
check(a == "ok", "saine : ok")
a = S.decide(inp({ missing = { source = 1 } }), S.new())
check(a == "reposer", "chaudiere perdue, site sur : reposer")
a = S.decide(inp({ missing = { gen = 1 } }), S.new())
check(a == "reposer", "machine perdue, site sur : reposer")
a = S.decide(inp({ missing = { eau = 1 } }), S.new())
check(a == "reposer", "pompe perdue : reposer")
a = S.decide(inp({ missing = { tuyau = 3 } }), S.new())
check(a == "reposer", "tuyaux perdus (la vapeur ne passe plus) : reposer")
a = S.decide(inp({ missing = { source = 1 }, enemies = 3 }), S.new())
check(a == "attendre", "ennemis a portee, pas encore dangereux : attendre (pas de pose sous le feu)")
a = S.decide(inp({ prod_kw = 0, dry = 2 }), S.new())
check(a == "attendre", "production nulle : pas d'action au premier releve")
local st = S.new()
S.decide(inp({ prod_kw = 0, dry = 2 }), st)
a = S.decide(inp({ prod_kw = 0, dry = 2 }), st)
check(a == "combustible", "production nulle confirmee, sources a sec : combustible")
st = S.new()
S.decide(inp({ prod_kw = 0, islands = 3 }), st)
a = S.decide(inp({ prod_kw = 0, islands = 3 }), st)
check(a == "relier", "production nulle confirmee, consommateurs sur ilot : relier")
st = S.new()
S.decide(inp({ prod_kw = 0 }), st)
a = S.decide(inp({ prod_kw = 0 }), st)
check(a == "attendre", "production nulle sans cause : attendre")
a = S.decide(inp({ prod_kw = 0, demand_kw = 0 }), S.new())
check(a == "ok", "production nulle sans demande : pas une panne")
a = S.decide(inp({ islands = 2, lost_links = 1 }), S.new())
check(a == "relier", "centrale vivante, ilot et poteau perdu : relier")
a = S.decide(inp({ islands = 2, lost_links = 0 }), S.new())
check(a == "ok", "ilot sans poteau perdu : ce n'est pas une remise en etat (autre mecanisme)")

-- §2 danger persistant
st = S.new()
for _ = 1, S.DANGER_SEEN - 1 do a = S.decide(inp({ missing = { source = 1 }, enemies = 2 }), st) end
check(a == "attendre", "ennemis vus peu de fois : on attend")
a = S.decide(inp({ missing = { source = 1 }, enemies = 2 }), st)
check(a == "autre_site", "ennemis vus durablement : autre site")
st = S.new()
S.decide(inp({ missing = { source = 1 }, enemies = 2 }), st)
S.decide(inp({ missing = { source = 1 }, enemies = 0 }), st)
check(st.seen == 0, "ennemis partis : la persistance repart a zero")
st = S.new()
a = S.decide(inp({ missing = { gen = 1 } }), st)
S.applied(st, a, 100)
a = S.decide(inp({ missing = { gen = 1 } }), st)
check(a == "reposer", "premier essai refait sur place")
S.applied(st, a, 200)
a = S.decide(inp({ missing = { gen = 1 } }), st)
check(a == "autre_site", "refaite en vain " .. S.MAX_TRIES .. " fois : on change de site")
st = S.new()
S.note_loss(st, S.SITE_LOSSES)
a = S.decide(inp({ missing = { source = 1 } }), st)
check(a == "autre_site", "site deja perdu plusieurs fois : autre site")
st = S.new()
st.tries = 1
S.recovered(st)
check(st.tries == 0, "production revenue : essais soldes")

-- §3 déménagement
st = S.new()
st.seen, st.site_losses, st.tries = 9, 3, 2
S.applied(st, "autre_site", 5)
check(st.relocations == 1 and st.seen == 0 and st.site_losses == 0 and st.tries == 0, "autre site : compteurs du nouveau site remis a zero")
st = S.new()
st.relocations = S.MAX_RELOC
st.site_losses = S.SITE_LOSSES
a = S.decide(inp({ missing = { source = 1 } }), st)
check(a == "attendre", "plus d'autre site : on n'en redemande pas")

-- §4 déterminisme
local r1, r2 = {}, {}
for k = 1, 2 do
  local s = S.new()
  local out = k == 1 and r1 or r2
  for _, i in ipairs({ inp(), inp({ missing = { source = 1 } }), inp({ prod_kw = 0, dry = 1 }), inp({ prod_kw = 0, dry = 1 }),
    inp({ missing = { gen = 2 }, enemies = 1 }) }) do
    local act, w = S.decide(i, s)
    out[#out + 1] = act .. "|" .. w
  end
end
check(table.concat(r1, ";") == table.concat(r2, ";"), "determinisme")

-- §5 aucun nom d'objet de jeu
do
  local s = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  for _, w in ipairs({ "boiler", "steam", "pole", "engine", "pump", "iron", "coal", "fo%-" }) do
    check(not s:find(w), "aucun nom d'objet dans le code (" .. w .. ")")
  end
end

-- §1 bis des consommateurs sous AUCUN poteau, centrale saine : plus de decision de couverture (pas de poteau neuf, version mince)
do
  local st = S.new()
  for _ = 1, 6 do
    check(S.decide(inp({ uncovered = 3, uncov_reads = 9 }), st) == "ok", "decouverts, centrale saine : aucune pose de poteau neuf")
  end
  check(S.decide(inp({ uncovered = 3, uncov_reads = 5, islands = 1, lost_links = 2 }), S.new()) == "relier",
    "poteaux perdus et ilot : relever les poteaux perdus")
  check(S.decide(inp({ uncovered = 2, missing = { source = 1 } }), S.new()) == "reposer", "centrale amputee : la centrale d'abord")
end

-- §1 ter centrale de remplacement : garder, rentrer, finie
do
  local st = S.new()
  check(S.reloc_verdict({ new_state = "fini", enemies = 0 }, st) == "fini", "remplacement fini : fini")
  check(S.reloc_verdict({ new_state = "refuse", enemies = 3 }, S.new()) == "rentrer", "remplacement refuse : rentrer")
  check(S.reloc_verdict({ new_state = nil, enemies = 3 }, S.new()) == "rentrer", "remplacement perdu : rentrer")
  local s2 = S.new()
  local v
  for i = 1, S.CALM_READS - 1 do v = S.reloc_verdict({ new_state = "reserve", enemies = 0 }, s2) end
  check(v == "garder", "remplacement en reserve, site d'origine calme depuis moins de CALM_READS releves : garder")
  check(S.reloc_verdict({ new_state = "reserve", enemies = 0 }, s2) == "rentrer", "site d'origine calme depuis CALM_READS releves, remplacement pas commence : rentrer")
  local s3 = S.new()
  for i = 1, 10 do v = S.reloc_verdict({ new_state = "reserve", enemies = 2 }, s3) end
  check(v == "garder", "ennemi toujours la : le remplacement est garde, aussi longtemps que necessaire")
  local s4 = S.new()
  S.reloc_verdict({ new_state = "reserve", enemies = 0 }, s4)
  S.reloc_verdict({ new_state = "reserve", enemies = 0 }, s4)
  S.reloc_verdict({ new_state = "reserve", enemies = 1 }, s4)
  check(S.reloc_verdict({ new_state = "reserve", enemies = 0 }, s4) == "garder", "un ennemi revu remet le compte de calme a zero")
  local s5 = S.new()
  for i = 1, 10 do v = S.reloc_verdict({ new_state = "chantier", enemies = 0 }, s5) end
  check(v == "garder", "remplacement deja en chantier : jamais abandonne pour un site calme")
  local s6 = S.new()
  s6.calm = 2
  S.applied(s6, "autre_site", 1)
  check(s6.calm == 0, "un deplacement remet le compte de calme a zero")
end

-- §6 mutants
local MUT = {
  { "pas de confirmation de la production nulle", "if st.bad < S.CONFIRM then", "if false then" },
  { "pose sous le feu", 'if (inp.enemies or 0) > 0 then return "attendre", "ennemis a portee du site : pas de pose sous le feu", detail end', "" },
  { "danger sans persistance", "st.seen >= S.DANGER_SEEN or", "st.seen >= 1 or" },
  { "les essais ne comptent pas", "or st.tries >= S.MAX_TRIES", "" },
  { "les pertes de site ne comptent pas", "st.site_losses >= S.SITE_LOSSES or", "" },
  { "sans limite de deplacements", "if st.relocations < S.MAX_RELOC then", "if true then" },
  { "pieces perdues ignorees", "if lost > 0 then", "if false then" },
  { "centrale pas finie jugee", "if not inp.fini then", "if false then" },
  { "ilot sans poteau perdu releve", "if (inp.islands or 0) > 0 and (inp.lost_links or 0) > 0 then", "if (inp.islands or 0) > 0 then" },
  { "panne sans demande", "demand >= S.MIN_DEMAND_KW", "true" },
  { "combustible confondu", 'if (inp.dry or 0) > 0 then return "combustible"', 'if false then return "combustible"' },
  { "deplacement ne remet pas les compteurs", "st.tries, st.site_losses, st.seen, st.bad, st.calm = 0, 0, 0, 0, 0", "" },
  { "pompe non comptee", "(m.source or 0) + (m.gen or 0) + (m.eau or 0)", "(m.source or 0) + (m.gen or 0) + (m.tuyau or 0)" },
  { "tuyaux non comptes", "+ (m.tuyau or 0)", "" },
  { "remplacement refuse non repris", 'if ns == nil or ns == "refuse" then return "rentrer"', 'if false then return "rentrer"' },
  { "calme sans compte", "not started and st.calm >= S.CALM_READS", "not started" },
  { "chantier abandonne", 'local started = ns ~= "attente" and ns ~= "plan" and ns ~= "reserve"', "local started = false" },
  { "ennemi ne remet pas le calme a zero", "if (info.enemies or 0) > 0 then st.calm = 0 else", "if false then else" },
}
local function battery(S2)
  local bad = 0
  local function exp(cond) if not cond then bad = bad + 1 end end
  exp((S2.decide(inp({ fini = false }), S2.new())) == "attendre")
  exp((S2.decide(inp(), S2.new())) == "ok")
  exp((S2.decide(inp({ missing = { source = 1 } }), S2.new())) == "reposer")
  exp((S2.decide(inp({ missing = { eau = 1 } }), S2.new())) == "reposer")
  exp((S2.decide(inp({ missing = { source = 1 }, enemies = 3 }), S2.new())) == "attendre")
  exp((S2.decide(inp({ missing = { tuyau = 2 } }), S2.new())) == "reposer")
  exp((S2.reloc_verdict({ new_state = "refuse" }, S2.new())) == "rentrer")
  do
    local s7 = S2.new()
    for _ = 1, S2.CALM_READS - 1 do S2.reloc_verdict({ new_state = "reserve", enemies = 0 }, s7) end
    exp((S2.reloc_verdict({ new_state = "reserve", enemies = 0 }, s7)) == "rentrer")
    local s8 = S2.new()
    for _ = 1, 10 do S2.reloc_verdict({ new_state = "chantier", enemies = 0 }, s8) end
    exp((S2.reloc_verdict({ new_state = "chantier", enemies = 0 }, s8)) == "garder")
    local s9 = S2.new()
    for _ = 1, S2.CALM_READS - 1 do S2.reloc_verdict({ new_state = "reserve", enemies = 0 }, s9) end
    S2.reloc_verdict({ new_state = "reserve", enemies = 2 }, s9)
    exp((S2.reloc_verdict({ new_state = "reserve", enemies = 0 }, s9)) == "garder")
  end
  exp((S2.decide(inp({ uncovered = 3, uncov_reads = 9 }), S2.new())) == "ok")
  exp((S2.decide(inp({ prod_kw = 0, dry = 2 }), S2.new())) == "attendre")
  local s3 = S2.new()
  S2.decide(inp({ prod_kw = 0, dry = 2 }), s3)
  exp((S2.decide(inp({ prod_kw = 0, dry = 2 }), s3)) == "combustible")
  s3 = S2.new()
  S2.decide(inp({ prod_kw = 0, islands = 3 }), s3)
  exp((S2.decide(inp({ prod_kw = 0, islands = 3 }), s3)) == "relier")
  exp((S2.decide(inp({ prod_kw = 0, demand_kw = 0 }), S2.new())) == "ok")
  exp((S2.decide(inp({ islands = 2, lost_links = 0 }), S2.new())) == "ok")
  exp((S2.decide(inp({ islands = 2, lost_links = 1 }), S2.new())) == "relier")
  s3 = S2.new()
  local act
  for _ = 1, S2.DANGER_SEEN - 1 do act = S2.decide(inp({ missing = { source = 1 }, enemies = 2 }), s3) end
  exp(act == "attendre")
  exp((S2.decide(inp({ missing = { source = 1 }, enemies = 2 }), s3)) == "autre_site")
  s3 = S2.new()
  local x = S2.decide(inp({ missing = { gen = 1 } }), s3)
  S2.applied(s3, x, 1)
  x = S2.decide(inp({ missing = { gen = 1 } }), s3)
  S2.applied(s3, x, 2)
  exp((S2.decide(inp({ missing = { gen = 1 } }), s3)) == "autre_site")
  s3 = S2.new()
  S2.note_loss(s3, S2.SITE_LOSSES)
  exp((S2.decide(inp({ missing = { source = 1 } }), s3)) == "autre_site")
  s3 = S2.new()
  s3.relocations, s3.site_losses = S2.MAX_RELOC, S2.SITE_LOSSES
  exp((S2.decide(inp({ missing = { source = 1 } }), s3)) == "attendre")
  s3 = S2.new()
  s3.seen, s3.site_losses, s3.tries = 9, 3, 2
  S2.applied(s3, "autre_site", 5)
  exp(s3.seen == 0 and s3.site_losses == 0 and s3.tries == 0)
  return bad
end
check(battery(S) == 0, "la batterie des mutants passe sur le code vrai")
local refused, kept = 0, {}
for _, m in ipairs(MUT) do
  local pos = SRC:find(m[2], 1, true)
  if not pos then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local src2 = SRC:sub(1, pos - 1) .. m[3] .. SRC:sub(pos + #m[2])
    local ok, S2 = pcall(load_s, src2)
    if not ok then
      refused = refused + 1
    else
      local ok2, bad = pcall(battery, S2)
      if not ok2 or bad > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
    end
  end
end
check(#kept == 0, "mutants NON refuses : " .. table.concat(kept, " ; "))
print(string.format("[SANTE] mutants refuses : %d sur %d", refused, #MUT))
print(string.format("[SANTE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
