--[[
  Lot DEFENSE-AP : banc HORS JEU de l'extraction EFFONDRÉE (shared/team/electrique.lua, E.collapsed et son entrée dans E.thermal).
  Lancement, depuis la racine du mod : lua5.2 tests/effondrement_test.lua

  Mesure (fo-logs/2026-11-09_INTEG-MAX/base-g1618033988-47f3d637, carte à 600 %, 432 200 ticks) : 28 pièces d'avant-poste de fer détruites à
  48-50 min, foreuses de fer 19 -> 4, fer à 0 dès 60 min, et [FO-ZERO-IDLE] « iron = palier:électrique : thermique refusée » jusqu'à 90 min alors
  qu'aucune extension électrique du fer n'avance (5 électriques sur le fer, 32 à 37 ailleurs). Règle : le refus du thermique ne tient plus quand
  l'extraction de la ressource est tombée sous 50 % de son pic récent ET qu'aucune foreuse de plus n'a travaillé depuis 5 min ; une fois permise,
  elle le reste jusqu'au retour à 80 % du pic. Aucun nom d'objet.
    1. E.collapsed : entrée, hystérésis, pic inconnu ; 2. E.thermal : refus d'avant sans pic, refus tenu tant que le débit tient ou qu'une
    extension progresse, permis une fois effondrée ; 3. mutants.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function read_all(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local function load_module(src)
  local chunk, err = load(src, "=electrique", "t", _ENV)
  if not chunk then error(err) end
  return chunk()
end

local MIN = 3600
local SRC = read_all("shared/team/electrique.lua")

local function facts(E)
  local f = {}
  local C = E.collapsed
  f.enter = C({ active = 5, peak = 19, stalled = 6 * MIN })
  f.not_stalled = C({ active = 5, peak = 19, stalled = 1 * MIN })
  f.at_limit = C({ active = 10, peak = 20, stalled = 6 * MIN })        -- 50 % pile : pas effondrée
  f.below = C({ active = 9, peak = 20, stalled = 6 * MIN })            -- 45 %
  f.was_low = C({ active = 12, peak = 19, stalled = 0, was = true })   -- 63 % : reste permise même sans durée
  f.was_back = C({ active = 16, peak = 19, stalled = 0, was = true })  -- 84 % : rétablie
  f.was_edge = C({ active = 16, peak = 20, stalled = 0, was = true })  -- 80 % pile : rétablie
  f.nopeak = C({ active = 0, peak = 0, stalled = 99 * MIN })
  f.small_peak = C({ active = 0, peak = 3, stalled = 99 * MIN })   -- 3 foreuses au pic : mise en place, pas un effondrement
  f.small_edge = C({ active = 0, peak = 6, stalled = 99 * MIN })   -- 6 : compté
  f.nopeak_nil = C({ active = 3 })
  f.empty = C()
  local _, down = C({ active = 5, peak = 19, stalled = 1 * MIN })
  f.down_only = down
  -- lot ELAGAGE : un retrait VOLONTAIRE (paires rendues au stock par la migration) n'est pas une perte : le pic baisse d'autant
  -- (emerald, 271828182 : 20 paires balayées, « 16 actives pour un pic de 36 » : EFFONDREE, thermiques reposées, rebalayées 6 fois)
  local pk, seen = E.peak_less(36, 20, 0)
  f.vol_peak, f.vol_seen = pk, seen
  f.vol_calm = C({ active = 16, peak = pk, stalled = 6 * MIN })
  f.vol_once = (E.peak_less(pk, 20, seen))        -- le même cumul n'est retranché qu'une fois
  f.vol_more = (E.peak_less(pk, 25, seen))        -- 5 de plus : 11
  f.vol_floor = (E.peak_less(3, 9, 0))            -- jamais négatif
  f.vol_nil = (E.peak_less(12, nil, nil))
  -- E.thermal : bascule en marche, 37 électriques ailleurs, 5 sur le fer
  local base = { obtainable = true, plants = 1, poles = true, healthy = true, el_live = 37, poles_stock = 20, res_live = 5 }
  local function th(over)
    local s = {}
    for k, v in pairs(base) do s[k] = v end
    for k, v in pairs(over or {}) do s[k] = v end
    return E.thermal(s)
  end
  f.refused_old = th()                                                               -- sans pic : le refus d'avant
  f.refused_ok = th({ res_peak = 19, res_active = 17, res_stalled = 9 * MIN })       -- débit tenu
  f.refused_progress = th({ res_peak = 19, res_active = 5, res_stalled = 1 * MIN })  -- effondré mais une extension progresse
  local ok, why = th({ res_peak = 19, res_active = 5, res_stalled = 6 * MIN })
  f.permitted, f.permitted_why = ok, (why or ""):find("effondree", 1, true) ~= nil
  f.permitted_was = th({ res_peak = 19, res_active = 12, res_stalled = 0, res_was = true })
  f.refused_back = th({ res_peak = 19, res_active = 16, res_stalled = 0, res_was = true })
  f.other_reason = th({ res_peak = 19, res_active = 5, res_stalled = 6 * MIN, plants = 0 })  -- une autre cause permet déjà
  return f
end

local E0 = load_module(SRC)
local F0 = facts(E0)
check(F0.enter == true and F0.not_stalled == false, "entrée : 5 foreuses pour un pic de 19 sans foreuse de plus depuis 6 min -> effondrée ; 1 min -> pas encore")
check(F0.at_limit == false and F0.below == true, "seuil : 50 % pile n'est pas effondré, 45 % l'est")
check(F0.down_only == true, "le second retour dit « sous le seuil » même avant la durée (journal)")
check(F0.was_low == true and F0.was_back == false and F0.was_edge == false, "hystérésis : déjà permise, 63 % du pic reste permis sans durée ; 84 % et 80 % rétablissent")
check(F0.small_peak == false and F0.small_edge == true, "pic de 3 foreuses : jamais effondré ; pic de 6 : oui")
check(F0.nopeak == false and F0.nopeak_nil == false and F0.empty == false, "pic nul, inconnu ou entrée vide : jamais effondré")
check(F0.refused_old == false, "témoin : sans pic, thermique refusée comme avant (37 électriques ailleurs, 5 sur la ressource)")
check(F0.refused_ok == false and F0.refused_progress == false, "débit tenu (17 sur 19) ou extension qui progresse (1 min) : le refus tient")
check(F0.permitted == true and F0.permitted_why, "effondrée et à l'arrêt : thermique permise, raison « effondree »")
check(F0.permitted_was == true and F0.refused_back == false, "permise tant que le débit n'est pas revenu à 80 % ; refusée de nouveau ensuite")
check(F0.other_reason == true, "une autre raison de permettre (aucune centrale) reste vraie")

check(F0.vol_peak == 16 and F0.vol_seen == 20 and F0.vol_calm == false, "retrait volontaire de 20 : pic 36 -> 16, 16 actives : pas effondrée")
check(F0.vol_once == 16 and F0.vol_more == 11 and F0.vol_floor == 0 and F0.vol_nil == 12, "cumul retranché une seule fois, jamais négatif, absent : pic inchangé")

local mutants = {
  { "retrait volontaire non retranché", "return max(0, (num(peak) or 0) - d), max(s, r)", "return (num(peak) or 0), max(s, r)" },
  { "cumul retranché à chaque pensée", "local d = max(0, r - s)", "local d = r" },
  { "pic négatif", "return max(0, (num(peak) or 0) - d), max(s, r)", "return (num(peak) or 0) - d, max(s, r)" },
  { "entrée sans durée", "return down and (a.was == true or (num(a.stalled) or 0) >= cfg.stall), down", "return down, down" },
  { "toujours à l'arrêt", "return down and (a.was == true or (num(a.stalled) or 0) >= cfg.stall), down", "return down and (a.was == true or true), down" },
  { "sans hystérésis", "return down and (a.was == true or (num(a.stalled) or 0) >= cfg.stall), down", "return down and (num(a.stalled) or 0) >= cfg.stall, down" },
  { "seuil de sortie = entrée", "local limit = a.was and cfg.recover_pct or cfg.collapse_pct", "local limit = cfg.collapse_pct" },
  { "seuil inclusif", "local down = active * 100 < peak * limit", "local down = active * 100 <= peak * limit" },
  { "entrée jamais lue par E.thermal", "if s.res_peak ~= nil and (E.collapsed(", "if false and (E.collapsed(" },
  { "E.thermal ignore la durée", "stalled = s.res_stalled, was = s.res_was }, cfg))", "stalled = 99999999, was = s.res_was }, cfg))" },
  { "E.thermal ignore l'hystérésis", "stalled = s.res_stalled, was = s.res_was }, cfg))", "stalled = s.res_stalled, was = nil }, cfg))" },
  { "seuil d'effondrement à 90", "collapse_pct = 50,", "collapse_pct = 90," },
  { "pic minimal ignoré", "peak_min = 6,", "peak_min = 0," },
  { "pic minimal inclusif", "or peak < cfg.peak_min then", "or peak <= cfg.peak_min then" },
  { "seuil de retour à 40", "recover_pct = 80,", "recover_pct = 40," },
  { "durée nulle", "stall = 5 * 3600,", "stall = 0," },
}
local killed = 0
for _, m in ipairs(mutants) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    check(false, "mutant « " .. m[1] .. " » : texte introuvable")
  else
    local ok, EM = pcall(load_module, SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local dead = not ok
    if ok then
      local okf, FM = pcall(facts, EM)
      if not okf then dead = true else
        for k, v in pairs(F0) do if FM[k] ~= v then dead = true end end
      end
    end
    if dead then killed = killed + 1 end
    check(dead, "mutant « " .. m[1] .. " » refusé")
  end
end
print(string.format("[EFFONDREMENT] mutants refusés : %d / %d", killed, #mutants))
print(string.format("[EFFONDREMENT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
