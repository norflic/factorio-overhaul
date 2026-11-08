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
    bilan()                          { ilots, figes, machines_figees, soldats_figes, n_frozen }, toutes factions (C20).
]]

local Gel = require("script.faction.gel")
local Gu = require("script.faction.gel_usines")
local G = require("shared.faction.gel")
local Ga = require("script.faction.gel_garnisons")

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
