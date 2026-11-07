--[[
  Lot VIDEO L11 « trace sur la carte » : pose et retire les étiquettes de carte décidées par la règle pure shared/ai3/trace.lua (Tr).
  Une ligne [FO-TRACE] par événement ; une étiquette (icône du produit, texte « R<rang> ordre|pose <pourquoi> ») par module décidé ou
  posé qui a une position, au plus Tr.MAX par force, la plus ancienne retirée.
    - L'étiquette d'une équipe va sur SA force. Votre équipe EST la force du joueur. Pour qu'une faction soit vue du DC, le réglage de
      débogage TC.SETTING (runtime-global, défaut faux) la pose AUSSI sur la force du joueur ; réglage coupé : ces copies sont
      retirées au passage suivant de TC.flush.
    - F131 : add_chart_tag exige un chunk CARTOGRAPHIÉ (rien en --create ni --benchmark, seulement en partie avec images) : une
      étiquette refusée reste « à poser » dans l'état et TC.flush la retente (appel par décision de la capitalisation).
    - État dans f.team.trace (sérialisable : numéros d'étiquette, jamais un objet du moteur ni une fonction) ; retrait par
      find_chart_tags autour de la position et tag_number.
  Branchement (INTEGRATION_VIDEO.md, L11) : TC.note(f, TC.event(o, rec), tick) pour chaque ordre envoyé par decide_finish (après le
  filtre de L6) ; TC.capi puis TC.flush à chaque pensée, à côté d'Ind.sweep (script/ai3/capitalisation.lua). build.lua n'est pas touché.
]]

local Tr = require("shared.ai3.trace")

local TC = {}

TC.SETTING = "fo-debug-trace-carte"
TC.CHUNK = 32

local floor = math.floor

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Le réglage de débogage est-il allumé ? (réglage absent avant l'intégration : faux, sans erreur)
function TC.on_player_too()
  local ok, v = pcall(function() return settings.global[TC.SETTING].value end)
  return ok and v == true
end

function TC.state(f)
  f.team = f.team or {}
  f.team.trace = f.team.trace or Tr.new()
  return f.team.trace
end

local function surface_of(f)
  if f.hq and f.hq.valid then return f.hq.surface end
  return game.surfaces[1]
end

--- Forces qui reçoivent les étiquettes de l'équipe f : la sienne, et celle du joueur si le réglage est allumé (une seule fois).
function TC.forces(f)
  local list = {}
  local own = game.forces[f.force]
  if own and own.valid then list[1] = own end
  if TC.on_player_too() then
    local p = game.forces.player
    if p and p.valid and not (own and own.name == p.name) then list[#list + 1] = p end
  end
  return list
end

local function icon_of(item)
  if game.item_prototypes and game.item_prototypes[item] then return { type = "item", name = item } end
  if game.fluid_prototypes and game.fluid_prototypes[item] then return { type = "fluid", name = item } end
  return nil
end

local function place(e, force, surface)
  if not force.is_chunk_charted(surface, { x = floor(e.x / TC.CHUNK), y = floor(e.y / TC.CHUNK) }) then return false end
  local tag = force.add_chart_tag(surface, { position = { x = e.x, y = e.y }, icon = icon_of(e.item), text = e.text })
  if not tag then return false end
  e.placed[force.name] = { n = tag.tag_number }
  return true
end

local function unplace(e, fname, surface)
  local pl = e.placed[fname]
  e.placed[fname] = nil
  local force = pl and game.forces[fname]
  if not (force and force.valid) then return 0 end
  local n = 0
  for _, t in ipairs(force.find_chart_tags(surface, { { e.x - 1, e.y - 1 }, { e.x + 1, e.y + 1 } })) do
    if t.valid and t.tag_number == pl.n then t.destroy(); n = n + 1 end
  end
  return n
end

--- Un événement ev = { key, item, x, y, why, rank, kind = "decide" | "pose" } de l'équipe f. Rend le nombre d'étiquettes posées.
function TC.note(f, ev, tick)
  local st = TC.state(f)
  local acts = Tr.push(st, ev, tick)
  -- une ligne par événement neuf : un ordre sans lieu (décision), ou une étiquette posée ou changée (rien quand elle est la même)
  if acts.add or not Tr.wants_tag(ev) then log(Tr.line(f.key or f.force, ev, tick)) end
  local surface = surface_of(f)
  if not surface then return 0 end
  for _, e in ipairs(acts.remove) do
    for _, fname in ipairs(sorted_keys(e.placed)) do unplace(e, fname, surface) end
  end
  local n = 0
  if acts.add then
    for _, force in ipairs(TC.forces(f)) do if place(acts.add, force, surface) then n = n + 1 end end
  end
  return n
end

--- Retente les étiquettes « à poser » (chunk cartographié depuis) ; retire les copies sur la force du joueur quand le réglage est coupé.
--- Rend (posées, retirées).
function TC.flush(f, tick)
  local st = f.team and f.team.trace
  if not st then return 0, 0 end
  local surface = surface_of(f)
  if not surface then return 0, 0 end
  local put, gone = 0, 0
  local forces = TC.forces(f)
  local allowed = {}
  for _, force in ipairs(forces) do allowed[force.name] = true end
  for _, e in ipairs(st.list) do
    for _, fname in ipairs(sorted_keys(e.placed)) do
      if not allowed[fname] then gone = gone + unplace(e, fname, surface) end
    end
  end
  for _, force in ipairs(forces) do
    for _, e in ipairs(Tr.pending(st, force.name)) do if place(e, force, surface) then put = put + 1 end end
  end
  return put, gone
end

--- Branchement (INTEGRATION_VIDEO.md, L11) : l'événement d'un ordre ENVOYÉ par la décision de capitalisation (o : ordre de Ca.decide,
--- rec : son suivi, script/ai3/capitalisation.lua decide_finish). À la décision, le module n'a pas encore de lieu : une ligne de journal.
function TC.event(o, rec)
  return { key = "capi:" .. tostring(o.key), item = o.item or o.resource, why = tostring(o.kind) .. " " .. tostring(rec and rec.exec or "?"),
    rank = type(o.rank) == "number" and o.rank or nil, kind = Tr.KINDS.decide }
end

--- Une fois par pensée (à côté d'Ind.sweep) : les modules des ordres ouverts (cs.open, exec « module ») qui ont un lieu au plan
--- directeur (f.build.projects[id].parts[1]) reçoivent leur étiquette, « ordre » tant que le projet n'est pas fini, « pose » ensuite.
--- Une étiquette inchangée ne coûte aucun appel au moteur (Tr.push). Rend le nombre d'étiquettes posées.
function TC.capi(f, cs, tick)
  local b = f.build
  if not (b and b.projects and cs and cs.open) then return 0 end
  local n = 0
  for _, rec in ipairs(cs.open) do
    if rec.exec == "module" then
      for _, id in ipairs(rec.mod_ids or { rec.module }) do
        local p = b.projects[id]
        local part = p and p.parts and p.parts[1]
        if part and part.w and part.h then
          local x0, y0 = part.ox or part.x, part.oy or part.y
          if x0 and y0 then
            n = n + TC.note(f, { key = "capi:" .. tostring(rec.key) .. ":" .. tostring(id), item = rec.item or rec.resource,
              why = tostring(rec.kind) .. " " .. tostring(p.state), rank = type(rec.rank) == "number" and rec.rank or nil,
              kind = (p.state == "fini") and Tr.KINDS.pose or Tr.KINDS.decide, x = x0 + part.w / 2, y = y0 + part.h / 2 }, tick)
          end
        end
      end
    end
  end
  return n
end

return TC
