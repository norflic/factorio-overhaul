--[[
  Lot VIDEO-ORDRE (lot 1 de la couverture vidéo, 7/11) : micro-banc en moteur réel de l'ordre dans le rang (shared/ai3/porte_rang.lua,
  Pr.order, Pr.recent, Pr.big_hold ; shared/ai3/capitalisation.lua, rank_gate et Ca.before ; script/ai3/capitalisation.lua, entrée
  mq_build et oubli d'un objet refusé).
  Mise en place (2 factions, la dernière par ordre de clé : « scarlet », qui voit des gisements dès la minute 0) :
    1. coffre de la faction : engrenages, câbles, circuits, inserters et bâtons RETIRÉS ; 3 000 plaques de fer et 3 000 plaques de
       cuivre posées (les plaques ne manquent pas : le manque commence au rang 2) ; 10 assembleurs, l'automatisation, l'électronique
       et l'inserter rapide recherchés ;
    2. un client du banc (fo-capi, bench_sink) consomme 30 inserters par minute : il faut 30 engrenages (manque 30), 90 câbles
       (manque 90 : le plus gros) et 30 circuits par minute ; l'engrenage a le meilleur retour, donc passait AVANT le câble ;
    3. la décision est hâtée (fo-ind, hasten), puis de nouveau 300 ticks après chaque décision ; relevé toutes les 60 ticks (fo-capi,
       status) : à chaque nouvelle décision, les ordres de fabrication dans l'ordre où elle les rend.
  CE QUE LE BANC PROUVE (7/11, archive fo-logs/2026-11-07_VIDEO-COUVERTURE/video-ordre/microbanc-10) : le code nouveau tourne dans la
  vraie partie, 5 à 6 décisions de suite, sans erreur Lua, avec le hook de script (mq_build) compilé. CE QU'IL NE PROUVE PAS : le
  contrat d'ordre. Une faction neuve n'a aucune centrale finie avant le tick 2 000 (état « reserve », aucun fantôme à ravivre) ni
  foreuse « disponible » : toutes les chaînes sont refusées par l'exécutant (« centrale demandee, pas finie »), la décision rend
  ordres=[] et r* reste nil. Les contrôles V1 à V3 sont donc écrits « NON EXERCE » (jamais « OK ») tant qu'aucune décision ne rend
  d'ordre de fabrication ; ils s'appliquent tels quels dès qu'un banc plus long ou une centrale posée en fait rendre. La preuve de
  l'ordre est hors jeu : tests/ordre_rang_test.lua (même code, mêmes données, 3 scènes, 20 mutants).
  Contrôles (écrits avant) : V1 la première décision qui rend le câble ET l'engrenage met le câble en premier ; V2 au moins deux
  décisions rendent des ordres de fabrication ; V3 aucun objet ordonné à la décision d n'est ordonné à d+1.
  Lancement (par la file) :
    banc.py --out <archive> --qui video-ordre -- 2000 video-ordre <source>
  Journal : [FO-VIDEO-ORDRE] ; le mod écrit [FO-CAPI] (ordres=[...] porte=[r*=... retenus=N]).
]]

local CHECK = 1900
local EVERY = 60
local REMOVE = { "iron-gear-wheel", "copper-cable", "electronic-circuit", "inserter", "iron-stick", "iron-plate", "copper-plate" }
local STOCK = { { "iron-plate", 3000 }, { "copper-plate", 3000 }, { "assembling-machine-1", 10 } }
local TECHS = { "automation", "electronics", "fast-inserter" }
local FAB = { chaine = true, packs = true, fours = true }

local function set_setting(ctx, name, value)
  local v = ctx.call("war_setting", name, value)
  ctx.check(v == value, "reglage " .. name .. " = " .. tostring(value), tostring(v))
end

