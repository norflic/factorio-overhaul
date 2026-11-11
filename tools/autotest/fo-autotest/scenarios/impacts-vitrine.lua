-- Scénario greffé du lot ART-IMPACTS (11/11, mandat de nuit du DC) : VITRINE des impacts refaits, en moteur réel.
--   banc.py --qui IMPACTS -- 600 impacts-vitrine <source>                        (contrôles, sans images)
--   banc.py --qui IMPACTS --captures -- 600 impacts-vitrine <source>             (captures : fo-shots/NNN-impacts-*.png)
-- Six sites sur un sol naturel ; toutes les 45 ticks, chaque site rejoue son effet par le moteur (aucun rendu de script) :
--   plasma (impact de la Bastion d'âge 4 : explosion, ONDE DE CHOC au sol, brûlure) ; singularité (impact du lanceur :
--   explosion, choc, DISTORSION, brûlure) ; frappe orbitale (porteur : choc, brûlure) ; titan (porteur du Juggernaut : choc,
--   distorsion, brûlure) ; faisceau du laser de la lignée (FAISCEAU DENSE) ; trace du fusil à rail (faisceau dense + impact).
-- Les noms viennent de la règle (shared/content/effets_armes.lua : Fx.armes, Fx.nom) ; un nom absent du jeu (source d'avant le
-- lot) se rabat sur l'effet d'avant (onde, arc électrique vanilla) : la même vitrine sert la planche AVANT / APRÈS.
-- Contrôles (finish) : prototypes du lot présents (choc, distorsion et son ombre, brûlure, faisceau du rail) ; chaque site a
-- rejoué son effet sans échec ; des brûlures sont au sol ; la trace du rail est un faisceau SANS dégâts (aucune perte de vie
-- d'une caisse posée sous la trace).

local Fx = require("__factorio-overhaul__/shared/content/effets_armes")
local A = require("__factorio-overhaul__/shared/content/arsenal")
-- shared/robots/titans.lua charge ses dépendances par chemin relatif (introuvable depuis le mod de test) : le titan de la vitrine
-- se trouve par les prototypes d'effets du jeu (premier « fo-fx-fo-titan-*-choc », sinon « -onde », dans l'ordre des noms).

local X0, Y0 = 7200, -2800
local PAS = 18
local CADENCE = 45

local function pack_de(mode)
  for _, p in ipairs(Fx.armes(A, nil)) do if p.mode == mode then return p end end
end

local function existe(n) return n and game.entity_prototypes[n] ~= nil end

--- Le premier nom qui existe dans le jeu.
local function premier(...)
  for _, n in ipairs({ ... }) do if existe(n) then return n end end
end

