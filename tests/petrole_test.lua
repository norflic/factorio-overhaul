--[[
  Lot PETROLE : test hors jeu de l'exécutant générique des chaînes à fluides (shared/ai3/fluides.lua) et de son
  branchement au cerveau général (shared/ai3/catalogue.lua, shared/ai3/general.lua).
    §1 exécutants déduits des données (extracteur du pétrole par la catégorie de ressource, machines par la catégorie de
       recette et les boîtes à fluide) ;
    §2 H8 : le pack chimique est IMPAYABLE sans l'exécutant, PAYABLE avec lui une fois le pétrole connu, et l'inconnu
       « pétrole » rapporte (il est à explorer) ;
    §3 chaîne de cellules des objets du pack (plastique, soufre : raffinerie, usines chimiques, pompe d'eau) ;
    §4 implantation sur un terrain simulé : extracteurs centrés sur les puits, tuyaux sans mélange, quais, poteaux ;
    §5 généralisation : mêmes résultats sur des données RENOMMÉES (aucun nom dans le code) ;
    §6 déterminisme : deux implantations identiques.
  Lancement : lua5.2 tests/petrole_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local K = require("shared.ai3.catalogue")
local Gen = require("shared.ai3.general")
local Fl = require("shared.ai3.fluides")
local R = require("shared.ai3.reglages")

local pass, fail = 0, 0
local function check(c, msg)
  if c then pass = pass + 1 else fail = fail + 1; print("[PETROLE] ECHEC : " .. msg) end
end
local function say(s) print("[PETROLE] " .. s) end
local function sorted_keys(t) local k = {} for x in pairs(t or {}) do k[#k + 1] = x end table.sort(k) return k end

-- Raccords vanilla 1.1.91 (data/base/prototypes/entity), direction nord ; les autres directions par rotation (sauf
-- l'extracteur, explicite par direction comme son prototype).
local function rot(p, d)
  local x, y = p[1], p[2]
  for _ = 1, d / 2 do x, y = -y, x end
  return { x, y }
end
local function boxes_of(spec)
  local out = {}
  for _, b in ipairs(spec) do
    local conns = {}
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      conns[d] = {}
      for _, p in ipairs(b.pts) do conns[d][#conns[d] + 1] = b.explicit and b.explicit[d] or rot(p, d) end
    end
    out[#out + 1] = { type = b.type, conns = conns }
  end
  return out
end
local VANILLA_BOXES = {
  ["oil-refinery"] = { w = 5, h = 5, boxes = { { type = "input", pts = { { -1, 3 } } }, { type = "input", pts = { { 1, 3 } } },
    { type = "output", pts = { { -2, -3 } } }, { type = "output", pts = { { 0, -3 } } }, { type = "output", pts = { { 2, -3 } } } } },
  ["chemical-plant"] = { w = 3, h = 3, boxes = { { type = "input", pts = { { -1, -2 } } }, { type = "input", pts = { { 1, -2 } } },
    { type = "output", pts = { { -1, 2 } } }, { type = "output", pts = { { 1, 2 } } } } },
  ["assembling-machine-2"] = { w = 3, h = 3, boxes = { { type = "input", pts = { { 0, -2 } } }, { type = "output", pts = { { 0, 2 } } } } },
  ["assembling-machine-3"] = { w = 3, h = 3, boxes = { { type = "input", pts = { { 0, -2 } } }, { type = "output", pts = { { 0, 2 } } } } },
  ["pumpjack"] = { w = 3, h = 3, boxes = { { type = "output", pts = { { 1, -2 } },
    explicit = { [0] = { 1, -2 }, [2] = { 2, -1 }, [4] = { -1, 2 }, [6] = { -2, 1 } } } } },
  ["offshore-pump"] = { w = 1, h = 1, boxes = { { type = "output", pts = { { 0, 1 } } } } },
}
local ELECTRIC = { ["oil-refinery"] = true, ["chemical-plant"] = true, ["assembling-machine-1"] = true,
  ["assembling-machine-2"] = true, ["assembling-machine-3"] = true, ["pumpjack"] = true, ["inserter"] = true,
  ["centrifuge"] = true, ["electric-mining-drill"] = true, ["electric-furnace"] = true }

--- Relevé de l'exécutant depuis le relevé du catalogue (comme script/ai3/petrole.lua le lit dans les prototypes).
local function rel_of(d)
  local rel = { entities = {}, recipes = d.recipes, resources = d.resources, hand = {} }
  for _, e in ipairs(d.entities) do
    local role = R.ENTITY_ROLE[e.type or ""]
    if role == "main" then for _, c in ipairs(e.crafting_categories or {}) do rel.hand[c] = true end end
    local vb = VANILLA_BOXES[e.name]
    rel.entities[e.name] = { role = role, item = e.item, w = vb and vb.w or 1, h = vb and vb.h or 1,
      categories = e.crafting_categories, rescats = e.resource_categories, fluid = e.fluid,
      boxes = vb and boxes_of(vb.boxes) or nil, electric = ELECTRIC[e.name] or e.energy == "electric" }
    if role == "fabrique" and not vb then rel.entities[e.name].w, rel.entities[e.name].h = 3, 3 end
  end
  return rel
end

local function exec_with(d, rel, names)
  local opts = F.opts()
  local add, info = Fl.executors(rel, opts.exec)
  for _, k in ipairs(sorted_keys(add)) do
    local v = add[k]
    if opts.exec[k] ~= true then
      if v == true then opts.exec[k] = true
      else
        opts.exec[k] = type(opts.exec[k]) == "table" and opts.exec[k] or {}
        for _, r in ipairs(sorted_keys(v)) do opts.exec[k][r] = true end
      end
    end
  end
  -- centrale de l'équipe (exécutant du plan directeur) : pompe de rive, chaudière, machine à vapeur
  for _, n in ipairs({ names.offshore, names.boiler, names.steam }) do opts.exec[n] = true end
  return opts, info, add
end

local function all_techs_before(cat, target)
  local done = {}
  local function walk(t)
    if done[t] then return end
    done[t] = true
    for _, p in ipairs(cat.techs[t].prerequisites) do walk(p) end
  end
  walk(target)
  done[target] = nil
  return done
end

local function run(d, label, names)
  local rel = rel_of(d)
  -- §1
  local opts, info, add = exec_with(d, rel, names)
  local ex = info.extract[names.crude] or {}
  check(#ex == 1 and ex[1] == names.pumpjack, label .. " §1 extracteur du pétrole déduit : " .. table.concat(ex, " "))
  local ms = info.recipes[names.basic] or {}
  check(ms[1] == names.refinery, label .. " §1 raffinerie déduite de la catégorie : " .. table.concat(ms, " "))
  check((info.recipes[names.plastic] or {})[1] == names.chem, label .. " §1 usine chimique du plastique")
  check((info.recipes[names.sulfur] or {})[1] == names.chem, label .. " §1 usine chimique du soufre")
  local eng = info.recipes[names.engine] or {}
  check(#eng >= 1, label .. " §1 le moteur (catégorie hors de la main) a une machine : " .. table.concat(eng, " "))
  check(info.recipes[names.gear] == nil, label .. " §1 l'engrenage (fait à la main) n'est pas une cellule")
  -- §2 H8
  local base = K.build(d, F.opts())
  local cat = K.build(d, opts)
  local techs = all_techs_before(cat, names.chem_tech)
  techs[names.chem_tech] = true
  local st_known = { stock = {}, techs = techs, built = {}, known = { [names.iron] = true, [names.copper] = true,
    [names.coal] = true, [names.stone] = true, [names.crude] = true, [names.water] = true } }
  local ev0 = Gen.prepare(base, st_known)
  check(not ev0.feas[names.chem_pack], label .. " §2 sans l'exécutant : pack chimique impayable (H8)")
  local ev1 = Gen.prepare(cat, st_known)
  check(ev1.feas[names.chem_pack] == true, label .. " §2 avec l'exécutant et le pétrole connu : pack chimique payable")
  local st_unk = { stock = {}, techs = techs, built = {}, known = { [names.iron] = true, [names.copper] = true,
    [names.coal] = true, [names.stone] = true, [names.water] = true } }
  local ev2 = Gen.prepare(cat, st_unk)
  check(not ev2.feas[names.chem_pack], label .. " §2 pétrole inconnu : impayable")
  local rv = Gen.resource_values(cat, ev2, st_unk, {})
  local crude_v = 0
  for _, r in ipairs(rv) do if r[1] == names.crude then crude_v = r[2] end end
  check(crude_v > 0, label .. " §2 le pétrole inconnu rapporte (" .. crude_v .. ") : il sera explore")
  local sum = Gen.summary(cat, ev1, st_known, { { item = names.chem_pack, n = 10 } })
  check(sum.payable and (sum.build[names.pumpjack] or 0) > 0 and (sum.build[names.refinery] or 0) > 0
    and (sum.build[names.chem] or 0) > 0, label .. " §2 dépliage du pack : chevalet, raffinerie, usine chimique construits")
  -- §2b « pack nouveau » (ctx.new_pack) : la recherche choisie consomme le pack chimique dès qu'il est payable
  local function consumes(t)
    for _, ing in ipairs((cat.techs[t] or {}).ingredients or {}) do if ing[1] == names.chem_pack then return true end end
    return false
  end
  -- (le palier militaire ouvert d'abord : la règle ne passe jamais devant une candidate qui ouvre elle-même un palier)
  local st2 = { stock = {}, techs = {}, built = {}, known = st_known.known }
  for k in pairs(techs) do st2.techs[k] = true end
  for k in pairs(all_techs_before(cat, names.mil_tech)) do st2.techs[k] = true end
  st2.techs[names.mil_tech] = true
  local ev3 = Gen.prepare(cat, st2)
  local d_on = Gen.choose(cat, ev3, st2, { new_pack = true })
  local used = {}
  for t in pairs(st2.techs) do for _, ing in ipairs((cat.techs[t] or {}).ingredients or {}) do used[ing[1]] = true end end
  local newp = false
  for _, ing in ipairs((cat.techs[d_on.tech or ""] or {}).ingredients or {}) do if not used[ing[1]] then newp = true end end
  check(d_on.tech ~= nil and newp and d_on.k1 == "pack nouveau", label .. " §2b pack nouveau : la recherche choisie consomme un pack jamais consommé (" .. tostring(d_on.tech) .. ")")
  local d_off = Gen.choose(cat, ev3, st2, {})
  say(label .. " §2b sans la règle : " .. tostring(d_off.tech) .. (consumes(d_off.tech or "") and " (consomme)" or " (ne consomme pas)"))
  -- §3 chaîne
  local ch, why = Fl.chain(rel, info, { names.plastic_bar, names.sulfur_item }, { [names.water] = "pompe" })
  check(ch ~= nil, label .. " §3 chaîne plastique + soufre : " .. tostring(why))
  if ch then
    local rs = {}
    for _, c in ipairs(ch.cells) do rs[#rs + 1] = c.recipe .. "@" .. c.machine end
    say(label .. " chaîne : " .. table.concat(rs, " ; "))
    check(#ch.cells == 3 and ch.cells[1].recipe == names.basic, label .. " §3 trois cellules, raffinerie d'abord")
    check(ch.sources[names.crude] == "extract" and ch.sources[names.water] == "pompe", label .. " §3 sources : puits et pompe")
  end
  -- §4 implantation sur un terrain simulé : eau à l'ouest (x < -30), une falaise de -5 à 5 en y = 20, 5 puits
  local function blocked(tx, ty)
    if tx < -30 then return true end
    if ty == 20 and tx >= -5 and tx <= 5 then return true end
    return false
  end
  local pumps = {}
  for y = -10, 10 do pumps[#pumps + 1] = { name = names.offshore, x = -30 + 0.5, y = y + 0.5, dir = 2, fluid = names.water } end
  -- pompe de rive : raccord à l'est quand elle regarde l'ouest (rotation de (0, 1)) : direction 2 = (-1, 0) ; on prend 6
  for _, p in ipairs(pumps) do p.dir = 6 end
  local req = { origin = { x = 0, y = 0 }, blocked = blocked, ents = rel.entities, chain = ch,
    wells = { { x = 10.5, y = 3.5 }, { x = 16.5, y = -4.5 }, { x = 22.5, y = 9.5 }, { x = 4.5, y = -12.5 }, { x = 30.5, y = 0.5 } },
    pumps = pumps, extractor = names.pumpjack, conduit = names.pipe, chest = names.chest, arm = names.arm,
    poles = { name = names.pole, supply = 3.5, wire = 9 }, network = { x = -20.5, y = -40.5 }, n_extract = 2 }
  local lay, why2 = Fl.layout(req)
  check(lay ~= nil, label .. " §4 implantation : " .. tostring(why2))
  if lay then
    local count = {}
    for _, e in ipairs(lay.ents) do count[e.name] = (count[e.name] or 0) + 1 end
    local parts = {}
    for _, k in ipairs(sorted_keys(count)) do parts[#parts + 1] = k .. "=" .. count[k] end
    say(label .. " implantation : " .. table.concat(parts, " ") .. string.format(" ; tuyaux %d, poteaux %d (liaison %d)", lay.pipes, lay.poles, lay.line))
    check(count[names.pumpjack] == 2, label .. " §4 deux chevalets")
    local on_well = 0
    for _, e in ipairs(lay.ents) do
      if e.name == names.pumpjack then
        for _, w in ipairs(req.wells) do if e.x == w.x and e.y == w.y then on_well = on_well + 1 end end
      end
    end
    check(on_well == 2, label .. " §4 chevalets centrés sur les puits (" .. on_well .. ")")
    check(count[names.refinery] == 1 and count[names.chem] == 2 and count[names.offshore] == 1, label .. " §4 raffinerie, 2 usines, 1 pompe")
    local ok, w3 = Fl.check(lay, rel.entities)
    check(ok, label .. " §4 réseaux de tuyaux d'un seul fluide, chaque machine raccordée : " .. tostring(w3))
    check(#lay.quais == 1 and lay.quais[1].item == names.coal and #lay.outs == 2, label .. " §4 quai du charbon, 2 sorties (plastique, soufre)")
    -- aucune entité sur une tuile bloquée, aucun chevauchement
    local occ, bad = {}, 0
    for _, e in ipairs(lay.ents) do
      local p = rel.entities[e.name] or { w = 1, h = 1 }
      local x0, y0, x1, y1 = Fl.rect_of(p, e.x, e.y, e.dir)
      for ty = y0, y1 do for tx = x0, x1 do
        local k = tx .. ":" .. ty
        if occ[k] or blocked(tx, ty) then bad = bad + 1 end
        occ[k] = true
      end end
    end
    check(bad == 0, label .. " §4 aucun chevauchement ni tuile bloquée (" .. bad .. ")")
    check(lay.line > 0, label .. " §4 ligne de poteaux jusqu'au réseau (" .. lay.line .. " relais)")
    -- §6 déterminisme
    local lay2 = Fl.layout(req)
    local same = lay2 and #lay2.ents == #lay.ents
    if same then for i, e in ipairs(lay.ents) do
      local o = lay2.ents[i]
      if o.name ~= e.name or o.x ~= e.x or o.y ~= e.y or o.dir ~= e.dir then same = false end
    end end
    check(same, label .. " §6 deux implantations identiques")
  end
  -- §4b rive LOIN du gisement (eau à x < -90) : machines près de la rive (req.block), le brut y vient par un long tuyau
  local function blocked2(tx, ty) return tx < -90 end
  local pumps2 = {}
  for y = -6, 6 do pumps2[#pumps2 + 1] = { name = names.offshore, x = -89.5, y = y + 0.5, dir = 6, fluid = names.water } end
  local req2 = {}
  for k, v in pairs(req) do req2[k] = v end
  req2.blocked, req2.pumps, req2.block = blocked2, pumps2, { x = -79.5, y = 0.5 }
  local lay2, why4 = Fl.layout(req2)
  check(lay2 ~= nil, label .. " §4b rive lointaine : " .. tostring(why4))
  if lay2 then
    local ok2, w5 = Fl.check(lay2, rel.entities)
    check(ok2, label .. " §4b réseaux sans mélange, chevalets raccordés : " .. tostring(w5))
    local ref
    for _, e in ipairs(lay2.ents) do if e.name == names.refinery then ref = e end end
    check(ref ~= nil and ref.x < -60, label .. " §4b raffinerie près de la rive (x " .. tostring(ref and ref.x) .. ")")
    say(string.format("%s §4b : %d tuyaux, %d poteaux, %d relais", label, lay2.pipes, lay2.poles, lay2.line))
  end
  return lay
end

local V = { crude = "crude-oil", pumpjack = "pumpjack", basic = "basic-oil-processing", refinery = "oil-refinery",
  plastic = "plastic-bar", sulfur = "sulfur", chem = "chemical-plant", engine = "engine-unit", gear = "iron-gear-wheel",
  chem_tech = "chemical-science-pack", mil_tech = "military-science-pack", chem_pack = "chemical-science-pack", iron = "iron-ore", copper = "copper-ore",
  coal = "coal", stone = "stone", plastic_bar = "plastic-bar", sulfur_item = "sulfur", water = "water",
  offshore = "offshore-pump", boiler = "boiler", steam = "steam-engine", pipe = "pipe", chest = "iron-chest", arm = "inserter", pole = "medium-electric-pole" }
run(F.dump(), "vanilla", V)

-- §5 Généralisation : tout renommé (préfixe « zz- »), boîtes et catégories comprises.
local function rename(s) return "zz-" .. s end
local d = F.dump()
local function ren_list(l) for i, v in ipairs(l or {}) do l[i] = rename(v) end end
local nr = {}
for name, r in pairs(d.recipes) do
  r.category = rename(r.category)
  for _, i in ipairs(r.ingredients) do i.name = rename(i.name) end
  for _, p in ipairs(r.products) do p.name = rename(p.name) end
  nr[rename(name)] = r
end
d.recipes = nr
local nt = {}
for name, t in pairs(d.techs) do
  for _, i in ipairs(t.ingredients) do i[1] = rename(i[1]) end
  ren_list(t.prerequisites); ren_list(t.unlocks)
  nt[rename(name)] = t
end
d.techs = nt
for _, e in ipairs(d.entities) do
  e.name = rename(e.name)
  if e.item then e.item = rename(e.item) end
  ren_list(e.crafting_categories); ren_list(e.resource_categories); ren_list(e.lab_inputs)
  if e.fluid then e.fluid = rename(e.fluid) end
  if e.fluid_in then e.fluid_in = rename(e.fluid_in) end
  if e.fluid_out then e.fluid_out = rename(e.fluid_out) end
end
for _, r in ipairs(d.resources) do
  r.entity = rename(r.entity); r.category = rename(r.category)
  for _, p in ipairs(r.products) do p.name = rename(p.name) end
end
local ni = {}
for name, it in pairs(d.items) do ni[rename(name)] = it end
d.items = ni
local nb = {}
for k, v in pairs(VANILLA_BOXES) do nb[rename(k)] = v end
VANILLA_BOXES = nb
local ne = {}
for k, v in pairs(ELECTRIC) do ne[rename(k)] = v end
ELECTRIC = ne
local fo = F.opts
F.opts = function()
  local o = fo()
  local ex = {}
  for k, v in pairs(o.exec) do ex[rename(k)] = v end
  o.exec = ex
  return o
end
local VR = {}
for k, v in pairs(V) do VR[k] = rename(v) end
local ok_r = pcall(run, d, "renomme", VR)
check(ok_r, "§5 données renommées : le même code tourne")

print(string.format("[PETROLE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
