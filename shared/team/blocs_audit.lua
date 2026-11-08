--[[
  Lot RESEAU-GRAPHE, second ajout du DC (8/11 vers 12 h) : AUDIT « n entrées, m sorties » d'un bloc d'usine. Règle PURE : aucune API du jeu,
  aucun nom d'objet (le combustible, les minerais et les fonctions de lecture sont passés par le contexte) ; lue hors jeu
  (tests/blocs_audit_test.lua). Conception : docs/conception/RESEAU_GRAPHE.md §10.

  « Vérifie bien qu'un bloc d'usine, ça a n inputs et n outputs en fonction des outputs [...] sinon ça peut poser problème en termes de logique
  et d'optimisation et pour optimiser l'espace de la base et la production. »

  Un bloc est un NŒUD à n entrées et m sorties typées par objet. Pour un gabarit g (shared/team/modules.lua) et son analyse rep (M.analyze) :
    - ENTRÉES ATTENDUES = ingrédients solides distincts des recettes de ses machines, nets de ce que ses propres machines produisent (un engrenage
      fabriqué dedans n'est pas une entrée), plus le combustible si une machine brûle ; SORTIES ATTENDUES = produits solides nets ;
    - recalcul INDÉPENDANT des débits (recette x cadence prévue) contre ce que l'analyse et le gabarit déclarent ;
    - PORTS : chaque entrée attendue arrive par au moins un port ; aucun port n'amène un objet qui n'est pas une entrée ; aucune voie ne mêle
      deux objets ; chaque sortie attendue part par un port ; aucun port ne sort un objet qui n'est pas un produit net ;
    - DIMENSIONNEMENT : capacité d'arrivée de chaque entrée contre son débit : par tapis (7,5/s par voie) ou par quai (un bras par objet et par
      port tapis, P.feeder du plan directeur ; 0,83/s pour le bras de base) ; capacité de sortie par voie.
  Rend un rapport { key, n_in_exp, n_in_real, n_out_exp, n_out_real, gaps = { { code, item, expected, real, text } }, notes }. Une liste `gaps`
  vide = bloc conforme. Déterminisme : listes triées, aucun pairs.
]]

local Au = {}

Au.TOL = 1e-6
Au.LANE_RATE = 7.5   -- objets/s par voie d'un tapis de base (shared/team/modules.lua, M.LANE_RATE)
Au.QUAI_ARM_RATE = 0.83 -- objets/s du bras d'un quai d'entrée de base (un seul par objet et par port : P.feeder, build.lua)
Au.ORE_BELT_FLOW = 1.0  -- objets/s : au-delà, un minerai est servi par foreuses et tapis, plus par quai (P.AUTO_FLOW)

