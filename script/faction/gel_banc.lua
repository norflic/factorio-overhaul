--[[
  Lot X10-GEL : interface des BANCS (« fo-gel »), pour le micro-banc `x10-gel-arene` du mod de test (fo-logs/2026-11-07_X10/
  L1_CRITERES.md §4, C1 à C7). Un GROUPE DE BANC est un jeu d'îlots d'une force quelconque, soumis à LA même règle de zone et de
  réveil que les factions (script/faction/gel_usines_jeu.lua, guet), mais dont les causes (attaque, perte, menace) et les joueurs
  sont posés par le banc : la comparaison avec une jumelle active ne dépend pas des décisions d'une faction.
  Aucune partie ordinaire n'a de groupe de banc (u.bancs vide) : rien ne change pour le DC. Toute l'interface est de BANC : aucun
  appel dans le mod (grep de « "fo-gel" » hors de ce fichier : vide) ; « reglage » n'écrit le réglage que si un banc l'appelle.

  remote.call("fo-gel", ...) :
    banc(nom, force)                 crée (ou remet à zéro) le groupe ;
    adopte(nom, entité)              relève l'îlot de cette entité (foreuse d'avant-poste ou four rempli à la main) dans le groupe ;
                                     rend { id = n } ou { why = raison } ;
    candidats(nom, foreuses, fours)  candidats relevés de nouveau toutes les Gu.RESCAN ticks, comme ceux d'une faction (C20' b) ;
    cause(nom, champ, valeur)        attack_t, lost_t, threatened_until, base_alert, army_out ;
    joueurs(nom, liste)              positions { {x, y}, ... } qui remplacent les joueurs connectés pour ce groupe (nil : les vrais) ;
    statut(entité)                   Gel.status (statut comptable d'une machine figée) ;
  Garnisons (Q7, script/faction/gel_garnisons.lua ; mêmes causes et joueurs que le groupe d'usines du même nom) :
    garnison(nom, force, qg, surface) crée (ou remet à zéro) une garnison de banc, QG en qg = {x, y} ;
    soldat(nom, entité, rôle, x, y)  ajoute un soldat (rôle nil : garnison du QG ; « guard » ou « patrol » au point (x, y)) ;
    tourelle(nom, entité)            ajoute une tourelle de l'équipe (amas, tourelle qui tire) ;
    g_cause(nom, champ, valeur)      comme cause, pour la garnison (armee = { alert = true }, alerts = { ... } compris) ;
    g_joueurs(nom, liste)            comme joueurs, pour la garnison ;
    g_commande(nom, entité)          crochet Gel.before_command (comme une commande du mod) ; rend entité.active juste après ;
    g_groupe(nom, entité, x, y)      crochet, puis groupe neuf envoyé en (x, y) (comme military.lua) ; rend le numéro du groupe ;
    g_compte(vrai)                   compte les appels de on_entity_damaged (C17) ;
    g_etat(nom)                      { soldats, figes, actifs_figes (relu au moteur), reveils, gels, causes, degats, degats_soldats,
                                       requetes, postes } ;
    etat(nom)                        { ilots, figes, machines_figees, pertes } ;
    constantes()                     { STEP, CALM, GUET, WAKE_R, FREEZE_R, WRITES } ;
    reglage(vrai|faux)               écrit le réglage de carte fo-war-gel (C20 : témoin éteint) ; rend Gel.on() ;
    bilan()                          { ilots, figes, machines_figees, soldats_figes, n_frozen }, toutes factions (C20) ;
    zones(fid)                       zones de menace du guet des garnisons de la faction (Ga.zones, lecture seule ; C19) ;
    recensement()                    { factions = { refus, candidats, avant-postes, soldats par rôle, postes, amas }, ilots = { sorte,
                                       foreuses, distance au QG, minerai, gisement, charbon } } : lecture (C20' b, scène
                                       x10-gel-echelle bâtie sur la composition de la partie du DC).
]]

