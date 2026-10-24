--[[
  Correction du lot IA1-a (défauts M1 et M2 de la vérification adverse, 24/10) : partie de 60 min SANS
  financement, pour mesurer l'effet de la taille des équipes sur l'ARMÉE des factions et sur le coffre de votre
  équipe. Commun aux scénarios `ia1-sansfonds` (réglages par défaut du mod) et `ia1-sansfonds-stock`
  (fo-recruit-idle-max = 60 : aucun frein par le travail, « seul le stock freine », Q-IA1-2 (2) à la lettre).

  Préparation (tick 0) : PvP « Paisible » ; guerre lancée SANS nombre d'ouvriers (la taille suit le réglage ; sur
  une source d'avant IA1-a, 10 ouvriers au plus, 2 au départ) ; AUCUN financement (stock de départ du QG) ; coffre
  de votre équipe garni comme le scénario intégré « pteam » (400 fer, 3 pistolets, 60 chargeurs...).
  Joue aussi sur une source 0.4.11 (témoin) : l'interface « fo-ia1 » y manque, le relevé se fait alors par les
  seuls rapports du mod ([FO-WAR] et « equipe du joueur », toutes les minutes).
  Lecture (armée à 30 et 60 min, ouvriers, technologie, fer du coffre de votre équipe) :
    py -3.9 -B tools/autotest/ia1_armee.py <archive> [<archive> ...]
  Graine : FO_MAP_SEED (CLAUDE.md §5). Aucun contrôle de résultat : mesure publiée (BILAN = préparation).
]]

local C = {}
local MIN = 3600

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if not chest then return false end
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  return true
end

--- idle_max : nil = réglage du mod laissé tel quel ; un nombre = fo-recruit-idle-max imposé (si l'interface existe).
function C.init(ctx, idle_max)
  local has_ia1 = remote.interfaces["fo-ia1"] ~= nil
  if idle_max and has_ia1 and remote.interfaces["fo-ia1"].set_setting then
    local v = ctx.remote("fo-ia1", "set_setting", "fo-recruit-idle-max", idle_max)
    ctx.check(v == idle_max, "fo-recruit-idle-max impose a " .. idle_max, v)
  end
  ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible")
  ctx.check(ctx.call("war_start", 4, 100) == true, "guerre lancee sans nombre d'ouvriers, sans financement")
  ctx.check(place_team_chest(ctx), "coffre d'equipe pose (garni comme pteam)")
  ctx.call("profiler", true)
  ctx.call("reset_stats")
  ctx.log("source " .. (has_ia1 and "avec l'interface fo-ia1 (lot IA1-a)" or "SANS l'interface fo-ia1 (temoin d'avant IA1-a)"))
end

function C.tick(ctx, e)
  if e.tick % MIN ~= 0 or e.tick == 0 then return end
  if not remote.interfaces["fo-ia1"] then return end
  local minute = e.tick / MIN
  for _, r in ipairs(ctx.remote("fo-ia1", "teams")) do
    ctx.log(string.format("minute %d | %s n=%d/%d recrues=%d frein=%d soldats=%d tech=%d ap=%d inactifs=%d",
      minute, r.key, r.n, r.max, r.recruited, r.held or 0, r.soldiers, r.tech, r.outposts, r.last and r.last.idle or -1))
  end
end

function C.finish(ctx)
  ctx.check(true, "mesure publiee (lecture : tools/autotest/ia1_armee.py)")
end

return C
