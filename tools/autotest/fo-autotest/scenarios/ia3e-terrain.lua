--[[
  Lot IA3-e (27/10) : DIAGNOSTIC du terrain des factions pour l'automatisation (expérience E212). Scénario de MESURE :
  la partie `default` (4 factions, Paisible) ; à 10 s, le plan directeur d'IA1-d est allumé pour chaque faction
  (remote « fo-ia1d » enable, rayon 5, SANS demande : seule l'évaluation des lots et des rues tourne) ; à 50 s, une ligne
  par faction :
    - QG ; tuiles d'eau dans un rayon de 64, 128, 192 et 256 tuiles (une centrale à vapeur demande une rive) ;
    - lots du treillis par état (libre, defricher, gisement, rive, occupe, refuse) et le lot de rive le plus proche ;
    - lots de gisement par ressource (les fonderies électriques veulent des foreuses sur un gisement à 3 lots au plus).
  Aucun contrôle sur les valeurs (mesure) : un seul contrôle, « chaque faction a son relevé ».
  Lancement : banc.py ... -- 3200 ia3e-terrain <source> ; journal [FO-IA3E-TERRAIN].
]]

local T_ENABLE = 600
local T_READ = 3000

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function kv(t)
  local out = {}
  for _, k in ipairs(sorted_keys(t)) do out[#out + 1] = k .. "=" .. tostring(t[k]) end
  return table.concat(out, " ")
end

local function hq_of(s, row)
  local e = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
  return e
end

return {
  description = "IA3-e : terrain des factions (eau, lots, gisements) pour l'automatisation",
  base = "default",
  check_tick = T_READ + 60,

  init = function(ctx) end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == T_ENABLE then
      st.keys = {}
      for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
        if row.key ~= "player" then
          local ok = ctx.remote("fo-ia1d", "enable", row.key, { radius = 5 })
          st.keys[#st.keys + 1] = row.key
          ctx.log(string.format("plan directeur allume pour %s : %s", row.key, tostring(ok)))
        end
      end
    end
    if e.tick == T_READ then
      local s = ctx.surface()
      st.done = 0
      for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
        if row.key ~= "player" then
          local hq = hq_of(s, row)
          local lay = ctx.remote("fo-ia1d", "layout", row.key)
          if hq and lay then
            local p = hq.position
            local water = {}
            for _, r in ipairs({ 64, 128, 192, 256 }) do
              water[#water + 1] = s.count_tiles_filtered({ position = p, radius = r, collision_mask = "water-tile" })
            end
            local states, res = {}, {}
            local rive_d, rive_n = nil, 0
            for _, l in ipairs(lay.lots or {}) do
              states[l.state] = (states[l.state] or 0) + 1
              local cx, cy = (l.x0 + l.x1) / 2, (l.y0 + l.y1) / 2
              local d = math.floor(math.sqrt((cx - p.x) ^ 2 + (cy - p.y) ^ 2))
              if l.state == "rive" then
                rive_n = rive_n + 1
                if not rive_d or d < rive_d then rive_d = d end
              end
              if l.state == "gisement" and l.reason then
                local k = l.reason
                res[k] = res[k] and math.min(res[k], d) or d
              end
            end
            local segs = {}
            for _, g in ipairs(lay.segs or {}) do segs[g.state] = (segs[g.state] or 0) + 1 end
            ctx.log(string.format("%s QG (%d, %d) | eau r64=%d r128=%d r192=%d r256=%d | lots {%s} | rive : %d lot(s), le plus proche a %s tuiles | gisements (distance du plus proche) {%s} | rues {%s}",
              row.key, math.floor(p.x), math.floor(p.y), water[1], water[2], water[3], water[4], kv(states), rive_n,
              tostring(rive_d), kv(res), kv(segs)))
            st.done = st.done + 1
          else
            ctx.log(string.format("%s : QG ou releve du plan absent", row.key))
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check((st.done or 0) >= 1 and st.done == #(st.keys or {}), "chaque faction a son releve", tostring(st.done))
  end,
}
