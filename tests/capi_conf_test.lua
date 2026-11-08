--[[
  Lot VIDEO-L5 « confirmation observée », branchement au runtime (critère K7 de fo-logs/2026-11-07_VIDEO-INTEG/CRITERES.md), au moteur
  simulé (tests/mock_engine.lua, products_finished sur demande) : un assembleur posé SANS COURANT (statut no_power, rien produit)
  dans la base d'une faction.
    §1 au relevé qui suit sa pose : unité engagée (shared/ai3/confirmation.lua), son groupe n'a aucune unité confirmée (n_cap = 0),
       son objet est suspendu (cs.scan.hold) et la décision le voit (entrée de Ca.decide_begin) ;
    §2 à Cf.STALL : une ligne [FO-CAPI-CONF] « echec <objet> (unite N) cause courant », puis la suspension levée, n_cap reste 0 ;
    §3 une ligne de bilan [FO-CAPI-CONF] par relevé ;
    §4 mutant (relevé sans confirmation, Capi.MUT.sans_conf) : §1 à §3 échouent.
  Lot X10-S10 (décision du DC du 7/11, 17 h 47, QCM-7/11-X10, OBJECTIFS §4 : « Oui, factions lointaines plus lentes (Recommandé) ») :
  le relevé de la capitalisation revient tous les Capi.CYCLE = 12 PENSÉES (une minute à 300 ticks). §1 à §4 se jouent le joueur PRÈS
  de la faction (rythme normal, attendus d'avant S10, fenêtre de 13 min). §5 : la même partie, joueur LOIN (la faction pense toutes
  les Cd.SLOW = 600 ticks quand elle est calme, un relevé toutes les 2 min) : mêmes contrôles sur une fenêtre multipliée par la
  cadence (13 × Cd.SLOW / 300 = 26 min), ce qui revient à des attendus divisés par la cadence sur 13 min.
  Ce n'est pas une preuve en jeu. Usage : lua5.2 tests/capi_conf_test.lua   (depuis la racine du mod ; environ 1 min)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[CAPI-CONF] ECHEC : " .. msg) end
end
local function say(s) print("[CAPI-CONF] " .. s) end
local function W() return M.world() end
local MIN = 3600
local ITEM, RECIPE, MACHINE = "iron-chest", "iron-chest", "assembling-machine-1"

-- Gisements larges, comme tests/capi_moteur_test.lua.
local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local function group_of(cs)
  for _, g in ipairs((cs.scan or {}).machines or {}) do
    if g.entity == MACHINE and g.recipe == RECIPE then return g end
  end
  return nil
end

local Cd = require("shared.faction.cadence")

local function run(mutant, near)
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true,
    products_finished = true })
  M.load_mod()
  local Ca = package.loaded["shared.ai3.capitalisation"]
  local Capi = package.loaded["script.ai3.capitalisation"]
  local out = { held_seen = 0, decisions_after = 0, hold_after = 0, ok = true }
  local u_id = nil
  -- Sonde : chaque décision de la faction qui porte l'assembleur (son groupe est dans l'entrée) : objet suspendu vu ou non.
  local begin = Ca.decide_begin
  Ca.decide_begin = function(input, st)
    for _, g in ipairs(input.machines or {}) do
      if g.entity == MACHINE and g.recipe == RECIPE then
        if input.hold and input.hold[ITEM] then out.held_seen = out.held_seen + 1 end
        if out.failed_tick then
          out.decisions_after = out.decisions_after + 1
          if input.hold == nil or input.hold[ITEM] ~= nil then out.hold_after = out.hold_after + 1 end
        end
      end
    end
    return begin(input, st)
  end
  if mutant then Capi.MUT.sans_conf = true end
  M.dispatch(W().on_init)
  M.command("fo-war", "start 2 30 30 320")
  -- Lot X10-S10 : joueur à 30 tuiles au nord du QG de la faction (rythme normal) ; sinon il reste au départ, loin d'elle.
  local f1 = global.fo.war.factions[1]
  if near and f1 and f1.hq_pos then W().player.character.teleport({ x = f1.hq_pos.x, y = f1.hq_pos.y - 30 }) end
  local ok, err = pcall(M.run_ticks, MIN)
  local f = global.fo.war.factions[1]
  out.key = f and f.key or "?"
  if ok and f then
    local e = f.hq.surface.create_entity({ name = MACHINE, position = { x = f.hq_pos.x + 25.5, y = f.hq_pos.y + 25.5 }, force = f.force })
    e.set_recipe(RECIPE)
    rawset(e, "_status", defines.entity_status.no_power)
    u_id = e.unit_number
  end
  out.u = u_id
  local needle = "[FO-CAPI-CONF] " .. out.key .. " : echec " .. ITEM .. " (unite " .. tostring(u_id) .. ") cause courant"
  local bilan = "[FO-CAPI-CONF] " .. out.key .. " : bilan"
  local seen = #W().logs
  local scans0 = nil
  local window = near and 13 * MIN or math.floor(13 * MIN * Cd.SLOW / 300)
  for _ = 1, window do
    if not ok then break end
    ok, err = pcall(M.run_ticks, 1)
    local cs = f.team and f.team.capi
    if cs and cs.scan and cs.scan.tick == game.tick then
      out.scans = (out.scans or 0) + 1
      local g = group_of(cs)
      if g and out.first == nil then
        out.first = { n = g.n, n_cap = g.n_cap, hold = cs.scan.hold and cs.scan.hold[ITEM],
          st = cs.cf and cs.cf.ids[u_id] and cs.cf.ids[u_id].state }
      end
      if out.failed_tick and g then out.after = { n_cap = g.n_cap, hold = cs.scan.hold and cs.scan.hold[ITEM] } end
    end
    local logs = W().logs
    for i = seen + 1, #logs do
      if logs[i]:find(needle, 1, true) and not out.failed_tick then out.failed_tick = game.tick end
      if logs[i]:find(bilan, 1, true) then out.bilans = (out.bilans or 0) + 1 end
    end
    seen = #logs
  end
  out.ok, out.err = ok, err
  for i = 1, #W().logs do
    if W().logs[i]:find("[FO-CADENCE] " .. out.key .. " : cadence LENTE", 1, true) then out.lente = true end
  end
  Ca.decide_begin = begin
  Capi.MUT.sans_conf = nil
  return out