local function sites()
  local L = {}
  local function impact(cle, mode, i)
    local p = pack_de(mode)
    L[#L + 1] = { cle = cle, genre = "impact", x = X0 + (i - 1) * PAS, y = Y0,
      nom = premier(Fx.nom(p, "impact"), Fx.nom(p, "choc"), Fx.nom(p, "onde")),
      lot = { Fx.nom(p, "choc"), Fx.nom(p, "brulure"), (p.impact and p.impact.distorsion) and Fx.nom(p, "distorsion") or nil } }
  end
  impact("plasma", "plasma", 1)
  impact("singularite", "singularite", 2)
  impact("orbitale", "orbital", 3)
  do
    local noms = {}
    for n in pairs(game.entity_prototypes) do
      if n:find("^fo%-fx%-fo%-titan%-") and (n:find("%-choc$") or n:find("%-onde$")) then noms[#noms + 1] = n end
    end
    table.sort(noms)
    local choc, onde_
    for _, n in ipairs(noms) do
      if not choc and n:find("%-choc$") then choc = n end
      if not onde_ and n:find("%-onde$") then onde_ = n end
    end
    local base = (choc or onde_ or ""):gsub("%-choc$", ""):gsub("%-onde$", "")
    L[#L + 1] = { cle = "titan", genre = "impact", x = X0 + 3 * PAS, y = Y0, nom = choc or onde_,
      lot = { base .. "-choc", base .. "-brulure", base .. "-distorsion" } }
  end
  local laser, rail = pack_de("laser"), pack_de("rail")
  L[#L + 1] = { cle = "laser", genre = "faisceau", x = X0 + 0.5 * PAS, y = Y0 + PAS, nom = laser.nom .. "-beam" }
  L[#L + 1] = { cle = "rail", genre = "faisceau", x = X0 + 2.5 * PAS, y = Y0 + PAS,
    nom = premier(Fx.nom(rail, "faisceau"), "electric-beam-no-sound"), impact = Fx.nom(rail, "impact"), lot = { Fx.nom(rail, "faisceau") } }
  return L
end

local function rejoue(s, site, t)
  local ok
  if site.genre == "impact" then
    local dx = (math.floor(t / CADENCE) % 3 - 1) * 0.6
    ok = s.create_entity({ name = site.nom, position = { site.x + dx, site.y } }) ~= nil
  else
    ok = s.create_entity({ name = site.nom, position = { site.x - 7, site.y }, source_position = { site.x - 7, site.y - 0.5 },
      target_position = { site.x + 7, site.y }, duration = CADENCE - 5 }) ~= nil
    if site.impact and existe(site.impact) then s.create_entity({ name = site.impact, position = { site.x + 7, site.y } }) end
  end
  site.n = (site.n or 0) + 1
  site.ok = (site.ok or 0) + (ok and 1 or 0)
end

return {
  description = "ART-IMPACTS : vitrine des faisceaux denses, ondes de choc au sol, brulures et distorsions de singularite",
  base = nil,
  check_tick = 540,
  shots_delay = 120,

  init = function(ctx)
    ctx.prepare_area(X0 - 20, Y0 - 16, X0 + 3 * PAS + 20, Y0 + PAS + 12, "dirt-4")
    local st = ctx.state()
    st.sites = sites()
    -- caisse témoin sous la trace du rail : un faisceau visuel seul ne lui ôte aucune vie
    local r = st.sites[#st.sites]
    st.caisse = ctx.surface().create_entity({ name = "wooden-chest", position = { r.x, r.y }, force = "neutral" })
    st.pret = true
    for _, site in ipairs(st.sites) do
      ctx.log(string.format("[FO-IMPACTS-VITRINE] site %s : %s %s", site.cle, site.genre, tostring(site.nom)))
    end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    if not st.place then
      local p = game.connected_players[1]
      if p then st.place = p.teleport({ X0 + 1.5 * PAS, Y0 + PAS / 2 }, ctx.surface()) and e.tick or false end
    end
    if e.tick >= 30 and e.tick % CADENCE == 0 then
      local s = ctx.surface()
      for _, site in ipairs(st.sites) do rejoue(s, site, e.tick) end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    for _, site in ipairs(st.sites) do
      ctx.check(site.nom ~= nil, "site " .. site.cle .. " : effet trouvé dans le jeu", site.nom)
      ctx.check((site.n or 0) > 0 and site.ok == site.n, "site " .. site.cle .. " : effet rejoué sans échec", tostring(site.ok) .. "/" .. tostring(site.n))
      for _, n in ipairs(site.lot or {}) do
        ctx.check(existe(n), "prototype du lot présent : " .. n)
      end
    end
    local brulures = 0
    for _, site in ipairs(st.sites) do
      for _, n in ipairs(site.lot or {}) do
        if n:find("%-brulure$") then brulures = brulures + s.count_entities_filtered({ name = n }) end
      end
    end
    ctx.check(brulures > 0, "brûlures au sol (éphémères) présentes", brulures)
    local c = st.caisse
    ctx.check(c and c.valid and c.health == c.prototype.max_health, "trace du rail visuelle seule : la caisse sous la trace garde toute sa vie",
      c and c.valid and c.health or "détruite")
    ctx.log(string.format("[FO-IMPACTS-VITRINE] BILAN brulures=%d", brulures))
  end,

  -- 25 captures : la session avec images de cette vitrine s'arrête d'elle-même vers la 27e (banc du 11/11 : 27 sur 31) ;
  -- 3 de nuit et 1 de jour par site, puis la vue d'ensemble.
  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    for _, site in ipairs(st.sites) do
      for i = 1, 3 do
        add(string.format("impacts-%s-nuit-%d", site.cle, i), site.x, site.y, 1.6, 0.5, { res = { 480, 360 }, info = false, aa = false, cadence = 7 })
      end
      add(string.format("impacts-%s-jour", site.cle), site.x, site.y, 1.6, 0, { res = { 480, 360 }, info = false, aa = false })
    end
    add("impacts-vue-nuit", X0 + 1.5 * PAS, Y0 + PAS / 2, 0.55, 0.5, { res = { 1280, 720 }, info = false })
  end,
}
