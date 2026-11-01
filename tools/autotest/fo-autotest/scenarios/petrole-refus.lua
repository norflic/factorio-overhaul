--[[
  Lot DIAG-PETROLE (01/11) : pourquoi une faction dont le pack chimique est OUVERT ne demande aucun site de pétrole
  (partie de 2 h du 31/10 : palier 3 à 12-29 min, pack chimique recherché à 40-58 min, aucun site, journal muet).
  Micro-banc COURT : 2 factions ; réglage fo-war-petrole allumé au tick 60 ; au tick 300 les technologies qui ouvrent le pack
  chimique sont données aux forces des factions (chaîne de prérequis du pack) ; les décisions du lot (une par minute) doivent
  alors soit demander un site, soit dire POURQUOI elles n'en demandent pas (une ligne [FO-PETROLE] par cause de refus).
  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui DIAG-P -- 9000 petrole-refus <source>
  Journal : [FO-PETROLE-REFUS].
]]

local SWITCH, GIVE = 60, 300
local CHAIN = { "automation", "logistic-science-pack", "steel-processing", "automation-2", "engine", "fluid-handling",
  "oil-processing", "plastics", "sulfur-processing", "advanced-electronics", "chemical-science-pack" }

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  local out = {}
  for _, row in ipairs(ok and type(rows) == "table" and rows or {}) do out[#out + 1] = row end
  return out
end

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

return {
  description = "DIAG-PETROLE : pack chimique ouvert aux factions, le lot demande un site ou dit pourquoi non",
  base = nil,
  check_tick = 8800,

  init = function(ctx)
    local st = ctx.state()
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 10)
    st.chest = place_team_chest(ctx)
    ctx.log("creation : guerre " .. tostring(st.war))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == SWITCH then
      ctx.log("reglage allume : " .. tostring(remote.call("factorio-overhaul", "war_setting", "fo-war-petrole", true)))
    end
    if e.tick == GIVE then
      for _, r in ipairs(teams()) do
        local f = game.forces[r.force]
        if f and r.key ~= "player" then
          local n = 0
          for _, name in ipairs(CHAIN) do
            local t = f.technologies[name]
            if t and not t.researched then t.researched = true; n = n + 1 end
          end
          local fr = f.recipes["chemical-science-pack"]
          ctx.log(string.format("[FO-PETROLE-REFUS] %s : %d technologie(s) donnee(s), recette du pack chimique ouverte : %s", r.key, n,
            tostring(fr and fr.enabled)))
        end
      end
    end
    if e.tick > GIVE and e.tick % 1800 == 0 then
      local parts = {}
      for _, r in ipairs(teams()) do
        local okp, s = pcall(remote.call, "fo-petrole", "status", r.key)
        parts[#parts + 1] = string.format("%s : decisions %s, sites %s", r.key, (okp and s) and tostring(s.decisions) or "-",
          (okp and s) and tostring(#(s.sites or {})) or "-")
      end
      ctx.log(string.format("[FO-PETROLE-REFUS] minute %.1f | %s", e.tick / 3600, table.concat(parts, " ; ")))
    end
  end,

  finish = function(ctx)
    local asked, plastic, sulfur = 0, false, false
    for _, r in ipairs(teams()) do
      if r.key ~= "player" then
        local okp, s = pcall(remote.call, "fo-petrole", "status", r.key)
        if okp and s and #(s.sites or {}) > 0 then asked = asked + 1 end
        for _, site in ipairs((okp and s and s.sites) or {}) do
          for _, it in ipairs(site.items or {}) do
            if it == "plastic-bar" then plastic = true end
            if it == "sulfur" then sulfur = true end
          end
        end
        if okp and s then
          for _, w in ipairs(s.why or {}) do ctx.log("[FO-PETROLE-REFUS] cause en cours chez " .. r.key .. " : " .. w) end
        end
      end
    end
    ctx.check(asked >= 1, "au moins une faction a demande un site de petrole une fois le pack chimique ouvert", tostring(asked))
    ctx.check(plastic and sulfur, "le site demande le plastique ET le soufre (la chaine du plastique n'est plus perdue)",
      tostring(plastic) .. "/" .. tostring(sulfur))
  end,
}
