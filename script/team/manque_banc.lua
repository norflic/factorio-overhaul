--[[
  Lot VIDEO-COUVERTURE 3 : interface de BANC du manque mesuré des laboratoires (scénario tools/autotest/fo-autotest/scenarios/manque-labo.lua).
  Lecture et mise en scène seulement ; AUCUNE règle ici, rien n'est appelé par le jeu. Installée par script/team/manque_vue.lua (qui passe son
  module : le banc règle Mv.PERIOD sans que ce fichier ait à le requérir, pas de cycle de chargement).

    bench_labo(key, pack, lab_name, qx, qy, lx, ly, prio, quai_item) : l'équipe `key` reçoit un projet « fini » du gabarit des laboratoires (p.spec.gen = "labs") : un
        coffre de quai en (qx, qy) qui attend `quai_item` (`pack` par défaut ; un autre objet = un quai qui ne reçoit pas les packs voulus), un laboratoire `lab_name` dans l'emprise (lx, ly, 3 × 3). Le courant est posé par le scénario
        (Terrain.power) AVANT l'appel. Le manque mesuré est recalculé toutes les 2 s au lieu de 60 (Mv.PERIOD) le temps du banc, et dès la
        pensée suivante. `prio` : priorité du projet (60 par défaut ; la tournée de remplissage de ses quais a prio + 3). Rend { project, lab } ou nil.
    labo_state(key, pid, pack) : lecture seule : manque publié de CE module pour `pack` (f.team.mq.res.by_module), et celui de tous (need_all), module affamé ou non, tâche de remplissage du quai
        (priorité, prise), contenu du quai, état du laboratoire.
]]
local State = require("script.faction.state")
local Board = require("script.team.board")
local Build = require("script.team.build")
local T = require("shared.team.config")
local R = require("shared.ai3.reglages")
local RegT = require("script.team.registre_types") -- lot UPS : registre des machines par force et par type (plus de recherche sur toute la surface)

local B = {}

local CHEST = T.outposts.coal.sink -- coffre des quais (comme script/team/manque_vue.lua)

local LAB_TYPES = {} -- types du moteur des laboratoires (rôle « labo » de R.ENTITY_ROLE)
for ty, role in pairs(R.ENTITY_ROLE) do if role == "labo" then LAB_TYPES[#LAB_TYPES + 1] = ty end end
table.sort(LAB_TYPES)

local function team_of(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

--- Installe l'interface `fo-manque` (une fois). Mv = le module de script/team/manque_vue.lua.
function B.install(Mv)
  if not (remote and remote.add_interface) then return end
  if remote.interfaces and remote.interfaces["fo-manque"] then return end
  remote.add_interface("fo-manque", {
    bench_labo = function(key, pack, lab_name, qx, qy, lx, ly, prio, quai_item)
      local f = team_of(key)
      if not (f and f.team and f.hq and f.hq.valid and type(pack) == "string" and type(lab_name) == "string") then return nil end
      local surface = f.hq.surface
      local q = surface.create_entity({ name = CHEST, position = { x = qx, y = qy }, force = f.force })
      local lab = surface.create_entity({ name = lab_name, position = { x = lx + 1.5, y = ly + 1.5 }, force = f.force })
      RegT.note(lab) -- lot UPS : pose sans événement, notée au registre des machines
      if not (q and lab) then return nil end
      local id = Build.request(f, { gen = "labs", bench = "manque-labo", prio = type(prio) == "number" and prio or 60 })
      local p = f.build and f.build.projects[id]
      if not p then return nil end
      p.state, p.finished, p.counted = "fini", game.tick, true
      local qi = type(quai_item) == "string" and quai_item or pack
      p.quais[#p.quais + 1] = { x = q.position.x, y = q.position.y, item = qi }
      p.inflow = { [qi] = 1 / 15 }
      p.parts = { { ox = lx, oy = ly, w = 3, h = 3 } }
      Mv.PERIOD = 120
      if f.team.mq then f.team.mq.tick = nil end
      return { project = id, lab = lab.unit_number }
    end,
    labo_state = function(key, pid, pack)
      local f = team_of(key)
      if not (f and f.team and f.build and f.build.projects[pid]) then return nil end
      local p = f.build.projects[pid]
      local st = f.team.mq
      local res = st and st.res
      local starved
      for _, s in ipairs(res and res.starved or {}) do
        if s.id == pid then starved = table.concat(s.items or {}, ",") end
      end
      local t = Board.get(f).tasks["ia1d:" .. tostring(pid) .. ":q:1"]
      local q = p.quais[1]
      local c = q and f.hq.surface.find_entity(CHEST, { q.x, q.y })
      local lab_status, lab_packs
      local pt = p.parts[1]
      for _, e in ipairs(f.hq.surface.find_entities_filtered({ area = { { pt.ox, pt.oy }, { pt.ox + pt.w, pt.oy + pt.h } }, type = LAB_TYPES,
        force = f.force })) do
        lab_status, lab_packs = e.status, e.get_item_count(pack)
      end
      local tech = f.team.ia3 and f.team.ia3.lab and f.team.ia3.lab.tech
      local no_power = defines.entity_status.no_power
      local mine = res and res.by_module[pid]
      return { need = mine and mine[pack] or 0, need_all = res and res.need[pack] or 0, build = res and res.build[pack] or 0, starved = starved, calc_tick = st and st.tick,
        refused = res and #res.refused or -1, no_power_modules = res and #res.no_power or -1, tech = tech,
        fill = t and { prio = t.prio, prise = t.worker ~= nil, count = t.items and t.items[1] and t.items[1][2] } or nil,
        quai = (c and c.valid) and c.get_item_count(pack) or -1, lab_packs = lab_packs, lab_status = lab_status,
        lab_no_power = lab_status == no_power, hq_packs = f.hq.get_item_count(pack) }
    end,
  })
end

return B
