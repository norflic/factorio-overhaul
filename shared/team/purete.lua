--[[
  PURETE (lot PURETE-TAPIS, retour du DC du 8/11 vers 18 h 30, en jouant la 0.6.71). Règle PURE : aucune API du jeu, aucun nom d'objet ;
  lue hors jeu (tests/purete_test.lua) et en jeu (script/team/purete.lua).

  Le DC : « L'algorithme de routage/piquage relie des outputs de machines d'assemblage directement sur ou à travers des lignes d'inputs
  destinées à d'autres ressources. Résultat : des ressources non désirées (ex: des convoyeurs) s'injectent sur les lignes d'input (ex:
  destinées aux circuits verts), ce qui bloque totalement les machines d'assemblage. [...] Une ligne d'output ne doit jamais fusionner avec
  une ligne d'input qui attend un objet différent. Le pathfinding doit vérifier la ressource transportée par le convoyeur cible avant de
  s'y connecter, et utiliser des répartiteurs avec filtres, des sauts par souterrains, ou des voies parallèles pour éviter tout mélange. »

  Avant le lot : chaque poseur de tapis (liaison, bus, rapatriement, piquage) interdisait « la tuile devant un tapis planifié ou bâti d'un
  projet de l'équipe » ; le tracé des lignes de foreuses (build.lua, plan_drills) n'interdisait rien ; aucun poseur ne regardait les tapis du
  monde hors plan (usine du joueur, autres forces), ni les répartiteurs, ni l'objet porté ; une queue de tapis d'un gabarit (le bout du tapis
  d'entrée d'une rangée sort d'une tuile de l'emprise) n'était pas réservée.

  VOCABULAIRE. Un « tapis du monde » est un enregistrement { x, y, dir, kind, item, seen } :
    - kind : "belt" (tapis), "splitter" (une tuile du répartiteur, chaque tuile a le sien), "ug_in" (entrée de souterrain : ne verse rien
      devant elle), "ug_out" (sortie), "ug" (souterrain de sens inconnu : traité comme les deux) ;
    - item : objet DÉCLARÉ de sa ligne au plan (liaison, rapatriement : l'objet de la ligne), nil si le tapis n'est pas au plan ;
    - seen : liste d'objets VUS sur ce tapis (facultatif).
  La table `world` est une fonction lookup(x, y) -> enregistrement ou nil, ou une table indexée par Pu.tkey(x, y).

  RÈGLE.
    ÉTRANGER (Pu.foreign) : un tapis est étranger à notre objet si ses objets déclarés et vus sont vides (INCONNU compte comme étranger)
    ou si l'un d'eux diffère du nôtre. Seul un tapis déclaré (ou vu) du MÊME objet n'est pas étranger.
    Un tracé (liste de tuiles { x, y, dir, ug }, dans l'ordre du flux) est REFUSÉ, avec sa cause, si :
      (a) « pointe_vers_etranger » : une tuile qui verse devant elle (tapis, sortie de souterrain) pointe vers un tapis étranger, bout à bout
          ou par le côté (la dernière tuile pointe vers sa cible déclarée : bras du quai, tampon ; ces tuiles sont `targets`) ;
      (b) « etranger_pointe_vers » : un tapis étranger qui verse devant lui (tapis, répartiteur, sortie de souterrain) pointe vers une tuile
          du tracé ;
      (c) « croisement_sans_souterrain » : une tuile du tracé est posée sur un tapis du monde étranger (la ligne étrangère est croisée sans
          passer dessous) ; « occupe » si le tapis est du même objet ;
      (d) « souterrain_meme_axe » : une paire souterraine du tracé passe au-dessus d'une pièce souterraine étrangère de même axe (le moteur
          apparierait les mauvaises pièces) ;
      (e) « chaine_rompue » : une tuile ne mène pas à la suivante (la preuve géométrique de Tv.verify le dit déjà ; ici pour le garde seul).
    Pu.forbidden(...) : l'ensemble des tuiles que le tracé ne doit pas utiliser parce qu'un tapis étranger y verse (b), pour le coût infini
    de l'A*. Pu.tail_refusals(...) : la même règle pour les queues de tapis d'un GABARIT (sa tuile devant lui, hors emprise).

  Déterminisme : listes triées, aucun `pairs` dans une décision, aucune trigonométrie, aucun temps mesuré.
]]

local Pu = {}

Pu.DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
local DV = Pu.DV

--- Même clé de tuile que Pl.tkey (shared/team/plan.lua) : les ensembles se mêlent sans conversion.
function Pu.tkey(x, y) return (x + 1048576) * 2097152 + (y + 1048576) end
local tkey = Pu.tkey

Pu.CAUSES = { "pointe_vers_etranger", "etranger_pointe_vers", "croisement_sans_souterrain", "occupe", "souterrain_meme_axe", "chaine_rompue" }

local function lookup_of(world)
  if type(world) == "function" then return world end
  return function(x, y) return world and world[tkey(x, y)] or nil end
