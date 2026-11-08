--[[
  Lots VIDEO-L6 et VIDEO-L10 : APPEL RÉEL de decide_start et decide_finish (script/ai3/capitalisation.lua) au moteur simulé, par une partie
  de 2 factions (Capi.think, décision découpée en tranches), réglages fo-war-portes et fo-war-paliers ALLUMÉS puis ÉTEINTS. Complète les
  contrôles par lecture du source (tests/portes_runtime_test.lua §4, tests/palier_runtime_test.lua §5), qui seuls ne suffisent pas (une
  ligne ajoutée les casse sans rien changer au comportement). Lancer depuis la racine du mod :
    lua5.2 tests/portes_paliers_moteur_test.lua   -> [L6L10-MOTEUR] BILAN : N OK, 0 ECHEC(S)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L6L10-MOTEUR] ECHEC : " .. msg) end
end
local MIN = 3600

local function patches() -- (même terrain que tests/capi_moteur_test.lua)
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

local function run(on, minutes)
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  local W = M.world()
  W.settings["fo-war-portes"] = on
  W.settings["fo-war-paliers"] = on
  M.load_mod()
  M.dispatch(W.on_init)
  M.command("fo-war", "start 2 30 30 320")
  local ok, err = pcall(M.run_ticks, minutes * MIN)
  local out = { ok = ok, err = err, capi = 0, portes = 0, palier = 0, st = {} }
  for _, l in ipairs(W.logs) do
    if l:find("[FO-CAPI]", 1, true) and l:find(" minute ", 1, true) then out.capi = out.capi + 1 end
    if l:find("[FO-PORTES]", 1, true) then out.portes = out.portes + 1 end
    if l:find("[FO-PALIER]", 1, true) then out.palier = out.palier + 1 end
  end
  for i = 1, 2 do
    local f = global.fo.war.factions[i]
    out.st[i] = f and f.team and f.team.capi or {}
  end
  return out
end

-- Réglages ALLUMÉS : decide_start (Capi.palier) et decide_finish (Capi.portes) tournent dans la vraie décision.
local on = run(true, 8)
check(on.ok, "allumes : partie sans erreur (" .. tostring(on.err) .. ")")
check(on.capi >= 2 * 5, "allumes : decisions de capitalisation jouees (" .. on.capi .. " lignes [FO-CAPI])")
local n_portes, n_palier = 0, 0
for i = 1, 2 do
  if on.st[i].portes then n_portes = n_portes + 1 end
  if on.st[i].palier then n_palier = n_palier + 1 end
end
check(n_portes == 2, "allumes : decide_finish a appele Capi.portes (etat cs.portes chez les 2 factions : " .. n_portes .. ")")
check(n_palier == 2, "allumes : decide_start a appele Capi.palier (etat cs.palier chez les 2 factions : " .. n_palier .. ")")
print(string.format("[L6L10-MOTEUR] allumes : %d decision(s), %d ligne(s) [FO-PORTES], %d ligne(s) [FO-PALIER] ; portes : %s ; palier : %s",
  on.capi, on.portes, on.palier,
  on.st[1].portes and string.format("fermee %s, %d fermeture(s)", tostring(on.st[1].portes.closed), on.st[1].portes.closes or 0) or "-",
  on.st[1].palier and string.format("marches %d, minuteur %s", on.st[1].palier.marches or 0, tostring(on.st[1].palier.until_tick)) or "-"))

-- Réglages ÉTEINTS : aucun état, aucune ligne, la décision tourne.
local off = run(false, 8)
check(off.ok, "eteints : partie sans erreur (" .. tostring(off.err) .. ")")
check(off.capi >= 2 * 5, "eteints : decisions jouees (" .. off.capi .. ")")
check(off.portes == 0 and off.palier == 0, "eteints : aucune ligne [FO-PORTES] ni [FO-PALIER] (" .. off.portes .. ", " .. off.palier .. ")")
check(off.st[1].portes == nil and off.st[2].portes == nil and off.st[1].palier == nil and off.st[2].palier == nil,
  "eteints : aucun etat cs.portes ni cs.palier")

print(string.format("[L6L10-MOTEUR] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
