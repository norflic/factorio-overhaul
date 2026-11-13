--[[
  Lot ENERGIE (centrale résiliente ; retour du DC du 2/11 sur la 0.6.34, points 5 et 11 : « ils viennent d'avoir un problème d'électricité
  […] ils ont pas compris qu'il fallait remettre […] des bras robotisés pour remplir les chaudières », « un petit jet préalable de charbon
  […] de 50 », « la base se développe comme s'il y avait l'électricité »). PUR : aucune API Factorio, aucun nom d'objet (les pièces sont des
  GENRES : chaudière, machine, pompe, bras, tapis ; le combustible n'est qu'un nombre), testé hors jeu par tests/sante_centrale_test.lua.

  Ce que les journaux du DC montrent (fo-logs/2026-11-02_ENERGIE/RAPPORT.md, chaînes déclencheur -> décision -> action -> effet) :
  1. DÉMARRAGE À FROID IMPOSSIBLE : une centrale dont tout le charbon vient de foreuses ÉLECTRIQUES (plan_feed, voie « tapis », aucun
     coffre) ne démarre jamais : les foreuses attendent le courant que la centrale ne produit pas faute de charbon (Emerald : « centrale
     finie » à 20 min, 0 kW pendant 125 min, `sources 1/1 a sec 1`). Une panne totale pose la même impasse. Le seul démarrage sûr est
     une AMORCE À LA MAIN : du charbon porté du stock directement dans la chaudière (S.PRIME), qui allume le courant des foreuses ; le
     tapis et les bras à combustion prennent ensuite le relais SANS courant (un bras électrique sur la chaudière est un blackout en
     attente : décision du 28/10, lot PLANDIR, gardée).
  2. CHAUDIÈRE À SEC SANS REMPLISSAGE : bras ou tapis détruits, chaudières sans combustible ; la reconstruction attend du fer pendant
     des dizaines de minutes (Ambre : 13 pièces sur 28 à refaire de 150 à 173 min). Pendant ce temps la centrale est à 0 : l'amorce
     est répétée (S.COOL) tant que la chaudière est à sec, depuis le stock, en tête de pile (S.PRIO, au-dessus de l'urgence du coffre).
  3. SATURATION SANS CROISSANCE : un chantier de reconstruction compte comme « chantier de centrale ouvert » et retient la centrale de
     plus pendant que la production plafonne à 100 % (Ambre, 23 min). Un chantier sans progrès depuis S.STALL ne retient plus rien, et
     la centrale de plus part AVANT la saturation (S.ANTICIPATE de la capacité, mise en chantier comprise).
  4. CONSOMMATEURS SANS COURANT : la base ouvre des modules électriques au-delà de ce que la centrale produit. Un module dont la
     puissance nominale dépasse la marge (S.admit) reste en attente ; jamais plus de S.GATE_WAIT d'attente pour rien.
]]
local S = {}

S.PRIME = 50          -- charbon porté à la main dans une chaudière à sec (le DC : « un petit jet préalable de 50 »)
S.PRIME_MIN = 10      -- en dessous, le stock ne paie pas une amorce utile
S.DRY_CHECKS = 3      -- relevés (5 s) de suite « à sec » avant l'amorce : 15 s (le tapis qui se remplit n'en déclenche pas)
S.COOL = 5400         -- ticks entre deux amorces d'une même centrale (90 s : 50 charbons durent 111 s à pleine charge)
S.PRIO = 92           -- priorité de la tâche d'amorce : au-dessus de l'urgence du coffre (91) et de « défendre d'abord » (90)
S.STALL = 18000       -- ticks (5 min) sans pièce reposée au bout desquels une reconstruction ne retient plus la centrale de plus
S.ANTICIPATE = 0.7    -- part de la capacité (production + consommateurs en chantier) à partir de laquelle la centrale de plus est demandée
S.ANTICIPATE_CHECKS = 6 -- relevés (5 s) de suite au-dessus de S.ANTICIPATE : 30 s, comme la saturation (un pic de mise en route n'est pas un besoin)
S.DRAW = 0.6          -- part de sa puissance nominale qu'un module en chantier tire en vrai (entrées limitées, machines à l'arrêt : mesuré à la moitié environ)
S.GATE_FRAC = 1.0     -- part de la capacité que production + consommateurs en chantier + nouveau module ne dépassent pas
S.GATE_WAIT = 43200   -- ticks (12 min) d'attente au plus d'un module retenu pour le courant : au-delà il passe (jamais de blocage définitif)
S.LOGS = 60           -- lignes [FO-SANTE-CENTRALE] au plus par équipe

