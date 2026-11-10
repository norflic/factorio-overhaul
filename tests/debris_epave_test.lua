-- Lot CC-DORMANT (F496) : les débris solides NEUTRES de l'épave de départ posés dans l'emprise d'une pièce sont retirés avant la pose de
-- son fantôme. Défaut mesuré (partie du DC sur la 0.6.88, graine 1732508881, fo-logs/2026-11-10_PLAYTEST-0688 ; sonde
-- fo-logs/2026-11-10_CC-DORMANT-SONDE) : un débris « simple-entity-with-owner » neutre sur la tuile d'un poteau faisait refuser son fantôme
-- « occupe » 14 fois ; la bande -33 restait bloquée de 21 à 60 min et gardait le créneau du fer ; la bande de l'avant-poste 1 payée par les
-- foreuses électriques dormantes ne partait pas (55 au coffre). Le test joue le TEXTE RÉEL de clear_floor (script/team/build.lua) sur une
-- surface simulée, puis les mêmes scènes sous mutants du texte : chaque mutant doit être refusé.
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local function plain(s, pat, init) return s:find(pat, init or 1, true) end

local SRC = read("script/team/build.lua"):gsub("\r\n", "\n")

--- Surface simulée : entités { type, force, x, y, minable, valid }.
local function surface_of(list)
  local s = { ents = list }
  local function has(t, v)
    if type(t) == "string" then return t == v end
    for _, x in ipairs(t) do if x == v then return true end end
    return false
  end
  function s.find_entities_filtered(q)
    local out = {}
    for _, d in ipairs(s.ents) do
      local a = q.area
      if d.valid and d.x >= a[1][1] and d.x <= a[2][1] and d.y >= a[1][2] and d.y <= a[2][2]
        and (q.type == nil or has(q.type, d.type)) and (q.force == nil or q.force == d.force) then out[#out + 1] = d end
    end
    return out
  end
  return s
end
local function ent(t, force, x, y, minable)
  local d = { type = t, force = force, x = x, y = y, minable = minable ~= false, valid = true }
  function d.destroy() d.valid = false end
  return d
end

--- clear_floor du texte (et Build.DEBRIS_TYPES s'il existe) ; footprint simulé : emprise 1x1 centrée sur (e.x, e.y).
local function load_clear(src)
  local a = plain(src, "local function clear_floor(surface, e)")
  if not a then return nil, "clear_floor absent" end
  local b = src:find("\nend\n", a, true)
  local head = ""
  local t = plain(src, "Build.DEBRIS_TYPES =")
  if t and t < a then head = src:sub(t, src:find("\n", t, true)) end
  local chunk = "local Build = {}\n" .. head .. src:sub(a, b + 4) .. "\nreturn clear_floor"
  local env = { ipairs = ipairs, footprint = function(e) return { { e.x - 0.5, e.y - 0.5 }, { e.x + 0.5, e.y + 0.5 } } end }
  local fn, err = load(chunk, "=clear_floor", "t", env)
  if not fn then return nil, err end
  return fn()
end

--- Les scènes : rend le nombre d'échecs.
local function scenes(src, quiet)
  local bad = 0
  local cf, err = load_clear(src)
  local function ck(c, m) if not c then bad = bad + 1 end if not quiet then check(c, m) end end
  if not cf then ck(false, "texte illisible : " .. tostring(err)) return bad end
  local pole = { x = -28.5, y = 2.5 }
  -- 1 : le cas du DC, un petit débris neutre sur la tuile du poteau
  local w = ent("simple-entity-with-owner", "neutral", -28.1, 2.3)
  local n = cf(surface_of({ w }), pole)
  ck(not w.valid and n == 1, "1 : le debris neutre de l'epave sur la tuile du poteau est retire")
  -- 2 : une épave moyenne (conteneur neutre minable)
  local c = ent("container", "neutral", -28.4, 2.6)
  cf(surface_of({ c }), pole)
  ck(not c.valid, "2 : l'epave conteneur neutre est retiree")
  -- 3 : le vaisseau principal (force de l'équipe) n'est pas touché
  local ship = ent("container", "player", -28.5, 2.5)
  cf(surface_of({ ship }), pole)
  ck(ship.valid, "3 : une entite de l'equipe n'est jamais retiree")
  -- 4 : un rocher neutre reste au défrichage (obstacle)
  local rock = ent("simple-entity", "neutral", -28.5, 2.5)
  cf(surface_of({ rock }), pole)
  ck(rock.valid, "4 : un rocher reste au defrichage")
  -- 5 : un arbre reste au défrichage
  local tree = ent("tree", "neutral", -28.5, 2.5)
  cf(surface_of({ tree }), pole)
  ck(tree.valid, "5 : un arbre reste au defrichage")
  -- 6 : un débris neutre non minable n'est pas détruit
  local fixed = ent("simple-entity-with-owner", "neutral", -28.5, 2.5, false)
  cf(surface_of({ fixed }), pole)
  ck(fixed.valid, "6 : un debris non minable reste")
  -- 7 : un débris solide hors de l'emprise (dans la marge des restes) reste
  local near = ent("simple-entity-with-owner", "neutral", -27.75, 2.5)
  cf(surface_of({ near }), pole)
  ck(near.valid, "7 : un debris hors de l'emprise reste")
  -- 8 : les restes au sol dans la marge partent toujours (comportement d'avant)
  local item = ent("item-entity", "neutral", -27.75, 2.5)
  local n8 = cf(surface_of({ item }), pole)
  ck(not item.valid and n8 == 1, "8 : un objet au sol dans la marge part toujours")
  -- 9 : une pièce d'une équipe (même type) n'est jamais retirée
  local own = ent("simple-entity-with-owner", "emerald", -28.5, 2.5)
  cf(surface_of({ own }), pole)
  ck(own.valid, "9 : une piece d'une equipe n'est jamais retiree")
  return bad
end

print("[DEBRIS-EPAVE] texte reel de script/team/build.lua")
scenes(SRC)

local CUT = "  for _, d in ipairs(surface.find_entities_filtered({ area = a, type = Build.DEBRIS_TYPES, force = \"neutral\" })) do\n"
  .. "    if d.valid and d.minable then d.destroy() n = n + 1 end\n  end\n"
local function mutate(from, to)
  local i = plain(SRC, from)
  if not i then return nil end
  return SRC:sub(1, i - 1) .. to .. SRC:sub(i + #from)
end
local MUTANTS = {
  { "coupe retiree (0.6.89)", CUT, "" },
  { "force ignoree", "type = Build.DEBRIS_TYPES, force = \"neutral\" })", "type = Build.DEBRIS_TYPES })" },
  { "minable ignore", "if d.valid and d.minable then", "if d.valid then" },
  { "marge des restes appliquee aux debris", "area = a, type = Build.DEBRIS_TYPES",
    "area = { { a[1][1] - 0.6, a[1][2] - 0.6 }, { a[2][1] + 0.6, a[2][2] + 0.6 } }, type = Build.DEBRIS_TYPES" },
  { "rochers ajoutes", "{ \"simple-entity-with-owner\", \"container\" }", "{ \"simple-entity-with-owner\", \"container\", \"simple-entity\" }" },
  { "conteneurs oublies", "{ \"simple-entity-with-owner\", \"container\" }", "{ \"simple-entity-with-owner\" }" },
  { "arbres ajoutes", "{ \"simple-entity-with-owner\", \"container\" }", "{ \"simple-entity-with-owner\", \"container\", \"tree\" }" },
}
for _, m in ipairs(MUTANTS) do
  local src = mutate(m[2], m[3])
  check(src ~= nil, "mutant '" .. m[1] .. "' applicable au texte")
  if src then check(scenes(src, true) > 0, "mutant '" .. m[1] .. "' refuse") end
end
print(string.format("[DEBRIS-EPAVE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
