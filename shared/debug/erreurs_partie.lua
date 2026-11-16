--[[
  N104-ERREURS (demande du DC, 16/11) : JOURNAL D'ERREURS DE PARTIE, règle PURE (aucune API du jeu, aucun nom d'objet : les objets
  et les projets sont des clés opaques). Un instrument : aucune décision d'IA ne lit ce module ni son état.

  « des logs d'erreurs de partie qui seraient soit des erreurs de placement, soit des écarts entre production investie et revenus ou
  consommée et produite / besoins spécifiques + pas d'augmentation, soit des défenses pas mises et attaques répétées et non défendues à
  un endroit précis (...) cela permettrait de mieux benchmarker les IA. »

  Entrée : chaque minute et par équipe, un relevé de FAITS (script/debug/erreurs_partie.lua dans le jeu ; tools/autotest/erreurs.py
  reconstitue les mêmes faits depuis les journaux d'avant ce lot et les rejoue ici, tools/autotest/erreurs_rejeu.lua) :
    facts = {
      capi     = { Y, spent, budget, bank, s, delta, alpha },            -- décision de la capitalisation (revenu, engagé, épargne)
      elec     = { demand, cap, fed, boilers },                           -- demande nominale, capacité bâtie (kW), chaudières nourries
      sous     = { { item, bilan, pente } },                              -- sous-production DURABLE (shared/ai3/bilan.lua, niveau « sous »)
      besoins  = { { item, manque, grow } },                              -- besoin évalué non couvert ; grow = capacité de l'objet
      bloques  = { { pid, age, built, total, x, y, cause, kind } },       -- projets sans progrès (age en min)
      zero     = { { label, age } },                                      -- capacité posée qui produit 0/min (age en min)
      champ    = { stuck, nopow, nofuel, at_stuck, at_nopow, at_nofuel }, -- relevé des bandes du champ (foreuses, fours)
      vides    = { { pid, x, y, cadre } },                                -- bandes au cadre posé SANS foreuse
      culs     = { { classe, x, y, n } },                                 -- tapis chargés sans sortie (classe de E.cul_classe ou « coupe »)
      chevauchements = { { pid, x, y, dropped, total } },                 -- projet refusé : toutes ses pièces sur des tuiles déjà au plan
      pertes   = { { ck, x, y, n, age } },                                -- pertes non refaites, par case de chunk (age de la plus vieille)
      attaques = { { ck, x, y, vagues, perdus, pv, t0, t1, par } },       -- vagues de morts par case de chunk, tourelles avant / maintenant
      defense  = { { post, have, want } },                                -- postes de défense (tourelles voulues / posées)
    }
  Seuils : TOUS dérivés de constantes existantes (E.seuils) : délai de pose Ca.T_LAG (« durable »), blocage Bl.STALL_TICKS, horizon du
  stock Ca.H_STOCK (épargne qui dort), vague Sa.T, mémoire des pertes Rc.RESET, plafond des lignes Capi.COURANT_LOGS. Aucun réglage neuf.

  Sortie (E.step) : épisodes par (catégorie, clé). Un épisode s'OUVRE quand sa condition tient depuis « durable » minutes (ligne
  « etat=ouvre »), se FERME quand elle ne tient plus (ligne « etat=fin », durée et pire valeur). Lignes ouvertes plafonnées par équipe et
  par catégorie ; le bilan de la minute (E.bilan) garde les comptes exacts au-delà du plafond.
    [FO-ERREUR-PARTIE] <equipe> <FAMILLE:sorte> min=<m> <x,y|-> etat=<ouvre|fin> ... détail chiffré
    [FO-ERREUR-BILAN] <equipe> min=<m> actifs=<n> score=<minutes d'erreur> | <FAMILLE:sorte>=<épisodes>/<minutes>/<pire> ...
  Déterminisme : clés triées, aucun hasard, aucun temps mesuré. État : nombres et chaînes seulement.
]]

local Ca = require("shared.ai3.capitalisation")
local Bl = require("shared.team.blocage")
local Sa = require("shared.team.secteur_attaque")
local Rc = require("shared.team.reconstruction")

local E = {}

E.TAG = "[FO-ERREUR-PARTIE]"
E.TAG_BILAN = "[FO-ERREUR-BILAN]"
E.PERIOD = 3600 -- un relevé par minute et par équipe (ticks)
E.FAMILLES = { "PLACEMENT", "INVESTISSEMENT", "FLUX", "DEFENSE" }
-- Catégories stables (ordre du journal et des tableaux).
E.CATS = {
  "PLACEMENT:chevauchement", "PLACEMENT:cul_de_sac", "PLACEMENT:tapis_coupe", "PLACEMENT:foreuse_sans_sortie",
  "PLACEMENT:four_sans_combustible", "PLACEMENT:sans_courant", "PLACEMENT:bande_sans_foreuses",
  "INVESTISSEMENT:epargne_dort", "INVESTISSEMENT:capital_sans_revenu", "INVESTISSEMENT:projet_bloque",
  "FLUX:deficit_matiere", "FLUX:besoin_non_couvert", "FLUX:deficit_electrique", "FLUX:chaudieres_a_sec",
  "DEFENSE:attaque_repetee", "DEFENSE:perte_non_reconstruite", "DEFENSE:defense_manquante",
}
E.CAT_SET = {}
for i, c in ipairs(E.CATS) do E.CAT_SET[c] = i end

