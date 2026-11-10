-- Lot ASSAUTS-TITANESQUES (10/11), au banc « content », en moteur réel :
--   (1) la barrière de périmètre se charge (tourelle, objet, recette, technologie, arc, autocollant) ; une borne ALIMENTÉE foudroie un
--       mordeur qui franchit son champ (il meurt ou perd de la vie), une borne SANS courant le laisse intact (témoin) ;
--   (2) un assaut de boss forcé par l'interface distante (préavis d'une seconde, cible « banc » loin de la zone de contenu) : le Kaiju de
--       l'ère de la partie et son escorte apparaissent sur la force naturelle, la machine à phases passe annonce -> rassemblement -> marche,
--       le journal [FO-ASSAUT] porte une ligne par phase.
-- (arsenal.lua est du Lua pur sans require : lisible depuis ce mod ; la règle des assauts requiert les niveaux et les titans par des chemins
--  relatifs au mod du jeu : ses noms sont lus par l'interface distante « assaut » : kaiju, era)
local A = require("__factorio-overhaul__/shared/content/arsenal")

local CIBLE = { x = 2600, y = 2600 } -- loin de la zone de contenu (x 300.., y 240..) : l'assaut ne touche pas les autres contrôles
local DECLENCHE = 600                -- tick du départ forcé (après la mise en place de tous les greffons)

return {
  setup = function(ctx)
    ctx.prepare_zone("grass-1")
    local z, s = ctx.zone, ctx.surface()
    local P = A.perimetre
    local tir, cible = game.create_force("fo-bar-tir"), game.create_force("fo-bar-cible")
    tir.set_cease_fire(cible, false)
    cible.set_cease_fire(tir, false)
    -- seules les bornes peuvent toucher les mordeurs témoins : paix avec la force naturelle (nid et défenseurs du banc) et le joueur
    for _, other in ipairs({ "enemy", "player" }) do
      for _, f in ipairs({ tir, cible }) do
        f.set_cease_fire(other, true)
        game.forces[other].set_cease_fire(f, true)
      end
    end
    tir.technologies[P.tech.name].researched = true
    local st = ctx.state()
    st.rows = {}
    -- le poteau du banc alimente 64 tuiles autour de lui (fo-autotest-power-pole) : le témoin SANS courant est à 98 tuiles à l'est
    for i, powered in ipairs({ true, false }) do
      local x, y = z.x0 + (powered and 20 or 118), z.y0 + 20
      local b = s.create_entity({ name = P.name, position = { x, y }, force = tir })
      if powered then ctx.power(x, y + 6, tir) end
      -- le mordeur est posé DANS le champ (à 1,5 tuile) : il franchit la ligne
      local u = s.create_entity({ name = "small-biter", position = { x + 1.5, y }, force = cible })
      if u then u.set_command({ type = defines.command.wander, radius = 1 }) end
      st.rows[i] = { barrier = b, biter = u, health = u and u.health, powered = powered }
      ctx.check(b ~= nil and u ~= nil, "borne " .. (powered and "alimentee" or "sans courant") .. " et son mordeur poses")
    end
    st.assaut_lance = false
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.assaut_lance and e.tick >= DECLENCHE then
      st.assaut_lance = true
      st.etat0 = ctx.call("assaut", "now", { preavis = 60, cible = CIBLE, defenses = 0 })
      st.evo = game.forces.enemy.evolution_factor
    end
  end,

  verify = function(ctx)
    local p = game.entity_prototypes
    local P = A.perimetre
    local miss = {}
    for _, n in ipairs({ P.name, P.name .. "-arc", P.name .. "-sticker" }) do if not p[n] then miss[#miss + 1] = n end end
    if not game.item_prototypes[P.name] then miss[#miss + 1] = "item " .. P.name end
    if not game.recipe_prototypes[P.name] then miss[#miss + 1] = "recette " .. P.name end
    if not game.technology_prototypes[P.tech.name] then miss[#miss + 1] = "technologie " .. P.tech.name end
    ctx.check(#miss == 0, "barriere : tourelle, arc, autocollant, objet, recette, technologie charges", table.concat(miss, " "))
    local bp = p[P.name]
    ctx.check(bp and bp.type == "electric-turret" and bp.collision_box.right_bottom.x - bp.collision_box.left_top.x < 1,
      "barriere : tourelle electrique d'une tuile", bp and (bp.collision_box.right_bottom.x - bp.collision_box.left_top.x))
    ctx.check(bp and bp.attack_parameters.range <= 5, "barriere : portee courte", bp and bp.attack_parameters.range)
    local rows = ctx.state().rows
    local r1, r2 = rows[1], rows[2]
    ctx.check(r1 and r1.biter and (not r1.biter.valid or r1.biter.health < r1.health), "barriere alimentee : le mordeur qui franchit est foudroye (mort ou blesse)",
      r1 and r1.biter and r1.biter.valid and r1.biter.health or "mort")
    ctx.check(r2 and r2.biter and r2.biter.valid and r2.biter.health == r2.health, "temoin : borne sans courant, mordeur intact",
      r2 and r2.biter and r2.biter.valid and r2.biter.health or "mort")

    -- assaut forcé
    local st = ctx.state()
    local etat = ctx.call("assaut")
    ctx.check(st.etat0 ~= nil and st.etat0.n == 1 and st.etat0.phase == "annonce", "assaut : depart force, phase annonce", st.etat0 and st.etat0.phase)
    ctx.check(etat.n == 1 and (etat.phase == "marche" or etat.phase == "assaut" or etat.phase == "rassemblement" or etat.phase == "aucun"),
      "assaut : la machine a phases avance (" .. tostring(etat.phase) .. ")", etat.apparus .. " apparu(s), " .. etat.vivants .. " vivant(s)")
    ctx.check(etat.apparus > 0 or etat.phase == "aucun", "assaut : des assaillants sont apparus", etat.apparus)
    local kaijus = etat.kaiju_name and ctx.surface().count_entities_filtered({ name = etat.kaiju_name, force = "enemy" }) or 0
    ctx.check(etat.kaiju_name ~= nil and etat.era == 1, "assaut : Kaiju de l'ere de la partie (banc : ere 1, aucune guerre)", tostring(etat.kaiju_name) .. " ere " .. tostring(etat.era))
    ctx.check(kaijus >= 1 or etat.phase == "aucun", "assaut : le Kaiju est sur la carte (force naturelle)", kaijus)
    ctx.check(etat.kaijus >= 1 or etat.phase == "aucun", "assaut : le Kaiju est inscrit a l'assaut", etat.kaijus)
  end,
}
