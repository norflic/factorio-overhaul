--[[
  Lot FOREUSES-THERMIQUES, MESURE du lead (7/11, 13 h 05, après le diagnostic « waiting_for_space_in_destination ») : sur la SAUVEGARDE du
  DC (copie fo-logs/2026-11-05_PARTIE-DC-ESSAI/autosave1-2121.zip), la collecte des plaques aux fours des avant-postes s'arrête-t-elle
  parce que le stockage de votre équipe est plein, ou pour une autre raison ? Le scénario ne change RIEN (nom au KIT_EGAL du mod de test,
  aucun réglage, aucune règle) ; il lit, par le remote de banc collect_probe (lecture seule), au départ puis toutes les 30 s pendant 2,5 min :
    (a) le stockage : coffres (QG + annexes), cases vides, place libre / en stock par produit et minerai, âge du dernier dépôt refusé ;
    (b) par avant-poste : production en attente, réceptacles pleins, tournée prise ou libre (et depuis quand), échecs du flux ;
    (c) les statuts moteur des thermiques, des électriques et des réceptacles (defines.entity_status), et l'inventaire de chaque PNJ.
  Plus, au départ et à la fin, le rapport du banc (log_report : ligne « equipe » avec tâches ok/échec et raisons d'échec, « ramasse »).
  Journal [FO-STOCK-DC] ; aucun BILAN de critère (mesure), seulement « relevé lisible ».
  Lancement (sans images, une place) :
    py -3.9 -B tools/autotest/banc.py --sauvegarde "<racine>\fo-logs\2026-11-05_PARTIE-DC-ESSAI\autosave1-2121.zip" --out <archive>
       --qui FOREUSES-TH -- 9300 foreuses-stock-dc <source>
]]

local DUR = 9000
local EVERY = 1800

local function names_of(h, status_name)
  if h == "" then return "-" end
  local out = {}
  for k, n in h:gmatch("(%-?%d+):(%d+)") do out[#out + 1] = (status_name[tonumber(k)] or k) .. "=" .. n end
  return table.concat(out, ",")
end

local S = {
  description = "FOREUSES-THERMIQUES : mesure du stockage et de la collecte sur la sauvegarde du DC",
  base = nil,
  check_tick = -1,
}

local function probe(ctx, label)
  local status_name = {}
  for name, v in pairs(defines.entity_status) do status_name[v] = name end
  local r = ctx.remote("fo-ia1", "collect_probe", "player")
  if not r then
    ctx.log("[FO-STOCK-DC] " .. label .. " : releve illisible")
    return nil
  end
  local s = r.stock
  ctx.log(string.format("[FO-STOCK-DC] %s tick %d | stock : coffres %d, cases %d, vides %d | place libre/en stock : %s | depot refuse il y a %s ticks",
    label, r.tick, s.chests, s.slots, s.empty, s.room, tostring(s.refused_ago)))
  local tot = { output = 0, stuck = 0, task = 0, free = 0 }
  for _, o in ipairs(r.outposts) do
    tot.output, tot.stuck = tot.output + o.output, tot.stuck + o.stuck
    if o.task == 1 then tot.task = tot.task + 1 end
    if o.free_age >= 0 then tot.free = tot.free + 1 end
    ctx.log(string.format("[FO-STOCK-DC] %s avant-poste %d (%s, migr %s) : en attente %d, pleins %d, a sec %d, tournee %s, libre depuis %s s, echecs %d, sans visite %d s | thermiques {%s} | electriques {%s} | recepteurs {%s}",
      label, o.id, o.kind, o.migr, o.output, o.stuck, o.dry, o.task == 1 and "prise" or "-", o.free_age >= 0 and tostring(math.floor(o.free_age / 60)) or "-",
      o.fails, o.idle_s, names_of(o.burners, status_name), names_of(o.electrics, status_name), names_of(o.sinks, status_name)))
  end
  ctx.log(string.format("[FO-STOCK-DC] %s total : %d avant-postes, %d objets en attente, %d recepteurs pleins, %d tournees prises, %d libres | PNJ (id:tache:vides/cases) %s",
    label, #r.outposts, tot.output, tot.stuck, tot.task, tot.free, table.concat(r.workers, " ")))
  return r
end

S.init = function(ctx)
  local st = ctx.state()
  local t = game.tick
  S.check_tick = t + DUR
  st.t0 = t
  ctx.check(t > 0, "partie du DC chargee depuis sa sauvegarde (tick de depart > 0)", t)
  ctx.call("log_report", "STOCK-DC depart")
  ctx.check(probe(ctx, "DEPART") ~= nil, "releve lisible au depart")
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.t0 or e.tick <= st.t0 or e.tick - st.t0 >= DUR or (e.tick - st.t0) % EVERY ~= 0 then return end
  probe(ctx, "+" .. math.floor((e.tick - st.t0) / 60) .. "s")
end

S.finish = function(ctx)
  ctx.call("log_report", "STOCK-DC fin")
  ctx.check(probe(ctx, "FIN") ~= nil, "releve lisible a la fin")
end

return S
