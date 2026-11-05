--[[
  Lot CORR-CHAMP-MANQUE (EFFONDREMENT) : la règle 8 des emplacements BRANCHÉE, au moteur simulé (tests/mock_engine.lua). Ce n'est pas
  une preuve en jeu.
  Cas B de la partie du DC (0.6.51, minute 11) : RIEN ne dort (100 fer, 100 cuivre), deux modules qui attendent leur matière tiennent
  les 2 emplacements, un ordre ouvert manque d'engrenages (dont la recette prend du fer : ingrédient direct, Ca.blocked_items sur les
  recettes du relevé Capi.data).
    §1 TÉMOIN (aucun ordre en manque) : c'est le cas de DEPENSES2 (c) seule : aucun siège, la foreuse de fer est refusée « plan
       directeur occupe » ;
    §2 LOT : chemin de jeu Capi.slots → Ca.blocked_items (recettes du relevé) → Em.short (stock libre du relevé) → Em.slots : un siège
       pour le fer, journal [FO-CAPI-EMPLACEMENTS] « +1 pour la matiere qui manque aux ordres ouverts (iron-plate) », foreuse de fer
       accordée, cuivre refusé, ordre « couvrir » du fer sur le siège.
    §3 INTERRUPTEUR du banc témoin (remote « fo-capi », « manque ») : éteint, même cas que §2 sans siège ; rallumé, le siège revient.
  Usage : lua5.2 tests/champ_manque_moteur_test.lua   (depuis la racine du mod ; quatre parties simulées, quelques minutes)
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

local function run(opts)
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  M.load_mod()
  M.dispatch(W().on_init)
  M.command("fo-war", "start 2 30 30 320")
  M.run_ticks(MIN)
  local f = global.fo.war.factions[1]
  local Stock = require("script.team.stock")
  local Em = require("shared.ai3.emplacements")
  local Ca = require("shared.ai3.capitalisation")
  -- Deux modules qui attendent leur matière tiennent les 2 emplacements (le moteur simulé n'ouvre aucun module réel : même montage
  -- que tests/depenses2_moteur_test.lua §7).
  local o_slots = Em.slots
  local seen = { first = nil, short_ok = nil }
  Em.slots = function(sl)
    if sl and sl.mods then
      local mods = {}
      for _, m in ipairs(sl.mods) do mods[#mods + 1] = m end
      for i = 1, 2 do mods[#mods + 1] = { key = "attente" .. i, states = { "attente" }, opened = 0 } end
      sl.mods = mods
    end
    local out = o_slots(sl)
    if sl and sl.names and not seen.first then seen.first = out end
    if out.comp and not seen.short_ok then seen.short_ok = out end
    return out
  end
  -- Un ordre ouvert qui manque d'engrenages (§2 seulement) : ajouté à l'entrée du prédicat, qui lit les vraies recettes du relevé.
  local o_bl = Ca.blocked_items
  if opts.gears then
    Ca.blocked_items = function(ctx)
      local open = {}
      for _, o in ipairs(ctx.open or {}) do open[#open + 1] = o end
      open[#open + 1] = { key = "banc:attente", missing = { { "iron-gear-wheel", 20 } } }
      seen.blocked = o_bl({ open = open, D = ctx.D })
      return seen.blocked
    end
  end
  for _, it in ipairs({ { "iron-plate", 100 }, { "copper-plate", 100 } }) do Stock.insert(f, it[1], it[2]) end
  -- §3 : interrupteur du banc témoin (remote « fo-capi », « manque »), pour CHAQUE faction (les relevés d'Em.slots ci-dessus ne
  -- disent pas de quelle équipe ils viennent)
  if opts.off ~= nil then
    seen.remote = true
    for _, ff in ipairs(global.fo.war.factions) do
      if remote.call("fo-capi", "manque", ff.key, not opts.off) ~= true then seen.remote = false end
    end
    seen.remote_player = remote.call("fo-capi", "manque", "player", not opts.off) -- (votre équipe, si elle existe dans ce monde)
  end
  local log0 = #W().logs
  M.run_ticks(4 * MIN)
  local lines = {}
  for i = log0 + 1, #W().logs do
    local l = W().logs[i]
    if l:find("[FO-CAPI-EMPLACEMENTS] " .. tostring(f.key), 1, true) then lines[#lines + 1] = l end
  end
  Em.slots, Ca.blocked_items = o_slots, o_bl
  return { f = f, seen = seen, lines = lines, Em = Em }
end

local function has(lines, s)
  for _, l in ipairs(lines) do if l:find(s, 1, true) then return true end end
  return false
end

say("§1 temoin : rien ne dort, aucun ordre en manque (DEPENSES2 (c) seule)")
local a = run({})
local s1 = a.seen.first
check(s1 ~= nil and s1.busy and s1.comp == nil and s1.room_comp == 0, "§1 emplacements pleins, aucun siège (" .. tostring(s1 and s1.why) .. ")")
check(s1 ~= nil and a.Em.drill_refused(s1, "iron-plate"), "§1 foreuse de fer refusée « plan directeur occupe » : (c) seule ne débloque pas le cas B")
check(a.seen.short_ok == nil and not has(a.lines, "matiere qui manque"), "§1 jamais de siège sur la partie")

say("§2 lot : un ordre ouvert manque d'engrenages (fer en ingredient direct)")
local b = run({ gears = true })
check(b.seen.blocked ~= nil and b.seen.blocked["iron-gear-wheel"] and b.seen.blocked["iron-plate"],
  "§2 prédicat sur les recettes du relevé : engrenage et fer bloqués")
local s2 = b.seen.short_ok
say("§2 emplacements : " .. tostring(s2 and s2.why))
check(s2 ~= nil and s2.busy and s2.room == 0 and s2.room_comp == 1 and s2.comp and s2.comp["iron-plate"] == true
  and not s2.comp["copper-plate"], "§2 chemin de jeu (Capi.slots, Em.short) : plein, 1 siège pour le fer")
check(s2 ~= nil and not b.Em.drill_refused(s2, "iron-plate") and b.Em.drill_refused(s2, "copper-plate"),
  "§2 foreuses sur ce relevé : fer accordé, cuivre refusé")
check(s2 ~= nil and b.Em.order_seat(s2.room, s2.room_comp, s2.comp, "iron-plate") == "complement",
  "§2 ordre « couvrir » du fer : siège du complément")
check(has(b.lines, "+1 pour la matiere qui manque aux ordres ouverts (iron-plate)"),
  "§2 journal [FO-CAPI-EMPLACEMENTS] : +1 pour la matiere qui manque (iron-plate)")

say("§3 temoin du banc : meme cas que §2, regle 8 eteinte par remote.call(\"fo-capi\", \"manque\", cle, false)")
local c = run({ gears = true, off = true })
check(c.seen.remote == true, "§3 interrupteur accepte (fo-capi, manque)")
check(c.seen.blocked == nil, "§3 regle eteinte : le predicat partage n'est pas consulte (cs.no_short)")
check(c.seen.first ~= nil and c.seen.first.busy and c.seen.first.comp == nil and c.Em.drill_refused(c.seen.first, "iron-plate")
  and c.seen.short_ok == nil and not has(c.lines, "matiere qui manque"), "§3 regle eteinte : aucun siege, foreuse de fer refusee")
local d = run({ gears = true, off = false })
check(d.seen.remote == true and d.seen.short_ok ~= nil and d.seen.short_ok.comp and d.seen.short_ok.comp["iron-plate"] == true,
  "§3 rallumee (on = true) : le siege du fer revient")

print(string.format("[CHAMP-MANQUE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