local function last_team(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out[#out]
end

local function index_of(list, item)
  for i, v in ipairs(list) do if v == item then return i end end
  return nil
end

return {
  description = "VIDEO-ORDRE : manque de cable et d'engrenages, le plus gros manque net du rang d'abord",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.dec = {}
    set_setting(ctx, "fo-war-ia3e", true)
    set_setting(ctx, "fo-war-capi", true)
    set_setting(ctx, "fo-war-workers", 30)
    local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
    ctx.check(ok == true, "difficulte Paisible imposee avant la guerre", tostring(ok))
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 300 then
      local r = last_team(ctx)
      st.key = r and r.key
      ctx.check(st.key ~= nil, "faction relevee (" .. tostring(st.key) .. ")")
      if not st.key then return end
      local hq = nil
      for _, h in ipairs(ctx.surface().find_entities_filtered({ name = "fo-faction-hq" })) do
        if h.valid and h.force.name == r.force then hq = h end
      end
      local inv = hq and hq.get_inventory(defines.inventory.chest)
      if inv then
        for _, n in ipairs(REMOVE) do
          local c = inv.get_item_count(n)
          if c > 0 then inv.remove({ name = n, count = c }) end
        end
      end
      local force = game.forces[r.force]
      for _, tech in ipairs(TECHS) do
        if force and force.technologies[tech] then force.technologies[tech].researched = true end
      end
      local put = ctx.remote("fo-ind", "stock", st.key, STOCK)
      ctx.check(inv ~= nil and put ~= nil and (put["iron-plate"] or 0) >= 3000 and (put["copper-plate"] or 0) >= 3000,
        "coffre : plaques de fer et de cuivre et 10 assembleurs poses, produits intermediaires retires ; recherches faites")
    end
    if st.key and not st.sink and t > 300 and t % 60 == 0 then
      if ctx.remote("fo-capi", "status", st.key) ~= nil then
        st.sink = ctx.remote("fo-capi", "bench_sink", st.key, "inserter", 30) == true
        ctx.check(st.sink, "client du banc : 30 inserters par minute")
      end
    end
    if st.sink and t % EVERY == 0 then
      -- la première décision tomberait vers le tick 3 300 : le banc la hâte (fo-ind, hasten), puis de nouveau 300 ticks après chaque décision
      if (not st.hasten_t or t - st.hasten_t >= 300) and (st.hasten_n == nil or (st.seen or 0) ~= st.hasten_n) then
        if ctx.remote("fo-ind", "hasten", st.key) == true then st.hasten_t, st.hasten_n = t, st.seen or 0 end
      end
      local cs = ctx.remote("fo-capi", "status", st.key)
      if cs and cs.res and (cs.decisions or 0) ~= st.seen then
        st.seen = cs.decisions or 0
        local fab = {}
        for _, o in ipairs(cs.res.orders or {}) do
          if FAB[o.kind] and o.item then fab[#fab + 1] = o.item end
        end
        st.dec[#st.dec + 1] = { tick = t, n = st.seen, fab = fab, rstar = cs.res.rstar, held = cs.res.rang_held }
        ctx.log(string.format("decision %d au tick %d : r*=%s retenus=%s fabrication [%s]", st.seen, t, tostring(cs.res.rstar),
          tostring(cs.res.rang_held), table.concat(fab, ", ")))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(#(st.dec or {}) >= 5, "D1 au moins 5 decisions de la capitalisation jouees avec le code nouveau, sans erreur Lua", tostring(#(st.dec or {})))
    local with = {}
    for _, d in ipairs(st.dec or {}) do if #d.fab > 0 then with[#with + 1] = d end end
    if #with < 2 then
      ctx.log("NON EXERCE : V1 (cable avant engrenage), V2 (deux decisions avec ordres), V3 (aucun doublon) : " .. #with ..
        " decision(s) rendent des ordres de fabrication (centrale demandee, pas finie : toutes les chaines sont refusees par l'executant)")
      return
    end
    local first = nil
    for _, d in ipairs(with) do
      if index_of(d.fab, "copper-cable") and index_of(d.fab, "iron-gear-wheel") then first = d break end
    end
    ctx.check(first ~= nil, "V1 une decision rend le cable ET l'engrenage", first and ("decision " .. first.n) or "aucune")
    if first then
      ctx.check(index_of(first.fab, "copper-cable") < index_of(first.fab, "iron-gear-wheel"),
        "V1 le cable (manque 90) passe avant l'engrenage (manque 30)", table.concat(first.fab, ", "))
    end
    local dup, pairs_seen = 0, 0
    for i = 1, #with - 1 do
      if with[i + 1].n == with[i].n + 1 then
        pairs_seen = pairs_seen + 1
        for _, a in ipairs(with[i].fab) do
          if index_of(with[i + 1].fab, a) then dup = dup + 1 end
        end
      end
    end
    ctx.log(string.format("V3 : %d paire(s) de decisions consecutives avec ordres, %d doublon(s)", pairs_seen, dup))
    ctx.check(dup == 0, "V3 aucun doublon d'une decision a la suivante", tostring(dup))
  end,
}
