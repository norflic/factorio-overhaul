-- Scénario greffé du lot RB-0 (31/10), essai E7 : changer la recette d'une usine par script (la « file » du plan) :
-- que rend `set_recipe`, que garde la machine, que perd-on ? (PLAN.md §3 ; F219, F221)
-- À LANCER SUR LA COPIE JETABLE : banc.py ... --qui RB0 -- 1000 rb0-file <copie>
--
-- Chaque cas : on compte tous les objets de la machine (entrées, sorties) + le dictionnaire rendu par set_recipe, avant et
-- après ; l'écart est la PERTE. Cas :
--   f1 recette A (10 fer -> kit), 100 fer, kit en sortie et fabrication suivante en cours (tick 180), -> recette B (cuivre) ;
--   f2 changement à mi-fabrication de la première pièce, sortie vide (ingrédients déjà prélevés), tick 60 ;
--   f3 A -> A (même recette) ; f4 A -> nil ; f5 recette « grand » (200 pierres, 400 fer) chargée, -> A ;
--   f6 deux modules de vitesse dans la machine : restent-ils ? ; f7 rotation A -> B -> A -> B toutes les 300 ticks (une fabrication dure 120 ticks ; les bras mettent 260 ticks à livrer 10 plaques, d'où une avance de 30 fer et 20 cuivre) avec
--   bras d'entrée (coffre) et de sortie (coffre) : kits produits, objets rendus, rien de perdu à la fin (bilan du coffre).
-- Le script remet dans le coffre ce que set_recipe rend (comme le fera usine.lua).

local C = require("scenarios/rb0_common")

local X0, Y0 = 7000, 7000
local MY = Y0 + 0.5
local CHECK = 1250
local CAS = {}

local function inventaire(m)
  local tot = {}
  for _, id in ipairs({ defines.inventory.assembling_machine_input, defines.inventory.assembling_machine_output,
    defines.inventory.assembling_machine_modules }) do
    local inv = m.get_inventory(id)
    if inv then
      for nom, n in pairs(inv.get_contents()) do tot[nom] = (tot[nom] or 0) + n end
    end
  end
  return tot
end

local function fusion(a, b)
  local r = {}
  for k, v in pairs(a) do r[k] = (r[k] or 0) + v end
  for k, v in pairs(b or {}) do r[k] = (r[k] or 0) + v end
  return r
end

local function ecart(avant, apres)
  local noms, d = {}, {}
  for k in pairs(avant) do noms[k] = true end
  for k in pairs(apres) do noms[k] = true end
  local liste = {}
  for k in pairs(noms) do liste[#liste + 1] = k end
  table.sort(liste)
  for _, k in ipairs(liste) do
    local x = (apres[k] or 0) - (avant[k] or 0)
    if x ~= 0 then d[#d + 1] = k .. ":" .. x end
  end
  return #d == 0 and "aucun" or table.concat(d, ",")
end

local function dict(t)
  local l = {}
  for k, v in pairs(t or {}) do l[#l + 1] = k .. "=" .. v end
  table.sort(l)
  return #l == 0 and "{}" or "{" .. table.concat(l, ",") .. "}"
end

return {
  description = "RB-0 E7 : set_recipe de l'usine (file de fabrication) : ce qui est rendu, ce qui reste, ce qui est perdu",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    if not C.exige(ctx, { "rb0-atelier", "rb0-kit-a", "rb0-kit-b-cu", "rb0-kit-grand", "rb0-kit", "rb0-kit-b" }, "atelier, 3 recettes") then return end
    local s = ctx.surface()
    C.pave(ctx, X0 - 4, Y0 - 12, X0 + 100, Y0 + 24)
    C.sans_ennemis(s, X0 - 8, Y0 - 16, X0 + 104, Y0 + 28)
    ctx.power(X0 + 40, Y0)
    st.cas = {}
    local function nouveau(id, i, recette)
      local m = s.create_entity({ name = "rb0-atelier", position = { X0 + 5.5 + 8 * (i - 1), MY }, force = "player" })
      m.set_recipe(recette)
      local c = { id = id, e = m, recette = recette }
      st.cas[#st.cas + 1] = c
      return c, m
    end
    local c1, m1 = nouveau("f1", 1, "rb0-kit-a")
    m1.insert({ name = "iron-plate", count = 100 })
    local c2, m2 = nouveau("f2", 2, "rb0-kit-a")
    m2.insert({ name = "iron-plate", count = 100 })
    local c3, m3 = nouveau("f3", 3, "rb0-kit-a")
    m3.insert({ name = "iron-plate", count = 100 })
    local c4, m4 = nouveau("f4", 4, "rb0-kit-a")
    m4.insert({ name = "iron-plate", count = 100 })
    local c5, m5 = nouveau("f5", 5, "rb0-kit-grand")
    m5.insert({ name = "stone", count = 300 })
    m5.insert({ name = "iron-plate", count = 500 })
    local c6, m6 = nouveau("f6", 6, "rb0-kit-a")
    m6.insert({ name = "iron-plate", count = 100 })
    m6.get_module_inventory().insert({ name = "speed-module", count = 2 })
    -- f7 : rotation avec bras
    local c7, m7 = nouveau("f7", 8, "rb0-kit-a")
    m7.insert({ name = "iron-plate", count = 30 })
    local x7 = X0 + 5.5 + 8 * 7
    local coffre_e = s.create_entity({ name = "steel-chest", position = { x7, MY - 3 }, force = "player" })
    coffre_e.insert({ name = "iron-plate", count = 400 })
    coffre_e.insert({ name = "copper-plate", count = 400 })
    coffre_e.insert({ name = "stone", count = 100 })
    local bras_e = s.create_entity({ name = "fast-inserter", position = { x7, MY - 2 }, force = "player" })
    bras_e.pickup_position = { x7, MY - 3 }
    bras_e.drop_position = { x7, MY - 1 }
    local coffre_s = s.create_entity({ name = "steel-chest", position = { x7, MY + 3 }, force = "player" })
    local bras_s = s.create_entity({ name = "fast-inserter", position = { x7, MY + 2 }, force = "player" })
    bras_s.pickup_position = { x7, MY + 1 }
    bras_s.drop_position = { x7, MY + 3 }
    bras_e.destroy() -- pas de bras d'entrée : le script remplit seul (bilan exact, aucun objet en main de bras)
    c7.entree, c7.sortie = coffre_e, coffre_s
    c7.initial = { ["iron-plate"] = 430, ["copper-plate"] = 400, ["stone"] = 100 }
    c7.rendus = {}
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    local f = {}
    for _, c in ipairs(st.cas) do f[c.id] = c end
    -- f1 : changement à t = 180 (kit en sortie, nouvelle fabrication entamée)
    local function change(c, recette, t_log)
      if not (c.e and c.e.valid) then return end
      local avant = inventaire(c.e)
      local prog = c.e.crafting_progress
      local ok, rendu = pcall(function() return c.e.set_recipe(recette) end)
      if not ok then
        c.res = "ERREUR " .. tostring(rendu)
        return
      end
      local apres = inventaire(c.e)
      local total_apres = fusion(apres, rendu)
      c.res = string.format("progres avant=%.2f ; avant=%s ; rendu=%s ; apres=%s ; bilan(apres + rendu - avant ; + = rembourse, - = perdu)=%s ; recette lue=%s ; progres apres=%.2f ; statut=%s",
        prog, dict(avant), dict(rendu), dict(apres), ecart(avant, total_apres), c.e.get_recipe() and c.e.get_recipe().name or "nil", c.e.crafting_progress, C.statut(c.e))
      c.perte = ecart(avant, total_apres)
    end
    if t == 180 then change(f.f1, "rb0-kit-b-cu") end
    if t == 60 then change(f.f2, "rb0-kit-b-cu") end -- progrès attendu ~0,5, sortie vide
    if t == 180 then change(f.f3, "rb0-kit-a") end
    if t == 180 then change(f.f4, nil) end
    if t == 120 then change(f.f5, "rb0-kit-a") end
    if t == 180 then change(f.f6, "rb0-kit-b-cu") end
    -- f7 : rotation
    local c7 = f.f7
    if c7 and c7.e and c7.e.valid and t >= 300 and t % 300 == 0 and t <= 900 then
      local k = math.floor(t / 300) % 2
      local cible = k == 1 and "rb0-kit-b-cu" or "rb0-kit-a"
      local avant = inventaire(c7.e)
      local rendu = c7.e.set_recipe(cible)
      local rem = 0
      for nom, n in pairs(rendu) do
        rem = rem + c7.entree.insert({ name = nom, count = n })
        c7.rendus[nom] = (c7.rendus[nom] or 0) + n
      end
      -- le script (comme usine.lua) remplit la machine de la nouvelle recette depuis le coffre : 3 fabrications
      local besoin = k == 1 and { { "copper-plate", 18 }, { "stone", 9 } } or { { "iron-plate", 30 } }
      local mis = {}
      for _, b in ipairs(besoin) do
        local pris = c7.entree.get_inventory(defines.inventory.chest).remove({ name = b[1], count = b[2] })
        local ok = c7.e.insert({ name = b[1], count = pris })
        mis[#mis + 1] = b[1] .. ":" .. pris .. "->" .. ok
      end
      log(string.format("[FO-RB0-FILE] E7 f7 changement t=%d vers %s : avant=%s ; rendu=%s ; mis en machine %s ; kits au coffre de sortie A=%d B=%d", t, cible,
        dict(avant), dict(rendu), table.concat(mis, " "), c7.sortie.get_item_count("rb0-kit"), c7.sortie.get_item_count("rb0-kit-b")))
      c7.n_rot = (c7.n_rot or 0) + 1
      c7.remis = (c7.remis or 0) + rem
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local f = {}
    for _, c in ipairs(st.cas) do f[c.id] = c end
    for _, id in ipairs({ "f1", "f2", "f3", "f4", "f5", "f6" }) do
      ctx.log("E7 " .. id .. " (" .. f[id].recette .. ") : " .. tostring(f[id].res))
    end
    ctx.check(not tostring(f.f1.perte):find(":-", 1, true), "E7 f1 changement A -> B avec kit en sortie : rien de perdu", tostring(f.f1.perte))
    ctx.check(not tostring(f.f2.perte):find(":-", 1, true), "E7 f2 changement en cours de fabrication : rien de perdu", tostring(f.f2.perte))
    ctx.check(not tostring(f.f5.perte):find(":-", 1, true), "E7 f5 recette a ingredients au-dela d'une pile -> A : rien de perdu", tostring(f.f5.perte))
    -- f6 : modules
    local mods = f.f6.e.get_module_inventory().get_item_count("speed-module")
    ctx.log("E7 f6 modules de vitesse restants dans la machine : " .. mods)
    ctx.check(mods == 2, "E7 f6 les modules restent apres set_recipe", tostring(mods))
    -- f7 : bilan
    local c7 = f.f7
    local e, s_ = c7.entree, c7.sortie
    local ent = { ["iron-plate"] = e.get_item_count("iron-plate"), ["copper-plate"] = e.get_item_count("copper-plate"), ["stone"] = e.get_item_count("stone") }
    local mach = inventaire(c7.e)
    local ka, kb = s_.get_item_count("rb0-kit"), s_.get_item_count("rb0-kit-b")
    local fer_total = ent["iron-plate"] + (mach["iron-plate"] or 0) + 10 * (ka + (mach["rb0-kit"] or 0))
    local cu_total = ent["copper-plate"] + (mach["copper-plate"] or 0) + 6 * (kb + (mach["rb0-kit-b"] or 0))
    local pierre_total = ent["stone"] + (mach["stone"] or 0) + 3 * (kb + (mach["rb0-kit-b"] or 0))
    ctx.log(string.format("E7 f7 : %d changements ; rendu cumule=%s ; remis au coffre=%s ; coffre entree=%s ; machine=%s ; kits A=%d B=%d (sortie) ; " ..
      "fer total (coffre+machine+10*kitsA)=%d/430 ; cuivre (coffre+machine+6*kitsB)=%d/400 ; pierre (coffre+machine+3*kitsB)=%d/100",
      c7.n_rot or 0, dict(c7.rendus), tostring(c7.remis), dict(ent), dict(mach), ka, kb, fer_total, cu_total, pierre_total))
    ctx.log("E7 f7 ecart : fer " .. (430 - fer_total) .. " ; cuivre " .. (400 - cu_total) .. " ; pierre " .. (100 - pierre_total) ..
      " (positif = en cours de fabrication a l'instant du bilan, ou perdu)")
    ctx.check(ka + kb >= 3, "E7 f7 la rotation produit des kits des deux recettes", string.format("A=%d B=%d", ka, kb))
  end,
}
