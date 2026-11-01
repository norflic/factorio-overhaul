-- Scénario greffé du lot RB-4 GAMME (1/11) : le DUEL en moteur réel (PLAN.md ROBOTS, §2 « gagner à 1 contre 3 du palier de l'âge »).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB4 -- 3600 rb-duel <source>
-- Les 7 robots de ligne (Trotte-Vapeur, Écaille, Bobineur, Aiguille, Truelle, Aileron, Lévite), chacun sur son site (80 tuiles entre
-- deux sites), face à TROIS déchiqueteurs du palier de son âge (shared/robots/duel.lua : Duel.tier_of_age), partis à 40 tuiles et
-- lancés à l'attaque au tick 120 (go_to_location, distraction par l'ennemi). Mesures : victoire, PV restants, durée, rapportées aux
-- prédictions du MODÈLE (table MODELE ci-dessous, recopiée de `lua5.2 tests/robots_duel_test.lua --scenario` ; le banc hors jeu contrôle
-- qu'elle n'a pas dérivé). L'écart au modèle sert à relever les constantes GLOBALES du modèle (AIM_DELAY, CONTACT_DELAY), jamais
-- un robot en particulier. Artillerie, soin et ingénieur : scénario rb-soutien. Journal : [FO-RB-DUEL].

local C = require("scenarios/rb0_common")

local T0 = 120
local CHECK = 3500
local X0, Y0 = 6000, 6000
local SEP = 40
local ECART_FRACTION = 0.20 -- écart toléré entre la marge mesurée et la marge du modèle
local ECART_DUREE = 0.40    -- écart relatif toléré sur la durée du duel

local TIER_NAMES = { "small", "medium", "big", "behemoth", "colossal", "titan", "apex", "primordial", "ancestral", "abyssal", "cataclysmic", "eternal" }
local TIER_OF_AGE = { 1, 1, 2, 2, 3, 3, 4, 5, 6, 6, 7, 9, 10, 12, 12 }
local function biter_name(tier)
  if tier <= 4 then return TIER_NAMES[tier] .. "-biter" end
  return "fo-" .. TIER_NAMES[tier] .. "-biter"
end

--MODELE-DEBUT
local MODELE = {
  ["steam-trotter"] = { age = 3, frac = 0.35, ticks = 531 },
  ["scalehide"] = { age = 5, frac = 0.39, ticks = 1173 },
  ["coiler"] = { age = 6, frac = 0.35, ticks = 358 },
  ["needle"] = { age = 7, frac = 0.35, ticks = 693 },
  ["trowel"] = { age = 10, frac = 0.35, ticks = 2130 },
  ["finback"] = { age = 11, frac = 0.35, ticks = 1799 },
  ["levite"] = { age = 12, frac = 0.35, ticks = 2459 },
}
--MODELE-FIN
local ORDRE = { "steam-trotter", "scalehide", "coiler", "needle", "trowel", "finback", "levite" }

local function R(ctx, fn, ...) return ctx.remote("fo-robots", fn, ...) end

return {
  description = "RB-4 : duel de chaque robot de ligne contre trois dechiqueteurs du palier de son age, compare au modele",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.sites = {}
    st.pret = false
    local manque = {}
    for _, id in ipairs(ORDRE) do
      if not game.entity_prototypes["fo-robot-player-" .. id] then manque[#manque + 1] = id end
    end
    if #manque > 0 then
      ctx.fail("prototypes des robots presents", table.concat(manque, ", "))
      return
    end
    C.force("rb-duel")
    game.map_settings.enemy_expansion.enabled = false
    ctx.call("war_setting", "fo-war-robots-cap", 200)
    ctx.prepare_area(X0 - 70, Y0 - 30, X0 + 40, Y0 + 80 * #ORDRE, "grass-1")
    C.sans_ennemis(s, X0 - 90, Y0 - 50, X0 + 60, Y0 + 80 * #ORDRE + 30)
    for i, id in ipairs(ORDRE) do
      local m = MODELE[id]
      local tier = TIER_OF_AGE[m.age]
      local y = Y0 + 80 * (i - 1)
      local un, why = R(ctx, "spawn", "rb-duel", id, X0, y)
      local site = { id = id, y = y, tier = tier, un = un, why = why, biters = {}, t_end = nil, win = nil, pv_max = nil, dmin = 1e9 }
      for k = 1, 3 do
        local b = s.create_entity({ name = biter_name(tier), position = { X0 - SEP, y + (k - 2) * 1.5 }, force = "enemy" })
        site.biters[#site.biters + 1] = b
      end
      local info = un and R(ctx, "unit_info", un)
      site.pv_max = info and info.max
      st.sites[#st.sites + 1] = site
      ctx.log(string.format("site %s : palier %d (%s), robot %s (%s), PV %s", id, tier, biter_name(tier), tostring(un), tostring(why), tostring(site.pv_max)))
    end
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    if e.tick == T0 then
      for _, site in ipairs(st.sites) do
        for _, b in ipairs(site.biters) do
          if b.valid then
            b.set_command({ type = defines.command.go_to_location, destination = { x = X0, y = site.y }, radius = 2,
              distraction = defines.distraction.by_enemy })
          end
        end
      end
    end
    if e.tick >= T0 and e.tick % 5 == 0 then
      for _, site in ipairs(st.sites) do
        if not site.t_end then
          local vivants = 0
          for _, b in ipairs(site.biters) do if b.valid then vivants = vivants + 1 end end
          local info = site.un and R(ctx, "unit_info", site.un)
          site.derniere = info and info.health or site.derniere
          if vivants == 0 and info then
            site.t_end, site.win, site.pv = e.tick - T0, true, info.health
          elseif not info then
            site.t_end, site.win, site.pv = e.tick - T0, false, 0
            site.restants = vivants
          end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    for _, site in ipairs(st.sites) do
      local m = MODELE[site.id]
      local frac = site.win and site.pv_max and (site.pv / site.pv_max) or 0
      local dur = site.t_end or -1
      local ok_win = site.win == true
      ctx.check(ok_win, "(" .. site.id .. ") gagne son duel contre 3 deshiqueteurs du palier " .. site.tier,
        string.format("victoire=%s, duree %d ticks (modele %d), PV restants %.2f (modele %.2f), biters restants %s", tostring(site.win), dur, m.ticks,
          frac, m.frac, tostring(site.restants)))
      ctx.check(ok_win and math.abs(frac - m.frac) <= ECART_FRACTION and math.abs(dur - m.ticks) <= ECART_DUREE * m.ticks,
        "(" .. site.id .. ") conforme au modele : marge a " .. ECART_FRACTION .. " pres, duree a " .. math.floor(ECART_DUREE * 100) .. " % pres",
        string.format("marge %.2f contre %.2f, duree %d contre %d", frac, m.frac, dur, m.ticks))
      ctx.log(string.format("[FO-RB-DUEL] %s palier=%d win=%s ticks=%d modele_ticks=%d marge=%.3f modele_marge=%.3f", site.id, site.tier,
        tostring(site.win), dur, m.ticks, frac, m.frac))
    end
    local ok_ledger = R(ctx, "check")
    ctx.check(ok_ledger == true, "registre des robots coherent")
  end,
}
