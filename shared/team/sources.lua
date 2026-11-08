--[[
  Lot MINAGE-MAIN (retour du DC du 8/11, 0.6.65, vers 12 h 10) : « ils sont cinq à miner du cuivre par terre alors que ils ont des coffres
  avec des milliers et des milliers [...] de plaques de cuivre » ; « ils sont tous à miner du fer à la main alors qu'ils ont littéralement
  des centaines, des milliers de fer dans les coffres de la fonderie » ; sa méthode : « Savoir que c'est un output, c'est déjà qu'il y a un
  bras robotisé qui récupère des ressources [...] et qui le met dans un coffre et ce coffre-là, il n'y a pas de sortie de ce coffre. »

  Règles PURES (aucune API Factorio, aucun nom d'objet : les ressources et leurs plaques arrivent en DONNÉES, lues par l'appelant dans
  shared/team/config.lua ; tests/sources_test.lua). L'exécution est script/team/sources.lua.

  1. REGISTRE des coffres, tenu à jour par ÉVÉNEMENTS (pose, retrait, rotation d'un bras ou d'une foreuse), jamais par balayage de la carte :
       un coffre est une SORTIE quand quelque chose y dépose (bras, foreuse) et qu'AUCUN bras n'en retire ; une ENTRÉE dans le cas inverse ;
       un RELAIS (dépose et retire) ou un coffre NEUTRE (ni l'un ni l'autre) ne compte pour rien.
       S.new / S.add_chest / S.remove_chest / S.link / S.unlink / S.kind / S.sorties.
  2. CONTENU des sorties : relu par tranches (S.read_batch), seuls les objets suivis sont gardés ; la montée du contenu est datée
       (S.set_content, champ `grew`) : une sortie dont le contenu monte est « en marche ».
  3. DÉCISION d'une ressource (S.decide) : prendre à la sortie la plus proche du coffre d'équipe qui en tient S.MIN au moins ; sinon attendre
       une sortie en marche ; sinon, et seulement alors, extraire à la main, avec la CAUSE écrite (aucune sortie, sortie vide, sortie
       dangereuse, tournée en pause).
  4. OBJETS ATTENDUS (S.fetchable) : ce que les tournées ramèneront, à ajouter à `view.incoming` du cerveau, jamais au stock libre (une prise
       stricte au coffre échouerait) ; et, pour une plaque promise, la tournée existe (même règle, même sortie).
  Déterminisme : aucune décision selon l'ordre de pairs (listes triées), aucune mesure de temps (le tick arrive en argument).
]]

local S = {}

S.MIN = 20            -- objets d'une sortie à partir desquels on va les chercher plutôt que miner à la main
S.TRIP_MAX = 2000     -- objets pris au plus par tournée (une tournée perdue ne perd pas toute la sortie)
S.PRIO = 89           -- sous M.URGENT (90) : ni ruée ni préemption (Rappel.stops), mais devant le minage (85 au plus) et la collecte du plan (52)
S.LIVE_TICKS = 5 * 3600 -- le contenu d'une sortie a monté depuis moins de 5 min : elle est « en marche »
S.PLATE_COVER = 500   -- plaques (produit) au stock d'équipe (coffre + annexes, brut) au-delà desquelles on ne mine plus leur minerai à la main
S.ORE_MIN = 50        -- minerai au stock : comme Mi.hand_verdict (max(S.ORE_MIN, 2 × la fournée))
S.READ_PER_THINK = 12 -- sorties relues au plus par pensée d'équipe
S.SCAN_PER_THINK = 40 -- coffres étudiés au plus par pensée pendant la reprise d'une sauvegarde d'avant le lot

---------------------------------------------------------------------------------------------------
-- 1. Registre
---------------------------------------------------------------------------------------------------
--- Registre vide. chests[uid] = { ent (opaque), x, y, feed = { [uid de bras] = true }, take = {...}, nf, nt, decl, n = { [objet] = n }, grew = { [objet] = tick }, read }
--- ins[uid de bras] = { feed = uid de coffre | nil, take = uid de coffre | nil }.
function S.new()
  return { chests = {}, ins = {}, nchests = 0, cursor = 0, todo = nil, scanned = false }
end

