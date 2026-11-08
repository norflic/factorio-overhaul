--[[
  Lot TV-REPLI (docs/TODO_VIDEO.md C07) : repli de placement simple d'un module sans lot (règle pure shared/team/repli_place.lua et colle
  script/team/repli_place.lua). Lancer depuis la racine du mod :
    lua5.2 tests/repli_place_test.lua   -> [REPLI-PLACE] BILAN : N OK, 0 ECHEC(S)
  §1 fenêtres (nombre, ordre des anneaux, aucun recouvrement, déterminisme) ; §2 raisons d'écarter une fenêtre ; §3 placement
  (anneau 0 si tout est libre, anneau suivant si le centre est bouché, marge, foreuses sur le minerai) ; §4 plafond de fenêtres lues et
  mémoire des refus ; §5 la colle (réglage, journal [FO-REPLI-PLACE], lot « repli », échec) ; §6 MUTANTS : la règle altérée de dix
  façons doit faire échouer ces contrôles.
]]
package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")
local M = require("shared.team.modules")

local total_pass, total_fail = 0, 0
local pass, fail = 0, 0
local verbose = true
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 if verbose then print("[REPLI-PLACE] ECHEC : " .. msg) end end
end
local function section(s) if verbose then print("== " .. s) end end

--- Les contrôles de la règle pure, rejouables sur une copie ALTÉRÉE (§6).
local function run_rule(Rp)
  local g = M.GEN.smelter("stone-furnace", "iron-ore", 4)
  local C = { x = 100, y = 200 }

  section("1. Fenêtres")
  local w = Rp.windows(C.x, C.y)
  check(#w == 49, "49 fenetres (anneaux 0 a 3) : " .. #w)
  check(w[1].x0 == C.x - 12 and w[1].y0 == C.y - 12 and w[1].x1 - w[1].x0 == P.LOT, "la premiere fenetre est centree sur le centre")
  local mono = true
  for i = 2, #w do if w[i].ring < w[i - 1].ring then mono = false end end
  check(mono, "anneaux dans l'ordre croissant")
  local overlap = 0
  for i = 1, #w do
    for j = i + 1, #w do
      local a, b = w[i], w[j]
      if a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1 then overlap = overlap + 1 end
    end
  end
  check(overlap == 0, "aucun recouvrement entre fenetres : " .. overlap)
  local w2 = Rp.windows(C.x, C.y)
  local same = #w == #w2
  for i = 1, #w do if not same or w[i].x0 ~= w2[i].x0 or w[i].y0 ~= w2[i].y0 then same = false end end
  check(same, "deterministe")

  section("2. Raisons d'ecarter une fenetre")
  local rect = w[1]
  local function info_of(st, why) return function() return st, why end end
  check(Rp.skip_reason(rect, { lot_info = info_of("refuse", "nid") }) == "nid", "lot voisin refuse pour un nid : ecartee")
  check(Rp.skip_reason(rect, { lot_info = info_of("refuse", "conteste") }) == "conteste", "lot refuse pour une force rivale : ecartee")
  check(Rp.skip_reason(rect, { lot_info = info_of("refuse", "eau") }) == nil, "lot refuse pour l'eau : lue (la tuile libre decide)")
  check(Rp.skip_reason(rect, { lot_info = info_of("gisement", "iron-ore") }) == "gisement", "module sans ressource : pas sur un gisement")
  check(Rp.skip_reason(rect, { res = "iron-ore", lot_info = info_of("gisement", "iron-ore") }) == nil, "module avec ressource : gisement permis")
  check(Rp.skip_reason(rect, { avoided = function() return true end }) == "danger", "site ecarte (danger) : ecartee")
  check(Rp.skip_reason(rect, {}) == nil, "rien a dire : lue")
  check(Rp.skip_reason(rect, { lot_info = function(tx, ty) if tx == rect.x0 and ty == rect.y0 then return "refuse", "nid" end end }) == "nid",
    "un coin sur un lot a nid suffit")

  section("3. Placement")
  local reads = 0
  local function free_all() return { free = function() return true end } end
  local function read_free(rect_) reads = reads + 1 return free_all(), nil end
  local ctx = { tick = 1000, bad = {}, read = read_free, fopts = { toward = C } }
  local fopts_before = ctx.fopts.toward
  local pl, cause, info = Rp.pick(g, C, ctx)
  check(pl ~= nil and cause == "ok", "tout libre : place trouvee")
  check(pl and pl.ring == 0 and pl.rect.x0 == w[1].x0, "tout libre : fenetre 0, au plus pres du centre")
  check(pl and pl.ox >= pl.rect.x0 + 1 and pl.ox + pl.g.w <= pl.rect.x1 - 1 and pl.oy >= pl.rect.y0 + 1 and pl.oy + pl.g.h <= pl.rect.y1 - 1,
    "marge d'une tuile dans la fenetre")
  check(pl and pl.inst and #pl.inst.entities > 0, "instance du gabarit rendue")
  check(reads == 1 and info.tried == 1, "une seule fenetre lue quand la premiere convient : " .. reads)
  -- vers le coin nord-ouest : l'emprise colle la marge d'une tuile (pas le bord de la fenetre)
  local pc = Rp.pick(g, C, { tick = 1, bad = {}, read = read_free, fopts = { toward = { x = C.x - 1000, y = C.y - 1000 } } })
  check(pc and pc ~= nil and pc.ox >= pc.rect.x0 + 1 and pc.oy == pc.rect.y0 + 1, "attire vers le coin : marge d'une tuile exactement (" .. tostring(pc and (pc.ox - pc.rect.x0) .. "," .. (pc.oy - pc.rect.y0)) .. ")")
  check(ctx.fopts.toward == fopts_before and ctx.fopts.free == nil, "les options de l'appelant ne sont pas modifiees")

  -- centre bouche : anneaux 0 et 1 impraticables (|dx|, |dy| <= 36)
  reads = 0
  local function read_ring2()
    reads = reads + 1
    return { free = function(tx, ty) return not (math.abs(tx - C.x) <= 37 and math.abs(ty - C.y) <= 37) end }, nil
  end
  local ctx2 = { tick = 1000, bad = {}, read = read_ring2 }
  local p2, c2, i2 = Rp.pick(g, C, ctx2)
  check(p2 ~= nil and p2.ring == 2, "centre bouche : repli sur l'anneau 2 (" .. tostring(p2 and p2.ring) .. ")")
  check(i2.tried == 9 + 1 or i2.tried <= Rp.MAX_WINDOWS, "fenetres lues bornees : " .. i2.tried)

  -- lot a nid : les fenetres de l'anneau 0 sont ecartees sans lecture
  reads = 0
  local ctx3 = { tick = 1000, bad = {}, read = read_free,
    lot_info = function(tx, ty) if math.abs(tx - C.x) <= 12 and math.abs(ty - C.y) <= 12 then return "refuse", "nid" end end }
  local p3, _, i3 = Rp.pick(g, C, ctx3)
  check(p3 ~= nil and p3.ring >= 1 and i3.skipped >= 1 and i3.refused.nid ~= nil, "nid au centre : fenetre ecartee, place plus loin")
  -- site ecarte
  local p3b = Rp.pick(g, C, { tick = 1, bad = {}, read = read_free, avoided = function(r) return r.ring == 0 end })
  check(p3b ~= nil and p3b.ring == 1, "site ecarte sur la fenetre 0 : anneau 1")

  -- foreuses : minerai dans la fenetre voisine a l'est (anneau 1)
  local d = M.GEN.drills("iron-ore", 2)
  local east = w[1].x0 + P.LOT -- fenetre (dx = 1, dy = 0)
  local function read_ore(rect_)
    local ores = {}
    if rect_.x0 == east and rect_.y0 == w[1].y0 then
      for y = rect_.y0, rect_.y1 - 1 do for x = rect_.x0, rect_.x1 - 1 do ores[P.tkey(x, y)] = true end end
    end
    return free_all(), ores
  end
  local pd, _, id = Rp.pick(d, C, { tick = 1, bad = {}, res = "iron-ore", read = read_ore, fopts = { toward = C },
    lot_info = function() return "gisement", "iron-ore" end })
  check(pd ~= nil and pd.rect.x0 == east and pd.rect.y0 == w[1].y0, "foreuses : la fenetre qui porte le minerai (anneau 1, a l'est)")
  check(pd and pd.cover >= P.DRILL_COVER, "foreuses : couverture du minerai " .. tostring(pd and pd.cover))
  check(id.refused["minerai"] ~= nil, "foreuses : les fenetres sans minerai sont refusees (minerai)")

  section("4. Plafond de fenetres lues et memoire des refus")
  reads = 0
  local function read_none() reads = reads + 1 return { free = function() return false end }, nil end
  local bad = {}
  local pn, cn, inn = Rp.pick(g, C, { tick = 1000, bad = bad, read = read_none })
  check(pn == nil and reads == Rp.MAX_WINDOWS and inn.tried == Rp.MAX_WINDOWS, "tout bouche : " .. Rp.MAX_WINDOWS .. " fenetres lues au plus (" .. reads .. ")")
  check(type(cn) == "string" and cn:find("place", 1, true) ~= nil and cn:find("12 fenetre", 1, true) ~= nil, "cause en une ligne : " .. tostring(cn))
  reads = 0
  local _, _, in2 = Rp.pick(g, C, { tick = 1010, bad = bad, read = read_none })
  check(in2.refused["deja-refusee"] == Rp.MAX_WINDOWS and reads == Rp.MAX_WINDOWS, "10 ticks plus tard : les 12 refusees ne sont pas relues, les 12 suivantes le sont")
  reads = 0
  Rp.pick(g, C, { tick = 1000 + Rp.RETRY + 1, bad = bad, read = read_none })
  check(reads == Rp.MAX_WINDOWS, "apres Rp.RETRY ticks : relues")
  -- un module sans memoire (bad nil) ne plante pas
  local pnil = Rp.pick(g, C, { tick = 1, read = read_free })
  check(pnil ~= nil, "sans memoire des refus : fonctionne")
end

local function run_all(Rp)
  pass, fail = 0, 0
  run_rule(Rp)
  return pass, fail
end

local Rp = require("shared.team.repli_place")
verbose = true
local p0, f0 = run_all(Rp)
total_pass, total_fail = total_pass + p0, total_fail + f0

---------------------------------------------------------------------------------------------------
-- 5. La colle (moteur simulé minimal)
---------------------------------------------------------------------------------------------------
pass, fail = 0, 0
section("5. Colle script/team/repli_place.lua")
do
  local logs = {}
  _G.log = function(s) logs[#logs + 1] = s end
  _G.game = { tick = 5000 }
  local on = true
  _G.settings = { global = setmetatable({}, { __index = function(_, k)
    if k == "fo-war-repli-place" then return { value = on } end
    return nil
  end }) }
  package.loaded["script.team.repli_place"] = nil
  local Rpl = require("script.team.repli_place")
  local g = M.GEN.smelter("stone-furnace", "iron-ore", 4)
  local lat = P.lattice({ x = 0.5, y = 0.5 })
  local f = { key = "ecarlate", build = { lat = lat, lots = {} } }
  local function read_masks() return { free = function() return true end } end
  local function ore_set() return {} end
  local ctx = { p = { id = 7 }, why = "pas de lot", center = { x = 0, y = 0 }, read_masks = read_masks, ore_set = ore_set, avoid_margin = 8 }
  local place = Rpl.try(f, nil, g, ctx)
  check(place ~= nil and place.lot == nil and place.repli == true, "colle : place rendue, sans lot du treillis (repli = true)")
  check(place and place.inst and place.masks and place.g, "colle : meme forme que place_module (g, inst, masks)")
  check(#logs == 1 and logs[1]:find("[FO-REPLI-PLACE]", 1, true) and logs[1]:find("pas de lot", 1, true) and logs[1]:find("pose de repli en (", 1, true),
    "journal [FO-REPLI-PLACE] avec la cause du plan et la place : " .. tostring(logs[1]))
  check(logs[1] and logs[1]:find("projet 7", 1, true) and logs[1]:find("ecarlate", 1, true), "journal : equipe et projet")
  check(f.build.repli and f.build.repli.ok == 1 and f.build.repli.ko == 0, "etat : 1 pose")
  local nlog = #logs
  local again = Rpl.try(f, nil, g, ctx)
  check(again ~= nil and #logs == nlog and f.build.repli.ok == 1, "colle : la meme pose, refaite par une autre passe du plan, n'est ni recomptee ni reecrite")
  -- lots du treillis : un lot a nid recouvre la fenetre 0 : elle est ecartee
  local lx0, ly0 = P.lot_rect(lat, 0, 0)
  f.build.lots[P.lot_key(0, 0)] = { i = 0, j = 0, state = "refuse", reason = "nid" }
  logs = {}
  local p2 = Rpl.try(f, nil, g, ctx)
  check(p2 ~= nil and p2.ring >= 1 or (p2 ~= nil and p2.rect.x0 ~= place.rect.x0), "colle : le lot a nid ecarte la fenetre qu'il recouvre")
  -- site ecarte
  f.build.lots = {}
  f.build.avoid = { { x = 0, y = 0, r = 4 } }
  local p3 = Rpl.try(f, nil, g, ctx)
  check(p3 ~= nil and p3.ring >= 1, "colle : b.avoid ecarte la fenetre du centre")
  f.build.avoid = nil
  -- echec : rien de libre
  logs = {}
  local ctx_ko = { p = { id = 8 }, why = "place", center = { x = 0, y = 0 }, read_masks = function() return { free = function() return false end } end,
    ore_set = ore_set, avoid_margin = 8 }
  local pk, ck = Rpl.try(f, nil, g, ctx_ko)
  check(pk == nil and type(ck) == "string" and f.build.repli.ko == 1, "colle : echec compte")
  check(logs[1] and logs[1]:find("AUCUNE place de repli", 1, true) and logs[1]:find("cause du plan : place", 1, true), "journal d'echec : " .. tostring(logs[1]))
  -- interrupteur
  on = false
  local poff, coff = Rpl.try(f, nil, g, ctx)
  check(poff == nil and coff == "reglage eteint", "reglage eteint : rien")
  _G.settings = nil
  check(Rpl.on() == false, "reglage absent (moteur simule) : eteint, sans erreur")
  -- plafond des lignes
  _G.settings = { global = { ["fo-war-repli-place"] = { value = true } } }
  f.build.repli.n = Rp.LOGS
  logs = {}
  Rpl.try(f, nil, g, ctx_ko)
  check(#logs == 0, "plafond de lignes de journal par equipe : " .. Rp.LOGS)
  _G.settings, _G.game, _G.log = nil, nil, nil
end
total_pass, total_fail = total_pass + pass, total_fail + fail

--- §5 bis : le relevé du terrain couvre 8 tuiles autour de la fenêtre (eau ou falaise à 3 tuiles hors fenêtre connue du masque rendu).
local function check_releve(mod_path, label)
  local f_pass, f_fail = 0, 0
  local function chk(ok, msg) if ok then f_pass = f_pass + 1 else f_fail = f_fail + 1 if label == "reel" then print("[REPLI-PLACE] ECHEC : " .. msg) end end end
  _G.log = function() end
  _G.game = { tick = 9000 }
  _G.settings = { global = { ["fo-war-repli-place"] = { value = true } } }
  package.loaded["script.team.repli_place"] = nil
  local fh = assert(io.open(mod_path, "rb")); local src = fh:read("*a"); fh:close()
  if label ~= "reel" then
    local s1, e1 = src:find("rect.x0 - 8, rect.y0 - 8, rect.x1 + 8, rect.y1 + 8", 1, true)
    assert(s1, "motif du releve introuvable")
    src = src:sub(1, s1 - 1) .. "rect.x0 - 1, rect.y0 - 1, rect.x1 + 1, rect.y1 + 1" .. src:sub(e1 + 1)
  end
  local Rpl = assert(load(src, "=repli_glue", "t"))()
  local g = M.GEN.smelter("stone-furnace", "iron-ore", 4)
  local lat = P.lattice({ x = 0.5, y = 0.5 })
  local f = { key = "ecarlate", build = { lat = lat, lots = {} } }
  local W = Rp.windows(0, 0)[1] -- fenêtre 0
  local wx, wy = W.x0 - 3, W.y0 + 5 -- 3 tuiles hors de la fenêtre, à l'ouest
  local seen
  local function read_masks(_, _, x0, y0, x1, y1)
    seen = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    return { rect = seen, free = function(tx, ty)
      -- comme le moteur : l'eau n'est connue que dans la zone lue
      if tx == wx and ty == wy and tx >= x0 and tx < x1 and ty >= y0 and ty < y1 then return false end
      return true
    end }
  end
  local place = Rpl.try(f, nil, g, { p = { id = 3 }, why = "pas de lot", center = { x = 0, y = 0 }, read_masks = read_masks,
    ore_set = function() return {} end, avoid_margin = 8 })
  chk(place ~= nil, "releve : place trouvee")
  chk(place and place.masks.free(wx, wy) == false, "releve : l'eau a 3 tuiles hors de la fenetre est connue du masque rendu (zone lue +-8)")
  chk(seen and seen.x0 <= W.x0 - 8 and seen.y0 <= W.y0 - 8 and seen.x1 >= W.x1 + 8 and seen.y1 >= W.y1 + 8, "releve : zone lue = fenetre +-8 tuiles")
  return f_pass, f_fail
end
section("5 bis. Releve du terrain +-8 tuiles")
do
  local gp, gf = check_releve("script/team/repli_place.lua", "reel")
  total_pass, total_fail = total_pass + gp, total_fail + gf
  local _, mf = check_releve("script/team/repli_place.lua", "mutant")
  if mf > 0 then total_pass = total_pass + 1
  else total_fail = total_fail + 1 print("[REPLI-PLACE] ECHEC : le mutant « releve +-1 » SURVIT") end
  _G.settings, _G.game, _G.log = nil, nil, nil
end

---------------------------------------------------------------------------------------------------
-- 6. Mutants
---------------------------------------------------------------------------------------------------
section("6. Mutants")
do
  local fh = assert(io.open("shared/team/repli_place.lua", "rb"))
  local src = fh:read("*a")
  fh:close()
  local mutants = {
    { "anneaux a l'envers", "for r = 0, Rp.RINGS do", "for r = Rp.RINGS, 0, -1 do" },
    { "nid non ecarte", 'if st == "refuse" and Rp.SKIP_REASONS[why or ""] then return why end', "if false then end" },
    { "gisement non ecarte", 'if gis and not ctx.res then return "gisement" end', "if false then end" },
    { "danger non ecarte", 'if ctx.avoided and ctx.avoided(rect) then return "danger" end', "if false then end" },
    { "memoire des refus ignoree", 'if not why and Rp.recently_bad(ctx.bad, rect, ctx.tick) then why = "deja-refusee" end', "" },
    { "refus non memorise", "if ctx.bad then ctx.bad[Rp.key(rect)] = ctx.tick end", "" },
    { "plafond de fenetres lues retire", "if info.tried >= Rp.MAX_WINDOWS then break end", "" },
    { "marge nulle", "fopts.margin = Rp.MARGIN", "fopts.margin = 0" },
    { "fenetres qui se recouvrent", "Rp.STEP = P.LOT ", "Rp.STEP = 12 " },
    { "minerai ignore", "if ctx.res then fopts.ore = ores; fopts.foreign = ores and ores.foreign or nil end", "" },
    { "premiere fenetre au lieu du centre", "local x0 = floor(cx + dx * Rp.STEP - half + 0.5)", "local x0 = floor(cx + dx * Rp.STEP + 0.5)" },
  }
  for _, m in ipairs(mutants) do
    local s, e = src:find(m[2], 1, true)
    if not s then
      total_fail = total_fail + 1
      print("[REPLI-PLACE] ECHEC : mutant « " .. m[1] .. " » : motif introuvable dans la regle")
    else
      local msrc = src:sub(1, s - 1) .. m[3] .. src:sub(e + 1)
      local fn = assert(load(msrc, "=mutant", "t"))
      local Rm = fn()
      verbose = false
      local _, ff = run_all(Rm)
      verbose = true
      if ff > 0 then
        total_pass = total_pass + 1
      else
        total_fail = total_fail + 1
        print("[REPLI-PLACE] ECHEC : le mutant « " .. m[1] .. " » SURVIT (aucun controle ne le voit)")
      end
    end
  end
end

print(string.format("[REPLI-PLACE] BILAN : %d OK, %d ECHEC(S)", total_pass, total_fail))
os.exit(total_fail == 0 and 0 or 1)
