-- n099 (retour du DC sur la 0.9.8 : « l'équipe du joueur n'arrive pas à évoluer ») : le verrou des tiers (F677,
-- script/ai3/anti_dispersion.lua, AdRt.fonte_prouvee) prouve la fonte d'une plaque par une bande de champ finie qui fond. Une bande posée
-- sur un gisement SANS avant-poste (champ demandé par la capitalisation, f.migration.fields, numéro >= FIELD_BASE) doit compter comme une
-- bande d'avant-poste (f.outposts) : sinon une équipe dont tous les champs d'une plaque sont de ce genre (votre équipe, graine 4251870853 :
-- tout son cuivre) n'a jamais la fonte prouvée et ne pose AUCUN assembleur de la partie. Même lecture pour la source automatisée du mall.
-- Données changées (aucun nom du jeu) : la décision vient de la table des types d'avant-poste et des rôles du plan.
-- Usage : lua5.2 tests/n099_tiers_champ_test.lua (depuis la racine du mod)
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("[N099-TIERS] ECHEC : " .. msg) end end

local OUTPOSTS = {
  k1 = { resource = "zz-minerai-a", product = "zz-plaque-a" },
  k2 = { resource = "zz-minerai-b", product = "zz-plaque-b" },
  k3 = { resource = "zz-brut", product = "zz-brut" },
}
-- Modules du moteur remplacés (la garde ne lit que ce qui suit)
package.loaded["shared.team.config"] = { outposts = OUTPOSTS }
package.loaded["script.faction.state"] = { war = function() return { started = 0 } end }
package.loaded["script.core.profiler"] = { fstart = function() end, fstop = function() end }
package.loaded["script.team.registre_types"] = { list = function() return {} end }
_G.log = function() end
_G.defines = { entity_status = { working = 1 } }
_G.game = { tick = 0, get_filtered_entity_prototypes = function() return {} end }

local AdRt = require("script.ai3.anti_dispersion")
local Ch = require("shared.team.champ")

local FIELD = 100001 -- (numéro d'un champ de la capitalisation : la valeur de FIELD_BASE + 1 au moment du test, lue ci-dessous)

-- Une équipe : une bande finie d'un avant-poste (k1) et une bande finie d'un champ de la capitalisation (k2), un four de bande qui fond chacune.
local function team(with_field)
  local ents = {}
  local surface = { find_entity = function(name, pos) local e = ents[pos[1] .. ":" .. pos[2]]; return e end }
  local function four(x, y) ents[x .. ":" .. y] = { valid = true, status = 1, products_finished = 5, unit_number = x * 1000 + y }
    return { role = AdRt.ROLE_FOUR, name = "zz-four", x = x, y = y, built = true } end
  local f = {
    key = "zz-equipe", started = 0, team = {}, hq = { valid = true, surface = surface }, force = {},
    outposts = { [1] = { id = 1, kind = "k1" } },
    migration = { fields = {} },
    build = { order = { 1, 2 }, projects = {
      [1] = { id = 1, state = "fini", spec = { site = "champ", champ = { oid = 1 } }, ents = { four(10, 10) } },
      [2] = { id = 2, state = "fini", spec = { site = "champ", champ = { oid = FIELD } }, ents = { four(20, 20) } },
    } },
  }
  if with_field then f.migration.fields[FIELD] = { id = FIELD, kind = "k2", field = true } end
  return f
end

-- 1. La cible d'un champ : l'avant-poste, sinon le gisement de la capitalisation
do
  local f = team(true)
  check(Ch.target(f, 1) == f.outposts[1], "Ch.target rend l'avant-poste")
  check(Ch.target(f, FIELD) == f.migration.fields[FIELD], "Ch.target rend le champ de la capitalisation")
  check(Ch.target(f, 999) == nil and Ch.target(nil, 1) == nil and Ch.target(f, nil) == nil, "Ch.target : rien sinon")
end

-- 2. Fonte prouvée par la bande du champ de la capitalisation (le maillon n099)
do
  local f = team(true)
  game.tick = 3600
  local ok = AdRt.fonte_prouvee(f, 3600)
  check(ok == true, "fonte prouvee : bande d'avant-poste (k1) + bande d'un champ de la capitalisation (k2)")
  check(f.team.ad.fonte and f.team.ad.fonte["zz-plaque-b"] == true, "plaque du champ de la capitalisation prouvee")
  check(f.team.ad.fonte and f.team.ad.fonte["zz-plaque-a"] == true, "plaque de l'avant-poste prouvee")
end

-- 3. Sans la cible (numéro inconnu), la plaque n'est pas prouvée : la garde reste fermée (pas de preuve inventée)
do
  local f = team(false)
  game.tick = 3600
  local ok, manque = AdRt.fonte_prouvee(f, 3600)
  check(ok == false and manque == "zz-plaque-b", "champ inconnu : fonte de zz-plaque-b non prouvee (" .. tostring(manque) .. ")")
end

-- 4. Le champ de la capitalisation est sous FIELD_BASE+ : vérification de la constante du moteur (lue dans le source, pas recopiée)
do
  local fh = assert(io.open("script/team/champ.lua", "rb")); local src = fh:read("*a"); fh:close()
  local base = tonumber(src:match("Champ%.FIELD_BASE%s*=%s*(%d+)"))
  check(base ~= nil and FIELD > base, "numero du test au-dela de Champ.FIELD_BASE (" .. tostring(base) .. ")")
  -- le mall lit la même cible (source automatisée d'une plaque)
  local fm = assert(io.open("script/team/mall.lua", "rb")); local ms = fm:read("*a"); fm:close()
  check(ms:find("Ch.target(f, sp.champ.oid)", 1, true) ~= nil, "mall : source automatisee lue par Ch.target")
end

print(string.format("[N099-TIERS] %d OK, %d ECHEC(S)", ok_n, fail_n))
if fail_n > 0 then os.exit(1) end
