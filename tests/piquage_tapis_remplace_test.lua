-- Plantage de la partie du DC en 0.7.90 (piquage.lua place_split) : le remplacement sur place (fast_replace) détruit l'entité du tapis source ;
-- toute lecture de `belt.<champ>` après `create_entity` lit une LuaEntity invalide. Test de source : aucune lecture de belt après la pose.
local src = assert(io.open("script/team/piquage.lua")):read("*a")
local function check(text)
  local body = text:match("local function place_split%(.-\nend\n")
  if not body then return false, "place_split introuvable" end
  local after = body:match("surface%.create_entity%((.*)$")
  if not after then return false, "create_entity introuvable" end
  if after:find("belt%.") then return false, "lecture de belt apres create_entity" end
  return true
end
local ok_n, fail_n = 0, 0
local function t(name, cond) if cond then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("ECHEC : " .. name) end end
local ok, why = check(src)
t("place_split ne lit plus le tapis remplace (" .. tostring(why) .. ")", ok)
-- mutant : la lecture du nom après la pose est rétablie
local mut = src:gsub("if e%.name == belt_name and", "if e.name == belt.name and", 1)
t("mutant (belt.name relu apres la pose) refuse", mut ~= src and not check(mut))
print(string.format("[PIQUAGE-TAPIS-REMPLACE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
