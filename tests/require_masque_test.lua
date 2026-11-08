-- Deux modules differents sous le meme nom local dans un fichier : le second masque le premier, et le plantage n'arrive
-- qu'en partie (0.6.28, script/team/build.lua, Cv : convoyeurs masque par champ_vapeur, lot ENERGIE contre RANGEES-DEBIT).
-- Lot TESTS-GIT (0.6.64) : la liste des fichiers vient de tests/depot.lua (git ls-files ; sans git, le disque, annoncé par une ligne
-- [ENVIRONNEMENT]). Avant : sans git, 0 fichier lu, « BILAN : 0 OK, 0 ECHEC » et code 1 sans dire pourquoi.
package.path = "./?.lua;" .. package.path
local D = require("tests.depot")
local ok, bad = 0, 0
local files, source = D.lua_files({ "script", "shared", "prototypes" })
if source == "disque" then D.env("liste des fichiers Lua (git ls-files)", #files > 0) end
for _, path in ipairs(files) do
  local seen, n = {}, 0
  for line in io.lines(path) do
    n = n + 1
    local name, mod = line:match('^local%s+([%w_]+)%s*=%s*require%(?%s*["\']([%w_./-]+)["\']')
    if name then
      if seen[name] and seen[name] ~= mod then
        bad = bad + 1
        print(string.format("[MASQUE] ECHEC %s:%d %s : %s masque par %s", path, n, name, seen[name], mod))
      end
      seen[name] = seen[name] or mod
    end
  end
  ok = ok + 1
end
if ok == 0 then
  bad = bad + 1
  print("[MASQUE] ECHEC aucun fichier Lua lu (source : " .. source .. ") : contrôle non joué")
end
print(string.format("[MASQUE] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and ok > 0 and 0 or 1)