local Gel = require("script.faction.gel")
require("script.faction.gel_etat") -- état du lot déclaré (namespace « gel ») et branché sur Gel.state
local Gu = require("script.faction.gel_usines")
local G = require("shared.faction.gel")
local Ga = require("script.faction.gel_garnisons")
local State = require("script.faction.state")
local C = require("script.ai3.comportement") -- rôles des soldats (recensement), comme gel_garnisons.lua

local function garrison(name)
  local a = Ga.A()
  return a and a.bancs[name] or nil
end

local function Gc_sorted(t)
  local ks = {}
  for k in next, t do ks[#ks + 1] = k end
  table.sort(ks, function(x, y) return tostring(x) < tostring(y) end)
  return ks
end

local function dist(x, y, hq)
  if not hq then return -1 end
  local dx, dy = x - hq.x, y - hq.y
  return math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
end

--- Combustible d'un brûleur, toutes sortes (l'inventaire du brûleur ne tient que du combustible ; aucun nom d'objet écrit ici).
local function fuel_of(e)
  local inv = e.valid and e.burner and e.burner.inventory
  return inv and inv.get_item_count() or 0
end

--- Nom d'un statut du moteur (defines.entity_status), table inverse faite une fois (clés triées).
local STATUS_NAME = {}
local function status_name(v)
  if v == nil then return "aucun" end
  if not next(STATUS_NAME) then
    for _, k in ipairs(State.sorted_keys(defines.entity_status)) do STATUS_NAME[defines.entity_status[k]] = k end
  end
  return STATUS_NAME[v] or tostring(v)
end

--- Une ligne par îlot relevé : faction, sorte (« coffre » : foreuses -> coffre, « four » : foreuses -> four, « qg » : four du QG
--- rempli à la main), foreuses, machines, distance au QG, minerai et gisement restant, charbon des brûleurs (plus petit, plus grand),
--- statuts des machines (Gel.status : celui d'une machine figée est son statut comptable, pas « disabled_by_script »).
local function census_ilot(I, hq)
  local nd, cmin, cmax = 0, math.huge, 0
  local st = {}
  for _, e in ipairs(I.machines) do
    if e.valid then
      if e.type == "mining-drill" then nd = nd + 1 end
      local c = fuel_of(e)
      cmin, cmax = math.min(cmin, c), math.max(cmax, c)
      local n = status_name(Gel.status(e))
      st[n] = (st[n] or 0) + 1
    end
  end
  local etats = {}
  for _, k in ipairs(Gc_sorted(st)) do etats[#etats + 1] = k .. "=" .. st[k] end
  local ore, amount = nil, 0
  for _, k in ipairs(Gc_sorted(I.res or {})) do
    local r = I.res[k]
    if r.valid then ore = ore or r.name; amount = amount + (r.amount or 0) end
  end
  if I.kind == "four" then
    local s = I.machines[1]
    local src = s and s.valid and s.get_inventory(defines.inventory.furnace_source)
    ore = src and Gc_sorted(src.get_contents())[1] or ore
  end
  return { fid = tostring(I.fid), sorte = I.kind == "four" and "qg" or (I.chest and "coffre" or "four"), foreuses = nd,
    machines = #I.machines, dist = dist(I.pos.x, I.pos.y, hq), minerai = tostring(ore), gisement = amount,
    charbon_min = cmin == math.huge and 0 or cmin, charbon_max = cmax, fige = I.st.frozen == true, etats = table.concat(etats, " ") }
end

--- Une faction : refus du dernier relevé, candidats, avant-postes (foreuses, distance au QG), fours du QG connus, soldats par rôle,
--- postes hors du cercle du QG, amas de tourelles (tourelles par amas).
local function census_faction(fid, f, u)
  local hq = f.hq_pos
  local F = { fid = tostring(fid), key = tostring(f.key), hq = { x = hq.x, y = hq.y }, soldats = 0, roles = {}, refus = {}, candidats = 0,
    postes = 0, amas = {}, tourelles = 0, avant_postes = {}, fours_qg = #(f.smelters or {}), noms = {}, noms_tourelles = {}, dist_soldats = {},
    dist_postes = {} }
  local st = u and u.stats[fid]
  if st then for _, k in ipairs(Gc_sorted(st.refus or {})) do F.refus[k] = st.refus[k] end end
  local sc = u and u.scan[fid]
  F.candidats = sc and #sc.q or 0
  F.lus = sc and math.min(sc.pos - 1, #sc.q) or 0 -- candidats déjà lus du relevé en cours (= candidats : relevé fini)
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local n, sx, sy = 0, 0, 0
    for _, d in ipairs(f.outposts[oid].drill_list or {}) do
      if d.valid then n, sx, sy = n + 1, sx + d.position.x, sy + d.position.y end
    end
    if n > 0 then F.avant_postes[#F.avant_postes + 1] = { foreuses = n, dist = dist(sx / n, sy / n, hq) } end
  end
  -- C.team crée l'état de l'équipe s'il manque : seulement pour une faction à soldats, que le guet des garnisons appelle déjà (même
  -- appel, gel_garnisons.lua) ; le recensement n'écrit rien d'autre.
  local t = (C.enabled() and (f.soldiers_count or 0) > 0) and C.team(f) or nil
  local per = t and t.sd and t.sd.per or {}
  for _, un in ipairs(State.sorted_keys(f.soldiers or {})) do
    local s = f.soldiers[un]
    if s and s.entity and s.entity.valid then
      F.soldats = F.soldats + 1
      local r = per[un] and per[un].role or "qg"
      F.roles[r] = (F.roles[r] or 0) + 1
      local e = s.entity
      F.noms[e.name] = (F.noms[e.name] or 0) + 1
      F.dist_soldats[#F.dist_soldats + 1] = dist(e.position.x, e.position.y, hq)
    end
  end
  local valid = {}
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local tu = f.turrets[id]
    if tu and tu.valid then
      valid[#valid + 1] = tu
      F.noms_tourelles[tu.name] = (F.noms_tourelles[tu.name] or 0) + 1
    end
  end
  F.tourelles = #valid
  local z = Ga.zones(fid)
  for _, zz in ipairs(z and z.zones or {}) do
    if zz.kind == "poste" then
      F.postes = F.postes + 1
      F.dist_postes[#F.dist_postes + 1] = dist(zz.position.x, zz.position.y, hq)
    elseif zz.kind == "amas" then
      local a, n = zz.area, 0
      for _, tu in ipairs(valid) do
        local p = tu.position
        if p.x >= a[1][1] and p.x <= a[2][1] and p.y >= a[1][2] and p.y <= a[2][2] then n = n + 1 end
      end
      F.amas[#F.amas + 1] = { tourelles = n, dist = dist((a[1][1] + a[2][1]) / 2, (a[1][2] + a[2][2]) / 2, hq) }
    end
  end
  return F
end

--- Recensement de la partie pour bâtir la scène x10-gel-echelle (C20' b) : lecture du monde et de l'état (seule écriture possible :
--- l'état d'équipe de C.team, voir census_faction).
local function census()
  local war = State.war()
  local u = Gu.U()
  local out = { factions = {}, ilots = {} }
  local hqs = {}
  for _, fid in ipairs(State.alive()) do
    local f = war and war.factions and war.factions[fid]
    if f and not f.is_player and f.hq_pos then
      hqs[tostring(fid)] = f.hq_pos
      out.factions[#out.factions + 1] = census_faction(fid, f, u)
    end
  end
  if u then
    for _, id in ipairs(Gc_sorted(u.ilots)) do
      local I = u.ilots[id]
      out.ilots[#out.ilots + 1] = census_ilot(I, hqs[tostring(I.fid)])
    end
  end
  return out
end

local function group(name)
  local u = Gu.U()
  if not u then return nil end -- stockage pas encore créé
  u.bancs = u.bancs or {}
  return u.bancs[name]
end

remote.add_interface("fo-gel", {
  banc = function(name, force)
    local u = Gu.U()
    if not u then return false end
    u.bancs = u.bancs or {}
    u.bancs[name] = { force = force, army_out = false }
    return true
  end,
  adopte = function(name, entity)
    local b = group(name)
    if not (b and entity and entity.valid) then return { why = "groupe ou entite" } end
    local f = { force = b.force, key = "banc:" .. name }
    local I, why
    if entity.type == "mining-drill" then I, why = Gu.discover_pair(f, entity.surface, entity)
    else I, why = Gu.discover_four(f, entity.surface, entity) end
    if not I then return { why = why } end
    local u = Gu.U()
    for _, m in ipairs(I.machines) do if u.by_unit[m.unit_number] then return { why = "deja pris" } end end
    Gu.register("banc:" .. name, I, game.tick)
    return { id = I.id }
  end,
  -- C20' (b), scène x10-gel-echelle : candidats du groupe (foreuses et fours du QG, relevés et REFUSÉS mêlés), relevés de nouveau
  -- comme ceux d'une faction (scan_tick, gel_usines_jeu.lua) : premier relevé Gu.RESCAN ticks après cet appel (les îlots adoptés sont
  -- alors figés et gardés), puis toutes les Gu.RESCAN ticks.
  candidats = function(name, drills, fours)
    local b = group(name)
    if not b then return false end
    b.cands = { force = b.force, key = "banc:" .. name, outposts = { [1] = { drill_list = drills or {} } }, smelters = fours or {} }
    Gu.U().scan["banc:" .. name] = { q = {}, pos = 1, next_at = game.tick + Gu.RESCAN }
    return true
  end,
  cause = function(name, field, value)
    local b = group(name)
    if b then b[field] = value end
    return b ~= nil
  end,
  joueurs = function(name, list)
    local b = group(name)
    if b then b.players = list end
    return b ~= nil
  end,
  statut = function(entity) return Gel.status(entity) end,
  etat = function(name)
    local u = Gu.U()
    if not u then return { ilots = 0, figes = 0, machines_figees = 0, pertes = 0 } end
    local fid = "banc:" .. name
    local n, fz, ents = 0, 0, 0
    for _, id in ipairs(u.ids_f[fid] or {}) do
      local I = u.ilots[id]
      n = n + 1
      if I.st.frozen then fz = fz + 1; ents = ents + #I.machines end
    end
    local s = u.stats[fid] or {}
    return { ilots = n, figes = fz, machines_figees = ents, pertes = s.pertes or 0 }
  end,
  garnison = function(name, force, hq, surface)
    local a = Ga.A()
    if not a then return false end
    local vid = "banc:" .. name
    if a.v[vid] and a.v[vid].n > 0 then Ga.wake_view(a, vid, "banc", game.tick) end
    a.posts[vid], a.lists[vid], a.hit[vid], a.lost[vid] = nil, nil, nil, nil
    a.bancs[name] = { force = force, hq = { x = hq.x or hq[1], y = hq.y or hq[2] }, surface = surface or 1, soldiers = {}, per = {},
      turrets = {}, army_out = false }
    a.bforce[force] = vid
    return true
  end,
  soldat = function(name, entity, role, x, y)
    local b = garrison(name)
    if not (b and entity and entity.valid and entity.unit_number) then return false end
    local u = entity.unit_number
    b.soldiers[u] = { entity = entity }
    if role then
      b.per[u] = { role = role, key = role .. ":" .. math.floor(x) .. ":" .. math.floor(y) .. ":" }
    end
    return true
  end,
  tourelle = function(name, entity)
    local b = garrison(name)
    if not (b and entity and entity.valid) then return false end
    b.turrets[entity.unit_number] = entity
    local a = Ga.A()
    a.lists["banc:" .. name] = nil
    return true
  end,
  g_cause = function(name, field, value)
    local b = garrison(name)
    if b then b[field] = value end
    return b ~= nil
  end,
  g_joueurs = function(name, list)
    local b = garrison(name)
    if b then b.players = list end
    return b ~= nil
  end,
  -- Commande donnée à un soldat de banc par le chemin du mod (crochet Gel.before_command, comme soldats.lua et military.lua) : rend
  -- l'état `active` juste après le crochet (réveil au tick même, C15).
  g_commande = function(name, entity)
    if not (garrison(name) and entity and entity.valid) then return nil end
    Gel.before_command(entity)
    return entity.active
  end,
  -- Le soldat entre dans un groupe neuf, envoyé en (x, y), comme military.lua (crochet, add_member, groupe noté) ; rend le numéro du groupe.
  g_groupe = function(name, entity, x, y)
    local b = garrison(name)
    if not (b and entity and entity.valid and b.soldiers[entity.unit_number]) then return nil end
    Gel.before_command(entity)
    local g = entity.surface.create_unit_group({ position = entity.position, force = entity.force })
    g.add_member(entity)
    g.set_command({ type = defines.command.go_to_location, destination = { x = x, y = y }, radius = 2,
      distraction = defines.distraction.by_enemy })
    b.soldiers[entity.unit_number].group = g.group_number
    return g.group_number
  end,
  g_compte = function(on)
    local a = Ga.A()
    if a then a.count = on == true end
    return a ~= nil
  end,
  g_etat = function(name)
    local a = Ga.A()
    local b = a and a.bancs[name]
    if not b then return { soldats = 0, figes = 0, actifs_figes = 0 } end
    local vid = "banc:" .. name
    local V = a.v[vid]
    local n, inactive = 0, 0
    for _, u in ipairs(Gc_sorted(b.soldiers)) do
      local e = b.soldiers[u].entity
      if e.valid then
        n = n + 1
        if not e.active then inactive = inactive + 1 end
      end
    end
    local posts = 0
    for _ in next, a.posts[vid] or {} do posts = posts + 1 end
    local why = {}
    for _, k in ipairs(Gc_sorted(a.stats.why)) do why[#why + 1] = k .. "=" .. a.stats.why[k] end
    return { soldats = n, figes = V and V.n or 0, actifs_figes = inactive, reveils = a.stats.reveil, gels = a.stats.gel,
      causes = table.concat(why, " "), degats = a.stats.dmg, degats_soldats = a.stats.dmg_soldat, requetes = a.stats.requetes,
      postes = posts }
  end,
  constantes = function()
    return { STEP = Gu.STEP, CALM = G.CALM, GUET = G.GUET, WAKE_R = G.WAKE_R, FREEZE_R = G.FREEZE_R, WRITES = Gel.WRITES }
  end,
  -- C20 (gain net, série A/B sur la partie du DC) : le réglage de carte écrit par le MOD lui-même (un mod ne peut écrire que ses
  -- propres réglages : le mod de test passe par ici) ; rend Gel.on() relu juste après. INTERFACE DE BANC SEULEMENT : rien dans le mod
  -- ne l'appelle ; sans appel d'un banc (mod de test, scénarios x10-gel-c20-*), elle n'a aucun effet sur une partie.
  reglage = function(on)
    settings.global[Gel.SETTING] = { value = on == true }
    return Gel.on()
  end,
  -- C19 (micro-banc x10-gel-zones) : zones de menace du guet des garnisons pour la faction fid (Ga.zones, lecture seule).
  zones = function(fid) return Ga.zones(fid) end,
  -- C20' (b), scène x10-gel-echelle : recensement de la partie (sortes d'îlots, refus, avant-postes, garnisons), lecture (census).
  recensement = function() return census() end,
  -- C20 : ce que le gel tient figé, toutes factions et groupes de banc confondus : { ilots, figes, machines_figees, soldats_figes,
  -- n_frozen } (n_frozen : machines figées comptées par le registre).
  bilan = function()
    local u = Gu.U()
    local n, fz, ents = 0, 0, 0
    if u then
      for _, id in ipairs(Gc_sorted(u.ilots)) do
        local I = u.ilots[id]
        n = n + 1
        if I.st.frozen then fz = fz + 1; ents = ents + #I.machines end
      end
    end
    local a = Ga.A()
    local g = Gel.state()
    return { ilots = n, figes = fz, machines_figees = ents, soldats_figes = a and a.n or 0, n_frozen = g and g.n_frozen or 0 }
  end,
})

return {}
