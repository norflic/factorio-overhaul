--[[
  Scénario GREFFÉ « m0-reprise » (lot M0, correction M-1 de la vérification du 23/10) : en moteur réel, sur nauvis,
  la garantie du tungstène ÉCHOUE deux fois, n'est pas marquée traitée, puis réussit à la reprise avec des critères
  assouplis (eau du bord comblée).

  Lancement (sans double source) : & "<racine>\fo-autotest.bat" nopause 2600 m0-reprise "<source>"
  Il faut au moins 2 500 ticks (contrôle final au tick 2 460).

  Mise en place (tick 10), sur la carte du banc (graine 20261020, site du tungstène posé à on_init) :
  - les chunks des 24 candidats des essais 0, 1 et 2 sont générés ;
  - un coffre du joueur au centre de chaque candidat des essais 0 et 1 (refus « batiment » : jamais assoupli) ;
  - de l'eau sous la moitié ouest du cœur de chaque candidat de l'essai 2 (47 % du carré du cœur : refusée aux
    niveaux 0 et 1, tolérée et comblée au niveau 2) ;
  - le tungstène est « oublié » (fo-monde.forget, banc seulement) ; avant chaque passage du filet, tout gisement de
    tungstène à moins de dmax est retiré (la carte devient une carte SANS tungstène : la garantie doit en poser un).
  Attendu :
  - tick 600 : essai 0, les 24 candidats refusés : ÉCHEC, ressource non traitée, reprise au tick 1 200 ;
  - tick 1 200 : essai 1 (autres candidats), ÉCHEC, reprise au tick 2 400 (délai doublé) ;
  - tick 1 800 : délai non écoulé, aucune passe ;
  - tick 2 400 : essai 2 (niveau 2) : site posé sur un candidat à moitié dans l'eau, eau comblée par les cendres,
    gisement complet, ressource traitée, historique des 2 échecs gardé ; coffres intacts.
]]

local MONDE = "fo-monde"
local KEY = "tungsten"
local T_SETUP, CHECK = 10, 2460
local CLEAN = { 590, 1190, 2390 }

local function call(fn, ...) return remote.call(MONDE, fn, ...) end

local function spec_of(specs, key)
  for _, s in ipairs(specs) do if s.key == key then return s end end
end

local function by_key(list, key)
  for _, d in ipairs(list or {}) do if d.key == key then return d end end
end

--- Retire tout gisement de tungstène à moins de dmax du départ (chunks générés). Renvoie le nombre retiré.
local function clean_tungsten(s, spec, spawn)
  local n = 0
  for _, e in ipairs(s.find_entities_filtered({ name = spec.resource, position = spawn, radius = spec.dmax + 1 })) do
    if e.valid then
      e.destroy()
      n = n + 1
    end
  end
  return n
end

local function all_match(list, pattern)
  for _, r in ipairs(list or {}) do if not r:find(pattern) then return false end end
  return true
end

