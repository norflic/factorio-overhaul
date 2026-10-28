--[[
  Lot MAINS : micro-banc en moteur réel de la règle « le fond ne travaille pas à la main ce que les machines fournissent »
  (shared/team/mains.lua, script/team/mains.lua). La partie du guide (scenarios/etape1-guide.lua) arrêtée à 15 min.
  Lecture par l'interface distante fo-mains : mesure par genre de tâche, débit automatique lu aux statistiques de la force,
  matières couvertes, tâches de fond libres qui minent ou fondent.
  Lancement : banc.py --out <archive> --graine <N> --qui MAINS -- 54500 mains-court <source>. Journal : [FO-MAINS-COURT].
]]

local base0 = require("scenarios/etape1-guide")
local TAG = "[FO-MAINS-COURT] "

local base = {}
for k, v in pairs(base0) do base[k] = v end
base.description = "MAINS : partie du guide jusqu'a 15 min, mesure du travail a la main et matieres couvertes par les machines"
base.check_tick = 54000
base.shots = nil
base.shots_delay = nil

local function keys_of(ctx)
  local out = { "player" }
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row.key end
  end
  return out
end

--- « ressource=raison fonte:plaque=raison » -> ensemble des noms
local function covered_set(why)
  local set = {}
  for tok in (why or ""):gmatch("%S+") do
    local name = tok:match("^fonte:([^=]+)=") or tok:match("^([^=]+)=")
    if name then set[name] = tok:match("^fonte:") and "fonte" or "mine" end
  end
  return set
end

base.finish = function(ctx)
  local any_rows, any_cover = 0, 0
  for _, key in ipairs(keys_of(ctx)) do
    local ok, st = pcall(remote.call, "fo-mains", "status", key)
    ctx.check(ok and st ~= nil, "fo-mains : etat de l'equipe " .. key, tostring(st))
    if ok and st then
      local rows = 0
      for _ in pairs(st.rows) do rows = rows + 1 end
      any_rows = any_rows + rows
      ctx.check(rows > 0, key .. " : des taches terminees mesurees", rows)
      -- Débits : une mesure par minute de jeu, jamais négative.
      local worst_n, neg = 1e9, false
      local flows = {}
      for p, fl in pairs(st.flow) do
        worst_n = math.min(worst_n, fl.n)
        if fl.rate < 0 then neg = true end
        flows[#flows + 1] = string.format("%s=%.1f/min(%d)", p, fl.rate, fl.n)
      end
      table.sort(flows)
      ctx.check(next(st.flow) ~= nil and worst_n >= 10, key .. " : au moins 10 minutes de debit mesurees pour chaque produit",
        table.concat(flows, " "))
      ctx.check(not neg, key .. " : aucun debit negatif")
      -- Cohérence : une matière couverte n'a plus aucune tâche de fond LIBRE qui la mine ou la fond.
      local cov = covered_set(st.why)
      local clash = {}
      for lab, n in pairs(st.open) do
        local kind, detail = lab:match("^(%a+):([^+]+)")
        if kind == "mine" and cov[detail] == "mine" then clash[#clash + 1] = lab .. "x" .. n end
        if kind == "smelt" then
          for p in detail:gmatch("[^/]+") do if cov[p] == "fonte" then clash[#clash + 1] = lab .. "x" .. n end end
        end
      end
      table.sort(clash)
      ctx.check(#clash == 0, key .. " : aucune tache de fond libre sur une matiere couverte", table.concat(clash, " "))
      if next(cov) then any_cover = any_cover + 1 end
      log(TAG .. string.format("%s | couvert [%s] | debits {%s} | fond libre %s | mesure %s", key, st.why, table.concat(flows, " "),
        (function() local o = {} for lab, n in pairs(st.open) do o[#o + 1] = lab .. "x" .. n end table.sort(o) return table.concat(o, " ") end)(),
        st.acc))
    end
  end
  ctx.check(any_rows > 0, "au moins une equipe a des taches mesurees", any_rows)
  log(TAG .. string.format("equipes avec au moins une matiere couverte : %d", any_cover))
end

return base
