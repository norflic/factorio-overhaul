--[[
  s42 bus-continu : (a) le quai de réinjection (s41) et la chaîne de poteaux du raccord (Mt.place_libre) ne se disputent plus aucune tuile ; la section se pose sans le quai si demandé ;
  (b) contrôle de continuité d'une ligne du tronc (shared/team/bus_continu.lua) : pièce absente rouverte, pièce mal orientée tournée, sortie de répartiteur non suivie dite, bornes.
  Usage : lua5.2 tests/s42_bus-continu_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local ok_n, ko_n = 0, 0
local function check(cond, what)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1; print("ECHEC : " .. tostring(what)) end
end
local Mt = require("shared.team.mall_tronc")
local Bc = require("shared.team.bus_continu")
local NAMES = { tapis = "belt", bras = "arm", coffre = "chest", poteau = "pole", repartiteur = "split", souterrain = "ug" }
local GENRES = { tapis = "belt", repartiteur = "split", souterrain = "ug" }
local ROLES = { ["mall-tronc"] = true, ["mall-prise"] = true, ["mall-amenee"] = true }
local floor = math.floor

---------------------------------------------------------------------------------------------------
-- (a) quai de réinjection et chaîne de poteaux
---------------------------------------------------------------------------------------------------
do
  local lines = { Mt.ligne(1, "fer"), Mt.ligne(2, "cuivre"), Mt.ligne(3, "acier") }
  local s1 = Mt.section(lines, { j = 1, bus = { a = 1, b = 2 } }, NAMES)
  for _, ln in ipairs(lines) do ln.y_to = s1.y_to[ln.k] end
  local n1 = 0
  for _, e in ipairs(s1.ents) do if e.reinj then n1 = n1 + 1 end end
  check(n1 == 0, "(a) rangee 1 : aucune piece de reinjection")
  for j = 2, 4 do
    for a = 1, 3 do
      local row = { j = j, bus = { a = a, b = (a < 3) and (a + 1) or nil } }
      local sec = Mt.section(lines, row, NAMES)
      local n, ouvert = 0, 0
      for _, e in ipairs(sec.ents) do
        if e.reinj then
          n = n + 1
          if Mt.place_libre(floor(e.x), floor(e.y)) then ouvert = ouvert + 1 end
        end
      end
      check(n > 0, string.format("(a) rangee %d, prise %d : le quai de reinjection est pose", j, a))
      check(ouvert == 0, string.format("(a) rangee %d, prise %d : %d tuile(s) du quai ouverte(s) a la chaine de poteaux", j, a, ouvert))
      -- sans le quai : mêmes tapis, mêmes routes, aucun quai de plus que les têtes
      local sans = Mt.section(lines, row, NAMES, { sans_reinjection = true })
      local m, conv, conv_sans = 0, 0, 0
      for _, e in ipairs(sans.ents) do
        if e.reinj then m = m + 1 end
        if ROLES[e.role] then conv_sans = conv_sans + 1 end
      end
      for _, e in ipairs(sec.ents) do if ROLES[e.role] then conv = conv + 1 end end
      check(m == 0 and #sans.quais == 0, "(a) sans_reinjection : aucune piece ni quai de reinjection")
      check(conv == conv_sans and #sans.routes == #sec.routes, "(a) sans_reinjection : les tapis et les routes sont les memes")
      check(#sec.ents - #sans.ents == n, "(a) sans_reinjection : seules les pieces du quai sont retirees")
    end
  end
  -- le couloir de la chaîne existe toujours : trois tuiles au nord de la tuile de passage, hors colonnes des lignes
  check(Mt.place_libre(-7, 13) and Mt.place_libre(-10, 13) and Mt.place_libre(-13, 12) and Mt.place_libre(-16, 11), "(a) couloir de la chaine ouvert au nord de la tuile de passage")
  check(not Mt.place_libre(-7, 14) and not Mt.place_libre(-9, 14) and not Mt.place_libre(-10, 14) and not Mt.place_libre(-16, 14) and not Mt.place_libre(-9, 13) and not Mt.place_libre(-15, 28),
    "(a) tuiles du quai (bras, coffre, relais, poteau) fermees a la chaine")
  check(not Mt.place_libre(-8, 12) and not Mt.place_libre(-7, 6) and not Mt.place_libre(-7, 10) and not Mt.place_libre(-3, 12), "(a) lignes, prises et tete des rangees a quais : toujours fermees")
end

---------------------------------------------------------------------------------------------------
-- (b) continuité
---------------------------------------------------------------------------------------------------
local function monde_de(sections)
  local pieces, world = {}, {}
  for _, sec in ipairs(sections) do
    for _, e in ipairs(sec.ents) do
      if ROLES[e.role] then
        local p = { x = e.x, y = e.y, dir = e.dir, kind = e.name, ug = e.type, built = true, item = e.name, role = e.role }
        pieces[#pieces + 1] = p
        local w = { kind = e.name, dir = e.dir, ug = e.type }
        if e.name == "split" then
          world[(e.x - 0.5) .. ":" .. e.y] = w
          world[(e.x + 0.5) .. ":" .. e.y] = w
        end
        world[e.x .. ":" .. e.y] = w
      end
    end
  end
  return pieces, world, function(x, y) return world[x .. ":" .. y] end
end
local function tronc()
  local lines = { Mt.ligne(1, "fer"), Mt.ligne(2, "cuivre") }
  local s1 = Mt.section(lines, { j = 1, bus = { a = 1, b = 2 } }, NAMES)
  for _, ln in ipairs(lines) do ln.y_to = s1.y_to[ln.k] end
  local s2 = Mt.section(lines, { j = 2, bus = { a = 1, b = 2 } }, NAMES)
  return { s1, s2 }
end
local function premier(res, cause)
  for _, d in ipairs(res.defauts) do if d.cause == cause then return d end end
end

do -- tronc intact : continu, toutes les pièces conformes, de la tête à la dernière section
  local pieces, _, lire = monde_de(tronc())
  local res = Bc.controle(pieces, lire, GENRES)
  check(#pieces > 60, "(b) le tronc de deux rangees porte ses pieces (" .. #pieces .. ")")
  check(Bc.continue(res) and res.ok == res.n and res.n == #pieces, "(b) tronc intact : continu (" .. #res.defauts .. " defaut(s))")
end
do -- deux tapis de tête disparus (le cas d'emerald, 209,5 min) : absents, à rouvrir, dans l'ordre du flux
  local pieces, world, lire = monde_de(tronc())
  world[pieces[1].x .. ":" .. pieces[1].y] = nil
  world[pieces[2].x .. ":" .. pieces[2].y] = nil
  local res = Bc.controle(pieces, lire, GENRES)
  check(not Bc.continue(res) and res.absent == 2 and res.ok == res.n - 2, "(b) deux tapis de tete absents : 2 defauts")
  check(res.defauts[1].i == 1 and res.defauts[1].action == "rouvrir" and res.defauts[2].i == 2, "(b) premier defaut = premiere tuile de la ligne, a rouvrir")
  -- bornes : cédée, retirée à la main, sans objet, déjà rouverte MAX fois
  pieces[1].dropped = true
  pieces[2].bc_n = Bc.MAX_ROUVRE
  res = Bc.controle(pieces, lire, GENRES)
  check(res.defauts[1].action == "laisser" and res.defauts[2].action == "laisser", "(b) piece cedee ou deja rouverte " .. Bc.MAX_ROUVRE .. " fois : laissee")
  pieces[1].dropped, pieces[1].hand_gave, pieces[2].bc_n, pieces[2].item = nil, true, Bc.MAX_ROUVRE - 1, nil
  res = Bc.controle(pieces, lire, GENRES)
  check(res.defauts[1].action == "laisser" and res.defauts[2].action == "laisser", "(b) piece retiree a la main ou sans objet : laissee")
  pieces[1].hand_gave, pieces[2].item = nil, "belt"
  res = Bc.controle(pieces, lire, GENRES)
  check(res.defauts[1].action == "rouvrir" and res.defauts[2].action == "rouvrir", "(b) sous le plafond : rouverte")
end
do -- pièce pas encore posée : « chantier », rien à faire
  local pieces, world, lire = monde_de(tronc())
  pieces[5].built = false
  world[pieces[5].x .. ":" .. pieces[5].y] = nil
  local res = Bc.controle(pieces, lire, GENRES)
  check(res.chantier == 1 and res.absent == 0 and res.defauts[1].action == "laisser" and not Bc.continue(res), "(b) piece en chantier : comptee, ligne coupee, aucune action")
end
do -- tapis tourné : à tourner ; souterrain tourné : laissé
  local pieces, world, lire = monde_de(tronc())
  world[pieces[4].x .. ":" .. pieces[4].y].dir = 2
  local iug
  for i, p in ipairs(pieces) do if p.kind == "ug" and not iug then iug = i end end
  check(iug ~= nil, "(b) le tronc a un souterrain (ligne 2)")
  world[pieces[iug].x .. ":" .. pieces[iug].y].ug = "autre"
  local res = Bc.controle(pieces, lire, GENRES)
  local d1, d2
  for _, d in ipairs(res.defauts) do
    if d.i == 4 then d1 = d end
    if d.i == iug then d2 = d end
  end
  check(res.tourne == 2 and d1 and d1.action == "tourner", "(b) tapis mal oriente : a tourner")
  check(d2 and d2.action == "laisser", "(b) souterrain mal oriente : laisse")
end
do -- répartiteur : ses deux sorties suivies ; la sortie de la prise retirée : dite
  local pieces, world, lire = monde_de(tronc())
  local isp
  for i, p in ipairs(pieces) do if p.kind == "split" and not isp then isp = i end end
  local sp = pieces[isp]
  local s = Bc.sorties(sp.x, sp.y, sp.dir)
  check(s[1].x == sp.x - 0.5 and s[2].x == sp.x + 0.5 and s[1].y == sp.y + 1 and s[2].y == sp.y + 1, "(b) sorties d'un repartiteur vers le sud : les deux tuiles au sud")
  check(lire(s[1].x, s[1].y) and lire(s[2].x, s[2].y), "(b) plan : les deux sorties portent une piece")
  world[s[2].x .. ":" .. s[2].y] = nil
  local res = Bc.controle(pieces, lire, GENRES)
  local d = premier(res, "sortie")
  check(d and d.x == s[2].x and d.y == s[2].y and res.sortie == 1 and res.absent == 1, "(b) sortie droite non suivie : dite, et la piece absente a rouvrir")
  -- un tapis qui fait face au répartiteur ne suit pas la sortie
  world[s[2].x .. ":" .. s[2].y] = { kind = "belt", dir = 0 }
  res = Bc.controle(pieces, lire, GENRES)
  check(res.sortie == 1 and res.tourne == 1, "(b) tapis face au repartiteur : sortie non suivie")
  local o = Bc.sorties(10, 5.5, 2)
  check(o[1].x == 11 and o[2].x == 11 and o[1].y == 5 and o[2].y == 6, "(b) sorties d'un repartiteur vers l'est")
end
do -- une autre pièce de convoyage à la place d'un tapis (répartiteur d'un autre module) : pas un défaut, jamais rouverte
  local pieces, world, lire = monde_de(tronc())
  world[pieces[6].x .. ":" .. pieces[6].y] = { kind = "split", dir = 4 }
  local res = Bc.controle(pieces, lire, GENRES)
  check(Bc.continue(res) and res.autre == 1, "(b) repartiteur a la place d'un tapis : le flux passe, aucun defaut")
  world[pieces[6].x .. ":" .. pieces[6].y] = { kind = "chest", dir = 0 }
  res = Bc.controle(pieces, lire, GENRES)
  check(res.absent == 1, "(b) un coffre a la place d'un tapis : absent")
end
do -- déterminisme
  local pieces, world, lire = monde_de(tronc())
  world[pieces[3].x .. ":" .. pieces[3].y] = nil
  world[pieces[20].x .. ":" .. pieces[20].y] = nil
  local a, b = Bc.controle(pieces, lire, GENRES), Bc.controle(pieces, lire, GENRES)
  local same = #a.defauts == #b.defauts
  for i = 1, #a.defauts do if a.defauts[i].i ~= b.defauts[i].i or a.defauts[i].cause ~= b.defauts[i].cause then same = false end end
  check(same and a.defauts[1].i < a.defauts[2].i, "(b) deux appels, meme liste, dans l'ordre du flux")
end

---------------------------------------------------------------------------------------------------
-- câblage (lecture du source) : le contrôle est lancé à l'audit de la minute, ne démonte rien, n'écrit aucun nom d'objet
---------------------------------------------------------------------------------------------------
do
  local fh = assert(io.open("script/team/mall_rangee.lua", "rb"))
  local src = fh:read("*a")
  fh:close()
  local a = src:find("function Rt.continuite", 1, true)
  local z = src:find("function Rt.minute", 1, true)
  check(a and z and a < z, "cablage : Rt.continuite defini avant Rt.minute")
  local corps = src:sub(a, z - 1)
  check(src:sub(z, z + 600):find("Rt.continuite(f, surface, tick)", 1, true) ~= nil, "cablage : Rt.minute lance le controle")
  check(not corps:find("%.destroy%(") and not corps:find("%.die%(") and not corps:find("order_deconstruction") and not corps:find("%.mine%("), "cablage : le controle ne demonte rien")
  check(not corps:find("transport%-belt") and not corps:find("\"splitter\"") and not corps:find("underground%-belt"), "cablage : aucun nom d'objet ni type en dur")
  check(corps:find("Bc.EVERY", 1, true) and corps:find("ENEMY_R", 1, true) and corps:find("bc_vu", 1, true), "cablage : echeance, garde ennemi, seconde vue")
  check(src:find("sans_reinjection = true", 1, true) ~= nil, "cablage : la section se pose sans le quai si ses tuiles sont prises")
end

print(string.format("s42 bus-continu : %d OK, %d ECHEC", ok_n, ko_n))
if ko_n > 0 then os.exit(1) end
