--[[
  Lot TV-PILOTE, point V88 de docs/TODO_VIDEO.md (« this Factory is able to address its own issues », vidéo 11:45 : chaque panne produit un
  signal que la MÊME boucle traite). TABLE EXPLICITE défaut -> signal -> levier, en données, appelée par la boucle de décision de la
  capitalisation (script/ai3/pilotage.lua, Pil.defauts, depuis le relevé de script/ai3/capitalisation.lua). PUR (aucune API Factorio, aucun
  nom d'objet), testé hors jeu par tests/defauts_test.lua.

  Avant ce lot, les causes d'arrêt vivaient en deux endroits sans lien : la table des statuts du moteur (CONF_CAUSE, script) et les causes
  de la confirmation (shared/ai3/confirmation.lua : « perdu », « rien produit », « jamais lu »), et chaque levier réagissait de son côté sans
  que rien ne dise qu'une panne avait un remède. Ici :
    * Df.FAULTS : une ligne par DÉFAUT = son nom (la `cause` lue par la confirmation), le SIGNAL qui le fait voir (statuts du moteur ou
      événement de la confirmation), le LEVIER qui le traite, l'effet attendu et le journal qui le prouve ;
    * Df.LEVERS : les leviers, chacun avec les fonctions du code qui le portent (le test vérifie que chaque fonction EXISTE dans son fichier :
      un levier sans code est un défaut sans remède) ;
    * Df.status_cause() : la table statut du moteur -> cause, LUE par le runtime (une seule source) ;
    * Df.route(events) : range les événements d'un relevé (échecs, arrêts, pertes) par défaut ; une cause absente de la table est
      NON ROUTÉE, écrite telle quelle (refus écrit : « defaut sans levier ») au lieu d'être ignorée ;
    * Df.line(...) : la ligne du journal [FO-DEFAUT] « cause -> signal -> levier ».
  Déterminisme : listes triées, aucun pairs décisionnel, aucun hasard, aucune horloge mesurée.
]]

local Df = {}

-- Leviers : nom -> { { fichier, fragment de code } ... } (preuves d'existence, relues par le test).
Df.LEVERS = {
  energie = { { "shared/ai3/capitalisation.lua", "function Ca.blocked_kw" }, { "shared/ai3/capitalisation.lua", "local function power_options" } },
  amont = { { "shared/ai3/capitalisation.lua", "local function fabric_options" }, { "shared/ai3/capitalisation.lua", "function Ca.options" } },
  collecte = { { "script/team/build.lua", "local function out_tasks" }, { "script/team/build.lua", "local function quai_tasks" } },
  relance = { { "script/ai3/amorce_rt.lua", "function AmRt.defer" }, { "script/ai3/amorce_rt.lua", "function AmRt.after_decision" } },
  reconstruction = { { "script/team/reconstruction.lua", "function Recon.think" } },
  ouvrir = { { "shared/ai3/capitalisation.lua", "local function extraction_options" } },
}

-- Défauts : `cause` = la clé que la confirmation lit (obs[id].cause) ou écrit (Cf.CAUSE_*) ; `statuses` = statuts du moteur (defines.entity_status)
-- qui la donnent ; `signal` = ce qui la fait voir ; `lever` = clé de Df.LEVERS ; `effect` = ce que le levier fait ; `journal` = la ligne qui le prouve.
Df.FAULTS = {
  { cause = "courant", statuses = { "no_power", "low_power", "not_plugged_in_electric_network", "recharging_after_power_outage" }, signal = "statut machine sans courant (relevé des machines)",
    lever = "energie", effect = "les kW retenus faute de courant font grandir la centrale AVANT sa saturation (Ca.blocked_kw, S.capi_kw)",
    journal = "[FO-CAPI-KW]" },
  { cause = "entree", statuses = { "no_ingredients", "item_ingredient_shortage", "fluid_ingredient_shortage", "missing_required_fluid", "no_input_fluid",
      "low_input_fluid", "no_fuel", "waiting_for_source_items", "missing_science_packs" },
    signal = "statut machine sans entree (relevé des machines)", lever = "amont",
    effect = "l'amont est décidé avant l'aval : « entree X d'abord (couverte a N pour mille) », aucune machine de plus sur une entrée vide",
    journal = "[FO-CAPI] refus chaine:" },
  { cause = "sortie", statuses = { "full_output", "waiting_for_space_in_destination" }, signal = "statut machine à sortie pleine (relevé des machines)",
    lever = "collecte", effect = "la capacité reste comptée (Cf.KEEP) et la sortie est vidée par la tournée de collecte du plan directeur",
    journal = "[FO-CHAMP-ETAT] / [FO-QUOTA]" },
  { cause = "recette", statuses = { "no_recipe" }, signal = "statut machine sans recette (relevé des machines)", lever = "relance",
    effect = "le même plan est re-émis après Cf.RETRY (la recette est posée par l'exécutant à la pose)", journal = "[FO-CAPI-REPLI]" },
  { cause = "perdu", statuses = {}, signal = "unité suivie absente du relevé complet (Cf lost_now)", lever = "reconstruction",
    effect = "la pièce détruite est refaite par la reconstruction ; l'unité sort de la capacité", journal = "[FO-RECON]" },
  { cause = "rien produit", statuses = {}, signal = "engagé sans progrès depuis Cf.STALL (échec lu, aucune cause du moteur)", lever = "relance",
    effect = "ré-émission identique (C5.3), puis repli du plan (Rp)", journal = "[FO-CAPI-CONF] echec" },
  { cause = "jamais lu", statuses = {}, signal = "engagé sans aucune lecture de statut (compteur absent)", lever = "relance",
    effect = "ré-émission identique, puis repli du plan (Rp)", journal = "[FO-CAPI-CONF] echec" },
  { cause = "chantier occupe", statuses = {}, signal = "refus de l'exécutant « plan directeur occupe » (Dm.BUSY_TEXT)", lever = "relance",
    effect = "le MÊME plan est re-émis après Cf.RETRY, deux fois au plus (AmRt.RELANCES_MAX)", journal = "[FO-CAPI-CONF] relance" },
  { cause = "gisement epuise", statuses = { "no_minable_resources" }, signal = "foreuse sans minerai sous elle (amount <= 0)", lever = "ouvrir",
    effect = "un gisement connu de plus est ouvert d'avance (Ca.H_LIFE), l'épuisé ne compte plus (amount <= 0)", journal = "[FO-CAPI-COUV]" },
}

-- Statuts du moteur (defines.entity_status, API 1.1.91) qui ne sont PAS une panne de production à router : l'état normal ou voulu, ou un bâtiment
-- que la capitalisation ne suit pas (trains, fusée, accumulateurs, tourelles : leur levier est ailleurs, dit en clair). Le test relit la liste
-- complète du moteur : chaque statut est soit routé (Df.FAULTS), soit ici avec sa raison, jamais ignoré en silence.
Df.NOT_FAULT = {
  working = "etat normal", normal = "etat normal", disabled = "voulu : coupe par le joueur", disabled_by_control_behavior = "voulu : reseau de signaux",
  disabled_by_script = "voulu : coupe par un script", closed_by_circuit_network = "voulu : reseau de signaux", opened_by_circuit_network = "voulu : reseau de signaux",
  marked_for_deconstruction = "voulu : demontage ordonne", turned_off_during_daytime = "voulu : lampe", networks_connected = "pont de reseau, hors production",
  networks_disconnected = "pont de reseau, hors production", no_modules_to_transmit = "balise, hors production", low_temperature = "reacteur, non suivi",
  charging = "accumulateur, non suivi", discharging = "accumulateur, non suivi", fully_charged = "accumulateur, non suivi",
  launching_rocket = "fusee, hors du mod", preparing_rocket_for_launch = "fusee, hors du mod", waiting_to_launch_rocket = "fusee, hors du mod",
  cant_divide_segments = "rails, hors du mod", not_connected_to_rail = "rails, hors du mod", waiting_for_train = "rails, hors du mod",
  waiting_for_target_to_be_built = "fantome de rail, hors du mod", out_of_logistic_network = "robots logistiques, non suivi",
  no_ammo = "tourelle : levier = but defense:munitions (shared/ai3/buts.lua), pas une machine de production",
  no_research_in_progress = "laboratoire sans recherche : levier = choix de recherche (General.choose_tech)",
}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local BY_CAUSE = {}
for _, f in ipairs(Df.FAULTS) do BY_CAUSE[f.cause] = f end

--- Table statut du moteur -> cause (lue par script/ai3/capitalisation.lua pour CONF_CAUSE : une seule source).
function Df.status_cause()
  local out = {}
  for _, f in ipairs(Df.FAULTS) do
    for _, st in ipairs(f.statuses) do out[st] = f.cause end
  end
  return out
end

--- Le défaut d'une cause, ou nil.
function Df.lookup(cause) return BY_CAUSE[cause] end

--- Forme de la table : chaque défaut a cause, signal, levier connu, effet, journal ; une cause une seule fois ; un statut une seule fois.
--- Rend la liste des défauts (vide si tout va bien).
function Df.validate(faults, levers)
  faults, levers = faults or Df.FAULTS, levers or Df.LEVERS
  local bad, seen_c, seen_s = {}, {}, {}
  for i, f in ipairs(faults) do
    local who = tostring(f.cause or ("#" .. i))
    for _, k in ipairs({ "cause", "signal", "lever", "effect", "journal" }) do
      if type(f[k]) ~= "string" or f[k] == "" then bad[#bad + 1] = who .. " : " .. k .. " absent" end
    end
    if type(f.statuses) ~= "table" then bad[#bad + 1] = who .. " : statuses absent" end
    if f.lever and not levers[f.lever] then bad[#bad + 1] = who .. " : levier inconnu « " .. tostring(f.lever) .. " »" end
    if seen_c[f.cause or ""] then bad[#bad + 1] = who .. " : cause en double" end
    seen_c[f.cause or ""] = true
    for _, st in ipairs(f.statuses or {}) do
      if seen_s[st] then bad[#bad + 1] = who .. " : statut en double « " .. st .. " »" end
      seen_s[st] = true
    end
  end
  for _, name in ipairs(sorted_keys(levers)) do
    if type(levers[name]) ~= "table" or #levers[name] == 0 then bad[#bad + 1] = "levier " .. name .. " : aucun code cite" end
  end
  return bad
end

--- Range les événements d'un relevé. events = { { cause, item, id } } ; rend
---   rows     = { { cause, signal, lever, n, items = { objets triés, sans doublon } } } triées par cause (défauts de la table vus),
---   unrouted = { { cause, n, items } } (causes ABSENTES de la table : à écrire, jamais ignorées),
---   total    = nombre d'événements.
--- Un événement sans cause lisible (nil, vide, non texte) est NON ROUTÉ sous la cause « (aucune) ».
function Df.route(events)
  local by, un = {}, {}
  local total = 0
  for _, e in ipairs(events or {}) do
    total = total + 1
    local c = e and e.cause
    if type(c) ~= "string" or c == "" then c = "(aucune)" end
    local f = BY_CAUSE[c]
    local bucket
    if f then
      bucket = by[c] or { cause = c, signal = f.signal, lever = f.lever, n = 0, set = {} }
      by[c] = bucket
    else
      bucket = un[c] or { cause = c, n = 0, set = {} }
      un[c] = bucket
    end
    bucket.n = bucket.n + 1
    local it = e and e.item
    if type(it) == "string" and it ~= "" then bucket.set[it] = true end
  end
  local function finish(map)
    local out = {}
    for _, c in ipairs(sorted_keys(map)) do
      local b = map[c]
      b.items, b.set = sorted_keys(b.set), nil
      out[#out + 1] = b
    end
    return out
  end
  return { rows = finish(by), unrouted = finish(un), total = total }
end

--- Ligne du journal [FO-DEFAUT] d'un défaut routé (aucune décision ne la lit).
function Df.line(key, row, minutes)
  local f = BY_CAUSE[row.cause]
  return string.format("[FO-DEFAUT] %s : %s -> %s -> levier %s (%s) : %d unite(s) %s a %.1f min", key, row.cause, row.signal, row.lever,
    f and f.effect or "?", row.n, #row.items > 0 and ("[" .. table.concat(row.items, " ") .. "]") or "[]", minutes or 0)
end

--- Ligne d'un défaut SANS levier (refus écrit).
function Df.line_unrouted(key, row, minutes)
  return string.format("[FO-DEFAUT] %s : defaut sans levier « %s » : %d unite(s) %s a %.1f min (a ajouter a Df.FAULTS)", key, row.cause, row.n,
    #row.items > 0 and ("[" .. table.concat(row.items, " ") .. "]") or "[]", minutes or 0)
end

--- Signature d'un routage (pour n'écrire qu'aux changements) : « cause=n » triés, causes non routées comprises.
function Df.signature(r)
  local parts = {}
  for _, row in ipairs(r.rows) do parts[#parts + 1] = row.cause .. "=" .. row.n end
  for _, row in ipairs(r.unrouted) do parts[#parts + 1] = "?" .. row.cause .. "=" .. row.n end
  return table.concat(parts, ",")
end

return Df
