--[[
  Lot CHAMP (suite, corr-champ2 ; demande du lead, 2/11 à 20 h 20) : les fonderies des bandes du champ ne dépendent plus d'un PNJ qui passe.
  Mesuré à 150 min (partie finale, graine 20261020) : azure, 33 fours de bande sur 69 « sans combustible », coffres de combustible à 0 ;
  emerald, 21 095 plaques dans les coffres de sortie, 19 coffres au seuil de collecte : le minerai s'arrête, 38 % des foreuses électriques
  bloquées en sortie.

  Règle PURE d'un passage du flux d'un champ (script/team/champ_flux.lua l'applique) :
    - SORTIES : chaque coffre de sortie qui tient au moins CFG.out_min objets est vidé vers le stock du QG, les plus pleins d'abord, au plus
      CFG.budget_out objets par passage ;
    - COMBUSTIBLE : chaque coffre de combustible sous CFG.fuel_low reçoit du combustible du stock du QG, les plus vides d'abord : d'abord
      jusqu'à CFG.fuel_low pour tous, puis jusqu'à CFG.fuel_target ; jamais sous CFG.fuel_floor au stock (la centrale brûle le même charbon),
      au plus CFG.budget_fuel par passage.
  C'est un TRANSFERT PAR SCRIPT (ni tapis ni PNJ) : une abstraction logistique, à valider par le Directeur Créatif.
  Aucun nom d'objet ; aucun `pairs` ; résultat identique quel que soit l'ordre des listes (tri par quantité puis numéro).
]]

local M = {}

M.CFG = {
  every = 60 * 60,      -- un passage par minute de jeu
  out_min = 50,         -- objets au moins dans un coffre de sortie pour qu'il soit vidé
  budget_out = 4000,    -- objets rapatriés au plus par passage et par équipe
  fuel_low = 20,        -- un coffre de combustible sous ce seuil est servi
  fuel_target = 50,     -- ... jusqu'à ce niveau (deux fours de pierre : environ 19 min)
  fuel_floor = 200,     -- combustible gardé au stock du QG (centrale, fours du QG)
  budget_fuel = 1000,   -- combustible donné au plus par passage et par équipe
}

local function by(key, desc)
  return function(a, b)
    if a.n ~= b.n then if desc then return a.n > b.n end return a.n < b.n end
    return a.id < b.id
  end
end

--- outs = { { id, n } } (objets dans chaque coffre de sortie), quais = { { id, n } } (combustible dans chaque coffre de combustible), fuel =
--- combustible au stock du QG. Rend { take = { { id, n } }, give = { { id, n } }, out = objets rapatriés, fuel = combustible donné }.
function M.plan(outs, quais, fuel, cfg)
  cfg = cfg or M.CFG
  local take, give = {}, {}
  local o = {}
  for _, c in ipairs(outs or {}) do if (c.n or 0) >= cfg.out_min then o[#o + 1] = { id = c.id, n = c.n } end end
  table.sort(o, by("n", true))
  local left, out = cfg.budget_out, 0
  for _, c in ipairs(o) do
    if left <= 0 then break end
    local n = math.min(c.n, left)
    take[#take + 1] = { c.id, n }
    left, out = left - n, out + n
  end
  local q = {}
  for _, c in ipairs(quais or {}) do if (c.n or 0) < cfg.fuel_low then q[#q + 1] = { id = c.id, n = c.n or 0, add = 0 } end end
  table.sort(q, by("n", false))
  local avail = math.max(0, math.min(cfg.budget_fuel, (fuel or 0) - cfg.fuel_floor))
  local given = 0
  for _, level in ipairs({ cfg.fuel_low, cfg.fuel_target }) do
    for _, c in ipairs(q) do
      if avail <= 0 then break end
      local n = math.min(level - (c.n + c.add), avail)
      if n > 0 then c.add, avail, given = c.add + n, avail - n, given + n end
    end
  end
  for _, c in ipairs(q) do if c.add > 0 then give[#give + 1] = { c.id, c.add } end end
  return { take = take, give = give, out = out, fuel = given }
end

return M
