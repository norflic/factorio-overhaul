--[[
  EFFONDREMENT (décision du DC, 7/11 vers 14 h 25 : « je veux toujours n ouvriers minimum, donc 12 si 12 au départ. Au delas ça coute
  des ressources ») : micro-banc de la recrue GRATUITE de votre équipe sous son effectif de départ (shared/team/spirale.lua).
  État de la partie du DC sur 0.6.58 (157 à 177 min) : 2 PNJ sur 12, aucun fer au coffre, chargeurs au coffre (194), aucun pistolet.
  Mise en place : effectif de départ 12 (fo-npc-start), coffre d'équipe posé (12 PNJ offerts), coffre SANS fer, sans pierre (pas de
  four à fabriquer : le témoin ne doit pas trouver de fer par une autre voie), cuivre 500, charbon 200, 194 chargeurs. Au tick KILL,
  10 PNJ sur 12 sont tués (les plus grands numéros d'unité) : il en reste 2. Relevé toutes les 10 ticks : effectif (fo-ia1 teams),
  recrues, pistolets et fer du coffre, PNJ armés.
  Attendus ÉCRITS AVANT tout passage (fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md) :
    - lot (recrue-gratuite) : première recrue au plus FIRST_MAX ticks après la mise à mort (une pensée de 300 ticks + E4 à T + 3) ;
      effectif revenu à 12 au plus ALL_MAX ticks après ; 10 recrues ; toutes armées d'un pistolet ; aucun pistolet ni fer pris au coffre ;
    - témoin (recrue-gratuite-temoin, sur 0e340b99) : AUCUNE recrue dans la fenêtre, effectif resté à 2 (le cas du DC) ;
    - garde (recrue-gratuite-garde, choix (1) du lead : la garde QGSURVIE reste active sous des biters) : mise à mort au tick 700 (le
      recensement du QG de la prévision existe), 4 biters INERTES (active = false) posés à 40 tuiles du coffre (rayon de la menace : 48 ;
      défense des PNJ : 18), aucune tourelle ; AUCUNE recrue pendant 1 800 ticks ; biters retirés : première recrue au plus FIRST_MAX
      ticks après, effectif revenu à 12 au plus ALL_MAX ticks après.
  Lancement : banc.py --qui EFFONDREMENT -- 3600 recrue-gratuite <source>, puis recrue-gratuite-temoin sur la source témoin.
]]

local KILL = 120
local GARDE_KILL = 700         -- garde : après la pensée du tick 174 (recensement du QG par la prévision, frais 3 min)
local GARDE_HOLD = 1800        -- garde : biters présents 30 s (6 pensées)
local BITERS = 4
local BITER_D = 40
local FIRST_MAX = 310          -- 300 (pensée) + 3 (E4) + marge
local ALL_MAX = 9 * 300 + FIRST_MAX
local STEP = 10
local START = 12
local LEFT = 2
local GUN = "pistol"

local function chest_of(ctx)
  return ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
end

local function team(ctx)
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key == "player" then return r end
  end
  return nil
end