return {
  description = "M0 : garantie en echec puis reprise (correction M-1)",
  check_tick = CHECK,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = game.surfaces[1]
    if e.tick == T_SETUP then
      local specs = call("specs")
      local spec = spec_of(specs, KEY)
      st.spec = spec
      local spawn = game.forces.player.get_spawn_position(s)
      st.spawn = { x = spawn.x, y = spawn.y }
      local status = call("status")
      local d0 = by_key(status.done, KEY)
      ctx.check(d0 and d0.ok and d0.phase == "init", "tungstene pose a on_init (etat de depart)")
      local cands = {}
      for k = 0, 2 do cands[k] = call("candidates", "nauvis", KEY, 24, k) end
      st.water_cands = cands[2]
      for k = 0, 2 do
        for _, c in ipairs(cands[k]) do s.request_to_generate_chunks({ c.x, c.y }, 1) end
      end
      s.force_generate_chunk_requests()
      -- L'eau d'abord : set_tiles retire les entités qu'elle recouvre (1er passage, 16:44 : un coffre de l'essai 0 noyé,
      -- candidat 8 refusé « sol » au lieu de « batiment »).
      local R = spec.core_radius + 1
      local water = {}
      for _, c in ipairs(cands[2]) do
        for y = c.y - R, c.y + R do
          for x = c.x - R, c.x - 1 do water[#water + 1] = { name = "water", position = { x, y } } end
        end
      end
      s.set_tiles(water)
      local wet = s.count_tiles_filtered({ position = { cands[2][1].x - 4, cands[2][1].y }, radius = 2, collision_mask = "water-tile" })
      ctx.check(wet > 0, "eau posee sous la moitie ouest des candidats de l'essai 2", wet .. " tuiles d'eau pres du candidat 1")
      local chests, made = {}, 0
      for k = 0, 1 do
        for _, c in ipairs(cands[k]) do
          local ch = s.create_entity({ name = "wooden-chest", position = { c.x + 0.5, c.y + 0.5 }, force = "player" })
          if ch then
            made = made + 1
            chests[#chests + 1] = ch.unit_number
          end
        end
      end
      st.chests = chests
      ctx.check(made == 48, "48 coffres du joueur poses (centres des candidats des essais 0 et 1)", made .. " poses")
      st.removed = clean_tungsten(s, spec, spawn)
      st.forgot = call("forget", KEY)
      ctx.check(st.forgot, "tungstene oublie (redevient a traiter)", "gisements retires : " .. st.removed)
    end
    for _, t in ipairs(CLEAN) do
      if e.tick == t and st.spec then
        local n = clean_tungsten(s, st.spec, st.spawn)
        ctx.log("tick " .. e.tick .. " : " .. n .. " entite(s) de tungstene retiree(s) a moins de dmax (carte sans tungstene)")
      end
    end
    if e.tick == 601 then
      local status = call("status")
      local f = by_key(status.fails, KEY)
      local h = f and f.history[1]
      ctx.check(by_key(status.done, KEY) == nil and f and f.count == 1 and f.next_tick == 1200,
        "tick 600 : echec de l'essai 0, ressource NON traitee, reprise au tick 1200",
        f and ("echecs " .. f.count .. ", reprise " .. f.next_tick) or "aucun echec enregistre")
      ctx.check(h and h.attempt == 0 and h.level == 0 and #h.rejected == 24 and all_match(h.rejected, ":[bv]"),
        "essai 0 : les 24 candidats refuses (batiment ou voisin)", h and table.concat(h.rejected, ",") or "-")
      st.runs1 = status.runs
    elseif e.tick == 1201 then
      local status = call("status")
      local f = by_key(status.fails, KEY)
      local h = f and f.history[2]
      ctx.check(by_key(status.done, KEY) == nil and f and f.count == 2 and f.next_tick == 2400 and status.runs == st.runs1 + 1,
        "tick 1200 : echec de l'essai 1, reprise au tick 2400 (delai double)",
        f and ("echecs " .. f.count .. ", reprise " .. f.next_tick .. ", passes " .. status.runs) or "aucun echec enregistre")
      ctx.check(h and h.attempt == 1 and h.level == 1 and #h.rejected == 24 and all_match(h.rejected, ":[bv]"),
        "essai 1 : autres candidats, les 24 refuses", h and table.concat(h.rejected, ",") or "-")
      st.runs2 = status.runs
    elseif e.tick == 1801 then
      local status = call("status")
      ctx.check(status.runs == st.runs2, "tick 1800 : delai non ecoule, aucune passe", "passes " .. status.runs)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = game.surfaces[1]
    local spec = st.spec
    local status = call("status")
    local d = by_key(status.done, KEY)
    local site = d and d.sites and d.sites[1]
    ctx.check(d and d.ok and d.phase == "filet" and d.tick == 2400 and d.attempt == 2 and d.level == 2 and by_key(status.fails, KEY) == nil
      and d.failures and #d.failures == 2,
      "tick 2400 : reussite a l'essai 2 (niveau 2), ressource traitee, 2 echecs gardes dans l'historique",
      d and string.format("phase %s, tick %s, essai %s, niveau %s, echecs %s", tostring(d.phase), tostring(d.tick), tostring(d.attempt),
        tostring(d.level), tostring(d.failures and #d.failures)) or "non traitee")
    if not (site and spec) then
      ctx.fail("site du tungstene pose a la reprise", "aucun site")
      return
    end
    -- Le site retenu est un candidat de l'essai 2 (à moitié dans l'eau à la mise en place).
    local wc = st.water_cands[site.try]
    ctx.check(wc and wc.x == site.x and wc.y == site.y and site.filled > 0,
      "site pose sur le candidat " .. site.try .. " de l'essai 2, eau du bord comblee",
      string.format("(%d, %d) a %.1f, %d tuile(s) d'eau comblee(s)", site.x, site.y, site.dist, site.filled or 0))
    local wet = s.count_tiles_filtered({ position = { site.x + 0.5, site.y + 0.5 }, radius = spec.site_radius - 2, collision_mask = "water-tile" })
    local ash = s.count_tiles_filtered({ area = { { site.x - spec.core_radius - 1, site.y - spec.core_radius - 1 }, { site.x, site.y + spec.core_radius + 2 } }, name = spec.tile })
    ctx.check(wet == 0 and ash > 0, "plus d'eau dans le disque du site ; cendres sur l'ancienne moitie d'eau",
      wet .. " tuile(s) d'eau dans le disque, " .. ash .. " tuile(s) de cendres sur la moitie ouest")
    local ents = s.find_entities_filtered({ name = spec.resource, position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
    local total, wrong = 0, 0
    for _, e in ipairs(ents) do
      total = total + e.amount
      local t = s.get_tile(math.floor(e.position.x), math.floor(e.position.y))
      if t.name ~= spec.tile then wrong = wrong + 1 end
    end
    ctx.check(#ents == site.entities and total == site.total and total >= spec.min_total and wrong == 0,
      "gisement complet sur les cendres", string.format("%d entites (rapport %d), %d (rapport %d), hors biome %d", #ents, site.entities, total, site.total, wrong))
    local d0 = math.sqrt((site.x - st.spawn.x) ^ 2 + (site.y - st.spawn.y) ^ 2)
    ctx.check(d0 >= spec.dmin and d0 <= spec.dmax, "site dans l'anneau des donnees (niveau 2 : anneau non allonge)", string.format("%.1f tuiles", d0))
    local alive = 0
    for _, ch in ipairs(s.find_entities_filtered({ name = "wooden-chest", force = "player" })) do
      for _, u in ipairs(st.chests or {}) do if ch.unit_number == u then alive = alive + 1 end end
    end
    ctx.check(alive == #(st.chests or {}), "coffres du joueur intacts", alive .. " sur " .. #(st.chests or {}))
  end,
}
