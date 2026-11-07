--[[
  Lot EXPERIMENTAUX-PUISSANCE (7/11) : FRAPPE SANS ALLOCATION des salves de zone (K.frappe), hors jeu. Lua 5.2, depuis la racine du mod :
      lua5.2 tests/xp_frappe_test.lua
  Mesure de design-attaques (7/11) et revue de la 0.6.57 : chaque lecture de `entity.force` crée un objet LuaForce ; K.hit en créait deux par
  coup (la force du tireur, celle de la cible), d'où des pics du ramasse-miettes. Charge le VRAI script/robots/experimentaux_commun.lua dans un
  monde bouché où toute lecture de `.force` est COMPTÉE :
    §1 K.frappe ne lit aucune force (ni de la cible, ni du tireur) : la cible par force_index, le tireur par son nom ;
    §2 égalité avec K.hit sur 300 cibles de 4 forces (ennemies, amie, en cessez-le-feu) : mêmes dégâts, mêmes tuées, mêmes comptes ;
    §3 K.ennemis : index des forces ennemies ; une cible d'une force non ennemie n'est pas touchée ;
    §4 la salve de zone frappe par K.frappe (source) ;
    §5 mutants refusés.
]]

package.path = "./?.lua;" .. package.path

local ok, bad = 0, 0
local function check(c, nom, detail)
  if c then ok = ok + 1 else bad = bad + 1; print("[XP-FRAPPE] ECHEC " .. nom .. " " .. tostring(detail or "")) end
end

