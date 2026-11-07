--[[
  Lot VIDEO-COUVERTURE 3 (V59, C3.1) : micro-banc du manque mesuré d'un module de LABORATOIRES.
  Scène (équipe du joueur, comme collecte-fer) : coffre d'équipe posé, puis, dès que l'équipe compte au moins 2 PNJ, à T0 :
    - 300 packs rouges au coffre d'équipe (de quoi payer la recherche la moins chère et remplir le quai de A) ;
    - courant invisible (Terrain.power) autour des deux laboratoires ;
    - interface de banc fo-manque (script/team/manque_banc.lua) : DEUX projets « finis » du gabarit des laboratoires, chacun avec un laboratoire
      posé SANS pack et un coffre de quai ; le manque mesuré est recalculé toutes les 2 s le temps du banc.
        A : son quai attend des packs rouges (priorité PRIO_BANC) : le plan peut le remplir ;
        B : son quai attend un AUTRE pack (le coffre n'en a pas) : aucune tournée possible, rien en route, le laboratoire reste sans pack rouge.
  Relevé toutes les 60 ticks : manque publié (f.team.mq.res), module affamé ou non, tâche de remplissage du quai (priorité, prise), contenu du quai.
  Contrôles ÉCRITS AVANT (fo-logs/2026-11-07_VIDEO-COUVERTURE/SYNTHESE.txt, critère C3.1 et micro-banc du lot 3) :
    M1 aucun des deux laboratoires n'est jamais « sans courant » (la scène tient) ;
    M2 B : dès qu'une technologie est en file, le manque de packs rouges du laboratoire est PUBLIÉ (> 0) et le module est affamé ;
    M2b A : tant que la tournée de remplissage est PRISE et le quai vide (les packs sont en route), le manque publié est 0 (transit compté) ;
    M3 A : une tâche de remplissage vers le quai du laboratoire, portant des packs rouges, est ÉMISE ;
    M3b A : elle est PRISE moins de T_PRISE ticks après T0 ;
    M4 A : une fois le quai garni, le prochain calcul du manque publie 0 (laboratoire plein : 0 publié).
  Pourquoi PRIO_BANC et pas la priorité ordinaire d'un projet (60, remplissage à 63) : mesuré en 5 passages de ce banc (archives
  fo-logs/2026-11-07_VIDEO-COUVERTURE/video-manque/manque-labo-1 à -5), une équipe qui démarre sans fer sert d'abord son minage (90) et ses
  recherches : le remplissage à 63 reste « libre » 35 s de suite (1 passage), et un remplissage à 93 né APRÈS les 10 premières secondes
  (1 passage) reste libre lui aussi, tous les PNJ étant tenus. Un remplissage à 93 présent dès T0 est pris en 2 s (passages 2 et 5). Mais alors
  les packs sont EN ROUTE et le manque est nul : d'où le laboratoire B, qui ne peut pas être servi, pour voir le manque publié.
  Lancement (par la file, jamais --seul) :
    banc.py --out <archive> --qui video-manque -- 2400 manque-labo <worktree>
  Journaux : [FO-MANQUE-LABO] (ce banc), [FO-MANQUE] (le mod : modules affamés).
]]

local T_MAX = 1500          -- au plus tard : T0 doit avoir eu lieu (équipe fondée, au moins 2 PNJ)
local T_PRISE = 1500        -- la tâche de remplissage est prise au plus tard 25 s après T0
local EVERY = 60
local CHECK = 2300
local PACK = "automation-science-pack"
local LAB = "lab"
local PACK_B = "logistic-science-pack" -- le quai de B attend ce pack : le coffre d'équipe n'en a pas
local PRIO_BANC = 90        -- projet de banc : son remplissage passe à 93, devant le minage du fer d'une équipe qui démarre

local function chest_of(ctx)
  return ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
end

local function line_of(tag, s)
  if not s then return "etat absent" end
  return string.format("%s manque %.2f | affame %s | techno %s | calc t%s | refus %d sans-courant %d | remplissage %s | quai %d | labo %s packs %s | QG %d",
    tag, s.need or -1, tostring(s.starved), tostring(s.tech), tostring(s.calc_tick), s.refused or -1, s.no_power_modules or -1,
    s.fill and string.format("p%s %s n%s", tostring(s.fill.prio), s.fill.prise and "PRISE" or "libre", tostring(s.fill.count)) or "aucun",
    s.quai or -1, tostring(s.lab_status), tostring(s.lab_packs), s.hq_packs or -1)
end