--- Classe d'un tapis chargé sans sortie : la MÊME règle que tools/autotest/fo-autotest/scenarios/cul_classe.lua (sonde [FO-CUL-DE-SAC]
--- du scénario ; égalité tenue par tests/n104_erreurs_test.lua). Rend chantier | souterrain_ampute | alimentation | retenue | impasse.
function E.cul_classe(c)
  if c.suite_a_poser then return "chantier" end
  if c.souterrain_seul then return "souterrain_ampute" end
  if (c.preneurs or 0) > 0 then return "alimentation" end
  if c.occ_suiv ~= nil and c.occ_suiv ~= c.propre then return "retenue" end
  return "impasse"
end

--- Seuils, en minutes, tous lus aux constantes du mod. `ext` : constantes du runtime (capitalisation : zero_alert, couv_every).
function E.seuils(ext)
  ext = ext or {}
  local s = {
    durable = Ca.T_LAG,               -- une condition qui dure plus que le délai de pose d'un correctif est une erreur
    stall = Bl.STALL_TICKS / 3600,    -- un projet (une bande, un poste) sans progrès depuis 10 min est bloqué
    h_epargne = Ca.H_STOCK,           -- épargne de plus de 10 min du flux réinvesti, rien d'engagé : elle dort
    vague = Sa.T / 3600,              -- deux morts à plus d'une minute d'écart : deux vagues
    memoire = Rc.RESET / 3600,        -- les vagues d'une case se comptent sur 30 min
    cap = ext.cap or 40,              -- lignes « ouvre » au plus par équipe et par catégorie (Capi.COURANT_LOGS)
  }
  s.durable_of = {
    ["FLUX:deficit_electrique"] = s.durable, ["FLUX:chaudieres_a_sec"] = s.durable, ["FLUX:besoin_non_couvert"] = s.durable,
    ["INVESTISSEMENT:epargne_dort"] = s.durable, ["PLACEMENT:foreuse_sans_sortie"] = s.durable,
    ["PLACEMENT:four_sans_combustible"] = s.durable, ["PLACEMENT:sans_courant"] = s.durable,
    ["PLACEMENT:bande_sans_foreuses"] = s.stall, ["DEFENSE:defense_manquante"] = s.stall,
  }
  return s
end

local function num(v) return tonumber(v) or 0 end
local function r0(v) return math.floor(num(v) + 0.5) end

--- Flux réinvesti par minute, le même calcul que Ca.budget : s × Y × (1000 − δ − α) ‰.
function E.per_min(c)
  return num(c.s) / 1000 * num(c.Y) * (1000 - num(c.delta) - num(c.alpha)) / 1000
end