-- causes, de la plus grave à la moins grave (l'ordre est celui du journal et de la décision)
S.CAUSES = { "chaudiere_a_sec", "chaudiere_detruite", "bras_manquants", "tapis_manquant", "machines_manquantes", "pompe_manquante", "coffre_vide" }

--- Lecture de la santé d'une centrale. c : { boilers = { want, alive, dry }, arms = { want, alive }, belts = { want, alive },
--- engines = { want, alive }, pumps = { want, alive }, chest = { n, low } (nil sans coffre), production, capacity }.
--- Rend { causes = { cause, ... } (ordre S.CAUSES), ok = vrai si aucune cause, repair = vrai si une PIÈCE manque (reconstruction à presser),
--- dry = chaudières à sec }.
function S.classify(c)
  local function gap(x) return x and math.max(0, (x.want or 0) - (x.alive or 0)) or 0 end
  local has = {}
  local dry = c.boilers and c.boilers.dry or 0
  if dry > 0 then has.chaudiere_a_sec = true end
  if gap(c.boilers) > 0 then has.chaudiere_detruite = true end
  if gap(c.arms) > 0 then has.bras_manquants = true end
  if gap(c.belts) > 0 then has.tapis_manquant = true end
  if gap(c.engines) > 0 then has.machines_manquantes = true end
  if gap(c.pumps) > 0 then has.pompe_manquante = true end
  if c.chest and (c.chest.n or 0) < (c.chest.low or 0) then has.coffre_vide = true end
  local causes = {}
  for _, k in ipairs(S.CAUSES) do if has[k] then causes[#causes + 1] = k end end
  return { causes = causes, ok = #causes == 0, dry = dry,
    repair = has.chaudiere_detruite or has.bras_manquants or has.tapis_manquant or has.machines_manquantes or has.pompe_manquante or false }
end

--- Chaudières à sec depuis assez longtemps pour une amorce. st : mémoire { dry_n } (nombres) ; dry : chaudières à sec à ce relevé.
--- Rend vrai quand le compte de relevés de suite atteint S.DRY_CHECKS ; une chaudière nourrie le remet à zéro.
function S.confirm(st, dry)
  if (dry or 0) > 0 then st.dry_n = (st.dry_n or 0) + 1 else st.dry_n = 0 end
  return st.dry_n >= S.DRY_CHECKS
end

--- Amorce à la main. st : mémoire { primed (tick de la dernière amorce) } ; dry : chaudières à sec ; stock : combustible au coffre du QG ;
--- tick. Rend { count (par chaudière), total, boilers } ou (nil, raison).
function S.prime(st, dry, stock, tick)
  if (dry or 0) <= 0 then return nil, "aucune chaudiere a sec" end
  if st.primed and tick - st.primed < S.COOL then return nil, "amorce recente" end
  stock = stock or 0
  if stock < S.PRIME_MIN then return nil, "stock de combustible insuffisant" end
  local per = math.min(S.PRIME, math.floor(stock / dry))
  if per < S.PRIME_MIN then
    -- le stock ne paie pas toutes les chaudières : les premières seulement
    local n = math.floor(stock / S.PRIME_MIN)
    if n < 1 then return nil, "stock de combustible insuffisant" end
    return { count = S.PRIME_MIN, boilers = math.min(dry, n), total = S.PRIME_MIN * math.min(dry, n) }
  end
  return { count = per, boilers = dry, total = per * dry }
end

--- Une reconstruction avance-t-elle ? st : mémoire { [clé] = { built, since } } ; built : pièces posées. Rend vrai quand AUCUNE pièce n'a
--- été reposée depuis S.STALL ticks (le chantier ne retient plus la centrale de plus).
function S.stalled(st, key, built, tick)
  local m = st[key]
  if not m or built ~= m.built then
    st[key] = { built = built, since = tick }
    return false
  end
  return tick - m.since >= S.STALL
end

--- Faut-il une centrale de plus AVANT la saturation ? used : production (kW) ; committed : consommateurs en chantier ou retenus (kW
--- nominaux, comptés à S.DRAW) ; capacity (kW).
function S.anticipate(used, committed, capacity)
  if not capacity or capacity <= 0 then return false end
  return (used or 0) + S.DRAW * (committed or 0) >= S.ANTICIPATE * capacity
end

--- Lot s41 energie (DC, 13/11 : « la centrale sature dès que les fours tournent ») : DEMANDE à couvrir par la centrale (kW) = la plus grande
--- de la production mesurée et de la puissance INSTALLÉE (kW nominaux des consommateurs finis) comptée à S.DRAW. Avant : la mesure seule ;
--- des machines posées mais à l'arrêt comptaient 0 kW, la centrale de plus n'était demandée qu'une fois la saturation constatée. Avec
--- S.ANTICIPATE (0,7) et C.GROW_LOAD (0,75), la centrale grandit tant que la capacité ne dépasse pas cette demande d'un tiers.
function S.demand(used, installed)
  local u = type(used) == "number" and used == used and used > 0 and used or 0
  local i = type(installed) == "number" and installed == installed and installed > 0 and installed < math.huge and installed or 0
  return math.max(u, S.DRAW * i)
end

-- Étape 5a de VIDEO-INTEG : kW nominaux que la CAPITALISATION a retenus faute de courant (dernière décision, une par minute) ; valables
-- deux décisions, puis oubliés (capitalisation coupée, équipe disparue : jamais une avance pour toujours).
S.CAPI_TTL = 2 * 3600

--- kW retenus par la capitalisation, comptés avec les consommateurs retenus de l'avance (S.anticipate, à S.DRAW) : sans eux, la décision
--- attend du courant et la centrale attend une saturation qui ne vient pas (boucle B). rec = { kw, tick } (f.team.capi.kw_blocked) ;
--- 0 si absent, invalide, daté du futur ou plus vieux que S.CAPI_TTL.
function S.capi_kw(rec, tick)
  if type(rec) ~= "table" or type(tick) ~= "number" then return 0 end
  local kw, t = rec.kw, rec.tick
  if type(kw) ~= "number" or type(t) ~= "number" or kw ~= kw or kw <= 0 or kw == math.huge then return 0 end
  if t > tick or tick - t > S.CAPI_TTL then return 0 end
  return kw
end

-- Lot TV-ENERGIE (diagnostic azure, 8/11 : foreuses de cuivre refusées de 26 à 48 min, 15 026 MU d'épargne dormants, centrale de plus à 32 min
-- puis 13 min de chantier) : un DÉFICIT DE kW est une crise de production. Les kW retenus faute de courant, avec de l'épargne qui dort
-- (S.DEFICIT_BANK : MU d'épargne au moins, au-dessus du prix d'une centrale d'une chaudière), demandent la centrale de plus tout de suite
-- (C.growth, n.deficit_kw), sans attendre S.sustain.
S.DEFICIT_BANK = 300

--- kW du déficit : les kW retenus (S.capi_kw) si la décision avait de l'épargne (rec.bank en MU, posé par la capitalisation) au moins S.DEFICIT_BANK,
--- sinon 0 (pas d'argent pour la centrale : rien à demander de plus vite que l'avance).
function S.deficit(rec, tick)
  local kw = S.capi_kw(rec, tick)
  if kw <= 0 then return 0 end
  local bank = type(rec) == "table" and rec.bank or nil
  if type(bank) ~= "number" or bank ~= bank or bank < S.DEFICIT_BANK then return 0 end
  return kw
end

--- Durée de l'avance. st : mémoire { ant_n } ; flag : S.anticipate à ce relevé. Rend vrai quand elle dure depuis S.ANTICIPATE_CHECKS relevés.
function S.sustain(st, flag)
  if flag then st.ant_n = (st.ant_n or 0) + 1 else st.ant_n = 0 end
  return st.ant_n >= S.ANTICIPATE_CHECKS
end

--- Un nouveau module électrique de `new` kW nominaux peut-il s'ouvrir ? c : { capacity, used, committed (kW) } ; st : mémoire { since } du module ;
--- tick. Rend (vrai, nil) ou (faux, raison) ; le module retenu passe après S.GATE_WAIT. Sans centrale finie (capacité nulle) : vrai (la
--- centrale précède, elle ne se juge pas elle-même).
--- FERMÉ PAR DÉFAUT (lot 5b, W04 n°2) : `c.plant_done` (centrale FINIE) avec une capacité non lue, ou une capacité lue sans production
--- (c.used absent, avant : compté 0 = tout admis) : le module est RETENU, raison écrite qui nomme l'entrée, et passe quand même après
--- S.GATE_WAIT (la mesure revient en quelques secondes, PA.watch). SANS centrale finie (capacité nulle, plant_done faux) : vrai comme avant,
--- car la centrale PRÉCÈDE les consommateurs et ne se juge pas elle-même (le premier module électrique la fait demander).
function S.admit(st, c, new, tick)
  local function hold(why)
    st.since = st.since or tick
    if tick - st.since >= S.GATE_WAIT then return true, "delai" end
    return false, why
  end
  if (new or 0) <= 0 then st.since = nil return true, nil end
  if not (type(c.capacity) == "number" and c.capacity > 0) then
    if c.plant_done then return hold("courant : centrale finie, entree absente : capacity") end
    st.since = nil
    return true, nil
  end
  if type(c.used) ~= "number" then return hold("courant : entree absente : used (production)") end
  local want = c.used + S.DRAW * ((c.committed or 0) + new)
  if want <= S.GATE_FRAC * c.capacity then st.since = nil return true, nil end
  st.since = st.since or tick
  if tick - st.since >= S.GATE_WAIT then return true, "delai" end
  return false, string.format("courant : %.0f kW produits + %.0f%% de (%.0f en chantier + %.0f ce module) = %.0f kW au-dela de %.0f kW", c.used or 0,
    S.DRAW * 100, c.committed or 0, new, want, c.capacity)
end

--- Ligne du journal [FO-SANTE-CENTRALE] (une seule mise en forme, pour la lire au banc). ev = { team, kind, tick, ... }.
function S.line(ev)
  local min = (ev.tick or 0) / 3600
  local t = tostring(ev.team)
  if ev.kind == "etat" then
    return string.format("[FO-SANTE-CENTRALE] %s : centrale %s a %.1f min : %s (chaudieres %d/%d dont %d a sec, bras %d/%d, tapis %d/%d, machines %d/%d, pompes %d/%d ; production %.0f kW sur %.0f kW)",
      t, tostring(ev.plant), min, #ev.causes > 0 and table.concat(ev.causes, " + ") or "saine",
      ev.boilers_alive or 0, ev.boilers_want or 0, ev.dry or 0, ev.arms_alive or 0, ev.arms_want or 0, ev.belts_alive or 0, ev.belts_want or 0,
      ev.engines_alive or 0, ev.engines_want or 0, ev.pumps_alive or 0, ev.pumps_want or 0, ev.production or 0, ev.capacity or 0)
  elseif ev.kind == "amorce" then
    return string.format("[FO-SANTE-CENTRALE] %s : centrale %s a %.1f min : amorce a la main, %d chaudiere(s) a sec, %d charbon(s) chacune (%d au total, stock %d) : tache de priorite %d",
      t, tostring(ev.plant), min, ev.boilers or 0, ev.count or 0, ev.total or 0, ev.stock or 0, S.PRIO)
  elseif ev.kind == "amorce-faite" then
    return string.format("[FO-SANTE-CENTRALE] %s : centrale %s a %.1f min : amorce posee, %d charbon(s) dans %d chaudiere(s)",
      t, tostring(ev.plant), min, ev.put or 0, ev.boilers or 0)
  elseif ev.kind == "sans-amorce" then
    return string.format("[FO-SANTE-CENTRALE] %s : centrale %s a %.1f min : %d chaudiere(s) a sec, pas d'amorce (%s)",
      t, tostring(ev.plant), min, ev.dry or 0, tostring(ev.why))
  elseif ev.kind == "retenu" then
    return string.format("[FO-SANTE-CENTRALE] %s : projet %s retenu a %.1f min : %s", t, tostring(ev.project), min, tostring(ev.why))
  elseif ev.kind == "admis" then
    return string.format("[FO-SANTE-CENTRALE] %s : projet %s admis a %.1f min (%s)", t, tostring(ev.project), min, tostring(ev.why))
  elseif ev.kind == "avance" then
    return string.format("[FO-SANTE-CENTRALE] %s : centrale de plus demandee a %.1f min AVANT la saturation (production %.0f kW + chantiers %.0f kW sur %.0f kW)",
      t, min, ev.used or 0, ev.committed or 0, ev.capacity or 0)
  elseif ev.kind == "avance-rompue" then
    return string.format("[FO-SANTE-CENTRALE] %s : avance de la centrale de plus INTERROMPUE a %.1f min apres %d releve(s) sur %d (production %.0f kW + chantiers %.0f kW sous le seuil de %.0f kW) : le compteur repart a zero",
      t, min, ev.n or 0, S.ANTICIPATE_CHECKS, ev.used or 0, ev.committed or 0, S.ANTICIPATE * (ev.capacity or 0))
  elseif ev.kind == "bloquee" then
    return string.format("[FO-SANTE-CENTRALE] %s : reconstruction de la centrale %s sans progres depuis %.0f s (%d piece(s) posee(s)) : elle ne retient plus la centrale de plus a %.1f min",
      t, tostring(ev.plant), (ev.waited or 0) / 60, ev.built or 0, min)
  end
  return "[FO-SANTE-CENTRALE] " .. t .. " : " .. tostring(ev.kind)
end

return S
