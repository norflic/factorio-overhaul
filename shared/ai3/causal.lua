--[[
  Lot s42 causal (chantier 3.2 du DC, partie de 4 h 15 en 0.7.96) : ARBRE DES CAUSES d'une pénurie de plaques. Règle PURE (aucune API
  Factorio, AUCUN nom d'objet du jeu : tests/s42_causal_test.lua). Câblage : script/ai3/causal_rt.lua (relevé à l'audit des champs).

  Le dépôt lisait déjà chaque panne à part (table des défauts shared/ai3/defauts.lua, [FO-CHAMP-ETAT], [FO-ENERGIE], [FO-RESEAU],
  [FO-CHARBON-CENTRALE]) ; aucune règle ne REMONTAIT la chaîne : à 216 min, azure écrit « foreuses 131 (marche 0, sans courant 113) »,
  « fours 93 (sans entree 88) », « production 0 kW », « sources 1/1 a sec 1 » sur quatre lignes de quatre modules, et rien ne dit que la
  cause des fours vides est le charbon de la centrale. Ca.diagnostiquer rend UNE cause racine et UN ordre.

  Chaîne remontée, dans cet ordre (celui du DC) :
    1. symptôme   : manque de plaques (le besoin n'est pas couvert), sinon machines à l'arrêt (part Ca.PART_ARRET), sinon rien (sain) ;
    2. les fours  : l'état d'arrêt DOMINANT des fours (sans courant, sans combustible, sortie pleine, sans entrée). Une cause locale au four
                    s'arrête là ; « sans entrée » (le minerai n'arrive pas) ou aucun four à l'arrêt : on remonte aux foreuses ;
    3. les foreuses : l'état d'arrêt dominant (sans courant, sans combustible, gisement épuisé, sortie pleine) ;
    4. la racine  : courant (pas de centrale, chaudières à sec avec ou sans charbon au stock, centrale saturée, hors réseau), combustible
                    (au stock ou épuisé), ligne coupée (foreuses bloquées sortie pleine ALORS QUE les fours n'ont pas d'entrée, ou tapis
                    perdus), gisement épuisé, sortie pleine, débit insuffisant, aucune foreuse.

  Relevé (toutes les rubriques sont facultatives ; un nombre absent vaut 0, sauf `courant.kw` et `combustible.libre` : nil = non mesuré) :
    plaques     = { manque = booléen }
    fours       = { n, marche, sans_entree, sans_combustible, sortie_pleine, sans_courant }
    foreuses    = { n, marche, sortie_pleine, sans_courant, sans_combustible, epuisees }
    courant     = { generatrices, kw, chaudieres, a_sec, saturee = booléen }
    combustible = { libre }          combustible au stock de l'équipe
    pertes      = { tapis }          pièces de transport d'un chantier fini absentes du terrain

  Verdict : { symptome, cause, ordre, chaine = { maillons lus, dans l'ordre }, cle = "cause>ordre" } ; textes par Ca.TEXTE.
  Déterminisme : états départagés par une LISTE ordonnée (jamais pairs), aucune horloge, aucun état gardé.
]]

local Ca = {}

Ca.PART_ARRET = 0.25 -- sans manque de plaques, le symptôme « machines à l'arrêt » demande cette part de machines arrêtées

--- États d'arrêt, dans l'ordre qui départage une égalité : la cause la plus en amont d'abord (le courant arrête tout le reste).
Ca.ETATS_FOURS = { "sans_courant", "sans_combustible", "sortie_pleine", "sans_entree" }
Ca.ETATS_FOREUSES = { "sans_courant", "sans_combustible", "epuisees", "sortie_pleine" }

--- Ordres : le levier EXISTANT qui répond (nom lu par le câblage : script/ai3/causal_rt.lua, Rt.LEVIERS) ; liste ordonnée.
Ca.ORDRES = {
  { id = "aucun", levier = "aucun" },
  { id = "amorcer_centrale", levier = "amorce et remplissage du coffre de la centrale" },
  { id = "extraire_combustible", levier = "extraction du combustible (manque du cerveau)" },
  { id = "agrandir_centrale", levier = "croissance de la centrale" },
  { id = "raccorder", levier = "raccordement des consommateurs hors reseau" },
  { id = "reconstruire", levier = "balayage de reconstruction" },
  { id = "ravitailler", levier = "tournee de ravitaillement des bruleurs" },
  { id = "collecter", levier = "collecte des sorties" },
  { id = "etendre", levier = "extension de l'extraction" },
}

Ca.TEXTE = {
  -- symptômes
  manque_plaques = "manque de plaques",
  machines_arret = "machines a l'arret",
  sain = "rien a signaler",
  -- causes
  aucune = "aucune",
  pas_de_centrale = "panne de courant : aucune generatrice debout",
  chaudieres_a_sec = "panne de courant : chaudieres a sec, combustible au stock",
  centrale_sans_combustible = "panne de courant : chaudieres a sec et stock de combustible vide",
  centrale_saturee = "courant insuffisant : centrale saturee",
  hors_reseau = "panne de courant : machines hors du reseau alimente (ligne electrique coupee)",
  four_sans_combustible = "fours sans combustible, combustible au stock",
  foreuse_sans_combustible = "foreuses sans combustible, combustible au stock",
  combustible_epuise = "bruleurs sans combustible et stock de combustible vide",
  sortie_pleine = "sorties pleines",
  ligne_coupee = "ligne coupee : le minerai n'arrive pas aux fours",
  gisement_epuise = "gisement epuise",
  aucune_foreuse = "aucune foreuse debout",
  debit_insuffisant = "debit de minerai insuffisant, tout tourne",
  -- ordres
  aucun = "aucun",
  amorcer_centrale = "amorcer la centrale",
  extraire_combustible = "extraire du combustible",
  agrandir_centrale = "agrandir la centrale",
  raccorder = "raccorder au reseau",
  reconstruire = "reconstruire la ligne",
  ravitailler = "ravitailler les bruleurs",
  collecter = "vider les sorties",
  etendre = "etendre l'extraction",
}

local function nb(v) return (type(v) == "number" and v == v and v > 0 and v ~= math.huge) and v or 0 end

--- État d'arrêt dominant d'une rubrique : le plus grand compte ; égalité : le premier de la liste. Rend (état ou nil, compte).
function Ca.dominant(rub, etats)
  local best, bn = nil, 0
  for _, k in ipairs(etats) do
    local n = nb(rub and rub[k])
    if n > bn then best, bn = k, n end
  end
  return best, bn
end

local function verdict(symptome, cause, ordre, chaine)
  return { symptome = symptome, cause = cause, ordre = ordre, chaine = chaine, cle = cause .. ">" .. ordre }
end

--- Racine d'une panne de courant.
local function courant(r, symptome, chaine)
  local c = r.courant or {}
  local libre = r.combustible and r.combustible.libre
  if nb(c.generatrices) == 0 then
    chaine[#chaine + 1] = "courant:aucune generatrice"
    return verdict(symptome, "pas_de_centrale", "agrandir_centrale", chaine)
  end
  local sec, ch = nb(c.a_sec), nb(c.chaudieres)
  -- chaudières à sec : toutes, ou une partie et plus aucun kW produit (kW non mesuré : seules « toutes à sec » comptent)
  if sec > 0 and (sec >= ch or (type(c.kw) == "number" and c.kw <= 0)) then
    chaine[#chaine + 1] = string.format("courant:chaudieres a sec %d/%d", sec, ch)
    if type(libre) == "number" and libre <= 0 then
      chaine[#chaine + 1] = "combustible:stock vide"
      return verdict(symptome, "centrale_sans_combustible", "extraire_combustible", chaine)
    end
    return verdict(symptome, "chaudieres_a_sec", "amorcer_centrale", chaine)
  end
  if c.saturee == true then
    chaine[#chaine + 1] = "courant:centrale saturee"
    return verdict(symptome, "centrale_saturee", "agrandir_centrale", chaine)
  end
  chaine[#chaine + 1] = "courant:centrale en marche"
  return verdict(symptome, "hors_reseau", "raccorder", chaine)
end

--- Racine d'un brûleur à sec (qui = "four" ou "foreuse").
local function combustible(r, symptome, chaine, qui)
  local libre = r.combustible and r.combustible.libre
  if type(libre) == "number" and libre <= 0 then
    chaine[#chaine + 1] = "combustible:stock vide"
    return verdict(symptome, "combustible_epuise", "extraire_combustible", chaine)
  end
  return verdict(symptome, qui .. "_sans_combustible", "ravitailler", chaine)
end

--- L'arbre. Rend le verdict (jamais nil).
function Ca.diagnostiquer(r)
  r = type(r) == "table" and r or {}
  local fo, fr = r.fours or {}, r.foreuses or {}
  local fn, dn = nb(fo.n), nb(fr.n)
  local f_arret = math.max(0, fn - nb(fo.marche))
  local d_arret = math.max(0, dn - nb(fr.marche))
  local chaine = {}
  -- 1. symptôme
  local symptome
  if r.plaques and r.plaques.manque == true then
    symptome = "manque_plaques"
  elseif fn + dn > 0 and (f_arret + d_arret) >= Ca.PART_ARRET * (fn + dn) and (f_arret + d_arret) > 0 then
    symptome = "machines_arret"
  else
    return verdict("sain", "aucune", "aucun", chaine)
  end
  -- 2. les fours : le minerai arrive-t-il ?
  local fe, fen = Ca.dominant(fo, Ca.ETATS_FOURS)
  if fn > 0 then chaine[#chaine + 1] = string.format("fours:%s %d/%d", fe or "en marche", fe and fen or nb(fo.marche), fn) end
  if fe == "sans_courant" then return courant(r, symptome, chaine) end
  if fe == "sans_combustible" then return combustible(r, symptome, chaine, "four") end
  if fe == "sortie_pleine" then return verdict(symptome, "sortie_pleine", "collecter", chaine) end
  -- 3. les foreuses : tournent-elles ?
  if dn == 0 then
    chaine[#chaine + 1] = "foreuses:aucune"
    return verdict(symptome, "aucune_foreuse", "etendre", chaine)
  end
  local de, den = Ca.dominant(fr, Ca.ETATS_FOREUSES)
  chaine[#chaine + 1] = string.format("foreuses:%s %d/%d", de or "en marche", de and den or nb(fr.marche), dn)
  if de == "sans_courant" then return courant(r, symptome, chaine) end
  if de == "sans_combustible" then return combustible(r, symptome, chaine, "foreuse") end
  if de == "epuisees" then return verdict(symptome, "gisement_epuise", "etendre", chaine) end
  local tapis = nb(r.pertes and r.pertes.tapis)
  if de == "sortie_pleine" then
    -- la foreuse attend de la place : si les fours manquent d'entrée (ou s'il n'y a pas de four au bout), son minerai ne part pas
    if fe == "sans_entree" or tapis > 0 then
      if tapis > 0 then chaine[#chaine + 1] = "tapis perdus " .. tapis end
      return verdict(symptome, "ligne_coupee", "reconstruire", chaine)
    end
    if fn == 0 then return verdict(symptome, "sortie_pleine", "collecter", chaine) end
    -- les fours tournent et les foreuses attendent : la fonderie est le goulot, pas l'extraction ; les plaques manquent : sorties à vider
    return verdict(symptome, "sortie_pleine", "collecter", chaine)
  end
  -- 4. toutes les foreuses tournent
  if tapis > 0 and fe == "sans_entree" then
    chaine[#chaine + 1] = "tapis perdus " .. tapis
    return verdict(symptome, "ligne_coupee", "reconstruire", chaine)
  end
  return verdict(symptome, "debit_insuffisant", "etendre", chaine)
end

--- L'ordre connu de la table (ou nil).
function Ca.ordre(id)
  for _, o in ipairs(Ca.ORDRES) do if o.id == id then return o end end
  return nil
end

--- Ligne du journal : `[FO-CAUSAL] <équipe> min <m> | <symptôme> <- <cause> -> <ordre>` puis la chaîne lue et, s'il est donné, l'effet du câblage.
function Ca.ligne(qui, minute, v, effet)
  local t = Ca.TEXTE
  return string.format("[FO-CAUSAL] %s min %.0f | %s <- %s -> %s | chaine : %s%s", tostring(qui), minute, t[v.symptome] or tostring(v.symptome),
    t[v.cause] or tostring(v.cause), t[v.ordre] or tostring(v.ordre), #v.chaine > 0 and table.concat(v.chaine, " <- ") or "-",
    effet and effet ~= "" and (" | " .. effet) or "")
end

return Ca