--- Conditions vraies dans ce relevé : { { cat, key, x, y, val, txt, grow, age } } (non triées).
function E.conds(facts, cfg)
  local out = {}
  local function add(cat, key, x, y, val, txt, extra)
    local c = { cat = cat, key = tostring(key), x = x, y = y, val = num(val), txt = txt }
    if extra then for k, v in pairs(extra) do c[k] = v end end
    out[#out + 1] = c
  end
  local c = facts.capi
  local bank = c and num(c.bank) or nil
  if c and num(c.Y) > 0 then
    local pm = E.per_min(c)
    local seuil = cfg.h_epargne * pm
    if pm > 0 and num(c.spent) <= pm and num(c.bank) >= seuil then
      add("INVESTISSEMENT:epargne_dort", "qg", nil, nil, c.bank, string.format("epargne=%d revenu=%d/min flux=%d/min engage=%d seuil=%d",
        r0(c.bank), r0(c.Y), r0(pm), r0(c.spent), r0(seuil)))
    end
  end
  local el = facts.elec
  if el then
    local d, cap, fed, nb = num(el.demand), num(el.cap), num(el.fed), num(el.boilers)
    if d > cap then
      add("FLUX:deficit_electrique", "reseau", nil, nil, d - cap, string.format("demande=%dkW capacite=%dkW manque=%dkW epargne=%s",
        r0(d), r0(cap), r0(d - cap), bank and tostring(r0(bank)) or "?"))
    end
    if nb > 0 and fed < nb and cap * fed / nb < d then
      add("FLUX:chaudieres_a_sec", "chaudieres", nil, nil, nb - fed, string.format("a_sec=%d/%d capacite_utile=%dkW demande=%dkW",
        r0(nb - fed), r0(nb), r0(cap * fed / nb), r0(d)))
    end
  end
  for _, s in ipairs(facts.sous or {}) do
    add("FLUX:deficit_matiere", s[1], nil, nil, -num(s[2]), string.format("objet=%s bilan=%.1f/min pente=%.1f/min", tostring(s[1]), num(s[2]), num(s[3])))
  end
  for _, s in ipairs(facts.besoins or {}) do
    if num(s[2]) > 0 then
      add("FLUX:besoin_non_couvert", s[1], nil, nil, s[2], string.format("objet=%s manque=%d capacite=%.1f", tostring(s[1]), r0(s[2]), num(s[3])),
        { grow = num(s[3]) })
    end
  end
  for _, p in ipairs(facts.bloques or {}) do
    if num(p.age) >= cfg.stall then
      add("INVESTISSEMENT:projet_bloque", "p" .. tostring(p.pid), p.x, p.y, p.age, string.format("projet=%s sorte=%s depuis=%dmin baties=%d/%d cause=%s",
        tostring(p.pid), tostring(p.kind or "?"), r0(p.age), r0(p.built), r0(p.total), tostring(p.cause or "?")), { age = num(p.age) })
    end
  end
  for _, z in ipairs(facts.zero or {}) do
    add("INVESTISSEMENT:capital_sans_revenu", z[1], nil, nil, z[2], string.format("capacite=%s produit=0/min depuis=%dmin", tostring(z[1]), r0(z[2])),
      { age = num(z[2]) })
  end
  local ch = facts.champ
  if ch then
    local function at(p) return p and p.x, p and p.y end
    if num(ch.stuck) > 0 then
      local x, y = at(ch.at_stuck)
      add("PLACEMENT:foreuse_sans_sortie", "champ", x, y, ch.stuck, string.format("foreuses_figees=%d", r0(ch.stuck)))
    end
    if num(ch.nofuel) > 0 then
      local x, y = at(ch.at_nofuel)
      add("PLACEMENT:four_sans_combustible", "champ", x, y, ch.nofuel, string.format("fours_sans_combustible=%d", r0(ch.nofuel)))
    end
    if num(ch.nopow) > 0 then
      local x, y = at(ch.at_nopow)
      add("PLACEMENT:sans_courant", "champ", x, y, ch.nopow, string.format("foreuses_sans_courant=%d", r0(ch.nopow)))
    end
  end
  for _, v in ipairs(facts.vides or {}) do
    add("PLACEMENT:bande_sans_foreuses", "p" .. tostring(v.pid), v.x, v.y, v.cadre, string.format("projet=%s cadre_pose=%d foreuses=0",
      tostring(v.pid), r0(v.cadre)))
  end
  for _, u in ipairs(facts.culs or {}) do
    local cat = (u.classe == "impasse" and "PLACEMENT:cul_de_sac")
      or ((u.classe == "souterrain_ampute" or u.classe == "coupe") and "PLACEMENT:tapis_coupe") or nil
    if cat then
      add(cat, string.format("%d,%d", math.floor(num(u.x)), math.floor(num(u.y))), u.x, u.y, u.n,
        string.format("classe=%s objets=%d", tostring(u.classe), r0(u.n)))
    end
  end
  for _, p in ipairs(facts.chevauchements or {}) do
    add("PLACEMENT:chevauchement", "p" .. tostring(p.pid), p.x, p.y, p.dropped, string.format("projet=%s pieces_sur_un_autre_plan=%d/%d",
      tostring(p.pid), r0(p.dropped), r0(p.total)))
  end
  for _, p in ipairs(facts.pertes or {}) do
    if num(p.age) >= cfg.stall then
      add("DEFENSE:perte_non_reconstruite", p.ck, p.x, p.y, p.n, string.format("pieces=%d plus_vieille=%dmin", r0(p.n), r0(p.age)))
    end
  end
  for _, a in ipairs(facts.attaques or {}) do
    if num(a.vagues) >= 2 and num(a.t1) <= num(a.t0) then
      add("DEFENSE:attaque_repetee", a.ck, a.x, a.y, a.pv, string.format("vagues=%d perdus=%d pv_perdus=%d tourelles=%d->%d par=%s",
        r0(a.vagues), r0(a.perdus), r0(a.pv), r0(a.t0), r0(a.t1), tostring(a.par or "?")))
    end
  end
  for _, d in ipairs(facts.defense or {}) do
    if num(d.have) < num(d.want) then
      add("DEFENSE:defense_manquante", d.post, nil, nil, num(d.want) - num(d.have), string.format("poste=%s tourelles=%d/%d",
        tostring(d.post), r0(d.have), r0(d.want)))
    end
  end
  return out
end

function E.new()
  return { ep = {}, stats = {}, said = {}, minute = nil }
end

local function pos_txt(x, y)
  if x == nil or y == nil then return "-" end
  return string.format("%d,%d", math.floor(num(x)), math.floor(num(y)))
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function stat(st, cat)
  local s = st.stats[cat]
  if not s then s = { n = 0, dur = 0, pire = 0 }; st.stats[cat] = s end
  return s
end

--- Une minute d'une équipe : intègre les conditions, rend les lignes à écrire (ouvertures, fins). `minute` croissante.
function E.step(st, team, minute, conds, cfg)
  local lines = {}
  local dt = st.minute and math.max(1, minute - st.minute) or 1
  st.minute = minute
  table.sort(conds, function(a, b)
    if a.cat ~= b.cat then return (E.CAT_SET[a.cat] or 99) < (E.CAT_SET[b.cat] or 99) end
    return a.key < b.key
  end)
  local seen = {}
  for _, c in ipairs(conds) do
    local id = c.cat .. "|" .. c.key
    if not seen[id] then
      seen[id] = true
      local ep = st.ep[id]
      if not ep then
        -- un fait qui porte son âge (projet bloqué, capacité à 0, perte) date l'épisode de son début, non du relevé
        ep = { cat = c.cat, key = c.key, t0 = minute - (c.age and math.floor(num(c.age)) or 0), ok = false, worst = 0, grow0 = c.grow }
        st.ep[id] = ep
      end
      if c.val > ep.worst then ep.worst = c.val end
      ep.x, ep.y, ep.txt = c.x, c.y, c.txt
      if ep.ok then
        local s = stat(st, c.cat)
        s.dur = s.dur + dt
        if ep.worst > s.pire then s.pire = ep.worst end
      else
        local need = (cfg.durable_of or {})[c.cat] or 0
        local grown = c.grow ~= nil and ep.grow0 ~= nil and c.grow > ep.grow0
        if grown then ep.t0, ep.grow0 = minute, c.grow end -- la capacité a augmenté : l'attente repart (ce n'est pas « sans augmentation »)
        if minute - ep.t0 >= need and not grown then
          ep.ok = true
          local s = stat(st, c.cat)
          s.n = s.n + 1
          s.dur = s.dur + minute - ep.t0 + 1 -- minutes de la condition, la première comprise
          if ep.worst > s.pire then s.pire = ep.worst end
          local n = (st.said[c.cat] or 0) + 1
          st.said[c.cat] = n
          if n <= (cfg.cap or 40) then
            ep.said = true
            lines[#lines + 1] = string.format("%s %s %s min=%d %s etat=ouvre depuis=%d val=%d %s", E.TAG, tostring(team), c.cat, minute,
              pos_txt(c.x, c.y), ep.t0, r0(c.val), c.txt or "")
          elseif n == (cfg.cap or 40) + 1 then
            lines[#lines + 1] = string.format("%s %s %s min=%d - etat=plafond lignes=%d (comptes au bilan)", E.TAG, tostring(team), c.cat, minute,
              cfg.cap or 40)
          end
        end
      end
    end
  end
  for _, id in ipairs(sorted_keys(st.ep)) do
    if not seen[id] then
      local ep = st.ep[id]
      if ep.ok and ep.said then
        lines[#lines + 1] = string.format("%s %s %s min=%d %s etat=fin duree=%d pire=%d %s", E.TAG, tostring(team), ep.cat, minute,
          pos_txt(ep.x, ep.y), math.max(1, minute - ep.t0), r0(ep.worst), ep.txt or "")
      end
      st.ep[id] = nil
    end
  end
  return lines
end

--- Score d'erreurs : minutes d'erreur cumulées, toutes catégories (un épisode compte au moins sa minute d'ouverture).
function E.score(st)
  local s = 0
  for _, cat in ipairs(E.CATS) do
    local x = st.stats[cat]
    if x then s = s + x.dur end
  end
  return s
end

--- Ligne de bilan de la minute (comptes exacts, au-delà du plafond des lignes).
function E.bilan(st, team, minute)
  local parts, act = {}, 0
  for _, id in ipairs(sorted_keys(st.ep)) do if st.ep[id].ok then act = act + 1 end end
  for _, cat in ipairs(E.CATS) do
    local x = st.stats[cat]
    if x and x.n > 0 then parts[#parts + 1] = string.format("%s=%d/%d/%d", cat, x.n, x.dur, r0(x.pire)) end
  end
  return string.format("%s %s min=%d actifs=%d score=%d | %s", E.TAG_BILAN, tostring(team), minute, act, E.score(st), table.concat(parts, " "))
end

return E
