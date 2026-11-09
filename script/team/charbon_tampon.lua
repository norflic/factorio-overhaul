--[[
  Lot COMBUSTIBLE-CENTRALE (levier a, 8/11) : le coffre d'une centrale est sous son seuil et le coffre du QG n'a plus de charbon (Cc.refill
  rend `short` : « aucune tache possible », avant ce lot la centrale restait à sec jusqu'au retour du charbon au QG). Les coffres de SORTIE
  des avant-postes de charbon (o.sinks, script/faction/outposts.lua) tiennent alors le tampon : la tâche de remplissage URGENTE
  (Cc.PRIO, même clé « ia1d:<projet>:q:<quai> » que celle du QG) part du tampon choisi par la règle pure Cc.pick_buffer
  (shared/team/charbon_centrale.lua) et passe par le MÊME programme que les dépôts de quartier : goto tampon, take_depot, goto coffre de la
  centrale, remplissage, retour du reste (worker.lua, ia1d_program, `ia1d.depot` + `depot_items`). Aucune étape nouvelle.
  Un tampon garde Cc.BUFFER_KEEP charbons (les brûleurs de son avant-poste). Rien n'est écrit hors la mémoire f.build.charbon[pid] (journal).
  Appelé par quai_tasks (script/team/build.lua) SEULEMENT quand r.short ; lecture des coffres au moteur, aucun nom d'objet écrit ici.
]]
local Cc = require("shared.team.charbon_centrale")
local T = require("shared.team.config")
local State = require("script.faction.state")

local Ct = {}

--- Tampons de charbon de l'équipe : coffres de sortie valides des avant-postes dont le produit est `item`.
--- Rend { { id, x, y, count, d2 } } (d2 : distance carrée au coffre de la centrale en (qx, qy)).
function Ct.buffers(f, item, qx, qy, depot_name)
  local out = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    local spec = o and T.outposts[o.kind]
    if spec and spec.product == item then
      for k, s in ipairs(o.sinks or {}) do
        if s.valid and s.type == "container" and s.name == depot_name then
          local n = s.get_inventory(defines.inventory.chest).get_item_count(item)
          if n > 0 then
            local dx, dy = s.position.x - qx, s.position.y - qy
            out[#out + 1] = { id = tostring(oid) .. "/" .. k, x = s.position.x, y = s.position.y, count = n, d2 = dx * dx + dy * dy }
          end
        end
      end
    end
  end
  return out
end

--- Tâche de remplissage depuis un tampon, ou nil (et la raison). q : quai { x, y, item } ; n : charbon au coffre ; r : verdict de Cc.refill
--- (short) ; ax, ay : point d'appui du coffre de la centrale ; depot_name : nom du coffre des dépôts (Build.Quartiers.DEPOT).
function Ct.relay(f, p, surface, i, q, n, r, ax, ay, depot_name, tick)
  if not (r and r.short) then return nil, "le QG a du charbon" end
  if f.build and f.build.opts and f.build.opts.no_tampon then return nil, "regle coupee (banc temoin)" end -- remote fo-ia1d set_option no_tampon
  local want = (r.target or 0) - n
  local pick, why = Cc.pick_buffer(Ct.buffers(f, q.item, q.x, q.y, depot_name), want)
  if not pick then return nil, why end
  local b = f.build
  b.charbon = b.charbon or {}
  local st = b.charbon[p.id] or {}
  b.charbon[p.id] = st
  if st.tampon_said ~= pick.buffer.id then
    st.tampon_said = pick.buffer.id
    b.charbon_logs = (b.charbon_logs or 0) + 1
    st.tampon_logs = (st.tampon_logs or 0) + 1
    if b.charbon_logs <= Cc.LOGS and st.tampon_logs <= Cc.BUFFER_LOGS then
      log(string.format("[FO-CHARBON-CENTRALE] %s : centrale %d, coffre %d a %d charbon(s), coffre du QG SANS charbon : tampon de l'avant-poste %s en (%.0f, %.0f) a %d charbon(s), %d a porter (cible %d), tache URGENTE (prio %d) a %.1f min",
        f.key or "player", p.id, i, n, pick.buffer.id, pick.buffer.x, pick.buffer.y, pick.buffer.count, pick.count, r.target, r.prio, (tick or 0) / 3600))
    end
  end
  return {
    key = "ia1d:" .. p.id .. ":q:" .. i, kind = "carry", prio = r.prio, no_rush = true, domain = "logistique", work = 40,
    depot_items = { { q.item, pick.count } },
    ia1d = { pid = p.id, mode = "fill", idx = i, ax = ax, ay = ay, depot = { x = pick.buffer.x, y = pick.buffer.y } },
  }
end

return Ct
