--[[
  Lot CHAMP-COUVERTURE (étape 0) : REJEU hors jeu des plans de champ d'une partie, à partir des lignes [FO-CHAMP-FORME] de son journal
  (script/team/champ.lua, Champ.frame ; codec shared/team/champ_forme.lua). Pour chaque ligne : la spec est relue, Ch.plan rejoué,
  le résultat (tuiles couvertes, foreuses, bandes posées) comparé à celui écrit en jeu, puis les compteurs du plan rejoué (coupées,
  sans fonderie). Avec une autre racine de sources, le même champ est planifié par une AUTRE version de la règle (avant / après un lot).

    lua5.2 tools/champ_forme.lua <journal> [racine des sources de la règle, défaut .] [--detail]

  Sortie : une ligne par forme, « IDENTIQUE » (rejeu de la même règle) ou « ECART » ; code 1 s'il y a un écart avec la racine par
  défaut (la règle qui a écrit la ligne doit la rejouer à l'identique), 0 sinon. Lecture seule : rien n'est écrit.
]]
local journal, root, detail = nil, ".", false
for _, a in ipairs(arg) do
  if a == "--detail" then detail = true
  elseif not journal then journal = a
  else root = a end
end
assert(journal, "usage : lua5.2 tools/champ_forme.lua <journal> [racine] [--detail]")

-- le codec vient de ce dépôt (une racine plus ancienne ne l'a pas) ; la règle, de la racine demandée
local here = (arg[0]:match("^(.*)[/\\]tools[/\\][^/\\]+$")) or "."
package.path = here .. "/?.lua;" .. package.path
local Fo = require("shared.team.champ_forme")
package.path = root .. "/?.lua;" .. package.path
for k in pairs(package.loaded) do if k:match("^shared%.") and k ~= "shared.team.champ_forme" then package.loaded[k] = nil end end
local Ch = require("shared.team.champ")
local Cv = require("shared.team.champ_verif")

local n, same, diff, bad = 0, 0, 0, 0
for line in io.lines(journal) do
  local who = line:match("%[FO%-CHAMP%-FORME%] (.-) : v1 |")
  if who then
    n = n + 1
    local spec, res = Fo.decode(line)
    if not spec then
      bad = bad + 1
      print(string.format("%-60s ILLISIBLE (%s)", who, tostring(res)))
    else
      local t0 = os.clock()
      local p, why = Ch.plan(spec)
      local dt = os.clock() - t0
      if not p then
        diff = diff + 1
        print(string.format("%-60s ECART : plan refuse (%s)", who, tostring(why)))
      else
        local rep = Cv.verify(p, spec)
        local bands = 0
        for _, bd in ipairs(p.bands) do if #bd.groups > 0 then bands = bands + 1 end end
        local ok = rep.covered == res.covered and rep.tiles == res.tiles and p.stats.drills == res.drills and bands == res.bands
        if ok then same = same + 1 else diff = diff + 1 end
        print(string.format("%-60s %s : couverture %d/%d (%.1f %%, en jeu %d/%d), %d foreuses (en jeu %d), %d bandes (en jeu %d) ; axe %s, coupees %d, sans fonderie %d ; %.2f s",
          who, ok and "IDENTIQUE" or "ECART", rep.covered, rep.tiles, 100 * rep.elec, res.covered, res.tiles, p.stats.drills, res.drills, bands,
          res.bands, p.axis, p.stats.capped or 0, p.stats.no_smelter or 0, dt))
        if detail then print("    " .. Cv.line(rep)) end
      end
    end
  end
end
print(string.format("[CHAMP-FORME] REJEU : %d forme(s), %d identique(s), %d ecart(s), %d illisible(s) (regle : %s)", n, same, diff, bad, root))
if root == "." and (diff > 0 or bad > 0) then os.exit(1) end
