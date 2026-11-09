--[[
  Lot MOTIFS : TÊTE DE RÉPARTITEURS pour l'ENTRÉE de plusieurs colonnes (demande de team-lead, 8/11 : « arbre 1 → N devant plusieurs
  colonnes, pour mega-fonderie et le mall »). Lua PUR, fabrique la DÉFINITION d'un arbre de répartiteurs planaire :
    une ligne entre à l'ouest ; K = 2^m lignes sortent à l'est, aux rangées des tapis d'entrée de K colonnes EMPILÉES (une colonne de
    hauteur `hauteur` tous les `pas` tuiles, son tapis d'entrée à la rangée `mid` de sa propre hauteur).
  Géométrie : à chaque niveau, un répartiteur (2 tuiles) reçoit la ligne sur sa rangée du haut ; ses deux sorties tournent l'une vers le nord,
  l'autre vers le sud (colonne verticale propre au niveau) jusqu'à la rangée d'entrée du répartiteur suivant ; au dernier niveau les
  lignes tournent vers l'est et vont au bord. Planaire : aucun croisement, aucun souterrain. Les voies sont conservées par les répartiteurs
  (minerai voie 1, combustible voie 2 restent mêlés exactement comme à l'entrée) ; chaque sortie porte 1/K du flux d'entrée.
  Le motif est une tuile UNIQUE (non répétable) ; les colonnes se posent à sa droite, une par sortie (k = 1 en haut).
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end
local D = need("shared.team.motifs.dsl", "shared/team/motifs/dsl")
local h = D.h
local E = D.E

local X = {}

--- Définition de l'arbre : K (puissance de 2, 2 à 16), pas (tuiles entre deux colonnes), mid (rangée du tapis d'entrée d'une colonne),
--- hauteur (hauteur d'une colonne, défaut : pas), jetons (jetons de la ligne : { A = { 1 }, combustible = { 2 } }). Renvoie (def) ou (nil, raison).
function X.definition(K, pas, mid, hauteur, jetons, id)
  local m = 0
  while 2 ^ m < K do m = m + 1 end
  if K < 2 or 2 ^ m ~= K or K > 8 then return nil, "K doit être 2, 4 ou 8" end
  hauteur = hauteur or pas
  if pas < 3 or mid < 0 or mid >= hauteur then return nil, "pas ou rangée d'entrée invalide" end
  local H = (K - 1) * pas + hauteur
  local Lh = 2 * m + 3
  local y = {}
  for i = 0, K - 1 do y[i] = mid + i * pas end
  local g = {}
  for r = 1, H do
    g[r] = {}
    for c = 1, Lh do g[r][c] = "." end
  end
  local function put(col, row, ch) g[row + 1][col + 1] = ch end
  -- rangée d'entrée d'un noeud : le répartiteur occupe (a, a + 1) ; a = partie entière du milieu des rangées de ses sorties extrêmes
  local function rang(lo, hi)
    if lo == hi then return y[lo] end
    return math.floor((y[lo] + y[hi]) / 2)
  end
  local sorties = {}
  local function noeud(lo, hi, niveau)
    local a = rang(lo, hi)
    local S = 2 * niveau + 1          -- colonne du répartiteur
    local V = S + 1                    -- colonne verticale du niveau
    put(S, a, "S"); put(S, a + 1, "S")
    local mid_i = math.floor((lo + hi - 1) / 2)
    local haut, bas = { lo, mid_i }, { mid_i + 1, hi }
    local ah = rang(haut[1], haut[2])
    local ab = rang(bas[1], bas[2])
    -- sortie du haut : tourne au nord (rangée a), monte jusqu'à ah ; sortie du bas : tourne au sud (rangée a + 1), descend jusqu'à ab
    for r = ah + 1, a do put(V, r, "n") end
    put(V, ah, "t")
    for r = a + 1, ab - 1 do put(V, r, "v") end
    put(V, ab, "t")
    for _, sous in ipairs({ { haut[1], haut[2], ah }, { bas[1], bas[2], ab } }) do
      if sous[1] == sous[2] then
        -- feuille : la ligne va à l'est jusqu'au bord, rangée y[i]
        for c = V + 1, Lh - 2 do put(c, sous[3], "t") end
        put(Lh - 1, sous[3], string.char(string.byte("a") + sous[1] + 1))   -- 'b', 'c', … pour k = 1, 2, … (K ≤ 8 : aucun conflit avec n, t, v)
        sorties[#sorties + 1] = { k = sous[1] + 1, cote = "E", pos = sous[3], jetons = jetons }
      else
        noeud(sous[1], sous[2], niveau + 1)
      end
    end
  end
  noeud(0, K - 1, 0)
  local a0 = rang(0, K - 1)
  put(0, a0, "a")
  table.sort(sorties, function(p, q) return p.k < q.k end)
  local art = {}
  for r = 1, H do art[r] = table.concat(g[r]) end
  local legende = { a = h.entree(1, E), t = h.tapis(E), n = h.tapis(D.N), v = h.tapis(D.S), S = h.repartiteur(E) }
  for k = 1, K do legende[string.char(string.byte("a") + k)] = h.sortie(k, E) end
  return {
    id = id or ("distribution-" .. K .. "-pas-" .. pas), famille = "equilibreur", usages = { "equilibreur", "distribution" }, origine = "derive",
    source = { "https://wiki.factorio.com/Balancers", "https://wiki.factorio.com/Splitter" },
    nom_fr = "Tête de répartiteurs : 1 ligne vers " .. K .. " colonnes (pas " .. pas .. ")",
    nom_en = "Splitter head: 1 line to " .. K .. " columns (pitch " .. pas .. ")",
    note_fr = "Arbre planaire de " .. (K - 1) .. " répartiteurs : une ligne entre à l'ouest et " .. K .. " lignes à parts égales sortent à l'est, aux rangées d'entrée de "
      .. K .. " colonnes empilées tous les " .. pas .. " tuiles (rangée " .. mid .. " de chaque colonne de hauteur " .. hauteur .. "). Les voies sont conservées. Tuile unique : "
      .. "les colonnes se posent à sa droite.",
    repetable = false, art = art, legende = legende,
    entrees = { { k = 1, cote = "O", pos = a0, jetons = jetons } }, sorties = sorties,
    capacite = { entrees = 1, sorties = K, repartiteurs = K - 1, pas = pas },
  }
end

return X
