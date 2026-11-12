--[[
  Lot MARGE-TIERS (13/11, P1 du DC) : « la production des ressources de Tier 0 (minerai, plaques de fer et de cuivre) et de Tier 1
  doit toujours dépasser la consommation globale d'au moins 20 %. Tant que cette marge n'est pas atteinte, tout investissement
  dans les tiers supérieurs est gelé au profit exclusif de nouvelles foreuses et fonderies. »
  PUR (aucune API Factorio, aucun nom du jeu : tests/iag_test.lua §8) ; tests/marge_test.lua.

  TIERS, lus dans les données : le rang de la décision (Rg.chain, ctx.rang.rank), profondeur de recette depuis les ressources
  minables. Rang 0 = produit d'une ressource (minerai), rang 1 = ce qu'on en tire directement (plaques) : TIER 0 ; rang 2 : TIER 1.
  Rang 3 et plus : tiers supérieurs (Mg.RANK_T1 = 2).

  MESURE (fenêtre glissante, Mg.WINDOW ticks) : à chaque décision le runtime (script/ai3/capitalisation.lua) pousse un relevé
  { t = tick, dt = minutes depuis le relevé précédent, made = { [objet] = fabriqués }, used = { [objet] = consommés } } lus aux
  statistiques de la force (item_production_statistics, compteurs cumulés : made = input_counts + fabrication à la main des PNJ,
  used = output_counts). Mg.rates rend { [objet] = { p, c } } par minute sur la fenêtre.

  MARGE d'un objet de tier 0 ou 1 consommé (c >= Mg.MIN_RATE /min) :
      offre = max(production mesurée p, capacité nominale posée P) + stock ÷ H ;   marge = offre ÷ c − 1.
  La CAPACITÉ compte (et pas seulement la production) : un objet fait à la demande ou une foreuse figée faute de place produisent
  exactement ce qui part (p = c), sans que la base manque de rien ; sans elle, toute chaîne saturée gèlerait les tiers
  supérieurs pour toujours (mise en garde des panels : un gel mal calibré bloque tout). La marge manque seulement quand la base
  consomme plus de 1 ÷ 1,2 = 83 % de ce que ses foreuses et fours posés savent sortir.

  GEL (hystérésis) : posé après Mg.ON_N décisions de suite avec une marge < Mg.PCT %, levé après Mg.OFF_N décisions de suite
  sans. Gelé : une option de CHAÎNE (assembleurs) d'un objet de rang > Mg.RANK_T1, sauf :
    - la défense : objets militaires (type du moteur, D.mil), objets qui posent un bâtiment militaire (tourelle, mur), demandés par
      la décision, et tout ce qui entre dans leurs recettes ;
    - les foreuses et les fonderies EXÉCUTABLES (relevé Ca.data, opts.exec) et ce qui entre dans leurs recettes, ainsi que la logistique et le courant qui les servent
      (types du moteur R.KIT_TYPE et R.PLANT_TYPES), au plus du rang de la foreuse ou de la fonderie la plus haute ;
    - sous menace (ctx.threat) : rien n'est gelé.
  Jamais gelés (autres types d'ordres) : couvrir, ouvrir, fours, packs, laboratoires, courant, leviers ; la pile (réparation,
  reconstruction, défense) ne passe pas par ici.

  Déterminisme : clés triées, aucun hasard ; état : nombres et tables de nombres.
]]

local Mg = {}

Mg.ON = true
Mg.PCT = 20          -- % de marge voulue (DC)
Mg.RANK_T1 = 2       -- rang le plus haut des tiers 0 et 1
Mg.MIN_RATE = 5      -- objets/min consommés : en dessous, la marge est du bruit
Mg.WINDOW = 5 * 3600 -- ticks de la fenêtre glissante
Mg.H_STOCK = 10      -- min : un stock couvre son débit pendant 10 min (= Ca.H_STOCK)
Mg.ON_N = 2          -- décisions de suite sous la marge avant le gel
Mg.OFF_N = 2         -- … et au-dessus avant la levée
Mg.LOG_MAX = 4       -- objets cités par ligne de journal

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function num(v) return type(v) == "number" and v == v and v or 0 end

--- Fenêtre neuve (état du runtime : nombres et tables de nombres).
function Mg.new() return { s = {} } end

