--[[
  Lot ART-IMPACTS (11/11, mandat de nuit du DC, chantier A §2 : « faisceaux denses, ondes de choc au sol, distorsions de
  singularité »). Banc hors jeu, Lua 5.2, racine du mod :
      lua5.2 tests/impacts_test.lua
    §1 recettes : le laser de la lignée et le fusil à rail portent un FAISCEAU dense (épaisseur, durée bornée pour la trace du
       rail) ; plasma, singularité, frappe orbitale et titans portent une ONDE DE CHOC au sol et une BRÛLURE éphémère ; la
       DISTORSION de singularité est réservée aux armes de la plus haute ère (lanceur de singularités, titans) ; chaque partie
       nouvelle prend la couleur de l'arme ; tous les packs passent Fx.verifier ;
    §2 bornes : un choc, une distorsion, une brûlure, un faisceau hors bornes, un impact sans porteur sont refusés ;
    §3 feuilles (D-6, graphics/effets/sprites.lua) : choc, singularite, singularite-ombre, faisceau, eclat présentes, PNG aux
       dimensions annoncées (grille de line_length colonnes), dans le budget (≤ 2 048 px de côté, ≤ 64 images), citées au
       MANIFEST ; Fx.verifier_feuille refuse une feuille hors budget ;
    §4 câblage des prototypes (lecture du source) : le choc est AU SOL, l'ombre de la singularité en mélange normal sous l'anneau
       additif, la trace du rail remplacée par le faisceau dense SANS action de dégâts, la frappe orbitale crée le porteur de
       l'impact (plus l'onde disparue), le laser habillé par le faisceau dense ;
    §5 mutants de la règle : chacun refusé.
]]

package.path = "./?.lua;" .. package.path

local Fx = require("shared.content.effets_armes")
local A = require("shared.content.arsenal")
local T = require("shared.robots.titans")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[IMPACTS] ECHEC : " .. msg) end
end

