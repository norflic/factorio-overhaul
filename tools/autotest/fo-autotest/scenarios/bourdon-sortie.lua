-- Lot BOURDON-SORTIE (4/11, QCM-4/11 du DC : « sortie automatique mais on doit pouvoir les déplacer manuellement hein, contrôler les robots »).
--   avec images (UN JOUEUR EST CONNECTÉ : l'outil Armée est rejoué par fo-robots-ui.tool, comme rb-ui) :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 2700" --qui BOURDON-SORTIE -- 2500 bourdon-sortie <source>
--   sans images (aucun joueur) : mêmes étapes, l'ordre passe par l'interface fo-robots.order (Ordres.select puis Ordres.order : même adaptateur).
-- Chaîne : un Bourdon fini dans la sortie d'un Portique (âge 15) -> le balayage des usines le sort -> il descend au point de sortie -> il gagne le
-- ralliement -> l'outil le choisit -> « aller » (Maj + droit) -> il vole, se pose -> « attaquer » (glisser droit sur 3 tourelles d'une force
-- hostile, à 60 tuiles) -> il s'approche à 35 tuiles et sonne Le Glas. Journal : [FO-BOURDON-SORTIE].
local C = require("scenarios/bourdon_commun")

local X, Y = 7400.5, -2599.5            -- centre du Portique 11 × 11
local SORTIE = { x = X, y = Y + 7.5 }    -- Mo.out_point : y + taille / 2 + 2
local RALLIEMENT = { x = X, y = Y + 16.5 } -- Mo.default_rally : 9 tuiles au sud de la sortie
local ALLER = { x = X + 15, y = Y + 16.5 }
local CIBLES = { { X + 75, Y + 12.5 }, { X + 75, Y + 16.5 }, { X + 75, Y + 20.5 } }
local OBJET, PORTIQUE, RECETTE, TOOL = "fo-bourdon-item", "fo-robot-gantry", "fo-robot-make-bourdon", "fo-robot-order"

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function player() return game.connected_players[1] end

local function etat(ctx)
  local st = ctx.state()
  return st.id and ctx.remote("fo-bourdon", "etat", st.id) or nil
end

--- Un ordre : par l'outil Armée si un joueur est connecté (événement rejoué), sinon par fo-robots.order (même Ordres.order).
local function ordre(ctx, ev, kind, cx, cy, r)
  local p = player()
  local st = ctx.state()
  local avant = ctx.remote("fo-robots", "state", "player").stats.ordered
  if p then
    ctx.remote("fo-robots-ui", "tool", p.index, ev, TOOL, cx - r, cy - r, cx + r, cy + r)
  else
    local b = etat(ctx)
    local cible = kind == "attack" and { x = CIBLES[2][1], y = CIBLES[2][2] } or { x = cx, y = cy }
    ctx.remote("fo-robots", "order", "player", kind, cible.x, cible.y, { x0 = b.x - 6, y0 = b.y - 6, x1 = b.x + 6, y1 = b.y + 6 }, 6)
  end
  st.voie = p and "outil Armee (joueur connecte)" or "fo-robots.order (sans joueur)"
  return ctx.remote("fo-robots", "state", "player").stats.ordered - avant
end

