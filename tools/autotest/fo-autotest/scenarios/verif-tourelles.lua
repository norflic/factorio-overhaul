--[[
  Vérification adverse du lot PNJ-VÉRIF (24/10, reprise) : les TOURELLES des équipes.
  Lecture du code :
  - shared/team/config.lua, T.unlocks[0] = { "military", "turrets", "stone-wall" } : en 1.1.91, la technologie
    vanilla qui débloque la recette gun-turret s'appelle « gun-turret » ; « turrets » n'existe pas
    (data/base/prototypes/technology.lua). script/team/team.lua unlock() ignore un nom absent (if tech then).
    Les factions IA ne pourraient donc jamais FABRIQUER de tourelles (objectif « fortify » bloqué).
  - script/team/team.lua garde un livre de recettes par clé force:tech (« player:0 » pour l'équipe du joueur, dont
    tech ne change jamais), construit au premier passage, jamais invalidé par une recherche du joueur.
  Ce scénario : partie du guide (Facile, war_start 2 30 4, coffre d'équipe garni + 3 000 fer et 600 cuivre en plus).
  - Relevé au tick 600 : recette gun-turret et technologies « turrets » / « gun-turret » pour chaque force de faction.
  - Variante « apres » (ce fichier) : le JOUEUR recherche « gun-turret » au tick 1 200, après le premier passage du
    cerveau de son équipe. Variante « avant » (verif-tourelles-avant) : recherche faite à l'init (témoin).
  - Relevé chaque minute : tourelles posées par l'équipe du joueur, au coffre, état de l'équipe ; contrôle au tick 107 000.
  Lancement : fo-autotest.bat nopause 108000 verif-tourelles <source>
]]

local CHECK = 107000
local RESEARCH_TICK = 1200
local TECH = "gun-turret"

local M = {}

function M.make(research_at_init)
  return {
    description = "VERIF : tourelles des factions et de l'equipe du joueur (recherche " .. (research_at_init and "avant" or "apres") .. ")",
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local ok = ctx.remote("fo-pvp", "set_difficulty", "easy")
      ctx.check(ok == true, "difficulte Facile imposee avant la guerre", tostring(ok))
      local started = ctx.call("war_start", 2, 30, 4)
      ctx.check(started == true, "guerre lancee : 2 factions, 30 soldats, 4 ouvriers", tostring(started))
      ctx.call("profiler", true)
      local s = ctx.surface()
      local c = game.forces.player.get_spawn_position(s)
      if research_at_init then game.forces.player.technologies[TECH].researched = true end
      local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
      local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      if chest then
        for _, it in ipairs({ { "iron-plate", 3400 }, { "copper-plate", 700 }, { "coal", 400 }, { "stone", 200 },
          { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
          chest.insert({ name = it[1], count = it[2] })
        end
      end
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      ctx.state().chest = chest
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if e.tick == 600 then
        local pvp = ctx.remote("fo-pvp", "status")
        local parts = {}
        st.faction_recipe = 0
        st.factions = 0
        for _, f in ipairs(pvp.factions) do
          local force = game.forces["fo-" .. f.key]
          if force then
            st.factions = st.factions + 1
            local r = force.recipes["gun-turret"]
            if r and r.enabled then st.faction_recipe = st.faction_recipe + 1 end
            parts[#parts + 1] = string.format("%s : recette gun-turret %s, technologie turrets %s, gun-turret recherchee %s", force.name,
              tostring(r and r.enabled), force.technologies["turrets"] and "existe" or "absente",
              tostring(force.technologies[TECH] and force.technologies[TECH].researched))
          end
        end
        ctx.log("tick 600 | " .. table.concat(parts, " ; "))
      end
      if not research_at_init and e.tick == RESEARCH_TICK then
        game.forces.player.technologies[TECH].researched = true
        ctx.log(string.format("tick %d : recherche %s faite pour la force du joueur (recette gun-turret %s)", e.tick, TECH,
          tostring(game.forces.player.recipes["gun-turret"].enabled)))
      end
      if e.tick % 3600 ~= 0 or e.tick == 0 then return end
      local s = ctx.surface()
      local placed = s.count_entities_filtered({ name = "gun-turret", force = "player" })
      local inchest = (st.chest and st.chest.valid) and st.chest.get_item_count("gun-turret") or -1
      local line = ctx.call("team_status") or "aucune equipe"
      ctx.log(string.format("minute %d | tourelles posees %d | au coffre %d | %s", e.tick / 3600, placed, inchest, line:sub(1, 220)))
      st.placed, st.inchest, st.line = placed, inchest, line
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      local placed = s.count_entities_filtered({ name = "gun-turret", force = "player" })
      ctx.check((st.factions or 0) == 2, "2 forces de faction relevees au tick 600", st.factions)
      ctx.check((st.faction_recipe or 0) == (st.factions or -1), "recette gun-turret debloquee pour chaque faction",
        string.format("%d sur %d", st.faction_recipe or 0, st.factions or 0))
      ctx.check(game.forces.player.recipes["gun-turret"].enabled, "recette gun-turret debloquee pour le joueur")
      ctx.check(placed > 0 or (st.inchest or 0) > 0, "l'equipe du joueur a fabrique des tourelles (posees ou au coffre)",
        string.format("posees %d, au coffre %d ; %s", placed, st.inchest or -1, (st.line or ""):sub(1, 160)))
    end,
  }
end

local t = M.make(false)
t.make = M.make
return t