local function read(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local HAUTE_ERE = { singularite = true, titan = true }   -- modes des armes de la plus haute ère (distorsion)
local CHOC = { plasma = true, singularite = true, orbital = true, titan = true }
local FAISCEAU = { laser = true, rail = true }

--- Les écarts d'un module de règle Fx aux recettes du lot ; liste vide = conforme.
local function ecarts(F)
  local motifs = {}
  local function m(s) motifs[#motifs + 1] = s end
  local packs = F.armes(A, T)
  local vus = {}
  for _, p in ipairs(packs) do
    if not p.delegue then
      vus[p.mode] = true
      local i = p.impact or {}
      if FAISCEAU[p.mode] then
        if not p.faisceau then m(p.nom .. " : pas de faisceau dense")
        elseif p.faisceau.couleur ~= p.couleur then m(p.nom .. " : le faisceau n'a pas la couleur de l'arme") end
        if p.mode == "rail" and not (p.faisceau and p.faisceau.duree) then m(p.nom .. " : trace du rail sans durée") end
      end
      if CHOC[p.mode] then
        if not i.choc then m(p.nom .. " : pas d'onde de choc au sol") end
        if not i.brulure then m(p.nom .. " : pas de brûlure au sol") end
      end
      if HAUTE_ERE[p.mode] then
        if not i.distorsion then m(p.nom .. " : arme de la plus haute ère sans distorsion") end
      elseif i.distorsion then
        m(p.nom .. " : distorsion hors de la plus haute ère")
      end
      for _, x in ipairs(F.verifier(p)) do m("verifier : " .. x) end
    end
  end
  for k in pairs(CHOC) do if not vus[k] then m("mode " .. k .. " absent des données") end end
  return motifs
end

---------------------------------------------------------------------------------------------------
-- §1 recettes
---------------------------------------------------------------------------------------------------
local e1 = ecarts(Fx)
for _, x in ipairs(e1) do print("  " .. x) end
check(#e1 == 0, "§1 recettes du lot (" .. #e1 .. " écart(s))")
do
  local packs = Fx.armes(A, T)
  local n_choc, n_dist, n_fais = 0, 0, 0
  for _, p in ipairs(packs) do
    if p.impact and p.impact.choc then n_choc = n_choc + 1 end
    if p.impact and p.impact.distorsion then n_dist = n_dist + 1 end
    if p.faisceau then n_fais = n_fais + 1 end
  end
  check(n_choc >= 3 + #T.ALLIES, "§1 ondes de choc : " .. n_choc .. " packs (plasma, singularité, orbitale et chaque titan)")
  check(n_dist == 1 + #T.ALLIES, "§1 distorsions : " .. n_dist .. " packs (lanceur de singularités et chaque titan)")
  check(n_fais == 2, "§1 faisceaux denses : " .. n_fais .. " packs (laser de la lignée, fusil à rail)")
end

---------------------------------------------------------------------------------------------------
-- §2 bornes
---------------------------------------------------------------------------------------------------
local function un(mode)
  for _, p in ipairs(Fx.armes(A, T)) do if p.mode == mode then return p end end
end
local function refuse_pack(nom, mode, f)
  local p = un(mode)
  f(p)
  check(#Fx.verifier(p) > 0, "§2 refusé : " .. nom)
end
refuse_pack("brûlure qui ne s'efface pas", "plasma", function(p) p.impact.brulure.tenue = 99999 end)
refuse_pack("onde de choc démesurée", "orbital", function(p) p.impact.choc.echelle = 99 end)
refuse_pack("distorsion trop longue", "singularite", function(p) p.impact.distorsion.duree = 999 end)
refuse_pack("faisceau trop épais", "laser", function(p) p.faisceau.epaisseur = 9 end)
refuse_pack("trace du rail trop longue", "rail", function(p) p.faisceau.duree = 600 end)
refuse_pack("impact sans porteur", "titan", function(p) p.impact.choc = nil end)

---------------------------------------------------------------------------------------------------
-- §3 feuilles
---------------------------------------------------------------------------------------------------
local function png_size(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local h = f:read(24)
  f:close()
  if not h or #h < 24 or h:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
  local function u32(s, i) local a, b, c, d = s:byte(i, i + 3); return ((a * 256 + b) * 256 + c) * 256 + d end
  return u32(h, 17), u32(h, 21)
end
local okspr, SPR = pcall(dofile, "graphics/effets/sprites.lua")
check(okspr and type(SPR) == "table", "§3 graphics/effets/sprites.lua lisible (sinon : py -3.9 tools/render/pieces/effets/vortex.py)")
if okspr then
  local man = read("graphics/effets/MANIFEST.json") or ""
  for _, cle in ipairs({ "choc", "singularite", "singularite-ombre", "faisceau", "eclat" }) do
    local s = SPR[cle]
    check(s ~= nil, "§3 feuille " .. cle .. " présente")
    if s then
      local motifs = Fx.verifier_feuille(cle, s)
      check(#motifs == 0, "§3 " .. cle .. " dans le budget : " .. table.concat(motifs, " ; "))
      local cols = s.line_length or s.images
      local rows = math.ceil(s.images / cols)
      for _, res in ipairs({ "lr", "hr" }) do
        local d = s[res]
        local p = d.filename:gsub("^__factorio%-overhaul__/", "")
        local w, h = png_size(p)
        check(w == d.width * cols and h == d.height * rows,
          string.format("§3 %s %s : PNG %s × %s = grille %d × %d de %d × %d", cle, res, tostring(w), tostring(h), cols, rows, d.width, d.height))
        check(w and w <= Fx.BORNES.feuille_px_max and h <= Fx.BORNES.feuille_px_max, "§3 " .. cle .. " " .. res .. " ≤ 2 048 px")
        check(man:find(p:match("([^/]+)$"), 1, true) ~= nil, "§3 MANIFEST cite " .. p)
      end
    end
  end
  check(#Fx.verifier_feuille("trop", { images = 16, line_length = 16, lr = { width = 128, height = 128 }, hr = { width = 256, height = 256 } }) > 0,
    "§3 une feuille de 16 × 256 px (4 096) est refusée")
  check(#Fx.verifier_feuille("trop", { images = 128, line_length = 8, lr = { width = 16, height = 16 }, hr = { width = 32, height = 32 } }) > 0,
    "§3 une feuille de 128 images est refusée")
end

---------------------------------------------------------------------------------------------------
-- §4 câblage des prototypes (source)
---------------------------------------------------------------------------------------------------
local P = read("prototypes/effets_armes.lua") or ""
check(P:find('animations = { feuille_anim("choc", c, o.echelle, o.duree) }, rotate = false, render_layer = "lower-object-above-shadow"', 1, true) ~= nil,
  "§4 le choc est au sol (lower-object-above-shadow)")
check(P:find('{ "distorsion-ombre", "singularite-ombre", true, "explosion" }, { "distorsion", "singularite", false, "projectile" }', 1, true) ~= nil,
  "§4 ombre (normale, couche explosion) SOUS l'anneau additif (couche projectile)")
check(P:find("if not ombre then a.tint, a.blend_mode, a.draw_as_glow = rgba(c), \"additive\", true end", 1, true) ~= nil,
  "§4 l'ombre n'est ni teintée ni additive")
check(P:find("if d and d.type == \"beam\" then d.beam, d.duration = fr, pack.faisceau.duree or d.duration end", 1, true) ~= nil,
  "§4 trace du rail : le faisceau dense remplace l'arc vanilla")
do
  local fr = P:match("local function faisceau_rail%(pack%)(.-)\nend")
  check(fr ~= nil and not fr:find("action =", 1, true) and fr:find("action_triggered_automatically = false", 1, true) ~= nil,
    "§4 le faisceau du rail est visuel seul (aucune action de dégâts)")
end
check(P:find("se[#se + 1] = { type = \"create-entity\", entity_name = ni }", 1, true) ~= nil and
  not P:find('entity_name = Fx.nom(pack, "onde") }\n        d.source_effects = se', 1, true),
  "§4 frappe orbitale : le porteur de l'impact (onde de choc) est créé")
check(P:find("if b and pack.faisceau then faisceau_dense(b, pack) end", 1, true) ~= nil, "§4 le laser de la lignée prend le faisceau dense")
check(P:find('local a = anim_feuille("faisceau", c, 1, 16)', 1, true) ~= nil,
  "§4 corps du faisceau à l'échelle 1 (une tuile par image : aucune jointure trouée)")
check(P:find("e.ground_patch_fade_out_start = b.tenue", 1, true) ~= nil and P:find("e.time_before_removed = b.tenue", 1, true) ~= nil,
  "§4 la brûlure s'efface (éphémère)")

---------------------------------------------------------------------------------------------------
-- §5 mutants de la règle
---------------------------------------------------------------------------------------------------
local SRC = read("shared/content/effets_armes.lua") or ""
local function charge(src)
  local chunk, err = load(src, "=mutant", "t", setmetatable({}, { __index = _G }))
  if not chunk then return nil, err end
  local ok, M = pcall(chunk)
  if not ok then return nil, M end
  return M
end
local function mutant(nom, de, vers, juge)
  check(SRC:find(de, 1, true) ~= nil, "§5 mutant « " .. nom .. " » : la règle d'origine est là")
  local M = charge((SRC:gsub(de:gsub("%p", "%%%0"), (vers:gsub("%%", "%%%%")), 1)))
  local ok, rej = pcall(juge, M)
  check(ok and rej, "§5 mutant refusé : " .. nom)
end
local function refuse_ecarts(M) return #ecarts(M) > 0 end
mutant("plasma sans onde de choc",
  "      choc = { echelle = 9.0, duree = 40 }, brulure = { source = \"medium-scorchmark-tintable\", tenue = 900 } },",
  "      brulure = { source = \"medium-scorchmark-tintable\", tenue = 900 } },", refuse_ecarts)
mutant("titans sans distorsion",
  "      distorsion = { echelle = 8.0, duree = 54 }, brulure = { source = \"medium-scorchmark-tintable\", tenue = 900 } },",
  "      brulure = { source = \"medium-scorchmark-tintable\", tenue = 900 } },", refuse_ecarts)
mutant("faisceau sans la couleur de l'arme",
  "  for _, k in ipairs({ \"bouche\", \"impact\", \"projectile\", \"champ\", \"singularite\", \"faisceau\" }) do",
  "  for _, k in ipairs({ \"bouche\", \"impact\", \"projectile\", \"champ\", \"singularite\" }) do", refuse_ecarts)
mutant("trace du rail sans borne de durée",
  "    if f.duree ~= nil and not nombre(f.duree, 1, B.duree_max) then m(\"faisceau : durée \" .. tostring(f.duree)) end", "",
  function(M) local p; for _, x in ipairs(M.armes(A, T)) do if x.mode == "rail" then p = x end end
    p.faisceau.duree = 600; return #M.verifier(p) == 0 end)
mutant("brûlure jamais effacée acceptée",
  "    if i.brulure and not (type(i.brulure.source) == \"string\" and nombre(i.brulure.tenue, 60, B.brulure_tenue_max)) then m(\"impact : brûlure hors bornes\") end", "",
  function(M) local p; for _, x in ipairs(M.armes(A, T)) do if x.mode == "plasma" then p = x end end
    p.impact.brulure.tenue = 99999; return #M.verifier(p) == 0 end)
mutant("feuille hors budget acceptée",
  "  if not (s.hr.width * cols <= B.feuille_px_max and s.hr.height * rows <= B.feuille_px_max) then",
  "  if false then",
  function(M) return #M.verifier_feuille("trop", { images = 16, line_length = 16, lr = { width = 128, height = 128 },
    hr = { width = 256, height = 256 } }) == 0 end)
mutant("distorsion offerte au laser (hors de la plus haute ère)",
  "    impact = { source = \"explosion-hit\", echelle = 0.9, duree = 20, lumiere = { taille = 6, intensite = 0.6, tenue = 0.35 },",
  "    impact = { source = \"explosion-hit\", echelle = 0.9, duree = 20, lumiere = { taille = 6, intensite = 0.6, tenue = 0.35 }, distorsion = { echelle = 3, duree = 20 },",
  refuse_ecarts)

print(string.format("[IMPACTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