return {
  description = "BOURDON-SORTIE : sortie du Portique, ralliement, outil Armee, aller, Glas",
  check_tick = 2400,
  shots_delay = 2420,

  init = function(ctx)
    C.forces()
    ctx.prepare_area(X - 40, Y - 20, X + 110, Y + 50, "dry-dirt")
    local s = ctx.surface()
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X - 200, Y - 200 }, { X + 300, Y + 200 } } })) do en.destroy() end
    local st = ctx.state()
    ctx.remote("fo-robots", "set_age", "player", 15)
    local force = game.forces.player
    force.recipes[RECETTE].enabled = true
    st.w = s.create_entity({ name = PORTIQUE, position = { X, Y }, force = "player", raise_built = true })
    st.w.set_recipe(RECETTE)
    st.mis = st.w.get_output_inventory().insert({ name = OBJET, count = 1 })
    -- contrôlé ICI : le balayage des usines (toutes les 60 ticks, tick 0 compris) peut sortir le Bourdon avant le premier tick du scénario
    ctx.check(st.mis == 1 and st.w.get_output_inventory().get_item_count(OBJET) == 1, "un Bourdon fini est depose dans la sortie du Portique", tostring(st.mis))
    st.cibles = {}
    for i, c in ipairs(CIBLES) do st.cibles[i] = s.create_entity({ name = "gun-turret", position = c, force = C.CIBLE }) end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    -- (1) sortie : le balayage (toutes les 60 ticks) retire l'objet et le Bourdon descend au point de sortie
    if not st.sorti and t > 10 and t % 10 == 0 then
      local bs = ctx.surface().find_entities_filtered({ name = "fo-bourdon", area = { { X - 60, Y - 60 }, { X + 60, Y + 60 } } })
      if #bs == 1 then
        st.sorti = t
        for id = 1, 9 do
          local b = ctx.remote("fo-bourdon", "etat", id)
          if b and b.unite == bs[1].unit_number then st.id = id end
        end
        local b = etat(ctx)
        ctx.check(st.w.get_output_inventory().get_item_count(OBJET) == 0, "le Portique est vide : il peut continuer", "tick " .. t)
        ctx.check(b and b.phase == "descente" and dist(b, SORTIE) < 1, "le Bourdon descend au point de sortie du Portique",
          b and string.format("%s en (%.1f, %.1f), tick %d", b.phase, b.x, b.y, t) or "absent")
      end
    end
    if not st.sorti then return end
    if t % 100 == 0 then
      local b = etat(ctx)
      ctx.log(string.format("t %d : %s", t, b and string.format("%s (%.1f, %.1f) glas %d, touches %d, tues %d, attente %s", b.phase, b.x, b.y, b.compte, b.touches,
        b.tues, tostring(b.attente)) or "absent"))
    end
    -- (2) il gagne le ralliement, puis l'outil le choisit et l'envoie : « aller »
    if not st.au_ralliement and t % 10 == 0 then
      local b = etat(ctx)
      if b and b.phase == "pose" and dist(b, RALLIEMENT) < 4 then
        st.au_ralliement = t
        ctx.ok("ancres posees, il a gagne le ralliement du Portique", string.format("(%.1f, %.1f), tick %d", b.x, b.y, t))
        local p = player()
        if p then
          ctx.remote("fo-robots-ui", "tool", p.index, "selected", TOOL, b.x - 6, b.y - 6, b.x + 6, b.y + 6)
          local sel = ctx.remote("fo-robots-ui", "selection", p.index)
          ctx.check(#sel == 1 and sel[1] == b.unite, "l'outil Armee choisit le Bourdon", #sel .. " robot(s) : " .. table.concat(sel, ","))
        end
        local n = ordre(ctx, "alt_reverse", "move", ALLER.x, ALLER.y, 0)
        ctx.check(n == 1, "« aller » : l'ordre est pris (" .. st.voie .. ")", n .. " robot(s)")
        st.t_aller = t
      end
    end
    if st.t_aller and not st.leve and t == st.t_aller + 20 then
      local b = etat(ctx)
      st.leve = b and b.phase
      ctx.check(b and (b.phase == "leve" or b.phase == "vol"), "il leve ses ancres pour partir", b and b.phase or "absent")
    end
    -- (3) arrivé, « attaquer » sur les tourelles hostiles : il s'approche à 35 tuiles, puis sonne
    if st.t_aller and not st.arrive and t % 10 == 0 and t > st.t_aller + 30 then
      local b = etat(ctx)
      if b and b.phase == "pose" and dist(b, ALLER) < 4 then
        st.arrive = t
        ctx.ok("arrive au point d'« aller », pose", string.format("(%.1f, %.1f), tick %d", b.x, b.y, t))
        local n = ordre(ctx, "reverse", "attack", X + 75, Y + 16.5, 6)
        ctx.check(n == 1, "« attaquer » : l'ordre est pris", n .. " robot(s)")
        st.t_glas = t
      end
    end
    if st.t_glas and not st.sonne and t % 10 == 0 then
      local b = etat(ctx)
      if b and b.compte >= 1 and (b.touches > 0 or b.tues > 0) then
        st.sonne = t
        ctx.ok("il s'est approche et a sonne Le Glas sur les tourelles", string.format("tick %d, a %.1f tuiles de la cible, %d touchees, %d detruites", t,
          dist(b, { x = X + 75, y = Y + 16.5 }), b.touches, b.tues))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.sorti ~= nil, "(1) sortie automatique du Portique", tostring(st.sorti))
    ctx.check(st.au_ralliement ~= nil, "(2) au ralliement", tostring(st.au_ralliement))
    ctx.check(st.arrive ~= nil, "(3) « aller » execute", tostring(st.arrive))
    ctx.check(st.sonne ~= nil, "(4) Glas sur l'ordre « attaquer »", tostring(st.sonne))
    local touchees = 0
    for _, c in ipairs(st.cibles or {}) do
      if not c.valid or c.health < c.prototype.max_health then touchees = touchees + 1 end
    end
    ctx.check(touchees == #CIBLES, "les 3 tourelles visees par l'outil sont touchees ou detruites", touchees .. " / " .. #CIBLES)
  end,

  shots = function(ctx, add)
    local b = etat(ctx)
    local bx, by = b and b.x or X, b and b.y or Y
    add("portique-z05", X + 30, Y - 10, 0.5, 0, { res = { 1600, 1100 }, info = false, aa = true })
    add("bourdon-cibles-z05", (bx + X + 75) / 2, by - 15, 0.5, 0, { res = { 1600, 1100 }, info = false, aa = true })
  end,
}
