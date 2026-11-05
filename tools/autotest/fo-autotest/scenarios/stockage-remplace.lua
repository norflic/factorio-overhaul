--[[
  Lot STOCKAGE (essai 3), micro-scénario (1 950 ticks) : remarque du DC du 5/11, 21 h 47 : « j'aurais remplacé un coffre en fer par un coffre
  en acier, le même coffre [...] j'ai posé le coffre par-dessus [...] ils retrouvent plus le coffre ». Écrit, NON lancé (le DC joue) ; BILAN
  attendu : fo-logs/2026-11-05_STOCKAGE/CRITERES.md §4.
    - tick 0 : coffre de votre équipe en (3500, 0) ; 1 coffre en fer et des pierres jusqu'à 96 cases sur 96 (stock au maximum) ;
    - vers le tick 300 : l'équipe pose une annexe en fer ; vers le tick 600 : le rangement du QG plein la remplit ;
    - tick 1 000 : le scénario VIDE l'annexe en fer et pose PAR-DESSUS un coffre en acier vide (create_entity fast_replace, sans événement : le
      cas d'un remplacement que le registre ne voit pas) ; il remplit de nouveau le QG ;
    - tick 1 300 : relevé du coffre A (remplacé) ; le scénario pose un coffre en acier B à l'angle du bloc (11, 11 : hors du rayon d'adoption
      de 12 tuiles), remplit A et le QG ;
    - tick 1 900 : contrôle : A a été rempli par l'équipe avant le tick 1 300, B après.
  Règle du lot : Stock.scan (script/team/stock.lua) retrouve A et B ; le rangement (Stock.balance) les remplit. Témoin (règle d'avant, essai-a) :
  l'ancienne annexe purgée, A et B jamais inscrits, rien rangé. Journal : [FO-STOCKAGE-REMPLACE] (et [FO-STOCKAGE] du mod).
  Limite : posés par script, A et B n'ont pas de joueur (last_user vide) : c'est le cas d'un coffre refait ou remplacé par l'équipe. Le cas
  EXACT du DC (coffre posé par un joueur) passe par la vue de dépôt du lot COFFRES-JOUEUR (Stock.depot = CJs.depot), prouvée par son test ;
  un banc en session avec un joueur le montrerait en moteur.
]]

local AX = 3500
local T_REPLACE, T_B, CHECK = 1000, 1300, 1900

local function area(dx0, dy0, dx1, dy1) return { { AX + dx0, dy0 }, { AX + dx1, dy1 } } end
local function stone_in(e) return (e and e.valid) and e.get_inventory(defines.inventory.chest).get_item_count("stone") or -1 end
local function fill(e)
  if not (e and e.valid) then return end
  local inv = e.get_inventory(defines.inventory.chest)
  inv.insert({ name = "stone", count = 50 * #inv })
end

return {
  description = "STOCKAGE : coffre en fer remplace par-dessus par un coffre en acier, puis coffre pose dans la zone : retrouves et remplis",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 40, -40, AX + 40, 40, "grass-1")
    st.hq = s.create_entity({ name = "fo-team-chest", position = { AX, 0 }, force = "player", raise_built = true })
    ctx.check(st.hq ~= nil, "coffre d'equipe pose")
    if st.hq then
      st.hq.insert({ name = "iron-chest", count = 1 })
      fill(st.hq)
    end
  end,

  tick = function(ctx, e)
    local t = e.tick
    local st = ctx.state()
    local s = ctx.surface()
    if t == T_REPLACE - 50 then
      local found = s.find_entities_filtered({ name = "iron-chest", force = "player", area = area(-12, 4, 12, 12) })
      st.iron = found[1]
      st.iron_stone = stone_in(st.iron)
      ctx.log(string.format("tick %d : annexe en fer de l'equipe %s, %d pierres dedans", t, st.iron and "trouvee" or "ABSENTE", st.iron_stone))
    elseif t == T_REPLACE then
      if st.iron and st.iron.valid then
        st.iron.get_inventory(defines.inventory.chest).clear()
        local p = st.iron.position
        st.a = s.create_entity({ name = "steel-chest", position = p, force = "player", fast_replace = true, spill = false })
        st.a_old_valid = st.iron.valid
      end
      fill(st.hq)
      ctx.log(string.format("tick %d : coffre en acier A pose par-dessus (%s), ancien encore valide : %s", t, tostring(st.a ~= nil),
        tostring(st.a_old_valid)))
    elseif t == T_B - 1 then
      st.a_stone = stone_in(st.a)
    elseif t == T_B then
      st.b = s.create_entity({ name = "steel-chest", position = { AX + 11, 11 }, force = "player" })
      fill(st.a)
      fill(st.hq)
      ctx.log(string.format("tick %d : A contenait %d pierres (rangees par l'equipe) ; coffre en acier B pose en (11, 11)", t, st.a_stone or -1))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local b = stone_in(st.b)
    ctx.log(string.format("FAIT : annexe en fer remplie avant le remplacement : %d ; A rempli par l'equipe : %d ; B rempli par l'equipe : %d",
      st.iron_stone or -1, st.a_stone or -1, b))
    ctx.check((st.iron_stone or 0) > 0, "stock au maximum : l'annexe en fer posee par l'equipe a ete remplie", st.iron_stone or -1)
    ctx.check((st.a_stone or 0) > 0, "coffre en acier pose PAR-DESSUS : retrouve et rempli par l'equipe", st.a_stone or -1)
    ctx.check(b > 0, "coffre en acier pose par le joueur dans la zone : retrouve et rempli par l'equipe", b)
  end,
}
