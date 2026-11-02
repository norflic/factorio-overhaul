--[[
  Lot FLUX-VOIE : frequence du melange de ressources sur une carte NATURELLE du banc (graine FO_MAP_SEED ou 20261020). Une foreuse
  electrique mine tout ce que couvre sa zone de 5 x 5 tuiles : une tuile de minerai dont la zone de 5 x 5 contient une AUTRE ressource
  minable est « exposee ». Journal : [FO-FLUX-VOIE] par ressource : tuiles, exposees, exposees a >= 4 tuiles etrangeres.
  Lancement : banc.py ... -- 300 flux-voie-carte <source> (rien n'est construit).
]]
local R = 14 -- chunks de rayon autour de (0, 0) : 448 tuiles
local MINABLE = { ["iron-ore"] = true, ["copper-ore"] = true, ["coal"] = true, ["stone"] = true }

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k)
  return k
end

return {
  description = "FLUX-VOIE-CARTE : ressources etrangeres dans la zone de 5 x 5 d'une foreuse (carte naturelle)",
  check_tick = 200,
  init = function(ctx) end,
  tick = function(ctx, e)
    local s = ctx.surface()
    local t = game.tick
    if t == 5 then
      s.request_to_generate_chunks({ 0, 0 }, R)
      s.force_generate_chunk_requests()
    elseif t == 20 then
      local grid, names = {}, {}
      local L = R * 32
      for _, r in ipairs(s.find_entities_filtered({ area = { { -L, -L }, { L, L } }, type = "resource" })) do
        local x, y = math.floor(r.position.x), math.floor(r.position.y)
        grid[x .. "," .. y] = r.name
        names[r.name] = (names[r.name] or 0) + 1
      end
      ctx.state().names = names
      local stat = {}
      for key, name in pairs(grid) do
        if MINABLE[name] then
          local x, y = key:match("^(-?%d+),(-?%d+)$")
          x, y = tonumber(x), tonumber(y)
          local foreign = 0
          for dy = -2, 2 do
            for dx = -2, 2 do
              local o = grid[(x + dx) .. "," .. (y + dy)]
              if o and o ~= name then foreign = foreign + 1 end
            end
          end
          local st = stat[name] or { n = 0, exp = 0, exp4 = 0, exp9 = 0 }
          stat[name] = st
          st.n = st.n + 1
          if foreign >= 1 then st.exp = st.exp + 1 end
          if foreign >= 4 then st.exp4 = st.exp4 + 1 end
          if foreign >= 9 then st.exp9 = st.exp9 + 1 end
        end
      end
      local all = {}
      for _, n in ipairs(sorted_keys(names)) do all[#all + 1] = n .. "=" .. names[n] end
      ctx.log("ressources dans " .. (2 * R * 32) .. " x " .. (2 * R * 32) .. " tuiles : " .. table.concat(all, " "))
      for _, name in ipairs(sorted_keys(stat)) do
        local st = stat[name]
        ctx.log(string.format("%s : %d tuiles, exposees (>= 1 etrangere dans le 5 x 5) %d (%.1f %%), >= 4 etrangeres %d (%.1f %%), >= 9 etrangeres %d (%.1f %%)",
          name, st.n, st.exp, 100 * st.exp / st.n, st.exp4, 100 * st.exp4 / st.n, st.exp9, 100 * st.exp9 / st.n))
      end
      ctx.state().done = true
    end
  end,
  finish = function(ctx)
    ctx.check(ctx.state().done == true, "releve fait")
  end,
}
