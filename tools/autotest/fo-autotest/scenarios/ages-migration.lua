--[[
  Lot AGES : migration d'une sauvegarde 0.6.35 (DOUBLE SOURCE) vers la branche : les champs nouveaux de f.team.capital (c.defer, c.eblock,
  c.far, c.thaw) n'existent pas dans la sauvegarde ; le chargement et 30 min de partie doivent les créer sans erreur, et le centre
  de chaque faction doit être décidé.
    py -3.9 -B tools/autotest/banc.py --creation <racine>/fo-logs/2026-11-02_PARITE/src-0.6.35 --out <archive> --qui AGES -- 108100 ages-migration <source>
  Création : PvP Paisible, guerre de 2 factions (30 soldats, 10 ouvriers), coffre d'équipe garni. Contrôles au tick 108 000 (30 min).
  Journal : [FO-AGES-MIGRATION].
]]

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  if not ok or type(rows) ~= "table" then return {} end
  return rows
end

return {
  description = "AGES : sauvegarde 0.6.35 rechargee par la branche, etat du capital recree, centre decide",
  base = nil,
  check_tick = 108000,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 10)
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", guerre " .. tostring(st.war))
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.log("version de creation " .. tostring(st.version_create) .. ", version du banc " .. tostring(script.active_mods["factorio-overhaul"]))
    local n, decided, centre, alive = 0, 0, 0, 0
    for _, r in ipairs(teams()) do
      if r.key ~= "player" then
        n = n + 1
        local s = remote.call("fo-capital", "status", r.key)
        if s then
          alive = alive + 1
          if (s.decisions or 0) >= 1 then decided = decided + 1 end
          if (s.cc_level or 0) >= 1 then centre = centre + 1 end
          ctx.log(string.format("%s : decisions %d, ameliorations %d, refus %d, centre niveau %d", r.key, s.decisions or 0, s.upgrades or 0,
            s.refused or 0, s.cc_level or 0))
        end
      end
    end
    ctx.check(n >= 2, "deux factions relevees", n)
    ctx.check(alive == n, "l'interface fo-capital repond pour chaque faction", alive .. "/" .. n)
    ctx.check(decided == n, "chaque faction a decide une amelioration apres le rechargement", decided .. "/" .. n)
    ctx.check(centre == n, "chaque faction a un centre de commandement", centre .. "/" .. n)
    ctx.check(st.version_create ~= nil, "version de creation lue", tostring(st.version_create))
  end,
}
