--[[
  Lot CAPI-DECIDE (7/11) : la décision de capitalisation (Ca.decide, capi:decide) reprenable en tranches, une par tick, dans l'étape
  E1b de la pensée (script/ai3/capitalisation.lua, shared/ai3/capitalisation.lua). Critères : fo-logs/2026-11-07_CAPI-DECIDE/CRITERES.md.

  Partie de banc au moteur simulé (même montage que tests/decoupage_pensee_test.lua, capitalisation allumée : FO_CAPI=1). Chaque
  passage est un PROCESSUS à part :
    lua5.2 tests/capi_decide_test.lua --run <mode> <minutes> <sortie>
  modes : bloc (tout au tick T), etapes (pensée en étapes, décision en tranches), charge (etapes, sauvegarde et chargement simulés à
  CHAQUE tick où une décision attend, mémoire du module vidée comme par un vrai chargement).
  Environnement : FO_CD_MUT=cle|vivant|st_tot|journal_tot|bonus (mutants du module) ; FO_CD_INJ=stock|bonus|snap (changements faits
  entre deux tranches par le banc : stock de la vue gardée, bonus d'une autre force dans D.bonus, instantané changé d'une autre
  décision) ; FO_CD_OUBLI=1 (avec snap : la mémoire est vidée au même moment, référence).
  Sorties : <sortie>_global.txt, _journal.txt, _info.txt.

  Sans argument, le banc complet (une partie à la fois, moins de 8 lua sur le PC ; jamais de relance d'un passage tué) :
    C0 contrôle statique (unités pures : ni log, ni game, ni global) ;
    C2 rien ne sort avant la dernière tranche (état de capitalisation inchangé et aucune ligne de la décision aux tranches
       intermédiaires) ;
    C3 sauvegarde et chargement à chaque tick de tranche = partie continue, octet à octet ; décisions découpées comptées ;
    C4 mutants : cle, vivant, st_tot, journal_tot, bonus.
  L'A/B C1 « mode bloc = ancien code » se joue à part (ancien code dans un autre dossier : voir CRITERES.md).
]]
package.path = "./?.lua;" .. package.path

local SELF = debug.getinfo(1, "S").source:sub(2)
local LUA = arg[-1] or "lua5.2"

local function run(mode, min, out)
  local M = require("tests.mock_engine")
  local function patches()
    local o = {}
    local d = 0.7071
    local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
    local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
      { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for _, c in ipairs(corners) do
      local hx, hy = c[1] * 320, c[2] * 320
      for ri, r in ipairs({ 40, 64, 88 }) do
        for di, v in ipairs(dirs) do
          o[#o + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
        end
      end
    end
    for i = 0, 11 do
      local a = i * math.pi / 6
      o[#o + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
    end
    return o
  end
  local PONDS = {}
  do
    local d = 0.7071
    for _, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do PONDS[#PONDS + 1] = { x = c[1] * 320 + 30, y = c[2] * 320 + 2 } end
  end
  local function tile_at(x, y)
    for _, q in ipairs(PONDS) do
      local dx, dy = x + 0.5 - q.x, y + 0.5 - q.y
      if dx * dx + dy * dy <= 49 then return "water" end
    end
    return "grass-1"
  end
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, ia3e = true, capi = true, tile_at = tile_at })
  local W = M.world()
  local Team = require("script.team.team")
  local Capi = require("script.ai3.capitalisation")
  local State = require("script.faction.state")
  Team.ETAPES = (mode ~= "bloc")
  local mut = os.getenv("FO_CD_MUT")
  if mut and mut ~= "" then Capi.MUT[mut] = true end
  local inj = os.getenv("FO_CD_INJ")
  local oubli = os.getenv("FO_CD_OUBLI") == "1"

  for _, p in pairs(W.prototypes) do if p.has_flag == nil then p.has_flag = function() return false end end end
  W.settings["fo-recruit-idle-max"] = 60
  W.settings["fo-war-workers"] = 4
  assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
  remote.call("factorio-overhaul", "war_fund", 3000)
  do
    local s = game.surfaces[1]
    local find = s.find_tiles_filtered
    s.count_tiles_filtered = function(t)
      if t.collision_mask ~= "water-tile" then return 0 end
      local area, cx, cy, r2 = t.area, nil, nil, nil
      if not area then
        local p, r = t.position, t.radius
        cx, cy, r2 = p.x or p[1], p.y or p[2], r * r
        area = { { math.floor(cx - r), math.floor(cy - r) }, { math.ceil(cx + r), math.ceil(cy + r) } }
      end
      local n = 0
      for _, tl in ipairs(find({ area = area, collision_mask = "water-tile" })) do
        local ok = true
        if r2 then local dx, dy = tl.position.x + 0.5 - cx, tl.position.y + 0.5 - cy; ok = dx * dx + dy * dy <= r2 end
        if ok then n = n + 1; if t.limit and n >= t.limit then return n end end
      end
      return n
    end
  end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 2 }, { "firearm-magazine", 40 }, { "burner-mining-drill", 6 }, { "stone-furnace", 6 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W.events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local Build = require("script.team.build")
  M.run_ticks(120)
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    Build.enable(f, { radius = 3 })
    Build.plant(f)
    Build.request(f, { gen = "gears", args = { 2, "assembling-machine-1" }, feed = true, prio = 60 })
    Build.request(f, { gen = "simple", args = { "iron-gear-wheel", 1, "assembling-machine-1" }, feed = true, prio = 55 })
  end

  local function teams()
    local list = {}
    for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
    local p = State.faction("player")
    if p then list[#list + 1] = p end
    return list
  end
  local function restore(copy)
    for k in pairs(global) do global[k] = nil end
    local c = M.deepcopy_global(copy)
    for k, v in pairs(c) do global[k] = v end
  end
  local PREFIX = { "[FO-CAPI]", "[FO-CAPI-REPLI]", "[FO-DEMANDE]", "[FO-CERVEAU]", "[FO-RESERVE]", "[FO-CAPI-COUV]" }
  local function capi_lines(from, key)
    local n = 0
    for i = from, #W.logs do
      local l = tostring(W.logs[i])
      for _, p in ipairs(PREFIX) do
        if l:sub(1, #p) == p and l:find(" " .. tostring(key) .. " ", 1, true) then n = n + 1 break end
      end
    end
    return n
  end

  local info = { sliced = 0, slices = 0, c2_cs = 0, c2_log = 0, loads = 0, decisions = 0, inj = 0, abort = 0 }
  local seen_seq = {}
  local snap_done = {}
  local total = min * 3600
  for _ = 1, total do
    -- avant le tick : décisions en cours et état de capitalisation de chaque équipe
    local before = {}
    for _, f in ipairs(teams()) do
      local cs = f.team and f.team.capi
      if cs and cs.dj then before[f] = { seq = cs.dj.seq, ser = M.serialize(cs), log0 = #W.logs + 1 } end
    end
    M.run_ticks(1)
    local pending = false
    for _, f in ipairs(teams()) do
      local cs = f.team and f.team.capi
      local b = before[f]
      if cs and cs.dj then
        pending = true
        local key = tostring(f.key or "player") .. ":" .. cs.dj.seq
        if not seen_seq[key] then seen_seq[key] = true; info.sliced = info.sliced + 1 end
        if b and b.seq == cs.dj.seq then
          -- tranche INTERMÉDIAIRE dans ce tick : rien n'est sorti de l'état de travail
          info.slices = info.slices + 1
          if M.serialize(cs) ~= b.ser then info.c2_cs = info.c2_cs + 1 end
          info.c2_log = info.c2_log + capi_lines(b.log0, f.key)
        end
        -- changements faits par le banc entre deux tranches
        if inj == "stock" and f.team.etape and f.team.etape.view and f.team.etape.view.stock then
          local st = f.team.etape.view.stock
          st["iron-plate"] = (st["iron-plate"] or 0) + 5000
          st["copper-plate"] = (st["copper-plate"] or 0) + 5000
          info.inj = info.inj + 1
        elseif inj == "bonus" then
          local D = Capi.data()
          D.bonus.mining, D.bonus.lab = 9, 9
          info.inj = info.inj + 1
        elseif inj == "snap" and b and b.seq == cs.dj.seq and not snap_done[f] and cs.decisions and cs.decisions >= 2 then
          -- une AUTRE décision (instantané changé, autre numéro) chargée en place de celle que la mémoire tient
          snap_done[f] = true
          local sti = cs.dj.input.stock
          for _, k in ipairs({ "iron-plate", "copper-plate", "stone", "coal" }) do sti[k] = (sti[k] or 0) + 20000 end
          cs.dj.seq = cs.dj.seq + 1000
          if oubli then Capi.forget_memory() end
          info.inj = info.inj + 1
        end
      elseif b then
        info.decisions = info.decisions + 1
      end
    end
    if mode == "charge" and pending then
      restore(M.deepcopy_global(global))
      Capi.forget_memory()
      info.loads = info.loads + 1
    end
  end
  for _, l in ipairs(W.logs) do if tostring(l):find("abandonnee", 1, true) and tostring(l):sub(1, 9) == "[FO-CAPI]" then info.abort = info.abort + 1 end end

  local function wr(suffix, text)
    local h = assert(io.open(out .. suffix, "w"))
    h:write(text)
    h:close()
  end
  wr("_global.txt", M.serialize(global))
  local jl = {}
  for _, l in ipairs(W.logs) do jl[#jl + 1] = tostring(l) end
  wr("_journal.txt", table.concat(jl, "\n"))
  local il = {}
  for _, k in ipairs({ "sliced", "slices", "decisions", "c2_cs", "c2_log", "loads", "inj", "abort" }) do il[#il + 1] = k .. " " .. info[k] end
  local ndec = 0
  for _, l in ipairs(W.logs) do if tostring(l):match("^%[FO%-CAPI%] %S+ minute") then ndec = ndec + 1 end end
  il[#il + 1] = "lignes_decision " .. ndec
  wr("_info.txt", table.concat(il, "\n"))
  print("[CAPI-DECIDE-RUN] " .. mode .. " fini")
end

if arg[1] == "--run" then
  run(arg[2], tonumber(arg[3]), arg[4])
  return
end

---------------------------------------------------------------------------------------------------
-- Banc complet
---------------------------------------------------------------------------------------------------
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local TMP = os.getenv("FO_TMP") or os.getenv("TEMP") or "."
local LUA_MAX = tonumber(os.getenv("FO_LUA_MAX") or "") or 8
local MIN = tonumber(os.getenv("FO_MIN") or "") or 10
local function lua_count()
  local h = io.popen('powershell -NoProfile -Command "@(Get-Process lua5.2 -ErrorAction SilentlyContinue).Count"')
  local n = tonumber((h:read("*a") or ""):match("%d+")) or LUA_MAX
  h:close()
  return n
end
local function slurp(path)
  local h = io.open(path, "r")
  if not h then return nil end
  local t = h:read("*a")
  h:close()
  return t
end
--- Un passage : env = { NOM = valeur } ; rend (fini, sortie, texte). Jamais relancé s'il est tué.
local function sub(mode, min, tag, env)
  local out = TMP .. "/capidecide_" .. tag
  local sets = {}
  for _, k in ipairs({ "FO_CD_MUT", "FO_CD_INJ", "FO_CD_OUBLI" }) do
    sets[#sets + 1] = string.format('set "%s=%s" && ', k, (env and env[k]) or "")
  end
  local cmd = string.format('%s%s %s --run %s %s "%s" 2>&1', table.concat(sets), LUA, SELF, mode, min, out)
  while lua_count() >= LUA_MAX do os.execute("ping -n 16 127.0.0.1 > nul") end
  local h = io.popen(cmd)
  local text = h:read("*a")
  h:close()
  local ok = text:find("[CAPI-DECIDE-RUN] " .. mode .. " fini", 1, true) ~= nil
  if not text:find("%S") then text = "(passage tué de l'extérieur, sans sortie : non relancé)" end
  return ok, out, text
end
local function info_of(out)
  local t = {}
  for k, v in (slurp(out .. "_info.txt") or ""):gmatch("(%S+) (%d+)") do t[k] = tonumber(v) end
  return t
end
local function same(a, b)
  local ga, gb = slurp(a .. "_global.txt"), slurp(b .. "_global.txt")
  local ja, jb = slurp(a .. "_journal.txt"), slurp(b .. "_journal.txt")
  return ga ~= nil and ga == gb and ja ~= nil and ja == jb, ga == gb, ja == jb
end

section("C0. Contrôle statique : les unités de la décision sont pures (ni log, ni game, ni global)")
for _, path in ipairs({ "shared/ai3/capitalisation.lua", "shared/ai3/leviers.lua", "shared/ai3/demande.lua", "shared/team/gisement.lua",
  "shared/ai3/reglages.lua", "shared/content/module_mult.lua" }) do
  local src = slurp(path) or ""
  src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", ""):gsub('"[^"\n]*"', '""')
  local bad = {}
  if src:find("%f[%w_]log%s*%(") then bad[#bad + 1] = "log" end
  if src:find("%f[%w_]game%s*[%.%[]") then bad[#bad + 1] = "game" end
  if src:find("%f[%w_]global%f[^%w_]") then bad[#bad + 1] = "global" end
  check(#bad == 0, path .. " : " .. table.concat(bad, ", "))
end
do -- mutant du contrôle : un log dans un source
  local src = ("local x = 1\nlog(\"x\")\n"):gsub("%-%-[^\n]*", ""):gsub('"[^"\n]*"', '""')
  check(src:find("%f[%w_]log%s*%(") ~= nil, "mutant : un log() dans un module pur est vu")
end

section("C2 et C3. Mode étapes, puis sauvegarde et chargement à chaque tick de tranche (" .. MIN .. " min)")
local oke, oe, te = sub("etapes", MIN, "etapes")
local okc, oc, tc = sub("charge", MIN, "charge")
check(oke and okc, "parties jouées" .. ((oke and okc) and "" or (" : " .. (oke and tc or te):sub(-400))))
local ie, ic = info_of(oe), info_of(oc)
print(string.format("  étapes : %d décision(s) découpée(s), %d tranche(s) intermédiaire(s), %d ligne(s) de décision ; charge : %d chargement(s)",
  ie.sliced or 0, ie.slices or 0, ie.lignes_decision or 0, ic.loads or 0))
check((ie.sliced or 0) >= 20 and (ie.slices or 0) >= 20, "au moins 20 décisions découpées en au moins 2 tranches")
check((ie.c2_cs or -1) == 0, "état de capitalisation inchangé à chaque tranche intermédiaire (" .. tostring(ie.c2_cs) .. ")")
check((ie.c2_log or -1) == 0, "aucune ligne de la décision avant sa dernière tranche (" .. tostring(ie.c2_log) .. ")")
local all, g_ok, j_ok = same(oe, oc)
check(all, "chargement à chaque tick de tranche (mémoire vidée) = partie continue (global " .. tostring(g_ok) .. ", journal " .. tostring(j_ok) .. ")")
check((ic.loads or 0) >= 40, "chargements à des ticks de tranche (" .. tostring(ic.loads) .. ")")

section("C4. Mutants (3 min chacun)")
-- clé ignorée : une autre décision (instantané changé, autre numéro) chargée pendant que la mémoire tient l'ancienne
local okr, orr = sub("etapes", 3, "snap_ref", { FO_CD_INJ = "snap", FO_CD_OUBLI = "1" })
local okn, on = sub("etapes", 3, "snap_norm", { FO_CD_INJ = "snap" })
local okm, om = sub("etapes", 3, "snap_mut", { FO_CD_INJ = "snap", FO_CD_MUT = "cle" })
check(okr and okn and okm and (info_of(orr).inj or 0) >= 1, "parties « autre décision chargée » jouées (" .. tostring(info_of(orr).inj) .. " instantané(s) changé(s))")
check(okr and okn and same(on, orr), "clé vérifiée : l'autre décision est refaite depuis son instantané (= mémoire vidée)")
check(okr and okm and not same(om, orr), "mutant « clé ignorée » refusé : la mémoire d'avant lue après le chargement change le résultat")
-- entrée vivante : le stock de la vue gardée change entre deux tranches
local ok1, o1 = sub("etapes", 3, "viv_e", { FO_CD_INJ = "stock" })
local ok2, o2 = sub("charge", 3, "viv_c", { FO_CD_INJ = "stock" })
local ok3, o3 = sub("etapes", 3, "viv_me", { FO_CD_INJ = "stock", FO_CD_MUT = "vivant" })
local ok4, o4 = sub("charge", 3, "viv_mc", { FO_CD_INJ = "stock", FO_CD_MUT = "vivant" })
check(ok1 and ok2 and same(o1, o2), "stock changé entre deux tranches : continue = chargée (la décision ne lit que l'instantané)")
check(ok3 and ok4 and not same(o3, o4), "mutant « entrée vivante » refusé (continue et chargée diffèrent)")
-- st avancé dès la première tranche
local ok5, o5 = sub("etapes", 3, "st_e", { FO_CD_MUT = "st_tot" })
local ok6, o6 = sub("charge", 3, "st_c", { FO_CD_MUT = "st_tot" })
check(ok5 and ok6 and not same(o5, o6), "mutant « st avancé » refusé (continue et chargée diffèrent)")
-- journal tôt
local ok7, o7 = sub("etapes", 3, "jt", { FO_CD_MUT = "journal_tot" })
check(ok7 and (info_of(o7).c2_log or 0) > 0, "mutant « journal tôt » refusé (" .. tostring(info_of(o7).c2_log) .. " ligne(s) avant la dernière tranche)")
-- D.bonus d'une autre équipe laissé en place
local ok8, o8 = sub("etapes", 3, "bonus_n", { FO_CD_INJ = "bonus" })
local ok9, o9 = sub("etapes", 3, "bonus_m", { FO_CD_INJ = "bonus", FO_CD_MUT = "bonus" })
check(ok8 and ok9 and not same(o8, o9), "mutant « D.bonus d'une autre équipe laissé en place » refusé (le résultat diffère de la référence)")

print(string.format("[CAPI-DECIDE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