return {
  description = "VIDEO-COUVERTURE 3 : un module de laboratoires sans pack rouge, une technologie en file : manque publie, remplissage pris, quai garni = manque nul",
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
    if not st.hq or e.tick < 120 then return end
    if not st.t0 and e.tick % 60 == 0 then
      local row
      for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do if r.key == "player" then row = r end end
      if (row and row.n >= 2) or e.tick >= T_MAX then
        local hq = st.hq
        -- terrain : l'emplacement du quai et du laboratoire, à 40 tuiles à l'est du coffre d'équipe, dégagé de tout
        local lx, ly = math.floor(hq.x) + 40, math.floor(hq.y) + 4
        ctx.prepare_area(lx - 6, ly - 6, lx + 10, ly + 20, "grass-1")
        st.power = ctx.power(lx + 6, ly + 6, "player") ~= nil
        local chest = chest_of(ctx)
        if chest then chest.get_inventory(defines.inventory.chest).insert({ name = PACK, count = 300 }) end
        local qx, qy = lx - 2.5, ly + 1.5
        local r = ctx.remote("fo-manque", "bench_labo", "player", PACK, LAB, qx, qy, lx, ly, PRIO_BANC)
        local rb = ctx.remote("fo-manque", "bench_labo", "player", PACK, LAB, qx, qy + 10, lx, ly + 10, nil, PACK_B)
        ctx.check(r ~= nil and r.project ~= nil and rb ~= nil and rb.project ~= nil, "deux projets de laboratoires de banc poses")
        st.pid = r and r.project
        st.pidb = rb and rb.project
        st.t0 = e.tick
        ctx.log(string.format("T0=%d : courant %s, projets A %s et B %s, laboratoires %s et %s, quai A (%.1f,%.1f)", e.tick, tostring(st.power),
          tostring(st.pid), tostring(st.pidb), tostring(r and r.lab), tostring(rb and rb.lab), qx, qy))
      end
      return
    end
    if not st.t0 or not st.pid or not st.pidb then return end
    local dt = e.tick - st.t0
    if e.tick % EVERY ~= 0 then return end
    local s = ctx.remote("fo-manque", "labo_state", "player", st.pid, PACK)
    if not s then return end
    local sb = ctx.remote("fo-manque", "labo_state", "player", st.pidb, PACK)
    if not sb then return end
    if dt % 300 == 0 then ctx.log(string.format("t0+%d | %s | %s", dt, line_of("A", s), line_of("B", sb))) end
    if s.lab_no_power or sb.lab_no_power then st.no_power = (st.no_power or 0) + 1 end
    if sb.tech ~= nil and (sb.need or 0) > 0 and sb.starved and sb.starved:find(PACK, 1, true) and not st.pub then
      st.pub = dt
      st.pub_need = sb.need
      ctx.log(string.format("t0+%d : MANQUE PUBLIE (B) %.2f/min de %s, module affame (%s), technologie %s", dt, sb.need, PACK, tostring(sb.starved), tostring(sb.tech)))
    end
    if s.fill and s.fill.prise and not st.take then
      st.take = dt
      st.take_tick = e.tick
      ctx.log(string.format("t0+%d : remplissage PRIS a la priorite %s", dt, tostring(s.fill.prio)))
    end
    -- transit : tournée prise, quai encore vide, calcul fait APRÈS la prise : les packs en route comptent
    if st.take_tick and st.transit_need == nil and s.fill and s.fill.prise and s.quai == 0 and (s.calc_tick or 0) > st.take_tick and s.tech ~= nil then
      st.transit_need = s.need or 0
      ctx.log(string.format("t0+%d : EN ROUTE, quai vide : manque publie %.2f", dt, st.transit_need))
    end
    if s.fill and not st.fill_seen then
      st.fill_seen = dt
      st.fill_count = s.fill.count
    end
    if s.quai >= 4 and not st.full then
      st.full = dt
      st.full_tick = e.tick
    end
    -- le premier calcul du manque APRÈS que le quai est garni (période de banc : 2 s)
    if st.full_tick and st.full_need == nil and (s.calc_tick or 0) > st.full_tick then st.full_need = s.need or 0 end
    st.last = s
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.t0 then
      ctx.check(false, "T0 a eu lieu (equipe fondee, 2 PNJ au moins)", "tick " .. tostring(CHECK))
      return
    end
    local s = ctx.remote("fo-manque", "labo_state", "player", st.pid, PACK) or st.last or {}
    ctx.log(string.format("RESULTAT courant=%s sans_courant=%s publie_B=%s manque_B=%s en_route_A=%s remplissage_vu=%s pris=%s quai_garni=%s manque_apres=%s quai=%s techno=%s",
      tostring(st.power), tostring(st.no_power or 0), tostring(st.pub), tostring(st.pub_need), tostring(st.transit_need), tostring(st.fill_seen),
      tostring(st.take), tostring(st.full), tostring(st.full_need), tostring(s.quai), tostring(s.tech)))
    ctx.check(st.power == true and (st.no_power or 0) == 0, "M1 : aucun laboratoire n'est jamais sans courant", tostring(st.no_power))
    ctx.check(st.pub ~= nil and (st.pub_need or 0) > 0, "M2 : B : le manque de packs rouges du laboratoire est publie (technologie en file, module affame)",
      string.format("publie %s technologie %s", tostring(st.pub), tostring(s.tech)))
    ctx.check(st.transit_need == 0, "M2b : A : tournee prise, quai vide : les packs en route comptent, manque publie nul", tostring(st.transit_need))
    ctx.check(st.fill_seen ~= nil and (st.fill_count or 0) > 0, "M3 : une tache de remplissage vers le quai du laboratoire est emise",
      string.format("vue %s, %s packs", tostring(st.fill_seen), tostring(st.fill_count)))
    ctx.check(st.take ~= nil and st.take < T_PRISE, "M3b : elle est prise a temps",
      string.format("prise %s vue %s limite %d", tostring(st.take), tostring(st.fill_seen), T_PRISE))
    ctx.check(st.full ~= nil and st.full_need == 0, "M4 : quai garni : le calcul suivant publie un manque nul",
      string.format("quai garni %s manque apres %s", tostring(st.full), tostring(st.full_need)))
  end,
}
