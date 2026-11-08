--[[ Lot RANGEES-ASM (8/11) : une hausse de la demande d'un objet agrandit la rangée de la même recette au lieu d'ouvrir un îlot.
  Ordres de banc (fo-capi, bench_order, exécutant réel des ordres « chaine ») dès que la capitalisation existe :
    1. chaine copper-cable à 60/min  : rangée neuve (1 machine) ;
    2. chaine copper-cable à 120/min : la MÊME rangée, encore en attente, agrandie (même numéro de module) ;
    3. chaine iron-gear-wheel à 600/min : rangée neuve dimensionnée sur la demande (5 machines au moins si le gabarit le permet).
  Journal du mod : [FO-RANGEES-ASM] (une ligne par décision). Lancement :
    banc.py --out <archive> --qui RANGEES-ASM -- 1500 rangees-asm <source>
]]
local CHECK = 1400
local PARTS = { { "assembling-machine-1", 40 }, { "assembling-machine-2", 20 }, { "fast-inserter", 60 }, { "inserter", 60 },
  { "transport-belt", 400 }, { "small-electric-pole", 100 }, { "medium-electric-pole", 40 }, { "iron-chest", 20 },
  { "copper-plate", 400 }, { "iron-plate", 400 } }
local ORDERS = { { "chaine", "copper-cable", 60 }, { "chaine", "copper-cable", 120 }, { "chaine", "iron-gear-wheel", 600 } }

local function first_team(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out[1]
end

return {
  description = "RANGEES-ASM : une hausse de la demande agrandit la rangee au lieu d'ouvrir un ilot",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    for _, s in ipairs({ { "fo-war-ia3e", true }, { "fo-war-capi", true }, { "fo-war-workers", 30 } }) do
      local v = ctx.call("war_setting", s[1], s[2])
      ctx.check(v == s[2], "reglage " .. s[1] .. " = " .. tostring(s[2]), tostring(v))
    end
    local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
    ctx.check(ok == true, "difficulte Paisible imposee avant la guerre", tostring(ok))
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
    st.res = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 300 then
      local r = first_team(ctx)
      st.key = r and r.key
      ctx.check(st.key ~= nil, "faction relevee (" .. tostring(st.key) .. ")")
      -- objets des gabarits au coffre (premier banc, 13 h 18 : « objets impossibles : assembling-machine-1,fast-inserter »)
      local put = st.key and ctx.remote("fo-ind", "stock", st.key, PARTS)
      ctx.check(put ~= nil, "coffre : pieces des rangees posees", tostring(put))
    end
    if st.key and not st.done and t > 300 and t % 60 == 0 and ctx.remote("fo-capi", "status", st.key) ~= nil then
      st.done = t
      for i, o in ipairs(ORDERS) do
        local mids, info = ctx.remote("fo-capi", "bench_order", st.key, o[1], o[2], o[3])
        st.res[i] = { ids = mids, why = info }
        ctx.log(string.format("ordre %d %s %s %d/min -> %s", i, o[1], o[2], o[3],
          mids and ("modules " .. table.concat(mids, ",")) or ("refus : " .. tostring(info))))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local r1, r2, r3 = st.res[1], st.res[2], st.res[3]
    ctx.check(st.done ~= nil, "ordres de banc envoyes", tostring(st.done))
    local id1 = r1 and r1.ids and r1.ids[1]
    local id2 = r2 and r2.ids and r2.ids[1]
    ctx.check(id1 ~= nil, "ordre 1 (copper-cable 60/min) : une rangee", tostring(r1 and r1.why))
    ctx.check(id1 ~= nil and id1 == id2, "ordre 2 (copper-cable 120/min) : la MEME rangee agrandie, pas un ilot de plus",
      tostring(id1) .. " -> " .. tostring(id2) .. " " .. tostring(r2 and r2.why))
    ctx.check(r3 and r3.ids and #r3.ids == 1, "ordre 3 (iron-gear-wheel 600/min) : une seule rangee", tostring(r3 and r3.why))
  end,
}
