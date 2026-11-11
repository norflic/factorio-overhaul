--[[
  Lot LEVIATHAN-SEG (mandat du DC, 11/11) : le corps ARTICULÉ d'un titan serpentin en jeu (T.ALLIES dont la règle dit `segmente` : le
  Léviathan). Règle pure : shared/robots/serpent.lua (historique en distance, pose et orientation des pièces, ordre de dessin) ;
  prototypes : sprites fixes <préfixe><archétype>-<pièce>-<stade>-<direction>-<couche> (prototypes/titans.lua, feuilles
  graphics/robots/titans/<archétype>/).
  - La TÊTE est l'entité ; elle regarde le CAP de sa trajectoire (Se.cap, g.seg.dir), jamais `orientation` (figée à 0 pour un
    spider-vehicle sans rotation du torse) ; son corps animé est dessiné par script/robots/titans.lua (M.hooks.tete : corps_anime, ou le même corps refait
    avec la même animation, la même vitesse et la même phase). Les SEGMENTS et la QUEUE sont des `rendering.draw_sprite` (aucune entité :
    UPS), trois couches chacun (ombre, corps, lueur), ciblés sur l'entité avec un décalage : entre deux mises à jour ils suivent la tête
    au tick près, sans aucun calcul.
  - Toutes les `segmente.periode` ticks (règle du titan) : l'historique des positions de la tête avance (un point tous les `pas`
    tuiles), chaque pièce est reposée à sa distance d'arc derrière la tête, tournée selon la courbe (image de la direction), avec
    l'ondulation verticale de la règle (l'ombre reste au sol).
  - ORDRE DE DESSIN (vue de 3/4 depuis le sud) : la pièce la plus au nord d'abord, la plus au sud par-dessus, la tête comprise
    (Se.ordre). Les rendus d'une même couche se dessinent dans l'ordre de leur création : quand l'ordre n'est plus juste à `tol` tuiles
    près (Se.ordre_valide), les pièces et la tête sont refaites dans le nouvel ordre (quelques objets, seulement quand la chaîne tourne).
  - Les rendus meurent avec l'entité (mort, remplacement de palier) : `dessiner` les refait depuis corps() ; l'historique, l'ordre et les
    identifiants vivent dans `global` (entrée du titan dans le registre `titans`) : rien à reconstruire au chargement d'une partie ; un
    titan posé avant ce lot reçoit ses pièces à sa première mise à jour.
  Déterminisme : listes, aucun pairs, aucune trigonométrie (table des directions de la règle).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local T = require("shared.robots.titans")
local Se = require("shared.robots.serpent")

local M = {}

--- Crochets posés par script/robots/titans.lua au chargement du module (comme Armee.hooks) : `tete(g, r)` (re)dessine le corps animé de
--- la tête à cet instant de l'ordre de dessin ; `orienter(g, r)` lui fait prendre l'image de son cap (g.seg.dir) dès qu'il change.
M.hooks = {}

local function couche_sprite(r, k, stage, dir, couche)
  local spec = r.segmente
  local piece = (k <= spec.n) and spec.pieces[1] or spec.pieces[2]
  return T.piece_name(r, piece, stage, dir, couche)
end

local function detruire_pieces(sg)
  for _, l in ipairs(sg.ids or {}) do
    for _, id in ipairs(l) do
      if rendering.is_valid(id) then rendering.destroy(id) end
    end
  end
  sg.ids = {}
end

--- Détruit les pièces d'un titan (si elles vivent encore) et oublie son corps articulé (la tête reste à titans.lua).
function M.detruire(g)
  if g.seg then detruire_pieces(g.seg) end
  g.seg = nil
end

local function ordonnees(pos, P)
  local ys = { pos.y }
  for k, p in ipairs(P) do ys[k + 1] = p.y end
  return ys
end

--- (Re)dessine la tête et les pièces dans l'ordre de dessin `ordre` (1 = la tête, k + 1 = la pièce k), aux poses `P`.
local function poser(g, r, sg, P, ordre)
  detruire_pieces(sg)
  local e = g.e
  local pos = e.position
  local spec = r.segmente
  for _, i in ipairs(ordre) do
    if i == 1 then
      if M.hooks.tete then M.hooks.tete(g, r) end
    else
      local k = i - 1
      local p = P[k]
      local dx, dy = p.x - pos.x, p.y - pos.y
      local oy = Se.ondulation(sg.cran, k, spec.onde)
      local l = {}
      for c_i, c in ipairs(T.COUCHES_ANIM) do
        l[c_i] = rendering.draw_sprite({ sprite = couche_sprite(r, k, g.stage, p.dir, c[1]), target = e,
          target_offset = (c_i == 1) and { dx, dy } or { dx, dy - oy }, surface = e.surface, render_layer = c[2] })
      end
      sg.ids[k] = l
      sg.dirs[k] = p.dir
    end
  end
  sg.ordre = ordre
