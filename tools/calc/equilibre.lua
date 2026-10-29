--[[
  CALCULATEUR D'ÉQUILIBRE (piste CALCULS, nuit du 29 au 30/10). Lua 5.2 pur, depuis la racine du mod :

    lua5.2 tests/datastage/harness.lua "<racine>/data" . --dump-calc tools/calc/donnees.lua   (après tout changement
                                                         de recette, de machine ou de technologie ; environ 40 s)
    lua5.2 tools/calc/equilibre.lua                       écrit docs/CALCULS_EQUILIBRE.md (environ 2 s)
    lua5.2 tools/calc/equilibre.lua --stdout              même texte sur la sortie
    lua5.2 tools/calc/equilibre.lua --verifier            code 1 si le document n'est plus la sortie du calculateur
    lua5.2 tools/calc/equilibre.lua --donnees <fichier>   autres données (fixture)

  Tout est CALCULÉ (aucun chiffre écrit à la main) depuis les recettes finales, les prototypes des machines et des
  modules, shared/levels/config.lua, shared/content/modules.lua et shared/content/epochs.lua. Seuils des incohérences :
  Eq.SEUILS. Méthode de la matière brute : tools/calc/mu.lua (programme linéaire) ; hypothèses : tools/calc/modele.lua.
]]

package.path = "./?.lua;" .. package.path
local Mo = require("tools.calc.modele")
local Fmt = require("tools.calc.format")
local L, M, X, MU = Mo.L, Mo.M, Mo.X, Mo.MU
local num, th, pct = Fmt.num, Fmt.thousands, Fmt.pct

local Eq = {}
Eq.SEUILS = {
  value_lo = 1 / 1.5, value_hi = 1.5,  -- valeur déclarée d'une monnaie / matière brute réelle (H0)
  level_jump = 2.5,                    -- saut de valeur d'un niveau au suivant (même famille)
  crafts_per_s = 60,                   -- fabrications par seconde au plus (moteur, F199)
}
Eq.HYPS = { "H0", "H2r", "H2" }
--- Écarts de valeur VOULUS (écrits par le scénario X0) : signalés comme biais, pas comme faute.
Eq.ASSUMED = { ["fo-resonance-crystal"] = "rareté assumée par X0 (gisements rares, valeur de monnaie au-dessus du minerai)" }

local function currency_rows(D, cache)
  local rows = {}
  for e = 2, L.EPOCHS do
    local m = L.epoch_materials[e]
    local xc = X.currency_of(e)
    local mu0 = cache.mu(m.item, "H0", e)
    local mu2 = cache.mu(m.item, "H2", e)
    rows[#rows + 1] = { e = e, item = m.item, value = m.value, provisional = m.provisional, want = m.want_item,
      mu0 = mu0, mu2 = mu2, ratio = m.value / mu0, x0_item = xc and xc.item, x0_value = xc and xc.value,
      stack_l = L.stack_size[m.item], stack_d = D.stacks[m.item] }
  end
  return rows
end