local function sorted_set(set)
  local out = {}
  for k in next, set do out[#out + 1] = k end
  table.sort(out)
  return out
end

local function has(list, v)
  for _, x in ipairs(list or {}) do if x == v then return true end end
  return false
end

local function rel_gap(a, b) return math.abs(a - b) > Au.TOL * math.max(1, math.abs(a), math.abs(b)) end

--- ctx = { recipes (M.RECIPES), spec_of (M.spec), fuel (nom du combustible), ores (ensemble des minerais, M.ORES), fluids = { [objet] = true }
--- (facultatif : déduit des recettes), ignore = { [objet] = true } (ex. la sortie électrique) }.
function Au.audit(g, rep, ctx)
  local R, spec_of = ctx.recipes, ctx.spec_of
  local ignore = ctx.ignore or {}
  local fluid = {}
  for _, k in ipairs(sorted_set(ctx.fluids or {})) do fluid[k] = true end
  for _, name in ipairs(sorted_set(R)) do
    for _, list in ipairs({ R[name].ingredients or {}, R[name].products or {} }) do
      for _, it in ipairs(list) do if it.fluid then fluid[it.name] = true end end
    end
  end
  local gaps, notes = {}, {}
  local function gap(code, item, expected, real, text)
    gaps[#gaps + 1] = { code = code, item = item, expected = expected, real = real, text = text }
  end

  -- 1. bilan par recette (indépendant de l'analyse)
  local cons, prod = {}, {}
  local burns = false
  for i, e in ipairs(g.entities or {}) do
    local s = spec_of(e.name)
    if s then
      local rate = (rep.rates and rep.rates[i]) or e.rate or 0
      if (s.kind == "assembler" or s.kind == "furnace") and e.recipe and R[e.recipe] then
        for _, ing in ipairs(R[e.recipe].ingredients or {}) do
          if not ing.fluid then cons[ing.name] = (cons[ing.name] or 0) + ing.amount * rate end
        end
        for _, p in ipairs(R[e.recipe].products or {}) do
          if not p.fluid then prod[p.name] = (prod[p.name] or 0) + p.amount * rate end
        end
      elseif s.kind == "drill" and g.resource then
        prod[g.resource] = (prod[g.resource] or 0) + rate
      elseif s.kind == "lab" and g.labs then
        for _, pk in ipairs(g.labs.packs or {}) do cons[pk] = (cons[pk] or 0) + rate end
      end
      if s.burner_kw and s.burner_kw > 0 and s.kind ~= "inserter" then burns = true end
    end
  end
  local exp_in, exp_out = {}, {}
  for _, it in ipairs(sorted_set(cons)) do
    local net = (prod[it] or 0) - cons[it]
    if net < -Au.TOL and not fluid[it] and not ignore[it] then exp_in[it] = -net end
  end
  for _, it in ipairs(sorted_set(prod)) do
    local net = prod[it] - (cons[it] or 0)
    if net > Au.TOL and not fluid[it] and not ignore[it] then exp_out[it] = net end
  end
  local fuel = ctx.fuel
  local fuel_by_porters = #(g.fuel_ports or {}) > 0
  if burns and fuel and not exp_in[fuel] and not (prod[fuel] and prod[fuel] > 0) then exp_in[fuel] = true end

  -- 2. entrées et sorties réelles (analyse), solides seulement
  local real_in, real_out = {}, {}
  for _, it in ipairs(sorted_set(rep.inputs or {})) do if not fluid[it] and not ignore[it] then real_in[it] = rep.inputs[it] end end
  for _, it in ipairs(sorted_set(rep.outputs or {})) do if not fluid[it] and not ignore[it] then real_out[it] = rep.outputs[it] end end
  for _, it in ipairs(sorted_set(exp_in)) do
    if real_in[it] == nil then gap("entree-manquante", it, exp_in[it], 0, "ingrédient solide sans entrée dans l'analyse") end
  end
  for _, it in ipairs(sorted_set(real_in)) do
    if exp_in[it] == nil then gap("entree-inutile", it, 0, real_in[it], "entrée qui n'est l'ingrédient d'aucune recette du bloc") end
  end
  for _, it in ipairs(sorted_set(exp_out)) do
    if real_out[it] == nil then gap("sortie-manquante", it, exp_out[it], 0, "produit net sans sortie dans l'analyse") end
  end
  for _, it in ipairs(sorted_set(real_out)) do
    if exp_out[it] == nil then gap("sortie-parasite", it, 0, real_out[it], "sortie qui n'est le produit net d'aucune recette du bloc") end
  end
  for _, it in ipairs(sorted_set(exp_in)) do
    if real_in[it] ~= nil and exp_in[it] ~= true and rel_gap(exp_in[it], real_in[it]) then
      gap("debit-entree", it, exp_in[it], real_in[it], "débit d'entrée recalculé différent de l'analyse")
    end
  end
  for _, it in ipairs(sorted_set(exp_out)) do
    if real_out[it] ~= nil and rel_gap(exp_out[it], real_out[it]) then
      gap("debit-sortie", it, exp_out[it], real_out[it], "débit de sortie recalculé différent de l'analyse")
    end
  end
  -- déclaré (g.inputs, g.nominal) contre recalculé
  for _, it in ipairs(sorted_set(g.inputs or {})) do
    if not fluid[it] and not ignore[it] and (real_in[it] == nil or rel_gap(g.inputs[it], real_in[it])) then
      gap("declare-entree", it, real_in[it] or 0, g.inputs[it], "entrée déclarée au gabarit différente de l'analyse")
    end
  end
  for _, it in ipairs(sorted_set(g.nominal or {})) do
    if not fluid[it] and not ignore[it] and (real_out[it] == nil or rel_gap(g.nominal[it], real_out[it])) then
      gap("declare-sortie", it, real_out[it] or 0, g.nominal[it], "sortie déclarée au gabarit différente de l'analyse")
    end
  end

  -- 3. ports
  local in_ports, out_ports = {}, {} -- objet -> nombre de ports
  local lane_cap_in, lane_cap_out = {}, {} -- objet -> capacité par voies (objets/s)
  local function lane_items(pi, p)
    local l = rep.lanes and rep.lanes[pi]
    if l then return { l[1] or {}, l[2] or {} } end
    if p.lanes then return { p.lanes[1] and { p.lanes[1] } or {}, p.lanes[2] and { p.lanes[2] } or {} } end
    return { p.item and { p.item } or {}, {} }
  end
  for pi, p in ipairs(g.ports or {}) do
    if p.kind == "tapis" or p.kind == "four" or p.kind == "quai" then
      local lanes = lane_items(pi, p)
      local seen = {}
      for l = 1, 2 do
        local items = lanes[l]
        local distinct = {}
        for _, it in ipairs(items) do if not has(distinct, it) then distinct[#distinct + 1] = it end end
        if #distinct > 1 then
          table.sort(distinct)
          gap("voie-melee", table.concat(distinct, "+"), 1, #distinct, "port " .. pi .. " voie " .. l .. " : plusieurs objets sur la même voie")
        end
        for _, it in ipairs(distinct) do
          seen[it] = true
          local cap = p.kind == "tapis" and Au.LANE_RATE or math.huge
          if p.io == "in" then lane_cap_in[it] = (lane_cap_in[it] or 0) + cap else lane_cap_out[it] = (lane_cap_out[it] or 0) + cap end
        end
      end
      for _, it in ipairs(sorted_set(seen)) do
        if p.io == "in" then
          in_ports[it] = (in_ports[it] or 0) + 1
          if not fluid[it] and exp_in[it] == nil and not ignore[it] then gap("port-entree-inutile", it, 0, 1, "port " .. pi .. " : amène un objet qui n'est pas une entrée") end
        else
          out_ports[it] = (out_ports[it] or 0) + 1
          if not fluid[it] and exp_out[it] == nil and not ignore[it] then gap("port-sortie-parasite", it, 0, 1, "port " .. pi .. " : sort un objet qui n'est pas un produit net") end
        end
      end
    end
  end
  for _, it in ipairs(sorted_set(exp_in)) do
    local fed_other = (it == fuel and fuel_by_porters) or (g.resource == it)
    if not in_ports[it] and not fed_other then gap("entree-sans-port", it, 1, 0, "ingrédient sans port d'entrée") end
  end
  for _, it in ipairs(sorted_set(exp_out)) do
    if not out_ports[it] then gap("sortie-sans-port", it, 1, 0, "produit net sans port de sortie") end
  end

  -- 4. dimensionnement
  for _, it in ipairs(sorted_set(exp_in)) do
    local rate = exp_in[it]
    if rate ~= true and in_ports[it] then
      local by_lane = lane_cap_in[it] or 0
      local quai_cap = in_ports[it] * Au.QUAI_ARM_RATE
      local belt_fed = ctx.ores and ctx.ores[it] and it ~= fuel and rate >= Au.ORE_BELT_FLOW
      if not belt_fed and rate > quai_cap + Au.TOL then
        gap("quai-sous-dimensionne", it, rate, quai_cap, string.format("%d port(s) x un bras de %.2f/s pour %.3f/s d'entrée", in_ports[it], Au.QUAI_ARM_RATE, rate))
      end
      if rate > by_lane + Au.TOL then
        gap("tapis-entree-sous-dimensionne", it, rate, by_lane, string.format("voies d'arrivée %.1f/s pour %.3f/s d'entrée", by_lane, rate))
      end
    end
  end
  for _, it in ipairs(sorted_set(exp_out)) do
    local cap = lane_cap_out[it]
    if cap and cap < math.huge and exp_out[it] > cap + Au.TOL then
      gap("tapis-sortie-sous-dimensionne", it, exp_out[it], cap, string.format("voies de sortie %.1f/s pour %.3f/s produits", cap, exp_out[it]))
    end
  end

  local n_in_exp, n_out_exp, n_in_real, n_out_real = 0, 0, 0, 0
  for _ in next, exp_in do n_in_exp = n_in_exp + 1 end
  for _ in next, exp_out do n_out_exp = n_out_exp + 1 end
  for _ in next, real_in do n_in_real = n_in_real + 1 end
  for _ in next, real_out do n_out_real = n_out_real + 1 end
  return { key = g.key, n_in_exp = n_in_exp, n_in_real = n_in_real, n_out_exp = n_out_exp, n_out_real = n_out_real,
    in_exp = sorted_set(exp_in), in_real = sorted_set(real_in), out_exp = sorted_set(exp_out), out_real = sorted_set(real_out),
    gaps = gaps, notes = notes }
end

--- Les écarts d'un rapport d'un code donné.
function Au.of_code(report, code)
  local out = {}
  for _, g in ipairs(report.gaps) do if g.code == code then out[#out + 1] = g end end
  return out
end

--- Vrai si le rapport n'a aucun écart « de structure » (n, m, ports) ; les écarts de dimensionnement se lisent à part.
local STRUCT = { ["entree-manquante"] = true, ["entree-inutile"] = true, ["sortie-manquante"] = true, ["sortie-parasite"] = true,
  ["debit-entree"] = true, ["debit-sortie"] = true, ["declare-entree"] = true, ["declare-sortie"] = true, ["port-entree-inutile"] = true,
  ["port-sortie-parasite"] = true, ["voie-melee"] = true, ["entree-sans-port"] = true, ["sortie-sans-port"] = true }
function Au.structural(report)
  local out = {}
  for _, g in ipairs(report.gaps) do if STRUCT[g.code] then out[#out + 1] = g end end
  return out
end

return Au