--- Ajoute un relevé et oublie ceux qui sortent de la fenêtre. sample = { t, dt (min, > 0), made = {}, used = {} }.
function Mg.push(win, sample)
  if not (sample and num(sample.dt) > 0) then return end
  local s = win.s
  s[#s + 1] = { t = sample.t, dt = sample.dt, made = sample.made or {}, used = sample.used or {} }
  while #s > 0 and s[1].t <= sample.t - Mg.WINDOW do table.remove(s, 1) end
end

--- Débits moyens par minute sur la fenêtre : { [objet] = { p, c } } (vide sans relevé).
function Mg.rates(win)
  local tot, sp, sc = 0, {}, {}
  for _, e in ipairs((win and win.s) or {}) do
    tot = tot + num(e.dt)
    for _, k in ipairs(sorted_keys(e.made)) do sp[k] = (sp[k] or 0) + num(e.made[k]) end
    for _, k in ipairs(sorted_keys(e.used)) do sc[k] = (sc[k] or 0) + num(e.used[k]) end
  end
  local out = {}
  if tot <= 0 then return out end
  local keys = {}
  for k in pairs(sp) do keys[k] = true end
  for k in pairs(sc) do keys[k] = true end
  for _, k in ipairs(sorted_keys(keys)) do out[k] = { p = (sp[k] or 0) / tot, c = (sc[k] or 0) / tot } end
  return out, tot
end

--- Lignes de marge : { { item, rank, p, c, cap, stock, supply, pct } } triées de la plus faible marge à la plus forte (puis le nom).
--- rates = Mg.rates ; rank = { [objet] = rang } ; cap = { [objet] = capacité nominale posée /min } ; stock = { [objet] = n } ;
--- skip = { [objet] = vrai } (fluides).
function Mg.rows(rates, rank, cap, stock, skip)
  local rows = {}
  for _, i in ipairs(sorted_keys(rates)) do
    local r, rk = rates[i], rank[i]
    if rk ~= nil and rk <= Mg.RANK_T1 and not (skip and skip[i]) and num(r.c) >= Mg.MIN_RATE then
      local s = num((stock or {})[i])
      local supply = math.max(num(r.p), num((cap or {})[i])) + s / Mg.H_STOCK
      rows[#rows + 1] = { item = i, rank = rk, p = num(r.p), c = num(r.c), cap = num((cap or {})[i]), stock = s, supply = supply,
        pct = (supply / r.c - 1) * 100 }
    end
  end
  table.sort(rows, function(a, b)
    if a.pct ~= b.pct then return a.pct < b.pct end
    return a.item < b.item
  end)
  return rows
end

--- Verdict d'une décision, avec l'hystérésis dans `st` ({ below, above, gel }, nombres et booléen).
--- Rend { gel, short = lignes sous la marge, rows, worst }.
function Mg.step(st, rows)
  local short = {}
  for _, r in ipairs(rows) do if r.pct < Mg.PCT then short[#short + 1] = r end end
  if #short > 0 then
    st.below, st.above = (st.below or 0) + 1, 0
    if (st.below or 0) >= Mg.ON_N then st.gel = true end
  else
    st.above, st.below = (st.above or 0) + 1, 0
    if (st.above or 0) >= Mg.OFF_N then st.gel = false end
  end
  return { gel = st.gel == true, short = short, rows = rows, worst = rows[1] }
end

--- Fermeture des recettes (sans filtre militaire, sans fluide) : `seeds` et tout ce qui entre dans une de leurs recettes.
function Mg.closure(D, seeds, out)
  out = out or {}
  local stack = {}
  for i = #seeds, 1, -1 do stack[#stack + 1] = seeds[i] end
  while #stack > 0 do
    local x = stack[#stack]
    stack[#stack] = nil
    if x and not out[x] then
      out[x] = true
      for _, rn in ipairs(D.producers[x] or {}) do
        for _, i in ipairs(D.recipes[rn].ingredients) do
          if not i.fluid and not out[i.name] then stack[#stack + 1] = i.name end
        end
      end
    end
  end
  return out
end

--- Objets jamais gelés : { [objet] = "defense" | "extraction" }. D = Ca.data ; rank = rang ; roles = { item_role, entity_role,
--- kit, plant } (tables de shared/ai3/reglages.lua : rôle par type du moteur). Rien n'y est nommé : tout se lit aux types.
function Mg.exempt(D, rank, roles)
  local ent_role = roles.entity_role or {}
  local items = D.items or {}
  local function place_role(i) local it = items[i] return it and it.place and ent_role[it.place] or nil end
  -- Défense : objets militaires et objets qui posent un bâtiment militaire, DEMANDÉS par la décision (un rang : la fermeture d'une
  -- armure lointaine n'exempte pas toute l'industrie), et leurs recettes.
  local mil = {}
  for _, i in ipairs(sorted_keys(items)) do
    if rank[i] ~= nil and (D.mil[i] or place_role(i) == "militaire") then mil[#mil + 1] = i end
  end
  local out = {}
  for k in pairs(Mg.closure(D, mil)) do out[k] = "defense" end
  -- Extraction : foreuses exécutables, fonderies (fabrique qui n'est pas un assembleur et sait tirer un objet des ressources).
  local raw_cat = {}
  for _, rn in ipairs(D.recipe_list or {}) do
    local r = D.recipes[rn]
    local all_raw = #r.ingredients > 0
    for _, ing in ipairs(r.ingredients) do if not D.res[ing.name] then all_raw = false end end
    if all_raw then raw_cat[r.category] = true end
  end
  local seeds, top = {}, -1
  local function seed(i)
    seeds[#seeds + 1] = i
    if rank[i] ~= nil and rank[i] > top then top = rank[i] end
  end
  for _, d in ipairs(D.drills or {}) do if d.exec ~= false then seed(d.item) end end
  for _, m in ipairs(D.makers or {}) do
    if m.exec ~= false and not m.assembler then
      local smelter = false
      for _, c in ipairs(m.cat_list or {}) do if raw_cat[c] then smelter = true end end
      if smelter then seed(m.item) end
    end
  end
  -- Logistique et courant qui servent foreuses et fonderies (types du moteur), au plus du rang de la plus haute d'entre elles.
  local kit, plant = roles.kit or {}, roles.plant or {}
  for _, i in ipairs(sorted_keys(items)) do
    local p = items[i].place
    if p and (kit[p] or plant[p]) and rank[i] ~= nil and rank[i] <= top then seeds[#seeds + 1] = i end
  end
  table.sort(seeds)
  for k in pairs(Mg.closure(D, seeds)) do if out[k] == nil then out[k] = "extraction" end end
  return out
end

--- Vrai si l'option `o` est gelée par le verdict `v` (Mg.step) ; exempt = Mg.exempt.
function Mg.frozen(v, o, rank, exempt)
  if not (v and v.gel) then return false end
  if o.kind ~= "chaine" or o.item == nil then return false end
  local rk = rank[o.item]
  if rk == nil or rk <= Mg.RANK_T1 then return false end
  return exempt[o.item] == nil
end

--- Cause d'un gel (refus de la capitalisation).
function Mg.cause(v)
  local w = v.short[1] or v.worst
  if not w then return "marge T0/T1 sous " .. Mg.PCT .. " %" end
  return string.format("marge T0/T1 : %s (rang %d) a %+.0f %% < %d %% (offre %.1f/min, conso %.1f/min) : foreuses et fonderies d'abord",
    w.item, w.rank, w.pct, Mg.PCT, w.supply, w.c)
end

--- Ligne de journal [FO-MARGE] (sans accents).
function Mg.format(key, minute, v, frozen_n, win_min)
  local parts = {}
  for j, r in ipairs(v.rows) do
    if j > Mg.LOG_MAX then parts[#parts + 1] = "+" .. (#v.rows - Mg.LOG_MAX) break end
    parts[#parts + 1] = string.format("%s:r%d p=%.1f c=%.1f cap=%.1f st=%d %+.0f%%", r.item, r.rank, r.p, r.c, r.cap, math.floor(r.stock),
      r.pct)
  end
  return string.format("[FO-MARGE] %s minute %d | fenetre %.1f min | gel %s | sous %d%% : %d | geles ce tour %d | [%s]", key or "?",
    minute, win_min or 0, v.gel and "OUI" or "non", Mg.PCT, #v.short, frozen_n or 0, table.concat(parts, " ; "))
end

return Mg