end

--- Dessine le corps articulé d'un titan segmenté `g` (archétype `r`) : historique en ligne droite derrière la tête, pièces posées, tête
--- (crochet) à sa place dans l'ordre de dessin. Appelé par corps() à la pose et au remplacement de palier.
function M.dessiner(g, r)
  local ancien = g.seg
  M.detruire(g)
  local spec = r.segmente
  if not spec then return end
  local e = g.e
  local pos = e.position
  local n = spec.directions
  local hist, dir
  if ancien and ancien.hist and #ancien.hist > 0 then
    -- remplacement de palier (même position) : la chaîne garde son chemin et la tête son cap
    hist, dir = ancien.hist, ancien.dir
    Se.avancer(hist, pos, spec.pas, Se.points_max(spec), dir or 0, n)
  else
    dir = Se.direction_orientation(e.orientation, n)
    hist = Se.init(pos, dir, n, Se.points_max(spec), spec.pas)
  end
  dir = Se.cap(hist, pos, spec.pas, n, dir)
  local P = Se.placer(hist, pos, spec.pas, Se.abscisses(spec), n, dir)
  local sg = { hist = hist, ids = {}, dirs = {}, cran = 0, dir = dir }
  g.seg = sg
  poser(g, r, sg, P, Se.ordre(ordonnees(pos, P)))
end

--- Mise à jour d'un titan segmenté : l'historique suit la tête, chaque pièce est reposée (décalage, image de sa direction, ondulation) ;
--- l'ordre de dessin est refait s'il n'est plus juste.
function M.maj(g, r)
  local spec = r.segmente
  local sg = g.seg
  if not (spec and sg) then return end
  local e = g.e
  local l1 = sg.ids[1]
  if not (l1 and rendering.is_valid(l1[2])) then
    M.dessiner(g, r)
    return
  end
  local pos = e.position
  local n = spec.directions
  Se.avancer(sg.hist, pos, spec.pas, Se.points_max(spec), sg.dir or 0, n)
  local dir_t = Se.cap(sg.hist, pos, spec.pas, n, sg.dir)
  local P = Se.placer(sg.hist, pos, spec.pas, Se.abscisses(spec), n, dir_t)
  sg.cran = (sg.cran + 1) % #Se.ONDE
  if dir_t ~= sg.dir then
    -- la tête tourne : son corps animé prend tout de suite l'image du nouveau cap (titans.lua, crochet `orienter`)
    sg.dir = dir_t
    if M.hooks.orienter then M.hooks.orienter(g, r) end
  end
  local ys = ordonnees(pos, P)
  if not Se.ordre_valide(sg.ordre, ys, spec.tol) then
    poser(g, r, sg, P, Se.ordre(ys))
    return
  end
  for k, p in ipairs(P) do
    local l = sg.ids[k]
    local dx, dy = p.x - pos.x, p.y - pos.y
    local oy = Se.ondulation(sg.cran, k, spec.onde)
    local change = p.dir ~= sg.dirs[k]
    for i, c in ipairs(T.COUCHES_ANIM) do
      local id = l and l[i]
      if id and rendering.is_valid(id) then
        rendering.set_target(id, e, (i == 1) and { dx, dy } or { dx, dy - oy })
        if change then rendering.set_sprite(id, couche_sprite(r, k, g.stage, p.dir, c[1])) end
      end
    end
    sg.dirs[k] = p.dir
  end
end

-- Une mise à jour par période de chaque archétype segmenté (abonnements statiques, une seule fois par période distincte).
do
  local vues = {}
  for _, r in ipairs(T.ALLIES) do
    local spec = r.segmente
    if spec and not vues[spec.periode] then
      vues[spec.periode] = true
      local periode = spec.periode
      Events.on_nth_tick(periode, function()
        local st = Storage.ns("titans")
        if not st or not st.juggernauts or #st.juggernauts == 0 then return end
        for _, g in ipairs(st.juggernauts) do
          if g.e and g.e.valid then
            local a = T.allie_of_id(g.id or "juggernaut")
            if a and a.segmente and a.segmente.periode == periode then
              -- titan posé avant le corps articulé (partie d'avant LEVIATHAN-SEG) : ses pièces sont posées à la première mise à jour
              if g.seg then M.maj(g, a) else M.dessiner(g, a) end
            end
          end
        end
      end)
    end
  end
end

return M
