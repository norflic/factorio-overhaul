--[[
  Lot CORR-CHAMP-MANQUE (EFFONDREMENT) : la règle 8 des emplacements BRANCHÉE, au moteur simulé (tests/mock_engine.lua). Ce n'est pas
  une preuve en jeu (micro-banc champ-manque, fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md E3).
  Relecture du lead (18 h 10, point 3) : RIEN n'est remplacé ici, ni Em.slots ni les prédicats. On appelle le VRAI Capi.slots d'une
  faction de la partie simulée, avec :
    - des ordres « module » injectés dans cs.open et f.team.ia3e.mods, comme tests/capi_debit_test.lua §6 ;
    - le livre des recettes OUVERTES de la force (Book.from_game, comme script/team/team.lua) ;
    - le relevé Capi.data.
  Une seule partie, cinq situations :
    §1 TÉMOIN : 2 modules en réserve sans manque déclaré. Rien ne dort : aucun siège, la foreuse de fer est refusée « plan
       directeur occupe ». C'est DEPENSES2 (c) seule.
    §2 CAS B (0.6.51, minute 11) : manques d'assembleurs, de bras et de coffres ; fer 66, cuivre 354. Siège du FER, journal
       [FO-CAPI-EMPLACEMENTS] « +1 pour la matiere qui manque aux ordres ouverts (iron-plate) », foreuse de fer accordée, cuivre
       refusé.
    §3 CIRCUITS (relecture, point 2) : 40 circuits qui manquent ; fer 10, cuivre 20. Siège du CUIVRE (par le câble), pas du fer.
    §4 INTERRUPTEUR du banc témoin (remote « fo-capi », « manque ») : §2 éteint, aucun siège ; rallumé, le siège revient.
    §5 CHAMP (relecture, point 1, BLOQUANT) : un ordre exec = "champ" ouvert sur le siège le TIENT, et la foreuse de fer est refusée
       à la décision suivante. Rouge sur 1e97d7da ; mutant « held_comp ignoré ».
    §6 CHAMP QUI BAT (seconde relecture, point 1) : ouvert depuis plus de Em.STALL, étiquette de progrès à jour (la pile bat), rien
       posé : il LÂCHE le siège, la foreuse de fer est de nouveau accordée. Rouge sur 87041986.
    §7 HYSTÉRÉSIS (seconde relecture, point 2) : deux relevés de suite, déficits proches qui s'échangent (fer 100 / cuivre 108, puis
       108 / 100) : la plaque du premier relevé garde le siège. Rouge sur 87041986.
  Ce que ce banc ne montre PAS : un ordre « couvrir » qui PART au journal [FO-CAPI]. La faute est au moteur simulé :
    - il n'a pas de foreuse électrique de l'exécutant (« foreuse electrique de l'executant nil »), donc aucune option de foreuse ;
    - avec une foreuse électrique posée dans le seul test, il plante plus loin, sans has_flag dans script/team/convoyeurs.lua.
  Ce départ se prouve en jeu, au micro-banc champ-manque.
  Usage : lua5.2 tests/champ_manque_moteur_test.lua   (depuis la racine du mod ; environ une demi-minute)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[CHAMP-MANQUE-MOTEUR] ECHEC : " .. msg) end
end
local function say(s) print("[CHAMP-MANQUE-MOTEUR] " .. s) end
local function W() return M.world() end
local MIN = 3600

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs({ { 1, 0 }, { -1, 0 } }) do
    for i = 0, 11 do
      out[#out + 1] = { x = c[1] * 320 + math.cos(i * math.pi / 6) * 60, y = math.sin(i * math.pi / 6) * 60, name = names[i % 4 + 1] }
    end
  end
  return out
end

M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
M.load_mod()
M.dispatch(W().on_init)
M.command("fo-war", "start 2 30 30 320")
M.run_ticks(MIN)
local f = global.fo.war.factions[1]
local cs, st = f.team.capi, f.team.ia3e
check(cs ~= nil and st ~= nil, "la capitalisation et l'automatisation de " .. tostring(f.key) .. " existent")
local Capi = require("script.ai3.capitalisation")
local Em = require("shared.ai3.emplacements")
local Book = require("shared.team.book")
local force = game.forces[f.force]
local book = Book.from_game(game.recipe_prototypes, { allowed = function(name)
  local r = force and force.recipes and force.recipes[name]
  return r ~= nil and r.enabled
end })
local nbook = 0
for _ in pairs(book.by_product) do nbook = nbook + 1 end
say(string.format("livre de la force %s : %d objet(s) faisables a la main", tostring(f.force), nbook))
check(book:handcraftable("electronic-circuit") and book:handcraftable("assembling-machine-1"), "le livre de la force a les circuits et les assembleurs")

local CASE_B = { { "packs:automation-science-pack", { { "assembling-machine-1", 2 }, { "inserter", 7 }, { "iron-chest", 3 } } },
  { "chaine:burner-mining-drill", { { "assembling-machine-1", 3 }, { "inserter", 10 }, { "iron-chest", 4 } } } }
local CIRC = { { "chaine:electronic-circuit-a", { { "electronic-circuit", 20 } } }, { "chaine:electronic-circuit-b", { { "electronic-circuit", 20 } } } }
local BARE = { { "chaine:a", {} }, { "chaine:b", {} } }

--- Situation : les ordres « module » donnés, en réserve, seuls ouverts (2 emplacements de base, comme le cas B) ; rend le relevé du
--- vrai Capi.slots et ses lignes de journal [FO-CAPI-EMPLACEMENTS].
local function situation(orders, stock, champ, keep_prev)
  local tick = game.tick + 60
  f.team.ia3.puits, cs.blocked_slots = nil, 0
  if not keep_prev then cs.seat_prev = nil end
  cs.open, cs.slots_sig = {}, nil
  local keep = {}
  for _, m in ipairs(st.mods) do if not (m.id >= 9200 and m.id < 9300) then keep[#keep + 1] = m end end
  st.mods = keep
  for i, c in ipairs(orders) do
    local id = 9200 + i
    st.mods[#st.mods + 1] = { id = id, product = "p" .. i, state = "reserve", missing = c[2], built = 0, total = 50, capi = c[1] }
    cs.open[#cs.open + 1] = { key = c[1], kind = "chaine", exec = "module", mod_ids = { id }, n = 1, opened = tick, progress_tick = tick,
      missing = c[2] }
  end
  if champ then
    local c = { key = "couvrir:iron-ore@banc", kind = "couvrir", exec = "champ", resource = "iron-ore", seat = "complement",
      opened = tick, progress_tick = tick, missing = {} }
    if type(champ) == "table" then for k, v in pairs(champ) do c[k] = v end end
    for k, v in pairs(c) do if v == "TICK" then c[k] = tick elseif type(v) == "number" and v < 0 then c[k] = tick + v end end
    cs.open[#cs.open + 1] = c
  end
  local log0 = #W().logs
  local sl = Capi.slots(f, cs, stock, tick, book)
  local lines = {}
  for i = log0 + 1, #W().logs do
    local l = W().logs[i]
    if l:find("[FO-CAPI-EMPLACEMENTS] " .. tostring(f.key), 1, true) then lines[#lines + 1] = l end
  end
  return sl, table.concat(lines, "\n")
end

local STOCK_B = { ["iron-plate"] = 66, ["copper-plate"] = 354 }

say("§1 temoin : deux modules en reserve sans manque declare (DEPENSES2 (c) seule)")
local s1 = situation(BARE, STOCK_B)
say("§1 " .. s1.why)
check(s1.busy and s1.room == 0 and s1.comp == nil and Em.drill_refused(s1, "iron-plate"), "§1 pleins, aucun siege, foreuse de fer refusee")

say("§2 cas B : assembleurs, bras et coffres qui manquent ; fer 66, cuivre 354")
local s2, j2 = situation(CASE_B, STOCK_B)
say("§2 " .. s2.why)
check(s2.busy and s2.room == 0 and s2.room_comp == 1 and s2.comp and s2.comp["iron-plate"] == true and not s2.comp["copper-plate"],
  "§2 pleins, un siege pour le FER")
check(not Em.drill_refused(s2, "iron-plate") and Em.drill_refused(s2, "copper-plate"), "§2 foreuse de fer accordee, de cuivre refusee")
check(Em.order_seat(s2.room, s2.room_comp, s2.comp, "iron-plate") == "complement", "§2 ordre « couvrir » du fer : siege du complement")
check(j2:find("+1 pour la matiere qui manque aux ordres ouverts (iron-plate)", 1, true) ~= nil,
  "§2 journal [FO-CAPI-EMPLACEMENTS] : +1 pour la matiere qui manque (iron-plate)")

say("§3 circuits : 40 circuits qui manquent ; fer 10, cuivre 20")
local s3, j3 = situation(CIRC, { ["iron-plate"] = 10, ["copper-plate"] = 20 })
say("§3 " .. s3.why)
check(s3.comp and s3.comp["copper-plate"] == true and not s3.comp["iron-plate"], "§3 siege du CUIVRE (par le cable), pas du fer")
check(not Em.drill_refused(s3, "copper-plate") and Em.drill_refused(s3, "iron-plate"), "§3 foreuse de cuivre accordee, de fer refusee")
check(j3:find("(copper-plate)", 1, true) ~= nil, "§3 journal : le cuivre")

say("§4 interrupteur du banc temoin (fo-capi, manque)")
check(remote.call("fo-capi", "manque", f.key, false) == true, "§4 interrupteur accepte")
local s4 = situation(CASE_B, STOCK_B)
check(s4.comp == nil and Em.drill_refused(s4, "iron-plate"), "§4 regle eteinte : aucun siege, foreuse de fer refusee")
check(remote.call("fo-capi", "manque", f.key, true) == true, "§4 regle rallumee")
local s4b = situation(CASE_B, STOCK_B)
check(s4b.comp and s4b.comp["iron-plate"] == true, "§4 rallumee : le siege du fer revient")

say("§5 champ (relecture, point 1) : un ordre exec = champ ouvert sur le siege le tient")
local s5, j5 = situation(CASE_B, STOCK_B, true)
say("§5 " .. s5.why)
local function s5_ok(sl)
  return sl.busy and sl.room == 0 and sl.room_comp == 0 and Em.drill_refused(sl, "iron-plate") and sl.counted == s2.counted
end
check(s5_ok(s5), "§5 le champ TIENT le siege : foreuse de fer refusee a la decision suivante, aucun emplacement ordinaire pris")
check(j5:find("siege tenu par 1 ordre(s)", 1, true) ~= nil, "§5 journal : siege tenu par 1 champ")
check(Em.champ_seat(true, s2.room, s2.room_comp, s2.comp, "iron-plate") == "complement"
  and Em.champ_seat(true, s5.room, s5.room_comp, s5.comp, "iron-plate") == nil, "§5 decision : le premier champ du fer prend le siege, le suivant est refuse")
local o_slots = Em.slots
Em.slots = function(s0) local c = {} for k, v in pairs(s0) do c[k] = v end c.held_comp = nil return o_slots(c) end
local s5m = situation(CASE_B, STOCK_B, true)
Em.slots = o_slots
check(not s5_ok(s5m), "§5 mutant « champ tenu ignore » (comme 1e97d7da) : refuse")

say("§6 champ qui bat (seconde relecture, point 1) : ouvert depuis plus de Em.STALL, etiquette a jour, rien pose")
local s6, j6 = situation(CASE_B, STOCK_B, { opened = -(Em.STALL + 600), progress_tick = "TICK", tag = "pile:1:reserve:pile:0" })
say("§6 " .. s6.why)
check(s6.room_comp == 1 and not Em.drill_refused(s6, "iron-plate") and not s6.why:find("siege tenu", 1, true),
  "§6 le champ qui bat sans rien poser LACHE le siege apres Em.STALL : foreuse de fer de nouveau accordee")
local s6b = situation(CASE_B, STOCK_B, { opened = -(Em.STALL + 600), progress_tick = "TICK", adv_tick = -600, built_hi = 4 })
check(s6b.room_comp == 0 and Em.drill_refused(s6b, "iron-plate"), "§6 le meme champ qui a pose il y a 10 s tient toujours le siege")

say("§7 hysteresis (seconde relecture, point 2) : deux releves de suite, deficits proches qui s'echangent")
local PL1 = { { "chaine:x", { { "iron-plate", 100 }, { "copper-plate", 108 } } } }
local PL2 = { { "chaine:x", { { "iron-plate", 108 }, { "copper-plate", 100 } } } }
local NONE = { ["iron-plate"] = 0, ["copper-plate"] = 0 }
local s7a = situation(PL1, NONE)
local s7b = situation(PL2, NONE, nil, true)
say("§7 releve 1 : " .. s7a.why)
say("§7 releve 2 : " .. s7b.why)
check(s7a.comp and s7a.comp["copper-plate"] and s7b.comp and s7b.comp["copper-plate"] and not s7b.comp["iron-plate"],
  "§7 le cuivre prend le siege (108 contre 100) puis le GARDE quand le fer passe a 108 (marge " .. tostring(require("shared.ai3.capitalisation").SEAT_MARGIN) .. " %)")
local s7c = situation(PL2, NONE)
check(s7c.comp and s7c.comp["iron-plate"], "§7 sans releve d'avant, le meme etat donne le fer (le plus grand deficit)")

print(string.format("[CHAMP-MANQUE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
