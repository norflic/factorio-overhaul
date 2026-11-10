--[[
  Lot BALISES-TEINTE (décision du DC, 10/11) : la lueur des balises d'une équipe suit le code couleur des MODULES qu'elles
  contiennent (règle pure : shared/content/modules_teintes.lua ; cyan = vitesse, ambre = productivité, émeraude = efficacité).

  À chaque impulsion du cron des scans (script/team/hygiene.lua, Hy.step : une ligne d'appel par tranche) :
    - tranche 0 : RELEVÉ des balises de la force dans la boîte des chunks (type du moteur, aucun nom ; les balises CACHÉES du
      prototype, drapeau « hidden », par exemple la balise des modules multiplicatifs, sont écartées), triées par unit_number ;
      les lumières des balises disparues sont retirées ; si le relevé tient dans Bt.CFG.max_per_slice, tout est traité ici ;
    - sinon : St.share_capped répartit la liste sur les tranches (au plus max_per_slice par tranche, le reste compté, jamais traité) ;
    - par balise : get_module_inventory → famille de chaque module lue au PROTOTYPE (game.item_prototypes[nom].module_effect) →
      Mt.teinte → UNE lumière rendering.draw_light attachée à l'entité (sprite utilitaire, échelle selon la largeur de la balise),
      mémorisée par unit_number : f.team.balises[u] = { id, c = { r, g, b } } ; recolorée (rendering.set_color) seulement si la
      couleur a changé (Mt.meme) ; retirée si la balise est vide ou disparue. Jamais de churn.
    - journal, à la dernière tranche travaillée : « [FO-BALISES] <équipe> : impulsion à X.X min : N balises, V vitesse,
      P productivité, E efficacité, M mixtes, R recolorées » (R = lumières posées ou recolorées).
  État (données pures) : f.team.balises = { [unit_number] = { id, c } } ; f.team.balises_passe = { t0, todo = { { u, x, y } }, n,
  seen = { [u] = true }, v, p, e, m, r, skipped, logged }. Déterminisme : listes triées, aucun `pairs` décisionnel, aucun temps mesuré.
  La teinte du PROTOTYPE (couches lumineuses des emplacements : prototypes/modules.lua, `beacon_tint.secondary`) reste celle du
  moteur ; cette lumière s'y ajoute (visible surtout la nuit, comme toute lumière du moteur).
  EN : per-beacon light coloured by the module families it holds, refreshed on the scan pulse ; one shared colour table.
]]

local Mt = require("shared.content.modules_teintes")
local BoiteChunks = require("script.team.boite_chunks")
local St = require("shared.team.scan_tranches")
local Profiler = require("script.core.profiler")

local Bt = {}

Bt.CFG = {
  max_per_slice = St.CFG.max_per_slice, -- balises traitées au plus par tranche (garde ; le reste est compté, jamais traité ici)
  sprite = "utility/light_medium",      -- sprite utilitaire du moteur (environ 9,4 tuiles à l'échelle 1)
  scale_per_tile = 0.18,                -- une balise de 3 tuiles → halo d'environ 5 tuiles
  intensity = 0.35,                     -- lueur modérée : la balise reste lisible, la couleur se voit de loin la nuit
  default_width = 3,                    -- largeur (tuiles) si le prototype ne donne pas de boîte de collision
}

local function key_of(f) return tostring(f.key or "player") end

local function new_pass(t0)
  return { t0 = t0, todo = {}, n = 0, seen = {}, v = 0, p = 0, e = 0, m = 0, r = 0, skipped = 0, logged = false }
end

--- Balise visible du jeu (une balise cachée du prototype, la balise des modules multiplicatifs par exemple, n'a pas de lueur).
local function visible(e)
  local p = e.prototype
  if p and p.has_flag and p.has_flag("hidden") then return false end
  return true
end

--- Familles des modules de la balise `e`, lues au prototype de chaque pile (une entrée par module ; sans famille → ignoré).
local function familles(e)
  local inv = e.get_module_inventory and e.get_module_inventory()
  local out = {}
  if not inv then return out end
  for i = 1, #inv do
    local s = inv[i]
    if s and s.valid_for_read then
      local p = game.item_prototypes[s.name]
      local fam = p and Mt.famille(p.module_effect)
      if fam then for _ = 1, (s.count or 1) do out[#out + 1] = fam end end
    end
  end
  return out
end

--- Retire la lumière mémorisée pour la balise `u` (si elle existe encore).
local function retire(t, u)
  local rec = t.balises[u]
  if rec and rec.id and rendering.is_valid(rec.id) then rendering.destroy(rec.id) end
  t.balises[u] = nil
end

--- Largeur (tuiles) de la balise `e` d'après sa boîte de collision.
local function largeur(e)
  local box = e.prototype and e.prototype.collision_box
  if not box or not box.right_bottom or not box.left_top then return Bt.CFG.default_width end
  local w = box.right_bottom.x - box.left_top.x
  if w <= 0 then return Bt.CFG.default_width end
  return w
end

--- Pose ou actualise la lumière de la balise `e` d'après ses modules ; compte dans la passe `h`.
local function colorer(t, h, e)
  local u = e.unit_number
  local fams = familles(e)
  local n = Mt.compte(fams)
  if n.total == 0 then
    if t.balises[u] then retire(t, u) end
    return
  end
  if n.familles > 1 then h.m = h.m + 1
  elseif n.speed > 0 then h.v = h.v + 1
  elseif n.productivity > 0 then h.p = h.p + 1
  else h.e = h.e + 1 end
  local c = Mt.teinte(fams)
  local rec = t.balises[u]
  if rec and rec.id and rendering.is_valid(rec.id) then
    if Mt.meme(rec.c, c) then return end
    rendering.set_color(rec.id, c)
    rec.c = c
  else
    local id = rendering.draw_light({
      sprite = Bt.CFG.sprite, scale = largeur(e) * Bt.CFG.scale_per_tile, intensity = Bt.CFG.intensity,
      color = c, target = e, surface = e.surface,
    })
    t.balises[u] = { id = id, c = c }
  end
  h.r = h.r + 1
end

--- 1. Relevé des balises de la force dans la boîte des chunks : liste triée { u, x, y }, ensemble des unit_number vus ;
--- les lumières des balises absentes du relevé sont retirées. Rend aussi les entités (même tick : utilisables directement).
local function releve(f, surface, t, h)
  local box = BoiteChunks.get(surface)
  local q = { type = "beacon", force = f.force }
  if box then q.area = { { box.x0 * 32, box.y0 * 32 }, { (box.x1 + 1) * 32, (box.y1 + 1) * 32 } } end
  local list, by_u = {}, {}
  for _, e in ipairs(surface.find_entities_filtered(q)) do
    if e.valid and e.unit_number and visible(e) then
      list[#list + 1] = { e.unit_number, e.position.x, e.position.y }
      by_u[e.unit_number] = e
      h.seen[e.unit_number] = true
    end
  end
  table.sort(list, function(a, b) return a[1] < b[1] end)
  h.todo, h.n = list, #list
  local gone = {}
  for u in pairs(t.balises) do if not h.seen[u] then gone[#gone + 1] = u end end
  table.sort(gone)
  for _, u in ipairs(gone) do retire(t, u) end
  return by_u
end

--- Retrouve la balise relevée `rec` = { u, x, y } (une tranche plus tard : l'entité n'est pas mémorisée).
local function retrouver(surface, f, rec)
  for _, e in ipairs(surface.find_entities_filtered({ type = "beacon", position = { rec[2], rec[3] }, force = f.force })) do
    if e.valid and e.unit_number == rec[1] then return e end
  end
  return nil
end

--- Traite les balises d'indices a..b de la liste relevée (entités `by_u` du relevé si même tick, sinon retrouvées à leur position).
local function traiter(f, surface, t, h, a, b, by_u)
  for i = a, b do
    local rec = h.todo[i]
    local e = by_u and by_u[rec[1]] or retrouver(surface, f, rec)
    if e and e.valid then colorer(t, h, e) elseif t.balises[rec[1]] then retire(t, rec[1]) end
  end
end

local function journal(f, h)
  h.logged = true
  if h.n == 0 then return end
  local extra = h.skipped > 0 and string.format(" ; %d non traitées (plafond %d par tranche)", h.skipped, Bt.CFG.max_per_slice) or ""
  log(string.format("[FO-BALISES] %s : impulsion à %.1f min : %d balises, %d vitesse, %d productivité, %d efficacité, %d mixtes, %d recolorées%s",
    key_of(f), h.t0 / 3600, h.n, h.v, h.p, h.e, h.m, h.r, extra))
end

--- Tranche `slice` (0..St.CFG.slices-1) de l'impulsion de l'équipe `f` au tick `tick` (appelée par Hy.step, même cadence).
function Bt.step(f, surface, tick, slice)
  local t = f.team
  if not t or not f.force or not surface or not surface.valid then return end
  t.balises = t.balises or {}
  local t0 = tick - slice
  local h = t.balises_passe
  if slice == 0 or not h or h.t0 ~= t0 then
    if slice ~= 0 then return end -- passe commencée sans relevé (chargement en cours d'impulsion) : on attend la prochaine
    h = new_pass(t0)
    t.balises_passe = h
  end
  if h.logged then return end
  Profiler.fstart("balises:tranche")
  local slices = St.CFG.slices
  if slice == 0 then
    local by_u = releve(f, surface, t, h)
    if h.n <= Bt.CFG.max_per_slice then
      traiter(f, surface, t, h, 1, h.n, by_u)
      journal(f, h)
    else
      local a, b, skipped = St.share_capped(h.n, 0, slices, Bt.CFG.max_per_slice)
      h.skipped = h.skipped + skipped
      traiter(f, surface, t, h, a, b, by_u)
    end
  else
    local a, b, skipped = St.share_capped(h.n, slice, slices, Bt.CFG.max_per_slice)
    h.skipped = h.skipped + skipped
    traiter(f, surface, t, h, a, b, nil)
    if slice == slices - 1 then journal(f, h) end
  end
  Profiler.fstop("balises:tranche")
end

--- Lecture (tests, GUI) : nombre de lumières tenues pour l'équipe `f`.
function Bt.count(f)
  local n = 0
  if f.team and f.team.balises then for _ in pairs(f.team.balises) do n = n + 1 end end
  return n
end

return Bt
