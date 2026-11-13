--[[
  EMPLACEMENTS DE MODULES des fours et des machines d'assemblage du mod (s42, chantier 2.1 du DC, partie de 4 h 15 en
  0.7.96 : « les fours ajoutés par le mod n'acceptent pas les modules »).

  Règle pure sur les données finales de l'étape data (data.raw), appelée par tests/datastage/harness.lua et prouvée sur
  des tables de synthèse par tests/s42_modules-proto_test.lua.

  Pour chaque prototype « furnace » ou « assembling-machine » ABSENT de la vanilla (créé par le mod) :
    1. au moins un emplacement (module_specification.module_slots ≥ 1) ;
    2. des effets admis (allowed_effects) non vides : en 1.1, un allowed_effects absent n'admet AUCUN effet, donc aucun
       module ; un four (type « furnace ») doit admettre les quatre effets ;
    3. dans une famille à paliers (noms « préfixe-N »), le nombre d'emplacements ne décroît jamais d'un palier au suivant.
  Dispenses, toutes déclarées :
    - refus DÉCLARÉ dans le prototype : module_slots = 0 ET allowed_effects = {} posés tous les deux (chaîne du calcul,
      décision du DC « PAS de modules d'effet pour le calcul », prototypes/compute.lua et compute_v2.lua) ;
    - M.EXEMPT : nom → raison (machines qui ne produisent rien).
  Productivité (M.limitation_gaps) : recettes des catégories d'un FOUR du mod absentes de la limitation d'un module de
  productivité (en 1.1, ce module refuse toute recette hors de sa liste : l'emplacement n'y sert pas à la productivité).
]]

local M = {}

M.TYPES = { "furnace", "assembling-machine" }
M.EFFECTS = { "consumption", "speed", "productivity", "pollution" }

M.EXEMPT = {
  ["fo-vitrine-v0-cheminee-four"] = "pièce de vitrine (copie du four en acier vanilla, sans recette de construction)",
  ["fo-flare-stack"] = "puits : détruit un fluide, ne produit rien",
  ["fo-cooling-pool"] = "désactivation passive du combustible usé (source d'énergie void, prototypes/spent_fuel.lua)",
}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Ensemble des effets admis d'un prototype (allowed_effects : liste, ou un seul nom).
local function effect_set(p)
  local ae, set, n = p.allowed_effects, {}, 0
  if type(ae) == "string" then ae = { ae } end
  for _, e in ipairs(ae or {}) do
    if not set[e] then set[e] = true; n = n + 1 end
  end
  return set, n
end

local function slots_of(p)
  local ms = p.module_specification
  return ms and ms.module_slots or 0
end

--- Inventaire trié (type, puis nom) des fours et machines d'assemblage ; own = absent de la vanilla.
function M.inventory(modded, vanilla)
  local out = {}
  for _, ty in ipairs(M.TYPES) do
    for _, name in ipairs(sorted_keys(modded[ty])) do
      local p = modded[ty][name]
      local set, n = effect_set(p)
      local declared_none = slots_of(p) == 0 and p.module_specification ~= nil
        and type(p.allowed_effects) == "table" and n == 0
      out[#out + 1] = { type = ty, name = name, own = not (vanilla and vanilla[ty] and vanilla[ty][name]),
        slots = slots_of(p), effects = set, neffects = n, declared_none = declared_none }
    end
  end
  return out
end

--- Erreurs (liste de textes, ordre fixe) et compteurs { own, with_slots, declared_none, exempt }.
function M.check(modded, vanilla)
  local errs = {}
  local c = { own = 0, with_slots = 0, declared_none = 0, exempt = 0 }
  local families = {}
  for _, r in ipairs(M.inventory(modded, vanilla)) do
    if r.own then
      c.own = c.own + 1
      local key = r.type .. "/" .. r.name
      if M.EXEMPT[r.name] then
        c.exempt = c.exempt + 1
      elseif r.declared_none then
        c.declared_none = c.declared_none + 1
      elseif r.slots < 1 then
        errs[#errs + 1] = key .. " : aucun emplacement de module"
      else
        c.with_slots = c.with_slots + 1
        if r.neffects == 0 then
          errs[#errs + 1] = key .. " : " .. r.slots .. " emplacement(s) mais aucun effet admis (allowed_effects absent ou vide)"
        elseif r.type == "furnace" then
          for _, e in ipairs(M.EFFECTS) do
            if not r.effects[e] then errs[#errs + 1] = key .. " : effet « " .. e .. " » non admis" end
          end
        end
        local prefix, n = r.name:match("^(.-)%-(%d+)$")
        if prefix then
          local fkey = r.type .. "/" .. prefix
          families[fkey] = families[fkey] or {}
          table.insert(families[fkey], { n = tonumber(n), slots = r.slots })
        end
      end
    end
  end
  for _, fkey in ipairs(sorted_keys(families)) do
    local rows = families[fkey]
    table.sort(rows, function(a, b) return a.n < b.n end)
    for i = 2, #rows do
      if rows[i].slots < rows[i - 1].slots then
        errs[#errs + 1] = string.format("%s : %d emplacement(s) au palier %d, %d au palier %d (décroît)",
          fkey, rows[i - 1].slots, rows[i - 1].n, rows[i].slots, rows[i].n)
      end
    end
  end
  return errs, c
end

--- Recettes (non cachées) des catégories des FOURS du mod qui admettent la productivité, absentes de la limitation d'un
--- module de productivité. Liste triée de { recipe, category, module }, une ligne par recette (premier module fautif).
function M.limitation_gaps(modded, vanilla)
  local cats = {}
  for _, r in ipairs(M.inventory(modded, vanilla)) do
    if r.own and r.type == "furnace" and r.slots > 0 and r.effects.productivity then
      for _, cat in ipairs(modded.furnace[r.name].crafting_categories or {}) do cats[cat] = true end
    end
  end
  local mods = {}
  for _, name in ipairs(sorted_keys(modded.module)) do
    local m = modded.module[name]
    local bonus = m.effect and m.effect.productivity and m.effect.productivity.bonus or 0
    if bonus > 0 and type(m.limitation) == "table" then
      local set = {}
      for _, rn in ipairs(m.limitation) do set[rn] = true end
      mods[#mods + 1] = { name = name, set = set }
    end
  end
  local gaps = {}
  for _, rn in ipairs(sorted_keys(modded.recipe)) do
    local rec = modded.recipe[rn]
    local cat = rec.category or "crafting"
    local hidden = rec.hidden or (rec.normal and rec.normal.hidden)
    if cats[cat] and not hidden then
      for _, m in ipairs(mods) do
        if not m.set[rn] then
          gaps[#gaps + 1] = { recipe = rn, category = cat, module = m.name }
          break
        end
      end
    end
  end
  return gaps, #mods
end

return M
