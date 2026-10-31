-- Deux modules differents sous le meme nom local dans un fichier : le second masque le premier, et le plantage n'arrive
-- qu'en partie (0.6.28, script/team/build.lua, Cv : convoyeurs masque par champ_vapeur, lot ENERGIE contre RANGEES-DEBIT).
local ok, bad = 0, 0
local p = assert(io.popen('git ls-files "script/*.lua" "shared/*.lua" "prototypes/*.lua"'))
for path in p:lines() do
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
p:close()
print(string.format("[MASQUE] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and ok > 0 and 0 or 1)
