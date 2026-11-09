--[[
  Lot POSE-PAR-LOTS (DC, 8/11, 17 h 50) : « Un humain (speedrunner) se pose devant un gisement, lance le craft de 20 foreuses d'un
  coup dans son inventaire, pose ses lignes completes (foreuses + convoyeurs + poteaux electriques en un seul passage), et passe a
  la suite. Les PNJ ont les ressources, ils peuvent crafter en masse. Pourquoi ne le font-ils pas ? Le flux d'execution manque
  cruellement d'anticipation et d'actions par lots (batching). »

  Regle PURE (aucune API Factorio) du KIT DE FABRICATION d'un projet : ce qui manque a un projet du plan directeur (module,
  bande de champ, ordre de la capitalisation : etat « reserve », raison « materiaux ») et que le stock permet de fabriquer a la
  main devient UNE tache de fabrication qui porte TOUTES les pieces (un seul plan du livre de recettes : les intermediaires
  communs, engrenages par exemple, ne sont fabriques qu'une fois), et non une file de morceaux de 30 s par objet.

  Avant ce lot (shared/ai3/projets.lua, P.want) : chaque objet manquant etait coupe en morceaux d'environ 30 s de travail
  (P.CHUNK_SECONDS), chaque morceau etait une tache (home -> prise -> fabrication -> home) et comptait pour une des
  P.MAX_CRAFTS = 12 fabrications emises par pensee, y compris quand sa tache etait deja prise : quelques gros projets mangeaient le
  budget des autres, et les pieces d'un meme projet arrivaient au coffre une a une (le projet attend la derniere).

  Bornes d'un kit (« un lot borne par le stock et l'inventaire ») :
    - le STOCK : seul ce que le stock virtuel permet de fabriquer entre dans un kit (aucune matiere premiere manquante) ; le reste
      (matiere premiere, plafond) repart au chemin d'avant (P.want : fabrication partielle, manque brut pour la fonderie, le minage) ;
    - l'INVENTAIRE : cases du personnage (K.MAX_SLOTS sur 80) pour les ingredients pris au coffre et tout ce que la fabrication produit,
      intermediaires compris (par exces) ;
    - la DUREE : K.MAX_S secondes de fabrication a vitesse 1 (le delai d'une fabrication en arriere-plan est de 5 min, worker.lua) ;
    - K.MAX_KITS kits au plus par projet et par pensee : un projet plus gros que cela est servi par plusieurs PNJ libres.
  Un kit qui depasse la borne est coupe (par objet entier d'abord, puis par quantite) et la suite devient le kit suivant.

  Determinisme : listes dans l'ordre donne (les manques d'un projet sont deja tries), aucun pairs decisionnel, aucun hasard.
]]

local K = {}

K.MAX_S = 150        -- secondes de fabrication (vitesse 1) d'un kit
K.MAX_SLOTS = 48     -- cases d'inventaire (sur 80) pour un kit : ingredients + tout ce qui est fabrique
K.MAX_KITS = 3       -- kits par projet et par pensee
K.DEFAULT_STACK = 50 -- pile par defaut quand le livre ne dit pas la taille des piles (book.stack_of)
K.LOG_MAX = 24
K.SIG_MAX = 64       -- clés de kit gardées pour ne pas annoncer deux fois le même contenu

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function stack_of(book, item)
  local f = book and book.stack_of
  local s = f and f(item) or nil
  if type(s) ~= "number" or s < 1 then s = K.DEFAULT_STACK end
  return s
end

--- Secondes de fabrication (vitesse 1) d'un plan du livre.
function K.energy(plan)
  local s = 0
  for _, c in ipairs(plan.crafts or {}) do s = s + (c.energy or 0) end
  return s
end

--- Cases d'inventaire qu'un plan occupe au plus : ce qu'il prend au stock + tout ce que ses fabrications produisent (les
--- intermediaires sont comptes entiers : estimation par exces).
function K.slots(book, plan)
  local n = 0
  for _, item in ipairs(sorted_keys(plan.uses or {})) do
    n = n + math.ceil(plan.uses[item] / stack_of(book, item))
  end
  for _, c in ipairs(plan.crafts or {}) do
    local r = book.recipes and book.recipes[c.recipe]
    local p = r and r.products and r.products[1]
    if p then n = n + math.ceil((c.runs or 1) * (p.amount or 1) / stack_of(book, p.name)) end
  end
  return n
end

local function copy_wants(wants)
  local out = {}
  for i, w in ipairs(wants) do out[i] = { w[1], w[2] } end
  return out
end

--- Le plan de `wants` depuis `avail` tient-il dans les bornes ? Rend vrai, ou faux et la cause : « raw » (une matiere premiere
--- manque : le stock ne suffit pas) ou « caps » (duree ou inventaire).
local function fits(book, avail, wants, max_s, max_slots)
  local plan = book:plan(wants, avail)
  if next(plan.raw) ~= nil then return false, "raw", plan end
  if K.energy(plan) > max_s or K.slots(book, plan) > max_slots then return false, "caps", plan end
  return true, nil, plan
end

