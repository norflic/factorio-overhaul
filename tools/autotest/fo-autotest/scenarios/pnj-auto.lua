--[[
  Lot PNJ-JOUABLE (24/10) : la guerre se lance SANS console, par les réglages de carte « fo-war-* » (ce que le
  Directeur Créatif cochera au menu Nouvelle partie). Le banc coche les réglages par l'interface distante du mod
  (`war_setting` : un mod n'écrit que ses propres réglages), puis :
  - tick 1 200 : la guerre est lancée seule (au passage du tick 600), avec 3 factions, 20 soldats et 3 ouvriers
    au plus, autour du point de départ ; puis le banc l'arrête (`war_stop`) ;
  - tick 2 500 (contrôle final) : elle n'est PAS relancée (une fois par partie).
  Lancement : `fo-autotest.bat nopause 2600 pnj-auto <source>`. Journal : [FO-PNJ-AUTO].
]]

return {
  description = "PNJ-JOUABLE : guerre lancee par les reglages de carte, une fois par partie",
  base = nil,
  check_tick = 2500,

  init = function(ctx)
    local st = ctx.state()
    st.set = {
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 3),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-soldiers", 20),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", 3),
      ctx.remote("factorio-overhaul", "war_setting", "fo-war-autostart", true),
    }
    ctx.check(st.set[1] == 3 and st.set[2] == 20 and st.set[3] == 3 and st.set[4] == true,
      "reglages de carte ecrits et relus (3, 20, 3, vrai)", table.concat({ tostring(st.set[1]), tostring(st.set[2]),
        tostring(st.set[3]), tostring(st.set[4]) }, ", "))
    local refused = ctx.remote("factorio-overhaul", "war_setting", "fo-pvp-difficulty", "hard")
    ctx.check(refused == nil, "relais refuse un reglage hors fo-war-*", tostring(refused))
    local pvp = ctx.remote("fo-pvp", "status")
    ctx.check(#pvp.factions == 0, "aucune guerre avant le premier passage", #pvp.factions)
  end,

  tick = function(ctx, e)
    if e.tick ~= 1200 then return end
    local st = ctx.state()
    local pvp = ctx.remote("fo-pvp", "status")
    st.n_auto = #pvp.factions
    local poi = ctx.call("points_of_interest")
    st.n_alive = #poi.factions
    st.removed = ctx.remote("factorio-overhaul", "war_stop")
    ctx.log(string.format("tick 1200 : %d factions lancees, %d vivantes ; arret : %s entites retirees", st.n_auto,
      st.n_alive, tostring(st.removed)))
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.n_auto == 3, "guerre lancee seule avec 3 factions avant le tick 1200", st.n_auto)
    ctx.check(st.n_alive == 3, "3 factions vivantes au tick 1200", st.n_alive)
    ctx.check((st.removed or 0) > 0, "guerre arretee par war_stop", st.removed)
    local pvp = ctx.remote("fo-pvp", "status")
    ctx.check(#pvp.factions == 0, "pas de relance apres l'arret (une fois par partie)", #pvp.factions)
  end,
}