--- Incohérences : liste de { gravite, texte } (gravité : « FAUX » valeur ou donnée erronée, « BIAIS », « NOTE »).
function Eq.incoherences(D, cache, cur)
  local out = {}
  local function add(g, t) out[#out + 1] = { g, t } end
  for _, r in ipairs(cur) do
    if r.mu0 == math.huge then
      add("FAUX", string.format("Époque %d : la monnaie `%s` n'a AUCUNE chaîne de fabrication dans les recettes du jeu.", r.e, r.item))
    elseif r.ratio > Eq.SEUILS.value_hi or r.ratio < Eq.SEUILS.value_lo then
      add((r.provisional or Eq.ASSUMED[r.item]) and "BIAIS" or "FAUX", string.format("Époque %d : `%s` déclarée %s u, matière brute réelle %s (rapport %s, hors de %s à %s)%s.",
        r.e, r.item, num(r.value), num(r.mu0, 2), num(r.ratio, 2), num(Eq.SEUILS.value_lo, 2), num(Eq.SEUILS.value_hi, 2),
        r.provisional and " ; monnaie provisoire" or (Eq.ASSUMED[r.item] and (" ; " .. Eq.ASSUMED[r.item]) or "")))
    end
    if r.stack_d and r.stack_l ~= r.stack_d then
      add("FAUX", string.format("Pile de `%s` : config %s, étape data %s (L.stack_size n'est plus le miroir du jeu).", r.item, tostring(r.stack_l), tostring(r.stack_d)))
    end
  end
  for _, item in ipairs(MU.sorted_keys(L.item_value)) do
    local mu0 = cache.mu(item, "H0", 1)
    local v = L.item_value[item]
    if mu0 < math.huge and (v / mu0 > Eq.SEUILS.value_hi or v / mu0 < Eq.SEUILS.value_lo) then
      local is_cur = false
      for e = 2, L.EPOCHS do if L.epoch_materials[e].item == item then is_cur = true end end
      if not is_cur then
        add("FAUX", string.format("Panier de base : `%s` vaut %s u dans L.item_value, %s en matière brute réelle.", item, num(v), num(mu0, 2)))
      end
    end
  end
  -- Détours par boucle productive (D-17) : sous H2, la chaîne d'une monnaie n'utilise plus le brut PRINCIPAL de sa
  -- chaîne H0 (exemple : uranium 238 refait de piles usées, sans minerai d'uranium). Première époque où cela arrive.
  local function main_raw(x)
    local best, bv
    for _, rn in ipairs(MU.sorted_keys(x)) do
      local r = x[rn]
      if r.recipe.c > 0 then
        local v = r.runs * r.recipe.c
        if not bv or v > bv + 1e-12 then best, bv = rn, v end
      end
    end
    return best
  end
  local loop_items, seen_li = {}, {}
  for _, r in ipairs(cur) do
    if not seen_li[r.item] then seen_li[r.item] = true; loop_items[#loop_items + 1] = r.item end
  end
  if not seen_li["uranium-235"] then loop_items[#loop_items + 1] = "uranium-235" end
  for _, item in ipairs(loop_items) do
    local _, x0 = cache.mu(item, "H0", 1)
    local raw0 = main_raw(x0)
    for e = 1, L.EPOCHS do
      local mu2, x2 = cache.mu(item, "H2", e)
      if raw0 and mu2 < math.huge and not x2[raw0] then
        local rs = {}
        for _, rn in ipairs(MU.sorted_keys(x2)) do rs[#rs + 1] = rn end
        local loop = MU.cycle(x2)
        if loop then
          add("FAUX", string.format("Boucle productive : dès l'époque %d (modules de productivité de l'époque), `%s` se fabrique SANS `%s` (brut principal de sa chaîne H0) en faisant tourner un CYCLE (%s), pour %s MU au lieu de %s. Chaîne : %s.",
            e, item, (raw0:gsub("^gisement:", "")), table.concat(loop, " → "), Fmt.small(mu2), num((cache.mu(item, "H0", 1)), 2), table.concat(rs, ", ")))
        else
          add("NOTE", string.format("Détour : dès l'époque %d, la chaîne la moins chère de `%s` sous H2 abandonne `%s` (brut principal de H0) : %s.",
            e, item, (raw0:gsub("^gisement:", "")), table.concat(rs, ", ")))
        end
        break
      end
    end
  end
  -- Machines des niveaux : vitesse, cases et emprise lues dans l'étape data contre la config.
  local VAN = { drill = { "mining_speed", "mining_speed" }, furnace = { "crafting_speed", "crafting_speed" },
    assembler = { "crafting_speed", "crafting_speed" } }
  for _, fk in ipairs({ "drill", "furnace", "assembler" }) do
    local f = L.by_key[fk]
    local base = D.machines[f.base]
    for n = 1, f.max do
      local m = D.machines[L.name(f, n)]
      if not m then
        add("FAUX", "Machine absente de l'étape data : " .. L.name(f, n))
      else
        local st
        for _, s in ipairs(f.stats) do if s.path[#s.path] == VAN[fk][1] then st = s end end
        local want = L.apply_stat(st, base[VAN[fk][2]], n)
        local got = m[VAN[fk][2]]
        if math.abs(want - got) > 0.006 then
          add("FAUX", string.format("%s : vitesse %s en jeu, %s par la config.", L.name(f, n), num(got, 3), num(want, 3)))
        end
        local slots = L.module_slots(f, n) or 0
        if (m.module_slots or 0) ~= slots then
          add("FAUX", string.format("%s : %d cases de module en jeu, %d par la config.", L.name(f, n), m.module_slots or 0, slots))
        end
        if m.side ~= L.footprint(f, n) then
          add("FAUX", string.format("%s : emprise %s en jeu, %s par la config.", L.name(f, n), tostring(m.side), tostring(L.footprint(f, n))))
        end
      end
    end
  end
  -- Sauts de valeur d'un niveau au suivant.
  for _, f in ipairs(L.families) do
    local prev
    for n = 2, f.max do
      local v = L.cost_value(L.cost(f, n))
      if prev and v / prev > Eq.SEUILS.level_jump then
        add("BIAIS", string.format("%s : le niveau %d coûte × %s du niveau %d (%s → %s u).", f.key, n, num(v / prev, 2), n - 1, th(prev), th(v)))
      end
      prev = v
    end
  end
  -- Plafond × 328,67 et 60 fabrications par seconde.
  for _, fk in ipairs({ "assembler", "drill" }) do
    local f = L.by_key[fk]
    for e = 1, L.EPOCHS do
      local kp = Mo.tier_available("productivity", e)
      local n = math.min(f.max, 2 * e)
      local slots = L.module_slots(f, n)
      if kp and M.mult.over_cap((function()
        local l = {}
        for _ = 1, slots do l[#l + 1] = M.cents("productivity", kp).productivity end
        return l
      end)()) then
        add("NOTE", string.format("%s niveau %d (époque %d) : %d modules de productivité palier %d dépassent le plafond × 328,67 du moteur (cases perdues).", fk, n, e, slots, kp))
        break
      end
    end
  end
  local fast = {}
  for e = 1, L.EPOCHS do
    local ks = Mo.tier_available("speed", e)
    local mach = Mo.machine_for(D, "crafting", e)
    local sp = mach.speed * Mo.full_factors("speed", ks, mach.slots).speed
    local cnt = 0
    for _, rn in ipairs(MU.sorted_keys(D.recipes)) do
      local r = D.recipes[rn]
      if Mo.FAMILY_OF_CATEGORY[r.category] == "assembler" and not MU.excluded(rn) and (r.energy or 0.5) > 0
        and sp / (r.energy or 0.5) > Eq.SEUILS.crafts_per_s then cnt = cnt + 1 end
    end
    if cnt > 0 then fast[#fast + 1] = string.format("époque %d : %d", e, cnt) end
  end
  if #fast > 0 then
    add("NOTE", "Recettes d'assembleur qui dépasseraient 60 fabrications/s (le moteur bride) avec la machine de l'époque pleine de modules de vitesse : " .. table.concat(fast, " ; ") .. ".")
  end
  -- Objets inaccessibles.
  local G = cache.graph("H0", 1)
  local unreachable = {}
  local produced = {}
  for _, x in ipairs(G.recipes) do
    if not x.name:find(":") then for n in pairs(x.outs) do produced[n] = true end end
  end
  for _, n in ipairs(MU.sorted_keys(produced)) do
    if cache.mu(n, "H0", 1) == math.huge then unreachable[#unreachable + 1] = "`" .. n .. "`" end
  end
  if #unreachable > 0 then
    add("FAUX", string.format("%d objet(s) produits par une recette mais sans chaîne depuis les gisements : %s.", #unreachable, table.concat(unreachable, ", ")))
  end
  if #G.orphans > 0 then
    add("NOTE", "Bruts sans gisement ni recette (comptés 1 MU) : " .. table.concat(G.orphans, ", ") .. ".")
  end
  return out
end

local function family_name(k)
  return ({ command = "Centre", gun = "Mitrailleuse", laser = "Laser", wall = "Mur", drill = "Foreuse",
    furnace = "Four", assembler = "Assembleur" })[k]
end

function Eq.render(D)
  local cache = Mo.new_cache(D)
  local P = Fmt.printer()
  local p = P.p
  local cur = currency_rows(D, cache)
  local inc = Eq.incoherences(D, cache, cur)

  p("# Calculs d'équilibre (généré)")
  p("")
  p("> **Document GÉNÉRÉ** par `lua5.2 tools/calc/equilibre.lua` (piste CALCULS). Ne pas éditer : relancer le calculateur.")
  p("> Données : `tools/calc/donnees.lua` (`harness.lua --dump-calc`, étape data FINALE vanilla 1.1.91 + mod), `shared/levels/config.lua`,")
  p("> `shared/content/modules.lua` (barème D-17), `shared/content/epochs.lua` (calendrier X0). Contrôlé par `lua5.2 tests/calc_test.lua`.")
  p("")
  p("## 0. Méthode et hypothèses")
  p("")
  p("- **Matière brute (MU)** : coût minimal, en minerai extrait, d'une unité nette de l'objet (programme linéaire sur TOUTES les recettes du jeu :")
  p("  sous-produits jetés s'ils ne servent pas, boucles comprises : Kovarex, chlore du titane, craquage). 1 minerai solide = 1 MU, 10 unités de")
  p("  fluide de gisement = 1 MU, eau et vapeur gratuites ; l'uranium consomme 1 acide sulfurique par minerai.")
  p("- **Hypothèses de modules** (machines au niveau maximal de l'époque, 2e ; meilleur palier dont la recette est rangée à l'époque, `X.base_recipe_epochs`) :")
  p("  - **H0** : aucun module (c'est le modèle actuel de `levels_test --tables` et de `--calibrate`) ;")
  p("  - **H1** : modules de vitesse dans toutes les cases (ne change que le nombre de machines) ;")
  p("  - **H2r** : modules de productivité dans toutes les cases des machines qui les admettent (limitation du jeu), foreuses EXCLUES ;")
  p("  - **H2** : comme H2r, foreuses comprises (le minerai lui-même est multiplié).")
  p("- Fusion : four en acier de la famille, sans case : jamais de module (le four électrique vanilla, 2 cases, n'est pas compté).")
  p("- Recherche de productivité minière vanilla, balises et bonus d'équipe : NON comptés.")
  p("")

  p("## 1. Incohérences relevées (" .. #inc .. ")")
  p("")
  p("| Gravité | Constat |")
  p("|---|---|")
  for _, r in ipairs(inc) do p(string.format("| %s | %s |", r[1], r[2])) end
  p("")

  p("## 2. Monnaies d'époque : valeur déclarée contre matière brute réelle")
  p("")
  p("| Époque | Objet en jeu | Valeur déclarée (u) | MU réelle H0 | Déclarée / réelle | MU réelle H2 (modules de l'époque) | Gain H2 | Monnaie X0 (papier) | Valeur X0 |")
  p("|---|---|---|---|---|---|---|---|---|")
  for _, r in ipairs(cur) do
    p(string.format("| %d | `%s`%s | %s | %s | %s | %s | × %s | %s | %s |", r.e, r.item, r.provisional and " (provisoire)" or "", num(r.value),
      num(r.mu0, 2), num(r.ratio, 2), Fmt.small(r.mu2), Fmt.big(r.mu0 / r.mu2),
      r.x0_item == r.item and "même" or ("`" .. tostring(r.x0_item) .. "`" .. (D.stacks[r.x0_item] and "" or " (absent du jeu)")),
      num(r.x0_value)))
  end
  p("")
  p("Paniers de base (L.item_value) :")
  p("")
  p("| Objet | Valeur déclarée | MU réelle H0 |")
  p("|---|---|---|")
  for _, item in ipairs({ "iron-plate", "copper-plate", "stone-brick", "iron-gear-wheel", "electronic-circuit" }) do
    p(string.format("| `%s` | %s | %s |", item, num(L.item_value[item]), num(cache.mu(item, "H0", 1), 2)))
  end
  p("")

  p("## 3. Machines des niveaux : vitesse, emprise, cases et modules (barème D-17, multiplication, plafond × 328,67)")
  p("")
  for _, fk in ipairs({ "assembler", "furnace", "drill" }) do
    local f = L.by_key[fk]
    p("### " .. family_name(fk))
    p("")
    p("| Niveau | Époque | Vitesse | Côté | Vitesse / tuile | Cases | Palier dispo. | × vitesse (H1) | Vitesse / tuile H1 | × productivité (H2) | × sortie (H2) |")
    p("|---|---|---|---|---|---|---|---|---|---|---|")
    for n = 1, f.max do
      local m = D.machines[L.name(f, n)]
      local e = L.epoch_of(f, n)
      local sp = m.crafting_speed or m.mining_speed
      local ks, kp = Mo.tier_available("speed", e), Mo.tier_available("productivity", e)
      local fs = Mo.full_factors("speed", ks, m.module_slots)
      local fp = Mo.full_factors("productivity", kp, m.module_slots)
      p(string.format("| %d | %d | %s | %d | %s | %d | %s | %s | %s | %s | %s |", n, e, num(sp, 3), m.side, num(sp / (m.side * m.side), 3),
        m.module_slots or 0, ks and (ks .. " / " .. kp) or "—", num(fs.speed, 2), num(sp * fs.speed / (m.side * m.side), 3),
        num(fp.prod, 2), num(fp.prod * fp.speed, 2)))
    end
    p("")
  end

  p("## 4. Chaînes : machines pour 1 monnaie par seconde, machines de l'époque")
  p("")
  p("| Époque | Monnaie | Machines H0 | Tuiles H0 | Machines H1 (vitesse) | Tuiles H1 | Machines H2 | Tuiles H2 | Fluides de gisement H0 (u/s) | Machines H0 (détail) |")
  p("|---|---|---|---|---|---|---|---|---|---|")
  for _, r in ipairs(cur) do
    local e = r.e
    local _, x0 = cache.mu(r.item, "H0", e)
    local _, x2 = cache.mu(r.item, "H2", e)
    if r.mu0 < math.huge then
      local l0, t0, fl = Mo.chain_machines(D, x0, e)
      local l1, t1 = Mo.chain_machines(D, x0, e, { speed_tier = Mo.tier_available("speed", e) })
      local l2, t2 = Mo.chain_machines(D, x2, e, { prod_tier = Mo.tier_available("productivity", e) })
      local function total(l) local s = 0 for _, b in ipairs(l) do s = s + b.count end return s end
      local det = {}
      for _, b in ipairs(l0) do det[#det + 1] = string.format("%s %s", num(b.count, 2), b.machine) end
      local fls = {}
      for _, k in ipairs(MU.sorted_keys(fl)) do fls[#fls + 1] = k .. " " .. num(fl[k], 1) end
      p(string.format("| %d | `%s` | %s | %s | %s | %s | %s | %s | %s | %s |", e, r.item, num(total(l0), 1), num(t0, 0), num(total(l1), 1),
        num(t1, 0), num(total(l2), 1), num(t2, 0), #fls > 0 and table.concat(fls, ", ") or "—", table.concat(det, ", ")))
    end
  end
  p("")

  -- 5. Coûts des niveaux
  p("## 5. Coût de chaque niveau : valeur déclarée, matière brute réelle H0 et H2")
  p("")
  p("Valeur déclarée : `L.cost_value` (ce que compte le calendrier). Réelle : quantités × MU réelle de chaque objet, à l'époque où l'on paie.")
  p("")
  local real0, real2 = Mo.real_value_fn(cache, "H0"), Mo.real_value_fn(cache, "H2")
  for _, f in ipairs(L.families) do
    p("### " .. family_name(f.key))
    p("")
    p("| Niveau | Payé à l'époque | Coût | Déclaré (u) | × préc. | Réel H0 (MU) | Réel H0 / déclaré | Réel H2 (MU) | Cases / moitié du coffre |")
    p("|---|---|---|---|---|---|---|---|---|")
    local prev
    for n = 2, f.max do
      local c = L.cost(f, n)
      local e = math.max(1, L.pay_epoch(f, n))
      local v = L.cost_value(c)
      local r0, r2 = real0(c, e), real2(c, e)
      local parts = {}
      for _, x in ipairs(c) do parts[#parts + 1] = th(x[2]) .. " " .. x[1] end
      local payer = L.payer_cc(f, n)
      p(string.format("| %d | %d | %s | %s | %s | %s | %s | %s | %d / %d |", n, e, table.concat(parts, ", "), th(v),
        prev and num(v / prev, 2) or "—", th(r0), num(r0 / v, 2), th(r2), L.cost_slots(c), math.floor(L.chest_slots(math.max(1, payer)) * L.MAX_SLOT_SHARE)))
      prev = v
    end
    p("")
  end

  -- 6. Calendrier
  p("## 6. Calendrier : durée impliquée par époque selon l'hypothèse de modules")
  p("")
  p("Même modèle que `levels_test --tables` (base de référence `L.target.base`, 30 % de la production X0 aux niveaux) ; seule la valeur des")
  p("coûts change : déclarée, puis matière brute réelle sous H0, H2r, H2.")
  p("")
  p("| Époque | Durée X0 | Dépense déclarée (u) | Impliquée (déclarée) | Dépense réelle H0 | Impliquée H0 | Dépense réelle H2r | Impliquée H2r | Dépense réelle H2 | Impliquée H2 |")
  p("|---|---|---|---|---|---|---|---|---|---|")
  local tot = { d = 0, h0 = 0, h2r = 0, h2 = 0 }
  local rows6 = {}
  for e = 1, L.EPOCHS do
    local sd = Mo.spend(e, function(c) return L.cost_value(c) end)
    local s0 = Mo.spend(e, real0)
    local s2r = Mo.spend(e, Mo.real_value_fn(cache, "H2r"))
    local s2 = Mo.spend(e, real2)
    local hd, h0, h2r, h2 = Mo.implied_hours(e, sd), Mo.implied_hours(e, s0), Mo.implied_hours(e, s2r), Mo.implied_hours(e, s2)
    tot.d, tot.h0, tot.h2r, tot.h2 = tot.d + hd, tot.h0 + h0, tot.h2r + h2r, tot.h2 + h2
    rows6[e] = { sd = sd, s0 = s0, s2 = s2, s2r = s2r }
    p(string.format("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |", e, Fmt.hours(L.target.epoch_hours(e)), th(sd), Fmt.hours(hd), th(s0),
      Fmt.hours(h0), th(s2r), Fmt.hours(h2r), th(s2), Fmt.hours(h2)))
  end
  local cal = 0
  for e = 1, L.EPOCHS do cal = cal + L.target.epoch_hours(e) end
  p(string.format("| **Total** | **%s** | | **%s** | | **%s** | | **%s** | | **%s** |", Fmt.hours(cal), Fmt.hours(tot.d), Fmt.hours(tot.h0), Fmt.hours(tot.h2r), Fmt.hours(tot.h2)))
  p("")

  -- 7. Recherche
  p("## 7. Recherche par époque (coûts FINAUX de l'étape data)")
  p("")
  p("Époque d'une technologie : règle QX9 de la config (`L.vanilla_tech_epoch`), relevée au maximum de ses prérequis. Packs valorisés en MU réelle H0.")
  p("")
  p("| Époque | Technologies | Unités | Temps de labo (labo-heures, vitesse 1) | Packs (MU) | Budget X0 de l'époque (u) | Packs / budget | Visée X0 : 35 % |")
  p("|---|---|---|---|---|---|---|---|")
  local tep = Mo.tech_epochs(D)
  local acc = {}
  for _, name in ipairs(MU.sorted_keys(D.techs)) do
    local t = D.techs[name]
    if t.enabled ~= false and not name:match("^fo%-epoch%-") then
      local e = tep[name]
      local a = acc[e] or { n = 0, units = 0, secs = 0, mu = 0 }
      a.n = a.n + 1
      a.units = a.units + t.count
      a.secs = a.secs + t.count * (t.time or 0)
      for _, i in ipairs(t.ingredients or {}) do a.mu = a.mu + t.count * i[2] * cache.mu(i[1], "H0", e) end
      acc[e] = a
    end
  end
  for e = 1, L.EPOCHS do
    local a = acc[e] or { n = 0, units = 0, secs = 0, mu = 0 }
    local b = L.target.budget(e)
    p(string.format("| %d | %d | %s | %s | %s | %s | %s | %s |", e, a.n, th(a.units), num(a.secs / 3600, 1), th(a.mu), th(b),
      pct(a.mu / b), (a.mu / b > 0.35 * 1.5 or a.mu / b < 0.35 / 3) and "**écart**" or "dans la fourchette"))
  end
  p("")

  -- 8. Proposition
  p("## 8. Proposition de courbe des 15 époques (NON appliquée : à trancher par le Directeur Créatif, Q-CALC-1)")
  p("")
  p("Trois voies, chiffrées sur le même modèle :")
  p("")
  p("- **(A) Suivre la productivité réelle** : multiplier la valeur d'époque par le gain H2 des monnaies de l'époque, pour que la durée")
  p("  impliquée sous H2 retombe sur le calendrier X0 (coûts affichés × le gain).")
  p("- **(B) Garder les coûts** : la partie raccourcit sous H2 (colonne « Impliquée H2 » du §6).")
  p("- **(C) Exclure les monnaies d'époque de la productivité** (limitation des modules) : la durée revient vers H0 ; la productivité ne sert")
  p("  plus qu'à l'usine (recherche, munitions, paniers de base).")
  p("")
  p("| Époque | value_mult actuel | cc_value actuel | Rapport réel H0 / déclaré | Gain H2 (dépense) | value_mult (A) | cc_value (A) | Valeur de monnaie proposée (MU réelle arrondie) |")
  p("|---|---|---|---|---|---|---|---|")
  for e = 1, L.EPOCHS do
    local ep = L.epochs[e]
    local r = rows6[e]
    local g = r.s0 / r.s2
    local m = L.epoch_materials[e]
    local prop = "—"
    if m then
      local mu0 = cache.mu(m.item, "H0", e)
      prop = mu0 < math.huge and Fmt.nice(mu0) or "—"
    end
    p(string.format("| %d | %s | %s | %s | × %s | %s | %s | %s |", e, num(ep.value_mult), th(ep.cc_value), num(r.s0 / r.sd, 2), Fmt.big(g),
      Fmt.bignum(Fmt.nice(ep.value_mult * g), 1), Fmt.bignum(Fmt.nice(ep.cc_value * g)), type(prop) == "number" and num(prop, 1) or prop))
  end
  p("")
  p("Lecture : sous H2, l'époque e est payée « Gain H2 » fois plus vite qu'en H0 ; (A) remet chaque époque à sa durée X0 en multipliant")
  p("valeur d'époque et passage du centre par ce gain (les quantités affichées grandissent d'autant : la règle de place du coffre est alors")
  p("à revérifier, `levels_test`). La dernière colonne aligne la valeur déclarée des monnaies sur leur coût réel (règle du modèle : « valeur")
  p("de l'objet en unités de matière brute ») ; elle ne change ni `value_mult` ni le calendrier, seulement les QUANTITÉS demandées.")
  return P.text()
end

local function main(args)
  local donnees, out, mode = "tools/calc/donnees.lua", "docs/CALCULS_EQUILIBRE.md", "write"
  local i = 1
  while args[i] do
    local a = args[i]
    if a == "--donnees" then donnees = args[i + 1]; i = i + 1
    elseif a == "--sortie" then out = args[i + 1]; i = i + 1
    elseif a == "--stdout" then mode = "stdout"
    elseif a == "--verifier" then mode = "check" end
    i = i + 1
  end
  local D = dofile(donnees)
  local text = Eq.render(D)
  if mode == "stdout" then io.write(text); return 0 end
  if mode == "check" then
    local fh = io.open(out, "rb")
    local old = fh and fh:read("*a") or ""
    if fh then fh:close() end
    if old ~= text then print("[CALC] " .. out .. " n'est plus la sortie du calculateur : relancer `lua5.2 tools/calc/equilibre.lua`"); return 1 end
    print("[CALC] " .. out .. " : à jour")
    return 0
  end
  local fh = assert(io.open(out, "wb"))
  fh:write(text)
  fh:close()
  print("[CALC] écrit : " .. out)
  return 0
end

if arg and arg[0] and arg[0]:match("equilibre%.lua$") then
  os.exit(main(arg))
end
return Eq
