--[[
  Lot PLANDIR : migration des bras de la centrale (shared/team/bras_retour.lua, script/team/plant_arms.lua).
  Les versions 0.6.5 à 0.6.7 passaient les bras de la centrale à l'électrique ; ce banc reproduit CET état dans la partie du guide
  (graine 123456789 : premier courant de votre équipe vers 8 min) au premier courant, par le remote de banc
  fo-ia1d.legacy_electric_arms (même remplacement sur place que l'ancien code, entrées marquées was_burner), puis lit :
    - juste après : les bras de la centrale sont ÉLECTRIQUES (l'état hérité existe) ;
    - 30 s à 1 min plus tard : tous repassés à combustion aux mêmes positions, le bras d'un autre module jamais touché ;
    - la centrale produit encore du courant ensuite.
  Limite assumée : une vraie sauvegarde 0.6.7 ne peut pas porter ce plan à 0 tick (la création n'avance pas la partie) ; l'état
  hérité est donc reproduit par le remote de banc, avec le code de conversion de 0.6.7.
  Lancement : banc.py --out <archive> --graine 123456789 --qui PLANDIR -- 36000 plandir-retour <source>
  Journal : [FO-PLANDIR-RETOUR].
]]

local base = require("scenarios/verif_guide_common")(30)
local TAG = "[FO-PLANDIR-RETOUR] "
local BURNER, ELECTRIC = "burner-inserter", "inserter"
local init0, tick0 = base.init, base.tick

base.description = "PLANDIR : migration des bras de centrale electriques (0.6.7) vers la combustion"
base.check_tick = 36000

base.init = function(ctx)
  local a = ctx.call("war_setting", "fo-war-ia3e", true)
  ctx.check(a == true, "reglage fo-war-ia3e allume", tostring(a))
  local b = ctx.call("war_setting", "fo-war-capi", true)
  ctx.check(b == true, "reglage fo-war-capi allume", tostring(b))
  if init0 then init0(ctx) end
end

local function plant_power(s)
  local kw, n = 0, 0
  for _, g in ipairs(s.find_entities_filtered({ type = "generator", force = "player" })) do
    n = n + 1
    kw = kw + (g.energy_generated_last_tick or 0)
  end
  return kw, n
end

--- Bras (nom, position) à moins de 14 tuiles d'une machine à vapeur de votre équipe.
local function plant_arms(s)
  local out = {}
  local gens = s.find_entities_filtered({ type = "generator", force = "player" })
  if #gens == 0 then return out end
  local seen = {}
  for _, g in ipairs(gens) do
    for _, a in ipairs(s.find_entities_filtered({ type = "inserter", force = "player",
      area = { { g.position.x - 14, g.position.y - 14 }, { g.position.x + 14, g.position.y + 14 } } })) do
      local k = string.format("%.1f:%.1f", a.position.x, a.position.y)
      if not seen[k] then
        seen[k] = true
        out[#out + 1] = { name = a.name, x = a.position.x, y = a.position.y }
      end
    end
  end
  table.sort(out, function(p, q) if p.y ~= q.y then return p.y < q.y end return p.x < q.x end)
  return out
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local st = ctx.state()
  local s = ctx.surface()
  if e.tick % 300 ~= 0 then return end
  if not st.injected then
    if e.tick < 6000 then return end
    local okp, status = pcall(remote.call, "fo-ia3e", "status", "player")
    local fini = okp and status and status.plant_state == "fini"
    local kw = plant_power(s)
    if fini and kw > 0 then
      local before = plant_arms(s)
      local n = remote.call("fo-ia1d", "legacy_electric_arms", "player") or 0
      local after = plant_arms(s)
      local burners0, elec1 = 0, 0
      for _, a in ipairs(before) do if a.name == BURNER then burners0 = burners0 + 1 end end
      for _, a in ipairs(after) do if a.name == ELECTRIC then elec1 = elec1 + 1 end end
      st.injected = { tick = e.tick, n = n, burners0 = burners0, elec1 = elec1, arms = after }
      ctx.check(n >= 3, "etat herite reproduit : bras de la centrale passes a l'electrique", string.format("%d converti(s)", n))
      ctx.check(elec1 >= n, "les bras convertis sont electriques sur la carte", string.format("%d electrique(s) pres de la centrale", elec1))
      log(TAG .. string.format("injection a %.1f min : %d bras convertis (%d a combustion avant, %d electriques apres)",
        e.tick / 3600, n, burners0, elec1))
    end
    return
  end
  local inj = st.injected
  if st.verified or e.tick < inj.tick + 1800 then return end
  st.verified = true
  local arms = plant_arms(s)
  local burners, electric = 0, 0
  for _, a in ipairs(arms) do
    if a.name == BURNER then burners = burners + 1 else electric = electric + 1 end
  end
  -- les positions converties : plus aucun bras électrique là, un bras à combustion à la place
  local back, still = 0, 0
  for _, a in ipairs(inj.arms) do
    if a.name == ELECTRIC then
      if s.find_entity(BURNER, { a.x, a.y }) then back = back + 1 end
      if s.find_entity(ELECTRIC, { a.x, a.y }) then still = still + 1 end
    end
  end
  local kw, ngen = plant_power(s)
  st.kw_after = kw
  ctx.check(back >= inj.n and still == 0, "tous les bras convertis sont repasses a combustion",
    string.format("%d a combustion, %d encore electrique(s) sur %d convertis", back, still, inj.n))
  ctx.check(ngen >= 1, "la centrale existe encore", tostring(ngen))
  log(TAG .. string.format("verification a %.1f min : %d bras a combustion, %d electriques pres de la centrale, %d generateur(s), puissance %.0f J/tick",
    e.tick / 3600, burners, electric, ngen, kw))
end

-- remplace la fin de la partie du guide (ses contrôles portent sur 60 minutes de partie)
base.finish = function(ctx)
  local st = ctx.state()
  ctx.check(st.injected ~= nil, "l'etat herite a pu etre reproduit avant la fin (premier courant de la centrale)")
  ctx.check(st.verified == true, "la verification apres migration a eu lieu")
  -- la centrale reste alimentée : production non nulle sur les 6 dernières minutes du banc
  local kw = plant_power(ctx.surface())
  ctx.check((st.kw_after or 0) > 0 or kw > 0, "la centrale produit du courant apres la migration",
    string.format("%.0f puis %.0f J/tick", st.kw_after or 0, kw))
  log(TAG .. string.format("fin : injection %s, verification %s, puissance %.0f J/tick",
    st.injected and string.format("%.1f min", st.injected.tick / 3600) or "jamais", tostring(st.verified), kw))
end

return base
