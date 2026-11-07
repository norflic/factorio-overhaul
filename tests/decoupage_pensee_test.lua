--[[
  Lot DÉCOUPAGE-PENSÉE (7/11) : une pensée d'équipe en huit étapes, une par tick (script/team/team.lua, shared/team/etapes.lua).
  Critères : fo-logs/2026-11-07_DECOUPAGE-PENSEE/CRITERES.md (quatre étapes) et CRITERES-E1-E4.md (E1 en trois tranches, E4 en
  trois ticks).

  Partie de banc au moteur simulé : 4 factions (plan directeur, centrale sur un étang, modules), ia3e allumé, votre équipe (coffre
  posé au centre). Chaque passage est un PROCESSUS à part (`--run`), pour partir d'un moteur et de modules neufs :
    lua5.2 tests/decoupage_pensee_test.lua --run <mode> <minutes> <sortie> [--sans <view.x|plan.x>]
  modes : bloc (les huit étapes au tick T, copies STRICTES), etapes (T à T + 7), charge (etapes, sauvegarde et chargement simulés
  à chaque tick où une étape attend), config (charge + on_configuration_changed à ces ticks), config-ref (mêmes chargements, même
  nombre d'appels à on_configuration_changed, au premier tick sans étape en attente), bascule (bloc puis etapes à mi-partie),
  releve (bloc, copie remplacée par un enregistreur des champs lus), sonde (bloc : tables des copies gardées atteignables depuis
  global ?), unites (etapes : instructions Lua comptées par étape). Sorties : <sortie>_global.txt, _journal.txt, _trace.txt,
  _info.txt. FO_MUT_CFG=efface|ligne : mutants du mode config ; FO_MUT_SIG=ignore|version : mutants du mode sig ; FO_L_LACHE=1 :
  L non strict (mutants de L, jugés sur le résultat).

  Sans argument, le banc complet (environ 45 min sur un PC chargé ; FO_RAPIDE=1 : parties 3 à 6 ; FO_SEULE5=1 : partie 5) :
    0. contrôle statique : champs lus en E4 à E6 (vue, plan) et dans Ia3.plan_capi et Ia3.plan_b (L) contre les listes ;
    1. relevé : les champs lus en E4 à E6 sont tous dans Et.VIEW et Et.PLAN ;
    2. mutants : chaque champ retiré à tour de rôle fait échouer la partie (copie stricte) ; ceux d'Et.RARES peuvent survivre ;
       chaque clé de Et.L retirée (L non strict) change le résultat ;
    3. etapes : deux parties identiques (déterminisme) ; ordre des portées de chaque pensée et ticks T à T + 7 ;
    4. charge : identique à la partie continue ;
    5. config : chaque pensée coupée par un changement de configuration finit, sans abandon ni rattrapage ; global identique à
       config-ref SANS filtre ; journal identique hors d'une liste blanche exacte (5 préfixes), avec autant de lignes de chaque
       sorte des deux côtés ; mutants « efface » (la migration perd les étapes) et « ligne » (ligne de décision) refusés ;
    6. bascule : une partie commencée d'un bloc (état d'une 0.6.56) passe aux étapes sans erreur ;
    7. signature et version : autre signature (dont celle d'a1090657), sans signature, changement de version du mod : effacées ;
       même signature : gardée ; mutants « signature ignorée » et « version ignorée » ;
    8. sonde : aucune table des copies gardées (vue entière, L, capi, stock) n'est atteignable depuis global ;
    9. unités de travail par étape (information).
  Avant chaque passage, le banc attend que le PC compte moins de 8 lua (FO_LUA_MAX) ; il ne relance jamais un passage tué.
  L'A/B « mode bloc = ancien code » se joue à part (ancien code dans un autre dossier, même fichier de test) : voir CRITERES.md P1.
]]
package.path = "./?.lua;" .. package.path

local SELF = debug.getinfo(1, "S").source:sub(2)
local LUA = arg[-1] or "lua5.2"

---------------------------------------------------------------------------------------------------
-- Une partie
---------------------------------------------------------------------------------------------------
local function run(mode, min, out, sans)
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
    for i = 0, 11 do -- gisements de votre équipe, autour du centre
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
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, ia3e = true, tile_at = tile_at })
  local W = M.world()
  local Team = require("script.team.team")
  local okE, Et = pcall(require, "shared.team.etapes")
  if not okE then Et = nil end
  -- Réglage du mode (l'ancien code n'a ni Team.ETAPES ni Et : rien à régler)
  local REC = {}
  if Et then
    if sans then
      local list, key = sans:match("^(%a+)%.(.+)$")
      local L = list == "view" and Et.VIEW or list == "L" and Et.L or Et.PLAN
      local j
      for i, k in ipairs(L) do if k == key then j = i end end
      assert(j, "champ inconnu des listes : " .. tostring(sans))
      table.remove(L, j)
    end
    Team.ETAPES = (mode == "etapes" or mode == "charge" or mode == "config" or mode == "config-ref" or mode == "sig" or mode == "unites")
    if mode == "releve" then
      local function recorder(src, name)
        return setmetatable({}, {
          __index = function(_, k) REC[name .. "." .. tostring(k)] = true return src[k] end,
          __newindex = function(_, k, v) REC["ECRIT " .. name .. "." .. tostring(k)] = true src[k] = v end,
          __pairs = function() REC[name .. ".<pairs>"] = true return next, src, nil end,
          __ipairs = function() REC[name .. ".<ipairs>"] = true return ipairs(src) end,
          __len = function() REC[name .. ".<len>"] = true return #src end,
        })
      end
      Team.FREEZE_HOOK = function(view, plan, ia3) return { ia3 = ia3, view = recorder(view or {}, "view"), plan = recorder(plan or {}, "plan") } end
    else
      Et.STRICT = true -- une fonction dans la copie : erreur
      Team.FREEZE_HOOK = function(view, plan, ia3) return Et.strict(Et.freeze(view, plan, ia3)) end
    end
    -- Copies gardées de E1a, E1b et E4 : STRICTES (L : lire une clé hors Et.L lève une erreur ; FO_L_LACHE=1 : non strict) ; les
    -- clés rendues par Ia3.plan_a doivent être dans Et.L (une clé de plus serait perdue sans bruit).
    local lache = os.getenv("FO_L_LACHE") == "1"
    Team.KEEP_HOOK = function(kind, a, b)
      if kind == "e1a" then
        if b then
          for k in pairs(b) do
            local ok = false
            for _, x in ipairs(Et.L) do if x == k then ok = true end end
            if not ok and not (sans and sans == "L." .. k) then error("etapes : Ia3.plan_a rend une cle hors de Et.L : " .. tostring(k)) end
          end
        end
        local v, l = Et.keep_e1(a, b)
        if mode == "sonde" then
          SONDE(kind, a, b)
          -- les champs déclarés (Et.REF_VIEW, Et.REF_L) sont gardés PAR RÉFÉRENCE dans la copie
          for _, k in ipairs(Et.REF_VIEW) do
            if type(a[k]) == "table" then ALIAS.ref = ALIAS.ref + 1; if not rawequal(v[k], a[k]) then ALIAS.ref_bad = ALIAS.ref_bad + 1 end end
          end
          for _, k in ipairs(b and Et.REF_L or {}) do
            if type(b[k]) == "table" then ALIAS.ref = ALIAS.ref + 1; if not rawequal(l[k], b[k]) then ALIAS.ref_bad = ALIAS.ref_bad + 1 end end
          end
        end
        return v, (l and not lache) and Et.strict_L(l) or l
      end
      if mode == "sonde" then SONDE(kind, a) end
      if kind == "capi" and sans == "L.capi" then return nil end -- mutant de L : capi (posée par E1b, hors de la copie de E1a)
      return (Et.keep(a, kind))
    end
  end

  -- Sonde (mode sonde) : une table d'une copie gardée est-elle une table atteignable depuis global (alias) ? Comptées par sorte.
  ALIAS = { n = 0, calls = 0, where = {}, declared = 0, ref = 0, ref_bad = 0 }
  local DECL = {}
  for _, k in ipairs(Et and Et.REF_VIEW or {}) do DECL["vue." .. k] = true end
  for _, k in ipairs(Et and Et.REF_L or {}) do DECL["L." .. k] = true end
  function SONDE(kind, a, b)
    ALIAS.calls = ALIAS.calls + 1
    local reach = {}
    local function mark(v, path)
      if type(v) ~= "table" or rawget(v, "_lua_object") or reach[v] then return end
      reach[v] = path
      for k, x in pairs(v) do mark(x, path .. "." .. tostring(k)) end
    end
    mark(global, "global")
    local seen = {}
    local function walk(v, path)
      if type(v) ~= "table" or rawget(v, "_lua_object") or seen[v] then return end
      seen[v] = true
      if reach[v] then
        local decl = kind == "e1a" and DECL[path]
        if decl then ALIAS.declared = ALIAS.declared + 1 else ALIAS.n = ALIAS.n + 1 end
        local key = (decl and "(par reference) " or "") .. kind .. " " .. path:gsub("%[%d+%]", "[i]") .. " = " .. reach[v]:gsub("%.%d+", ".i")
        ALIAS.where[key] = (ALIAS.where[key] or 0) + 1
        return
      end
      for k, x in pairs(v) do walk(x, path .. "." .. tostring(k)) end
    end
    walk(a, kind == "e1a" and "vue" or kind)
    if b then walk(b, "L") end
  end

  -- Montage (tests/etalement_plan_test.lua) : has_flag des tapis et eau comptée, à l'identique pour tous les codes comparés.
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
  -- Votre équipe : coffre posé au centre, garni
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 2 }, { "firearm-magazine", 40 }, { "burner-mining-drill", 6 }, { "stone-furnace", 6 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W.events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })

  local Build = require("script.team.build")
  local State = require("script.faction.state")
  local Profiler = require("script.core.profiler")
  M.run_ticks(120)
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    Build.enable(f, { radius = 3 })
    Build.plant(f)
    Build.request(f, { gen = "gears", args = { 2, "assembling-machine-1" }, feed = true, prio = 60 })
    Build.request(f, { gen = "simple", args = { "iron-gear-wheel", 1, "assembling-machine-1" }, feed = true, prio = 55 })
  end

  -- Trace des portées des pensées (nom, tick)
  local WANT = {}
  for _, n in ipairs({ "team:view", "team:plan_a", "team:plan_capi", "team:plan", "team:board", "team:poles", "team:build", "tt:recon", "tt:reparation", "tt:repair",
    "tt:inter", "team:market", "tt:idle", "team:scale", "tt:stock", "tt:spares", "tt:gisement", "tt:foswap", "tt:migchamp",
    "tt:capital", "tt:fin", "faction:attack" }) do WANT[n] = true end
  local trace = {}
  for _, fname in ipairs({ "start", "fstart" }) do
    local o = Profiler[fname]
    Profiler[fname] = function(name, ...)
      if WANT[name] then trace[#trace + 1] = game.tick .. " " .. name end
      return o(name, ...)
    end
  end

  UNITS = {}
  if mode == "unites" then
    local count = 0
    debug.sethook(function() count = count + 1 end, "", 100)
    local open = {}
    local o_start, o_stop = Profiler.start, Profiler.stop
    Profiler.start = function(name, ...)
      local n = name:match("^team:etape(%d)$")
      if n then open[name] = count end
      return o_start(name, ...)
    end
    Profiler.stop = function(name, ...)
      local n = name:match("^team:etape(%d)$")
      if n and open[name] then
        UNITS[#UNITS + 1] = { n = tonumber(n), t0 = game.tick - (tonumber(n) - 1), u = (count - open[name]) * 100 }
        open[name] = nil
      end
      return o_stop(name, ...)
    end
    local think = Team.think
    Team.think = function(f, surface, tick, tail)
      local c0 = count
      local r = think(f, surface, tick, tail)
      UNITS[#UNITS + 1] = { n = 1, t0 = tick, u = (count - c0) * 100 }
      return r
    end
  end

  local function restore(copy)
    for k in pairs(global) do global[k] = nil end
    local c = M.deepcopy_global(copy)
    for k, v in pairs(c) do global[k] = v end
  end
  local function pending()
    for _, id in ipairs(State.alive()) do
      local f = State.faction(id)
      if f and f.team and f.team.etape then return true end
    end
    local p = State.faction("player")
    return p and p.team and p.team.etape and true or false
  end

  local total = min * 3600
  SIGS = {}
  local loads, configs = 0, 0
  -- config : on_configuration_changed À CHAQUE tick où une étape attend (400 fois au plus) ; config-ref : les mêmes chargements,
  -- et le même nombre d'appels à on_configuration_changed, mais au premier tick suivant SANS étape en attente. FO_MUT_CFG (mutants
  -- du contrôle, mode config seulement) : « efface » (la migration perd l'état des étapes en attente), « ligne » (la migration écrit
  -- une ligne de décision hors de la liste blanche quand une étape attend).
  local mut_cfg = os.getenv("FO_MUT_CFG")
  local function config_call()
    W.on_config({ mod_changes = {} })
    configs = configs + 1
    if mode == "config" and mut_cfg then
      for _, id in ipairs(State.alive()) do
        local f = State.faction(id)
        if f and f.team and f.team.etape then
          if mut_cfg == "efface" then f.team.etape = nil end
          if mut_cfg == "ligne" then log("[FO-TEAM] " .. tostring(f.key) .. " : MUTANT, decision ecrite pendant la migration") end
        end
      end
    end
  end
  if mode == "charge" or mode == "config" or mode == "config-ref" then
    local owed = 0
    for _ = 1, total do
      M.run_ticks(1)
      if pending() then
        restore(M.deepcopy_global(global))
        loads = loads + 1
        if mode == "config" and configs < 400 then config_call() end
        if mode == "config-ref" and configs + owed < 400 then owed = owed + 1 end
      elseif owed > 0 then
        for _ = 1, owed do config_call() end
        owed = 0
      end
    end
  elseif mode == "sig" then
    -- Signature des listes (relecture de 6fcfe757) : trois changements de configuration, chacun pendant la pensée en cours d'une
    -- équipe différente : signature d'une autre version, puis aucune signature (partie d'avant la signature), puis la même.
    local done, step = 0, 1
    local mut_sig = os.getenv("FO_MUT_SIG")
    if mut_sig == "ignore" then Team.etapes_config_changed = function() end end -- mutant : signature ignorée
    if mut_sig == "version" then -- mutant : version ignorée (la règle de la signature seule)
      local real = Team.etapes_config_changed
      Team.etapes_config_changed = function() return real({ mod_changes = {} }) end
    end
    local HOW = { "autre", "sans", "version", "meme" }
    local SIG_A109 = "view:" .. table.concat(Et.VIEW, ",") .. "|plan:" .. table.concat(Et.PLAN, ",") -- signature d'a1090657
    local used = {}
    for _ = 1, total do
      M.run_ticks(1)
      done = done + 1
      if step <= #HOW then
        local pick
        for _, id in ipairs(State.alive()) do
          local f = State.faction(id)
          if not pick and f and f.team and f.team.etape and not used[f] then pick = f end
        end
        local pl = State.faction("player")
        if not pick and pl and pl.team and pl.team.etape and not used[pl] then pick = pl end
        if pick then
          used[pick] = true
          local how = HOW[step]
          if how == "autre" then pick.team.etape.sig = SIG_A109 elseif how == "sans" then pick.team.etape.sig = nil end
          local s = { f = pick, how = how, t0 = pick.team.etape.t0, n = pick.team.etape.n }
          if how == "version" then
            W.on_config({ mod_changes = { ["factorio-overhaul"] = { old_version = "0.6.58", new_version = "0.6.59" } } })
          else
            W.on_config({ mod_changes = {} })
          end
          configs = configs + 1
          s.after = pick.team.etape and "garde" or "efface"
          s.p0 = (pick.team.etapes or {}).pensees or 0
          SIGS[#SIGS + 1] = s
          step = step + 1
        end
      end
    end
  elseif mode == "bascule" then
    M.run_ticks(math.floor(total / 2))
    Team.ETAPES = true
    M.run_ticks(total - math.floor(total / 2))
  else
    M.run_ticks(total)
  end

  local function wr(suffix, text)
    local h = assert(io.open(out .. suffix, "w"))
    h:write(text)
    h:close()
  end
  wr("_global.txt", M.serialize(global))
  local jl = {}
  for _, l in ipairs(W.logs) do jl[#jl + 1] = tostring(l) end
  wr("_journal.txt", table.concat(jl, "\n"))
  wr("_trace.txt", table.concat(trace, "\n"))
  local info = { "mode " .. mode, "chargements " .. loads, "configurations " .. configs }
  for _, s in ipairs(SIGS) do
    info[#info + 1] = string.format("sig %s %s %s pensees_apres %d etape %s", tostring(s.f.key or "player"), s.how, s.after,
      ((s.f.team.etapes or {}).pensees or 0) - s.p0, tostring(s.n))
  end
  local function counts(f)
    local c = f and f.team and f.team.etapes or {}
    return string.format("%s pensees %d abandons %d rattrapages %d", tostring(f and (f.key or "player")), c.pensees or 0,
      c.abandons or 0, c.rattrapages or 0)
  end
  for _, id in ipairs(State.alive()) do info[#info + 1] = counts(State.faction(id)) end
  info[#info + 1] = counts(State.faction("player"))
  local rk = {}
  for k in pairs(REC) do rk[#rk + 1] = k end
  table.sort(rk)
  for _, k in ipairs(rk) do info[#info + 1] = "lu " .. k end
  if mode == "sonde" then
    info[#info + 1] = string.format("sonde appels %d alias %d declares %d references %d fausses %d", ALIAS.calls, ALIAS.n, ALIAS.declared,
      ALIAS.ref, ALIAS.ref_bad)
    local wk = {}
    for k in pairs(ALIAS.where) do wk[#wk + 1] = k end
    table.sort(wk)
    for _, k in ipairs(wk) do info[#info + 1] = "alias " .. k .. " x" .. ALIAS.where[k] end
  end
  for _, r in ipairs(UNITS) do info[#info + 1] = string.format("unites %d %d %d", r.n, r.t0, r.u) end
  wr("_info.txt", table.concat(info, "\n"))
  print("[DECOUPAGE-RUN] " .. mode .. " fini")
end

if arg[1] == "--run" then
  local sans
  for i = 5, #arg do if arg[i] == "--sans" then sans = arg[i + 1] end end
  run(arg[2], tonumber(arg[3]), arg[4], sans)
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
-- Plafond du PC (garde du lead pendant une partie du DC : au plus 8 lua à la fois). Avant CHAQUE passage, le banc attend que le PC
-- compte moins de 8 lua5.2 (FO_LUA_MAX pour un autre plafond) ; il ne relance JAMAIS un passage tué (aucune sortie, code 127) : ce
-- passage compte « tué », sans verdict, et le banc le dit.
local LUA_MAX = tonumber(os.getenv("FO_LUA_MAX") or "") or 8
local function lua_count()
  local h = io.popen('powershell -NoProfile -Command "@(Get-Process lua5.2 -ErrorAction SilentlyContinue).Count"')
  local n = tonumber((h:read("*a") or ""):match("%d+")) or LUA_MAX
  h:close()
  return n
end
local function sub(mode, min, tag, sans)
  local out = TMP .. "/decoupage_" .. tag
  local cmd = string.format('%s %s --run %s %s "%s"%s 2>&1', LUA, SELF, mode, min, out, sans and (" --sans " .. sans) or "")
  while lua_count() >= LUA_MAX do os.execute("ping -n 16 127.0.0.1 > nul") end
  local h = io.popen(cmd)
  local text = h:read("*a")
  h:close()
  local ok = text:find("[DECOUPAGE-RUN] " .. mode .. " fini", 1, true) ~= nil
  if not text:find("%S") then text = "(passage tué de l'extérieur, sans sortie : non relancé)" end
  return ok, out, text
end
local function slurp(path)
  local h = io.open(path, "r")
  if not h then return nil end
  local t = h:read("*a")
  h:close()
  return t
end
local function lines_of(text)
  local o = {}
  for l in (text or ""):gmatch("[^\n]+") do o[#o + 1] = l end
  return o
end

local Et = require("shared.team.etapes")
local MIN = tonumber(os.getenv("FO_MIN") or "") or 10

---------------------------------------------------------------------------------------------------
-- 0. Contrôle STATIQUE (relecture de 6fcfe757) : en jeu la copie n'est pas stricte, un champ oublié vaudrait nil sans rien dire.
-- On lit le SOURCE de TT.e4 et de chaque fonction qui reçoit la vue ou le plan (suivies de proche en proche) : chaque `view.X` et
-- `plan.X` lu doit être dans Et.VIEW / Et.PLAN, chaque champ listé doit être lu quelque part, et la vue ou le plan ne doit être
-- transmis à AUCUNE fonction hors de la table SUIVIES (sinon : l'y ajouter, avec le nom de son paramètre).
---------------------------------------------------------------------------------------------------
section("0. Contrôle statique des champs lus en E4 à E6 (sources de TT.e4, TT.e5, TT.e6 et des fonctions qui reçoivent la vue ou le plan)")
local SUIVIES = {
  ["TT.e4"] = { file = "script/team/team.lua", header = "TT.e4 = function(f, surface, tick, et)", params = { view = "view", plan = "plan" } },
  ["TT.e5"] = { file = "script/team/team.lua", header = "TT.e5 = function(f, surface, tick, et)", params = { view = "view", plan = "plan" } },
  ["TT.e6"] = { file = "script/team/team.lua", header = "TT.e6 = function(f, surface, tick, et)", params = { view = "view", plan = "plan" } },
  ["Team.measure"] = { file = "script/team/team.lua", header = "function Team.measure(f, view, tick)", params = { view = "view" } },
  ["Team.effectif_journal"] = { file = "script/team/team.lua", header = "function Team.effectif_journal(f, view, tick)", params = { view = "view" } },
  ["Team.plafond_journal"] = { file = "script/team/team.lua", header = "function Team.plafond_journal(f, view, stock, tick)", params = { view = "view" } },
  ["Ia3.capital_pay"] = { file = "script/ai3/cerveau.lua", header = "function Ia3.capital_pay(f, surface, tick, plan, stock, only_center)", params = { plan = "plan" } },
  ["Ia3.measure"] = { file = "script/ai3/cerveau.lua", header = "function Ia3.measure(f, tick, plan)", params = { plan = "plan" } },
  ["Capital.pay"] = { file = "script/ai3/capital.lua", header = "function Capital.pay(f, surface, tick, plan, stock, only_center)", params = { plan = "plan" } },
  ["Recon.upgrade_stock"] = { file = "script/team/reconstruction.lua", header = "function Recon.upgrade_stock(f, book, stock, tick, plan)", params = { plan = "plan" } },
}
local function source_body(spec)
  local h = io.open(spec.file, "r")
  if not h then return nil, "fichier absent" end
  local s = h:read("*a")
  h:close()
  local i = s:find(spec.header, 1, true)
  if not i then return nil, "en-tête introuvable" end
  local j = s:find("\nend\n", i, true) or s:find("\nend\r\n", i, true)
  if not j then return nil, "fin introuvable" end
  local body = s:sub(i, j + 4)
  body = body:gsub("%-%-%[%[.-%]%]", "") -- commentaires longs
  local lines = {}
  for l in (body .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = (l:gsub("%-%-.*$", "")) end -- commentaires de ligne
  return table.concat(lines, "\n")
end
-- Appel qui reçoit l'identifiant en position `pos` : la parenthèse ouvrante non fermée qui le précède, et le nom juste avant.
local function callee_at(body, pos)
  local depth = 0
  for k = pos - 1, 1, -1 do
    local c = body:sub(k, k)
    if c == ")" then depth = depth + 1
    elseif c == "(" then
      if depth == 0 then return body:sub(1, k - 1):match("([%w_%.:]+)%s*$") end
      depth = depth - 1
    elseif c == "\n" and depth == 0 and body:sub(k + 1, pos - 1):match("^%s*local ") then return nil
    end
  end
  return nil
end
-- Champs lus (`pname.X`) et fonctions qui reçoivent `pname` seul (ni champ lu, ni index, hors déclaration) dans un source.
local function SCAN(body, pname)
  local fields, callees = {}, {}
  for fld in body:gmatch("%f[%w_]" .. pname .. "%.([%a_][%w_]*)") do fields[fld] = true end
  local pos = 1
  while true do
    local a, b = body:find("%f[%w_]" .. pname .. "%f[^%w_]", pos)
    if not a then break end
    local before, after = body:sub(a - 1, a - 1), body:sub(b + 1, b + 1)
    if before ~= "." and after ~= "." and after ~= "[" then
      local callee = callee_at(body, a)
      if callee and callee ~= "function" then callees[#callees + 1] = callee end
    end
    pos = b + 1
  end
  return fields, callees
end
local static = { view = {}, plan = {} }
local errs, seen_fn = {}, {}
local queue = { { name = "TT.e4" }, { name = "TT.e5" }, { name = "TT.e6" } }
while #queue > 0 do
  local item = table.remove(queue, 1)
  local spec = SUIVIES[item.name]
  local key = item.name
  if not seen_fn[key] then
    seen_fn[key] = true
    local body, why = source_body(spec)
    if not body then
      errs[#errs + 1] = item.name .. " : " .. why
    else
      for list, pname in pairs(spec.params) do -- (ordre sans effet : ensembles)
        local fields, callees = SCAN(body, pname)
        for fld in pairs(fields) do static[list][fld] = true end
        for _, callee in ipairs(callees) do
          if SUIVIES[callee] then
            if SUIVIES[callee].params[list] then queue[#queue + 1] = { name = callee }
            else errs[#errs + 1] = callee .. " reçoit " .. list .. " sans paramètre suivi" end
          else
            errs[#errs + 1] = item.name .. " transmet " .. list .. " à " .. callee .. ", fonction non suivie"
          end
        end
      end
    end
  end
end
local function diff(set, listed)
  local missing, unused = {}, {}
  local L = {}
  for _, k in ipairs(listed) do L[k] = true end
  for k in pairs(set) do if not L[k] then missing[#missing + 1] = k end end
  for _, k in ipairs(listed) do if not set[k] then unused[#unused + 1] = k end end
  table.sort(missing)
  return missing, unused
end
local mv, uv = diff(static.view, Et.VIEW)
local mp, up = diff(static.plan, Et.PLAN)
local nfn = 0
for _ in pairs(seen_fn) do nfn = nfn + 1 end
print(string.format("  %d fonction(s) lues ; champs lus : vue %d, plan %d", nfn, (function() local n = 0 for _ in pairs(static.view) do n = n + 1 end return n end)(),
  (function() local n = 0 for _ in pairs(static.plan) do n = n + 1 end return n end)()))
check(#errs == 0, "sources lues, aucune transmission à une fonction non suivie : " .. table.concat(errs, " ; "))
check(#mv == 0 and #mp == 0, "champs lus et non gardés : vue [" .. table.concat(mv, ", ") .. "], plan [" .. table.concat(mp, ", ") .. "]")
check(#uv == 0 and #up == 0, "champs gardés jamais lus : vue [" .. table.concat(uv, ", ") .. "], plan [" .. table.concat(up, ", ") .. "]")
-- Mutant du contrôle statique : une liste privée d'un champ lu doit être vue
do
  local short = {}
  for i = 2, #Et.PLAN do short[#short + 1] = Et.PLAN[i] end
  local m2 = diff(static.plan, short)
  check(#m2 == 1 and m2[1] == Et.PLAN[1], "mutant : liste du plan sans « " .. Et.PLAN[1] .. " » refusée par le contrôle statique")
  -- mutants du SOURCE : un champ nouveau lu en E4, et le plan transmis à une fonction nouvelle
  local src = "  local x = plan.champ_nouveau or 0 -- plan.dans_un_commentaire\n  Autre.fonction(f, tick, plan)\n  local y = view.stock\n"
  local fld, cal = SCAN(src:gsub("%-%-[^\n]*", ""), "plan")
  check(fld.champ_nouveau and not fld.dans_un_commentaire and #cal == 1 and cal[1] == "Autre.fonction",
    "mutants du source : champ nouveau vu, commentaire ignoré, transmission à une fonction nouvelle vue")
end
-- 0 bis. L (E1a -> E1b -> E1c) : Ia3.plan_capi et Ia3.plan_b ne lisent que des clés de Et.L, toutes lues ; L ne passe à aucune
-- autre fonction ; Ia3.plan_a rend EXACTEMENT les clés de Et.L sauf capi (posée par E1b) ; dans team.lua, l'état et.L ne passe qu'à
-- Ia3.plan_capi et Ia3.plan_b.
do
  local readL, errL = {}, {}
  for _, spec in ipairs({ { file = "script/ai3/cerveau.lua", header = "function Ia3.plan_capi(f, view, book, tick, L)" },
    { file = "script/ai3/cerveau.lua", header = "function Ia3.plan_b(f, view, book, surface, tick, L)" } }) do
    local body, why = source_body(spec)
    if not body then errL[#errL + 1] = spec.header .. " : " .. why
    else
      local fields, callees = SCAN((body:gsub("^[^\n]*\n", "", 1)), "L") -- (sans l'en-tête, qui déclare L)
      for k in pairs(fields) do readL[k] = true end
      for _, c in ipairs(callees) do errL[#errL + 1] = spec.header .. " transmet L à " .. c end
    end
  end
  local ml, ul = diff(readL, Et.L)
  check(#errL == 0, "L lu dans plan_capi et plan_b seulement, transmis à aucune autre fonction : " .. table.concat(errL, " ; "))
  check(#ml == 0 and #ul == 0, "clés de L : lues et non gardées [" .. table.concat(ml, ", ") .. "], gardées jamais lues [" .. table.concat(ul, ", ") .. "]")
  local body = source_body({ file = "script/ai3/cerveau.lua", header = "function Ia3.plan_a(f, view, book, surface, tick)" })
  local ret = body and body:match("\n%s*return (%b{})%s*\nend") or ""
  local rk = {}
  for k in ret:gmatch("([%a_][%w_]*)%s*=") do rk[k] = true end
  rk.capi = true
  local mr, ur = diff(rk, Et.L)
  check(ret ~= "" and #mr == 0 and #ur == 0, "Ia3.plan_a rend les clés de Et.L sauf capi : hors liste [" .. table.concat(mr, ", ") .. "], absentes [" .. table.concat(ur, ", ") .. "]")
  local tsrc = slurp("script/team/team.lua") or ""
  local users, bad = {}, {}
  local pos = 1
  while true do
    local a, b = tsrc:find("%f[%w_]et%.L%f[^%w_]", pos)
    if not a then break end
    local after = tsrc:sub(b + 1, b + 1)
    if after ~= "." then
      local c = callee_at(tsrc, a)
      if c then users[c] = true end
    end
    pos = b + 1
  end
  for c in pairs(users) do if c ~= "Ia3.plan_capi" and c ~= "Ia3.plan_b" then bad[#bad + 1] = c end end
  table.sort(bad)
  check(users["Ia3.plan_capi"] and users["Ia3.plan_b"] and #bad == 0, "et.L passé à Ia3.plan_capi et Ia3.plan_b seulement (autres : " .. table.concat(bad, ", ") .. ")")
  -- mutants : liste L privée d'une clé lue ; source de plan_b qui lit une clé nouvelle ; plan_a qui rend une clé de plus
  local shortL = {}
  for i = 2, #Et.L do shortL[#shortL + 1] = Et.L[i] end
  local m3 = diff(readL, shortL)
  check(#m3 == 1 and m3[1] == Et.L[1], "mutant : liste L sans « " .. Et.L[1] .. " » refusée")
  local f2 = SCAN("  local x = L.cle_nouvelle\n", "L")
  check(f2.cle_nouvelle == true, "mutant du source : clé nouvelle de L vue")
  local rk2 = {}
  for k in ("{ w = w, nouvelle = 1 }"):gmatch("([%a_][%w_]*)%s*=") do rk2[k] = true end
  local m4 = diff(rk2, Et.L)
  check(#m4 == 1 and m4[1] == "nouvelle", "mutant : plan_a qui rend une clé hors liste refusé")
end

if os.getenv("FO_STATIQUE") then
  print(string.format("[DECOUPAGE-PENSEE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
  os.exit(failures == 0 and 0 or 1)
end

if not os.getenv("FO_RAPIDE") then -- FO_RAPIDE=1 : parties 3 à 6 seulement
section("1. Relevé des champs lus en E4 (" .. MIN .. " min, mode bloc)")
local ok, out, text = sub("releve", MIN, "releve")
check(ok, "partie de relevé jouée" .. (ok and "" or (" : " .. text:sub(-400))))
local listed = {}
for _, k in ipairs(Et.VIEW) do listed["view." .. k] = true end
for _, k in ipairs(Et.PLAN) do listed["plan." .. k] = true end
local read_n, missing = 0, {}
for _, l in ipairs(lines_of(slurp(out .. "_info.txt"))) do
  local k = l:match("^lu (.+)$")
  if k and k:sub(1, 6) == "ECRIT " then
    check(false, "E4 écrit dans la vue ou le plan : " .. k)
  elseif k then
    read_n = read_n + 1
    if not listed[k] then missing[#missing + 1] = k end
  end
end
print(string.format("  %d champ(s) ou usage(s) relevé(s) ; listés : view %d, plan %d", read_n, #Et.VIEW, #Et.PLAN))
check(read_n > 0, "des champs lus en E4")
check(#missing == 0, "champs lus et non gardés : " .. table.concat(missing, ", "))

section("2. Mutants : chaque champ gardé, retiré à tour de rôle, fait échouer la partie (copie stricte, 3 min)")
local survivors = {}
local all = {}
for _, k in ipairs(Et.VIEW) do all[#all + 1] = "view." .. k end
for _, k in ipairs(Et.PLAN) do all[#all + 1] = "plan." .. k end
local okb, outb = sub("bloc", 3, "mut_ref")
check(okb, "partie de référence (bloc, 3 min)")
local refg, refj = slurp(outb .. "_global.txt"), slurp(outb .. "_journal.txt")
local by_error, by_diff, unknown = 0, 0, {}
for _, k in ipairs(all) do
  local okm, outm, tm = sub("bloc", 3, "mut", k)
  if okm then
    local same = slurp(outm .. "_global.txt") == refg and slurp(outm .. "_journal.txt") == refj
    if same then survivors[#survivors + 1] = k else by_diff = by_diff + 1 end
  elseif tm:find("champ non garde lu en E4 : " .. k, 1, true) then
    by_error = by_error + 1
  else
    unknown[#unknown + 1] = k .. " (" .. tm:sub(-160) .. ")"
  end
end
print(string.format("  refusés : %d par l'erreur de la copie stricte, %d par un résultat différent", by_error, by_diff))
check(#unknown == 0, "aucun mutant sans verdict (tués ou autre erreur) : " .. table.concat(unknown, " ; "))
local rares, plain = {}, {}
for _, k in ipairs(survivors) do if Et.RARES[k] then rares[#rares + 1] = k else plain[#plain + 1] = k end end
print(string.format("  %d mutant(s), %d survivant(s) dont %d de branche rare (Et.RARES)%s", #all, #survivors, #rares,
  #rares > 0 and (" : " .. table.concat(rares, ", ")) or ""))
check(#plain == 0, "aucun champ gardé inutile en 3 min (survivants hors Et.RARES : " .. table.concat(plain, ", ") .. ")")
-- Mutants de L : chaque clé retirée de Et.L, L NON strict (FO_L_LACHE=1 : la clé vaut nil en E1b et E1c) ; jugés sur le résultat.
local survL, unkL, diffL = {}, {}, 0
for _, k in ipairs(Et.L) do
  local out = TMP .. "/decoupage_mutL_" .. k
  while lua_count() >= LUA_MAX do os.execute("ping -n 16 127.0.0.1 > nul") end
  local hh = io.popen(string.format('set "FO_L_LACHE=1" && %s %s --run bloc 3 "%s" --sans L.%s 2>&1', LUA, SELF, out, k))
  local text = hh:read("*a")
  hh:close()
  if text:find("[DECOUPAGE-RUN] bloc fini", 1, true) then
    if slurp(out .. "_global.txt") == refg and slurp(out .. "_journal.txt") == refj then survL[#survL + 1] = k else diffL = diffL + 1 end
  elseif text:find("%S") then
    diffL = diffL + 1 -- erreur de la partie (clé nil lue) : refusé
  else
    unkL[#unkL + 1] = k .. " (tué, sans sortie)"
  end
end
print(string.format("  L : %d mutant(s), %d refusé(s), %d survivant(s)%s", #Et.L, diffL, #survL, #survL > 0 and (" : " .. table.concat(survL, ", ")) or ""))
check(#unkL == 0, "aucun mutant de L sans verdict : " .. table.concat(unkL, " ; "))
local rareL = {}
for _, k in ipairs(survL) do if not Et.RARES["L." .. k] then rareL[#rareL + 1] = k end end
check(#rareL == 0, "aucune clé de L inutile en 3 min (survivantes hors Et.RARES : " .. table.concat(rareL, ", ") .. ")")

end

if not os.getenv("FO_SEULE5") then -- FO_SEULE5=1 : partie 5 seulement
section("3. Mode étapes : déterminisme, ordre, ticks (" .. MIN .. " min)")
local ok1, o1, t1 = sub("etapes", MIN, "etapes1")
local ok2, o2, t2 = sub("etapes", MIN, "etapes2")
check(ok1 and ok2, "deux parties jouées" .. ((ok1 and ok2) and "" or (" : " .. (ok1 and t2 or t1):sub(-300))))
local g1, j1 = slurp(o1 .. "_global.txt"), slurp(o1 .. "_journal.txt")
check(g1 and g1 == slurp(o2 .. "_global.txt"), "global identique d'une partie à l'autre")
check(j1 and j1 == slurp(o2 .. "_journal.txt"), "journal identique d'une partie à l'autre")
-- Ordre : chaque pensée commence par team:view ; ses portées suivent l'ordre canonique, à T (E1a), T + 1 (E1b), T + 2 (E1c),
-- T + 3 (E2), T + 4 (E3), T + 5 (E4), T + 6 (E5), T + 7 (E6 et la queue)
local ORDER = { { "team:view", 0 }, { "team:plan_a", 0 }, { "team:plan_capi", 1 }, { "team:plan", 2 }, { "team:board", 2 },
  { "team:poles", 2 }, { "team:build", 3 }, { "tt:recon", 4 }, { "tt:reparation", 4 }, { "tt:repair", 4 }, { "tt:inter", 5 },
  { "team:market", 5 }, { "tt:idle", 5 }, { "team:scale", 5 }, { "tt:stock", 5 }, { "tt:spares", 5 }, { "tt:gisement", 5 },
  { "tt:foswap", 6 }, { "tt:migchamp", 7 }, { "tt:capital", 7 }, { "tt:fin", 7 }, { "faction:attack", 7 } }
local rank = {}
for i, o in ipairs(ORDER) do rank[o[1]] = i end
local thinks, bad_order, bad_tick, complete = 0, 0, 0, 0
local cur
local function close()
  if cur and cur.last >= rank["tt:fin"] then complete = complete + 1 end
end
for _, l in ipairs(lines_of(slurp(o1 .. "_trace.txt"))) do
  local t, name = l:match("^(%d+) (.+)$")
  t = tonumber(t)
  if name == "team:view" then
    close()
    thinks = thinks + 1
    cur = { t0 = t, last = 1 }
  elseif cur then
    local r = rank[name]
    if r < cur.last then bad_order = bad_order + 1 end
    cur.last = math.max(cur.last, r)
    if t - cur.t0 ~= ORDER[r][2] then bad_tick = bad_tick + 1 end
  end
end
close()
print(string.format("  %d pensée(s), %d complète(s) ; hors ordre %d, hors tick %d", thinks, complete, bad_order, bad_tick))
check(thinks >= 20 and complete >= thinks - 5, "pensées jouées en entier (les dernières peuvent être en cours à la fin)")
check(bad_order == 0, "ordre des appels gardé")
check(bad_tick == 0, "étapes à T, T + 1 … T + 7")
local info1 = slurp(o1 .. "_info.txt") or ""
local ab = 0
for n in info1:gmatch("abandons (%d+)") do ab = ab + tonumber(n) end
local rt = 0
for n in info1:gmatch("rattrapages (%d+)") do rt = rt + tonumber(n) end
check(ab == 0 and rt == 0, string.format("ni abandon ni rattrapage (%d, %d)", ab, rt))

section("4. Sauvegarde et chargement à chaque tick d'étape (" .. MIN .. " min)")
local okc, oc = sub("charge", MIN, "charge")
check(okc, "partie jouée")
local ic = slurp(oc .. "_info.txt") or ""
print("  " .. (ic:match("chargements %d+") or "?"))
check(slurp(oc .. "_global.txt") == g1, "global identique à la partie continue")
check(slurp(oc .. "_journal.txt") == j1, "journal identique à la partie continue")

end

if not os.getenv("FO_SEULE7") then -- FO_SEULE5=1 FO_SEULE7=1 : parties 0 et 7 seulement
section("5. Changement de configuration en pleine étape (" .. MIN .. " min)")
-- Référence : mêmes chargements et même nombre d'appels à on_configuration_changed, mais à un tick SANS étape en attente
-- (config-ref). Global comparé TEL QUEL ; journal comparé hors d'une LISTE BLANCHE exacte des 5 sortes de lignes qu'écrit
-- on_configuration_changed lui-même (préfixes exacts), et chaque sorte doit compter EXACTEMENT autant de lignes des deux côtés.
local WHITE = { "[FO-LEVELS] 19 objets de co", "[FO-LOTS] mise ", "[FO-MODMULT] mise ", "[FO-FONDERIE] fonderie des champs a tapis : ",
  "[FO-PTEAM] montee de version : " }
local function split_white(j)
  local kept, n = {}, {}
  for i = 1, #WHITE do n[i] = 0 end
  for _, l in ipairs(lines_of(j)) do
    local w
    for i, pre in ipairs(WHITE) do if l:sub(1, #pre) == pre then w = i break end end
    if w then n[w] = n[w] + 1 else kept[#kept + 1] = l end
  end
  return table.concat(kept, string.char(10)), n
end
local function cfg_compare(o_a, o_b)
  local ja, na = split_white(slurp(o_a .. "_journal.txt"))
  local jb, nb = split_white(slurp(o_b .. "_journal.txt"))
  local counts_ok = true
  for i = 1, #WHITE do if na[i] ~= nb[i] then counts_ok = false end end
  return slurp(o_a .. "_global.txt") == slurp(o_b .. "_global.txt"), ja == jb, counts_ok, na, nb
end
local okf, of = sub("config", MIN, "config")
local okr, orf = sub("config-ref", MIN, "configref")
check(okf and okr, "parties jouées (config, config-ref)")
local inf = slurp(of .. "_info.txt") or ""
print("  " .. (inf:match("configurations %d+") or "?") .. " ; référence : " .. ((slurp(orf .. "_info.txt") or ""):match("configurations %d+") or "?"))
local abf, rtf, pf = 0, 0, 0
for n in inf:gmatch("abandons (%d+)") do abf = abf + tonumber(n) end
for n in inf:gmatch("rattrapages (%d+)") do rtf = rtf + tonumber(n) end
for n in inf:gmatch("pensees (%d+)") do pf = pf + tonumber(n) end
check(pf > 0 and abf == 0 and rtf == 0, string.format("pensées finies %d, abandons %d, rattrapages %d", pf, abf, rtf))
local g_ok, j_ok, c_ok, na, nb = cfg_compare(of, orf)
print("  lignes de la liste blanche, config / référence : " .. table.concat(na, " ") .. " / " .. table.concat(nb, " "))
check(c_ok, "liste blanche : autant de lignes de chaque sorte des deux côtés")
check(g_ok, "global identique à la référence (sans filtre)")
check(j_ok, "journal identique à la référence, hors liste blanche")
-- Mutants du contrôle (3 min) : la migration perd l'état des étapes ; la migration écrit une ligne de décision
local okr3, or3 = sub("config-ref", 3, "configref3")
for _, mc in ipairs({ "efface", "ligne" }) do
  local out = TMP .. "/decoupage_configmut_" .. mc
  while lua_count() >= LUA_MAX do os.execute("ping -n 16 127.0.0.1 > nul") end
  local hh = io.popen(string.format('set "FO_MUT_CFG=%s" && %s %s --run config 3 "%s" 2>&1', mc, LUA, SELF, out))
  local text = hh:read("*a")
  hh:close()
  local okm, om = text:find("[DECOUPAGE-RUN] config fini", 1, true) ~= nil, out
  local mg, mj, mcnt = false, false, false
  if okm and okr3 then mg, mj, mcnt = cfg_compare(om, or3) end
  check(okm and okr3 and not (mg and mj and mcnt), "mutant « " .. mc .. " » refusé par le contrôle (global " .. tostring(mg) .. ", journal " .. tostring(mj) .. ")")
end

end

if not os.getenv("FO_SEULE5") then
section("6. Bascule d'une partie commencée d'un bloc (" .. MIN .. " min)")
local okg, og = sub("bascule", MIN, "bascule")
check(okg, "partie jouée sans erreur")
local ig = slurp(og .. "_info.txt") or ""
local pg = 0
for n in ig:gmatch("pensees (%d+)") do pg = pg + tonumber(n) end
check(pg > 0, "pensées en étapes après la bascule (" .. pg .. ")")

end

if not os.getenv("FO_SEULE5") or os.getenv("FO_SEULE7") then
section("7. Signature et version au changement de configuration (relecture de 6fcfe757 ; suite E1-E4, 3 min)")
local oks, os7 = sub("sig", 3, "sig")
check(oks, "partie jouée")
local is = slurp(os7 .. "_info.txt") or ""
local js = slurp(os7 .. "_journal.txt") or ""
local seen = { autre = 0, sans = 0, version = 0, meme = 0 }
local bad = {}
for how, after, n in is:gmatch("sig %S+ (%a+) (%a+) pensees_apres (%-?%d+)") do
  seen[how] = seen[how] + 1
  local want = (how == "meme") and "garde" or "efface"
  if after ~= want or tonumber(n) < 1 then bad[#bad + 1] = how .. " " .. after .. " " .. n end
end
print(string.format("  équipes : signature d'a1090657 %d, sans signature %d, version changée %d, même signature %d", seen.autre, seen.sans,
  seen.version, seen.meme))
check(seen.autre == 1 and seen.sans == 1 and seen.version == 1 and seen.meme == 1,
  "une pensée de chaque sorte au changement de configuration (signature d'a1090657, sans signature, version changée, même)")
check(#bad == 0, "autre signature, sans signature ou version changée : effacée ; même signature : gardée ; chaque équipe repense ensuite (" .. table.concat(bad, " ; ") .. ")")
local nlog, nver = 0, 0
for _, l in ipairs(lines_of(js)) do
  if l:find("[FO-ETAPES]", 1, true) and l:find("effacee a l'etape", 1, true) then nlog = nlog + 1 end
  if l:find("[FO-ETAPES]", 1, true) and l:find("au changement de version du mod (0.6.58 -> 0.6.59)", 1, true) then nver = nver + 1 end
end
check(nlog == 3 and nver == 1, "trois lignes [FO-ETAPES] « effacée » au journal, dont une de version (" .. nlog .. ", " .. nver .. ")")
-- Mutant « signature ignorée » : la migration garde toute pensée en cours, quelle que soit sa signature ; le contrôle doit le voir
do
  local out = TMP .. "/decoupage_sig_mut"
  while lua_count() >= LUA_MAX do os.execute("ping -n 16 127.0.0.1 > nul") end
  local hh = io.popen(string.format('set "FO_MUT_SIG=ignore" && %s %s --run sig 3 "%s" 2>&1', LUA, SELF, out))
  local text = hh:read("*a")
  hh:close()
  local okm = text:find("[DECOUPAGE-RUN] sig fini", 1, true) ~= nil
  local kept = 0
  for how, after in (slurp(out .. "_info.txt") or ""):gmatch("sig %S+ (%a+) (%a+) pensees_apres") do
    if how ~= "meme" and after == "garde" then kept = kept + 1 end
  end
  check(okm and kept == 3, "mutant « signature ignorée » refusé : les 3 pensées à effacer restent gardées et le contrôle le voit (" .. kept .. ")")
end
do -- mutant « version ignorée » : la migration n'applique que la règle de la signature
  local out = TMP .. "/decoupage_sig_mutv"
  while lua_count() >= LUA_MAX do os.execute("ping -n 16 127.0.0.1 > nul") end
  local hh = io.popen(string.format('set "FO_MUT_SIG=version" && %s %s --run sig 3 "%s" 2>&1', LUA, SELF, out))
  local text = hh:read("*a")
  hh:close()
  local okm = text:find("[DECOUPAGE-RUN] sig fini", 1, true) ~= nil
  local vkept = (slurp(out .. "_info.txt") or ""):find("sig %S+ version garde") ~= nil
  check(okm and vkept, "mutant « version ignorée » refusé : la pensée de la version changée reste gardée et le contrôle le voit")
end
end

if not os.getenv("FO_SEULE5") then
section("8. Sonde : tables des copies gardées atteignables depuis global (mode bloc, 3 min)")
local okp, op = sub("sonde", 3, "sonde")
check(okp, "partie jouée")
local ip = slurp(op .. "_info.txt") or ""
local calls, nal, ndecl, nref, nbad = ip:match("sonde appels (%d+) alias (%d+) declares (%d+) references (%d+) fausses (%d+)")
print(string.format("  %s copie(s) sondée(s) ; alias non déclarés %s ; déclarés (gardés par référence, Et.REF_VIEW et Et.REF_L) %s ; références vérifiées %s, fausses %s",
  tostring(calls), tostring(nal), tostring(ndecl), tostring(nref), tostring(nbad)))
for l in ip:gmatch("\nalias ([^\n]+)") do print("    " .. l) end
check(tonumber(calls or 0) > 0 and tonumber(nal or -1) == 0, "aucune table d'une copie gardée n'est une table de global, hors champs déclarés")
check(tonumber(nref or 0) > 0 and tonumber(nbad or -1) == 0, "champs déclarés gardés par référence (même table que global)")

section("9. Unités de travail par étape (mode étapes, " .. MIN .. " min ; instructions Lua ; information)")
local oku, ou = sub("unites", MIN, "unites")
check(oku, "partie jouée")
local per, think = {}, {}
for n, t0, u in (slurp(ou .. "_info.txt") or ""):gmatch("unites (%d+) (%d+) (%d+)") do
  n, t0, u = tonumber(n), tonumber(t0), tonumber(u)
  local s = per[n] or { max = 0, sum = 0, k = 0 }
  per[n] = s
  s.max, s.sum, s.k = math.max(s.max, u), s.sum + u, s.k + 1
  local th = think[t0] or { e1 = 0, e4 = 0 }
  think[t0] = th
  if n <= 3 then th.e1 = th.e1 + u elseif n >= 6 then th.e4 = th.e4 + u end
end
local NAMES = Et.STAGES
for n = 1, #NAMES do
  local s = per[n]
  if s then print(string.format("  %-4s %4d fois : max %10d, moyenne %10d", NAMES[n], s.k, s.max, math.floor(s.sum / s.k))) end
end
local e1max, e4max = 0, 0
for _, th in pairs(think) do e1max = math.max(e1max, th.e1); e4max = math.max(e4max, th.e4) end
local s1 = math.max((per[1] or {}).max or 0, (per[2] or {}).max or 0, (per[3] or {}).max or 0)
local s4 = math.max((per[6] or {}).max or 0, (per[7] or {}).max or 0, (per[8] or {}).max or 0)
print(string.format("  E1 entier : max %d ; plus grosse tranche E1a-E1c : %d (%.0f %%)", e1max, s1, e1max > 0 and 100 * s1 / e1max or 0))
print(string.format("  E4 entier : max %d ; plus grosse tranche E4-E6 : %d (%.0f %%)", e4max, s4, e4max > 0 and 100 * s4 / e4max or 0))
check(per[1] and per[2] and per[3] and per[6] and per[7] and per[8], "toutes les étapes comptées")
end

print(string.format("[DECOUPAGE-PENSEE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
