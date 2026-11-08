--[[
  Lot MESURE-MODULE (8/11/2026) : micro-banc du dedoublonnage des coffres d'un projet (cause du « dort » a 4 fois le contenu : plan_feed
  ajoutait les coffres a p.quais / p.outs a chaque plan, un plan qui attendait puis recommencait en laissait N copies).
  Scene (equipe du joueur, comme collecte-fer) : coffre d'equipe pose (400 charbon), puis, des que l'equipe compte au moins 4 PNJ, a T0 :
    - un projet « fini » de banc tient 2 coffres de sortie de fer (A 600 plaques, C 400 plaques) ; un coffre d'entree de charbon (vide) est
      ajoute, et les listes p.outs / p.quais sont repetees 4 fois (8 sorties, 4 quais : le cas du projet 3 de la partie du DC, a 3 attentes) ;
    - PHASE 1 « avant » : p.sites_v = 1 (le dedoublonnage ne passe pas) : les taches en double s'installent au tableau comme dans la
      sauvegarde du DC ; releve toutes les 60 ticks pendant 900 ticks ;
    - PHASE 2 « apres » : p.sites_v remis a nil : la passe du plan directeur dedoublonne (Build.dedupe_sites) au prochain passage ; releve toutes
      les 60 ticks pendant 600 ticks.
  Controles ECRITS AVANT :
    K0 l'injection a eu lieu : 8 sorties et 4 quais ;
    K1 PHASE 1 : le tableau porte plus de taches de collecte (>= 4) que de coffres (2) : le defaut se voit (sinon la scene ne prouve rien) ;
    K2 PHASE 2 : 2 sorties, 1 quai, p.sites_v = 1 ;
    K3 PHASE 2 : jamais plus de taches de collecte que de coffres (2), jamais plus d'une tache de remplissage, et aucune cle d'indice
       au-dela des listes (o:3 a o:8, q:2 a q:4) a la fin ; une tache prise avant le dedoublonnage reste prise (jamais jetee) ;
    K4 au moins une tache de collecte ou de remplissage existe encore apres (la passe n'a pas tout jete).
  Le mod ecrit « [FO-SITES] ... copie(s) ... retiree(s) » au journal (a lire dans benchmark.log).
  Lancement : banc.py --out <archive> --qui MESURE-MODULE -- 5000 sites-doublon <source>   (check au tick 4800)
  Journal : [FO-SITES-DOUBLON].
]]

local EVERY = 60
local T_MAX = 2400
local HOLD = 900
local AFTER = 600
local CHECK = 4800

local function spot(ctx, hq, dx, dy)
  local s = ctx.surface()
  local p = s.find_non_colliding_position("iron-chest", { x = hq.x + dx, y = hq.y + dy }, 12, 1)
  return p or { x = hq.x + dx, y = hq.y + dy }
end

local function brief(s)
  if not s then return "etat absent" end
  return string.format("sorties %d quais %d sites_v %s | collecte %d remplissage %d prises %d | %s", s.outs, s.quais, tostring(s.sites_v), s.collect,
    s.fill, s.taken, table.concat(s.keys, " "))
end

--- Plus grand indice des cles « ia1d:<pid>:o|q:<i> » d'un releve.
local function max_idx(s, letter)
  local m = 0
  for _, k in ipairs(s.keys) do
    local base = k:gsub("%*$", "")
    local l, i = base:match(":([oq]):(%d+)$")
    if l == letter and tonumber(i) > m then m = tonumber(i) end
  end
  return m
end

