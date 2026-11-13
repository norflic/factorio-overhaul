--[[
  ANTI-DISPERSION, côté RUNTIME (lot IA-GARDE ; règle pure et définitions : shared/ai3/anti_dispersion.lua). Seul lecteur du jeu pour la
  garde : il MESURE, une fois par minute et par équipe (factions et votre équipe), les colonnes de fonderie automatisées (bandes du champ du
  plan directeur) et les assembleurs actifs de la force, garde l'état dans f.team.ad, et répond aux points de décision :
    - script/ai3/exploration.lua : AdRt.permet(f, "exploration", ...) à l'ouverture d'une demande d'exploration et au départ d'une veille ;
    - script/ai3/petrole.lua : AdRt.permet(f, "petrole") avant la décision d'un site, l'extension d'un champ de puits et les fabrications
      d'un site pas fini ;
    - script/ai3/cerveau.lua : AdRt.cerveau(f, tick) passe l'état et les sortes de démarrage à la pensée pure (shared/ai3/cerveau.lua filtre
      les buts de sur-stockage d'un minerai brut) ; AdRt.compte(f, ...) compte ce qu'elle a inhibé ;
    - script/team/migration_champ.lua : AdRt.permet(f, "surstock", ...) avant la demande d'une bande d'un minerai brut.
  Journal [FO-ANTI-DISPERSION] : une ligne à chaque changement d'état (première mesure, ouverture, fermeture) et à la première décision
  inhibée de chaque famille pendant une fermeture (shared/ai3/anti_dispersion.lua, Ad.mesure et Ad.inhibe), 80 lignes au plus par équipe.
  État (f.team.ad, nombres, booléens, chaînes) : { next (tick de la prochaine mesure), ouvert, colonnes, assembleurs, inh = { [famille] = n },
  dites = { [famille] = true }, lignes, pf = { [unit_number] = produits finis à la mesure précédente } }.
  Aucun nom d'objet : types de prototypes du moteur, rôles du plan du champ, catégories lues aux prototypes, table des types d'avant-poste.
]]

local Ad = require("shared.ai3.anti_dispersion")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Profiler = require("script.core.profiler") -- lot UPS : portées fines « ws: » (recherches sur toute la surface ; mesure seulement)

local AdRt = {}

AdRt.EVERY = 3600 -- ticks entre deux mesures d'une équipe (une minute)
AdRt.ASM_TYPE = "assembling-machine" -- type de prototype du moteur (LuaEntityPrototype.type), pas un nom d'objet
AdRt.FOUR_TYPE = "furnace"
AdRt.ROLE_FOUR = "champ-four" -- rôle des fours d'une bande au plan du champ (shared/team/champ.lua)

local SORTES = Ad.demarrage(T.outposts) -- table de configuration : la même sur tous les pairs, jamais dans global
local FOUR_CATS = nil -- catégories de fabrication des prototypes de type four (lues une fois aux prototypes, au premier usage)