end

--- Le tapis verse-t-il devant lui ? (l'entrée d'un souterrain ne verse rien sur la tuile qui la suit ; un souterrain de sens inconnu, si)
function Pu.outputs(rec)
  return rec ~= nil and rec.kind ~= "ug_in"
end

--- Objets déclarés et vus d'un enregistrement, triés, sans doublon.
function Pu.items_of(rec)
  local set, out = {}, {}
  if rec then
    if type(rec.item) == "string" then set[rec.item] = true
    elseif type(rec.item) == "table" then -- ligne à deux objets (un par voie) : liste d'objets
      for _, it in ipairs(rec.item) do if type(it) == "string" then set[it] = true end end
    end
    for _, it in ipairs(rec.seen or {}) do
      if type(it) == "string" then set[it] = true end
    end
  end
  for it in next, set do out[#out + 1] = it end
  table.sort(out)
  return out
end

--- Ensemble d'objets de NOTRE ligne : `item` est un objet (texte) ou une liste d'objets (tapis à deux objets, un par voie) ; nil si inconnu.
local function mine_set(item)
  if type(item) == "string" then return { [item] = true } end
  if type(item) == "table" then
    local set, n = {}, 0
    for _, it in ipairs(item) do if type(it) == "string" then set[it] = true; n = n + 1 end end
    if n > 0 then return set end
  end
  return nil
end

--- Le tapis est-il étranger à `item` ? (inconnu : oui ; un tapis dont TOUS les objets sont parmi les nôtres n'est pas étranger ; la pureté se juge par
--- TAPIS entier, pas par voie : un tapis à deux objets est étranger à une ligne qui n'en porte qu'un)
function Pu.foreign(rec, item)
  if rec == nil then return false end
  local mine = mine_set(item)
  if not mine then return true end
  local items = Pu.items_of(rec)
  if #items == 0 then return true end
  for _, it in ipairs(items) do
    if not mine[it] then return true end
  end
  return false
end

--- Texte de notre objet (journal) : « a » ou « a+b ».
function Pu.item_label(item)
  local set = mine_set(item)
  if not set then return "?" end
  local out = {}
  for it in next, set do out[#out + 1] = it end
  table.sort(out)
  return table.concat(out, "+")
end

--- Texte de l'objet d'un enregistrement (journal) : « a » ou « a+b », « ? » si inconnu.
function Pu.label(rec)
  local items = Pu.items_of(rec)
  if #items == 0 then return "?" end
  return table.concat(items, "+")
end

local function axis_of(d) return (d == 0 or d == 4) and 1 or 2 end
local function is_ug(rec) return rec ~= nil and (rec.kind == "ug_in" or rec.kind == "ug_out" or rec.kind == "ug") end

local function refusal(cause, t, w, item)
  return { cause = cause, x = t.x, y = t.y, wx = w and w.x or t.x, wy = w and w.y or t.y, mine = Pu.item_label(item), other = w and Pu.label(w) or "?" }
end

--- Contrôle d'un tracé.
---   tiles : liste { x, y, dir, ug = nil | "input" | "output" } dans l'ordre du flux ;
---   item : l'objet de notre ligne (nil : inconnu, tout tapis du monde est étranger) ;
---   world : fonction lookup(x, y) ou table (voir en-tête) ;
---   opts : targets = { [tkey] = true } (tuiles où la dernière tuile peut verser : bras du quai, tampon), own = { [tkey] = true } (tuiles de
---          notre propre projet, jamais lues comme tapis du monde), first = faux pour sauter (b) sur la première tuile.
--- Rend ok (booléen) et la liste des refus { cause, x, y, wx, wy, mine, other } (vide si ok).
function Pu.check(tiles, item, world, opts)
  opts = opts or {}
  local look = lookup_of(world)
  local own = opts.own or {}
  local targets = opts.targets or {}
  local function at(x, y)
    if own[tkey(x, y)] then return nil end
    return look(x, y)
  end
  local bad = {}
  local n = #tiles
  local mine = {}
  for _, t in ipairs(tiles) do mine[tkey(t.x, t.y)] = true end
  for i, t in ipairs(tiles) do
    local v = DV[t.dir]
    if not v then
      bad[#bad + 1] = refusal("chaine_rompue", t, nil, item)
    else
      -- (c) la tuile elle-même sur un tapis du monde
      local here = at(t.x, t.y)
      if here then
        bad[#bad + 1] = refusal(Pu.foreign(here, item) and "croisement_sans_souterrain" or "occupe", t, here, item)
      end
      -- (a) ce que cette tuile verse devant elle
      local pours = t.ug ~= "input"
      if pours then
        local fx, fy = t.x + v[1], t.y + v[2]
        local nx = tiles[i + 1]
        if nx then
          if not (nx.x == fx and nx.y == fy) then bad[#bad + 1] = refusal("chaine_rompue", t, nil, item) end
        elseif not targets[tkey(fx, fy)] then
          local w = at(fx, fy)
          if w and not mine[tkey(fx, fy)] and Pu.foreign(w, item) then
            bad[#bad + 1] = refusal("pointe_vers_etranger", t, w, item)
          end
        end
      end
      -- (b) les tapis du monde qui versent sur cette tuile
      if not (i == 1 and opts.first == false) then
        for _, d in ipairs({ 0, 2, 4, 6 }) do
          local dv = DV[d]
          local wx, wy = t.x - dv[1], t.y - dv[2] -- voisin dont le sens d vise (t.x, t.y)
          if not mine[tkey(wx, wy)] then
            local w = at(wx, wy)
            if w and w.dir == d and Pu.outputs(w) and Pu.foreign(w, item) then
              bad[#bad + 1] = refusal("etranger_pointe_vers", t, w, item)
            end
          end
        end
      end
    end
  end
  -- (d) paires souterraines : une pièce étrangère de même axe sous la paire
  for i = 1, n - 1 do
    local a, c = tiles[i], tiles[i + 1]
    if a.ug == "input" and c.ug == "output" then
      local v = DV[a.dir]
      local span = math.abs(c.x - a.x) + math.abs(c.y - a.y)
      if v and span >= 2 then
        for k = 1, span - 1 do
          local x, y = a.x + k * v[1], a.y + k * v[2]
          local w = at(x, y)
          if is_ug(w) and axis_of(w.dir or 0) == axis_of(a.dir) then
            bad[#bad + 1] = refusal("souterrain_meme_axe", { x = x, y = y }, w, item)
          end
        end
      end
    end
  end
  return #bad == 0, bad
end

--- Tuiles interdites au tracé de `item` dans une zone : celles où un tapis étranger verse (cause b). `recs` : liste d'enregistrements du monde
--- (les tapis de la zone, dans n'importe quel ordre) ; `own` : tuiles de notre propre projet (ignorées). Rend { [tkey] = true }.
function Pu.forbidden(recs, item, own)
  local out = {}
  for _, w in ipairs(recs) do
    local v = DV[w.dir]
    if v and Pu.outputs(w) and Pu.foreign(w, item) and not (own and own[tkey(w.x, w.y)]) then
      out[tkey(w.x + v[1], w.y + v[2])] = true
    end
  end
  return out
end

--- Queues d'un gabarit : tuiles devant les tapis dont la tuile suivante n'appartient pas au gabarit.
---   belts : liste { x, y, dir } des tuiles de tapis du gabarit (coordonnées entières, relatives à l'origine) ;
---   occupied : { [tkey] = true } des tuiles de toutes les pièces du gabarit ; skip : { [tkey] = true } à ne pas lire (tuiles réservées
---   exprès : tête d'alimentation et quai de sortie, déjà contrôlés par la place des ports).
--- Rend une liste triée { x, y (la tuile devant), bx, by, dir (le tapis qui verse) }.
function Pu.tails(belts, occupied, skip)
  local out = {}
  for _, b in ipairs(belts) do
    local v = DV[b.dir]
    if v then
      local fx, fy = b.x + v[1], b.y + v[2]
      local k = tkey(fx, fy)
      if not occupied[k] and not (skip and skip[k]) then
        out[#out + 1] = { x = fx, y = fy, bx = b.x, by = b.y, dir = b.dir }
      end
    end
  end
  table.sort(out, function(a, c)
    if a.y ~= c.y then return a.y < c.y end
    if a.x ~= c.x then return a.x < c.x end
    return a.bx * 1000 + a.by < c.bx * 1000 + c.by
  end)
  return out
end

--- Queues d'un gabarit posé à (ox, oy) contre le monde : un gabarit verse un mélange (ses ingrédients), donc tout tapis du monde devant
--- une queue est étranger sauf s'il est déclaré du même objet que `item` (nil : jamais). Rend les refus (cause a).
function Pu.tail_refusals(tails, ox, oy, item, world, own)
  local look = lookup_of(world)
  local bad = {}
  for _, t in ipairs(tails) do
    local x, y = ox + t.x, oy + t.y
    if not (own and own[tkey(x, y)]) then
      local w = look(x, y)
      if w and Pu.foreign(w, item) then
        bad[#bad + 1] = refusal("pointe_vers_etranger", { x = ox + t.bx, y = oy + t.by }, { x = x, y = y, item = w.item, seen = w.seen }, item)
      end
    end
  end
  return bad
end

--- Ligne de journal d'un refus : « [FO-PURETE] <module> : tracé refusé (<cause>) objet <x> contre <y> en (x, y) ».
function Pu.line(module, r, team)
  return string.format("[FO-PURETE] %s%s : tracé refusé (%s) objet %s contre %s en (%d, %d)", team and (team .. " ") or "", module, r.cause,
    tostring(r.mine), tostring(r.other), r.wx, r.wy)
end

return Pu
