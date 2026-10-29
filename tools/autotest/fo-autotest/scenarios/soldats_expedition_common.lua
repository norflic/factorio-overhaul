--[[
  Lot CORR-SOLDATS (remarque 4 du DC : « une base de 25 soldats inactifs, attendent de se faire attaquer [...] alors qu'ils
  pourraient détruire la base de biters »), mesure PROVOQUÉE et déterministe en moteur réel. Guerre de 2 factions (30 soldats,
  4 ouvriers), caractère forcé PACIFIQUE (agressivité 700 : l'ancien seuil CLEAR_AGR = 900 ne joue pas), 30 soldats inactifs
  chacune. À PLACE tick, un champ de nids est posé à 115 tuiles du QG de chaque faction (direction fixe, entre deux rayons de
  patrouille) et MARQUÉ sur la carte de la faction (comme vu par un éclaireur) :
    mode « expedition » : Écarlate : 2 nids + 2 vers (besoin 11 <= surplus 19 : la règle doit lancer l'expédition) ;
                          Azur : 8 nids + 4 vers (besoin 27 > surplus 19 : la règle ne doit RIEN lancer) ;
    mode « retraite »    : Écarlate : champ MARQUÉ petit (1 nid + 1 ver, besoin 7) mais MORTEL (2 nids, 6 vers moyens, 4 tourelles
                          ennemies garnies) : retraite attendue, site non retenté ; Azur : rien posé.
  opts.sans : la règle est coupée à l'init (war_option soldats_offensive = false) : le MÊME code ne doit rien lancer.
  Mesures (journal [FO-SOLDATS-EXP]) : offense_ops, clear_ops, retreats (fo-ia3k status), nids restants, soldats vivants, soldats près
  du QG, maximum de soldats de la faction à moins de 40 tuiles du champ (échantillon toutes les 120 ticks).
  Lancement : banc.py --out <archive> --qui SOLDATS -- 9600 soldats-expedition <source>
]]

return function(opts)
  local MODE = opts.mode
  local SANS = opts.sans and true or false
  local TAG = "[FO-SOLDATS-EXP] "
  local PLACE, CHECK = 600, 9000
  local DIR = { 0.9239, 0.3827 } -- entre deux rayons de patrouille (0 degré et 45 degrés)
  local DIST = 115 -- hors de portee des points de patrouille (anneau a 80 tuiles : 51 tuiles du champ) : sans la regle, personne n y va

  local function field_of(key)
    if MODE == "expedition" then
      if key == "scarlet" then return { nests = 2, worms = 2, mark_nests = 2, mark_worms = 2, turrets = 0, tag = "petit" } end
      return { nests = 8, worms = 4, mark_nests = 8, mark_worms = 4, turrets = 0, tag = "trop gros" }
    end
    if key == "scarlet" then return { nests = 2, worms = 6, mark_nests = 1, mark_worms = 1, turrets = 4, tag = "mortel" } end
    return nil
  end

  local function teams()
    local out = {}
    for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
      if row.key ~= "player" then out[row.key] = row.force end
    end
    return out
  end

  local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

  local function put(s, name, at, r, radius)
    local p = s.find_non_colliding_position(name, at, radius or 14, r or 1)
    local e = p and s.create_entity({ name = name, position = p, force = "enemy" })
    return e and { x = e.position.x, y = e.position.y } or nil
  end

  return {
    description = "CORR-SOLDATS : expedition des soldats inactifs contre un champ de nids connu (" .. MODE .. (SANS and ", regle coupee" or "") .. ")",
    check_tick = CHECK,

    init = function(ctx)
      ctx.check(ctx.call("war_start", 2, 30, 4) == true, "guerre lancee : 2 factions, 30 soldats, 4 ouvriers")
      ctx.call("profiler", true)
      ctx.check(ctx.remote("fo-ia3k", "set_character", "scarlet", 1000, 700) == true, "Ecarlate forcee pacifique (agressivite 700)")
      ctx.check(ctx.remote("fo-ia3k", "set_character", "azure", 1000, 700) == true, "Azur forcee pacifique (agressivite 700)")
      if SANS then
        ctx.check(ctx.call("war_option", "soldats_offensive", false) == true, "regle coupee (soldats_offensive = false)")
      end
      ctx.state().fields = {}
      ctx.state().maxnear = {}
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      local s = ctx.surface()
      if e.tick == PLACE then
        local force_of = teams()
        local poi = ctx.call("points_of_interest")
        for _, f in ipairs(poi.factions or {}) do
          local spec = field_of(f.key)
          local trained = ctx.call("war_train", f.key, 30) -- les soldats naissent de l'economie : on les pose, 30 inactifs
          ctx.log(TAG .. string.format("%s : %d soldat(s) poses a la garnison", f.key, trained or -1))
          if spec then
            local c0 = { x = f.hq.x + DIR[1] * DIST, y = f.hq.y + DIR[2] * DIST }
            local center = s.find_non_colliding_position("biter-spawner", c0, 24, 2) or c0
            local rec = { key = f.key, force = force_of[f.key], hq = f.hq, center = center, spec = spec, nests = 0, worms = 0, turrets = 0 }
            for i = 1, spec.nests do
              local a = { x = center.x + ((i - 1) % 4 - 1.5) * 8, y = center.y + math.floor((i - 1) / 4) * 8 - 4 }
              local p = put(s, "biter-spawner", a, 1, 10)
              if p then
                rec.nests = rec.nests + 1
                if i <= spec.mark_nests then ctx.remote("fo-ia3k", "mark", f.key, p.x, p.y, "spawner", 30) end
              end
            end
            for i = 1, spec.worms do
              local a = { x = center.x + ((i - 1) % 3 - 1) * 7, y = center.y + 9 + math.floor((i - 1) / 3) * 5 }
              local name = spec.turrets > 0 and "medium-worm-turret" or "small-worm-turret"
              local p = put(s, name, a, 0.5, 10)
              if p then
                rec.worms = rec.worms + 1
                if i <= spec.mark_worms then ctx.remote("fo-ia3k", "mark", f.key, p.x, p.y, "worm", 30) end
              end
            end
            for i = 1, spec.turrets do
              local p = put(s, "gun-turret", { x = center.x + (i - 2.5) * 5, y = center.y - 8 }, 0.5, 8)
              if p then
                rec.turrets = rec.turrets + 1
                local t = s.find_entities_filtered({ position = p, radius = 1, name = "gun-turret", force = "enemy", limit = 1 })[1]
                if t then t.insert({ name = "piercing-rounds-magazine", count = 40 }) end
              end
            end
            st.fields[#st.fields + 1] = rec
            st.maxnear[f.key] = 0
            ctx.log(TAG .. string.format("%s : champ %s pose a %d tuiles du QG, centre (%d, %d) : %d nid(s), %d ver(s), %d tourelle(s) ; marques : %d nid(s) + %d ver(s)",
              f.key, spec.tag, math.floor(dist(center, f.hq)), math.floor(center.x), math.floor(center.y), rec.nests, rec.worms, rec.turrets,
              spec.mark_nests, spec.mark_worms))
          end
        end
      end
      if e.tick > PLACE and e.tick % 120 == 0 then
        for _, rec in ipairs(st.fields) do
          local n = #s.find_entities_filtered({ position = rec.center, radius = 40, force = rec.force, type = "unit" })
          if n > st.maxnear[rec.key] then st.maxnear[rec.key] = n end
        end
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      local res = {}
      for _, rec in ipairs(st.fields) do
        local status = ctx.remote("fo-ia3k", "status", rec.key) or {}
        local sv = status.stats or {}
        local nests_left = #s.find_entities_filtered({ position = rec.center, radius = 30, type = "unit-spawner", force = "enemy" })
        local alive = #s.find_entities_filtered({ force = rec.force, type = "unit" })
        local at_hq = #s.find_entities_filtered({ position = rec.hq, radius = 45, force = rec.force, type = "unit" })
        local r = { ops = sv.offense_ops or 0, sent = sv.offense_sent or 0, clear = sv.clear_ops or 0, retreats = sv.retreats or 0, nests_left = nests_left,
          nests = rec.nests, alive = alive, at_hq = at_hq, maxnear = st.maxnear[rec.key] or 0 }
        res[rec.key] = r
        ctx.log(TAG .. string.format("FAIT %s (%s%s) : expeditions des inactifs %d (soldats envoyes %d), nettoyages %d, retraites %d | nids %d -> %d | soldats vivants %d (pres du QG %d) | maximum pres du champ %d",
          rec.key, rec.spec.tag, SANS and ", regle coupee" or "", r.ops, r.sent, r.clear, r.retreats, r.nests, r.nests_left, r.alive, r.at_hq, r.maxnear))
      end
      ctx.check(#st.fields >= 1, "les champs ont ete poses")
      local sc, az = res.scarlet, res.azure
      if MODE == "expedition" then
        if SANS then
          ctx.check(sc and sc.ops == 0 and sc.clear == 0, "SANS la regle : aucune expedition d'Ecarlate", sc and (sc.ops .. "/" .. sc.clear) or "?")
          ctx.check(sc and sc.nests_left == sc.nests, "SANS la regle : aucun nid d'Ecarlate detruit", sc and (sc.nests_left .. "/" .. sc.nests) or "?")
          ctx.check(az and az.ops == 0, "SANS la regle : aucune expedition d'Azur", az and az.ops or "?")
        else
          ctx.check(sc and sc.ops >= 1, "E1 : Ecarlate lance une expedition des inactifs", sc and sc.ops or "?")
          ctx.check(sc and sc.nests_left < sc.nests, "E1 : au moins un nid d'Ecarlate detruit", sc and (sc.nests_left .. " restants sur " .. sc.nests) or "?")
          ctx.check(sc and sc.sent == 11, "E2 : 11 soldats envoyes (3 + 2 x 4 menaces connues), pas toute la garnison", sc and sc.sent or "?")
          ctx.check(sc and sc.at_hq >= 8, "E2 : la reserve (>= 8) reste au QG d'Ecarlate", sc and sc.at_hq or "?")
          ctx.check(az and az.ops == 0 and az.clear == 0, "E3 : Azur (champ trop gros) ne lance rien", az and (az.ops .. "/" .. az.clear) or "?")
          ctx.check(az and az.nests_left == az.nests, "E3 : les nids d'Azur sont intacts", az and (az.nests_left .. "/" .. az.nests) or "?")
        end
      else
        if SANS then
          ctx.check(sc and sc.ops == 0 and sc.clear == 0 and sc.retreats == 0, "SANS la regle : ni expedition ni retraite", sc and (sc.ops .. "/" .. sc.clear .. "/" .. sc.retreats) or "?")
        else
          ctx.check(sc and sc.ops >= 1, "E5 : l'expedition part contre le champ marque petit", sc and sc.ops or "?")
          ctx.check(sc and sc.retreats >= 1, "E5 : retraite quand plus de la moitie de la force est morte", sc and sc.retreats or "?")
          ctx.check(sc and sc.ops <= 1, "E5 : site non retente pendant le delai", sc and sc.ops or "?")
          ctx.check(sc and sc.alive >= 6, "E5 : la faction n'est pas aneantie (>= 6 soldats vivants ; la partie perd aussi des soldats SANS la regle : voir le bras -sans)", sc and sc.alive or "?")
        end
      end
    end,
  }
end
