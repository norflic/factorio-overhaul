--[[
  Correctif C3 de DIAG_CONSO (fo-logs/2026-11-07_VIDEO-COUVERTURE/DIAG_CONSO.md, M2 à M4) : micro-banc (palier 3) de la REMISE DIRECTE contre le moteur réel.
  Un module du plan directeur reste « reserve:materiaux » parce que les objets finis qu'il attend n'arrivent pas au coffre (plein, il refuse tout objet non
  vital). Ce banc prouve la chaîne réelle de la remise : module en réserve avec son manque (p.missing écrit par Build.reserve) -> un « PNJ » arrive au
  QG avec ces objets (fo-amorce deliver : inventaire temporaire + AmRt.deliver, la fonction qu'appelle deposit_inventory de worker.lua) -> p.stock du
  module -> Build.reserve voit la réserve complète -> le module QUITTE la réserve (défrichage, fantômes), et le coffre n'a reçu aucun de ces objets.
  Ce que ce banc NE prouve pas : le crochet de worker.lua dans un vrai dépôt de PNJ (contrôlé à la lecture du code par tests/amorce_glue_test.lua) ; la
  durée de réserve d'une partie entière (rejeu long, accord du DC).
  La demande est faite comme un ordre de la capitalisation (fo-ind row), sans pièces au coffre : le module attend tout.
  Lancement : banc.py --out <archive> --qui video-amorce -- 2400 amorce-remise <worktree>
  Journal : [FO-AMORCE-REMISE] (ce banc) ; [FO-AMORCE] « remise directe » (le mod).
]]

local ITEM = "piercing-rounds-magazine"

local function teams(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

local function chest_count(ctx, key, name)
  local hq = ctx.remote("fo-prevision", "teams")
  local row
  for _, r in ipairs(hq or {}) do if r.key == key then row = r end end
  if not row then return nil end
  local n = 0
  local chests = ctx.surface().find_entities_filtered({ position = { row.x, row.y }, radius = 12, name = "fo-team-chest" })
  for _, c in ipairs(chests) do n = n + c.get_item_count(name) end
  return n
end

return {
  description = "C3 DIAG_CONSO : remise directe d'un objet attendu par un module en reserve (micro-banc)",
  base = nil,
  check_tick = 2300,

  init = function(ctx)
    for _, s in ipairs({ { "fo-war-industrie", true }, { "fo-war-ia3e", true }, { "fo-war-capi", false } }) do
      local v = ctx.call("war_setting", s[1], s[2])
      ctx.check(v == s[2], "reglage " .. s[1] .. " = " .. tostring(s[2]), tostring(v))
    end
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible")
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 400 then
      local tm = teams(ctx)
      st.key = tm[1] and tm[1].key
      ctx.check(st.key ~= nil, "deux factions relevees")
      if not st.key then return end
      local id, info = ctx.remote("fo-ind", "row", st.key, ITEM, 6)
      st.id = id
      ctx.check(id ~= nil, st.key .. " : rangee de " .. ITEM .. " demandee (" .. tostring(info) .. ")")
    end
    if st.id and not st.delivered and e.tick > 400 and e.tick % 60 == 0 then
      local rs = ctx.remote("fo-amorce", "reserves", st.key)
      local mine
      for _, r in ipairs(rs or {}) do if r.id == st.id and #r.missing > 0 then mine = r end end
      if mine then
        -- le PNJ porte la SOMME des manques de tous les modules en reserve (la centrale, avant dans la file, prend d'abord sa part)
        local total, names = {}, {}
        for _, r in ipairs(rs) do
          for _, m in ipairs(r.missing) do
            if not total[m[1]] then names[#names + 1] = m[1] end
            total[m[1]] = (total[m[1]] or 0) + m[2]
          end
        end
        table.sort(names)
        st.before_missing = {}
        st.chest_before = {}
        for _, n in ipairs(names) do
          st.before_missing[#st.before_missing + 1] = { n, total[n] }
          st.chest_before[n] = chest_count(ctx, st.key, n)
        end
        st.delivered = {}
        for _, m in ipairs(st.before_missing) do
          st.delivered[m[1]] = ctx.remote("fo-amorce", "deliver", st.key, m[1], m[2])
        end
        st.t_deliver = e.tick
        local parts = {}
        for _, m in ipairs(st.before_missing) do parts[#parts + 1] = string.format("%s %d (remis %s)", m[1], m[2], tostring(st.delivered[m[1]])) end
        ctx.log("module " .. st.id .. " en reserve au tick " .. e.tick .. " : manque " .. table.concat(parts, ", "))
      end
    end
    if st.t_deliver and not st.left and e.tick > st.t_deliver and e.tick % 30 == 0 then
      local rs = ctx.remote("fo-amorce", "reserves", st.key)
      local still = false
      for _, r in ipairs(rs or {}) do if r.id == st.id then still = r end end
      if not still then
        st.left = e.tick
        ctx.log("le module " .. st.id .. " a quitte la reserve au tick " .. e.tick .. " (" .. (e.tick - st.t_deliver) .. " ticks apres la remise)")
      elseif #still.missing > 0 then
        st.still_missing = still.missing
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.id ~= nil, "un module a ete demande")
    ctx.check(st.t_deliver ~= nil and st.before_missing ~= nil and #st.before_missing > 0, "le module est passe en reserve avec un manque (p.missing)")
    local all = st.before_missing ~= nil
    for _, m in ipairs(st.before_missing or {}) do
      if (st.delivered or {})[m[1]] ~= m[2] then all = false end
    end
    ctx.check(all, "chaque objet du manque a ete remis en entier (aucune remise au-dela du manque)")
    ctx.check(st.left ~= nil and st.left - (st.t_deliver or 0) <= 600, "le module a quitte la reserve moins de 10 s apres la remise (" .. tostring(st.left and st.left - st.t_deliver) .. " ticks)")
    local same = true
    for _, m in ipairs(st.before_missing or {}) do
      local now = chest_count(ctx, st.key, m[1])
      if st.chest_before and now and st.chest_before[m[1]] and now > st.chest_before[m[1]] then same = false end
    end
    ctx.check(same, "le coffre n'a recu aucun des objets remis (la remise ne passe pas par lui)")
    log(string.format("[FO-AMORCE-REMISE] module %s : quitte la reserve %s ticks apres la remise directe", tostring(st.id), tostring(st.left and st.left - st.t_deliver)))
  end,
}
