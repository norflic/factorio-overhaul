--[[
  Lot RB-3 CERVEAU (1/11) : une FACTION fait fabriquer des robots, contre le moteur réel. Deux scénarios partagent ce fichier :

    rb-faction         : une faction financée, dont la technologie des robots est faite (le banc la donne : ce lot ne pilote pas la
                         recherche) ; son stock contient l'atelier (objet), les pièces du plan directeur et les ingrédients du kit.
                         Chaîne attendue : le catalogue lit l'unité du kit (items_to_place_this) -> Rb.choose -> Rb.demand -> Ml.want (source
                         « unite ») -> Id.decide : cellule seule en sortie « unité » -> Auto.submit -> plan directeur -> PNJ -> atelier
                         bâti -> kit -> balayage : unité -> Military.adopt (soldat de la faction : garnison). Témoin : l'autre faction n'a
                         pas la technologie, donc ni demande, ni atelier, ni robot.
    rb-faction-eteint  : le même, réglage maître `fo-war-robots` ÉTEINT dès le départ : aucune demande, aucun atelier, aucun robot ;
                         une pensée forcée de la faction ne demande rien.
  Comme le banc du mall (ind_mall_common.lua), le BANC raccourcit le temps des PNJ : il ravive lui-même les fantômes du module et garnit ses
  quais d'entrée ; tout le reste (demande, décision, plan, recette, balayage, adoption) est celui du mod.
  Lancement (par la file) : banc.py --out <archive> --qui RB23 -- 9600 rb-faction <source>   (de même rb-faction-eteint)
  Journal : [FO-RB-FACTION] (ce banc), [FO-ROBOTS] et [FO-MALL] (le mod).
]]

local KIT = "fo-robot-kit-steam-trotter"
local WORKSHOP = "fo-robot-workshop"
local TECH = "fo-robot-automata"

local PARTS = {
  { WORKSHOP, 4 }, -- les ingredients du kit n'ont pas besoin du coffre : le banc garnit les quais d'entree du module (comme le mall)
  { "assembling-machine-1", 12 }, { "assembling-machine-2", 24 }, { "inserter", 80 }, { "long-handed-inserter", 40 },
  { "fast-inserter", 30 }, { "wood", 200 }, { "transport-belt", 300 }, { "iron-chest", 30 }, { "wooden-chest", 10 }, { "small-electric-pole", 60 },
  { "medium-electric-pole", 40 }, { "copper-plate", 800 }, { "stone-brick", 300 }, { "coal", 400 },
}

