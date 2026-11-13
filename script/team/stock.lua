--[[
  STOCK d'une équipe = coffre du QG + ANNEXES (lot COFFRE, constat du DC du 27/10, 18 h 50 : coffre plein « depuis un bon
  moment », jamais vidé, jamais d'autre coffre). Règles pures : shared/team/annexe.lua ; données : T.annex.

  Toute lecture, prise et dépôt du stock passe par ici (le coffre du QG d'abord, puis les annexes) : un ouvrier, le cerveau
  ou une amélioration ne voit jamais la différence entre un objet du coffre et un objet d'une annexe. Sans annexe, chaque
  fonction est EXACTEMENT l'appel au coffre du QG d'avant (f.hq).

    Stock.count(f, item) / Stock.remove(f, item, n) / Stock.insert(f, item, n) / Stock.contents(f) / Stock.inventories(f)
    Stock.balance(f)          range l'excédent du coffre du QG aux annexes (piles entières) quand il dépasse T.annex.park_at ;
    Stock.grow(f, surface)    pose un coffre du stock (bloc T.annex.block, côté extérieur) quand les cases se remplissent, ou
                              PAR ANTICIPATION (lot STOCKAGE : stock à 60 % pendant 5 min, ou dépôt refusé) ; pose aussi les
                              fours DORMANTS de votre équipe au QG (Stock.deploy_idle, lot ADOPTE) ;
    Stock.wanted(f)           coffres à avoir en main (fabrication de fond) : pour Fond.candidates.
  f.annex = liste d'entités (le coffre détruit par un ennemi est retiré de la liste, son contenu est perdu).
  f.stock_watch = { since, retry } et f.refused_at (nombres seuls) : fenêtre d'agrandissement régulier (shared/team/annexe.lua) ;
  f.annex_sy = face du bloc (+1 sud, -1 nord), fixée à la première pose : une partie d'avant (annexes au sud) garde le sud.
]]

local T = require("shared.team.config")
local A = require("shared.team.annexe")
local Sg = require("shared.team.stockage") -- lot STOCKAGE-VITAL : réserve des matières vitales, ramassage, coffre urgent
local Pl = require("shared.ai3.places")
local Plan = require("shared.team.plan") -- lot STOCKAGE-VITAL (a) : clé de tuile du plan directeur (f.build.occ), projet d'une entité bloquante
local PlacesQG = require("script.ai3.places_qg")
local Br = require("shared.ai3.bras")
local Ad = require("shared.team.adopte")
local Profiler = require("script.core.profiler") -- lot X10-S0 : compteurs d'appels (mode detail du profileur seulement, mesure)
local FQ = require("shared.ai3.fonderie_qg") -- lot PD-FONDERIEQG (D77) : fonderie du QG bornée par l'automatisation
local Pqs = require("script.team.plafond_qg") -- lot STOCK-QG : plafonds de rapatriement au QG par catégorie d'objet (brut, base, déclassé)
local RegT = require("script.team.registre_types") -- lot UPS : registre des machines par force et par type (plus de recherche sur toute la surface)

-- Entrées de la fonderie du QG, triées (données de shared/team/config.lua), pour FQ.automated.
local SMELT_INPUTS = {}
do
  local ps = {}
  for p in pairs(T.smelter_inputs) do ps[#ps + 1] = p end
  table.sort(ps)
  for _, p in ipairs(ps) do SMELT_INPUTS[#SMELT_INPUTS + 1] = { p, T.smelter_inputs[p][1], T.smelter_inputs[p][2] } end
end

local Stock = {}

-- Lot X10-S0 (demande de charbonmain pour le lot S1, 7/11) : APPELS AU MOTEUR du stock, comptés AUX SITES D'APPEL (pas à l'entrée des
-- fonctions : un appel servi plus tard par un mémo ne touchera pas le moteur et ne doit pas compter). count : get_item_count ;
-- contents : get_inventory et get_contents ; annexes : lectures de .valid ; place (demande de charbonmain, 8/11 : lectures de place de
-- STOCKAGE-VITAL) : get_inventory, count_empty_stacks et get_insertable_count de Stock.inventories, Stock.room, Stock.can_take,
-- Stock.fill (totals), Stock.balance, du dépôt d'une non vitale (non_vital_plan) et de la poche d'un PNJ (Stock.note_claim). Un coffre
-- du moteur simulé sans ces fonctions n'est pas compté. Mesure seulement, jamais lue par une décision : table du module (jamais dans
-- global), tenue en mode fin du profileur seulement ; en mode détail, aussi écrite en compteurs « #stock:… » à la fin des lignes
-- [FO-PERF3-T].
Stock.engine_calls = { count = 0, contents = 0, annexes = 0, place = 0 }
local EC_NAME = { count = "stock:count", contents = "stock:contents", annexes = "stock:annexes", place = "stock:place" }
local function ec(kind, n)
  if Profiler.fine() then
    local t = Stock.engine_calls
    t[kind] = t[kind] + n
    Profiler.fcount(EC_NAME[kind], n)
  end
end

-- Lot STOCKAGE-VITAL : matières vitales { [objet] = true } (T.stock_vital : fer et charbon des avant-postes).
local VITAL = {}
for _, it in ipairs(T.stock_vital or {}) do VITAL[it] = true end
Stock.VITAL = VITAL
-- Lot STOCKAGE-VITAL : coffres des annexes { [objet] = true } : un coffre est du stockage, il entre dans la réserve des vitales, et un
-- coffre refusé au dépôt (stock plein) est posé en annexe sur-le-champ (place_held).
local ANNEX = {}
for _, k in ipairs(T.annex.kinds) do ANNEX[k.item] = true end
function Stock.ANNEX_ITEM(item) return ANNEX[item] == true end
Stock.REFUSED_LOG = 3600 -- ticks entre deux lignes « dépôt refusé » d'une équipe
Stock.COUNT_LOG = 3600    -- fenêtre des deux compteurs (dépôts refusés, poches pleines) : une ligne chacun par fenêtre au plus
Stock.POCKET_FULL = 0.90  -- poche « pleine » à la prise de tâche : cases prises / cases de l'inventaire principal

--- Lot STOCKAGE-VITAL (demande du lead, 7/11 : « un PNJ qui réessaie sans fin est un PNJ perdu ») : compteur des dépôts REFUSÉS d'un
--- PNJ (Stock.insert avec opts.reserve, script/team/worker.lua) dans la fenêtre courante : appels refusés (un objet d'un dépôt),
--- passages au QG (ticks distincts : un dépôt vide la poche en un tick) et objets refusés. f.stock_refused_win, tolérant à nil.
local function count_refused(f, k, tick)
  local c = f.stock_refused_win
  if not c then
    c = { since = tick, calls = 0, visits = 0, items = 0 }
    f.stock_refused_win = c
  end
  c.calls, c.items = c.calls + 1, c.items + k
  if c.last ~= tick then c.visits, c.last = c.visits + 1, tick end
  f.stats = f.stats or {}
  f.stats.refused_calls = (f.stats.refused_calls or 0) + 1
end

--- Lot STOCKAGE-VITAL : prise de tâche d'un PNJ (script/team/worker.lua, après Board.claim) : compte les prises dont l'inventaire
--- principal est plein à Stock.POCKET_FULL ou plus (le PNJ part avec une poche qu'il ne peut plus remplir). f.stock_claim_win.
function Stock.note_claim(f, inv, tick)
  if not (inv and inv.count_empty_stacks) then return end
  local size = #inv
  if size <= 0 then return end
  local c = f.stock_claim_win
  if not c then
    c = { since = tick, n = 0, full = 0 }
    f.stock_claim_win = c
  end
  c.n = c.n + 1
  f.stats = f.stats or {}
  f.stats.claims = (f.stats.claims or 0) + 1 -- cumul (banc stockage-sol-dc : la fenêtre d'une minute dépasse un banc de 3 700 ticks)
  ec("place", 1) -- count_empty_stacks de la poche
  if size - inv.count_empty_stacks() >= Stock.POCKET_FULL * size then
    c.full = c.full + 1
    f.stats = f.stats or {}
    f.stats.claim_full = (f.stats.claim_full or 0) + 1
  end
end

--- Fin de fenêtre des deux compteurs (Stock.grow, à chaque passage du stock) : une ligne [FO-STOCKAGE] chacun s'il a compté quelque chose.
local function flush_counts(f, tick)
  local c = f.stock_refused_win
  if c and tick - c.since >= Stock.COUNT_LOG then
    if c.calls > 0 then
      log(string.format("[FO-STOCKAGE] %s : depots refuses de PNJ : %d passage(s) au QG, %d objet(s) d'un depot refuse(s), %d objet(s) refuse(s), sur %.1f min a %.1f min",
        f.key or "player", c.visits, c.calls, c.items, (tick - c.since) / 3600, (tick - (f.started or 0)) / 3600))
    end
    f.stock_refused_win = nil
  end
  local q = f.stock_claim_win
  if q and tick - q.since >= Stock.COUNT_LOG then
    if q.full > 0 then
      log(string.format("[FO-STOCKAGE] %s : poches pleines : %d prise(s) de tache sur %d avec la poche pleine a %d %% ou plus, sur %.1f min a %.1f min",
        f.key or "player", q.full, q.n, math.floor(Stock.POCKET_FULL * 100 + 0.5), (tick - q.since) / 3600, (tick - (f.started or 0)) / 3600))
    end
    f.stock_claim_win = nil
  end
end
local place_held -- (défini plus bas : il lit l'emprise et la face du bloc des annexes)

-- Minerai et plaque de chaque avant-poste (Sg.demanded : une plaque demandée garde son minerai au minage à la main, et l'inverse).
local LINKS = {}
for _, k in ipairs(T.OUTPOST_ORDER) do LINKS[#LINKS + 1] = { T.outposts[k].resource, T.outposts[k].product } end

Stock.RESV_EVERY = 60 -- C1 : relecture des manques des projets en réserve (ticks)

--- C1 de DIAG_CONSO (7/11) : manques des projets du plan directeur en état « reserve » (p.missing : ce que le stock libre ne leur fournit
--- pas ; vide pour une réserve suspendue par la pile ou le QG), sommés par objet (Sg.reserve_need) et relus au plus toutes les
--- Stock.RESV_EVERY ticks (f.stock_resv, tolérant à nil). Rend false sans plan directeur.
local function reserve_need(f)
  local b = f.build
  if not (b and b.order and b.projects) then return false end
  local tick = (game and game.tick) or 0
  local c = f.stock_resv
  if c and tick >= c.at and tick - c.at < Stock.RESV_EVERY then return c.agg end
  local lists = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and (p.state == "reserve" or p.progressif) and not p.abandoned and p.missing and #p.missing > 0 then lists[#lists + 1] = p.missing end -- (p.progressif : bande partie sans toute sa matière)
  end
  local agg = Sg.reserve_need(lists)
  f.stock_resv = { at = tick, agg = agg }
  return agg
end

--- Lot STOCKAGE-VITAL : matières que l'équipe demande en ce moment { [objet] = q } (manque mesuré du cerveau, manque de l'objectif
--- courant ; nets du stock) : reçues au dépôt jusqu'à q (Stock.insert). Rend aussi les deux tables sources de la pensée
--- (Sg.demand_room compte le dépôt par pensée). Avec `all` (Stock.skip_fn), les manques des projets en réserve comptent aussi (C1) :
--- jamais écartés du ramassage.
local function demanded(f, all)
  local team = f.team
  local ia3 = team and team.ia3
  return Sg.demanded(ia3 and ia3.short, team and team.missing, LINKS, all and reserve_need(f) or nil), ia3 and ia3.short or false,
    team and team.missing or false
end

--- Annexes valides (la liste est purgée des entités disparues).
function Stock.annexes(f)
  local a = f.annex
  if not a or #a == 0 then return {} end
  ec("annexes", #a) -- #a lectures de .valid
  local out = {}
  for _, e in ipairs(a) do
    if e.valid then out[#out + 1] = e end
  end
  if #out ~= #a then f.annex = out end
  return out
end

local function chest_inv(e) return e.get_inventory(defines.inventory.chest) end

function Stock.count(f, item)
  local n = f.hq.get_item_count(item)
  local annex = Stock.annexes(f)
  ec("count", 1 + #annex)
  for _, e in ipairs(annex) do n = n + e.get_item_count(item) end
  return n
end

-- DIAGNOSTIC (lot DEFENSE-AP, journal seul, aucune décision ne le lit) : où va la plaque de fer de votre équipe ? Chaque retrait
-- est compté par minute sous « fichier:ligne de l'appelant » et la tâche en cours (`Stock.ctx`, posée par Worker au pas « take »).
-- Compteur de module (jamais dans `global`) : une session rechargée repart de zéro, sans effet sur le jeu.
-- Lot CC-COMBUSTIBLE (diagnostic, journal seul) : meme compte pour le combustible, ligne [FO-CHARBON-SORTIE] (ou va le charbon du
-- coffre pendant que les bruleurs des avant-postes restent a sec : partie du DC du 10/11, graine 3592985581).
local FER = { acc = {}, minute = nil, tag = "[FO-FER-SORTIE] %s minute %d : %d plaque(s) de fer sorties du coffre | %s" }
local CHB = { acc = {}, minute = nil, tag = "[FO-CHARBON-SORTIE] %s minute %d : %d charbon(s) sortis du coffre | %s" }
local function fer_flush(f, minute, D)
  D = D or FER
  local rows = {}
  for k, v in pairs(D.acc) do rows[#rows + 1] = { k = k, n = v } end
  table.sort(rows, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.k < b.k end)
  local out, tot = {}, 0
  for i, r in ipairs(rows) do
    tot = tot + r.n
    if i <= 8 then out[#out + 1] = r.k .. "=" .. r.n end
  end
  if tot > 0 then
    log(string.format(D.tag, f.key or "player", minute, tot, table.concat(out, " ; ")))
  end
  D.acc = {}
end
local function fer_note(f, item, got)
  if got <= 0 or (f.key and f.key ~= "player") then return end
  local D = (item == T.outposts.iron.product and FER) or (item == T.fuel and CHB) or nil
  if not D then return end
  local minute = math.floor(game.tick / 3600)
  if D.minute and minute ~= D.minute then fer_flush(f, D.minute, D) end
  D.minute = minute
  local info = debug.getinfo(3, "Sl")
  local at = info and (((info.short_src or "?"):gsub("^.*[/\\]", "")) .. ":" .. (info.currentline or 0)) or "?"
  local k = at .. "/" .. (Stock.ctx or "-")
  D.acc[k] = (D.acc[k] or 0) + got
end

--- Retire jusqu'à `n` objets (coffre du QG d'abord) ; rend le nombre retiré.
function Stock.remove(f, item, n)
  local got = f.hq.remove_item({ name = item, count = n })
  if got < n then
    for _, e in ipairs(Stock.annexes(f)) do
      got = got + e.remove_item({ name = item, count = n - got })
      if got >= n then break end
    end
  end
  fer_note(f, item, got)
  return got
end

-- Tailles de pile lues aux prototypes (constantes pendant une partie ; cache du module, jamais dans `global`).
local STACK_OF = {}
local function stack_of(item)
  local s = STACK_OF[item]
  if s then return s end
  local protos = game and game.item_prototypes
  local proto = protos and protos[item]
  if not proto then return nil end
  s = proto.stack_size or 50
  STACK_OF[item] = s
  return s
end

--- Lot STOCKAGE-VITAL : plan de dépôt d'une matière NON vitale quand la réserve des vitales mord. La réserve ne vaut que pour le COFFRE
--- DU QG (décision du lead, 7/11 : « réserve au seul coffre du QG, les annexes prennent les non vitales tant qu'elles ont de la place ») :
--- Sg.new_stacks sur ses seules cases. Rend les coffres dans l'ordre du dépôt (QG puis annexes), la place de leurs piles entamées et
--- leurs cases neuves permises (le QG au-delà de sa réserve, une annexe toutes ses cases vides) ; nil quand la réserve du QG ne mord
--- pas, quand tout le dépôt tient dans les piles entamées du coffre du QG (sortie tôt : aucune annexe lue), ou quand l'inventaire ne
--- se lit pas (moteur simulé).
local function non_vital_plan(f, item, n)
  local stack = stack_of(item)
  if not stack then return nil end
  if not f.hq.get_inventory then return nil end -- coffre simulé sans inventaire (tests hors jeu)
  local hq_inv = chest_inv(f.hq)
  if not (hq_inv.count_empty_stacks and hq_inv.get_insertable_count) then return nil end
  local em = hq_inv.count_empty_stacks()
  local p = math.max(0, hq_inv.get_insertable_count(item) - em * stack)
  ec("place", 3) -- get_inventory, count_empty_stacks et get_insertable_count du coffre du QG
  if p >= n then return nil end -- sortie tôt : le dépôt tient dans les piles entamées du coffre du QG
  local allowed = Sg.new_stacks(item, em, #hq_inv, VITAL, T.stockage)
  if allowed >= em then return nil end -- la réserve du QG ne mord pas : dépôt ordinaire
  local ents, parts, news = { f.hq }, { p }, { allowed * stack }
  for _, e in ipairs(Stock.annexes(f)) do
    local inv = chest_inv(e)
    if not (inv.count_empty_stacks and inv.get_insertable_count) then return nil end
    local ae = inv.count_empty_stacks()
    ents[#ents + 1] = e
    parts[#parts + 1] = math.max(0, inv.get_insertable_count(item) - ae * stack)
    ec("place", 3) -- les mêmes, d'une annexe
    news[#news + 1] = ae * stack
  end
  return { ents = ents, parts = parts, news = news }
end

-- Cases prises et cases du coffre du QG, puis du total.
local function slots_of(inv)
  local size = #inv
  ec("place", 1) -- count_empty_stacks
  return size - inv.count_empty_stacks(), size
end

local function totals(f)
  local used, size = slots_of(chest_inv(f.hq))
  local annex = Stock.annexes(f)
  ec("place", 1 + #annex) -- get_inventory du coffre du QG et de chaque annexe
  for _, e in ipairs(annex) do
    local u, s = slots_of(chest_inv(e))
    used, size = used + u, size + s
  end
  return used, size, #annex
end

--- Lot STOCKAGE-VITAL : cases prises, cases et annexes du stock (0, 0, 0 sans inventaire lisible : moteur simulé).
function Stock.fill(f)
  if not (f.hq and f.hq.valid and f.hq.get_inventory) then return 0, 0, 0 end
  return totals(f)
end

-- Dépôt ordinaire de `k` objets : coffre du QG d'abord, puis les annexes (sans réserve). Rend le nombre déposé.
local function plain_insert(f, item, k)
  local put = k > 0 and f.hq.insert({ name = item, count = k }) or 0
  if put < k then
    for _, e in ipairs(Stock.annexes(f)) do
      put = put + e.insert({ name = item, count = k - put })
      if put >= k then break end
    end
  end
  return put
end

--- Dépose jusqu'à `n` objets (coffre du QG d'abord, puis les annexes) ; rend le nombre déposé.
--- opts.reserve (lot STOCKAGE-VITAL) : la réserve des vitales s'applique (une matière non vitale ne prend pas les dernières cases).
--- SEUL le dépôt d'un PNJ au QG la demande (script/team/worker.lua, deposit_inventory : ce qui est refusé reste en poche). Tout autre
--- appelant (remboursement d'un script, retour d'une prise, rangement) garde l'ancien chemin : relecture revue-0659 du 7/11, un objet
--- non vital pris puis rendu tombait sur une case libérée DANS la réserve, était refusé, et l'appelant qui ignore le retour le perdait.
--- Une matière DEMANDÉE en ce moment entre dans la réserve comme une vitale, jusqu'à la quantité demandée (relecture revue-0659, D1).
function Stock.insert(f, item, n, opts)
  local want, put = n, 0
  local plan = opts and opts.reserve and not VITAL[item] and not ANNEX[item] and non_vital_plan(f, item, n) or nil
  if plan then
    -- Les piles entamées d'abord, coffre par coffre (un dépôt du moteur remplit les piles avant les cases vides : déposer d'un bloc au
    -- coffre du QG prenait ses cases vides même quand la place était dans les piles d'une annexe), puis les cases neuves : les annexes
    -- d'abord, le coffre du QG en dernier, au-delà de sa réserve seulement.
    local room = 0
    for i = 1, #plan.ents do room = room + plan.parts[i] + plan.news[i] end
    want = math.min(n, room)
    for i, e in ipairs(plan.ents) do
      local k = math.min(want - put, plan.parts[i])
      if k > 0 then put = put + e.insert({ name = item, count = k }) end
    end
    for i = 2, #plan.ents + 1 do
      local j = i <= #plan.ents and i or 1 -- annexes 2..N, puis le QG (1)
      local k = math.min(want - put, plan.news[j])
      if k > 0 then put = put + plan.ents[j].insert({ name = item, count = k }) end
    end
    -- Relecture revue-0659 (D1) : une matière DEMANDÉE (Stock.skip_fn la laisse ramasser et miner) prend la réserve comme une vitale,
    -- au plus la quantité demandée (f.stock_dem[objet], Sg.demand_room) : refusée, elle restait en poche et la demande, nette du stock,
    -- ne baissait jamais.
    if put < n then
      local need, src_s, src_m = demanded(f)
      local room, rec = Sg.demand_room(f.stock_dem and f.stock_dem[item], need[item], src_s, src_m)
      -- C1 de DIAG_CONSO (7/11) : un objet qui MANQUE à un projet en réserve (hors projet dominant : modules 94 à 98 de la partie du DC)
      -- entre aussi, jusqu'à ce manque moins ce que le stock en tient déjà (Sg.resv_room : la réserve le reprend au stock)
      local resv = reserve_need(f)
      local rq = resv and resv[item]
      local rroom = rq and Sg.resv_room(rq, Stock.count(f, item)) or 0
      local k = math.min(n - put, math.max(room, rroom))
      if k > 0 then
        local got = plain_insert(f, item, k)
        put, want = put + got, want + got
        if rec and room > 0 then rec.used = rec.used + math.min(got, room) end
      end
      if rec then
        f.stock_dem = f.stock_dem or {}
        f.stock_dem[item] = rec
      end
    end
  else
    put = plain_insert(f, item, want)
  end
  -- Lot STOCKAGE-VITAL : un coffre que le stock plein refuse est posé en annexe (le PNJ qui le porte ne le garde pas en poche).
  if put < n and ANNEX[item] then put = put + place_held(f, item, n - put) end
  -- Lot STOCK-QG : ce qui entre hors objets finis, par objet et par appelant (journal [FO-STOCKAGE], mesure seulement)
  if put > 0 then Pqs.note_entry(f, item, put) end
  -- Lot STOCKAGE : un dépôt refusé = plus de place pour cet objet (quel qu'il soit) ; déclenche la pose anticipée d'un coffre.
  if put < n then
    local tick = game.tick or 0
    -- Lot STOCK-QG : un brut ou un déclassé refusé ne déclenche PAS la pose d'une annexe (on n'agrandit que pour des objets finis utiles)
    local cat = Pqs.category(f, item)
    if cat ~= "brut" and cat ~= "declasse" then f.refused_at = tick end
    -- Lot STOCKAGE-VITAL : objets refusés par objet (cumul des tentatives de dépôt : un objet resté en poche et redéposé compte à chaque
    -- fois), lus par la sonde de banc (fo-ia1 stock_cost).
    f.stats = f.stats or {}
    f.stats.refused = f.stats.refused or {}
    f.stats.refused[item] = (f.stats.refused[item] or 0) + (n - put)
    if opts and opts.reserve then count_refused(f, n - put, tick) end -- dépôt d'un PNJ refusé (compteur de la fenêtre)
    -- Lot STOCKAGE-VITAL : au journal, au plus une ligne par équipe et par Stock.REFUSED_LOG ticks.
    if f.hq.get_inventory and (not f.refused_log or tick - f.refused_log >= Stock.REFUSED_LOG) then
      f.refused_log = tick
      local used, size, na = totals(f)
      log(string.format("[FO-STOCKAGE] %s : depot refuse : %d/%d %s pris (%s), stock %d/%d cases, annexes %d, a %.1f min", f.key or "player",
        put, n, item, VITAL[item] and "vitale" or (want < n and "non vitale, reserve des vitales" or "plus de place"), used, size, na,
        (tick - (f.started or 0)) / 3600))
    end
  end
  return put
end


--- Lot STOCKAGE-VITAL (objets au sol, 7/11) : objets de `item` que le stock prend encore (sans réserve, comme Stock.insert sans opts),
--- ou nil quand un inventaire ne le dit pas (moteur simulé : l'appelant garde son ancien chemin).
function Stock.room(f, item)
  if not (f.hq and f.hq.valid and f.hq.get_inventory) then return nil end
  local n = 0
  local invs = Stock.inventories(f)
  for _, inv in ipairs(invs) do
    if not inv.get_insertable_count then return nil end
    n = n + inv.get_insertable_count(item)
  end
  ec("place", #invs) -- get_insertable_count de chaque coffre
  return n
end

--- Lot STOCKAGE-VITAL (objets au sol, 7/11) : le stock prend-il TOUT `list` = { {objet, n}, ... } (un objet peut revenir plusieurs fois) ?
--- Piles entamées de chaque objet, puis cases vides partagées (Sg.fits). Rend (vrai/faux, cases neuves nécessaires, cases vides) ; vrai
--- quand un inventaire ne se lit pas (moteur simulé).
function Stock.can_take(f, list)
  if not (f.hq and f.hq.valid and f.hq.get_inventory) then return true, 0, 0 end
  local invs = Stock.inventories(f)
  local empty = 0
  for _, inv in ipairs(invs) do
    if not (inv.count_empty_stacks and inv.get_insertable_count) then return true, 0, 0 end
    empty = empty + inv.count_empty_stacks()
  end
  ec("place", #invs) -- count_empty_stacks de chaque coffre
  local total, names = {}, {}
  for _, it in ipairs(list or {}) do
    if (it[2] or 0) > 0 then
      if not total[it[1]] then names[#names + 1] = it[1] end
      total[it[1]] = (total[it[1]] or 0) + it[2]
    end
  end
  table.sort(names)
  local rows = {}
  for _, name in ipairs(names) do
    local stack = stack_of(name) or 1
    local part = 0
    for _, inv in ipairs(invs) do part = part + math.max(0, inv.get_insertable_count(name) - inv.count_empty_stacks() * stack) end
    ec("place", 2 * #invs) -- get_insertable_count et count_empty_stacks de chaque coffre, pour cet objet
    rows[#rows + 1] = { n = total[name], stack = stack, part = part }
  end
  local ok, need = Sg.fits(rows, empty)
  return ok, need, empty
end

--- Contenu du stock { [objet] = nombre } : coffre du QG et annexes.
function Stock.contents(f)
  local c = chest_inv(f.hq).get_contents()
  local annex = Stock.annexes(f)
  ec("contents", 2 * (1 + #annex)) -- get_inventory et get_contents, du coffre du QG et de chaque annexe
  if #annex == 0 then return c end
  local out = {}
  for k, v in pairs(c) do out[k] = v end
  for _, e in ipairs(annex) do
    for k, v in pairs(chest_inv(e).get_contents()) do out[k] = (out[k] or 0) + v end
  end
  return out
end

--- Inventaires du stock (pour les fonctions du moteur qui prennent une liste d'inventaires).
function Stock.inventories(f)
  local list = { chest_inv(f.hq) }
  for _, e in ipairs(Stock.annexes(f)) do list[#list + 1] = chest_inv(e) end
  ec("place", #list) -- get_inventory du coffre du QG et de chaque annexe
  return list
end

--- Rangement : l'excédent du coffre du QG passe aux annexes quand le coffre dépasse T.annex.park_at. Rend le nombre
--- d'objets rangés.
function Stock.balance(f)
  if not (f.hq and f.hq.valid) then return 0 end
  local annex = Stock.annexes(f)
  if #annex == 0 then return 0 end
  local inv = chest_inv(f.hq)
  ec("place", 1) -- get_inventory du coffre du QG
  local used, size = slots_of(inv)
  if size <= 0 or used < T.annex.park_at * size then return 0 end
  local room = 0
  for _, e in ipairs(annex) do room = room + chest_inv(e).count_empty_stacks() end
  ec("place", 2 * #annex) -- get_inventory et count_empty_stacks de chaque annexe
  ec("contents", 1) -- get_contents du coffre du QG (le rangement)
  local contents = inv.get_contents()
  local stack_of = {}
  for name in pairs(contents) do
    local proto = game.item_prototypes[name]
    stack_of[name] = proto and proto.stack_size or 1
  end
  local moved = 0
  for _, m in ipairs(A.park_plan(contents, stack_of, size, used, room)) do
    local left = m[2]
    for _, e in ipairs(annex) do
      if left <= 0 then break end
      local put = e.insert({ name = m[1], count = left })
      if put > 0 then
        inv.remove({ name = m[1], count = put })
        left, moved = left - put, moved + put
      end
    end
  end
  if moved > 0 then
    f.stats = f.stats or {}
    f.stats.annex_parked = (f.stats.annex_parked or 0) + moved
  end
  return moved
end

--- Coffres à avoir en main pour agrandir le stock (0 : le stock a de la place).
--- Coffres du stock EN MAIN : ceux du coffre et des annexes, moins ce que le plan directeur va encore réclamer (un coffre
--- réservé à un avant-poste n'est pas posé en annexe).
local function chests_in_hand(f, item)
  return math.max(0, Stock.count(f, item) - (Stock.demand and Stock.demand(f, item) or 0))
end

--- Lot STOCKAGE-VITAL (point D3 de docs/IA_WORKFLOW.md) : coffres d'annexe que le plan directeur va encore réclamer { [objet] = n },
--- pour que le fond compte « en main » comme Stock.wanted et Stock.urgent (stock moins cette demande).
function Stock.annex_demand(f)
  local out = {}
  for _, k in ipairs(T.annex.kinds) do out[k.item] = Stock.demand and Stock.demand(f, k.item) or 0 end
  return out
end

--- Emprise (largeur, hauteur en tuiles) d'un coffre du stock, lue au prototype (1 × 1 sans prototype : moteur simulé).
local function footprint(item)
  local protos = game and game.entity_prototypes
  local proto = protos and protos[item]
  return Pl.tiles(proto and proto.collision_box)
end

--- Face du bloc des annexes : la première pose la fixe (face de l'EXTÉRIEUR de la carte, A.outward) ; une partie d'avant
--- (annexes déjà posées au sud) garde le sud.
local function side(f)
  if f.annex_sy then return f.annex_sy end
  if f.annex and #f.annex > 0 then
    f.annex_sy = 1
  elseif f.hq_pos then
    f.annex_sy = A.outward(f.hq_pos.y)
  else
    return 1 -- position du QG pas encore connue : rien n'est figé (la face se fixe à la première lecture avec position)
  end
  return f.annex_sy
end

--- Lot STOCKAGE-VITAL (d) : places des annexes : la face du bloc (side(f)), PUIS l'autre face du lot du QG, chacune dans son ordre de
--- distance (décision du lead, 7/11 : impasse de la sauvegarde du DC, 46 annexes au sud et les 2 dernières places tenues par des
--- steel-chest du DC ; la face nord reste dans le lot du QG et ne touche aucune rue). Une place tenue par une entité qui n'est pas à nous
--- (tourelle de la défense, coffre du DC, réserve du plan) est sautée, jamais retirée.
local function annex_slots(f, w, h)
  local sy = side(f)
  local out = {}
  for _, o in ipairs(A.slots(sy, w, h)) do out[#out + 1] = o end
  for _, o in ipairs(A.slots(-sy, w, h)) do out[#out + 1] = o end
  return out
end

--- Plafond d'annexes : les places des deux faces pour l'emprise du premier coffre posable, MOINS celles tenues par autre chose que nous
--- (dernier relevé de Stock.grow, au plus toutes les Stock.ANNEX_DIAG_LOG : f.annex_lost, tolérant à nil) : Stock.wanted ne croit
--- jamais à une place qui n'existe pas.
local function capacity(f)
  local k = T.annex.kinds[1]
  local w, h = footprint(k.item)
  return math.max(0, #annex_slots(f, w, h) - (f.annex_lost or 0))
end
Stock.capacity = capacity

--- Pose UN coffre `item` à la première place libre du bloc des annexes (une place réservée par le plan directeur est sautée) ;
--- `take()` retire le coffre de sa source une fois l'entité créée. Rend 1 (posé) ou 0.
local function annex_make(f, surface, item, take)
  return function(pos)
    if PlacesQG.is_reserved(f, item, pos) then return false end
    local e = surface.create_entity({ name = item, position = pos, force = f.force })
    if not (e and e.valid) then return false end
    RegT.note(e) -- lot UPS : pose sans événement, notée au registre des machines
    take()
    f.annex = f.annex or {}
    f.annex[#f.annex + 1] = e
    return true
  end
end

-- Pile simple (prototype de type « item », santé pleine) : seule sorte qu'on relève du sol sans rien perdre (relecture de 3a276733, B2).
local function is_simple(st)
  if not (st and st.valid_for_read) then return false end
  local proto = game.item_prototypes[st.name]
  return proto ~= nil and proto.type == "item" and (st.health or 1) >= 1
end

--- Lot STOCKAGE-VITAL (b) : une place du bloc que SEULS des objets au sol refusent (F404 : un item-on-ground sur la tuile suffit à
--- refuser can_place_entity au contrôle par défaut, ghost_revive, celui de script/ai3/places_qg.lua) : ses objets (piles simples
--- seulement ; une autre entité ou une pile spéciale sur la place : on n'y touche pas) sont relevés, le coffre posé, et les objets mis
--- DEDANS ; si la pose échoue, ils retournent au stock ou, à défaut, au sol de la place (rien n'est perdu). Première place qui convient,
--- dans l'ordre du bloc. Rend 1 si un coffre a été posé, 0 sinon. Une ligne [FO-ANNEXE] « place degagee ».
local function place_on_ground(f, surface, item, take)
  if not (surface.can_place_entity and surface.find_entities_filtered and surface.spill_item_stack and f.hq_pos) then return 0 end
  local w, h = footprint(item)
  for _, o in ipairs(annex_slots(f, w, h)) do
    local p = { x = Pl.snap(f.hq_pos.x + o[1], w), y = Pl.snap(f.hq_pos.y + o[2], h) }
    if not PlacesQG.is_reserved(f, item, p) and not surface.can_place_entity({ name = item, position = p, force = f.force }) then
      local area = { { p.x - w / 2 + 0.01, p.y - h / 2 + 0.01 }, { p.x + w / 2 - 0.01, p.y + h / 2 - 0.01 } }
      local ents = surface.find_entities_filtered({ area = area })
      local held, ok = {}, #ents > 0
      for _, e in ipairs(ents) do
        if not (e.valid and e.name == "item-on-ground" and is_simple(e.stack)) then
          ok = false
          break
        end
        held[#held + 1] = { e = e, name = e.stack.name, count = e.stack.count }
      end
      if ok then
        for _, it in ipairs(held) do it.e.destroy() end
        local placed = PlacesQG.place_list(surface, item, f.force, f.hq_pos, { o }, 0, 1, annex_make(f, surface, item, take))
        local chest = placed > 0 and f.annex and f.annex[#f.annex] or nil
        local inside, n = 0, 0
        for _, it in ipairs(held) do
          local put = chest and chest.valid and chest.insert({ name = it.name, count = it.count }) or 0
          inside = inside + put
          n = n + it.count
          if put < it.count then put = put + Stock.insert(f, it.name, it.count - put) end
          if put < it.count then surface.spill_item_stack(p, { name = it.name, count = it.count - put }, false, nil, false) end
        end
        if placed > 0 then
          log(string.format("[FO-ANNEXE] %s : place (%.1f, %.1f) degagee : %d objet(s) au sol releve(s), %d mis dans le coffre pose", f.key or "player",
            p.x, p.y, n, inside))
          f.stats = f.stats or {}
          f.stats.annex_cleared = (f.stats.annex_cleared or 0) + 1
          return 1
        end
      end
    end
  end
  return 0
end

local function place_one(f, surface, item, take)
  local w, h = footprint(item)
  local placed = PlacesQG.place_list(surface, item, f.force, f.hq_pos, annex_slots(f, w, h), 0, 1, annex_make(f, surface, item, take))
  if placed == 0 then placed = place_on_ground(f, surface, item, take) end
  if placed == 0 and f.hq_pos then
    -- Lot s41 spawn-joueur : le QG chevauche un gisement (une place du bloc est refusée pour une RESSOURCE) et le bloc n'a rien donné :
    -- la couronne voisine (A.outer_slots), mêmes contrôles (place libre, hors ressource, hors réserve du plan), sans passe de secours.
    local on_ore = false
    for _, o in ipairs(annex_slots(f, w, h)) do
      if PlacesQG.on_resource(surface, item, { x = Pl.snap(f.hq_pos.x + o[1], w), y = Pl.snap(f.hq_pos.y + o[2], h) }) then
        on_ore = true
        break
      end
    end
    if on_ore then
      placed = PlacesQG.place_list(surface, item, f.force, f.hq_pos, A.outer_slots(w, h), 0, 1, annex_make(f, surface, item, take))
      if placed > 0 then
        local e = f.annex[#f.annex]
        log(string.format("[FO-ANNEXE] %s : bloc des annexes sur un gisement, coffre pose en couronne voisine (%.1f, %.1f)", f.key or "player",
          e.position.x, e.position.y))
      end
    end
  end
  return placed
end

--- Lot STOCKAGE-VITAL (impasse vue le 7/11 sur la sauvegarde du DC : stock plein, 46 annexes sur 48, coffre en main, aucune pose) :
--- pourquoi les places du bloc des annexes refusent `item` ? Rend les places refusées, dans l'ordre du bloc : { x, y, ground = objets
--- au sol sur la place, names = autres entités (noms triés), reserved = gardée par le plan directeur, own = une de nos annexes y est }.
--- Boîte de la place rétrécie de 0,01 (F96 : une entité qui touche seulement le bord serait rendue).
function Stock.annex_blockers(f, surface, item)
  local w, h = footprint(item)
  local own = {}
  for _, e in ipairs(Stock.annexes(f)) do
    if e.unit_number then own[e.unit_number] = true end
  end
  local out = {}
  for _, o in ipairs(annex_slots(f, w, h)) do
    local p = { x = Pl.snap(f.hq_pos.x + o[1], w), y = Pl.snap(f.hq_pos.y + o[2], h) }
    local reserved = PlacesQG.is_reserved(f, item, p)
    if reserved or not surface.can_place_entity({ name = item, position = p, force = f.force }) then
      local row = { x = p.x, y = p.y, ground = 0, names = {}, reserved = reserved, own = false }
      local seen = {}
      local area = { { p.x - w / 2 + 0.01, p.y - h / 2 + 0.01 }, { p.x + w / 2 - 0.01, p.y + h / 2 - 0.01 } }
      for _, e in ipairs(surface.find_entities_filtered({ area = area })) do
        if e.name == "item-on-ground" then
          row.ground = row.ground + 1
        elseif e.unit_number and own[e.unit_number] then
          row.own = true
        else
          -- force et projet du plan directeur qui tient la tuile de l'entité (f.build.occ) : un coffre du DC n'est jamais touché
          local force = type(e.force) == "table" and e.force.name or tostring(e.force or "-")
          local occ = f.build and f.build.occ
          local pid = occ and e.position and occ[Plan.tkey(math.floor(e.position.x), math.floor(e.position.y))]
          local label = string.format("%s[%s%s]", e.name, force, pid and (", projet " .. tostring(pid)) or ", hors plan")
          if not seen[label] then
            seen[label] = true
            row.names[#row.names + 1] = label
          end
        end
      end
      table.sort(row.names)
      out[#out + 1] = row
    end
  end
  return out
end

--- Texte d'une place refusée (journal [FO-ANNEXE]).
local function blocker_text(r)
  local parts = {}
  if r.ground > 0 then parts[#parts + 1] = "sol " .. r.ground end
  if #r.names > 0 then parts[#parts + 1] = table.concat(r.names, "+") end
  if r.reserved then parts[#parts + 1] = "reserve du plan" end
  if #parts == 0 then parts[1] = "refusee sans entite" end
  return string.format("(%.1f, %.1f) %s", r.x, r.y, table.concat(parts, ", "))
end
Stock.ANNEX_DIAG_LOG = 5 * 3600 -- ticks entre deux lignes « aucune place libre » d'une équipe

--- Lot STOCKAGE-VITAL : `k` coffres qu'un PNJ dépose et que le stock plein refuse sont posés en annexes sur-le-champ (au plus jusqu'au
--- plafond d'annexes) : sans cela, un coffre fabriqué pour un stock PLEIN restait en poche et le stock ne grandissait jamais. Le
--- PNJ retire de sa poche le nombre rendu. Une ligne [FO-ANNEXE] par pose.
place_held = function(f, item, k)
  local surface = f.hq.surface
  if not (surface and f.hq_pos and f.hq.get_inventory) then return 0 end -- moteur simulé sans inventaire
  local tick = game.tick or 0
  -- Garde (revue-s et lead, 7/11) : le bloc plein a été essayé il y a moins de T.annex.retry (ici ou par Stock.grow, même
  -- f.stock_watch.retry) : aucune nouvelle recherche de place (jusqu'à 2 × 80 appels au moteur par essai) à chaque dépôt refusé.
  local watch = f.stock_watch
  if watch and watch.retry and tick < watch.retry then return 0 end
  -- Une annexe à la fois, puis le RESTE des coffres refusés va dans le stock agrandi (sauvegarde du DC, 7/11 : la faction emerald
  -- posait 79 annexes en 5 ms pour un PNJ qui portait 79 coffres, au lieu d'une annexe et de 78 coffres rangés dedans).
  local placed, stored, failed, left = 0, 0, false, k
  while left > 0 do
    local used, size, n = totals(f)
    if n >= capacity(f) then break end
    if place_one(f, surface, item, function() end) == 0 then
      failed = true
      break
    end
    placed, left = placed + 1, left - 1
    f.stats = f.stats or {}
    f.stats.annex_placed = (f.stats.annex_placed or 0) + 1
    f.stats.annex_held = (f.stats.annex_held or 0) + 1
    log(string.format("[FO-ANNEXE] %s : coffre %d pose (%s) au depot d'un PNJ (stock plein pour ce coffre), stock %d/%d cases a %.1f min",
      f.key or "player", n + 1, item, used, size, (tick - (f.started or 0)) / 3600))
    if left > 0 then
      local put = plain_insert(f, item, left)
      stored, left = stored + put, left - put
    end
  end
  if placed > 0 then
    f.stock_watch = f.stock_watch or {}
    f.stock_watch.since, f.stock_watch.retry, f.stock_watch.placed_at = tick, nil, tick
  elseif failed then
    f.stock_watch = f.stock_watch or {}
    f.stock_watch.retry = tick + T.annex.retry
  end
  return placed + stored
end

--- Coffres à avoir en main pour agrandir le stock, NETS des coffres en main ; `gross` vrai : BRUTS (le fond, shared/team/fond.lua,
--- retire lui-même les coffres en main hors demande du plan directeur : sans cela ils étaient retirés deux fois, point D3 de
--- docs/IA_WORKFLOW.md).
function Stock.wanted(f, gross)
  if not (f.hq and f.hq.valid) then return 0 end
  local used, size, n = totals(f)
  if size <= 0 then return 0 end -- capacité inconnue (moteur simulé)
  used = math.max(0, used - Pqs.junk(f, function() return Stock.contents(f) end)) -- lot STOCK-QG : le brut et le déclassé ne comptent pas
  local have = 0
  for _, k in ipairs(T.annex.kinds) do have = have + chests_in_hand(f, k.item) end
  local tick = game.tick or 0
  local w = A.wanted(used, size, n, gross and 0 or have, A.early_due(f.stock_watch, tick, f.refused_at), capacity(f))
  -- Lot STOCKAGE-VITAL : au-dessus de T.stockage.urgent_at sans coffre en main, au moins un coffre à fabriquer (avant la saturation).
  if Sg.urgent(used / size, have > 0, T.stockage) and n < capacity(f) then w = math.max(w, 1) end
  return w
end

--- Stock LIBRE (coffre et annexes moins ce que les tâches ont réservé) : posé par script/team/board.lua au chargement
--- (le tableau requiert ce fichier : pas de require retardé, F24). Absent : le stock tel quel.
Stock.free_view = nil
--- Pose de fours au QG (Outposts.place_smelters), posée par script/team/board.lua pour la même raison.
Stock.place_smelters = nil
--- Registre des fours du QG (Outposts.smelters), idem.
Stock.smelters = nil
--- Exemplaires d'un objet que le plan directeur va encore réclamer (posé par script/team/board.lua) : jamais dormants.
Stock.demand = nil
--- Crochet de pensée (balayage des fantômes d'aperçu), idem.
Stock.on_think = nil

--- Lot ADOPTE (constat du DC : « les IA se mettent à poser des fours ») : les fours LIBRES au-delà de Ad.IDLE_KEEP sont posés
--- au QG (registre f.smelters, rangées T.hq_rows.smelter), jusqu'à Br.SMELT_HARD fours en tout (ils sont déjà fabriqués : un four
--- de plus, même sans minerai, ne coûte rien, contrairement à une commande d'avance) ; le combustible
--- vient du stock libre. VOTRE équipe seulement : les factions posent leurs fours par leurs vagues (Br.smelters). Une ligne
--- [FO-ADOPTE] par pose. Rend le nombre posé.
function Stock.deploy_idle(f, surface, tick)
  if not (f.is_player and f.hq and f.hq.valid and Stock.free_view and Stock.place_smelters and Stock.smelters) then return 0 end
  local ok, on = pcall(function() return settings.global["fo-war-adopte"].value end)
  if ok and on == false then return 0 end
  local free = Stock.free_view(f, tick)
  -- Dormant = resté LIBRE toute une fenêtre (A.window) : le kit de départ et les fours qu'une tâche va réclamer ne sont pas posés.
  local claimed = Stock.demand and Stock.demand(f, T.SMELTER) or 0
  local w, lo = Ad.window(f.idle_window, tick, math.max(0, (free[T.SMELTER] or 0) - claimed))
  f.idle_window = w
  if lo == nil then return 0 end
  local have = lo
  local registry = Stock.smelters(f)
  local cap = Br.SMELT_HARD
  -- Lot PD-FONDERIEQG (D77) : dès qu'une ligne à tapis fond une plaque (module fini, débit mesuré : f.team.ia3.covered), les
  -- fours dormants ne sont plus posés au QG au-delà de FQ.KEEP : ils restent au coffre, où la ligne les prend pour grandir.
  local covered = f.team and f.team.ia3 and f.team.ia3.covered
  local n_auto = #FQ.automated(SMELT_INPUTS, covered)
  local why
  cap, why = FQ.limit(cap, FQ.KEEP, n_auto, 0, 0)
  local n = Ad.deploy(have, #registry, 0, cap)
  -- Trace de la fenêtre close (au plus une ligne par fenêtre, 60 lignes par équipe) : fours au coffre, libres (minimum de la
  -- fenêtre), registre, posés : de quoi lire pourquoi des fours restent au coffre (réservés par une tâche, ou plafond atteint).
  f.stats = f.stats or {}
  f.stats.idle_logs = (f.stats.idle_logs or 0) + 1
  if f.stats.idle_logs <= 60 then
    log(string.format("[FO-ADOPTE] player : fenetre %.1f min : %d four(s) au coffre, %d libre(s) et non reclames toute la fenetre (plan : %d), registre %d/%d, a poser %d%s",
      (tick - (f.started or 0)) / 3600, Stock.count(f, T.SMELTER), have, claimed, #registry, cap, n,
      why and string.format(" ([FO-FONDERIE-QG] %d plaque(s) fondue(s) par ligne a tapis : plafond %d au lieu de %d)", n_auto, cap, Br.SMELT_HARD) or ""))
  end
  if n <= 0 then return 0 end
  local tmp = game.create_inventory(8)
  tmp.insert({ name = T.SMELTER, count = Stock.remove(f, T.SMELTER, n) })
  -- le combustible libre accompagne les fours (jusqu'à T.fuel_per_burner chacun) ; sans charbon libre, ils sont posés à sec
  local fuel = math.min(math.max(0, free[T.fuel] or 0), T.fuel_per_burner * n)
  if fuel > 0 then tmp.insert({ name = T.fuel, count = Stock.remove(f, T.fuel, fuel) }) end
  local placed = Stock.place_smelters(f, surface, n, tmp)
  for name, c in pairs(tmp.get_contents()) do Stock.insert(f, name, c) end
  tmp.destroy()
  if placed > 0 then
    f.stats = f.stats or {}
    f.stats.idle_deployed = (f.stats.idle_deployed or 0) + placed
    log(string.format("[FO-ADOPTE] player : %d four(s) dormant(s) pose(s) au QG (libres %d, registre %d -> %d, plafond %d) a %.1f min", placed,
      have, #registry - placed, #registry, cap, (tick - (f.started or 0)) / 3600))
  end
  return placed
end

Stock.GROUND_RADIUS = 10  -- tuiles autour de f.hq_pos où le stock reprend les objets posés au sol
Stock.GROUND_LIMIT = 200  -- objets au sol lus au plus par passage
local GROUND_OPTS = { reserve = true } -- la réserve des vitales s'applique, comme au dépôt d'un PNJ (une matière demandée la prend : D1)

--- Lot STOCKAGE-VITAL (objets au sol, 7/11 : 1 774 objets au pied du coffre de l'équipe dans la partie du DC, répandus quand le stock
--- refusait ; source : script/team/migration_champ.lua, give) : le stock reprend les objets posés au sol à Stock.GROUND_RADIUS tuiles au
--- plus du QG, Stock.GROUND_LIMIT au plus par passage, piles triées par position (x, y, puis nom) ; un seul dépôt par objet. Une pile
--- entrée en partie garde son reste au sol (compte réduit), jamais détruite. PILES SIMPLES seulement (relecture de 3a276733, B2 :
--- recréer la pile à neuf perdrait grille d'équipement, inventaire, étiquette, santé) : prototype de type « item » (plaques, minerais,
--- charbon, coffres : tout ce que migration_champ et melange répandaient) et santé pleine ; le reste (armure, munitions entamées, objets
--- abîmés, plans) reste au sol. Une ligne [FO-STOCKAGE] par passage qui reprend quelque chose, au plus une par Stock.REFUSED_LOG sinon.
--- Rend le nombre d'objets repris.
function Stock.pick_ground(f, surface, tick)
  if not (f.hq and f.hq.valid and f.hq_pos and surface and surface.find_entities_filtered) then return 0 end
  local ents = surface.find_entities_filtered({ name = "item-on-ground", position = f.hq_pos, radius = Stock.GROUND_RADIUS,
    limit = Stock.GROUND_LIMIT })
  if #ents == 0 then return 0 end
  local rows, names, by, simple = {}, {}, {}, {}
  for _, e in ipairs(ents) do
    local st = e.valid and e.stack
    local name = st and st.valid_for_read and st.name
    if name and simple[name] == nil then
      local proto = game.item_prototypes[name]
      simple[name] = proto ~= nil and proto.type == "item"
    end
    if name and simple[name] and (st.health or 1) >= 1 then
      if not by[name] then
        by[name] = { n = 0, put = 0 }
        names[#names + 1] = name
      end
      by[name].n = by[name].n + st.count
      rows[#rows + 1] = { e = e, x = e.position.x, y = e.position.y, name = name }
    end
  end
  table.sort(rows, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return a.name < b.name
  end)
  table.sort(names)
  for _, name in ipairs(names) do by[name].put = Stock.insert(f, name, by[name].n, GROUND_OPTS) end
  local took = 0
  for _, r in ipairs(rows) do
    local b = by[r.name]
    if b.put > 0 and r.e.valid then
      local st = r.e.stack
      local n = st.count
      if n <= b.put then
        r.e.destroy()
        b.put, took = b.put - n, took + n
      else
        st.count = n - b.put
        b.put, took = 0, took + b.put
      end
    end
  end
  local parts, seen = {}, 0
  for _, name in ipairs(names) do
    parts[#parts + 1] = string.format("%s %d", name, by[name].n)
    seen = seen + by[name].n
  end
  if #names == 0 then return 0 end -- aucune pile simple : rien à reprendre, rien à écrire
  if took > 0 or not f.ground_log or (tick or 0) - f.ground_log >= Stock.REFUSED_LOG then
    f.ground_log = tick or 0
    log(string.format("[FO-STOCKAGE] %s : sol du QG : %d objet(s) repris sur %d lu(s) (%s), %d pile(s) au plus par passage, rayon %d, a %.1f min",
      f.key or "player", took, seen, table.concat(parts, ", "), Stock.GROUND_LIMIT, Stock.GROUND_RADIUS, ((tick or 0) - (f.started or 0)) / 3600))
  end
  f.stats = f.stats or {}
  f.stats.ground_taken = (f.stats.ground_taken or 0) + took
  f.stats.ground_passes = (f.stats.ground_passes or 0) + 1
  return took
end

--- Pose un coffre du stock (au plus un par appel) quand les cases se remplissent (70 %) ou par ANTICIPATION (lot STOCKAGE :
--- stock à 60 % depuis 5 min, ou dépôt refusé). Les places viennent du bloc de T.annex.block, du plus proche du QG au plus
--- lointain, côté extérieur ; une place réservée par le plan directeur (PlacesQG.is_reserved) est sautée, sans passe de secours.
--- Rend vrai si un coffre a été posé.
function Stock.grow(f, surface, tick)
  if not (f.hq and f.hq.valid) then return false end
  if Stock.on_think then Stock.on_think(f, tick) end -- lot FANTOMES : balayage des aperçus (posé par script/team/board.lua)
  Stock.deploy_idle(f, surface, tick)
  Stock.pick_ground(f, surface, tick) -- lot STOCKAGE-VITAL : objets posés au sol autour du QG, repris quand le stock a la place
  flush_counts(f, tick) -- lot STOCKAGE-VITAL : dépôts refusés, poches pleines (une ligne chacun par fenêtre)
  local used, size, n = totals(f)
  if size <= 0 then return false end
  -- Lot STOCK-QG : les cases prises par du brut et du déclassé ne comptent pas : une annexe ne s'ouvre que pour des objets finis utiles
  -- (et des intermédiaires de base), jamais pour du charbon, de la pierre, du bois ou des fours de pierre déclassés. `used` reste le
  -- remplissage réel pour les journaux ; `eff` pilote l'agrandissement.
  local junk = Pqs.junk(f, function() return Stock.contents(f) end)
  local eff = math.max(0, used - junk)
  Pqs.flush(f, tick, junk, used, size)
  -- Lot STOCKAGE-VITAL (d) : places tenues par autre chose que nous (tourelles, coffres du DC, réserve du plan ; le sol seul ne compte
  -- pas, place_on_ground le dégage), relevées au plus toutes les Stock.ANNEX_DIAG_LOG quand le stock se remplit : capacity les retire.
  if surface and surface.can_place_entity and surface.find_entities_filtered and f.hq_pos and A.fill(eff, size) >= T.annex.grow_at
    and (not f.annex_scan_at or tick - f.annex_scan_at >= Stock.ANNEX_DIAG_LOG) then
    f.annex_scan_at = tick
    local lost = 0
    for _, r in ipairs(Stock.annex_blockers(f, surface, T.annex.kinds[1].item)) do
      if not r.own and (#r.names > 0 or r.reserved) then lost = lost + 1 end
    end
    f.annex_lost = lost
  end
  -- Lot STOCKAGE-VITAL : urgence au journal, une fois par tranche de 5 min et par équipe
  do
    local have = 0
    for _, k in ipairs(T.annex.kinds) do have = have + chests_in_hand(f, k.item) end
    if Sg.urgent(eff / size, have > 0, T.stockage) and (not f.stock_urgent_log or tick - f.stock_urgent_log >= 5 * 3600) then
      f.stock_urgent_log = tick
      log(string.format("[FO-STOCKAGE] %s : stock %d/%d cases (%.0f %%), aucun coffre en main : coffre URGENT demande (annexes %d) a %.1f min",
        f.key or "player", used, size, 100 * used / size, n, (tick - (f.started or 0)) / 3600))
    end
  end
  f.stock_watch = f.stock_watch or {}
  local st = A.watch(f.stock_watch, eff, size, tick)
  if not A.need_chest(eff, size, n, A.early_due(st, tick, f.refused_at), capacity(f)) then return false end
  if st.retry and tick < st.retry then return false end
  local blocked = false
  for _, k in ipairs(T.annex.kinds) do
    if chests_in_hand(f, k.item) >= 1 then
      local placed = place_one(f, surface, k.item, function() Stock.remove(f, k.item, 1) end)
      if placed > 0 then
        f.stats = f.stats or {}
        f.stats.annex_placed = (f.stats.annex_placed or 0) + 1
        st.since, st.retry, st.placed_at, f.refused_at = tick, nil, tick, nil -- la fenêtre repart : au plus un coffre toutes les 5 min par anticipation
        log(string.format("[FO-ANNEXE] %s : coffre %d pose (%s), stock %d/%d cases a %.1f min (dont %d de brut et de declasse, hors agrandissement)",
          f.key or "player", n + 1, k.item, used, size, (tick - (f.started or 0)) / 3600, junk))
        return true
      end
      blocked = true
    end
  end
  -- Un coffre en main mais plus une place libre dans le bloc : on ne refait pas la recherche à chaque pensée.
  if blocked then
    st.retry = tick + T.annex.retry
    -- Lot STOCKAGE-VITAL : la raison au journal (au plus une ligne par Stock.ANNEX_DIAG_LOG) : places prises par nos annexes, et pour
    -- les autres ce qui les bloque (objets au sol, entités, réserve du plan directeur).
    if surface and surface.can_place_entity and surface.find_entities_filtered and f.hq_pos
      and (not f.annex_diag_log or tick - f.annex_diag_log >= Stock.ANNEX_DIAG_LOG) then
      f.annex_diag_log = tick
      local rows = Stock.annex_blockers(f, surface, T.annex.kinds[1].item)
      local kw, kh = footprint(T.annex.kinds[1].item)
      local n_slots = #annex_slots(f, kw, kh)
      local n_own, n_ground, parts = 0, 0, {}
      for _, r in ipairs(rows) do
        if r.own then
          n_own = n_own + 1
        else
          if r.ground > 0 then n_ground = n_ground + 1 end
          if #parts < 8 then parts[#parts + 1] = blocker_text(r) end
        end
      end
      log(string.format("[FO-ANNEXE] %s : coffre en main mais aucune place libre : %d place(s) (deux faces du lot), %d prise(s) par nos annexes, %d autre(s) "
        .. "refusee(s) dont %d par des objets au sol : %s ; stock %d/%d cases, annexes %d, a %.1f min", f.key or "player", n_slots, n_own,
        #rows - n_own, n_ground, #parts > 0 and table.concat(parts, " ; ") or "aucune", used, size, n, (tick - (f.started or 0)) / 3600))
    end
  end
  return false
end

--- Lot STOCKAGE-VITAL : coffre URGENT (stock rempli à T.stockage.urgent_at, aucun coffre en main) : lu par le fond (shared/team/fond.lua,
--- F.annex_urgent), qui le fabrique même cerveau en manque et fond coupé.
function Stock.urgent(f)
  if not (f.hq and f.hq.valid) then return false end
  local used, size, n = totals(f)
  if size <= 0 or n >= capacity(f) then return false end
  used = math.max(0, used - Pqs.junk(f, function() return Stock.contents(f) end)) -- lot STOCK-QG : le brut et le déclassé ne comptent pas
  local have = 0
  for _, k in ipairs(T.annex.kinds) do have = have + chests_in_hand(f, k.item) end
  return Sg.urgent(used / size, have > 0, T.stockage)
end

--- Lot STOCKAGE-VITAL : prédicat « ne pas ramasser `objet` » aux avant-postes (non vitale saturée par le cerveau, ou toute non vitale
--- quand le stock est rempli à T.stockage.stop_at ; jamais une matière demandée en ce moment), ou nil quand rien n'est écarté.
Stock.OVER_EVERY = 60    -- C2 : relecture des saturées au plafond (ticks)
Stock.OVER_LOG = 600     -- C2 : au plus une ligne « plafond des saturées » par équipe sur cette durée, et seulement quand l'ensemble change

--- C2 de DIAG_CONSO (7/11) : saturées du cerveau (f.team.ia3.saturated) dont le stock atteint T.stockage.sat_cap piles (Sg.over_cap) :
--- plus ramassées aux avant-postes, ni collectées aux coffres de sortie du plan directeur, ni minées à la main (Stock.skip_fn), vitales
--- comprises. Relu toutes les Stock.OVER_EVERY ticks (f.stock_over, tolérant à nil) ; une ligne [FO-STOCKAGE] quand l'ensemble change.
local function over_cap(f)
  local tick = (game and game.tick) or 0
  local c = f.stock_over
  if c and tick >= c.at and tick - c.at < Stock.OVER_EVERY then return c.set end
  local ia3 = f.team and f.team.ia3
  local set = Sg.over_cap(ia3 and ia3.saturated, function(it) return Stock.count(f, it) end, stack_of, T.stockage)
  local names, text = {}, {}
  for it in pairs(set) do names[#names + 1] = it end
  table.sort(names)
  for i, it in ipairs(names) do text[i] = it .. " " .. set[it] end
  local key = table.concat(names, " ") -- l'ensemble (noms seuls) : un compte qui bouge ne refait pas la ligne
  local was = c and c.key or ""
  f.stock_over = { at = tick, set = set, key = key, logged = c and c.logged or nil }
  if key ~= was and (not f.stock_over.logged or tick - f.stock_over.logged >= Stock.OVER_LOG) then
    f.stock_over.logged = tick
    log(string.format("[FO-STOCKAGE] %s : plafond des saturees (%d piles) : {%s} plus ramassees ni collectees (avant : {%s}) a %.1f min",
      f.key or "player", (T.stockage and T.stockage.sat_cap) or Sg.DEFAULT.sat_cap, table.concat(text, ", "), was, (tick - (f.started or 0)) / 3600))
  end
  return set
end

function Stock.skip_fn(f)
  if not (f.hq and f.hq.valid) then return nil end
  local used, size = totals(f)
  if size <= 0 then return nil end
  local ia3 = f.team and f.team.ia3
  -- relecture du 7/11 : jamais une matière que l'équipe demande en ce moment (manque mesuré du cerveau, manque de l'objectif
  -- courant ; nets du stock), même stock presque plein et plafond d'annexes atteint
  local need = demanded(f, true)
  local set = Sg.skip(ia3 and ia3.saturated, used / size, VITAL, T.stockage, ia3 and ia3.other_short, need, over_cap(f))
  -- Lot STOCK-QG (directive du DC, 8/11) : PLAFOND DE RAPATRIEMENT par catégorie d'objet (shared/team/plafond_qg.lua), indépendant de la
  -- saturation du cerveau : un objet au plafond de sa catégorie n'est plus ramassé, collecté, miné à la main ni vidé d'un tampon (il reste au
  -- tampon de sa zone), vitales comprises ; une matière DEMANDÉE y échappe sauf si elle est brute (plafond dur).
  local hard = Pqs.hard_set(f, function() return Stock.contents(f) end, need)
  if next(set) == nil and next(hard) == nil then return nil end
  return function(item)
    if hard[item] then
      Pqs.note_skip(f, item)
      return true
    end
    return Sg.skipped(set, item, VITAL)
  end
end

--- Lot STOCK-QG : place restante du stock pour un objet BRUT ou DÉCLASSÉ (shared/team/plafond_qg.lua, Pq.room), ou nil quand il n'a pas de
--- plafond (objet fini, base, ou matière demandée). Lu par le dépôt d'un PNJ (script/team/worker.lua, deposit_inventory) : ce que le stock
--- n'accueille plus est RETIRÉ de la poche (relevé de la partie du 8/11 : le bois de 768 à 4 960 en 30 min avec le seul ramassage plafonné,
--- le reste arrivant par le dépôt des PNJ). Le brut demandé monte à Pq.DEFAULT.brut_demande fois son plafond.
function Stock.cap_room(f, item)
  if not (f.hq and f.hq.valid) or not Pqs.discards(f, item) then return nil end
  local need = demanded(f, true)
  return Pqs.room(f, item, Stock.count(f, item), need[item] ~= nil)
end

--- Lot STOCK-QG : compte (journal) ce que le dépôt d'un PNJ a retiré de sa poche faute de place au plafond.
function Stock.note_cap_drop(f, item, n) Pqs.note_drop(f, item, n) end

return Stock
