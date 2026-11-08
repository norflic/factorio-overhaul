--[[
  Lot MINAGE-MAIN : règles pures du registre des coffres de SORTIE et de la décision « prendre à la sortie ou extraire à la main »
  (shared/team/sources.lua). Usage : lua5.2 tests/sources_test.lua (depuis la racine du mod).
    §1 registre : sortie / entrée / relais / neutre ; pose et retrait ; coffre déclaré ; liens refaits
    §2 contenu : montée datée par objet, première lecture, tranches circulaires
    §3 rangées : ordre par distance, coffres écartés
    §4 décision : 2 000 plaques dans une sortie de fonderie = aucune extraction à la main ; causes écrites quand elle reste permise
    §5 objets attendus ; §6 données lues de shared/team/config.lua (aucun nom dans la règle)
    §7 mutants : chaque règle cassée est vue par au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")

local S
local passes, failures = 0, 0
local current_mutant
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    print("  ECHEC" .. (current_mutant and (" [mutant " .. current_mutant .. "]") or "") .. " : " .. msg)
  end
end

local IRON = T.outposts.iron
local PLATE, ORE = IRON.product, IRON.resource
local TRACKED_ALL = nil

local function always() return true end
local function never() return false end

local function suite()
  local TARGETS = S.targets(T.outposts, T.smelter_inputs, T.OUTPOST_ORDER)
  local TRACKED = S.tracked(TARGETS)

  ---------------------------------------------------------------------------------------------------
  -- §1 registre
  ---------------------------------------------------------------------------------------------------
  local reg = S.new()
  S.add_chest(reg, 10, "ent10", 0, 0)
  S.add_chest(reg, 20, "ent20", 5, 0)
  S.add_chest(reg, 30, "ent30", 9, 0)
  S.add_chest(reg, 40, "ent40", 12, 0)
  check(S.kind(reg, 10) == "neutre" and S.kind(reg, 99) == nil, "un coffre sans bras est neutre ; un inconnu n'a pas de genre")
  check(S.link(reg, 101, "feed", 10) and S.kind(reg, 10) == "sortie", "un bras y dépose, aucun n'en retire : SORTIE (la règle du DC)")
  check(S.link(reg, 102, "take", 10) and S.kind(reg, 10) == "relais", "un bras y dépose et un autre en retire : relais, pas une sortie")
  S.unlink(reg, 102)
  check(S.kind(reg, 10) == "sortie", "le bras de retrait est ramassé : redevient une sortie")
  check(S.link(reg, 103, "take", 20) and S.kind(reg, 20) == "entree", "seulement retiré : entrée")
  check(S.link(reg, 104, "feed", 30) and S.link(reg, 105, "feed", 30) and S.kind(reg, 30) == "sortie", "deux bras déposent : sortie")
  S.unlink(reg, 104)
  check(S.kind(reg, 30) == "sortie", "un des deux bras partis : encore sortie")
  S.unlink(reg, 105)
  check(S.kind(reg, 30) == "neutre", "les deux partis : neutre")
  check(not S.link(reg, 106, "feed", 777), "un lien vers un coffre inconnu n'est pas posé")
  check(not S.link(reg, 106, "autre", 10), "un rôle inconnu n'est pas posé")
  -- le bras pivote : son lien de dépôt passe d'un coffre à l'autre
  S.link(reg, 107, "feed", 10)
  S.link(reg, 107, "feed", 40)
  check(reg.chests[10].nf == 1 and reg.chests[40].nf == 1, "un bras qui change de coffre quitte l'ancien (10 : 107 retiré, reste 101)")
  check(reg.chests[10].feed[107] == nil and reg.chests[40].feed[107] == true, "ensembles de déposants cohérents")
  -- idempotence
  S.link(reg, 107, "feed", 40)
  check(reg.chests[40].nf == 1, "relier deux fois le même bras ne le compte pas deux fois")
  -- coffre déclaré par le plan directeur
  S.add_chest(reg, 50, "ent50", 20, 0).decl = true
  check(S.kind(reg, 50) == "sortie", "une sortie DÉCLARÉE du plan directeur est une sortie sans bras connu")
  S.link(reg, 108, "take", 50)
  check(S.kind(reg, 50) == "relais", "déclarée mais un bras en retire : relais")
  S.unlink(reg, 108)
  -- retrait d'un coffre
  S.remove_chest(reg, 10)
  check(S.kind(reg, 10) == nil and reg.ins[101] == nil, "coffre retiré : plus de genre, son bras n'a plus de lien")
  check(S.remove_chest(reg, 10) == false, "retirer deux fois : faux")
  local ids = S.sorties(reg)
  local sorted = true
  for i = 2, #ids do if ids[i - 1] >= ids[i] then sorted = false end end
  check(sorted and #ids == 2, "sorties triées par identifiant (40, 50 restent) : " .. #ids)
  -- nombre de coffres suivi
  check(reg.nchests == 4, "4 coffres restent (retiré 1 sur 5) : " .. reg.nchests)

  ---------------------------------------------------------------------------------------------------
  -- §2 contenu
  ---------------------------------------------------------------------------------------------------
  local r2 = S.new()
  local c = S.add_chest(r2, 1, "e1", 0, 0)
  S.link(r2, 11, "feed", 1)
  check(S.set_content(r2, 1, { [PLATE] = 300, [ORE] = 5, ["autre-objet"] = 9999 }, TRACKED, 100) == false, "première lecture : pas une montée")
  check(c.n[PLATE] == 300 and c.n[ORE] == 5 and c.n["autre-objet"] == nil, "seuls les objets suivis sont gardés")
  check(S.set_content(r2, 1, { [PLATE] = 450, [ORE] = 5 }, TRACKED, 200) == true and c.grew[PLATE] == 200, "le contenu monte : daté, par objet")
  check(c.grew[ORE] == nil, "l'autre objet n'a pas monté")
  check(S.set_content(r2, 1, { [PLATE] = 400, [ORE] = 5 }, TRACKED, 300) == false and c.grew[PLATE] == 200, "il baisse : la date de montée ne bouge pas")
  check(c.n[PLATE] == 400 and c.read == 300, "contenu et tick de lecture à jour")
  check(S.set_content(r2, 99, {}, TRACKED, 1) == false, "coffre inconnu : rien")
  -- tranches circulaires
  local r3 = S.new()
  for _, id in ipairs({ 5, 9, 12, 20, 31 }) do S.add_chest(r3, id, "e", 0, 0); S.link(r3, id + 1000, "feed", id) end
  S.add_chest(r3, 7, "e", 0, 0) -- neutre : jamais relu
  local seen = {}
  local b1 = S.read_batch(r3, 2)
  local b2 = S.read_batch(r3, 2)
  local b3 = S.read_batch(r3, 2)
  check(#b1 == 2 and b1[1] == 5 and b1[2] == 9, "1re tranche : 5, 9")
  check(b2[1] == 12 and b2[2] == 20, "2e tranche : 12, 20")
  check(b3[1] == 31 and b3[2] == 5, "3e tranche : 31 puis retour à 5 (circulaire)")
  for _, id in ipairs(b1) do seen[id] = true end
  check(seen[7] == nil, "un coffre neutre n'est pas relu")
  check(#S.read_batch(S.new(), 5) == 0, "registre vide : aucune tranche")
  check(#S.read_batch(r3, 50) == 5, "tranche plus grande que le nombre de sorties : toutes, une fois")

  ---------------------------------------------------------------------------------------------------
  -- §3 rangées
  ---------------------------------------------------------------------------------------------------
  local r4 = S.new()
  local function sortie(id, x, y, n, item)
    S.add_chest(r4, id, "e" .. id, x, y)
    S.link(r4, id + 5000, "feed", id)
    S.set_content(r4, id, { [item or PLATE] = n }, TRACKED, 10)
  end
  sortie(3, 100, 0, 800)
  sortie(1, 50, 0, 2000)
  sortie(2, 50, 0, 100)  -- égalité de distance avec 1 : identifiant
  sortie(4, 10, 0, 0)    -- vide : écartée
  sortie(5, 5, 0, 700)   -- écartée par l'appelant (coffre d'équipe, avant-poste)
  local rows = S.rows(r4, PLATE, { x = 0, y = 0 }, function(uid) return uid == 5 end)
  check(#rows == 3 and rows[1].uid == 1 and rows[2].uid == 2 and rows[3].uid == 3, "plus proche d'abord, égalité par identifiant, vide et écartée absentes")
  check(rows[1].n == 2000 and rows[1].d2 == 2500, "contenu et distance au carré")
  check(#S.rows(r4, ORE, { x = 0, y = 0 }, nil) == 0, "aucun minerai dans ces sorties")

  ---------------------------------------------------------------------------------------------------
  -- §4 décision
  ---------------------------------------------------------------------------------------------------
  local function decide(rows_, over)
    local a = { rows = rows_, pause = never, safe = always, now = 1000, crisis = false }
    for k, v in pairs(over or {}) do a[k] = v end
    return S.decide(a)
  end
  local d = decide({ { uid = 7, x = 40, y = 0, n = 2000, d2 = 1600 } })
  check(d.act == "fetch" and d.row.uid == 7 and d.n == 2000 and not S.hand_ok(d), "2 000 plaques dans une sortie de fonderie : prendre à la sortie, AUCUNE extraction à la main")
  d = decide({ { uid = 7, x = 40, y = 0, n = 9000, d2 = 1600 } })
  check(d.n == S.TRIP_MAX, "une tournée prend au plus S.TRIP_MAX")
  d = decide({ { uid = 7, n = 19, d2 = 1 } })
  check(d.act == "hand" and d.why == "sorties vides" and S.hand_ok(d), "moins de S.MIN : la main reprend, cause « sorties vides »")
  d = decide({ { uid = 7, n = S.MIN, d2 = 1 } })
  check(d.act == "fetch", "S.MIN pile : on va le chercher")
  d = decide({})
  check(d.act == "hand" and d.why == "aucune sortie", "aucune sortie : la main, cause « aucune sortie »")
  d = decide(nil)
  check(d.act == "hand" and d.why == "aucune sortie", "rangées absentes : comme aucune sortie")
  d = decide({ { uid = 7, n = 2000, d2 = 1 } }, { safe = never })
  check(d.act == "hand" and d.why == "sortie dangereuse", "sortie sous menace : la main, cause « sortie dangereuse »")
  d = decide({ { uid = 7, n = 2000, d2 = 1 } }, { pause = always })
  check(d.act == "hand" and d.why == "tournee en pause apres un echec", "tournée en pause après un échec : la main reprend, cause écrite")
  d = decide({ { uid = 7, n = 2000, d2 = 1 }, { uid = 8, n = 500, d2 = 9 } }, { pause = function(uid) return uid == 7 end })
  check(d.act == "fetch" and d.row.uid == 8, "la plus proche est en pause : on prend à la suivante")
  d = decide({ { uid = 7, n = 2000, d2 = 1 }, { uid = 8, n = 500, d2 = 9 } }, { safe = function(uid) return uid == 8 end })
  check(d.act == "fetch" and d.row.uid == 8, "la plus proche est dangereuse : la suivante, sûre")
  d = decide({ { uid = 8, n = 500, d2 = 9 }, { uid = 7, n = 2000, d2 = 1 } })
  check(d.row.uid == 8, "l'ordre des rangées est celui de l'appelant (S.rows trie) : la première qui convient")
  d = decide({ { uid = 7, n = 5, grew = 900, d2 = 1 } })
  check(d.act == "wait" and not S.hand_ok(d), "sortie presque vide dont le contenu monte (montée récente) : on attend, pas de minage à la main")
  d = decide({ { uid = 7, n = 5, grew = 1000 - 18001, d2 = 1 } })
  check(d.act == "hand" and d.why == "sorties vides", "montée vieille de plus de S.LIVE_TICKS : la source est morte, la main reprend")
  d = decide({ { uid = 7, n = 5, grew = 1000 - 18000, d2 = 1 } })
  check(d.act == "wait", "montée juste à la limite : encore en marche")
  d = decide({ { uid = 7, n = 2000, d2 = 1 } }, { crisis = true })
  check(d.act == "hand" and d.why == "crise", "crise injectée par un banc : la main passe")
  d = decide({ { uid = 7, n = 2000, d2 = 1 }, { uid = 8, n = 5, grew = 990, d2 = 4 } })
  check(d.act == "fetch" and d.row.uid == 7, "sortie garnie ET sortie en marche : on prend à la garnie")
  -- cause la plus parlante : une sortie dangereuse garnie l'emporte sur une sortie vide
  d = decide({ { uid = 7, n = 2000, d2 = 1 }, { uid = 8, n = 3, d2 = 4 } }, { safe = function(uid) return uid == 8 end })
  check(d.why == "sortie dangereuse", "dangereuse garnie + vide : la cause est le danger")

  ---------------------------------------------------------------------------------------------------
  -- §4 ter : débits, entrées relues, stock qui couvre, mots fixes
  ---------------------------------------------------------------------------------------------------
  local r6 = S.new()
  local cs = S.add_chest(r6, 1, "e1", 0, 0)
  S.link(r6, 11, "feed", 1)
  S.set_content(r6, 1, { [PLATE] = 100 }, TRACKED, 0)
  check(cs.rin == nil and cs.rout == nil, "première lecture : pas de débit")
  S.set_content(r6, 1, { [PLATE] = 400 }, TRACKED, 3600)
  check(cs.rin[PLATE] == 300 and cs.rout[PLATE] == nil, "300 plaques de plus en une minute : 300 par minute en entrée")
  S.note_removed(r6, 1, PLATE, 150)
  S.set_content(r6, 1, { [PLATE] = 450 }, TRACKED, 7200) -- +50 visibles, 150 retirés par nos tournées : 200 entrées
  check(cs.rin[PLATE] == 200 and cs.rout[PLATE] == nil, "ce que nos tournées retirent n'est pas une consommation : entrée 200 par minute")
  S.set_content(r6, 1, { [PLATE] = 330 }, TRACKED, 10800)
  check(cs.rout[PLATE] == 120 and cs.rin[PLATE] == nil, "baisse sans nous : 120 par minute sortis")
  local r7 = S.new()
  S.add_chest(r7, 5, "e5", 0, 0); S.link(r7, 51, "take", 5)
  S.add_chest(r7, 6, "e6", 0, 0)
  S.add_chest(r7, 7, "e7", 0, 0); S.link(r7, 71, "feed", 7); S.link(r7, 72, "take", 7)
  local rd = S.readable(r7)
  check(#rd == 1 and rd[1] == 5, "les entrées sont relues (consommation) ; neutres et relais non")
  check(S.stock_covers({ ore = 0, plate = 21096, count = 50 }) == true, "21 096 plaques au stock : le minage du minerai n'a pas lieu d'être")
  check(S.stock_covers({ ore = 0, plate = S.PLATE_COVER - 1, count = 50 }) == false, "juste sous le seuil de plaques : la main reste permise")
  check(S.stock_covers({ ore = 100, plate = 0, count = 50 }) == true and S.stock_covers({ ore = 99, plate = 0, count = 50 }) == false, "minerai : max(50, 2 × fournée)")
  check(S.stock_covers({ ore = 130, plate = 0, count = 70 }) == false and S.stock_covers({ ore = 140, plate = 0, count = 70 }) == true, "minerai : la fournée compte")
  check(S.stock_covers({ ore = 0, plate = nil, count = 50 }) == false, "ressource brute sans plaque : seul le minerai compte")
  d = decide({ { uid = 7, n = 2000, d2 = 1 } }, { safe = never })
  check(d.code == "sortie_dangereuse", "mot fixe de la cause : sortie_dangereuse")
  check(decide({}).code == "aucune_sortie" and decide({ { uid = 7, n = 3, d2 = 1 } }).code == "sorties_vides", "mots fixes : aucune_sortie, sorties_vides")
  check(decide({ { uid = 7, n = 2000, d2 = 1 } }, { pause = always }).code == "tournee_en_pause", "mot fixe : tournee_en_pause")
  check(decide({ { uid = 7, n = 2000, d2 = 1 } }, { crisis = true }).code == "crise", "mot fixe : crise")

  ---------------------------------------------------------------------------------------------------
  -- §4 quater : PNJ libres, la cause de l'inaction
  ---------------------------------------------------------------------------------------------------
  check(S.idle_cause({ idle = 0, free = { craft = 5 }, waiting = {} }) == nil, "aucun PNJ libre : rien à écrire")
  local ic = S.idle_cause({ idle = 3, free = { craft = 198, mine = 144 }, waiting = { { pid = 7, ents = 446, missing = { { PLATE, 900 }, { "transport-belt", 461 } } },
    { pid = 8, ents = 52, missing = { { PLATE, 100 } } } } })
  check(ic and ic.code == "matiere" and ic.text:find("^rien a construire : 2 projet%(s%) attendent de la matiere"), "projets en attente de matière : cause « matiere »")
  check(ic.text:find(PLATE .. " 1000", 1, true) and ic.text:find("transport-belt 461", 1, true), "manques additionnés, du plus grand au plus petit")
  check(ic.text:find(PLATE, 1, true) < ic.text:find("transport-belt", 1, true), "le plus gros manque d'abord")
  ic = S.idle_cause({ idle = 2, free = { craft = 198, mine = 144, service = 27 }, waiting = {} })
  check(ic.code == "bloquees" and ic.text:find("369 tache%(s%) libre%(s%) mais aucune prenable") and ic.text:find("craft 198, mine 144, service 27", 1, true), "tâches libres mais aucune prenable : types cités")
  ic = S.idle_cause({ idle = 1, free = {}, waiting = {} })
  check(ic.code == "aucune" and ic.text == "rien a construire : aucune tache au tableau", "rien du tout : « aucune tache au tableau »")
  local many = {}
  for i = 1, 9 do many["k" .. i] = 10 - i end
  ic = S.idle_cause({ idle = 1, free = many, waiting = {} })
  check(select(2, ic.text:gsub("k%d", "")) == S.IDLE_KINDS_MAX, "au plus S.IDLE_KINDS_MAX types cités")

  ---------------------------------------------------------------------------------------------------
  -- §5 objets attendus
  ---------------------------------------------------------------------------------------------------
  local rws = { { uid = 1, n = 1000 }, { uid = 2, n = 15 }, { uid = 3, n = 400 }, { uid = 4, n = 600 } }
  check(S.fetchable(rws, always, never, nil) == 2000, "attendu = sorties de S.MIN au moins (15 écarté) : 1000 + 400 + 600")
  check(S.fetchable(rws, function(uid) return uid ~= 1 end, never, nil) == 1000, "une sortie dangereuse n'est pas attendue")
  check(S.fetchable(rws, always, function(uid) return uid == 3 end, nil) == 1600, "une tournée en pause n'est pas attendue")
  check(S.fetchable(rws, always, never, 700) == 700, "borné par la place du coffre d'équipe")
  check(S.fetchable({}, always, never, nil) == 0 and S.fetchable(nil, always, never, nil) == 0, "rien")

  ---------------------------------------------------------------------------------------------------
  -- §6 données
  ---------------------------------------------------------------------------------------------------
  local by = {}
  for _, x in ipairs(TARGETS) do by[x.res] = x end
  check(by[ORE] and by[ORE].item == PLATE and by[ORE].plate == true, "le minerai de fer cherche sa plaque")
  check(by[T.outposts.coal.resource] and by[T.outposts.coal.resource].item == T.outposts.coal.resource and by[T.outposts.coal.resource].plate == false,
    "le charbon est une ressource brute : on cherche le charbon")
  check(by[T.outposts.copper.resource] and by[T.outposts.copper.resource].item == T.outposts.copper.product, "le cuivre cherche sa plaque")
  check(TRACKED[PLATE] and TRACKED[ORE] and TRACKED[T.outposts.coal.resource], "objets suivis : plaque, minerai, ressource brute")
  check(TARGETS[1].res == T.outposts[T.OUTPOST_ORDER[1]].resource, "ordre des types respecté")
  -- aucun nom d'objet dans la règle (lu en source)
  local fh = io.open("shared/team/sources.lua", "rb")
  local src = fh and fh:read("*a") or ""
  if fh then fh:close() end
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  local bad = {}
  for _, name in ipairs({ "iron%-plate", "copper%-plate", "iron%-ore", "copper%-ore", "\"coal\"", "\"stone\"", "iron%-chest", "stone%-furnace" }) do
    if code:find(name) then bad[#bad + 1] = name end
  end
  check(#bad == 0, "aucun nom d'objet du jeu dans shared/team/sources.lua : " .. table.concat(bad, ","))

  ---------------------------------------------------------------------------------------------------
  -- §4 bis : le cas du DC de bout en bout (registre -> rangées -> décision)
  ---------------------------------------------------------------------------------------------------
  local r5 = S.new()
  S.add_chest(r5, 900, "fonderie", 60, 10)
  S.link(r5, 9001, "feed", 900) -- le bras de la fonderie
  S.set_content(r5, 900, { [PLATE] = 2000 }, TRACKED, 50)
  local rr = S.rows(r5, PLATE, { x = 0, y = 0 }, nil)
  local dd = S.decide({ rows = rr, pause = never, safe = always, now = 60, crisis = false })
  check(not S.hand_ok(dd) and dd.act == "fetch", "DC : 2 000 plaques de fer dans la sortie d'une fonderie posée, manque de fer : aucune extraction à la main")
  S.link(r5, 9002, "take", 900) -- le joueur y branche un bras de retrait : plus une sortie
  rr = S.rows(r5, PLATE, { x = 0, y = 0 }, nil)
  check(#rr == 0, "un bras en retire : ce n'est plus une sortie, ses plaques ne comptent pas")
  dd = S.decide({ rows = rr, pause = never, safe = always, now = 60, crisis = false })
  check(S.hand_ok(dd) and dd.why == "aucune sortie", "… et la main reprend, cause « aucune sortie »")
end

---------------------------------------------------------------------------------------------------
-- §7 mutants
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "sortie-ignore-takers", function() S.classify = function(nf, nt) if nf > 0 then return "sortie" end if nt > 0 then return "entree" end return "neutre" end end },
  { "entree-prise-pour-sortie", function() S.classify = function(nf, nt) if nf > 0 and nt == 0 then return "sortie" end if nt > 0 then return "sortie" end return "neutre" end end },
  { "neutre-est-sortie", function() S.classify = function(nf, nt) if nt == 0 then return "sortie" end return "entree" end end },
  { "decl-ignoree", function()
      S.kind = function(reg, cuid)
        local c = reg.chests[cuid]
        if not c then return nil end
        return S.classify(c.nf, c.nt)
      end
    end },
  { "decl-force-sortie", function()
      S.kind = function(reg, cuid)
        local c = reg.chests[cuid]
        if not c then return nil end
        if c.decl then return "sortie" end
        return S.classify(c.nf, c.nt)
      end
    end },
  { "unlink-oublie", function() S.unlink = function() end end },
  { "remove-chest-garde", function() S.remove_chest = function(reg, cuid) return reg.chests[cuid] ~= nil end end },
  { "link-compte-double", function()
      local o = S.link
      S.link = function(reg, iuid, role, cuid)
        local ok = o(reg, iuid, role, cuid)
        local c = reg.chests[cuid]
        if ok and c then if role == "feed" then c.nf = c.nf + 1 else c.nt = c.nt + 1 end end
        return ok
      end
    end },
  { "link-inconnu-accepte", function()
      local o = S.link
      S.link = function(reg, iuid, role, cuid) if not reg.chests[cuid] then return true end return o(reg, iuid, role, cuid) end
    end },
  { "set-content-garde-tout", function()
      local o = S.set_content
      S.set_content = function(reg, cuid, items, tracked, tick)
        local all = {}
        for k in pairs(items) do all[k] = true end
        return o(reg, cuid, items, all, tick)
      end
    end },
  { "premiere-lecture-monte", function()
      local o = S.set_content
      S.set_content = function(reg, cuid, items, tracked, tick)
        local c = reg.chests[cuid]
        if c then c.read = c.read or 0 end
        return o(reg, cuid, items, tracked, tick)
      end
    end },
  { "monte-tout-objet", function()
      local o = S.set_content
      S.set_content = function(reg, cuid, items, tracked, tick)
        local g = o(reg, cuid, items, tracked, tick)
        local c = reg.chests[cuid]
        if g and c then for item in pairs(c.n) do c.grew[item] = tick end end
        return g
      end
    end },
  { "tranche-sans-curseur", function()
      S.read_batch = function(reg, batch)
        local ids, out = S.sorties(reg), {}
        for i = 1, math.min(batch, #ids) do out[i] = ids[i] end
        return out
      end
    end },
  { "tranche-lit-neutres", function()
      S.read_batch = function(reg, batch)
        local ids, out = {}, {}
        for id in pairs(reg.chests) do ids[#ids + 1] = id end
        table.sort(ids)
        for i = 1, math.min(batch, #ids) do out[i] = ids[i] end
        return out
      end
    end },
  { "rangees-farthest", function()
      local o = S.rows
      S.rows = function(reg, item, at, skip)
        local r = o(reg, item, at, skip)
        table.sort(r, function(a, b) return a.d2 > b.d2 end)
        return r
      end
    end },
  { "rangees-skip-ignore", function()
      local o = S.rows
      S.rows = function(reg, item, at) return o(reg, item, at, nil) end
    end },
  { "rangees-vides", function()
      local o = S.rows
      S.rows = function(reg, item, at, skip)
        local r = o(reg, item, at, skip)
        for _, cuid in ipairs(S.sorties(reg)) do
          local c = reg.chests[cuid]
          if (c.n[item] or 0) == 0 and not c.grew[item] and not (skip and skip(cuid)) then
            r[#r + 1] = { uid = cuid, x = c.x, y = c.y, n = 0, d2 = 0 }
          end
        end
        return r
      end
    end },
  { "decide-min-zero", function() S.MIN = 1 end },
  { "decide-min-haut", function() S.MIN = 100000 end },
  { "decide-sans-danger", function()
      local o = S.decide
      S.decide = function(a) a.safe = function() return true end return o(a) end
    end },
  { "decide-sans-pause", function()
      local o = S.decide
      S.decide = function(a) a.pause = function() return false end return o(a) end
    end },
  { "decide-sans-crise", function()
      local o = S.decide
      S.decide = function(a) a.crisis = false return o(a) end
    end },
  { "decide-live-toujours", function() S.LIVE_TICKS = 10 ^ 9 end },
  { "decide-live-jamais", function() S.LIVE_TICKS = -1 end },
  { "decide-sans-borne", function() S.TRIP_MAX = 10 ^ 9 end },
  { "decide-main-toujours", function() S.hand_ok = function() return true end end },
  { "decide-jamais-main", function() S.hand_ok = function() return false end end },
  { "decide-sans-cause", function()
      local o = S.decide
      S.decide = function(a) local d = o(a); if d.act == "hand" then d.why = "aucune sortie" end return d end
    end },
  { "attendu-sans-room", function()
      local o = S.fetchable
      S.fetchable = function(rows, safe, pause) return o(rows, safe, pause, nil) end
    end },
  { "attendu-sans-danger", function()
      local o = S.fetchable
      S.fetchable = function(rows, _, pause, room) return o(rows, always, pause, room) end
    end },
  { "attendu-sans-pause", function()
      local o = S.fetchable
      S.fetchable = function(rows, safe, _, room) return o(rows, safe, never, room) end
    end },
  { "attendu-petites-sorties", function()
      S.fetchable = function(rows, safe, pause, room)
        local total = 0
        for _, r in ipairs(rows or {}) do if r.n > 0 and safe(r.uid) and not pause(r.uid) then total = total + r.n end end
        if room ~= nil and total > room then total = room end
        return total
      end
    end },
  { "debit-ignore-retraits", function()
      S.note_removed = function() end
    end },
  { "couvre-minerai-seul", function() S.stock_covers = function(a) return (a.ore or 0) >= math.max(S.ORE_MIN, 2 * (a.count or 0)), "minerai" end end },
  { "couvre-plaques-jamais", function() S.PLATE_COVER = 10 ^ 9 end },
  { "couvre-toujours", function() S.stock_covers = function() return true, "minerai" end end },
  { "entrees-non-relues", function() S.readable = function(reg) return S.sorties(reg) end end },
  { "codes-absents", function()
      local o = S.decide
      S.decide = function(a) local d = o(a); d.code = nil return d end
    end },
  { "inaction-muette", function() S.idle_cause = function() return nil end end },
  { "inaction-sans-matiere", function()
      local o = S.idle_cause
      S.idle_cause = function(a) a.waiting = {} return o(a) end
    end },
  { "inaction-libres-zero", function()
      local o = S.idle_cause
      S.idle_cause = function(a) a.idle = 0 return o(a) end
    end },
  { "cibles-brut-comme-plaque", function()
      local o = S.targets
      S.targets = function(spec, inputs, order)
        local t = o(spec, inputs, order)
        for _, x in ipairs(t) do x.item = x.res end
        return t
      end
    end },
}

package.loaded["shared.team.sources"] = nil
S = require("shared.team.sources")
suite()
local base_failures, base_passes = failures, passes
local killed = 0
for _, m in ipairs(MUTANTS) do
  package.loaded["shared.team.sources"] = nil
  S = require("shared.team.sources")
  local before = failures
  current_mutant = m[1]
  local silent_print = print
  print = function() end
  local ok, err = pcall(function() m[2](); suite() end)
  print = silent_print
  current_mutant = nil
  if not ok or failures > before then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
  -- les échecs des mutants ne comptent pas dans le bilan du témoin
  failures = before
  passes = base_passes
end
print(string.format("[SOURCES] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refuses", base_passes, base_failures, killed, #MUTANTS))
os.exit((base_failures == 0 and killed == #MUTANTS) and 0 or 1)
