--[[
  Lot X10-S0, fait F403 (7/11, x10-script ; fo-logs\2026-11-07_X10\M8_CRITERES.md §3 bis) : une table NEUVE rangée à chaque tick dans
  un local de MODULE (upvalue fermée dès que le fichier est chargé) bloque le marquage du ramasse-miettes de Lua 5.2 : la barrière
  avant de l'upvalue marque aussitôt toute la structure, et le cycle ne finit plus (mesuré : 9 cycles contre 21, tas de 516 Mo contre
  57 ; même signature en jeu, banc M8-01).
  1. RÈGLE STATIQUE sur script/ et shared/ : aucune affectation d'une table neuve (constructeur `{`) à un local de module dans une
     fonction, sauf les caches posés UNE fois, listés ci-dessous avec leur raison. Une entrée de plus se justifie à la relecture :
     « posé une fois », jamais « par tick » (sinon : un champ de table, `T.x = {}`, comme le profileur, script/core/profiler.lua).
  2. Mutant : une source qui a la forme doit être vue par la règle.
  3. Le fait lui-même, hors jeu, à petite échelle : même allocation rangée dans une upvalue fermée contre un champ de table.
  Usage : lua5.2 tests/upvalue_gc_test.lua   (depuis la racine du mod ; quelques secondes)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

-- Caches posés une fois (relevé du 7/11) : [fichier] = { [nom] = raison }.
local ALLOW = {
  ["script/core/profiler.lua"] = { timers = "remis à neuf à chaque bascule du profileur (set_enabled), jamais par tick",
    counts = "idem" },
  ["script/team/migration_champ.lua"] = { covering_name = "cache paresseux des noms, posé une fois" },
  ["shared/team/modules.lua"] = { ERAS = "index paresseux, posé une fois", ERA_REFUS = "idem", EPOCH_IDX = "idem" },
  ["script/ai3/cerveau.lua"] = { cat = "catalogue du cerveau, posé une fois (puis quand les données changent)" },
  ["script/ai3/industrie.lua"] = { LEC = "lecteur des données, posé une fois" },
  ["script/ai3/petrole.lua"] = { pack_rows = "cache paresseux, posé une fois" },
  ["script/ai3/prevision.lua"] = { POLLUTER_TYPES = "tables de types, posées une fois", TURRET_TYPES = "idem", SITE_TYPES = "idem" },
  ["script/team/front.lua"] = { LAB_TYPES = "tables de types, posées une fois", ASSET_TYPES = "idem" },
  ["script/team/plant_arms.lua"] = { STATUS_NAME = "table des états du moteur, posée une fois" },
  ["shared/content/guarantee.lua"] = { SPECS = "données des sites garantis, posées une fois" },
  ["shared/levels/config.lua"] = { cost_table = "table des coûts, posée une fois" },
  -- (intégrateur, 8/11 : lot LOURD point 2, b4be4c89) J.reset ne sert qu'aux bancs hors jeu (nouvelle partie simulée), jamais par tick
  ["script/core/lourd.lua"] = { served = "remis à neuf par J.reset, bancs hors jeu seulement, jamais par tick" },
  -- (TESTS-VERTS, relecture : lot PURGE-MINE, 77c26cc8) drills() rend DRILLS dès qu'il existe et ne le remet jamais à nil
  ["script/team/electrique.lua"] = { DRILLS = "foreuses électriques des données, cache paresseux posé une fois" },
}

--- Affectations d'une table neuve à un local de module dans une fonction : { { ligne, nom, texte } }.
local function scan_source(src)
  local tops = {}
  local lines = {}
  for l in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = l:gsub("\r$", "") end
  for _, l in ipairs(lines) do
    if not l:match("^local%s+function") then
      local names = l:match("^local%s+([%a_][%w_,%s]*)=") or l:match("^local%s+([%a_][%w_,%s]*)$")
      if names then for n in names:gmatch("[%a_][%w_]*") do tops[n] = true end end
    end
  end
  local KW = { ["local"] = true, ["if"] = true, ["elseif"] = true, ["return"] = true, ["while"] = true, ["until"] = true, ["for"] = true }
  local out = {}
  for i, l in ipairs(lines) do
    local code = l:gsub("%-%-.*$", "")
    if code:match("^%s+") then
      -- une ligne peut porter plusieurs instructions : « if c then x = {} end » ; chaque morceau est lu à part
      local cut = (" " .. code .. " "):gsub(" then ", "\1"):gsub(" else ", "\1"):gsub(" do ", "\1"):gsub(";", "\1")
      for seg in cut:gmatch("[^\1]+") do
        local lhs, rhs = seg:match("^%s*([%a_][%w_%s,]-)%s*=%s*(.-)%s*$")
        if lhs and rhs and rhs:sub(1, 1) == "{" and lhs:gsub("[%a_][%w_]*", ""):match("^[%s,]*$") then
          local first = lhs:match("^[%a_][%w_]*")
          if not KW[first] then
            for n in lhs:gmatch("[%a_][%w_]*") do
              if tops[n] then out[#out + 1] = { i, n, (code:gsub("^%s+", "")):sub(1, 100) } end
            end
          end
        end
      end
    end
  end
  return out
end

local function lua_files()
  local p = io.popen('dir /s /b script\\*.lua shared\\*.lua 2>nul')
  local list = {}
  if p then
    for l in p:lines() do
      local rel = l:gsub("\\", "/"):match("/(script/.*)$") or l:gsub("\\", "/"):match("/(shared/.*)$")
      if rel then list[#list + 1] = rel end
    end
    p:close()
  end
  if #list == 0 then
    p = io.popen("find script shared -name '*.lua' 2>/dev/null")
    if p then for l in p:lines() do list[#list + 1] = (l:gsub("^%./", "")) end p:close() end
  end
  table.sort(list)
  return list
end

-- 1. règle statique
local files = lua_files()
local bad, allowed, seen_allow = {}, 0, {}
for _, f in ipairs(files) do
  local fh = io.open(f, "rb")
  if fh then
    local src = fh:read("*a")
    fh:close()
    for _, h in ipairs(scan_source(src)) do
      local a = ALLOW[f]
      if a and a[h[2]] then
        allowed = allowed + 1
        seen_allow[f .. ":" .. h[2]] = true
      else
        bad[#bad + 1] = string.format("%s:%d %s (%s)", f, h[1], h[2], h[3])
      end
    end
  end
end
print(string.format("[UPVALUE-GC] %d fichier(s) relus, %d affectation(s) de cache permises", #files, allowed))
for _, b in ipairs(bad) do print("   " .. b) end
check(#files > 100 and #bad == 0, string.format("règle : aucune table neuve affectée à un local de module dans une fonction, hors caches listés (%d écart(s))", #bad))

-- 2. mutant : la forme exacte de l'ancien profileur doit être vue
local MUT = "local dt_names = {}\nlocal function flush()\n  dt_names = {}\nend\n"
local MUT2 = "local a, sh = nil, nil\nlocal function on(x)\n  if x then sh = { n = 0 } end\nend\n"
local FIELD = "local DT = { names = {} }\nlocal function flush()\n  DT.names = {}\n  local x = {}\n  if DT.names == x then return end\nend\n"
check(#scan_source(MUT) == 1 and #scan_source(MUT2) == 1 and #scan_source(FIELD) == 0,
  "mutant : la table neuve dans un local de module est vue (aussi après « if … then »), le champ de table et le local de fonction ne le sont pas")

-- 3. le fait, hors jeu, à petite échelle (chunks chargés : upvalues FERMÉES, comme un fichier du mod)
local function play(store)
  local chunk = [[
    local ballast, junk, H = nil, nil, {}
    return function(t)
      if not ballast then
        ballast = {}
        for i = 1, 40000 do ballast[i] = { a = i, b = i, c = i, d = i } end
        return
      end
      local j = {}
      for i = 1, 1200 do j[i] = { a = i, b = i, c = i, d = i } end
      ]] .. store .. [[

    end
  ]]
  collectgarbage("collect")
  local step = assert(load(chunk))()
  local n = 0
  local arm
  arm = function() setmetatable({}, { __gc = function() n = n + 1; arm() end }) end
  arm()
  local top = 0
  for t = 1, 900 do
    step(t)
    local c = collectgarbage("count")
    if c > top then top = c end
  end
  local cycles = n
  step = nil
  arm = function() end
  collectgarbage("collect")
  return cycles, top
end
local cu, tu = play("junk = j")
local cf, tf = play("H.junk = j")
print(string.format("[UPVALUE-GC] upvalue fermée : %d fin(s) de cycle, tas au plus %.0f Mo ; champ de table : %d, %.0f Mo", cu, tu / 1024, cf, tf / 1024))
check(tu > 2.5 * tf and cf > cu, "F403 : la table neuve rangée dans une upvalue fermée retient le ramasse-miettes (tas et cycles), pas le champ de table")

print(string.format("[UPVALUE-GC] BILAN : %d OK%s", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or ""))
os.exit(fail_n == 0 and 0 or 1)