end

local function verdict(o, quiet)
  local fi = o.first or {}
  local af = o.after or {}
  local ok = {
    o.ok,
    fi.st == "engage" and fi.n_cap == 0 and (fi.n or 0) >= 1 and fi.hold ~= nil,
    o.held_seen >= 1,
    o.failed_tick ~= nil,
    o.failed_tick ~= nil and af.hold == nil and af.n_cap == 0 and o.decisions_after >= 1 and o.hold_after == 0,
    (o.bilans or 0) >= (o.scans or 1) and (o.scans or 0) >= 10,
  }
  local msgs = {
    "partie sans erreur (" .. tostring(o.err) .. ")",
    string.format("§1 relevé après la pose : unité %s engagée (%s), n_cap %s sur %s, objet suspendu (%s)", tostring(o.u), tostring(fi.st),
      tostring(fi.n_cap), tostring(fi.n), tostring(fi.hold)),
    string.format("§1 la décision voit la suspension (%d décision(s))", o.held_seen),
    string.format("§2 ligne [FO-CAPI-CONF] « echec %s (unite %s) cause courant » (tick %s)", ITEM, tostring(o.u), tostring(o.failed_tick)),
    string.format("§2 après l'échec : suspension levée (%s), n_cap %s, %d décision(s) dont %d encore suspendue(s)", tostring(af.hold),
      tostring(af.n_cap), o.decisions_after, o.hold_after),
    string.format("§3 une ligne de bilan par relevé (%d pour %d relevés)", o.bilans or 0, o.scans or 0),
  }
  local all = true
  for i = 1, #ok do
    if not quiet then check(ok[i], msgs[i]) end
    all = all and ok[i]
  end
  return all
end

local a = run(false, true)
say(string.format("§1-3 faction %s (joueur proche) : unité %s, %d relevé(s), %d bilan(s), échec au tick %s, suspension vue %d fois", a.key,
  tostring(a.u), a.scans or 0, a.bilans or 0, tostring(a.failed_tick), a.held_seen))
check(not a.lente, "§1-3 joueur pres de la faction : jamais en cadence lente")
verdict(a, false)

local b = run(true, true)
say(string.format("§4 mutant : %d bilan(s), échec %s, suspension vue %d fois", b.bilans or 0, tostring(b.failed_tick), b.held_seen))
check(not verdict(b, true), "§4 mutant refusé : relevé sans confirmation")

-- §5 Lot X10-S10 : joueur loin, faction lointaine et calme : un relevé toutes les 2 min ; fenêtre de 26 min (13 × la cadence).
local c = run(false, false)
say(string.format("§5 faction %s (lointaine) : %d relevé(s), %d bilan(s), échec au tick %s, suspension vue %d fois, fenêtre %d min", c.key,
  c.scans or 0, c.bilans or 0, tostring(c.failed_tick), c.held_seen, math.floor(13 * Cd.SLOW / 300)))
check(c.lente, "§5 la faction, loin du joueur, est passee en cadence lente")
check(verdict(c, true), "§5 faction lointaine et calme : §1 à §3 tiennent sur la fenêtre multipliée par la cadence (bilan par relevé, échec, suspension levée)")

print(string.format("[CAPI-CONF] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
