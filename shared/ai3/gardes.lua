--[[
  Lot TV-GARDES (TODO_VIDEO W04, « une garde sans mesure se prouve ou se retire ») : INVENTAIRE LU des gardes de shared/ai3 et shared/team.
  PUR : aucune API Factorio. Chaque garde y a sa MESURE (ce qu'elle lit), sa SONDE (un appel de la VRAIE garde, mesure retirée) et
  son verdict écrit :
    ferme   la mesure manque, la garde REFUSE et la raison écrite est non vide (sa raison nomme l'entrée quand la règle la nomme) ;
    voulu   la garde reste OUVERTE sur ce cas, et le registre dit POURQUOI (décision écrite, pas un oubli).
  tests/gardes_registre_test.lua joue chaque sonde, refuse une garde sans refus, refuse un fichier marqué « fermé par défaut » absent de
  ce registre, et rejoue 14 mutants (la garde du texte source est ouverte : la sonde doit voir l'ouverture). Le registre est de la DONNÉE :
  il n'appelle aucune décision ; la décision garde ses propres appels (liste « appelant » = fichier:ligne à la date du lot, 0.6.64).
  Aucun nom d'objet du jeu : des chaînes opaques (tests/iag_test.lua §8 bis).

  Sonde : sonde(M) -> ferme (booléen), raison (texte ou nil). M[alias] = module de la garde (le test y glisse un mutant).
  Entrée : { id, fichier, mesure, appelant, mods = { alias = chemin require }, sonde = fonction, verdict = "ferme" | "voulu", pourquoi = texte (voulu) }
]]

local G = {}

-- Fichiers marqués « fermé par défaut » ou « garde fermée » dans leur texte : le test lit les sources et compare à cette liste.
G.MARQUES = { "[Ff]erm[^ ]* par d[^ ]*faut", "FERM[^ ]* PAR D[^ ]*FAUT", "garde ferm[^ ]*" } -- (motifs Lua : é fait deux octets)

local function refus(ok, why) return not ok, why end

G.LIST = {
  { id = "Pf.input", fichier = "shared/ai3/plafonds.lua", mesure = "valeur numerique finie >= 0 de chaque entree d'une garde",
    appelant = "shared/ai3/plafonds.lua (Pf.fits, Pf.test, Pf.power_missing)", mods = { Pf = "shared.ai3.plafonds" }, verdict = "ferme",
    sonde = function(M) local v, why = M.Pf.input(nil, "demand"); return v == nil, why end },
  { id = "Pf.fits", fichier = "shared/ai3/plafonds.lua", mesure = "demand, posed, open, n_posed, n_open, add.rate, add.n",
    appelant = "shared/ai3/capitalisation.lua:2177 (Pf.fits_item)", mods = { Pf = "shared.ai3.plafonds" }, verdict = "ferme",
    sonde = function(M)
      local a = M.Pf.fits(nil, { rate = 1, n = 1 }, "x")
      local b, why = M.Pf.fits({ posed = 0, open = 0, n_posed = 0, n_open = 0 }, { rate = 1, n = 1 }, "x")
      return a == false and b == false, why end },
  { id = "Pf.fits_item", fichier = "shared/ai3/plafonds.lua", mesure = "objet present au registre des plafonds",
    appelant = "shared/ai3/capitalisation.lua:2177", mods = { Pf = "shared.ai3.plafonds" }, verdict = "ferme",
    sonde = function(M) return refus(M.Pf.fits_item({}, "x", { rate = 1, n = 1 })) end },
  { id = "Pf.open_room", fichier = "shared/ai3/plafonds.lua", mesure = "liste des ordres ouverts",
    appelant = "shared/ai3/capitalisation.lua:2186", mods = { Pf = "shared.ai3.plafonds" }, verdict = "ferme",
    sonde = function(M) local room, why = M.Pf.open_room(nil, 5); return room == 0, why end },
  { id = "Pf.power_missing", fichier = "shared/ai3/plafonds.lua", mesure = "power.have_kw (capacite de la centrale finie)",
    appelant = "shared/ai3/plafonds.lua (Pf.power_why)", mods = { Pf = "shared.ai3.plafonds" }, verdict = "ferme",
    sonde = function(M) local why = M.Pf.power_missing({}); return why ~= nil, why end },
  { id = "Pe.measure", fichier = "shared/ai3/portes_extension.lua", mesure = "workers, idle, free_tasks (transport)",
    appelant = "shared/ai3/portes_extension.lua (Pe.transport -> Pe.gate)", mods = { Pe = "shared.ai3.portes_extension" }, verdict = "ferme",
    sonde = function(M) local tense, _, why = M.Pe.measure({}); return tense == nil, why end },
  { id = "Pe.transport", fichier = "shared/ai3/portes_extension.lua", mesure = "workers, idle, free_tasks",
    appelant = "shared/ai3/capitalisation.lua:1007 (Pe.filter)", mods = { Pe = "shared.ai3.portes_extension" }, verdict = "ferme",
    sonde = function(M) local closed, why = M.Pe.transport(M.Pe.new(), {}); return closed == true, why end },
  { id = "Pe.site_room", fichier = "shared/ai3/portes_extension.lua", mesure = "batis (unites posees), open_sites (chantiers ouverts)",
    appelant = "shared/ai3/portes_extension.lua (Pe.gate)", mods = { Pe = "shared.ai3.portes_extension" }, verdict = "ferme",
    sonde = function(M) local room, _, why = M.Pe.site_room(nil, 0); return room == 0, why end },
  { id = "Pl.stable", fichier = "shared/ai3/palier.lua", mesure = "manques, bras_libres (nombres), crise (booleen)",
    appelant = "shared/ai3/palier.lua (Pl.step) <- shared/ai3/capitalisation.lua:1061", mods = { Pl = "shared.ai3.palier" }, verdict = "ferme",
    sonde = function(M) local ok, why = M.Pl.stable({}); return ok == false, why end },
  { id = "Lm.allows", fichier = "shared/team/lot_minerai.lua", mesure = "role du lot (minerai ou general) et sorte du module",
    appelant = "script/team/lots_minerai_glue.lua:85", mods = { Lm = "shared.team.lot_minerai" }, verdict = "ferme",
    sonde = function(M) local ok, why = M.Lm.allows(nil, "x"); return ok == false, why end },
  { id = "Cf.counts", fichier = "shared/ai3/confirmation.lua", mesure = "unite du carnet de confirmation",
    appelant = "script/ai3/capitalisation.lua:422", mods = { Cf = "shared.ai3.confirmation" }, verdict = "ferme",
    sonde = function(M) local ok, why = M.Cf.counts(nil, "x"); return ok == false, why end },
  { id = "Cf.step", fichier = "shared/ai3/confirmation.lua", mesure = "carnet et tick",
    appelant = "script/ai3/capitalisation.lua:542", mods = { Cf = "shared.ai3.confirmation" }, verdict = "ferme",
    sonde = function(M) local r, why = M.Cf.step(nil, {}, 10); return r == nil, why end },
  { id = "S.admit", fichier = "shared/team/sante_centrale.lua", mesure = "capacity, used (centrale finie)",
    appelant = "script/team/sante_centrale.lua:254", mods = { S = "shared.team.sante_centrale" }, verdict = "ferme",
    sonde = function(M) local ok, why = M.S.admit({}, { plant_done = true }, 100, 0); return ok == false, why end },
  { id = "Fx.drop_service", fichier = "shared/team/flux.lua", mesure = "stuck (sorties pleines) de la rangee de l'avant-poste",
    appelant = "shared/ai3/cerveau.lua:460 (regle F3 ALLUMEE seulement : Fx.ENABLE.keep_drop)", mods = { Fx = "shared.team.flux" }, verdict = "ferme",
    sonde = function(M)
      local was = M.Fx.ENABLE.keep_drop
      M.Fx.ENABLE.keep_drop = true
      local drop, why = M.Fx.drop_service({}, true)
      M.Fx.ENABLE.keep_drop = was
      return drop == false, why end },
  { id = "Fx.drop_service (eteinte)", fichier = "shared/team/flux.lua", mesure = "Fx.ENABLE.keep_drop",
    appelant = "shared/ai3/cerveau.lua:460", mods = { Fx = "shared.team.flux" }, verdict = "voulu",
    pourquoi = "regle F3 ETEINTE par defaut (Fx.ENABLE.keep_drop = false, aucun gain prouve, tests/flux_test.lua:204) : la tournee retiree suit la regle d'avant ; le refus ecrit n'agit qu'allumee",
    sonde = function(M) return M.Fx.drop_service({}, true) == false, nil end },
  { id = "D.gate", fichier = "shared/ai3/danger.lua", mesure = "max_d, goal_d, deaths ou blocked (releve du danger)",
    appelant = "script/ai3/comportement.lua:843 ; shared/team/vague.lua:92", mods = { D = "shared.ai3.danger" }, verdict = "ferme",
    sonde = function(M) local v, why = M.D.gate({}, { prudence = 500 }); return v == "wait", why end },
  { id = "Ic.gate", fichier = "shared/team/ilots_croissance.lua", mesure = "threatened, main_busy, islands, max, unwalled, unguarded, outside_busy",
    appelant = "script/team/build.lua:4651", mods = { Ic = "shared.team.ilots_croissance" }, verdict = "ferme",
    sonde = function(M)
      local a = M.Ic.gate({})
      local ok, why = M.Ic.gate({ threatened = false, main_busy = false, islands = 0, max = 4, unwalled = 0, unguarded = 0 })
      local c = M.Ic.gate({ main_busy = false, islands = 0, max = 4, unwalled = 0, unguarded = 0, outside_busy = 0 })
      return a == false and ok == false and c == false, why end },
  { id = "Fa.share", fichier = "shared/ai3/famille_armee.lua", mesure = "parts { delta, alpha } de la capitalisation (part reservee a la famille armee)",
    appelant = "shared/ai3/cerveau.lua:358", mods = { Fa = "shared.ai3.famille_armee" }, verdict = "ferme",
    sonde = function(M) local s, why = M.Fa.share(nil)
      return s == nil and M.Fa.share({ delta = 1 }) == nil and M.Fa.share({ delta = 100, alpha = 50 }) ~= nil, why end },
  { id = "Sl.allows", fichier = "shared/team/sonde_lot.lua", mesure = "minerai du bord du lot (sonde 30 x 30) et sorte du module",
    appelant = "script/team/place_glue.lua (Pg.states_for)", mods = { Sl = "shared.team.sonde_lot" }, verdict = "ferme",
    sonde = function(M)
      -- intégrateur (8/11, fusion de TV-PLACE et TV-GARDES) : une sorte de module inconnue est refusée, avec sa raison
      local ok, why = M.Sl.allows(nil, "sorte-inconnue-du-banc")
      return ok == false, why end },
  { id = "Vt.low", fichier = "shared/team/vapeur_tampon.lua", mesure = "taux de vapeur des machines de la centrale (vapeur / capacité)",
    appelant = "script/team/vapeur_glue.lua:56", mods = { Vt = "shared.team.vapeur_tampon" }, verdict = "ferme",
    sonde = function(M)
      -- intégrateur (8/11, fusion de TV-VAPEUR et TV-GARDES) : sans lecture, le tampon n'est jamais « bas » (aucun remplissage d'urgence)
      local a, why = M.Vt.low(false, nil)
      return a == false and M.Vt.low(true, nil) == false and M.Vt.low(false, 0.1) == true, why end },
  { id = "H.update", fichier = "shared/ai3/hysteresis.lua", mesure = "valeur de la mesure (nombre)",
    appelant = "shared/team/menace_equipe.lua (Me.update) et les crises de la capitalisation", mods = { H = "shared.ai3.hysteresis" }, verdict = "ferme",
    sonde = function(M)
      local st = M.H.new()
      local _, ev = M.H.update(st, nil, 10, 20, false)
      return ev == "absent" and st.crise == false, ev end },
  { id = "Am.direct", fichier = "shared/ai3/amorce.lua", mesure = "quantite portee (nombre positif fini)",
    appelant = "script/ai3/amorce_rt.lua:198", mods = { Am = "shared.ai3.amorce" }, verdict = "ferme",
    sonde = function(M)
      local out = M.Am.direct({ { id = "p", state = "reserve", missing = { { "x", 5 } } } }, "x", nil)
      return #out == 0, "remise directe sans quantite : rien" end },
  { id = "Mq.module", fichier = "shared/ai3/manque_local.lua", mesure = "technologie en cours, vitesse, duree d'unite, ingredients",
    appelant = "shared/ai3/manque_local.lua:201", mods = { Mq = "shared.ai3.manque_local" }, verdict = "ferme",
    sonde = function(M) local m, why = M.Mq.module({ consumes = M.Mq.RESEARCH }); return m == nil, why end },
  { id = "Ca.absent_input", fichier = "shared/ai3/capitalisation.lua", mesure = "listes d'entree machines, drills, stock, open",
    appelant = "script/ai3/capitalisation.lua (decide_start : la decision est refusee)", mods = { Ca = "shared.ai3.capitalisation" }, verdict = "ferme",
    sonde = function(M)
      local name = M.Ca.absent_input({ drills = {}, stock = {}, open = {} })
      return name == "machines", name and ("liste d'entree absente : " .. name) or nil end },
  { id = "Me.update", fichier = "shared/team/menace_equipe.lua", mesure = "armed (tourelle armee ou chargeurs recenses au QG)",
    appelant = "script/team/menace_equipe.lua:32", mods = { Me = "shared.team.menace_equipe" }, verdict = "ferme",
    sonde = function(M)
      local st = M.Me.new()
      M.Me.update(st, { tick = 1000, loss_t = 1000, armed = false })
      local on, _, why = M.Me.update(st, { tick = 1000 + M.Me.THREAT_TICKS + 10, loss_t = 1000, armed = nil })
      return on == true, why end },
  { id = "Df.evaluer", fichier = "shared/ai3/defauts.lua", mesure = "mesure de chaque defaut de la table (view.outposts, st.short)",
    appelant = "script/ai3/defauts_rt.lua (Ia3.plan_b, script/ai3/cerveau.lua)", mods = { Df = "shared.ai3.defauts" }, verdict = "ferme",
    sonde = function(M)
      local rows = M.Df.evaluer({}, {})
      local r = rows[1]
      return r ~= nil and r.etat == "non_mesure", r and r.why end },
  { id = "Sa.holds", fichier = "shared/ai3/saturation.lua", mesure = "pente (fonte) du stock",
    appelant = "shared/ai3/buts.lua:181", mods = { Sa = "shared.ai3.saturation" }, verdict = "voulu",
    pourquoi = "sans pente mesuree la saturation garde la regle d'avant (stock >= seuil) : elle RETIENT l'extraction, elle n'ouvre jamais la croissance",
    sonde = function(M) return M.Sa.holds(100, 50, nil) ~= true, nil end },
  { id = "B.saturated", fichier = "shared/ai3/buts.lua", mesure = "stock libre de la matiere",
    appelant = "shared/ai3/buts.lua (travail d'extraction)", mods = { B = "shared.ai3.buts" }, verdict = "voulu",
    pourquoi = "decision du lot 5b (n3) : un objet absent du stock vaut 0 (le moteur n'enumere pas les zeros) ; fermer la saturation arreterait l'extraction",
    sonde = function(M) return M.B.saturated({ stock = {}, workers = 8 }, "x") ~= false, nil end },
  { id = "Pi.allows", fichier = "shared/ai3/pile.lua", mesure = "retenue de la pile de priorite",
    appelant = "shared/ai3/cerveau.lua:264-324", mods = { Pi = "shared.ai3.pile" }, verdict = "voulu",
    pourquoi = "pas de pile ou pas de retenue = rien n'est retenu : c'est l'etat normal d'une equipe sans projet, pas une mesure manquante",
    sonde = function(M) return M.Pi.allows(nil, "x", nil) ~= true, nil end },
  { id = "Q.filter", fichier = "shared/team/quotas.lua", mesure = "verdicts des quotas",
    appelant = "aucun a l'execution (tests/quotas_test.lua seulement)", mods = { Q = "shared.team.quotas" }, verdict = "voulu",
    pourquoi = "ORPHELINE : aucun appelant d'execution ; sans verdict rien n'est retire, et rien ne l'appelle (chemin reel : Build.Quotas.feed_ok)",
    sonde = function(M) return #M.Q.filter({ { key = "k" } }, nil) == 0, nil end },
  { id = "Ad.surstock (cerveau)", fichier = "shared/ai3/cerveau.lua", mesure = "ctx.dispersion (colonnes de fonderie automatisees, assembleurs actifs), sorte de l'avant-poste, manque",
    appelant = "shared/ai3/cerveau.lua:343-361 (lot IA-GARDE, buts couverture:/releve: sans manque)", mods = { Ad = "shared.ai3.anti_dispersion" }, verdict = "ferme",
    sonde = function(M) return refus(M.Ad.permet(M.Ad.etat(nil, nil), "surstock", { sorte = "brut" })) end },
  { id = "Rb.extent", fichier = "shared/team/rangee_bus.lua", mesure = "reponse de chaque tuile (libre, defricher, bloque:<cause>)",
    appelant = "aucun a l'execution (tests/rangee_bus_test.lua ; script/ai3/petrole.lua et shared/ai3/rangee_fluides.lua lisent Rb.croissance et Rb.capacite)",
    mods = { Rb = "shared.team.rangee_bus" }, verdict = "ferme",
    sonde = function(M)
      local r = M.Rb.extent({ x = 0, y = 0, axe = "x", sens = 1, pas = 2, largeur = 2, n_max = 3, tuile = function() return nil end })
      return r.n == 0 and r.stop == "obstacle:inconnu", r.stop end },
}

--- Joue la sonde d'une garde. over : { alias = module } (mutant). Rend ferme, raison, erreur (texte si la sonde plante).
function G.run(entry, over)
  local M = {}
  for alias, path in pairs(entry.mods) do M[alias] = (over and over[alias]) or require(path) end
  local ok, a, b = pcall(entry.sonde, M)
  if not ok then return nil, nil, tostring(a) end
  return a, b, nil
end

--- Verdict d'une garde : "ok" (elle fait ce que le registre dit, refus ecrit compris), sinon la cause (texte).
function G.verdict(entry, over)
  local ferme, why, err = G.run(entry, over)
  if err then return "sonde en erreur : " .. err end
  if entry.verdict == "ferme" then
    if not ferme then return "la garde S'OUVRE sans sa mesure" end
    if type(why) ~= "string" or why == "" then return "la garde ferme SANS refus ecrit" end
    return "ok"
  end
  if type(entry.pourquoi) ~= "string" or #entry.pourquoi < 20 then return "garde ouverte sans raison ecrite" end
  if ferme then return "le registre dit voulu mais la garde ferme (registre perime)" end
  return "ok"
end

--- Ligne de journal d'un inventaire : [FO-GARDES] n gardes, f fermees avec refus ecrit, v ouvertes voulues, ko en defaut.
function G.line()
  local f, v, ko = 0, 0, 0
  for _, e in ipairs(G.LIST) do
    local r = G.verdict(e)
    if r ~= "ok" then ko = ko + 1 elseif e.verdict == "ferme" then f = f + 1 else v = v + 1 end
  end
  return string.format("[FO-GARDES] %d gardes : %d fermees avec refus ecrit, %d ouvertes voulues (raison ecrite), %d en defaut", #G.LIST, f, v, ko)
end

return G
