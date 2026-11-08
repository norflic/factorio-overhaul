--[[
  Lot TV-GARDES (W04) : chaque garde du registre shared/ai3/gardes.lua a sa mesure et son refus ÉCRIT. Banc HORS JEU. Lancement, depuis la
  racine du mod : lua5.2 tests/gardes_registre_test.lua
    A. chaque garde : sa sonde (la VRAIE garde, mesure retirée) ferme avec une raison non vide, ou le registre écrit pourquoi elle reste ouverte ;
    B. chaque fichier de shared/ marqué « fermé par défaut » / « garde fermée » est au registre (une garde nouvelle sans refus fait échouer ce banc) ;
    C. chaque entrée a un fichier existant, des appelants écrits, une mesure écrite ;
    D. 14 mutants du texte source (la garde s'ouvre ou perd son refus) : chacun doit être vu par la sonde ;
    E. registre amputé (un fichier retiré) : B le voit.
]]
package.path = "./?.lua;" .. package.path
local G = require("shared.ai3.gardes")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function slurp(p) local f = io.open(p, "rb"); if not f then return nil end local x = f:read("*a"); f:close(); return x end

-- A. chaque garde
for _, e in ipairs(G.LIST) do
  local r = G.verdict(e)
  check(r == "ok", "A : " .. e.id .. " : " .. r)
end

-- C. entrées complètes, identifiants uniques
do
  local seen = {}
  for _, e in ipairs(G.LIST) do
    check(not seen[e.id], "C : identifiant en double : " .. e.id)
    seen[e.id] = true
    check(slurp(e.fichier) ~= nil, "C : " .. e.id .. " : fichier absent : " .. tostring(e.fichier))
    check(type(e.mesure) == "string" and #e.mesure > 3, "C : " .. e.id .. " : mesure non ecrite")
    check(type(e.appelant) == "string" and #e.appelant > 3, "C : " .. e.id .. " : appelant non ecrit")
    check(e.verdict == "ferme" or e.verdict == "voulu", "C : " .. e.id .. " : verdict inconnu")
  end
end

-- B. complétude : les fichiers marqués
local function ls(dir)
  local out = {}
  local win = package.config:sub(1, 1) == "\\"
  local p = io.popen(win and ('dir /b "' .. dir:gsub("/", "\\") .. '" 2>nul') or ('ls "' .. dir .. '" 2>/dev/null'))
  if p then for l in p:lines() do out[#out + 1] = dir .. "/" .. l end p:close() end
  return out
end
local function marked_files()
  local files = {}
  for _, d in ipairs({ "shared/ai3", "shared/team" }) do
    for _, f in ipairs(ls(d)) do
      if f:match("%.lua$") then
        local src = slurp(f) or ""
        for _, pat in ipairs(G.MARQUES) do
          if src:find(pat) then files[#files + 1] = f; break end
        end
      end
    end
  end
  return files
end
local function missing(list)
  local have = {}
  for _, e in ipairs(list) do have[e.fichier] = true end
  local out = {}
  for _, f in ipairs(marked_files()) do if not have[f] and f ~= "shared/ai3/gardes.lua" then out[#out + 1] = f end end
  return out
end
do
  local marked = marked_files()
  check(#marked >= 10, "B : le balayage trouve les fichiers marques (" .. #marked .. ")")
  local m = missing(G.LIST)
  check(#m == 0, "B : fichier(s) marque(s) sans garde au registre : " .. table.concat(m, ", "))
  -- E. registre amputé
  local cut = {}
  for _, e in ipairs(G.LIST) do if e.fichier ~= "shared/team/ilots_croissance.lua" then cut[#cut + 1] = e end end
  local m2 = missing(cut)
  check(#m2 == 1 and m2[1] == "shared/team/ilots_croissance.lua", "E : registre amputé : le fichier retire est vu (" .. table.concat(m2, ",") .. ")")
end

-- D. mutants : { id de la garde, alias du module, chemin du source, texte, remplacement }
local function load_mut(path, from, to)
  local src = slurp(path)
  if not src then return nil, "source illisible" end
  local i, j = src:find(from, 1, true)
  if not i then return nil, "texte introuvable : " .. from end
  local fn, err = load(src:sub(1, i - 1) .. to .. src:sub(j + 1), "@" .. path)
  if not fn then return nil, err end
  return fn()
end
local MUT = {
  { "Pf.input", "Pf", "shared/ai3/plafonds.lua", 'if v == nil then return nil, "entree absente : " .. name end', "if v == nil then return 0 end" },
  { "Pf.open_room", "Pf", "shared/ai3/plafonds.lua", 'if type(open) ~= "table" then return 0, "ordres ouverts : entree absente" end', 'if type(open) ~= "table" then open = {} end' },
  { "Pf.fits", "Pf", "shared/ai3/plafonds.lua", 'if type(s) ~= "table" then return false, "plafond " .. who .. " : aucun releve" end', 'if type(s) ~= "table" then return true end' },
  { "Pe.site_room", "Pe", "shared/ai3/portes_extension.lua", 'if b == nil or o == nil then return 0, 0,', 'if b == nil or o == nil then b, o = b or 0, o or 0 end if false then return 0, 0,' },
  { "Pe.measure", "Pe", "shared/ai3/portes_extension.lua", 'if not w or not idle or not free then return nil, nil, "mesure absente" end', 'if not w or not idle or not free then return false, true, "x" end' },
  { "Pl.stable", "Pl", "shared/ai3/palier.lua", 'return false, "entree absente (garde fermee)"', 'return true' },
  { "Lm.allows", "Lm", "shared/team/lot_minerai.lua", 'return false, "role du lot absent (garde fermee)"', "return true" },
  { "Cf.counts", "Cf", "shared/ai3/confirmation.lua", 'return false, "unite absente du carnet de confirmation"', "return false" },
  { "S.admit", "S", "shared/team/sante_centrale.lua", 'if c.plant_done then return hold("courant : centrale finie, entree absente : capacity") end', "if c.plant_done then return true, nil end" },
  { "D.gate", "D", "shared/ai3/danger.lua", 'return "wait", "danger non lu"', 'return "go", nil' },
  { "Ic.gate", "Ic", "shared/team/ilots_croissance.lua", 'if type(v) ~= "number" or v ~= v then return false, "mesure absente : " .. k end', "if type(v) ~= \"number\" or v ~= v then v = 0 end" },
  { "Ic.gate", "Ic", "shared/team/ilots_croissance.lua", 'if type(info[k]) ~= "boolean" then return false, "mesure absente : " .. k end', "if type(info[k]) ~= \"boolean\" then info[k] = false end" },
  { "Me.update", "Me", "shared/team/menace_equipe.lua", 'return st.crise, nil, "tourelles non recensees : menace gardee"', "return st.crise, nil, nil" },
  { "Ca.absent_input", "Ca", "shared/ai3/capitalisation.lua", 'if type(input[k]) ~= "table" then return k end', 'if type(input[k]) ~= "table" then input[k] = {} end' },
  { "H.update", "H", "shared/ai3/hysteresis.lua", 'if not num(valeur) then return st, "absent" end', "if not num(valeur) then valeur = 0 end" },
}
local by_id = {}
for _, e in ipairs(G.LIST) do by_id[e.id] = e end
for _, m in ipairs(MUT) do
  local e = by_id[m[1]]
  local mod, err = load_mut(m[3], m[4], m[5])
  if not check(mod ~= nil and e ~= nil, "D : mutant " .. m[1] .. " : " .. tostring(err)) then goto continue end
  local r = G.verdict(e, { [m[2]] = mod })
  check(r ~= "ok", "D : le mutant de " .. m[1] .. " n'est PAS vu (verdict ok)")
  ::continue::
end

print(string.format("[GARDES-REGISTRE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
print(G.line())
os.exit(failures == 0 and 0 or 1)
