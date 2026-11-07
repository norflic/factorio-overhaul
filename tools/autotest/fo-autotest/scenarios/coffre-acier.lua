--[[
  Lot COFFRES-JOUEUR, micro-scénario (300 ticks ; avec un VRAI joueur : `banc.py --captures`) : remarques du DC du 5/11 (« Les ressources dans
  les coffres que j'ai posés n'ont jamais été utilisées » ; 21 h 47 : coffre en acier posé PAR-DESSUS un coffre en fer, « ils retrouvent plus
  le coffre » ; « comme c'est un coffre que j'ai posé, ils devraient [...] pouvoir l'utiliser parce qu'il y a beaucoup d'espace »).
    - tick 0 : coffre de votre équipe en (3700, 0), plein de pierres (le stock ne peut plus rien recevoir ni servir de fer) ;
    - tick 120 (joueur de la session avec images) : le JOUEUR pose, à 20-40 tuiles au nord-est (hors de la zone de stockage des annexes) :
        A coffre en acier, 200 plaques de fer ; B coffre en acier vide ; R coffre en fer ; D coffre en fer de 30 fers avec un bras qui y DÉPOSE
        (sortie d'une chaîne du joueur) ; et l'équipe... rien : T coffre en fer posé SANS joueur (dernier utilisateur vide) ;
    - tick 125 : le joueur pose un coffre en acier PAR-DESSUS R (remplacement rapide : nouvelle entité, nouveau numéro) ;
    - tick 130 : listes refaites (interface fo-ia1 bench_stock « refresh ») ; dans le MÊME tick : 50 fers pris au stock de l'équipe
      (Stock.remove), 100 cuivres déposés (Stock.insert) ;
    - tick 200 : contrôles. Attendu : A, B, R (nouveau), D dans la PRISE ; A, B et R dans le DÉPÔT (coffres ordinaires sans bras), pas D ;
      T nulle part ; 50 fers pris dans A (le plus proche) ; 100 cuivres déposés dans A, B ou R (du plus proche au plus lointain), jamais dans
      D ; rien en attente.
  Sans joueur (banc sans images) : les coffres ne peuvent pas porter de dernier utilisateur ; le scénario le journalise et ne contrôle que
  l'équipe fondée. Journal : [FO-COFFRE-ACIER] (et [FO-COFFRES-JOUEUR] du mod).
]]

local AX, AY = 3700, 0
local T_POSE, T_REPL, T_MESURE, CHECK = 120, 125, 130, 200

local function at(dx, dy) return { x = AX + dx + 0.5, y = AY + dy + 0.5 } end
local function count(e, item) return (e and e.valid) and e.get_inventory(defines.inventory.chest).get_item_count(item) or -1 end
local function near(row, e) return e and e.valid and math.abs(row.x - e.position.x) < 0.1 and math.abs(row.y - e.position.y) < 0.1 end
local function member(rows, e)
  for _, r in ipairs(rows or {}) do if near(r, e) then return true end end
  return false
end

return {
  description = "COFFRES-JOUEUR : coffres du joueur lus, vides, remplis par l'equipe ; coffre en acier pose par-dessus retrouve",
  check_tick = CHECK,
  shots_delay = CHECK + 10,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 50, AY - 50, AX + 50, AY + 50, "grass-1")
    st.hq = s.create_entity({ name = "fo-team-chest", position = { AX, AY }, force = "player", raise_built = true })
    ctx.check(st.hq ~= nil, "coffre de votre equipe pose (equipe fondee)")
    if st.hq then
      local inv = st.hq.get_inventory(defines.inventory.chest)
      inv.insert({ name = "stone", count = 50 * #inv })
      st.hq_full = inv.count_empty_stacks() == 0
    end
    ctx.check(st.hq_full, "coffre de votre equipe plein de pierres (aucune place, aucun fer)")
  end,

  tick = function(ctx, e)
    local t = e.tick
    if t ~= T_POSE and t ~= T_REPL and t ~= T_MESURE then return end
    local st = ctx.state()
    local s = ctx.surface()
    local p = game.players[1]
    if t == T_POSE then
      st.player = p ~= nil
      if not p then
        ctx.log("tick 120 : AUCUN joueur (banc sans images) : les coffres ne peuvent pas porter de dernier utilisateur ; lancer avec --captures")
        return
      end
      local function put(name, dx, dy, items, who)
        local en = s.create_entity({ name = name, position = at(dx, dy), force = "player", player = who })
        if en and items then for k, v in pairs(items) do en.insert({ name = k, count = v }) end end
        return en
      end
      st.a = put("steel-chest", 20, -20, { ["iron-plate"] = 200 }, p)
      st.b = put("steel-chest", 24, -20, nil, p)
      st.r = put("iron-chest", 28, -20, nil, p)
      st.d = put("iron-chest", 36, -20, { ["iron-plate"] = 30 }, p)
      st.t = put("iron-chest", 40, -20, { ["iron-plate"] = 40 }, nil)
      -- Bras qui DÉPOSE dans D (au nord de D) : la direction qui le fait déposer dans D.
      -- drop_target reste vide tant que le bras n'a pas tourné (moteur réel, 7/11) : la direction se choisit sur drop_position.
      local box = st.d and st.d.bounding_box
      for _, dir in ipairs({ defines.direction.north, defines.direction.south }) do
        local ins = s.create_entity({ name = "inserter", position = at(36, -21), direction = dir, force = "player", player = p })
        local q = ins and ins.drop_position
        if q and box and q.x >= box.left_top.x and q.x <= box.right_bottom.x and q.y >= box.left_top.y and q.y <= box.right_bottom.y then
          st.ins = ins
          break
        end
        if ins then ins.destroy() end
      end
      st.r_unit = st.r and st.r.unit_number
      ctx.log(string.format("tick %d : joueur %s ; A %s, B %s, R %s, D %s (bras qui y depose : %s), T %s (sans joueur)", t, p.name,
        tostring(st.a ~= nil), tostring(st.b ~= nil), tostring(st.r ~= nil), tostring(st.d ~= nil), tostring(st.ins ~= nil), tostring(st.t ~= nil)))
    elseif t == T_REPL and st.player and st.r then
      local old = st.r
      st.r = s.create_entity({ name = "steel-chest", position = old.position, force = "player", fast_replace = true, spill = false, player = p })
      st.r_old_valid = old.valid
      st.r_new_unit = st.r and st.r.unit_number
      ctx.log(string.format("tick %d : coffre en acier pose PAR-DESSUS R : %s, ancien valide : %s, numero %s -> %s", t, tostring(st.r ~= nil),
        tostring(st.r_old_valid), tostring(st.r_unit), tostring(st.r_new_unit)))
    elseif t == T_MESURE and st.player then
      local lists = ctx.remote("fo-ia1", "bench_stock", "player", "refresh")
      st.take, st.depot = lists and lists.take or {}, lists and lists.depot or {}
      local c0 = ctx.remote("fo-ia1", "bench_stock", "player", "count", "iron-plate")
      local a0 = count(st.a, "iron-plate")
      st.got = ctx.remote("fo-ia1", "bench_stock", "player", "remove", "iron-plate", 50)
      st.c1 = ctx.remote("fo-ia1", "bench_stock", "player", "count", "iron-plate")
      st.c0, st.a_taken = c0, a0 - count(st.a, "iron-plate")
      local before = count(st.a, "copper-plate") + count(st.b, "copper-plate") + count(st.r, "copper-plate")
      st.put = ctx.remote("fo-ia1", "bench_stock", "player", "insert", "copper-plate", 100)
      st.cu = count(st.a, "copper-plate") + count(st.b, "copper-plate") + count(st.r, "copper-plate") - before
      st.cu_d = count(st.d, "copper-plate")
      ctx.log(string.format("tick %d : prise %d/%d (lisible %d -> %d, A -%d) ; depot %d/%d (A+B+R +%d, D %d) ; prise %d coffre(s), depot %d", t,
        st.got or -1, 50, c0 or -1, st.c1 or -1, st.a_taken, st.put or -1, 100, st.cu, st.cu_d, #st.take, #st.depot))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.player then
      ctx.log("FAIT : session sans joueur : partie joueur non jouee (lancer : banc.py --captures)")
      return
    end
    ctx.check(st.a and st.b and st.r and st.d and st.t and st.ins, "coffres et bras poses par le joueur (T sans joueur)")
    ctx.check(st.r and st.r.valid and st.r_old_valid == false and st.r_new_unit ~= st.r_unit,
      "coffre en acier pose PAR-DESSUS R : nouvelle entite, nouveau numero", string.format("%s -> %s", tostring(st.r_unit), tostring(st.r_new_unit)))
    ctx.check(member(st.take, st.a) and member(st.take, st.b) and member(st.take, st.r) and member(st.take, st.d) and not member(st.take, st.t),
      "PRISE : A, B, R (remplace), D ; pas T (pose sans joueur)", #st.take .. " coffre(s)")
    ctx.check(member(st.depot, st.b) and member(st.depot, st.r) and not member(st.depot, st.d) and not member(st.depot, st.t),
      "DEPOT : B et R (remplace) ; pas D (un bras y depose), pas T", #st.depot .. " coffre(s)")
    ctx.check(st.got == 50 and st.a_taken == 50 and (st.c0 or 0) >= 230 and st.c1 == st.c0 - 50,
      "50 fers pris au stock de l'equipe, dans le coffre A du joueur (le QG n'en a pas)", string.format("%s pris, A -%s, lisible %s -> %s",
        tostring(st.got), tostring(st.a_taken), tostring(st.c0), tostring(st.c1)))
    ctx.check(st.put == 100 and st.cu == 100 and st.cu_d == 0,
      "100 cuivres deposes (QG plein) dans les coffres de depot du joueur, rien dans D (sortie de chaine)", string.format("%s rendus, +%s, D %s",
        tostring(st.put), tostring(st.cu), tostring(st.cu_d)))
  end,

  shots = function(ctx, add)
    add("coffres-joueur", AX + 30, AY - 20, 1.5, 0.5, { info = true })
    add("qg-equipe", AX, AY, 1.5, 0.5, { info = true })
  end,
}
