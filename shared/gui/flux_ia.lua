--[[
  Lot UI-FLUX (chantier 4 du DC, nuit du 15/11) : règles PURES du panneau « Flux de l'IA » (script/gui/flux.lua). Aucune API Factorio,
  aucun nom d'objet : les matières suivies et leurs quantités viennent de l'appelant (shared/team/config.lua, T.outposts, et les projets
  que l'IA tient DÉJÀ). Testé hors jeu : tests/flux_ia_test.lua.

  Rien de ce module n'est une comptabilité de l'IA : c'est une LECTURE de ses engagements.
    - un projet du plan directeur (f.build.projects, état, `created`, spec) engage le coût en matières premières de ce qu'il lui reste
      à poser (Build.needs_of, dépliée par le livre de recettes en plaques / pierre / charbon) ;
    - les buts de l'IA3 (f.team.ia3.projects : famille, `opened`) donnent l'heure de lancement des catégories qui n'ont pas de projet du
      plan directeur (recherche, défense) ;
    - le stock libre est celui du besoin évalué (f.team.ia3.noyau.free) ou, à défaut, le contenu du coffre.

  Catégories (ordre d'affichage) : champ (rangées de foreuses), fonderies, énergie, mall / usines, recherche, défense.
  Déterminisme : l'ordre d'affichage est fixe (Fx.CATS), aucune sortie ne dépend d'un `pairs`.
]]

local Fx = {}

Fx.CATS = { "champ", "fonderies", "energie", "mall", "recherche", "defense" }
Fx.FREE = "libre" -- clé de la barre « stock libre »
-- États d'un projet du plan directeur qui n'engagent plus rien (fini, annulé).
Fx.DONE = { fini = true, refuse = true }

--- Catégorie d'un projet du plan directeur d'après sa `spec` (table de Build.request), ou nil (hors catégorie).
--- Ordre des règles : la défense et l'énergie d'abord (une enceinte, une centrale ou une ligne électrique n'est ni un champ ni une usine),
--- puis la recherche (laboratoires et paquets), le mall, la fonderie, le champ ; tout autre générateur de gabarit est une usine.
function Fx.classify(spec)
  if type(spec) ~= "table" then return nil end
  if spec.enceinte or spec.walls or spec.tourelles or spec.defense then return "defense" end
  if spec.alim or spec.alimquai or spec.plant or spec.gen == "steam" or spec.site == "ligne_bande" then return "energie" end
  local gen = type(spec.gen) == "string" and spec.gen or nil
  if gen == "labs" or (gen and gen:sub(-5) == "packs") then return "recherche" end
  if spec.site == "mall" or spec.mall or spec.liaison or spec.piquage then return "mall" end
  if gen == "smelter" or spec.furnace then return "fonderies" end
  if spec.champ or spec.site == "champ" or spec.rapatriement or gen == "drills" then return "champ" end
  if spec.site == "petrole" or gen or spec.key then return "mall" end
  return nil
end

--- Catégorie d'un but de l'IA3 (f.team.ia3.projects[i].family), ou nil : seules les familles qui n'ont pas de projet du plan directeur.
Fx.FAMILY_CAT = { recherche = "recherche", defense = "defense", armee = "defense", proteger = "defense", preparer = "defense",
  extraction = "champ", couverture = "champ", migration = "champ", foreuses = "champ" }
function Fx.family_cat(family) return Fx.FAMILY_CAT[family or ""] end

local function num(x) return type(x) == "number" and x == x and x or 0 end

--- Pourcentage entier arrondi de n sur total (0 si total <= 0).
function Fx.pct(n, total)
  if num(total) <= 0 then return 0 end
  return math.floor(num(n) * 100 / total + 0.5)
end

--- mm:ss d'une durée en ticks (60 par seconde) ; « --:-- » si la durée est inconnue.
function Fx.mmss(ticks)
  if type(ticks) ~= "number" or ticks ~= ticks or ticks < 0 then return "--:--" end
  local s = math.floor(ticks / 60)
  return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

--- Un projet du plan directeur est-il ACTIF (engage encore quelque chose) ?
function Fx.active(state) return state ~= nil and not Fx.DONE[state] end

--- Synthèse. inp = {
---   tick,
---   resources = { matière, ... }                   (ordre d'affichage),
---   builds    = { { cat, created, raw = { [matière] = n } } }   projets ACTIFS du plan directeur (raw : coût restant en matières premières),
---   goals     = { { cat, opened } }                  buts actifs de l'IA3 (heure de lancement seulement),
---   extra     = { [cat] = { [matière] = n } }        engagements hors projets (demande de défense, paquets de la recherche en cours),
---   starts    = { [cat] = tick }                     lancements connus d'ailleurs (facultatif),
---   free      = { [matière] = n }                    stock libre }.
--- Rend { res = { [matière] = { total, bars = { { cat, n, pct } } } }, cats = { [cat] = { n, pct, count, since } }, engaged, other }.
--- bars : une entrée par catégorie à quantité > 0 puis « libre » ; pct = part de la matière (stock libre compris) ;
--- cats[c].pct = part du total engagé (toutes matières suivies, hors stock libre) ; since = ticks depuis le plus ancien lancement actif.
function Fx.summarize(inp)
  local cat_n, cat_count, cat_start, other = {}, {}, {}, 0
  local per = {}
  for _, c in ipairs(Fx.CATS) do cat_n[c], cat_count[c], per[c] = 0, 0, {} end
  local function start(c, t)
    if t and (cat_start[c] == nil or t < cat_start[c]) then cat_start[c] = t end
  end
  local tracked = {}
  for _, r in ipairs(inp.resources or {}) do tracked[r] = true end
  for _, b in ipairs(inp.builds or {}) do
    if b.cat and per[b.cat] then
      cat_count[b.cat] = cat_count[b.cat] + 1
      start(b.cat, b.created)
      for _, r in ipairs(inp.resources or {}) do
        local n = num((b.raw or {})[r])
        if n > 0 then per[b.cat][r] = (per[b.cat][r] or 0) + n end
      end
    else
      other = other + 1
    end
  end
  for _, g in ipairs(inp.goals or {}) do
    if g.cat and per[g.cat] then start(g.cat, g.opened) end
  end
  for c, t in pairs(inp.starts or {}) do
    if per[c] then start(c, t) end -- (`pairs` sans effet : minimum de lancements, commutatif)
  end
  for _, c in ipairs(Fx.CATS) do
    local ex = (inp.extra or {})[c]
    if ex then
      for _, r in ipairs(inp.resources or {}) do
        local n = num(ex[r])
        if n > 0 then per[c][r] = (per[c][r] or 0) + n end
      end
    end
  end
  local out = { res = {}, cats = {}, other = other, engaged = 0 }
  for _, r in ipairs(inp.resources or {}) do
    local bars, total = {}, 0
    for _, c in ipairs(Fx.CATS) do
      local n = per[c][r] or 0
      if n > 0 then
        bars[#bars + 1] = { cat = c, n = n }
        total = total + n
        cat_n[c] = cat_n[c] + n
        out.engaged = out.engaged + n
      end
    end
    local free = num((inp.free or {})[r])
    if free > 0 then
      bars[#bars + 1] = { cat = Fx.FREE, n = free }
      total = total + free
    end
    for _, b in ipairs(bars) do b.pct = Fx.pct(b.n, total) end
    out.res[r] = { total = total, bars = bars }
  end
  for _, c in ipairs(Fx.CATS) do
    local since = nil
    if cat_start[c] and num(inp.tick) >= cat_start[c] then since = inp.tick - cat_start[c] end
    out.cats[c] = { n = cat_n[c], pct = Fx.pct(cat_n[c], out.engaged), count = cat_count[c], since = since, start = cat_start[c] }
  end
  return out
end

--- Ligne de journal [FO-FLUX-IA] lisible (le tag [FO-FLUX] est celui de script/team/flux.lua) (aucune décision ne la lit) : pourcentages des catégories et temps du plus ancien projet.
function Fx.line(key, minute, sm)
  local parts = {}
  for _, c in ipairs(Fx.CATS) do
    local cs = sm.cats[c]
    parts[#parts + 1] = string.format("%s=%d%%/%s/%d", c, cs.pct, Fx.mmss(cs.since), cs.count)
  end
  return string.format("[FO-FLUX-IA] %s minute %d : engage %d | %s | hors categorie %d", tostring(key), minute, math.floor(sm.engaged), table.concat(parts, " "),
    sm.other)
end

return Fx