return {
  description = "MESURE-MODULE : projet dont les listes de coffres sont x4, taches en double au tableau, puis dedoublonnage",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8 a la fondation")
    local s = ctx.surface()
    local c0 = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
    local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    chest.get_inventory(defines.inventory.chest).insert({ name = "coal", count = 400 })
    st.hq = { x = chest.position.x, y = chest.position.y }
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.hq or e.tick < 300 then return end
    if not st.t0 then
      if e.tick % 60 ~= 0 then return end
      local row
      for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do if r.key == "player" then row = r end end
      if (row and row.n >= 4) or e.tick >= T_MAX then
        local hq = st.hq
        st.A, st.C = spot(ctx, hq, 40, 0), spot(ctx, hq, 0, 45)
        st.Q = spot(ctx, hq, -12, 8)
        local r = ctx.remote("fo-ia1", "bench_collecte", "player", 4, { { st.A.x, st.A.y, 600 }, { st.C.x, st.C.y, 400 } })
        ctx.check(r ~= nil and r.outs == 2, "projet de banc : 2 coffres de sortie", r and tostring(r.outs) or "nil")
        st.pid = r and r.project
        if not st.pid then return end
        local d = ctx.remote("fo-ia1", "bench_sites_dup", "player", st.pid, 4, { x = st.Q.x, y = st.Q.y, item = "coal" }, true)
        ctx.check(d ~= nil and d.outs == 8 and d.quais == 4, "K0 : injection : 8 sorties et 4 quais", d and (d.outs .. "/" .. d.quais) or "nil")
        st.t0 = e.tick
        st.before = { collect = 0, fill = 0, taken = 0 }
        ctx.log(string.format("T0=%d : projet %s, A (%.0f,%.0f) C (%.0f,%.0f) quai (%.0f,%.0f), injection %s", e.tick, tostring(st.pid), st.A.x, st.A.y,
          st.C.x, st.C.y, st.Q.x, st.Q.y, d and (d.outs .. "/" .. d.quais) or "nil"))
      end
      return
    end
    local dt = e.tick - st.t0
    if e.tick % EVERY ~= 0 then return end
    local s = ctx.remote("fo-ia1", "bench_sites_state", "player", st.pid)
    if not s then return end
    if dt <= HOLD then
      -- PHASE 1 : on garde le plus grand nombre de taches en double vu
      if s.collect > st.before.collect then st.before.collect = s.collect end
      if s.fill > st.before.fill then st.before.fill = s.fill end
      if s.taken > st.before.taken then st.before.taken = s.taken end
      ctx.log(string.format("avant t0+%d | %s", dt, brief(s)))
      if dt + EVERY > HOLD and not st.released then
        st.released = true
        st.taken_keys = {}
        for _, k in ipairs(s.keys) do if k:sub(-1) == "*" then st.taken_keys[#st.taken_keys + 1] = k end end
        local d = ctx.remote("fo-ia1", "bench_sites_dup", "player", st.pid, 1, nil, false)
        ctx.log(string.format("LIBERE a t0+%d : p.sites_v remis a nil (listes %s), prises avant : [%s]", dt, d and (d.outs .. "/" .. d.quais) or "nil",
          table.concat(st.taken_keys, " ")))
      end
      return
    end
    -- PHASE 2
    st.after = st.after or { collect = 0, fill = 0, outs = 0, quais = 0, any = false, bad_idx = false }
    local a = st.after
    if s.collect > a.collect then a.collect = s.collect end
    if s.fill > a.fill then a.fill = s.fill end
    if s.collect + s.fill > 0 then a.any = true end
    a.outs, a.quais, a.sites_v = s.outs, s.quais, s.sites_v
    a.last = s
    ctx.log(string.format("apres t0+%d | %s", dt, brief(s)))
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.t0 or not st.pid then
      ctx.check(false, "T0 a eu lieu (equipe fondee, 4 PNJ au moins)", "tick " .. tostring(CHECK))
      return
    end
    local b, a = st.before or {}, st.after or {}
    ctx.log(string.format("RESULTAT avant : collecte max %s remplissage max %s prises max %s | apres : sorties %s quais %s sites_v %s collecte max %s remplissage max %s",
      tostring(b.collect), tostring(b.fill), tostring(b.taken), tostring(a.outs), tostring(a.quais), tostring(a.sites_v), tostring(a.collect), tostring(a.fill)))
    ctx.check((b.collect or 0) >= 4, "K1 : avant, plus de taches de collecte que de coffres (>= 4 pour 2 coffres)", tostring(b.collect))
    ctx.check(a.outs == 2 and a.quais == 1 and a.sites_v == 1, "K2 : apres, 2 sorties, 1 quai, p.sites_v = 1",
      string.format("%s/%s/%s", tostring(a.outs), tostring(a.quais), tostring(a.sites_v)))
    local last = a.last
    ctx.check((a.collect or 99) <= 2 and (a.fill or 99) <= 1 and last ~= nil and max_idx(last, "o") <= 2 and max_idx(last, "q") <= 1,
      "K3 : apres, jamais plus de taches que de coffres, aucune cle au-dela des listes",
      string.format("collecte max %s remplissage max %s o<=%d q<=%d", tostring(a.collect), tostring(a.fill), last and max_idx(last, "o") or -1,
        last and max_idx(last, "q") or -1))
    ctx.check(a.any == true, "K4 : des taches de collecte ou de remplissage existent encore apres")
    ctx.log("Prises avant le dedoublonnage : [" .. table.concat(st.taken_keys or {}, " ") .. "] ; lire aussi [FO-SITES] dans benchmark.log")
  end,
}
