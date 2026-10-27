--[[
  Lot CAPITAL « améliorer, et monter les époques » : partie de MESURE (celle d'iag-partie : base « default », 4 factions,
  100 soldats, 10 ouvriers dont 8 au départ, Paisible ; cerveau par besoins et cerveau général allumés par défaut),
  allongée, plus les contrôles des améliorations des factions à `check_tick` (interface « fo-capital ») :
    1. au moins 3 factions sur 4 ont POSÉ leur centre de commandement (centre de niveau ≥ 1) ;
    2. au moins 2 factions ont AMÉLIORÉ un bâtiment (niveau ≥ 2 d'une famille autre que le centre) ;
    3. au moins une faction a MONTÉ son centre (niveau ≥ 2 : l'époque 2 ouverte) ;
    4. chaque amélioration payée vient d'une décision au journal (décisions ≥ 1 pour toute faction qui a amélioré) ;
    5. les bâtiments à niveaux recensés EN JEU (find_entities_filtered) disent la même chose que l'interface.
  Variante « temoin » : même partie, améliorations des factions COUPÉES (fo-capital set_enabled false, rangé dans
  l'état de la guerre) : mesure de l'effet sur l'armée et la recherche (relevés par minute d'ia3d_common, paliers).
  Journal : [FO-IA3D-DEFAULT] (relevés), [FO-CAPITAL] (décisions et paiements, côté mod) et les contrôles du banc.
]]

local L = require("__factorio-overhaul__/shared/levels/config")

return function(variant, ticks)
  local base = require("scenarios/iag_common")("partie", ticks)
  local CHECK = (ticks or 216000) - 600
  base.check_tick = CHECK
  base.description = "CAPITAL : ameliorations et centre des factions (" .. variant .. ")"
  local temoin = variant == "temoin"
  local init0, tick0, finish0 = base.init, base.tick, base.finish
  base.init = function(ctx)
    init0(ctx)
    if temoin then
      local ok = pcall(remote.call, "fo-capital", "set_enabled", false)
      ctx.check(ok, "temoin : ameliorations des factions coupees", tostring(ok))
    end
  end
  base.tick = function(ctx, e)
    tick0(ctx, e)
    if temoin and e.tick == 60 then pcall(remote.call, "fo-capital", "set_enabled", false) end
  end
  base.finish = function(ctx)
    finish0(ctx) -- contrôles du cerveau général (iag_common) : gardés, ils disent si la recherche souffre
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    rows = ok and rows or {}
    local s = ctx.surface()
    local n_fac, n_cc, n_up, n_cc2, n_dec_ok, n_seen_ok = 0, 0, 0, 0, 0, 0
    local center = nil
    for _, f in ipairs(L.families) do if f.key == "command" then center = f end end
    for _, row in ipairs(rows) do
      if row.key ~= "player" then
        n_fac = n_fac + 1
        local okc, c = pcall(remote.call, "fo-capital", "status", row.key)
        c = okc and c or {}
        -- Recensement EN JEU : niveau le plus haut de chaque famille parmi les bâtiments de la force.
        local seen, ccn = {}, 0
        for _, fam in ipairs(L.families) do
          local names = {}
          for n = 1, fam.max do names[#names + 1] = L.name(fam, n) end
          for _, e in ipairs(s.find_entities_filtered({ force = row.force, name = names })) do
            local _, n = L.parse(e.name)
            if fam == center then ccn = math.max(ccn, n) else seen[fam.key] = math.max(seen[fam.key] or 0, n) end
          end
        end
        local up = false
        local parts = {}
        for _, fam in ipairs(L.families) do
          if seen[fam.key] then
            parts[#parts + 1] = fam.key .. "=" .. seen[fam.key]
            if seen[fam.key] >= 2 then up = true end
          end
        end
        if ccn >= 1 then n_cc = n_cc + 1 end
        if ccn >= 2 then n_cc2 = n_cc2 + 1 end
        if up then n_up = n_up + 1 end
        if (c.upgrades or 0) == 0 or (c.decisions or 0) >= 1 then n_dec_ok = n_dec_ok + 1 end
        if (c.cc_level or 0) == ccn then n_seen_ok = n_seen_ok + 1 end
        local hist = {}
        for i, h in ipairs(c.history or {}) do
          if i > #(c.history or {}) - 6 then
            hist[#hist + 1] = string.format("%s@%.1f(v%d,c%d)", h.key, (h.tick or 0) / 3600, h.value or 0, h.work or 0)
          end
        end
        ctx.log(string.format("capital %s : centre niveau %d (interface %d), decisions %d, ameliorations %d, refus %d, batiments en jeu [%s], dernieres decisions [%s]",
          row.key, ccn, c.cc_level or 0, c.decisions or 0, c.upgrades or 0, c.refused or 0, table.concat(parts, " "),
          table.concat(hist, " ")))
      end
    end
    if temoin then
      ctx.check(n_cc == 0 and n_up == 0, "temoin : aucune amelioration de faction", n_cc .. " centre(s), " .. n_up .. " amelioree(s)")
      return
    end
    ctx.check(n_fac > 0 and n_cc >= math.min(3, n_fac), "au moins 3 factions sur 4 ont pose leur centre", n_cc .. "/" .. n_fac)
    ctx.check(n_up >= math.min(2, n_fac), "au moins 2 factions ont ameliore un batiment", n_up .. "/" .. n_fac)
    ctx.check(n_cc2 >= 1, "au moins une faction a monte son centre (epoque 2 ouverte)", n_cc2 .. "/" .. n_fac)
    ctx.check(n_dec_ok == n_fac, "chaque faction qui ameliore a decide au journal", n_dec_ok .. "/" .. n_fac)
    ctx.check(n_seen_ok == n_fac, "niveau du centre : interface = recensement en jeu", n_seen_ok .. "/" .. n_fac)
  end
  return base
end
