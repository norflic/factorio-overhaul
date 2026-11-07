--[[
  Empreintes de RÉFÉRENCE des plans de champ (lot CHAMP-COUVERTURE, coût de Ch.plan) : pour chaque cas du corpus (tests/champ_formes.lua),
  l'empreinte du plan entier, et pour 4 formes celle de chaque bande seule rejouée du cadre. Écrit tests/fixtures/champ_plans_ref.lua.
  Usage, depuis la racine du mod :
    lua5.2 tools/champ_plans_ref.lua [chemin de shared/team/champ.lua de référence] > tests/fixtures/champ_plans_ref.lua
  Sans argument : le module du dépôt. Avec un chemin (ex. un `git show <commit>:shared/team/champ.lua` recopié) : ce module-là, avec les
  autres modules du dépôt. Pur, aucune API Factorio.
]]
package.path = "./?.lua;" .. package.path
local Ch
if arg[1] then
  Ch = assert(loadfile(arg[1]))()
  package.loaded["shared.team.champ"] = Ch
else
  Ch = require("shared.team.champ")
end
local Fm = require("tests.champ_formes")
local Sr = require("tests.champ_plan_serial")
local BANDS = { ["disque r30"] = true, ["r30 + anneau de tourelles (r34)"] = true, ["r30 + lacs aux deux bouts"] = true,
  ["r30 + eau aux bouts, ouverture de 5"] = true }
local out = { "-- Empreintes de reference des plans de champ (tools/champ_plans_ref.lua" .. (arg[1] and (", module " .. arg[1]) or "") .. ")",
  "return {" }
for _, cs in ipairs(Fm.corpus()) do
  local p, why = Ch.plan(cs.spec())
  local h, n, ne = Sr.print(p, why)
  out[#out + 1] = string.format("  { name = %q, hash = %q, len = %d, ents = %d, bands = {", cs.name, h, n, ne)
  if BANDS[cs.name] and p then
    for _, bd in ipairs(p.bands) do
      local fr = {}
      for k, v in pairs(p.frame) do fr[k] = v end
      fr.only = { [bd.pr] = true }
      local sp = cs.spec()
      sp.frame = fr
      local q, qwhy = Ch.plan(sp)
      local bh, bn, be = Sr.print(q, qwhy)
      out[#out + 1] = string.format("    { pr = %d, hash = %q, len = %d, ents = %d },", bd.pr, bh, bn, be)
    end
  end
  out[#out + 1] = "  } },"
end
out[#out + 1] = "}"
print(table.concat(out, "\n"))