--- PNJ de votre équipe près du coffre (personnages de la force du joueur), triés par numéro d'unité.
local function workers(ctx, chest)
  local list = {}
  for _, c in ipairs(ctx.surface().find_entities_filtered({ type = "character", force = "player", position = chest.position, radius = 80 })) do
    if c.valid and not c.player then list[#list + 1] = c end
  end
  table.sort(list, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  return list
end

local function armed(c)
  local inv = c.valid and c.get_inventory(defines.inventory.character_guns)
  return inv ~= nil and inv.get_item_count(GUN) > 0
end

return function(mode)
  local lot = mode ~= false -- true (lot) ou "garde"
  local garde = mode == "garde"
  local TAG = "RECRUE-GRATUITE" .. (garde and "-GARDE" or (lot and "" or "-TEMOIN"))
  local KILL_T = garde and GARDE_KILL or KILL
  local LIFT = garde and (KILL_T + GARDE_HOLD) or nil
  local REF = LIFT or KILL_T -- départ des délais mesurés (mise à mort, ou retrait des biters)
  local CHECK = REF + ALL_MAX + 90
  return {
    description = string.format("EFFONDREMENT : votre equipe tombee a %d PNJ sur %d, sans fer ni pistolet au coffre (%s)", LEFT, START,
      garde and "garde QG sous des biters, puis recrue gratuite" or (lot and "recrue gratuite attendue" or "temoin 0.6.58 : aucune recrue attendue")),
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local st = ctx.state()
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", START) == START, "effectif de depart " .. START)
      local s = ctx.surface()
      local c0 = game.forces.player.get_spawn_position(s)
      local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
      local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      local inv = chest.get_inventory(defines.inventory.chest)
      for _, it in ipairs({ "iron-plate", "iron-ore", "stone", "pistol", "iron-gear-wheel" }) do inv.remove({ name = it, count = 100000 }) end
      inv.insert({ name = "copper-plate", count = 500 })
      inv.insert({ name = "coal", count = 200 })
      inv.insert({ name = "firearm-magazine", count = 194 })
      local r = team(ctx)
      ctx.check(r ~= nil and r.n == START, "equipe creee a " .. START .. " PNJ", tostring(r and r.n))
      st.hq = { x = chest.position.x, y = chest.position.y }
      st.samples = 0
      ctx.log(string.format("[FO-%s] depart : coffre en %.1f,%.1f ; PNJ %s", TAG, st.hq.x, st.hq.y, tostring(r and r.n)))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.hq then return end
      local t = e.tick
      local chest = chest_of(ctx)
      if not chest then return end
      if t == KILL_T then
        local inv = chest.get_inventory(defines.inventory.chest)
        for _, it in ipairs({ "iron-plate", "iron-ore", "pistol" }) do inv.remove({ name = it, count = 100000 }) end
        local list = workers(ctx, chest)
        local killed = 0
        for i = #list, LEFT + 1, -1 do
          list[i].die()
          killed = killed + 1
        end
        local r = team(ctx)
        st.n0 = r and r.n or -1
        st.rec0 = r and r.recruited or 0
        st.killed = killed
        st.first, st.full = nil, nil
        st.pistols0 = inv.get_item_count(GUN)
        st.max_iron, st.max_pistols = 0, 0
        ctx.log(string.format("[FO-%s] mise a mort au tick %d : %d PNJ tues, effectif %d", TAG, t, killed, st.n0))
        if garde then
          local s = ctx.surface()
          st.biters, st.biter_d = {}, {}
          for i = 1, BITERS do
            local want = { x = chest.position.x + BITER_D, y = chest.position.y + (i - 2.5) * 3 }
            local bp = s.find_non_colliding_position("small-biter", want, 8, 0.5)
            local b = bp and s.create_entity({ name = "small-biter", position = bp, force = "enemy" })
            if b then
              b.active = false
              st.biters[#st.biters + 1] = b
              st.biter_d[#st.biter_d + 1] = math.sqrt((bp.x - chest.position.x) ^ 2 + (bp.y - chest.position.y) ^ 2)
            end
          end
          ctx.log(string.format("[FO-%s] %d biter(s) inerte(s) poses a %s tuiles du coffre", TAG, #st.biters,
            table.concat((function() local o = {} for _, d in ipairs(st.biter_d) do o[#o + 1] = string.format("%.1f", d) end return o end)(), ",")))
        end
        return
      end
      if garde and st.n0 and t == LIFT then
        local alive = 0
        for _, b in ipairs(st.biters or {}) do
          if b.valid then
            alive = alive + 1
            b.destroy()
          end
        end
        local r = team(ctx)
        st.alive_at_lift = alive
        st.n_lift = r and r.n or -1
        st.rec_hold = (r and r.recruited or 0) - st.rec0
        ctx.log(string.format("[FO-%s] retrait des biters au tick %d : %d encore la, effectif %d, recrues pendant la menace %d", TAG, t, alive,
          st.n_lift, st.rec_hold))
        return
      end
      if not st.n0 or t <= KILL_T or t % STEP ~= 0 or t > CHECK - 10 then return end
      st.samples = st.samples + 1
      local r = team(ctx)
      local n = r and r.n or -1
      local inv = chest.get_inventory(defines.inventory.chest)
      st.max_iron = math.max(st.max_iron, inv.get_item_count("iron-plate"))
      st.max_pistols = math.max(st.max_pistols, inv.get_item_count(GUN))
      if not st.first and n > (st.n_lift or st.n0) and (not LIFT or t > LIFT) then
        st.first = t - REF
        ctx.log(string.format("[FO-%s] premiere recrue %d ticks apres la mise a mort (effectif %d)", TAG, st.first, n))
      end
      if not st.full and n >= START then
        st.full = t - REF
        ctx.log(string.format("[FO-%s] effectif revenu a %d, %d ticks apres la mise a mort", TAG, n, st.full))
      end
      if (t - KILL_T) % 600 == 0 then
        ctx.log(string.format("[FO-%s] +%d ticks | effectif %d | recrues %d | fer au coffre %d | pistolets au coffre %d", TAG, t - KILL_T, n,
          (r and r.recruited or 0) - st.rec0, inv.get_item_count("iron-plate"), inv.get_item_count(GUN)))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local chest = chest_of(ctx)
      if not (st.n0 and chest) then
        ctx.check(false, "la mise a mort a eu lieu", "tick " .. tostring(KILL_T))
        return
      end
      local r = team(ctx)
      local n = r and r.n or -1
      local rec = (r and r.recruited or 0) - st.rec0
      local list = workers(ctx, chest)
      local n_armed = 0
      for _, c in ipairs(list) do if armed(c) then n_armed = n_armed + 1 end end
      ctx.log(string.format("[FO-%s] RESULTAT tues=%d effectif_apres=%d effectif_fin=%d recrues=%d premiere=%s plein=%s armes=%d/%d fer_max=%d pistolets_max=%d echantillons=%d",
        TAG, st.killed, st.n0, n, rec, tostring(st.first), tostring(st.full), n_armed, #list, st.max_iron, st.max_pistols, st.samples))
      ctx.check(st.killed == START - LEFT and st.n0 == LEFT, "10 PNJ tues, il en reste 2", string.format("%d tues, effectif %d", st.killed, st.n0))
      ctx.check(st.max_iron == 0 and st.max_pistols == 0, "coffre sans fer ni pistolet pendant toute la fenetre",
        string.format("fer max %d, pistolets max %d", st.max_iron, st.max_pistols))
      if garde then
        local dmin, dmax = 1e9, 0
        for _, d in ipairs(st.biter_d or {}) do dmin, dmax = math.min(dmin, d), math.max(dmax, d) end
        ctx.check(#(st.biters or {}) == BITERS and dmin >= 30 and dmax <= 46, BITERS .. " biters inertes poses entre 30 et 46 tuiles du coffre",
          string.format("%d, de %.1f a %.1f", #(st.biters or {}), dmin, dmax))
        ctx.check(st.rec_hold == 0 and st.n_lift == LEFT and st.alive_at_lift == BITERS,
          "garde QG : aucune recrue pendant " .. GARDE_HOLD .. " ticks sous les biters (0 tourelle armee)",
          string.format("%s recrue(s), effectif %s, biters encore la %s", tostring(st.rec_hold), tostring(st.n_lift), tostring(st.alive_at_lift)))
      end
      if lot then
        ctx.check(st.first ~= nil and st.first <= FIRST_MAX, "premiere recrue au plus " .. FIRST_MAX .. " ticks apres", tostring(st.first))
        ctx.check(st.full ~= nil and st.full <= ALL_MAX and n == START, "effectif revenu a " .. START .. " au plus " .. ALL_MAX .. " ticks apres",
          string.format("plein a %s, effectif %d", tostring(st.full), n))
        ctx.check(rec == START - LEFT, "10 recrues", tostring(rec))
        ctx.check(n_armed == #list and #list == START, "toutes armees d'un pistolet", string.format("%d/%d", n_armed, #list))
      else
        ctx.check(rec == 0 and n == LEFT, "temoin : aucune recrue, effectif reste a 2 (cas du DC)", string.format("%d recrue(s), effectif %d", rec, n))
      end
    end,
  }
end