local function lire(p)
  local f = assert(io.open(p, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = lire("script/robots/experimentaux_commun.lua")

local lectures = 0 -- lectures de `.force` sur une entité
local FORCES = {}
local function force(nom, index, ennemis)
  local f = { name = nom, index = index, ennemis = ennemis }
  f.is_enemy = function(other) return f.ennemis[other.name] == true end
  FORCES[nom] = f
  return f
end
local tireur_f = force("tireur", 1, { biters = true, rouges = true })
force("biters", 2, {})
force("amis", 3, {})
force("rouges", 4, {})
local INDEX = { "tireur", "biters", "amis", "rouges" }

--- Entité bouchée : `.force` compté (et rendu, pour K.hit), `.force_index` libre, damage qui retire les PV.
local function entite(fnom, pv, journal)
  local e = { valid = true, health = pv, destructible = true, force_index = FORCES[fnom].index }
  e.damage = function(amount, f, dtype, src)
    journal[#journal + 1] = type(f)
    local d = math.min(e.health, amount)
    e.health = e.health - d
    if e.health <= 0 then e.valid = false end
    return d
  end
  return setmetatable(e, { __index = function(_, k)
    if k == "force" then
      lectures = lectures + 1
      return FORCES[fnom]
    end
    return nil
  end })
end

local function charge(source)
  local store = { stats = {}, giants = {}, gjobs = {} }
  package.loaded["script.core.storage"] = { declare = function() end, ns = function() return store end }
  _G.log = function() end
  _G.game = { tick = 0, forces = setmetatable({}, { __index = function(_, k) return FORCES[k] end,
    __pairs = function() local i = 0 return function() i = i + 1 if INDEX[i] then return INDEX[i], FORCES[INDEX[i]] end end end }) }
  local f = assert(load(source, "=experimentaux_commun.lua"))
  return f(), store
end

local function scenario(source)
  local K = charge(source)
  -- 300 cibles de 4 forces, PV variés ; deux passes identiques : K.hit puis K.frappe
  local function cibles(journal)
    local out = {}
    for i = 1, 300 do
      local fnom = ({ "biters", "rouges", "amis", "tireur" })[i % 4 + 1]
      out[i] = entite(fnom, 50 + (i * 37) % 400, journal)
    end
    return out
  end
  local jh, jf, jr = {}, {}, {}
  local ch, cf, cr = cibles(jh), cibles(jf), cibles(jr)
  local tir = entite("tireur", 1000, {})
  local sh, sf = { degats = 0, cibles = 0, tues = 0 }, { degats = 0, cibles = 0, tues = 0 }
  local K_S = K.S()
  K_S.stats.h, K_S.stats.f = sh, sf
  -- référence : l'ancien K.hit (force.is_enemy(e.force), une LuaForce par cible)
  local tr, nr, kr = 0, 0, 0
  for i = 1, 300 do
    local x = cr[i]
    if x.valid and x.health and x.destructible and tireur_f.is_enemy(x.force) then
      local avant = x.health
      tr = tr + x.damage(200, tireur_f, "laser", tir)
      nr = nr + 1
      if avant > 0 and (not x.valid or x.health <= 0) then kr = kr + 1 end
    end
  end
  local th, tf = 0, 0
  lectures = 0
  for i = 1, 300 do th = th + K.hit({ id = "h" }, ch[i], 200, "laser", tireur_f, tir) end
  local lect_hit = lectures
  local noms = K.enemy_forces(tireur_f)
  local en = K.ennemis_du_tick("tireur")
  lectures = 0
  for i = 1, 300 do tf = tf + K.frappe(sf, cf[i], 200, "laser", "tireur", tir, en) end
  -- paix déclarée en pleine salve (décision du lead, 7/11) : comptée dès le tick suivant, pour K.frappe comme pour K.hit
  local journal = {}
  local rouge1, rouge2, bit = entite("rouges", 1000, journal), entite("rouges", 1000, journal), entite("biters", 1000, journal)
  local st = { degats = 0, cibles = 0, tues = 0 }
  _G.game.tick = 10
  local avant = K.frappe(st, rouge1, 100, "laser", "tireur", tir, K.ennemis_du_tick("tireur"))
  tireur_f.ennemis.rouges = nil -- paix (ou cessez-le-feu) entre le tireur et les rouges
  _G.game.tick = 11
  local apres = K.frappe(st, rouge2, 100, "laser", "tireur", tir, K.ennemis_du_tick("tireur"))
  local apres_hit = K.hit({ id = "f" }, rouge2, 100, "laser", tireur_f, tir)
  local bit_apres = K.frappe(st, bit, 100, "laser", "tireur", tir, K.ennemis_du_tick("tireur"))
  tireur_f.ennemis.rouges = true
  _G.game.tick = 0
  return { th = th, tf = tf, tr = tr, nr = nr, kr = kr, sh = sh, sf = sf, lect_hit = lect_hit, lect_frappe = lectures, jf = jf, noms = noms, en = en, K = K,
    paix = { avant = avant, apres = apres, apres_hit = apres_hit, bit = bit_apres } }
end

local R = scenario(SRC)
check(R.lect_frappe == 0, "§1 K.frappe ne lit aucune force (cible par force_index, tireur par son nom)", tostring(R.lect_frappe))
check(R.lect_hit == 0, "§1 K.hit non plus : ennemis du tireur par index, mémorisés pour le tick", tostring(R.lect_hit))
local types_ok = #R.jf > 0
for _, t in ipairs(R.jf) do if t ~= "string" then types_ok = false end end
check(types_ok, "§1 damage reçoit le NOM de la force qui tire (aucun objet LuaForce)")
check(R.th == R.tr and R.tf == R.tr and R.tr > 0 and R.sh.cibles == R.nr and R.sf.cibles == R.nr and R.sh.tues == R.kr and R.sf.tues == R.kr,
  "§2 égalité avec l'ancien K.hit (is_enemy) : K.hit et K.frappe, mêmes dégâts, mêmes cibles touchées, mêmes tuées",
  string.format("dégâts %d / %d / %d, tuées %d / %d / %d", R.tr, R.th, R.tf, R.kr, R.sh.tues, R.sf.tues))
check(#R.noms == 2 and R.noms[1] == "biters" and R.noms[2] == "rouges" and R.en[2] and R.en[4] and not R.en[3] and not R.en[1],
  "§3 K.ennemis : index des forces ennemies seulement (ni amie, ni elle-même)")
check(R.sf.cibles == 150, "§3 seules les cibles des forces ennemies sont touchées (150 sur 300)", tostring(R.sf.cibles))
check(R.paix.avant == 100 and R.paix.apres == 0 and R.paix.apres_hit == 0 and R.paix.bit == 100,
  "§3 paix déclarée en pleine salve : la force devenue amie n'est plus frappée dès le tick suivant (K.frappe et K.hit), les autres oui",
  string.format("%s %s %s %s", R.paix.avant, R.paix.apres, R.paix.apres_hit, R.paix.bit))

-- §4 la salve de zone frappe par K.frappe (source)
local SXG = lire("script/robots/experimentaux_geants.lua")
check(SXG:find("j.total = j.total + K.frappe(st_r, t, j.salve, j.dtype, fid, e, en)", 1, true) ~= nil
  and not SXG:find("K.hit(r, t, j.salve", 1, true) and not SXG:find("j.ennemis", 1, true)
  and SXG:find("local st_r, fid, en = K.stat(j.id), j.force, K.ennemis_du_tick(j.force)", 1, true) ~= nil,
  "§4 salve de zone : K.frappe, ennemis relus à chaque tick (K.ennemis_du_tick), jamais gardés dans le job")

-- §5 mutants
local MUTANTS = {
  { "force de la cible lue comme objet", "or not ennemis[e.force_index] then return 0 end", "or not ennemis[e.force.index] then return 0 end" },
  { "forces ennemies ignorées", "or not ennemis[e.force_index] then return 0 end", "then return 0 end" },
  { "tuées non comptées", "  if before > 0 and (not e.valid or e.health <= 0) then st.tues = st.tues + 1 end\n  return dealt\nend\n\n--- Index",
    "  return dealt\nend\n\n--- Index" },
  { "ennemis : toutes les forces", "    if f then out[f.index] = true end", "    out[1], out[2], out[3], out[4] = true, true, true, true" },
  { "K.hit relit la force de chaque cible", "  if not ennemis_de(force)[e.force_index] then return 0 end", "  if not force.is_enemy(e.force) then return 0 end" },
  { "ennemis jamais relus (salve entière)", "  if t ~= memo_tick then memo_tick, memo = t, {} end", "  if memo_tick < 0 then memo_tick, memo = t, {} end" },
  { "K.hit sans contrôle des ennemis", "  if not ennemis_de(force)[e.force_index] then return 0 end", "" },
}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    check(false, "§5 mutant introuvable : " .. m[1])
  else
    local src = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local okm, Rm = pcall(scenario, src)
    local passe = okm and Rm.lect_frappe == 0 and Rm.lect_hit == 0 and Rm.th == Rm.tr and Rm.tf == Rm.tr and Rm.sh.tues == Rm.kr and Rm.sf.tues == Rm.kr
      and Rm.sf.cibles == 150 and Rm.en[2] and not Rm.en[3] and Rm.paix.apres == 0 and Rm.paix.apres_hit == 0 and Rm.paix.bit == 100
    check(not passe, "§5 mutant refusé : " .. m[1])
  end
end

print(string.format("[XP-FRAPPE] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and 0 or 1)