--- Plus grand k (<= left) tel que `cur` + { item, k } tient. Rend k, la cause de l'arret (nil si tout tient). Un premier objet
--- dans un kit vide est toujours admis (une unite) pourvu que le stock le permette : une unite plus lourde que la borne ne reste pas
--- sans fabricant.
local function best_k(book, avail, cur, item, left, max_s, max_slots)
  local function try(k)
    local w = copy_wants(cur)
    w[#w + 1] = { item, k }
    return fits(book, avail, w, max_s, max_slots)
  end
  local ok = try(left)
  if ok then return left, nil end
  local lo, hi = 0, left - 1
  local steps = 0
  while lo < hi and steps < 9 do
    steps = steps + 1
    local mid = math.floor((lo + hi + 1) / 2)
    if try(mid) then lo = mid else hi = mid - 1 end
  end
  local why
  do
    local _, cause = try(lo + 1)
    why = cause
  end
  if lo == 0 and #cur == 0 then
    -- une seule unite hors bornes (duree ou cases) mais fabricable : admise ; matiere premiere manquante : non
    local w = { { item, 1 } }
    local plan = book:plan(w, avail)
    if next(plan.raw) == nil then return 1, (left > 1) and "caps" or nil end
    return 0, "raw"
  end
  return lo, why
end

--- Construit les kits de ce qui manque. `shorts` = { {objet, n}, ... } (manques NETS du stock, dans l'ordre), `avail` = stock
--- virtuel { [objet] = n } (non modifie), opts = { max_s, max_slots, max_kits }.
--- Rend { kits, rest, avail } :
---   kits  = { { wants = {{objet, n}}, crafts, uses, energy, slots }, ... }   un kit = une tache de fabrication
---   rest  = { {objet, n}, ... }   ce que les kits ne couvrent pas (a servir par le chemin d'avant : fabrication partielle, manque brut)
---   avail = stock virtuel apres les kits.
function K.build(book, avail, shorts, opts)
  opts = opts or {}
  local max_s, max_slots = opts.max_s or K.MAX_S, opts.max_slots or K.MAX_SLOTS
  local max_kits = opts.max_kits or K.MAX_KITS
  local kits, rest = {}, {}
  local av = avail
  local cur = {}
  local function close()
    if #cur == 0 then return end
    local plan = book:plan(cur, av)
    kits[#kits + 1] = { wants = cur, crafts = plan.crafts, uses = plan.uses, energy = K.energy(plan), slots = K.slots(book, plan) }
    av = plan.avail
    cur = {}
  end
  for _, s in ipairs(shorts or {}) do
    local item, left = s[1], s[2]
    if left > 0 and not book:handcraftable(item) then
      rest[#rest + 1] = { item, left }
    elseif left > 0 then
      while left > 0 do
        if #kits >= max_kits and #cur == 0 then
          rest[#rest + 1] = { item, left }
          left = 0
        else
          local k, why = best_k(book, av, cur, item, left, max_s, max_slots)
          if k > 0 then
            cur[#cur + 1] = { item, k }
            left = left - k
          end
          if left > 0 then
            if why == "raw" or (k == 0 and #cur == 0) then
              -- le stock ne permet pas davantage : le reste est un manque de matiere premiere (chemin d'avant)
              rest[#rest + 1] = { item, left }
              left = 0
            else
              -- borne de duree ou d'inventaire : ce kit part, la suite ira dans le suivant
              close()
              if #kits >= max_kits then
                rest[#rest + 1] = { item, left }
                left = 0
              end
            end
          end
        end
      end
    end
  end
  close()
  return { kits = kits, rest = rest, avail = av }
end

--- Texte « objet xN, objet xM » d'une liste de pieces.
function K.pieces_text(list)
  local parts = {}
  for _, w in ipairs(list or {}) do parts[#parts + 1] = string.format("%s x%d", tostring(w[1]), w[2] or 0) end
  return table.concat(parts, ", ")
end

--- Annonce d'un kit emis dans st.kit_log (borne a K.LOG_MAX), relue par le runtime qui l'ecrit au journal [FO-LOTS-KIT]. Une fois par
--- (cle, contenu) : un kit libre est reemis a chaque pensee avec le meme contenu, sans nouvelle ligne. Rend vrai si annonce.
function K.announce(st, tick, rec)
  if type(st) ~= "table" then return false end
  local sig = K.pieces_text(rec.pieces)
  st.kit_sig = st.kit_sig or {}
  if st.kit_sig[rec.key] == sig then return false end
  st.kit_sig[rec.key] = sig
  st.kit_sig_n = (st.kit_sig_n or 0) + 1
  if st.kit_sig_n > K.SIG_MAX then st.kit_sig, st.kit_sig_n = { [rec.key] = sig }, 1 end
  st.kit_log = st.kit_log or {}
  st.kit_seq = (st.kit_seq or 0) + 1
  rec.seq, rec.tick = st.kit_seq, tick
  st.kit_log[#st.kit_log + 1] = rec
  while #st.kit_log > K.LOG_MAX do table.remove(st.kit_log, 1) end
  return true
end

return K
