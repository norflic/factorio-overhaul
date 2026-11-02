--[[
  Lot AGES : libellé d'un objectif d'équipe (shared/team/objectif.lua) et traductions. Retour du DC du 2/11 : « Unknown key:
  "fo-team.goal-ia3-alim-assembling-machine-2" » à l'écran.
    §1 cas écrits : chaque famille de but donne son libellé et ses paramètres ;
    §2 TOUT objectif affichable a sa clé de traduction, en français et en anglais, avec le bon nombre de paramètres :
       barreaux de l'échelle (T.ladder, T.player_ladder), clés fixes, clés paramétrées ;
    §3 le code ne produit pas de famille de but que le libellé ignore : tous les « key = "<famille>:" » des générateurs de
       buts (shared/ai3), passés par la même transformation que le cerveau (« ia3- » + « : » devenu « - »), ne tombent pas
       sur le libellé de repli ;
    §4 les trois écrans (fenêtre d'équipe, ligne d'objectif, journal) passent par script/team/objectif.lua ;
    §5 mutants : chaque règle retirée est vue.
  Usage : lua5.2 tests/objectif_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")

local pass, fail = 0, 0
local function check(c, m)
  if c then pass = pass + 1 else fail = fail + 1 print("[OBJECTIF] ECHEC : " .. m) end
end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local function load_obj(src)
  local fn, err = load(src, "=objectif", "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

local LOCALE_FILES = { "factorio-overhaul", "ia3c", "ia3e", "migration_declenche", "s1", "ages" }

--- Clés « [fo-team] » des fichiers de langue d'une langue : { clé = texte } (tous les fichiers du dossier).
local function locale(lang)
  local out = {}
  local dir = "locale/" .. lang
  local p = assert(io.popen('ls "' .. dir .. '"'))
  for name in p:lines() do
    local sec
    for line in (read(dir .. "/" .. name)):gmatch("[^\r\n]+") do
      local s = line:match("^%[(.-)%]$")
      if s then sec = s
      elseif sec == "fo-team" then
        local k, v = line:match("^([^=;#][^=]*)=(.*)$")
        if k then out[k] = v end
      end
    end
  end
  p:close()
  return out
end

local function arity(text)
  local n = 0
  for d in text:gmatch("__(%d)__") do if tonumber(d) > n then n = tonumber(d) end end
  return n
end

local SRC = read("shared/team/objectif.lua")
local FR, EN = locale("fr"), locale("en")

local function suite(Obj)
  local function d(goal) return Obj.describe(goal) end
  local function id_args(goal)
    local r = d(goal)
    local a = {}
    for i, x in ipairs(r.args) do a[i] = x.kind .. ":" .. tostring(x.v) end
    return r.id, table.concat(a, ",")
  end

  -- §1 cas écrits.
  local cases = {
    { "ia3-alim-assembling-machine-2", "ia3-alim", "item:assembling-machine-2" },
    { "ia3-auto-iron-plate", "ia3-auto-objet", "item:iron-plate" },
    { "ia3-auto-centrale", "ia3-auto-centrale", "" },
    { "ia3-auto-electric-furnace", "ia3-auto-objet", "item:electric-furnace" },
    { "ia3-extraction-iron", "ia3-extraction-iron", "" },
    { "ia3-extraction-uranium", "ia3-extraction-autre", "outpost:uranium" },
    { "ia3-couverture-copper", "ia3-couverture", "outpost:copper" },
    { "ia3-releve-stone", "ia3-releve", "outpost:stone" },
    { "ia3-recherche", "ia3-recherche", "" },
    { "ia3-armee", "ia3-armee", "" },
    { "ia3-capital-fonderie", "ia3-capital-fonderie", "" },
    { "ia3-defense-munitions", "ia3-defense-munitions", "" },
    { "ia3-capital-gun-2-30", "ia3-capital-up", "entity:gun,number:2" },
    { "ia3-capital-command-2-228", "ia3-capital-up", "entity:command,number:2" },
    { "ia3-capital-command-1-pose", "ia3-capital-pose", "entity:command" },
    { "ia3-capital-remplacer-stone-furnace>steel-furnace-77", "ia3-capital-remplacer", "item:stone-furnace,item:steel-furnace" },
    { "ia3-capi-couvrir-123", "ia3-capi-couvrir", "text:123" },
    { "ia3-capi-ouvrir-9", "ia3-capi-ouvrir", "text:9" },
    { "ia3-capi-packs-chemical-science-pack", "ia3-capi-packs", "item:chemical-science-pack" },
    { "ia3-capi-chaine-electronic-circuit", "ia3-capi-chaine", "item:electronic-circuit" },
    { "ia3-capi-fours-iron-plate", "ia3-capi-fours", "item:iron-plate" },
    { "ia3-capi-labos-lab", "ia3-capi-labos", "" },
    { "ia3-capi-energie", "ia3-capi-energie", "" },
    { "ia3-capi-inconnu-x", "ia3-capi-autre", "text:inconnu-x" },
    { "ia3-quelque-chose-de-neuf", "ia3-autre", "text:quelque-chose-de-neuf" },
    { "coal", "coal", "" },
    { "tech3", "tech3", "" },
  }
  for _, c in ipairs(cases) do
    local id, args = id_args(c[1])
    check(id == c[2] and args == c[3], "§1 " .. c[1] .. " -> " .. id .. " (" .. args .. ") au lieu de " .. c[2] .. " (" .. c[3] .. ")")
  end
  check(id_args(nil) == "", "§1 objectif absent : identifiant vide, pas d'erreur")

  -- §2 traductions : tout identifiant produit existe en FR et EN, avec le bon nombre de paramètres.
  local ids = {}
  for _, c in ipairs(cases) do ids[d(c[1]).id] = true end
  for _, step in ipairs(T.ladder) do ids[d(step.key).id] = true end
  for _, step in ipairs(T.player_ladder) do ids[d(step.key).id] = true end
  for k in pairs(Obj.FIXED) do ids[k] = true end
  for _, k in ipairs(T.OUTPOST_ORDER) do ids["ia3-extraction-" .. k] = true end
  for k in pairs(Obj.FIXED_AUTO) do ids[d("ia3-auto-" .. k).id] = true end
  for k in pairs(Obj.ARITY) do ids[k] = true end
  local n_ids = 0
  for id in pairs(ids) do
    n_ids = n_ids + 1
    local want = Obj.ARITY[id] or 0
    local f, e = FR["goal-" .. id], EN["goal-" .. id]
    check(f ~= nil, "§2 clé française absente : fo-team.goal-" .. id)
    check(e ~= nil, "§2 clé anglaise absente : fo-team.goal-" .. id)
    if f then check(arity(f) == want, "§2 paramètres du texte français de " .. id .. " : " .. arity(f) .. " au lieu de " .. want) end
    if e then check(arity(e) == want, "§2 paramètres du texte anglais de " .. id .. " : " .. arity(e) .. " au lieu de " .. want) end
  end
  check(n_ids >= 35, "§2 au moins 35 identifiants contrôlés (" .. n_ids .. ")")
  -- Les genres d'avant-poste du jeu sont ceux du libellé, et chacun a sa clé « outpost-<genre> ».
  for _, k in ipairs(T.OUTPOST_ORDER) do
    check(Obj.OUTPOSTS[k], "§2 genre d'avant-poste connu du libellé : " .. k)
    check(FR["outpost-" .. k] and EN["outpost-" .. k], "§2 clé outpost-" .. k)
  end
  for k in pairs(Obj.OUTPOSTS) do
    local found = false
    for _, o in ipairs(T.OUTPOST_ORDER) do if o == k then found = true end end
    check(found, "§2 genre d'avant-poste du libellé absent de T.OUTPOST_ORDER : " .. k)
  end

  -- §3 familles de buts du code.
  local files = { "shared/ai3/buts.lua", "shared/ai3/automatiser.lua", "shared/ai3/capital.lua", "shared/ai3/capitalisation.lua" }
  local seen, n_scan = {}, 0
  for _, path in ipairs(files) do
    for line in read(path):gmatch("[^\r\n]+") do
      if line:find("goals[#goals + 1] = {", 1, true) or line:find('return { key = "capital:"', 1, true) then
        for fam in line:gmatch('key = "(%a+):?"?') do seen[fam] = true end
      end
    end
  end
  for fam in pairs(seen) do
    n_scan = n_scan + 1
    local sample = "ia3-" .. fam .. "-x1"
    local own = { recherche = "ia3-recherche", armee = "ia3-armee", defense = "ia3-defense-munitions", capital = "ia3-capital-fonderie",
      capi = "ia3-capi-energie" }
    if own[fam] then sample = own[fam] end
    local r = d(sample)
    check(r.id ~= "ia3-autre" and r.id ~= "ia3-capi-autre", "§3 famille de but du code sans libellé : " .. fam .. " -> " .. r.id)
  end
  check(n_scan >= 9, "§3 au moins 9 familles lues dans le code (" .. n_scan .. ")")
  -- Les genres de la capitalisation (clé « capi:<genre>:… ») ont tous un libellé propre.
  local capi_src = read("shared/ai3/capitalisation.lua")
  for _, kind in ipairs({ "couvrir", "ouvrir", "packs", "chaine", "fours", "labos", "energie" }) do
    check(capi_src:find('"' .. kind .. '"', 1, true) ~= nil, "§3 genre de capitalisation encore dans le code : " .. kind)
    check(d("ia3-capi-" .. kind .. "-x").id == "ia3-capi-" .. kind, "§3 genre de capitalisation : " .. kind)
  end
end

local Obj = assert(load_obj(SRC))
suite(Obj)

-- §4 branchement : les trois écrans passent par le libellé.
local function has(path, needle) return read(path):find(needle, 1, true) ~= nil end
check(has("script/gui/team_window.lua", "Objectif.name(t.goal)"), "§4 fenêtre d'équipe, ligne d'objectif")
check(has("script/gui/team_window.lua", 'Objectif.name((("ia3-" .. p.key)'), "§4 fenêtre d'équipe, liste des projets")
check(has("script/team/team.lua", "Objectif.name(t.goal)"), "§4 Team.goal_text")
check(has("script/gui/ia1i_journal.lua", "Objectif.name(tostring(e.a))"), "§4 journal de l'équipe")
for _, p in ipairs({ "script/gui/team_window.lua", "script/team/team.lua", "script/gui/ia1i_journal.lua" }) do
  local s = read(p)
  check(not s:find('"fo-team.goal-" .. t.goal', 1, true) and not s:find('"fo-team.goal-" .. tostring(e.a)', 1, true),
    "§4 plus de clé « fo-team.goal-<objectif> » écrite à la main dans " .. p)
end

-- §5 mutants : la série est rejouée sur le mutant ; ses échecs sont ATTENDUS (retirés du total), il doit en avoir au moins un.
local function mutant(name, from, to)
  local a, b = SRC:find(from, 1, true)
  if not a then check(false, "§5 mutant « " .. name .. " » : motif introuvable") return end
  local m = load_obj(SRC:sub(1, a - 1) .. to .. SRC:sub(b + 1))
  if not m then check(false, "§5 mutant « " .. name .. " » : ne se charge pas") return end
  local p0, f0 = pass, fail
  local real_print = print
  print = function() end
  local ok = pcall(suite, m)
  print = real_print
  local added = fail - f0
  pass, fail = p0, f0
  check(added > 0 or not ok, "§5 mutant « " .. name .. " » non vu")
end
mutant("alim retiré", 'return res("ia3-alim", item(obj))', 'return res("ia3-autre", item(obj))')
mutant("amélioration retirée", 'return res("ia3-capital-up", { kind = "entity", v = fam }, { kind = "number", v = tonumber(lvl) })', 'return res("ia3-autre", text(cap))')
mutant("relève retirée", 'if kind then return res("ia3-releve", { kind = "outpost", v = kind }) end', 'if kind then return res("ia3-autre", text(kind)) end')
mutant("couverture retirée", 'return res("ia3-couverture", { kind = "outpost", v = kind })', 'return res("ia3-autre", text(kind))')
mutant("capi retiré", 'if capi then', 'if false then')
mutant("remplacer retiré", 'if from and to then return res("ia3-capital-remplacer", item(from), item(to)) end', '')
mutant("paramètres de l'amélioration", '["ia3-capital-up"] = 2', '["ia3-capital-up"] = 1')

print(string.format("[OBJECTIF] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
