--[[
  N099-FONDERIES (DC, test 0.9.8 sur un autre PC : « des fonderies qui se superposent », « problèmes de chemins entre les fonderies et
  les foreuses »). Test PUR du plan de champ (shared/team/champ.lua, Ch.plan) sur la spec réelle du fer du joueur (carte du DC,
  tests/fixtures/champ_joueur_dc.lua).

  Chaîne (B2, deux réservations de la même tuile) : une bande est planifiée SEULE (Champ.band, frame.only) ; les pièces des autres bandes
  du même avant-poste sont « nôtres » (script/team/champ.lua, mine_of) et spec.mine gagne sur spec.blocked (c.free) ; la recherche de
  colonne ailleurs (Co.away, away_free) posait donc la colonne et son lien SUR la colonne d'une bande déjà bâtie ; Build.SITES.champ en
  écartait ensuite les pièces (moteur, graine 4251870853, joueur, 60,8 min : projet 44, bande -63 : « 24 foreuses, 0 fours, 167 entites
  (386 deja au plan) » ; projets 46 et 63 de même, 0 four chacun).
  Coupe : mine_of écrit la rangée `pr` de la bande sur ses tuiles ; away_free refuse une tuile d'une AUTRE bande.

  Mesure : chaque bande replanifiée seule, les autres posées (blocked = pièce, mine = leur pr). Tuiles de fours et de lien posées sur une
  autre bande : avant 92 tuiles de fours (bandes 7 et -9), après 0.
  Mutant : away_free d'avant (sans le refus) -> des fours sur une autre bande.
  Lancement (racine du mod) : lua5.2 tests/n099_fonderies_test.lua   -> [N099-FONDERIES] BILAN : N OK, 0 ECHEC(S)
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1; print("[N099-FONDERIES] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC_CH = read("shared/team/champ.lua")
local SRC_CO = read("shared/team/champ_colonne.lua")
local function sub1(src, a, b, name)
  local i, j = src:find(a, 1, true)
  assert(i, "mutant introuvable : " .. name)
  assert(not src:find(a, j + 1, true), "mutant ambigu : " .. name)
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end
local function load_ch(ch_src)
  for _, m in ipairs({ "shared.team.champ_colonne", "shared.team.champ" }) do package.loaded[m] = nil end
  package.loaded["shared.team.champ_colonne"] = assert(load(SRC_CO, "=shared/team/champ_colonne.lua", "t", _ENV))()
  package.loaded["shared.team.champ"] = assert(load(ch_src, "=shared/team/champ.lua", "t", _ENV))()
  return package.loaded["shared.team.champ"]
end

local function K(x, y) return (x + 50000) * 100000 + (y + 50000) end -- (Ch.key)
local function tiles(e)
  local w, h = e.w or e.size, e.h or e.size
  local out = {}
  local x0, y0 = math.floor(e.x - w / 2 + 0.01), math.floor(e.y - h / 2 + 0.01)
  for i = 0, w - 1 do for j = 0, h - 1 do out[#out + 1] = { x0 + i, y0 + j } end end
  return out
end
local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end

-- rend (tuiles de fours sur une autre bande, tuiles de lien sur une autre bande, fours posés, liens posés) sur toutes les bandes
local function measure(Ch)
  local fx = dofile("tests/fixtures/champ_joueur_dc.lua")
  local spec = fx.spec
  local P = Ch.plan(spec)
  assert(P, "plan entier")
  local by, prs = {}, {}
  for _, e in ipairs(P.ents) do
    if e.pr then
      if not by[e.pr] then by[e.pr] = {}; prs[#prs + 1] = e.pr end
      by[e.pr][#by[e.pr] + 1] = e
    end
  end
  table.sort(prs)
  local over_f, over_l, fours, liens = 0, 0, 0, 0
  for _, prB in ipairs(prs) do
    local s2 = copy(spec)
    s2.blocked, s2.mine = copy(spec.blocked), copy(spec.mine or {})
    local other = {}
    for _, pr in ipairs(prs) do
      if pr ~= prB then
        for _, e in ipairs(by[pr]) do
          for _, t in ipairs(tiles(e)) do
            local k = K(t[1], t[2])
            s2.blocked[k] = "piece"
            if s2.mine[k] == nil then s2.mine[k] = pr end
            other[k] = pr
          end
        end
      end
    end
    local fr = copy(P.frame); fr.only = { [prB] = true }
    s2.frame = fr
    local Q = Ch.plan(s2)
    for _, e in ipairs(Q and Q.ents or {}) do
      if e.pr == prB then
        if e.kind == "four" then fours = fours + 1 end
        if e.role == "lien" then liens = liens + 1 end
        for _, t in ipairs(tiles(e)) do
          if other[K(t[1], t[2])] then
            if e.kind == "four" then over_f = over_f + 1 end
            if e.role == "lien" then over_l = over_l + 1 end
          end
        end
      end
    end
  end
  return over_f, over_l, fours, liens
end

-- 1. le code livré
local Ch = load_ch(SRC_CH)
local of, ol, nf, nl = measure(Ch)
print(string.format("[N099-FONDERIES] livre : fours sur une autre bande %d tuile(s), lien sur une autre bande %d, fours poses %d, liens %d", of, ol, nf, nl))
check(of == 0, "aucune tuile de four d'une bande seule sur une autre bande (" .. of .. ")")
check(ol == 0, "aucune tuile de lien d'une bande seule sur une autre bande (" .. ol .. ")")
check(nf > 0 and nl > 0, "les bandes seules gardent des fours et des colonnes ailleurs (" .. nf .. " fours, " .. nl .. " liens)")

-- 2. mutant : away_free d'avant le lot
local MUT = sub1(SRC_CH, '      if type(m) == "number" and m ~= bd.pr then return false end\n', "", "refus")
local Cm = load_ch(MUT)
local mf, ml = measure(Cm)
print(string.format("[N099-FONDERIES] mutant (refus retire) : fours sur une autre bande %d tuile(s), lien %d", mf, ml))
check(mf > 0, "mutant : des fours d'une bande seule tombent sur une autre bande (" .. mf .. ")")

-- 3. le producteur (script/team/champ.lua, mine_of) écrit la rangée de la bande, pas `true`
local SRC_SC = read("script/team/champ.lua")
check(SRC_SC:find("local pr = tonumber(p.spec.champ.pr)", 1, true) ~= nil and SRC_SC:find("mine[k] = pr or true", 1, true) ~= nil,
  "mine_of marque les tuiles des pieces de bande par leur rangee pr")

print(string.format("[N099-FONDERIES] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