local function teams(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

local function module_ents(ctx, key, id)
  local lay = ctx.remote("fo-ia1d", "layout", key)
  local out = {}
  for _, e in ipairs(lay and lay.ents or {}) do
    if e.pid == id then out[#out + 1] = e end
  end
  return out
end

local function wants_kit(view)
  for _, w in ipairs(view and view.want or {}) do
    if w.item == KIT then return w end
  end
  return nil
end

return function(name, robots_on)
  return {
    description = "RB-3 (" .. name .. ") : demande de robots d'une faction -> atelier -> kit -> unite -> soldat (reglage " .. (robots_on and "allume" or "eteint") .. ")",
    check_tick = 9500,
    init = function(ctx)
      local st = ctx.state()
      st.t = {}
      st.prototypes = game.entity_prototypes[WORKSHOP] ~= nil and game.item_prototypes[KIT] ~= nil
      if not st.prototypes then
        ctx.fail("prototypes du lot presents (atelier, kit)")
        return
      end
      local function set_setting(n, v)
        local r = ctx.call("war_setting", n, v)
        ctx.check(r == v, "reglage " .. n .. " = " .. tostring(v), tostring(r))
      end
      set_setting("fo-war-industrie", true)
      set_setting("fo-war-ia3e", true)
      set_setting("fo-war-capi", true)
      set_setting("fo-war-workers", 30)
      set_setting("fo-war-robots", robots_on)
      ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible imposee avant la guerre")
      ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
      ctx.check(ctx.call("war_fund", 20000) == 2, "2 factions financees (20000 fer)")
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.prototypes then return end
      local t = e.tick
      if t == 400 then
        local tm = teams(ctx)
        st.key, st.control, st.force, st.cforce = tm[1] and tm[1].key, tm[2] and tm[2].key, tm[1] and tm[1].force, tm[2] and tm[2].force
        ctx.check(st.key ~= nil and st.control ~= nil, "deux factions relevees")
        if not st.key then return end
        local tech = game.forces[st.force].technologies[TECH]
        tech.researched = true
        ctx.check(tech.researched and game.forces[st.force].recipes["fo-robot-make-steam-trotter"].enabled,
          st.key .. " : technologie des robots faite, recette du kit ouverte (le banc la donne)")
        local put = ctx.remote("fo-ind", "stock", st.key, PARTS)
        ctx.check(put ~= nil and (put[WORKSHOP] or 0) >= 1, st.key .. " : atelier et pieces posees au coffre d'equipe")
        for _, p in ipairs(PARTS) do
          if put and (put[p[1]] or 0) < p[2] then ctx.log(string.format("ATTENTION : %s inseree a %d sur %d", p[1], put[p[1]] or 0, p[2])) end
        end
        -- la lecture du catalogue : l'unite du kit est lue aux prototypes, sans un nom
        local up = game.entity_prototypes["fo-robot-player-steam-trotter"]
        local items = up and up.items_to_place_this
        ctx.check(items ~= nil and items[1] ~= nil and items[1].name == KIT, "le kit pose l'unite du joueur (items_to_place_this)")
      end
      -- la pensée de robots a lieu toute seule (nth_tick 1200) ; relevé de la demande après la première
      if st.key and t == 1300 then
        local v = ctx.remote("fo-robots-faction", "view", st.key)
        local c = ctx.remote("fo-robots-faction", "view", st.control)
        local w = wants_kit(v)
        st.want_seen = w
        if robots_on then
          ctx.check(w ~= nil and w.src == "unite" and w.rate > 0,
            st.key .. " : demande de kits notee au mall (source unite), choisie par le cerveau",
            w and string.format("%s %.2f/min", w.item, w.rate) or "aucune demande (vue: " .. tostring(v ~= nil) .. ")")
          ctx.check(wants_kit(c) == nil, st.control .. " (sans la technologie) : aucune demande de kits")
        else
          ctx.check(w == nil and wants_kit(c) == nil, "reglage eteint : aucune demande de kits", w and w.item or "rien")
        end
        local th = ctx.remote("fo-robots-faction", "think", st.key, t)
        ctx.log("pensee forcee : " .. (th and string.format("%s besoin %d point(s), %d kit(s), %.2f/min", th.item, th.want, th.units, th.rate) or "nil"))
        if not robots_on then
          ctx.check(th == nil, "reglage eteint : une pensee forcee ne choisit rien", th and th.item or "rien")
        end
      end
      -- la décision de la capitalisation est hâtée (elle tombe sinon vers le tick 3 300)
      if st.key and not st.hastened and t >= 1400 and t % 60 == 0 then
        if ctx.remote("fo-ind", "hasten", st.key) == true then
          st.hastened = t
          ctx.log("decision hatee au tick " .. t)
        end
      end
      -- BANC SEULEMENT : le temps (voir l'en-tête)
      if st.key and t >= 3000 and t % 120 == 0 and not st.done_fini then
        local s0 = ctx.remote("fo-ind", "status", st.key)
        local b0 = s0 and s0.blocs and s0.blocs[1]
        if b0 and (b0.state == "fantomes" or b0.state == "chantier" or b0.state == "raccordement" or b0.state == "fini") then
          local s1 = ctx.surface()
          local ents = module_ents(ctx, st.key, b0.id)
          st.revived = (st.revived or 0) + (ctx.remote("fo-ind", "revive", st.key, b0.id) or 0)
          if not st.powered then
            for _, en in ipairs(ents) do
              if not st.powered and en.name:find("electric%-pole") then
                local real = s1.find_entity(en.name, { en.x, en.y })
                if real and real.valid then
                  for _, d in ipairs({ { 2, 2 }, { -2, 2 }, { 2, -2 }, { -2, -2 }, { 3, 0 }, { 0, 3 }, { -3, 0 }, { 0, -3 } }) do
                    if not st.powered and ctx.power(real.position.x + d[1], real.position.y + d[2], real.force.name) then st.powered = true end
                  end
                end
              end
            end
          end
          if b0.state == "fini" then
            st.done_fini = t
            for _, q in ipairs(b0.quais or {}) do
              local ch = s1.find_entity("iron-chest", { q.x, q.y })
              if ch and ch.valid then ch.insert({ name = q.item, count = 600 }) end
            end
            ctx.log(string.format("module %d FINI au tick %d (%d fantome(s) ravives par le banc, %d quai(s) garni(s))", b0.id, t, st.revived or 0, #(b0.quais or {})))
          end
        end
      end
      if st.key and t % 600 == 0 and t >= 600 then
        local s = ctx.remote("fo-ind", "status", st.key)
        local v = ctx.remote("fo-robots-faction", "view", st.key)
        local parts = {}
        for _, b in ipairs(s and s.blocs or {}) do
          local miss = {}
          for _, mm in ipairs(b.missing or {}) do miss[#miss + 1] = tostring(mm[1]) .. " " .. tostring(mm[2]) end
          parts[#parts + 1] = string.format("%d:%s:%s:%d/%d%s", b.id, b.kind, b.state, b.built, b.total,
            (b.reason or #miss > 0) and (" (" .. tostring(b.reason) .. " ; manque " .. table.concat(miss, ", ") .. ")") or "")
        end
        ctx.log(string.format("tick %d : modules [%s] ; ateliers %s, points de robots %s, soldats %s, garnison %s", t, table.concat(parts, " "),
          tostring(v and v.workshops), tostring(v and v.robots), tostring(v and v.by_unit), tostring(v and v.garrison)))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.prototypes or not st.key then return end
      local s = ctx.remote("fo-ind", "status", st.key)
      local c = ctx.remote("fo-ind", "status", st.control)
      local v = ctx.remote("fo-robots-faction", "view", st.key)
      local vc = ctx.remote("fo-robots-faction", "view", st.control)
      ctx.check(c == nil or #c.blocs == 0, "temoin : aucun module (" .. tostring(c and #c.blocs or 0) .. ")")
      ctx.check(vc ~= nil and vc.workshops == 0 and vc.robots == 0, "temoin : aucun atelier, aucun robot")
      if not robots_on then
        ctx.check(v ~= nil and v.workshops == 0 and v.robots == 0 and (s == nil or #s.blocs == 0) and wants_kit(v) == nil,
          "reglage eteint : aucun module, aucun atelier, aucun robot, aucune demande",
          string.format("ateliers %s, robots %s, modules %d", tostring(v and v.workshops), tostring(v and v.robots), s and #s.blocs or 0))
        local ok, why = ctx.remote("fo-robots", "check")
        ctx.check(ok == true, "registre coherent", tostring(why))
        return
      end
      local b = s and s.blocs[1]
      ctx.check(b ~= nil and b.kind == "seul" and b.items[1] == KIT, st.key .. " : le module est une cellule seule du kit",
        b and (b.kind .. " " .. tostring(b.items[1])) or "aucun module")
      if not b then return end
      ctx.check(b.total > 0, "le plan directeur a place la cellule (" .. tostring(b.total) .. " entite(s))")
      ctx.log(string.format("etat final du module %d : %s, %d / %d entite(s) baties", b.id, b.state, b.built, b.total))
      ctx.check(b.state == "fini", "la cellule est finie (" .. tostring(b.state) .. ")", tostring(b.reason))
      ctx.check(v ~= nil and v.workshops >= 1, "un atelier de robots est pose pour la faction", tostring(v and v.workshops))
      local etat = ctx.remote("fo-robots", "state", st.force)
      ctx.check(etat ~= nil and etat.stats.created >= 1 and #etat.units >= 1, "un kit est devenu une unite de la faction",
        etat and string.format("creees %d, unites %d", etat.stats.created, #etat.units) or "etat absent")
      local un = etat and etat.units[1]
      local vue = un and ctx.remote("fo-robots", "faction_view", un)
      ctx.check(vue ~= nil and vue.listed == true and vue.kind == "soldier" and vue.soldiers >= 1 and vue.garrison >= 1,
        "le robot est un SOLDAT de la faction (Military.adopt : inscrit, garnison)",
        vue and string.format("inscrit %s, genre %s, soldats %s, garnison %s", tostring(vue.listed), tostring(vue.kind), tostring(vue.soldiers),
          tostring(vue.garrison)) or "aucune vue")
      local ok, why = ctx.remote("fo-robots", "check")
      ctx.check(ok == true and etat.stats.create_failed == 0, "registre coherent, aucun echec de creation", tostring(why))
      ctx.log(string.format("bilan : ateliers %d, points %d, unites %d, soldats %s, garnison %s", v.workshops, v.robots, #etat.units, tostring(v.by_unit),
        tostring(v.garrison)))
    end,
  }
end
