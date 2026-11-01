--[[
  Lot RB-4 GAMME (1/11) : MODÈLE DE DUEL des robots contre les déchiqueteurs (PLAN fo-logs/2026-10-31_ROBOTS §2, lot RB-4 :
  « recalage de PV et de dégâts par le banc rb-duel et shared/robots/modele.lua sur les 12 paliers, pas à la main »).
  Lua PUR : aucune API du jeu, aucun nom d'objet.

  Ce que le module fait :
    - donne les statistiques d'un déchiqueteur de chaque palier (1 à 12, famille facultative) depuis shared/content/enemies.lua
      (E.new_tiers, E.stats) et les chiffres vanilla des paliers 1 à 4 (data/base/prototypes/entity/enemies.lua) ;
    - applique la règle de résistance du moteur (retrait fixe, puis pourcentage ; sous 1 de dégâts : 1 / (2 - x)) ;
    - donne le PALIER DE L'ÂGE : le plus haut palier présent à au moins 10 % de poids d'apparition à la borne haute de la
      fenêtre d'évolution de l'âge (X.evolution_window, E.spawn_curves) : âge 15 -> palier 12 (× 1 100) ;
    - joue un duel (une équipe de robots contre N déchiqueteurs qui chargent, un tick à la fois, déterministe) ;
    - CALIBRE : trouve par bissection le facteur λ qui multiplie ensemble PV et dégâts par tir d'un robot pour qu'il gagne
      son duel avec la marge visée (Duel.TARGET), et la quantité de soin d'une impulsion pour un soutien.
  tests/robots_duel_test.lua contrôle que les chiffres écrits dans shared/content/robots.lua SONT ce que ce module calcule ;
  `lua5.2 tests/robots_duel_test.lua --calibrer` imprime la table à recopier. Le banc rb-duel (moteur réel) rejoue les mêmes
  duels et mesure l'écart au modèle (constantes AIM_DELAY, CONTACT_DELAY, relevées au moteur, jamais ajustées robot par robot).
]]

local E = require("shared.content.enemies")
local X = require("shared.content.epochs")

local Duel = {}

local floor, max, min = math.floor, math.max, math.min
local ln = math.log

---------------------------------------------------------------------------------------------------
-- 1. Constantes du duel (relevées au moteur par le banc rb-duel ; voir RAPPORT RB-4)
---------------------------------------------------------------------------------------------------
Duel.BITERS = 3          -- « gagner à 1 contre 3 » du palier de l'âge
Duel.SEPARATION = 40     -- distance de départ entre les déchiqueteurs et la ligne de front (tuiles)
Duel.AIM_DELAY = 20      -- ticks entre l'entrée d'une cible en portée et le premier tir
Duel.CONTACT_DELAY = 18  -- ticks entre le contact et la première morsure
Duel.AREA_SHARE = 0.5    -- part des dégâts d'une zone reçue par les déchiqueteurs voisins de la cible (rb-duel, Bobineur : voir RAPPORT RB-4)
Duel.MAX_TICKS = 36000   -- au-delà : impasse, le duel est perdu
Duel.TARGET = 0.35       -- marge visée : part des PV de l'équipe qui reste après le duel
Duel.WEIGHT_MIN = 0.10   -- poids d'apparition minimal pour qu'un palier compte comme « présent » à l'âge
Duel.SCREEN_SECONDS = 12 -- un écran (artillerie) tient 12 s sous la morsure des trois déchiqueteurs
Duel.HEAL_BASE_MARGIN = 0.08 -- soutien : le robot de ligne de référence gagne seul d'extrême justesse
Duel.HEAL_TARGET = 0.45  -- soutien : avec le soin, la marge visée