local function four_cats()
  if FOUR_CATS then return FOUR_CATS end
  local out = {}
  local ok, protos = pcall(function() return game.get_filtered_entity_prototypes({ { filter = "type", type = AdRt.FOUR_TYPE } }) end)
  if ok and protos then
    for _, p in pairs(protos) do -- (ensemble : l'ordre ne compte pas)
      for cat in pairs(p.crafting_categories or {}) do out[cat] = true end
    end
  end
  FOUR_CATS = out
  return out
end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

local function key_of(f) return f.key or "player" end

local function sorted_keys(t)
  local out = {}
  for k in pairs(t or {}) do out[#out + 1] = k end
  table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
  return out
end

local function memo_of(f)
  if not f.team then return nil end
  f.team.ad = f.team.ad or { next = 0 }
  return f.team.ad
end

--- Mesure (colonnes, assembleurs) sur le jeu ; nil quand l'équipe n'a ni QG ni surface (moteur partiel).
local function measure(f, memo)
  local surface = f.hq and f.hq.valid and f.hq.surface or nil
  if not surface then return nil end
  local W = defines and defines.entity_status and defines.entity_status.working or nil -- (moteur simulé sans états : jamais « travaille »)
  local prev, cur = memo.pf or {}, {}
  local function moved(e)
    local n = e.products_finished or 0
    local u = e.unit_number
    local before = u and prev[u] or nil
    if u then cur[u] = n end
    return (W ~= nil and e.status == W) or (before ~= nil and n > before)
  end
  -- colonnes : bandes du champ finies, fours posés et présents, au moins un qui fond
  local colonnes = 0
  local b = f.build
  for _, pid in ipairs((b and b.order) or {}) do
    local p = b.projects[pid]
    local qc = p and p.spec and p.spec.champ
    if qc and p.state == "fini" then -- (le projet du réseau du charbon n'a aucun four de bande : jamais une colonne)
      local fours, actifs = 0, 0
      for _, e in ipairs(p.ents or {}) do
        if e.role == AdRt.ROLE_FOUR and e.built and not e.skipped and not e.dropped then
          local ent = surface.find_entity(e.name, { e.x, e.y })
          if ent and ent.valid then
            fours = fours + 1
            if moved(ent) then actifs = actifs + 1 end
          end
        end
      end
      if Ad.colonne({ bande = true, etat = p.state, fours = fours, fours_actifs = actifs }) then colonnes = colonnes + 1 end
    end
  end
  -- assembleurs actifs de la force
  local assembleurs = 0
  local cats = four_cats()
  Profiler.fstart("ws:antidisp")
  local ok, list = pcall(function() return surface.find_entities_filtered({ type = AdRt.ASM_TYPE, force = f.force }) end)
  Profiler.fstop("ws:antidisp")
  for _, e in ipairs((ok and list) or {}) do
    if e.valid then
      local r = e.get_recipe and e.get_recipe() or nil
      local u = e.unit_number
      local before = u and prev[u] or nil
      local n = e.products_finished or 0
      if u then cur[u] = n end
      if Ad.assembleur({ assembleur = e.type == AdRt.ASM_TYPE, recette = r and r.name or nil, categorie = r and r.category or nil, fours = cats,
        travaille = W ~= nil and e.status == W, fini = n, fini_avant = before }) then
        assembleurs = assembleurs + 1
      end
    end
  end
  memo.pf = cur
  return Ad.etat(colonnes, assembleurs)
end

--- État de la garde pour l'équipe (mesuré au plus une fois par AdRt.EVERY ticks), ou nil (pas de mesure possible).
function AdRt.etat(f, tick)
  local memo = memo_of(f)
  if not memo then return nil end
  tick = tick or game.tick
  if tick >= (memo.next or 0) then
    memo.next = tick + AdRt.EVERY
    local etat = measure(f, memo)
    if etat then
      local txt = Ad.mesure(memo, etat, key_of(f), minutes(f, tick))
      if txt then log("[FO-ANTI-DISPERSION] " .. txt) end
    end
  end
  if memo.ouvert == nil then return nil end
  return { ouvert = memo.ouvert, colonnes = memo.colonnes or 0, assembleurs = memo.assembleurs or 0 }
end

--- Une décision inhibée ailleurs (pensée pure) : comptée et dite à la première de sa famille.
function AdRt.compte(f, famille, n, tick)
  local memo = memo_of(f)
  if not memo or memo.ouvert ~= false then return end
  for _ = 1, (n or 1) do
    local txt = Ad.inhibe(memo, famille, key_of(f), minutes(f, tick or game.tick))
    if txt then log("[FO-ANTI-DISPERSION] " .. txt) end
  end
end

--- La décision serait-elle permise ? Sans compter (l'appelant compte, AdRt.compte, quand une décision a vraiment été retenue).
function AdRt.voit(f, famille, c, tick)
  return (Ad.permet(AdRt.etat(f, tick or game.tick), famille, c))
end

--- La décision est-elle permise ? Compte et journalise une inhibition. c : contexte de shared/ai3/anti_dispersion.lua (Ad.permet).
function AdRt.permet(f, famille, c, tick)
  tick = tick or game.tick
  local etat = AdRt.etat(f, tick)
  local ok, why = Ad.permet(etat, famille, c)
  if not ok then AdRt.compte(f, famille, 1, tick) end
  return ok, why
end

--- Sorte de démarrage d'une ressource (« brut », « fondre ») ou nil ; d'un type d'avant-poste.
function AdRt.sorte(res) return SORTES[res] end
function AdRt.sorte_type(kind) return Ad.sorte_type(T.outposts, kind) end

--- Besoin mesuré de la matière `item` à la dernière pensée du cerveau (manque par rapport au besoin, ou manque propre).
function AdRt.manque(f, item)
  local st = f.team and f.team.ia3
  if not (st and item) then return false end
  return (st.starved_open or {})[item] == true or ((st.short_core or {})[item] or 0) > 0
end

--- L'équipe tient-elle déjà la ressource `res` (un avant-poste d'un type qui l'extrait) ?
function AdRt.tient(f, res)
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local spec = o and T.outposts[o.kind]
    if spec and spec.resource == res then return true end
  end
  return false
end

--- Entrée de la pensée pure (ctx.dispersion de shared/ai3/cerveau.lua) : { ouvert, sortes = { [type] = sorte } } ou nil.
function AdRt.cerveau(f, tick)
  local etat = AdRt.etat(f, tick)
  if not etat then return nil end
  local sortes = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do sortes[kind] = Ad.sorte_type(T.outposts, kind) end
  return { ouvert = etat.ouvert, colonnes = etat.colonnes, assembleurs = etat.assembleurs, sortes = sortes }
end

return AdRt
