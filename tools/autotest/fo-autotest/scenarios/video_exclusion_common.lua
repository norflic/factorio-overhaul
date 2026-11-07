--[[
  Lot VIDEO-PLAFONDS, partie d (V99) : contrat en MOTEUR RÉEL du réglage d'exclusion de demande `fo-war-exclusion` (règle pure
  shared/ai3/exclusion.lua, lecture et journal script/ai3/exclusion.lua). « Un objet exclu = 0 ordre. »
  Protocole : la guerre part seule (réglages de carte, comme pnj-auto), 2 factions ; au tick 1300, un client de chaque faction
  consomme 120 plaques de fer par minute (remote fo-capi bench_sink : puits mesuré de la capitalisation) ; la première décision
  de la capitalisation vient vers le tick 3000 (minute 1) ; contrôle au tick 3900.
    variante « exclusion » : fo-war-exclusion = « iron-plate » AVANT la guerre. Attendu : chaque faction a décidé au moins une fois,
                             aucun ordre ouvert ni fini ne porte sur les plaques de fer ; le journal du mod porte « [FO-EXCLU] »
                             (lu par tools/autotest/video_exclusion.py sur l'archive du banc).
    variante « temoin »    : réglage VIDE (la valeur par défaut est relue vide avant tout). Même protocole ; la ligne [FO-CAPI] de la
                             décision montre l'ordre sur les plaques (lu par le même outil) : sans lui, l'attendu de la variante
                             « exclusion » ne prouverait rien.
  Lancement : banc.py --out <archive> --qui video-plafonds -- 4000 video-exclusion <source> (puis video-exclusion-temoin).
  Journal : [FO-VIDEO-EXCLUSION] / [FO-VIDEO-EXCLUSION-TEMOIN].
]]

local ITEM = "iron-plate"

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

return function(variant)
  local excluded = (variant == "exclusion")
  return {
    description = "VIDEO-PLAFONDS V99 : objet exclu = 0 ordre (" .. variant .. ")",
    check_tick = 3900,

    init = function(ctx)
      local st = ctx.state()
      local default_ok, default_value = pcall(function() return settings.global["fo-war-exclusion"].value end)
      ctx.check(default_ok and default_value == "", "reglage fo-war-exclusion declare, VIDE par defaut", tostring(default_value))
      local set = {
        ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 2),
        ctx.remote("factorio-overhaul", "war_setting", "fo-war-soldiers", 10),
        ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", 3),
        ctx.remote("factorio-overhaul", "war_setting", "fo-war-autostart", true),
      }
      ctx.check(set[1] == 2 and set[2] == 10 and set[3] == 3 and set[4] == true, "reglages de la guerre ecrits et relus")
      if excluded then
        local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-exclusion", ITEM)
        ctx.check(v == ITEM, "fo-war-exclusion ecrit et relu (« " .. ITEM .. " »)", tostring(v))
      end
      st.keys = {}
    end,

    tick = function(ctx, e)
      if e.tick ~= 1300 then return end
      local st = ctx.state()
      for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
        if row.key ~= "player" then
          st.keys[#st.keys + 1] = row.key
          ctx.remote("fo-capi", "bench_sink", row.key, ITEM, 120)
        end
      end
      table.sort(st.keys)
      ctx.log("tick 1300 : puits de 120 " .. ITEM .. "/min chez " .. #st.keys .. " faction(s) : " .. table.concat(st.keys, " "))
    end,

    finish = function(ctx)
      local st = ctx.state()
      ctx.check(#st.keys == 2, "2 factions lancees avant le tick 1300", #st.keys)
      for _, key in ipairs(st.keys) do
        local s = ctx.remote("fo-capi", "status", key)
        ctx.check(s ~= nil and (s.decisions or 0) >= 1, key .. " : la capitalisation a decide au moins une fois (sinon le contrat est vide)",
          s and tostring(s.decisions))
        local touched = {}
        for _, list in ipairs({ s and s.open or {}, s and s.done or {} }) do
          for _, rec in ipairs(list) do
            local blob = table.concat({ tostring(rec.key), tostring(rec.product), tostring(rec.resource), tostring(rec.item) }, " ")
            if blob:find(ITEM, 1, true) then touched[#touched + 1] = tostring(rec.key) end
          end
        end
        if excluded then
          ctx.check(#touched == 0, key .. " : AUCUN ordre ouvert ni fini sur " .. ITEM .. " (objet exclu)", table.concat(touched, ","))
        else
          ctx.log(key .. " : temoin, ordres sur " .. ITEM .. " : " .. (#touched > 0 and table.concat(touched, ",") or "aucun (voir la ligne [FO-CAPI])"))
        end
      end
    end,
  }
end