---------------------------------------------------------------------------------------------------
-- 2. Déchiqueteurs
---------------------------------------------------------------------------------------------------
-- Paliers 1 à 4 : valeurs vanilla (small, medium, big, behemoth). res[type] = { retrait fixe, fraction }.
local VANILLA = {
  { hp = 15, dmg = 7, cd = 35, speed = 0.2, res = {} },
  { hp = 75, dmg = 15, cd = 35, speed = 0.24, res = { physical = { 4, 0.10 }, explosion = { 0, 0.10 } } },
  { hp = 375, dmg = 30, cd = 35, speed = 0.23, res = { physical = { 8, 0.10 }, explosion = { 0, 0.10 } } },
  { hp = 3000, dmg = 90, cd = 50, speed = 0.3, res = { physical = { 12, 0.10 }, explosion = { 12, 0.10 } } },
}
Duel.VANILLA = VANILLA

local function copy_res(res)
  local out = {}
  for _, k in ipairs({ "physical", "explosion", "acid", "fire", "laser", "electric", "poison", "impact" }) do
    if res[k] then out[k] = { res[k][1], res[k][2] } end
  end
  return out
end

--- Statistiques d'un déchiqueteur : { hp, dmg, cd, speed, res }. Palier 5 et plus : multiplicateurs de E.new_tiers sur le
--- béhémoth, résistances physique, explosion et acide relevées du retrait `resist` et du pourcentage `resist` (prototypes/
--- enemies.lua, scaled_resistances). Famille facultative : PV, dégâts, vitesse et résistances de E.families.
function Duel.biter(tier, family)
  tier = max(1, min(E.TIERS, floor(tier)))
  local b
  if tier <= E.VANILLA_TIERS then
    local v = VANILLA[tier]
    b = { hp = v.hp, dmg = v.dmg, cd = v.cd, speed = v.speed, res = copy_res(v.res) }
  else
    local v, nt = VANILLA[4], E.new_tiers[tier]
    b = { hp = v.hp * nt.hp, dmg = v.dmg * nt.damage, cd = v.cd, speed = v.speed * nt.speed, res = copy_res(v.res) }
    local flat, pct = nt.resist, nt.resist / 100
    for _, k in ipairs({ "physical", "explosion", "acid" }) do
      local r = b.res[k] or { 0, 0 }
      b.res[k] = { r[1] + flat, min(0.95, r[2] + pct) }
    end
  end
  local f = family and E.families[family]
  if f then
    b.hp, b.dmg, b.speed = b.hp * f.hp, b.dmg * f.damage, b.speed * f.speed
    local fr = E.family_resist(f, tier)
    local keys = {}
    for k in next, fr do keys[#keys + 1] = k end -- trié juste après
    table.sort(keys)
    for _, k in ipairs(keys) do
      local r = b.res[k] or { 0, 0 }
      b.res[k] = { r[1] + fr[k][1], min(0.95, r[2] + fr[k][2] / 100) }
    end
    b.dtype = f.damage_type
  end
  b.dtype = b.dtype or "physical"
  return b
end

--- Règle de résistance du moteur : retrait fixe d'abord ; sous 1 de dégâts restants, 1 / (2 - x) ; puis le pourcentage.
function Duel.after_resist(amount, dtype, res)
  local r = res and res[dtype]
  if not r then return amount end
  local x = amount - r[1]
  if x < 1 then x = 1 / (2 - x) end
  return x * (1 - r[2])
end

---------------------------------------------------------------------------------------------------
-- 3. Palier de l'âge
---------------------------------------------------------------------------------------------------
--- Poids d'apparition du palier `tier` à l'évolution `e` (interpolation linéaire des points de E.spawn_curves).
function Duel.weight(tier, e)
  local c = E.spawn_curves[tier]
  if not c then return 0 end
  if e <= c[1][1] then return c[1][2] end
  for i = 2, #c do
    local a, b = c[i - 1], c[i]
    if e <= b[1] then
      if b[1] == a[1] then return b[2] end
      return a[2] + (b[2] - a[2]) * (e - a[1]) / (b[1] - a[1])
    end
  end
  return c[#c][2]
end

--- Palier de l'âge : le plus haut palier dont le poids est d'au moins WEIGHT_MIN à la borne haute de la fenêtre d'évolution.
function Duel.tier_of_age(age)
  age = max(1, min(#X.evolution_window, floor(age)))
  local e = X.evolution_window[age][2]
  local best = 1
  for t = 1, E.TIERS do
    if Duel.weight(t, e) >= Duel.WEIGHT_MIN then best = t end
  end
  return best
end

---------------------------------------------------------------------------------------------------
-- 4. Le duel
---------------------------------------------------------------------------------------------------
--- Un membre d'équipe : { hp, back (tuiles derrière la ligne de front), shot = { damage, cooldown, dtype, area, range, min_range },
--- heal = { amount, period, max } }. Le membre `front` (back 0) reçoit les morsures tant qu'il vit.
--- Rend { win, ticks, left = { PV restants par membre }, fraction = { part restante par membre } }.
function Duel.fight(team, biter, count, opts)
  opts = opts or {}
  local members = {}
  for i, m in ipairs(team) do
    members[i] = { hp = m.hp, maxhp = m.hp, back = m.back or 0, shot = m.shot, heal = m.heal, ready = nil, idx = i }
  end
  table.sort(members, function(a, b)
    if a.back ~= b.back then return a.back < b.back end
    return a.idx < b.idx
  end)
  local bs = {}
  for i = 1, count do bs[i] = { hp = biter.hp, ready = nil } end
  local alive_b = count
  local p = -(opts.separation or Duel.SEPARATION)
  local contact_at
  local function target()
    for _, m in ipairs(members) do if m.hp > 0 then return m end end
    return nil
  end
  local ticks = opts.max_ticks or Duel.MAX_TICKS
  local t = 0
  while t < ticks do
    local tg = target()
    if not tg then break end
    if p < tg.back then p = min(tg.back, p + biter.speed) end
    -- tirs
    for _, m in ipairs(members) do
      local s = m.shot
      if m.hp > 0 and s and alive_b > 0 then
        local d = m.back - p
        local lo = s.min_range or 0
        if d <= s.range and d >= lo then
          if m.ready == nil then m.ready = t + Duel.AIM_DELAY end
          if t >= m.ready then
            local dmg = Duel.after_resist(s.damage, s.dtype, biter.res)
            if (s.area or 0) >= 2 then
              local first = true
              for _, b in ipairs(bs) do
                if b.hp > 0 then
                  b.hp = b.hp - (first and dmg or dmg * Duel.AREA_SHARE)
                  first = false
                end
              end
            else
              for _, b in ipairs(bs) do
                if b.hp > 0 then b.hp = b.hp - dmg break end
              end
            end
            alive_b = 0
            for _, b in ipairs(bs) do if b.hp > 0 then alive_b = alive_b + 1 end end
            m.ready = t + s.cooldown
          end
        else
          m.ready = nil
        end
      end
    end
    if alive_b == 0 then break end
    -- morsures
    tg = target()
    if tg and p >= tg.back - 1e-9 then
      contact_at = contact_at or t
      for _, b in ipairs(bs) do
        if b.hp > 0 then
          if b.ready == nil then b.ready = t + Duel.CONTACT_DELAY end
          if t >= b.ready then
            tg.hp = tg.hp - biter.dmg
            b.ready = t + biter.cd
            if tg.hp <= 0 then
              tg = target()
              if not tg then break end
            end
          end
        end
      end
    end
    -- soin en impulsion
    if t % 60 == 59 then
      for _, m in ipairs(members) do
        local h = m.heal
        if m.hp > 0 and h then
          local n = 0
          for _, o in ipairs(members) do
            if o.hp > 0 and o.hp < o.maxhp and n < (h.max or 30) then
              o.hp = min(o.maxhp, o.hp + h.amount)
              n = n + 1
            end
          end
        end
      end
    end
    t = t + 1
  end
  local res = { win = alive_b == 0 and target() ~= nil, ticks = t, left = {}, fraction = {}, contact_at = contact_at }
  for _, m in ipairs(members) do
    local v = max(0, m.hp)
    res.left[m.idx] = v
    res.fraction[m.idx] = v / m.maxhp
  end
  return res
end

---------------------------------------------------------------------------------------------------
-- 5. Conception d'un robot et calibrage
---------------------------------------------------------------------------------------------------
--- Arme d'un robot de données `r` (shared/content/robots.lua) au format du duel.
function Duel.shot_of(r)
  local d = r.dmg0 or (r.shot and r.shot.damage) or 0
  if not r.shot or d <= 0 then return nil end
  return { damage = d, cooldown = r.shot.cooldown, dtype = r.dtype or "physical", area = r.area,
    range = r.range, min_range = r.min_range }
end

--- Équipe d'un duel pour le robot `r` : { team, subject (indice du membre dont la marge compte), kind }.
--- - ligne (tireur, assaut, géant) : le robot seul contre les déchiqueteurs ; sujet : lui-même ;
--- - artillerie (portée minimale) : un ÉCRAN sans arme qui tient SCREEN_SECONDS sous la morsure des déchiqueteurs, l'artillerie
---   à min_range + 2 derrière ; sujet : l'écran (l'artillerie tient tant que l'écran tient) ;
--- - soutien (soin) : un robot de ligne de référence (`ref`, { hp, shot }) devant, le soutien 6 tuiles derrière ; sujet : la ligne.
function Duel.team_of(r, biter, hp, shot, ref)
  if r.heal then
    return { team = { { hp = ref.hp, back = 0, shot = ref.shot },
      { hp = hp, back = 6, heal = { amount = r.heal.amount, period = r.heal.period, max = r.heal.max } } }, subject = 1, kind = "soutien" }
  end
  if r.min_range and shot then
    local screen = biter.dmg * Duel.BITERS * 60 / biter.cd * Duel.SCREEN_SECONDS
    return { team = { { hp = screen, back = 0 }, { hp = hp, back = r.min_range + 2, shot = shot } }, subject = 1, kind = "artillerie" }
  end
  return { team = { { hp = hp, back = 0, shot = shot } }, subject = 1, kind = "ligne" }
end

local function sig3(v)
  if v <= 0 then return 0 end
  local e = floor(ln(v) / ln(10))
  local scale = 10 ^ (e - 2)
  return floor(v / scale + 0.5) * scale
end
Duel.sig3 = sig3

--- Résultat du duel d'un robot pour un PV et un dégât par tir donnés.
function Duel.run(r, hp, damage, tier, ref, family)
  local biter = Duel.biter(tier, family)
  local shot = Duel.shot_of(r)
  if shot then shot = { damage = damage, cooldown = shot.cooldown, dtype = shot.dtype, area = shot.area, range = shot.range, min_range = shot.min_range } end
  local d = Duel.team_of(r, biter, hp, shot, ref)
  local res = Duel.fight(d.team, biter, Duel.BITERS)
  res.fraction_subject = res.fraction[d.subject]
  res.kind = d.kind
  return res
end

local function bisect(f, lo, hi, iterations)
  -- f(x) vrai pour x grand ; rend le plus petit x (à 1e-6 relatif) pour lequel f est vrai
  for _ = 1, iterations or 80 do
    local mid = math.sqrt(lo * hi)
    if f(mid) then hi = mid else lo = mid end
  end
  return hi
end

--- Calibre un robot : λ tel que (PV = λ × hp0, dégâts = λ × dmg0) gagne avec la marge visée contre `Duel.BITERS` déchiqueteurs du
--- palier de son âge. Rend { hp, damage, lambda, tier, fraction } (PV à 3 chiffres significatifs, dégâts entiers à 3 chiffres).
--- `r.hp0` et `r.dmg0` donnent la FORME (rapport PV / dégâts : le plan) ; `ref` : robot de ligne de référence d'un soutien.
function Duel.calibrate(r, ref, tier_override, family, target)
  target = target or Duel.TARGET
  local tier = tier_override or Duel.tier_of_age(r.age)
  local shot = Duel.shot_of(r)
  local function ok(lam)
    local hp = sig3(r.hp0 * lam)
    local dm = shot and max(1, sig3(r.dmg0 * lam)) or 0
    local res = Duel.run(r, hp, dm, tier, ref, family)
    return res.win and res.fraction_subject >= target
  end
  local lam = bisect(ok, 1e-6, 1e9, 55)
  local hp = sig3(r.hp0 * lam)
  local dm = shot and max(1, sig3(r.dmg0 * lam)) or 0
  local res = Duel.run(r, hp, dm, tier, ref, family)
  return { hp = hp, damage = dm, lambda = lam, tier = tier, fraction = res.fraction_subject, win = res.win, ticks = res.ticks }
end

--- Robot de ligne de référence d'un soutien au palier `tier` : de la forme `shape` (hp0, dmg0, shot), calibré pour gagner
--- seul d'extrême justesse (marge Duel.HEAL_BASE_MARGIN). Rend { hp, shot }.
function Duel.reference_line(shape, tier)
  local r = { age = 1, hp0 = shape.hp0, dmg0 = shape.dmg0, shot = { damage = shape.dmg0, cooldown = shape.shot.cooldown }, dtype = shape.dtype,
    range = shape.range, area = shape.area }
  local c = Duel.calibrate(r, nil, tier, nil, Duel.HEAL_BASE_MARGIN)
  return { hp = c.hp, shot = { damage = c.damage, cooldown = shape.shot.cooldown, dtype = shape.dtype or "physical", area = shape.area,
    range = shape.range } }
end

--- Calibre le soin (PV par impulsion et par cible) d'un soutien : le plus petit pour que l'équipe (ligne de référence + soutien)
--- atteigne Duel.HEAL_TARGET. Rend { amount, tier, fraction, base }.
function Duel.calibrate_heal(r, shape)
  local tier = Duel.tier_of_age(r.age)
  local ref = Duel.reference_line(shape, tier)
  local biter = Duel.biter(tier)
  local function frac(amount)
    local rr = { heal = { amount = amount, period = 60, max = r.heal.max } }
    local d = Duel.team_of(rr, biter, r.hp, nil, ref)
    local res = Duel.fight(d.team, biter, Duel.BITERS)
    return res.win and res.fraction[1] or -1
  end
  local alone = Duel.fight({ { hp = ref.hp, back = 0, shot = ref.shot } }, biter, Duel.BITERS)
  local amount = bisect(function(a) return frac(a) >= Duel.HEAL_TARGET end, 1e-3, 1e12, 55)
  amount = sig3(amount)
  return { amount = amount, tier = tier, fraction = frac(amount), base = alone.fraction[1], ref = ref }
end

--- Plus haut palier (1 à 12) contre lequel le robot, ses chiffres écrits, gagne encore le duel (marge ≥ 0), 0 s'il perd dès le 1er.
function Duel.reach(r, hp, damage, ref)
  local last = 0
  for t = 1, E.TIERS do
    local res = Duel.run(r, hp, damage, t, ref)
    if res.win then last = t end
  end
  return last
end

--- Forme du robot de ligne de référence d'un soutien (celle de l'Écaille du plan : PV et dégâts physiques, cadence 40, portée 14).
Duel.HEAL_REF = { hp0 = 5000, dmg0 = 100, shot = { cooldown = 40 }, dtype = "physical", range = 14 }

--- PV d'un soutien : un écran qui tient SCREEN_SECONDS sous la morsure des déchiqueteurs du palier de son âge.
function Duel.support_hp(tier)
  local b = Duel.biter(tier)
  return sig3(b.dmg * Duel.BITERS * 60 / b.cd * Duel.SCREEN_SECONDS)
end

--- Calibre toute la gamme (liste de données Ro.ROBOTS) : { [id] = { hp, damage, heal, tier, fraction, ... } }.
function Duel.calibrate_all(robots)
  local out = {}
  for _, r in ipairs(robots) do
    if r.heal then
      local tier = Duel.tier_of_age(r.age)
      local rr = { age = r.age, hp = Duel.support_hp(tier), heal = r.heal }
      local h = Duel.calibrate_heal(rr, Duel.HEAL_REF)
      out[r.id] = { hp = rr.hp, damage = 0, heal = h.amount, tier = tier, fraction = h.fraction, base = h.base }
    else
      out[r.id] = Duel.calibrate(r)
    end
  end
  return out
end

return Duel