--- Ajoute (ou rend) l'enregistrement d'un coffre. `ent` est opaque pour cette règle.
function S.add_chest(reg, uid, ent, x, y)
  local c = reg.chests[uid]
  if c then
    c.ent, c.x, c.y = ent, x or c.x, y or c.y
    return c
  end
  c = { ent = ent, x = x or 0, y = y or 0, feed = {}, take = {}, nf = 0, nt = 0, n = {}, grew = {} }
  reg.chests[uid] = c
  reg.nchests = reg.nchests + 1
  return c
end

local function unlink_role(reg, iuid, role)
  local link = reg.ins[iuid]
  local cuid = link and link[role]
  if not cuid then return end
  link[role] = nil
  local c = reg.chests[cuid]
  if c then
    local set = role == "feed" and c.feed or c.take
    if set[iuid] then
      set[iuid] = nil
      if role == "feed" then c.nf = c.nf - 1 else c.nt = c.nt - 1 end
    end
  end
  if link.feed == nil and link.take == nil then reg.ins[iuid] = nil end
end

--- Un bras (ou une foreuse) dépose dans le coffre `cuid` (role "feed") ou en retire (role "take"). Le lien précédent du même rôle est défait.
--- Rend faux quand le coffre est inconnu (le lien n'est pas posé).
function S.link(reg, iuid, role, cuid)
  if role ~= "feed" and role ~= "take" then return false end
  local c = reg.chests[cuid]
  if not c then return false end
  local link = reg.ins[iuid]
  if link and link[role] == cuid then return true end
  unlink_role(reg, iuid, role)
  link = reg.ins[iuid] or {}
  reg.ins[iuid] = link
  link[role] = cuid
  local set = role == "feed" and c.feed or c.take
  set[iuid] = true
  if role == "feed" then c.nf = c.nf + 1 else c.nt = c.nt + 1 end
  return true
end

--- Défait les deux liens d'un bras (retiré, tourné, détruit).
function S.unlink(reg, iuid)
  unlink_role(reg, iuid, "feed")
  unlink_role(reg, iuid, "take")
end

--- Retire un coffre et ses liens (les bras restent connus ailleurs, s'ils en ont un autre).
function S.remove_chest(reg, cuid)
  local c = reg.chests[cuid]
  if not c then return false end
  local ids = {}
  for iuid in pairs(c.feed) do ids[#ids + 1] = iuid end
  for iuid in pairs(c.take) do ids[#ids + 1] = iuid end
  table.sort(ids)
  for _, iuid in ipairs(ids) do
    local link = reg.ins[iuid]
    if link then
      if link.feed == cuid then link.feed = nil end
      if link.take == cuid then link.take = nil end
      if link.feed == nil and link.take == nil then reg.ins[iuid] = nil end
    end
  end
  reg.chests[cuid] = nil
  reg.nchests = reg.nchests - 1
  return true
end

--- Classe un coffre d'après le nombre de déposants (nf) et de retirants (nt).
function S.classify(nf, nt)
  if nf > 0 and nt == 0 then return "sortie" end
  if nt > 0 and nf == 0 then return "entree" end
  if nf > 0 and nt > 0 then return "relais" end
  return "neutre"
end

--- Genre d'un coffre du registre ; nil si inconnu. Un coffre DÉCLARÉ (sortie d'un projet du plan directeur : le plan y dépose par
--- construction) compte au moins un déposant.
function S.kind(reg, cuid)
  local c = reg.chests[cuid]
  if not c then return nil end
  local nf = c.nf
  if c.decl and nf == 0 then nf = 1 end
  return S.classify(nf, c.nt)
end

--- Identifiants des sorties, triés.
function S.sorties(reg)
  local out = {}
  for cuid in pairs(reg.chests) do
    if S.kind(reg, cuid) == "sortie" then out[#out + 1] = cuid end
  end
  table.sort(out)
  return out
end

---------------------------------------------------------------------------------------------------
-- 2. Contenu, relu par tranches
---------------------------------------------------------------------------------------------------
--- Enregistre le contenu relu d'un coffre (seuls les objets de `tracked` = { [objet] = true } sont gardés). Rend vrai si un objet suivi a MONTÉ.
--- Débits (par minute, nil à la première lecture) : c.rin[objet] = ce qui est ENTRÉ (hausse du contenu + ce que les tournées ont retiré, S.note_removed),
--- c.rout[objet] = ce qui est SORTI sans nous (baisse du contenu moins ce que les tournées ont retiré).
function S.set_content(reg, cuid, items, tracked, tick)
  local c = reg.chests[cuid]
  if not c then return false end
  local new, grew = {}, false
  local names = {}
  for item in pairs(tracked) do names[#names + 1] = item end
  table.sort(names)
  local dt = c.read ~= nil and (tick - c.read) or 0
  local rin, rout = nil, nil
  if dt > 0 then rin, rout = {}, {} end
  for _, item in ipairs(names) do
    local n = items[item]
    n = (type(n) == "number" and n > 0) and n or 0
    local old = c.n[item] or 0
    if n > 0 then new[item] = n end
    if n > old and c.read ~= nil then
      c.grew[item] = tick
      grew = true
    end
    if rin then
      local removed = (c.removed and c.removed[item]) or 0
      local delta = n - old + removed
      if delta > 0 then rin[item] = delta * 3600 / dt end
      local out = old - n - removed
      if out > 0 then rout[item] = out * 3600 / dt end
    end
  end
  c.n = new
  c.read = tick
  c.removed = nil
  if rin then c.rin, c.rout = rin, rout end
  return grew
end

--- Une tournée a retiré `n` de `item` du coffre (hors du débit mesuré).
function S.note_removed(reg, cuid, item, n)
  local c = reg.chests[cuid]
  if not c or n <= 0 then return end
  c.removed = c.removed or {}
  c.removed[item] = (c.removed[item] or 0) + n
end

--- Identifiants des coffres à relire : sorties et entrées (le contenu des entrées donne la consommation), triés.
function S.readable(reg)
  local out = {}
  for cuid in pairs(reg.chests) do
    local k = S.kind(reg, cuid)
    if k == "sortie" or k == "entree" then out[#out + 1] = cuid end
  end
  table.sort(out)
  return out
end

--- Prochaine tranche de coffres à relire : au plus `batch` sorties ou entrées, par ordre croissant d'identifiant après le curseur (circulaire).
--- Le curseur avance ; rend la liste.
function S.read_batch(reg, batch)
  local ids = S.readable(reg)
  if #ids == 0 then return {} end
  local out = {}
  local start = 1 -- première sortie après le curseur, sinon retour au début
  for i, id in ipairs(ids) do
    if id > reg.cursor then start = i break end
  end
  for k = 0, math.min(batch, #ids) - 1 do
    local id = ids[((start - 1 + k) % #ids) + 1]
    out[#out + 1] = id
    reg.cursor = id
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- 3. Décision
---------------------------------------------------------------------------------------------------
local function d2(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return dx * dx + dy * dy
end

--- Sorties qui tiennent (ou font monter) `item`, de la plus proche du point `at` = { x, y } (le coffre d'équipe) à la plus lointaine
--- (égalité : identifiant). `skip(uid)` écarte un coffre (coffre d'équipe, annexe, sortie d'un avant-poste déjà comptée ailleurs).
--- Rend des rangées { uid, x, y, n, grew, d2 }.
function S.rows(reg, item, at, skip)
  local rows = {}
  for _, cuid in ipairs(S.sorties(reg)) do
    if not (skip and skip(cuid)) then
      local c = reg.chests[cuid]
      local n = c.n[item] or 0
      local grew = c.grew[item]
      if n > 0 or grew then
        rows[#rows + 1] = { uid = cuid, x = c.x, y = c.y, n = n, grew = grew, d2 = d2(c.x, c.y, at.x, at.y) }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.d2 ~= b.d2 then return a.d2 < b.d2 end
    return a.uid < b.uid
  end)
  return rows
end

--- a = { rows (S.rows), pause(uid) -> vrai si la tournée de cette sortie est en pause après un échec, safe(uid) -> faux si danger,
---       now = tick, crisis = vrai pour une crise injectée par un banc }.
--- Rend { act = "fetch", row, n } | { act = "wait", row } | { act = "hand", why }.
function S.decide(a)
  if a.crisis then return { act = "hand", why = "crise", code = S.CODES["crise"] } end
  local best, live
  local saw_rich, unsafe, paused, any = false, false, false, false
  for _, r in ipairs(a.rows or {}) do
    any = true
    local rich = r.n >= S.MIN
    if rich then saw_rich = true end
    if not a.safe(r.uid) then
      if rich then unsafe = true end
    elseif a.pause(r.uid) then
      if rich then paused = true end
    elseif rich then
      best = best or r
    elseif r.grew and a.now - r.grew <= S.LIVE_TICKS then
      live = live or r
    end
  end
  if best then return { act = "fetch", row = best, n = math.min(best.n, S.TRIP_MAX) } end
  if live then return { act = "wait", row = live } end
  local why
  if unsafe then why = "sortie dangereuse"
  elseif paused then why = "tournee en pause apres un echec"
  elseif saw_rich or any then why = "sorties vides"
  else why = "aucune sortie" end
  return { act = "hand", why = why, code = S.CODES[why] }
end

--- Mots FIXES de la cause (état sérialisable lu par la vue du cerveau : jamais un texte libre).
S.CODES = { ["sortie dangereuse"] = "sortie_dangereuse", ["tournee en pause apres un echec"] = "tournee_en_pause", ["sorties vides"] = "sorties_vides",
  ["aucune sortie"] = "aucune_sortie", ["crise"] = "crise" }

--- Le stock d'équipe couvre-t-il déjà ce minage ? a = { ore = minerai au stock (brut, coffre + annexes), plate = produit au stock (nil : ressource
--- brute), count = fournée de la tâche }. Quelle que soit la raison comptable (réservation, saturation, manque mesuré), le minage à la main
--- n'est pas fait pour ce qui dort au stock : minerai au moins max(S.ORE_MIN, 2 × la fournée), ou S.PLATE_COVER plaques.
--- Rend vrai, "minerai" | "plaques" ; sinon faux.
function S.stock_covers(a)
  local count = a.count or 0
  local need = math.max(S.ORE_MIN, 2 * count)
  if (a.ore or 0) >= need then return true, "minerai" end
  if a.plate ~= nil and a.plate >= S.PLATE_COVER then return true, "plaques" end
  return false
end

--- Le minage à la main est-il permis ? (aucune sortie ne peut fournir : ni prise, ni attente d'une sortie en marche).
function S.hand_ok(decision) return decision.act == "hand" end

---------------------------------------------------------------------------------------------------
-- 4. Objets attendus
---------------------------------------------------------------------------------------------------
--- Total que les tournées ramèneront de `rows` (sorties sûres, tournée non en pause, au moins S.MIN), borné par `room` (place au coffre ; nil :
--- pas de borne). Une sortie à moins de S.MIN n'est pas attendue.
function S.fetchable(rows, safe, pause, room)
  local total = 0
  for _, r in ipairs(rows or {}) do
    if r.n >= S.MIN and safe(r.uid) and not pause(r.uid) then total = total + r.n end
  end
  if room ~= nil and total > room then total = room end
  return total
end

---------------------------------------------------------------------------------------------------
-- 5. Données : ressources suivies
---------------------------------------------------------------------------------------------------
--- spec = T.outposts, inputs = T.smelter_inputs ({ produit = { entrée, quantité } }), order = T.OUTPOST_ORDER.
--- Rend la liste { res, item, plate } dans l'ordre des types : `item` est ce qu'on va chercher (la plaque quand le minerai se fond, sinon
--- la ressource elle-même), `plate` vrai quand c'est une plaque fondue.
function S.targets(spec, inputs, order)
  local out, seen = {}, {}
  for _, kind in ipairs(order or {}) do
    local s = spec[kind]
    if s and s.resource and not seen[s.resource] then
      seen[s.resource] = true
      local input = inputs and inputs[s.product]
      if input and input[1] == s.resource then
        out[#out + 1] = { res = s.resource, item = s.product, plate = true }
      elseif s.product == s.resource then
        out[#out + 1] = { res = s.resource, item = s.resource, plate = false }
      end
    end
  end
  return out
end

--- Objets suivis dans les coffres : la ressource et son produit, { [objet] = true }.
function S.tracked(targets)
  local t = {}
  for _, x in ipairs(targets) do
    t[x.res] = true
    t[x.item] = true
  end
  return t
end

return S
