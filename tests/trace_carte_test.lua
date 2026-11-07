--[[
  Lot VIDEO L11 : banc HORS JEU de la trace sur la carte (règle pure shared/ai3/trace.lua, runtime script/ai3/trace_carte.lua) sur le
  moteur simulé (tests/mock_engine.lua, complété ICI sans le modifier : numéro d'étiquette, find_chart_tags, et F131 : add_chart_tag
  rend nil sur un chunk non cartographié). Lancement, depuis la racine du mod : lua5.2 tests/trace_carte_test.lua
    1. une ligne [FO-TRACE] par événement ; une étiquette seulement avec une position ;
    2. faction : étiquette sur SA force ; réglage de débogage allumé : aussi sur la force du joueur ; coupé : copies retirées ;
       votre équipe : une seule étiquette, sur la force du joueur ;
    3. au plus Tr.MAX par force, la plus ancienne retirée ; même clé : une étiquette, texte remplacé ; même texte : aucun appel ;
    4. chunk non cartographié (F131) : rien posé, gardé « à poser », posé par TC.flush une fois cartographié ;
    5. texte borné, coupé sur un caractère UTF-8 entier ; état sérialisable ;
    6. coût en instructions ; 7. mutants refusés.
]]
package.path = "./?.lua;" .. package.path
local Mk = require("tests.mock_engine")
local Tr = require("shared.ai3.trace")
local TC = require("script.ai3.trace_carte")
local LIMIT = Tr.MAX -- borne attendue, lue AVANT les mutants (un mutant qui la change ne change pas l'attente)
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end

local W, charted, calls
local function boot()
  Mk.new_world()
  W = Mk.world()
  charted, calls = {}, 0
  local num = 0
  for _, fname in ipairs({ "player", "enemy" }) do
    local f = W.forces[fname]
    local base = f.add_chart_tag
    f.is_chunk_charted = function(surface, c) assert(surface and c and c.x and c.y) return charted[c.x .. "," .. c.y] == true end
    f.add_chart_tag = function(surface, tag)
      calls = calls + 1
      local c = math.floor(tag.position.x / 32) .. "," .. math.floor(tag.position.y / 32)
      if not charted[c] then return nil end -- F131
      assert(tag.icon or (tag.text and tag.text ~= ""), "ChartTagSpec : icône ou texte")
      local t = base(surface, tag)
      num = num + 1
      t.tag_number, t.icon = num, tag.icon
      return t
    end
    f.find_chart_tags = function(surface, area)
      local out = {}
      for _, t in ipairs(f._tags) do
        local p = t.position
        if t.valid and p.x >= area[1][1] and p.x <= area[2][1] and p.y >= area[1][2] and p.y <= area[2][2] then out[#out + 1] = t end
      end
      return out
    end
  end
end
local function live(fname)
  local out = {}
  for _, t in ipairs(W.forces[fname]._tags) do if t.valid then out[#out + 1] = t end end
  return out
end
local function chart_all() for cx = -4, 4 do for cy = -4, 4 do charted[cx .. "," .. cy] = true end end end
local function faction() return { key = "rouge", force = "enemy", team = {} } end
local function ev(i, extra)
  local e = { key = "m" .. i, item = "iron-plate", x = 10 + i, y = 20, why = "manque mesure", rank = 2, kind = "decide" }
  for k, v in pairs(extra or {}) do e[k] = v end
  return e
end

local function battery(verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  -- 1 et 2
  boot(); chart_all()
  local f = faction()
  local nlog = #W.logs
  TC.note(f, { key = "x", item = "iron-plate", why = "ordre sans lieu", rank = 1, kind = "decide" }, 60)
  ck(#W.logs == nlog + 1 and W.logs[#W.logs]:find("[FO-TRACE]", 1, true) ~= nil, "une ligne [FO-TRACE] par événement")
  ck(#live("enemy") == 0, "sans position : aucune étiquette")
  W.settings[TC.SETTING] = false
  TC.note(f, ev(1), 120)
  ck(#live("enemy") == 1 and #live("player") == 0, "réglage coupé : étiquette sur la force de la faction seulement")
  ck(live("enemy")[1] and live("enemy")[1].icon and live("enemy")[1].icon.name == "iron-plate", "icône du produit")
  W.settings[TC.SETTING] = true
  TC.note(f, ev(2), 180)
  ck(#live("enemy") == 2 and #live("player") == 1, "réglage allumé : aussi sur la force du joueur (vue du DC)")
  TC.flush(f, 240)
  ck(#live("player") == 2, "flush : l'étiquette d'avant le réglage est copiée chez le joueur")
  W.settings[TC.SETTING] = false
  TC.flush(f, 300)
  ck(#live("player") == 0 and #live("enemy") == 2, "réglage coupé : copies retirées de la force du joueur, celles de la faction restent")
  -- votre équipe
  W.settings[TC.SETTING] = true
  local mine = { key = "player", force = "player", team = {} }
  TC.note(mine, ev(3), 360)
  ck(#live("player") == 1, "votre équipe : une seule étiquette, sur la force du joueur")
  -- 3. borne et remplacement
  boot(); chart_all()
  W.settings[TC.SETTING] = false
  f = faction()
  for i = 1, LIMIT + 5 do TC.note(f, ev(i), 60 * i) end
  local tags = live("enemy")
  ck(#tags == LIMIT, string.format("au plus %d étiquettes par force (%d)", LIMIT, #tags))
  local xs = {}
  for _, t in ipairs(tags) do xs[t.position.x] = true end
  ck(xs[10 + LIMIT + 5] and xs[10 + 6] and not xs[10 + 5] and not xs[11], "la plus ancienne est retirée, la plus récente gardée")
  local c0 = calls
  TC.note(f, ev(LIMIT + 5), 9999)
  ck(calls == c0, "même étiquette : aucun appel au moteur")
  TC.note(f, ev(LIMIT + 5, { kind = "pose", why = "pose au lot" }), 10000)
  local same = 0
  local txt
  for _, t in ipairs(live("enemy")) do if t.position.x == 10 + LIMIT + 5 then same = same + 1; txt = t.text end end
  ck(same == 1 and txt and txt:find("pose", 1, true), "même clé : une étiquette, texte remplacé (" .. tostring(txt) .. ")")
  ck(#live("enemy") == LIMIT, "remplacement : le compte ne bouge pas")
  -- 4. F131
  boot()
  f = faction()
  TC.note(f, ev(1), 60)
  ck(#live("enemy") == 0 and #Tr.pending(f.team.trace, "enemy") == 1, "chunk non cartographié : rien posé, gardé à poser")
  chart_all()
  local put = TC.flush(f, 3600)
  ck(put == 1 and #live("enemy") == 1, "cartographié ensuite : posé par flush")
  ck(#Tr.pending(f.team.trace, "enemy") == 0, "plus rien à poser")
  -- 5. texte et état
  local long = Tr.text({ rank = 3, kind = "decide", why = string.rep("é", 40) })
  ck(#long <= Tr.TEXT_MAX, "texte borné (" .. #long .. " octets)")
  local okutf = true
  local last = long:byte(#long)
  if last and last >= 0xC0 then okutf = false end
  if last and last >= 0x80 and last < 0xC0 then
    local lead = long:byte(#long - 1)
    okutf = lead and lead >= 0xC0 or false
  end
  ck(okutf, "coupé sur un caractère entier")
  ck(long:sub(1, 3) == "R3 ", "le rang d'abord")
  local function has_bad(t, seen)
    seen = seen or {}
    if seen[t] then return false end
    seen[t] = true
    for _, v in pairs(t) do
      if type(v) == "function" or (type(v) == "table" and (v._lua_object or has_bad(v, seen))) then return true end
    end
    return false
  end
  ck(not has_bad(f.team.trace), "état sérialisable : ni fonction ni objet du moteur")
  return fails
end

print("[TRACE] 1-5. règle et runtime")
check(battery(true) == 0, "batterie sans échec")

-- 6. coût
do
  boot(); chart_all()
  W.settings[TC.SETTING] = true
  local f = faction()
  for i = 1, Tr.MAX do TC.note(f, ev(i), i) end
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  TC.note(f, ev(100), 1000)
  debug.sethook()
  local p = 0
  debug.sethook(function() p = p + 1 end, "", 1)
  Tr.push(Tr.new(), ev(1), 1)
  debug.sethook()
  local fl = 0
  debug.sethook(function() fl = fl + 1 end, "", 1)
  TC.flush(f, 2000)
  debug.sethook()
  print(string.format("[TRACE] instructions : note avec retrait de la plus ancienne, 2 forces %d (moteur simulé compris) ; Tr.push seul %d ; flush (%d étiquettes, rien à faire) %d",
    c, p, Tr.MAX, fl))
  check(p < 1500 and c < 20000 and fl < 20000, "coût borné (un appel par module décidé ou posé)")
end

-- 7. mutants : patch de la table du module, ou du SOURCE pour une fonction locale
print("[TRACE] 7. mutants")
local function with_source(path, from, to, modname, fn)
  local fh = assert(io.open(path, "rb")); local src = fh:read("*a"); fh:close()
  local s, n = src:gsub(from, to)
  assert(n > 0, "mutant sans effet : " .. from)
  local m = assert(load(s, "@" .. path .. " (mutant)"))()
  local old = package.loaded[modname]
  package.loaded[modname] = m
  local r = fn(m)
  package.loaded[modname] = old
  return r
end
local function run_mutant(name, setup, teardown)
  setup()
  local ok, f = pcall(battery, false)
  teardown()
  if not ok then f = 1 end
  check(f > 0, "mutant refusé : " .. name .. (ok and "" or " (plantage)"))
end
local function patch(tbl, k, v) local old = tbl[k]; return function() tbl[k] = v end, function() tbl[k] = old end end
local function source_mutant(name, path, modname, from, to, field_owner)
  -- remplace les fonctions du module utilisé par TC (même table) par celles du source muté
  local saved = {}
  run_mutant(name, function()
    with_source(path, from, to, modname, function(m)
      for k, v in pairs(m) do saved[k] = field_owner[k]; field_owner[k] = v end
    end)
  end, function() for k, v in pairs(saved) do field_owner[k] = v end end)
end
do local s, t = patch(TC, "forces", function(f) return { game.forces[f.force] } end); run_mutant("étiquette sur la force de la faction seulement", s, t) end
do local s, t = patch(Tr, "MAX", 1e9); run_mutant("aucune borne d'étiquettes", s, t) end
do local s, t = patch(Tr, "cut", function(x) return tostring(x or "") end); run_mutant("texte non borné", s, t) end
source_mutant("retirer la plus RÉCENTE au lieu de la plus ancienne", "shared/ai3/trace.lua", "shared.ai3.trace",
  "table%.remove%(keep, 1%)", "table.remove(keep, #keep - 1)", Tr)
source_mutant("même clé : pas de remplacement (doublons)", "shared/ai3/trace.lua", "shared.ai3.trace",
  "if e%.key == ev%.key then", "if false then", Tr)
source_mutant("coupe au milieu d'un caractère UTF-8", "shared/ai3/trace.lua", "shared.ai3.trace",
  "if not b or b < 0x80 or b >= 0xC0 then break end", "break", Tr)
source_mutant("pas de nouvel essai après la cartographie", "script/ai3/trace_carte.lua", "script.ai3.trace_carte",
  "for _, e in ipairs%(Tr%.pending%(st, force%.name%)%) do", "for _, e in ipairs({}) do", TC)
source_mutant("copies chez le joueur gardées quand le réglage est coupé", "script/ai3/trace_carte.lua", "script.ai3.trace_carte",
  "if not allowed%[fname%] then", "if false then", TC)

print(string.format("[TRACE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
