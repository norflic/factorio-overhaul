--[[
  Lot ÉTAGE 5 (5/11) : test hors jeu de shared/team/couloir.lua (couloir d'accès réservé des avant-postes) et de ses lecteurs.
    §1 géométrie (Co.tiles) : droit, en L, côté de la largeur, longueur, arrêt avant le QG, tri, sans doublon ; §2 couloirs d'une équipe
    (Co.team_tiles) ; §3 le bâtiment qui ferme la dernière issue (Co.closer) ; §4 câblage (quatre lecteurs, tapis qui traversent, journal,
    interrupteur) ; §5 mutants de la règle ; §6 Build.reserved_entity au moteur simulé (et ses mutants) ; §7 aucun nom d'objet.
  Usage : lua5.2 tests/couloir_test.lua   (depuis la racine du mod ; quelques secondes)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/couloir.lua")
local function load_co(src)
  package.loaded["shared.team.acces_champ"] = nil
  local fn = load(src, "=couloir", "t")
  if not fn then return nil end
  local ok, m = pcall(fn)
  return ok and m or nil
end

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[COULOIR] ECHEC : " .. name) end
end

local function has(list, x, y)
  for _, t in ipairs(list) do if t.x == x and t.y == y then return true end end
  return false
end

local function suite(Co)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  -- §1 géométrie
  local e = Co.tiles(0.5, 0.5, 50.5, 0.5)
  c("droit vers l'est : 36 tuiles de chemin x 2 de large", #e == 72 and has(e, 0, 0) and has(e, 0, 1) and has(e, 35, 0) and has(e, 35, 1))
  c("droit : longueur Co.LEN, pas au-dela", not has(e, 36, 0) and Co.LEN == 35)
  local up = Co.tiles(0, 0, 50, -5)
  c("largeur du cote du QG sur l'autre axe (QG au nord : rangee y-1)", has(up, 10, -1) and not has(up, 10, 1))
  local near = Co.tiles(0, 0, 10, 0)
  c("QG proche : arret a Co.HQ_GAP du QG", has(near, 2, 0) and not has(near, 3, 0) and Co.HQ_GAP >= 4)
  local l = Co.tiles(0, 0, -10, 30)
  c("en L : axe dominant (y) d'abord, puis l'autre (x)", has(l, 0, 30) and has(l, -1, 30) and has(l, -2, 30) and has(l, -2, 31)
    and not has(l, -1, 0) == false)
  local sorted, dup, seen = true, false, {}
  for i, t in ipairs(l) do
    local k = t.x .. "," .. t.y
    if seen[k] then dup = true end
    seen[k] = true
    if i > 1 then
      local p = l[i - 1]
      if p.y > t.y or (p.y == t.y and p.x >= t.x) then sorted = false end
    end
  end
  c("tuiles triees (y, puis x), sans doublon", sorted and not dup)
  local same = Co.tiles(0, 0, -10, 30)
  local eq = #same == #l
  for i = 1, #l do if not (same[i] and same[i].x == l[i].x and same[i].y == l[i].y) then eq = false end end
  c("deterministe", eq)
  c("acces sur le QG : la seule tuile de l'acces", #Co.tiles(3, 3, 3, 3) == Co.WIDTH)
  c("largeur de 2 tuiles", Co.WIDTH == 2)
  -- §2 couloirs d'une équipe
  local tt = Co.team_tiles({ [2] = { access = { x = 0, y = 0 } }, [1] = { access = { x = 0, y = 1 } }, [4] = { access = { x = 0, y = 10 } },
    [3] = { pos = { x = 0, y = 20 } } }, { x = 50, y = 0 })
  local first = {}
  for _, t in ipairs(tt) do if not first[t.x .. "," .. t.y] then first[t.x .. "," .. t.y] = t.id end end
  c("equipe : avant-poste sans acces : pas de couloir ; tuile commune gardee par le premier id", first["0,1"] == 1 and first["0,0"] == 1
    and first["0,10"] == 4 and first["0,9"] == 4
    and (function() for _, t in ipairs(tt) do if t.id == 3 then return false end end return true end)())
  local tt_n = 0
  for _ in pairs(first) do tt_n = tt_n + 1 end
  c("equipe : sans doublon", tt_n == #tt)
  -- §3 dernière issue : accès (5,5) cerné par 8 obstacles d'une tuile ; un coin retiré ne rouvre pas (4-voisinage), un côté si
  local boxes = {}
  local idx = {}
  for _, d in ipairs({ { 4, 4 }, { 5, 4 }, { 6, 4 }, { 4, 5 }, { 6, 5 }, { 4, 6 }, { 5, 6 }, { 6, 6 } }) do
    boxes[#boxes + 1] = { d[1], d[2], d[1] + 1, d[2] + 1 }
    idx[d[1] .. "," .. d[2]] = #boxes
  end
  local rect = { 0, 0, 10, 10 }
  local acc = { x = 5.5, y = 5.5 }
  c("dernier ferme : le plus recent qui rouvre (le coin ne rouvre pas)",
    Co.closer(boxes, {}, acc, rect, { idx["4,4"], idx["5,4"], idx["6,5"] }) == idx["5,4"])
  c("dernier ferme : aucun retrait seul ne suffit -> nil", Co.closer(boxes, {}, acc, rect, { idx["4,4"], idx["6,6"] }) == nil)
  local many = {}
  for _ = 1, Co.CLOSER_TRIES do many[#many + 1] = idx["4,4"] end
  many[#many + 1] = idx["5,4"]
  c("dernier ferme : au plus Co.CLOSER_TRIES essais", Co.closer(boxes, {}, acc, rect, many) == nil)
  return res
end

local Co = assert(load_co(SRC), "module illisible")
for _, r in ipairs(suite(Co)) do check(r[1], r[2]) end

-- §4 câblage
local B = read("script/team/build.lua")
local CH = read("script/team/champ.lua")
local W = read("script/team/worker.lua")
check("lecteur 1 : Build.reserved_entity (agrandissements, tourelles)", B:find("if (occ and occ[k]) or cor[k] then return true end", 1, true) ~= nil
  and B:find("Outposts.reserved = function(f, name, pos, dir) return Build.reserved_entity(f, name, pos, dir) end", 1, true) ~= nil)
check("lecteur 2 : read_masks free() (modules, poteaux du plan)", B:find("return not water[k] and not blocked[k] and not b.occ[k] and not cor[k]", 1, true) ~= nil)
check("lecteur 3 : vue des poteaux en cache", B:find("return not b.occ[k] and not cor[k]", 1, true) ~= nil)
check("lecteur 4 : masque de la migration du champ", CH:find('if cor[k] and not blocked[Ch.key(x, y)] then blocked[Ch.key(x, y)] = "couloir" end', 1, true) ~= nil)
check("les tapis traversent (cout du tapis sans couloir)", B:find("if masks.water[k] or masks.blocked[k] or b.occ[k] or planned[k] then return nil end", 1, true) ~= nil)
check("interrupteur de banc f.team.couloir_off", B:find("(f.team and f.team.couloir_off) then return NO_COULOIR end", 1, true) ~= nil)
check("journal : derniere issue fermee par", W:find("derniere issue fermee par %s", 1, true) ~= nil and W:find("Co.closer(boxes, tiles, base, rect, order)", 1, true) ~= nil)

-- §5 mutants de la règle
local MUTANTS = {
  { "largeur ignoree", "for k = 0, width - 1 do", "for k = 0, 0 do" },
  { "largeur du mauvais cote", "if along_x then add(px, py + k * sy) else add(px + k * sx, py) end", "if along_x then add(px, py - k * sy) else add(px - k * sx, py) end" },
  { "longueur sans borne", "local budget = math.min(len, math.max(0, math.abs(dx) + math.abs(dy) - Co.HQ_GAP))", "local budget = math.max(0, math.abs(dx) + math.abs(dy) - Co.HQ_GAP)" },
  { "jusqu'au QG", "math.abs(dx) + math.abs(dy) - Co.HQ_GAP))", "math.abs(dx) + math.abs(dy)))" },
  { "axe dominant ignore", "local x_first = math.abs(dx) >= math.abs(dy)", "local x_first = true" },
  { "sans tri", "table.sort(out, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)", "" },
  { "pas de second troncon", "local n2 = math.min(budget - n1, x_first and math.abs(dy) or math.abs(dx))", "local n2 = 0" },
  { "sans acces : couloir depuis le centre de l'avant-poste", "local a = outposts[id].access", "local a = outposts[id].access or outposts[id].pos" },
  { "dernier ferme : ordre ignore", "if n > Co.CLOSER_TRIES then return nil end", "if n > 1e9 then return nil end" },
  { "dernier ferme : poche acceptee", "if not r.moved and not r.enclosed then return i end", "if true then return i end" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local mut = load_co(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local seen = mut == nil
    if not seen then
      local okm, res = pcall(suite, mut)
      if not okm then seen = true else for _, r in ipairs(res) do if not r[2] then seen = true break end end end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants de la regle refuses %d/%d%s", refused, #MUTANTS, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""),
  refused == #MUTANTS)
package.loaded["shared.team.couloir"] = nil

-- §6 Build.reserved_entity au moteur simulé : une emprise sur le couloir est réservée, à côté non ; interrupteur.
local Mk = require("tests.mock_engine")
local function moteur(build_src)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  if build_src then package.preload["script.team.build"] = function() return assert(load(build_src, "=build", "t"))() end end
  local okg, err = pcall(function()
    Mk.new_game({ patches = { { x = 60, y = 0, name = "coal" } }, p_busy = 0, p_nopath = 0, p_lost = 0, seed = 3 })
    local s = game.surfaces[1]
    local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
    Mk.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
    Mk.run_ticks(120)
  end)
  package.preload["script.team.build"] = nil
  if not okg then c("partie au moteur simule : " .. tostring(err), false) return res end
  local Build = require("script.team.build")
  local f = global.fo.pteam.team
  c("equipe avec un QG", f and f.hq_pos ~= nil)
  if not (f and f.hq_pos) then return res end
  local saved = f.outposts
  local ax, ay = f.hq_pos.x + 40, f.hq_pos.y
  f.outposts = { [7] = { access = { x = ax, y = ay } } }
  local on = Build.reserved_entity(f, "stone-furnace", { x = ax - 10, y = ay + 1 })
  local off = Build.reserved_entity(f, "stone-furnace", { x = ax - 10, y = ay + 6 })
  c("emprise sur le couloir : reservee", on == true)
  c("emprise a cote du couloir : libre", off == false)
  f.team.couloir_off = true
  c("interrupteur : couloir coupe", Build.reserved_entity(f, "stone-furnace", { x = ax - 10, y = ay + 1 }) == false)
  f.team.couloir_off = nil
  f.outposts = { [7] = { access = { x = ax, y = ay } }, [8] = { access = { x = ax, y = ay - 20 } } }
  c("cache refait quand un acces change", Build.reserved_entity(f, "stone-furnace", { x = ax - 10, y = ay - 19 }) == true)
  f.outposts = saved
  return res
end
for _, r in ipairs(moteur(nil)) do check("moteur : " .. r[1], r[2]) end
local BMUT = {
  { "reserved_entity sans couloir", "if (occ and occ[k]) or cor[k] then return true end", "if occ and occ[k] then return true end" },
  { "cache jamais refait", "if c and c.sig == s then return c.set end", "if c then return c.set end" },
  { "interrupteur ignore", "(f.team and f.team.couloir_off) then return NO_COULOIR end", "false then return NO_COULOIR end" },
}
local bref, bkept = 0, {}
for _, m in ipairs(BMUT) do
  local a, b = B:find(m[2], 1, true)
  if not a then
    bkept[#bkept + 1] = m[1] .. " (motif introuvable)"
  else
    local seen = false
    local okm, res = pcall(moteur, B:sub(1, a - 1) .. m[3] .. B:sub(b + 1))
    if not okm then seen = true else for _, r in ipairs(res) do if not r[2] then seen = true break end end end
    if seen then bref = bref + 1 else bkept[#bkept + 1] = m[1] end
  end
end
check(string.format("moteur : mutants de build.lua refuses %d/%d%s", bref, #BMUT, #bkept > 0 and (" ; survivants : " .. table.concat(bkept, ", ")) or ""),
  bref == #BMUT)

-- §7 aucun nom d'objet du jeu dans la règle
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
local found = {}
for _, n in ipairs({ "coal", "stone", "iron", "copper", "chest", "furnace", "drill", "plate", "ore", "belt", "turret" }) do
  if code:find('"' .. n, 1, true) or code:find(n .. '"', 1, true) then found[#found + 1] = n end
end
check("aucun nom d'objet dans la regle" .. (#found > 0 and (" : " .. table.concat(found, ",")) or ""), #found == 0)

print(string.format("[COULOIR] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
