--[[
  Lot DÉCOUPAGE-PENSÉE (7/11) : une pensée d'équipe en quatre étapes (script/team/team.lua, shared/team/etapes.lua). Critères :
  fo-logs/2026-11-07_DECOUPAGE-PENSEE/CRITERES.md.

  Partie de banc au moteur simulé : 4 factions (plan directeur, centrale sur un étang, modules), ia3e allumé, votre équipe (coffre
  posé au centre). Chaque passage est un PROCESSUS à part (`--run`), pour partir d'un moteur et de modules neufs :
    lua5.2 tests/decoupage_pensee_test.lua --run <mode> <minutes> <sortie> [--sans <view.x|plan.x>]
  modes : bloc (les quatre étapes au tick T, copie STRICTE), etapes (T à T + 3), charge (etapes, sauvegarde et chargement simulés
  à chaque tick où une étape attend), config (charge + on_configuration_changed à ces ticks), config-ref (mêmes chargements, même
  nombre d'appels à on_configuration_changed, au premier tick sans étape en attente), bascule (bloc puis etapes à mi-partie),
  releve (bloc, copie remplacée par un enregistreur des champs lus). Sorties : <sortie>_global.txt, _journal.txt, _trace.txt,
  _info.txt. FO_MUT_CFG=efface|ligne : mutants du mode config.

  Sans argument, le banc complet (environ 45 min sur un PC chargé ; FO_RAPIDE=1 : parties 3 à 6 ; FO_SEULE5=1 : partie 5) :
    1. relevé : les champs lus en E4 sont tous dans Et.VIEW et Et.PLAN ;
    2. mutants : chaque champ retiré à tour de rôle fait échouer la partie (copie stricte) ; ceux d'Et.RARES peuvent survivre ;
    3. etapes : deux parties identiques (déterminisme) ; ordre des portées de chaque pensée et ticks T à T + 3 ;
    4. charge : identique à la partie continue ;
    5. config : chaque pensée coupée par un changement de configuration finit, sans abandon ni rattrapage ; global identique à
       config-ref SANS filtre ; journal identique hors d'une liste blanche exacte (5 préfixes), avec autant de lignes de chaque
       sorte des deux côtés ; mutants « efface » (la migration perd les étapes) et « ligne » (ligne de décision) refusés ;
    6. bascule : une partie commencée d'un bloc (état d'une 0.6.56) passe aux étapes sans erreur.
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
      local L = list == "view" and Et.VIEW or Et.PLAN
      local j
      for i, k in ipairs(L) do if k == key then j = i end end
      assert(j, "champ inconnu des listes : " .. tostring(sans))
      table.remove(L, j)
    end
    Team.ETAPES = (mode == "etapes" or mode == "charge" or mode == "config" or mode == "config-ref" or mode == "sig")
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
  for _, n in ipairs({ "team:view", "team:plan", "team:board", "team:poles", "team:build", "tt:recon", "tt:reparation", "tt:repair",
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
    local HOW = { "autre", "sans", "meme" }
    local used = {}
    for _ = 1, total do
      M.run_ticks(1)
      done = done + 1
      if step <= 3 then
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
          if how == "autre" then pick.team.etape.sig = "view:x|plan:y" elseif how == "sans" then pick.team.etape.sig = nil end
          local s = { f = pick, how = how, t0 = pick.team.etape.t0 }
          W.on_config({ mod_changes = {} })
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
    info[#info + 1] = string.format("sig %s %s %s pensees_apres %d", tostring(s.f.key or "player"), s.how, s.after,
      ((s.f.team.etapes or {}).pensees or 0) - s.p0)
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
section("0. Contrôle statique des champs lus en E4 (source de TT.e4 et des fonctions qui reçoivent la vue ou le plan)")
local SUIVIES = {
  ["TT.e4"] = { file = "script/team/team.lua", header = "TT.e4 = function(f, surface, tick, fz)", params = { view = "view", plan = "plan" } },
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
local queue = { { name = "TT.e4", lists = { view = "view", plan = "plan" } } }
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

end

if not os.getenv("FO_SEULE5") then -- FO_SEULE5=1 : partie 5 seulement
section("3. Mode étapes : déterminisme, ordre, ticks (" .. MIN .. " min)")
local ok1, o1, t1 = sub("etapes", MIN, "etapes1")
local ok2, o2, t2 = sub("etapes", MIN, "etapes2")
check(ok1 and ok2, "deux parties jouées" .. ((ok1 and ok2) and "" or (" : " .. (ok1 and t2 or t1):sub(-300))))
local g1, j1 = slurp(o1 .. "_global.txt"), slurp(o1 .. "_journal.txt")
check(g1 and g1 == slurp(o2 .. "_global.txt"), "global identique d'une partie à l'autre")
check(j1 and j1 == slurp(o2 .. "_journal.txt"), "journal identique d'une partie à l'autre")
-- Ordre : chaque pensée commence par team:view ; ses portées suivent l'ordre canonique, à T (E1), T + 1 (E2), T + 2 (E3), T + 3 (E4)
local ORDER = { { "team:view", 0 }, { "team:plan", 0 }, { "team:board", 0 }, { "team:poles", 0 }, { "team:build", 1 }, { "tt:recon", 2 },
  { "tt:reparation", 2 }, { "tt:repair", 2 }, { "tt:inter", 3 }, { "team:market", 3 }, { "tt:idle", 3 }, { "team:scale", 3 },
  { "tt:stock", 3 }, { "tt:spares", 3 }, { "tt:gisement", 3 }, { "tt:foswap", 3 }, { "tt:migchamp", 3 }, { "tt:capital", 3 },
  { "tt:fin", 3 }, { "faction:attack", 3 } }
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
check(bad_tick == 0, "étapes à T, T + 1, T + 2, T + 3")
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
section("7. Signature des champs gardés au changement de configuration (relecture de 6fcfe757, 3 min)")
local oks, os7 = sub("sig", 3, "sig")
check(oks, "partie jouée")
local is = slurp(os7 .. "_info.txt") or ""
local js = slurp(os7 .. "_journal.txt") or ""
local seen = { autre = 0, sans = 0, meme = 0 }
local bad = {}
for how, after, n in is:gmatch("sig %S+ (%a+) (%a+) pensees_apres (%d+)") do
  seen[how] = seen[how] + 1
  local want = (how == "meme") and "garde" or "efface"
  if after ~= want or tonumber(n) < 1 then bad[#bad + 1] = how .. " " .. after .. " " .. n end
end
print(string.format("  équipes : autre signature %d, sans signature %d, même signature %d", seen.autre, seen.sans, seen.meme))
check(seen.autre == 1 and seen.sans == 1, "une pensée d'une autre signature et une sans signature au changement de configuration")
check(#bad == 0, "autre ou sans signature : effacée ; même signature : gardée ; chaque équipe repense ensuite (" .. table.concat(bad, " ; ") .. ")")
local nlog = 0
for _, l in ipairs(lines_of(js)) do
  if l:find("[FO-ETAPES]", 1, true) and l:find("effacee a l'etape", 1, true) then nlog = nlog + 1 end
end
check(nlog == 2, "deux lignes [FO-ETAPES] « effacée » au journal (" .. nlog .. ")")
end

print(string.format("[DECOUPAGE-PENSEE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
