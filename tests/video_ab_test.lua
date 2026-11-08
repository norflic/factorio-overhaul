--[[
  Lot TV-METHODE (TODO vidéo C25, l.320 : « résoudre sans casser ce qui marche » : comparaison A/B octet à octet ; D05, l.260 :
  temps de réglage). Pour CHAQUE réglage de la vidéo (settings/video.lua), sur une même partie du moteur simulé (tests/mock_engine.lua,
  deux factions, mêmes entrées que tests/portes_paliers_moteur_test.lua) :
    (a) réglage ÉTEINT (faux) : journal ET état de global identiques à l'octet près à la partie de RÉFÉRENCE, où le réglage est
        ABSENT (repli « éteint » de chaque lecteur : l'ancien comportement, avant le lot VIDEO) ;
    (b) réglage ALLUMÉ (vrai) : CHANGE au moins une décision (journal ou état différent de la partie éteinte).
  Témoin de déterminisme : deux parties de référence identiques à l'octet (sans cela, (a) ne prouverait rien).
  Mutants : pour chaque réglage, un mutant qui force le lecteur à « allumé » (doit casser (a)) et un qui le force à « éteint »
  (doit casser (b)). Un mutant remplace le texte d'un VRAI fichier source, chargé par un chargeur de require.

  ÉCARTS CONNUS (comptés à part, jamais un OK) : pour fo-war-lots-minerai et fo-debug-trace-carte, la partie de 30 minutes ne mène
  à aucune décision du réglage (vérifié : zéro ligne [FO-TRACE] ni [FO-LOTS-MINERAI] en allumé). Leur (b) et leur mutant « éteint »
  ne sont donc PAS prouvés au moteur simulé ici ; (a) l'est. Lever l'écart = une partie qui envoie des ordres (trace) ou pose un lot
  de minerai (lots), puis passer b_couvert à vrai.

  Lancer depuis la racine du mod :  lua5.2 tests/video_ab_test.lua   -> [VIDEO-AB] BILAN : N OK, 0 ECHEC(S), E ECART(S) CONNU(S)

  Coût du réglage (D05, mesure au moteur simulé) : nombre de parties jouées et minutes de jeu simulées, au BILAN.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local pass, fail, gaps = 0, 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[VIDEO-AB] ECHEC : " .. msg) end
end
-- Écart connu : une comparaison NON PROUVABLE sur cette partie, comptée à part.
local function gap(msg)
  gaps = gaps + 1
  print("[VIDEO-AB] ECART CONNU : " .. msg)
end

local MIN = 3600
local MINUTES = 8 -- même durée que tests/portes_paliers_moteur_test.lua (16 s pour deux parties)

-- Les quatre réglages de la vidéo : balise de journal, module qui les lit (texte exact à remplacer par un mutant), couverture de (b).
local REGLAGES = {
  { name = "fo-war-portes", tag = "[FO-PORTES]", module = "script.ai3.capitalisation", path = "script/ai3/capitalisation.lua",
    old = "settings.global[Capi.PORTES_SETTING].value end)\n  return ok and v == true", b_couvert = true },
  { name = "fo-war-paliers", tag = "[FO-PALIER]", module = "script.ai3.capitalisation", path = "script/ai3/capitalisation.lua",
    old = "settings.global[Capi.PALIERS_SETTING].value end)\n  return ok and v == true", b_couvert = true },
  { name = "fo-war-lots-minerai", tag = "[FO-LOTS-MINERAI]", module = "script.team.lots_minerai_glue", path = "script/team/lots_minerai_glue.lua",
    old = "  local ok, v = pcall(read_setting)\n  return ok and v == true", b_couvert = false,
    ecart = "aucune ligne [FO-LOTS-MINERAI] sur la partie « fo-war start 2 » (30 min) : l'équipe du joueur ne pose pas de lot de minerai" },
  { name = "fo-debug-trace-carte", tag = "[FO-TRACE]", module = "script.ai3.trace_carte", path = "script/ai3/trace_carte.lua",
    old = "settings.global[TC.SETTING].value end)\n  return ok and v == true", b_couvert = false,
    ecart = "aucune ligne [FO-TRACE] sur la partie « fo-war start 2 » (30 min) : aucun ordre de faction n'est envoyé (TC.note jamais appelé)" },
}

-- Mutant courant (nil : le code réel). Lu par le chargeur de require ci-dessous, à chaque chargement du module visé.
local MUTANT = nil
table.insert(package.searchers, 1, function(name)
  if not MUTANT or name ~= MUTANT.module then return nil end
  local f = assert(io.open(MUTANT.path, "rb"))
  local src = f:read("*a")
  f:close()
  local i, j = src:find(MUTANT.old, 1, true)
  assert(i, "mutant : texte introuvable dans " .. MUTANT.path)
  assert(not src:find(MUTANT.old, j + 1, true), "mutant : texte non unique dans " .. MUTANT.path)
  local m = src:sub(1, i - 1) .. MUTANT.new .. src:sub(j + 1)
  return assert(load(m, "=" .. MUTANT.path))
end)

local function patches() -- (même terrain que tests/portes_paliers_moteur_test.lua)
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

-- Une partie. setting = nom du réglage, value = true | false | "absent" (non déclaré : repli « éteint »).
-- Les autres réglages de la vidéo sont ABSENTS partout : chaque réglage est testé seul.
local parties, minutes = 0, 0
local function run(setting, value, label)
  parties = parties + 1
  minutes = minutes + MINUTES
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  local W = M.world()
  if setting and value ~= "absent" then W.settings[setting] = value end
  M.load_mod()
  M.dispatch(W.on_init)
  M.command("fo-war", "start 2 30 30 320")
  local ok, err = pcall(M.run_ticks, MINUTES * MIN)
  check(ok, label .. " : partie sans erreur (" .. tostring(err) .. ")")
  local ok_s, state = pcall(M.serialize, global)
  return {
    ok = ok, err = err,
    journal = table.concat(W.logs, "\n"),
    state = ok_s and state or ("ERREUR DE SERIALISATION : " .. tostring(state)),
  }
end

local function count(journal, tag)
  local n = 0
  for line in (journal .. "\n"):gmatch("(.-)\n") do
    if line:find(tag, 1, true) then n = n + 1 end
  end
  return n
end

print("== 0. Référence et déterminisme")
local REF = run(nil, nil, "référence (tous absents)")
local REF2 = run(nil, nil, "référence bis")
check(REF.journal == REF2.journal and REF.state == REF2.state, "déterminisme : deux parties absentes identiques à l'octet")
check(count(REF.journal, "[FO-CAPI]") >= 2 * 5,
  "la partie de référence joue des décisions de capitalisation (" .. count(REF.journal, "[FO-CAPI]") .. " lignes [FO-CAPI])")

print("== 1. A/B par réglage (éteint puis allumé, contre l'absent)")
local AB = {}
for _, r in ipairs(REGLAGES) do
  local off = run(r.name, false, r.name .. " éteint")
  local on = run(r.name, true, r.name .. " allumé")
  AB[r.name] = { off = off, on = on }
  -- (a) : éteint = référence, à l'octet près, journal et état.
  check(off.journal == REF.journal, "(a) " .. r.name .. " éteint : journal différent de la référence (" .. #off.journal .. " contre " .. #REF.journal .. " octets)")
  check(off.state == REF.state, "(a) " .. r.name .. " éteint : état global différent de la référence (octet près)")
  check(count(off.journal, r.tag) == 0, "(a) " .. r.name .. " éteint : des lignes " .. r.tag .. " apparaissent")
  -- (b) : allumé change au moins une décision.
  local changed = on.journal ~= off.journal or on.state ~= off.state
  if r.b_couvert then
    check(changed, "(b) " .. r.name .. " allumé : aucune décision changée (journal et état identiques à l'éteint)")
  elseif changed then
    print("  (b) " .. r.name .. " : une décision change désormais : lever l'écart (passer b_couvert à vrai)")
    check(true, "")
  else
    check(count(on.journal, r.tag) == 0, "(b) écart " .. r.name .. " : des lignes " .. r.tag .. " apparaissent, écart à relire")
    gap("(b) " .. r.name .. " allumé non prouvé au moteur simulé : " .. r.ecart)
  end
  print(string.format("  %-22s allumé : %d ligne(s) %s ; journal %d o -> %d o ; état %s",
    r.name, count(on.journal, r.tag), r.tag, #off.journal, #on.journal, on.state == off.state and "identique" or "différent"))
end

print("== 2. Mutants (chaque mutant doit être REFUSÉ par la comparaison qui le vise)")
local function mutant(r, kind, expected)
  -- Réglage sans décision sur cette partie : le code du lecteur n'y est pas atteint, un mutant y survit (vérifié : « allume » aussi).
  if not r.b_couvert then
    gap("mutant « " .. kind .. " » de " .. r.name .. " : non testable sur cette partie (le code du réglage n'y mène à aucune décision)")
    return
  end
  -- Le mutant ne change que la dernière ligne du lecteur (« return ok and v == true » devient « return true » ou « return false »).
  local new = r.old:gsub("return ok and v == true$", kind == "allume" and "return true" or "return false")
  assert(new ~= r.old, "mutant : la dernière ligne du lecteur n'a pas été trouvée")
  MUTANT = { module = r.module, path = r.path, old = r.old, new = new }
  local ok_m, res = pcall(function()
    local off = run(r.name, false, r.name .. " mutant " .. kind .. " éteint")
    local on = run(r.name, true, r.name .. " mutant " .. kind .. " allumé")
    local got = {}
    if off.journal ~= REF.journal or off.state ~= REF.state then got.a = true end
    if on.journal == off.journal and on.state == off.state then got.b = true end
    return got
  end)
  MUTANT = nil
  if not ok_m then print("  erreur pendant le mutant : " .. tostring(res)) end
  check(ok_m and res[expected] == true,
    string.format("mutant « %s » de %s non refusé par (%s)", kind, r.name, expected))
end

for _, r in ipairs(REGLAGES) do
  mutant(r, "allume", "a")
  mutant(r, "eteint", "b")
end

print("== 3. Coût du réglage (D05)")
print(string.format("  parties jouées : %d ; minutes de jeu simulées : %d", parties, minutes))

print(string.format("[VIDEO-AB] BILAN : %d OK, %d ECHEC(S), %d ECART(S) CONNU(S) ; coût : %d parties, %d minutes simulées",
  pass, fail, gaps, parties, minutes))
os.exit(fail == 0 and 0 or 1)
