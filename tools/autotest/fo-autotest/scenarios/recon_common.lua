--[[
  Lot RECON (28/10) : bancs de la CONNAISSANCE des rivales. Réponse du DC : « les factions ne peuvent viser QUE ce qu'elles ont
  reconnu ; elles ne peuvent pas viser un avant-poste qui n'a pas été vu ; peut-être qu'elles ont apporté un soldat quand même,
  si ça peut faire l'exploration ».
  Deux factions, sans joueur actif, à `distance` tuiles du départ (donc 2 × distance l'une de l'autre) :
    - « separees » (800) : aucune ne voit l'autre. Attendu : AUCUNE attaque entre factions, au moins un soldat éclaireur parti,
      toute attaque proposée par la sonde `recon_probe` refusée (et comptée) ;
    - « voisines » (60) : leurs QG sont à portée des yeux du chef (160 tuiles). Attendu : chacune VOIT l'autre (QG et avant-
      postes, statut fraîche), la sonde accepte l'attaque, aucun soldat envoyé en reconnaissance ;
    - « attaque » (60, 50 min, 40 000 plaques ; ABANDONNÉ : les factions y restent en survie sous les bitters et n'attaquent pas d'elles-mêmes en 50 min, fo-logs/2026-10-28_RECON3/attaque-2) : les mêmes voisines, jouées assez longtemps pour qu'une attaque entre factions PARTE : preuve en
      moteur réel du critère central, « où elles se voient, l'attaque part » (ligne [FO-STRAT] attaque ... savoir N min, lue
      par tools/autotest/recon_mesures.py).
  Journal : [FO-RECON-<CAS>] ; lignes du mod : [FO-RECON]. Lancement : fo-autotest.bat nopause <ticks> recon-<cas> <source>.
]]
return function(case, distance, ticks)
  local TAG = "[FO-RECON-" .. case:upper() .. "] "
  local function status(ctx)
    return ctx.call("recon_status")
  end
  return {
    description = "RECON : connaissance des rivales, cas " .. case .. " (distance " .. distance .. ")",
    base = nil,
    check_tick = ticks - 300, -- le contrôle se joue avant la fin du banc (sinon il est sauté)

    init = function(ctx)
      local ok = ctx.remote("fo-pvp", "set_difficulty", "peaceful")
      ctx.check(ok == true, "difficulte Paisible (aucun PvP : seule la guerre entre factions)", tostring(ok))
      local started = ctx.call("war_start", 2, 60, 6, distance)
      ctx.check(started == true, "guerre lancee : 2 factions, QG a " .. distance .. " tuiles du depart", tostring(started))
      ctx.call("war_fund", case == "attaque" and 40000 or 3000) -- « attaque » : assez de plaques pour lever l'armée (13 à 28 soldats)
      ctx.call("profiler", true)
    end,

    tick = function(ctx, e)
      -- « voisines » : preuve en moteur réel que l'attaque PART après une vue (les parties de 50 min restent en « survie » sous la
      -- pression des bitters : aucune attaque spontanée). 2 000 ticks avant le contrôle, la 1re faction lance une vraie attaque
      -- de 2 soldats contre la 2e (Military.attack : filet de connaissance, chemin, groupe, ligne « [FO-STRAT] attaque … savoir
      -- N min »).
      if case == "voisines" and e.tick == ticks - 2400 then
        local r = status(ctx)
        local a, b = r.factions[1], r.factions[2]
        local ok = a and b and ctx.call("recon_force_attack", a.key, b.key, 2)
        ctx.log(TAG .. "attaque forcee " .. tostring(a and a.key) .. " -> " .. tostring(b and b.key) .. " : " .. tostring(ok))
      end
      if e.tick % 1800 ~= 0 or e.tick == 0 then return end
      local r = status(ctx)
      local parts = {}
      for _, f in ipairs(r.factions) do
        local rs = {}
        for _, x in ipairs(f.rivals) do
          rs[#rs + 1] = string.format("%s %s%s%s", x.key, x.status, x.hq and " qg" or "", x.posts > 0 and (" " .. x.posts .. "p") or "")
        end
        parts[#parts + 1] = string.format("%s attaques %d eclaireurs %d perdus %d refus %d [%s]", f.key, f.attacks, f.scouts, f.lost,
          f.refused, table.concat(rs, "; "))
      end
      ctx.log(string.format("minute %.1f | %s", e.tick / 3600, table.concat(parts, " | ")))
    end,

    finish = function(ctx)
      local r = status(ctx)
      ctx.check(r.fog == true, "brouillard actif (connaissance par la vue)")
      ctx.check(#r.factions == 2, "2 factions vivantes", #r.factions)
      local attacks, scouts, seen_all, none_seen = 0, 0, true, true
      for _, f in ipairs(r.factions) do
        attacks, scouts = attacks + f.attacks, scouts + f.scouts
        for _, x in ipairs(f.rivals) do
          if x.status == "inconnue" then seen_all = false else none_seen = false end
        end
      end
      local a, b = r.factions[1], r.factions[2]
      local pa = a and b and ctx.call("recon_probe", a.key, b.key)
      local pb = a and b and ctx.call("recon_probe", b.key, a.key)
      ctx.log(TAG .. string.format("attaques %d, eclaireurs partis %d, sonde %s/%s, rivales toutes vues %s, aucune vue %s", attacks,
        scouts, tostring(pa), tostring(pb), tostring(seen_all), tostring(none_seen)))
      if case == "separees" then
        ctx.check(attacks == 0, "0 attaque lancee entre factions qui ne se voient pas", attacks)
        ctx.check(scouts >= 1, "au moins un soldat eclaireur parti pour chercher", scouts)
        ctx.check(pa == false and pb == false, "la sonde refuse l'attaque d'une rivale jamais vue", tostring(pa) .. "/" .. tostring(pb))
        local rr = ctx.call("recon_status")
        local refused = 0
        for _, f in ipairs(rr.factions) do refused = refused + f.refused end
        ctx.check(refused >= 2, "les refus sont comptes", refused)
      elseif case == "attaque" then
        ctx.check(seen_all, "chaque faction a vu l'autre (QG a portee des yeux)")
        ctx.check(attacks >= 1, "au moins une attaque entre factions lancee apres une vue (journal : savoir N min)", attacks)
        ctx.check(pa == true and pb == true, "la sonde accepte l'attaque d'une rivale vue", tostring(pa) .. "/" .. tostring(pb))
      else
        ctx.check(seen_all, "chaque faction a vu l'autre (QG a portee des yeux)")
        ctx.check(pa == true and pb == true, "la sonde accepte l'attaque d'une rivale vue", tostring(pa) .. "/" .. tostring(pb))
        ctx.check(scouts == 0, "aucun soldat envoye en reconnaissance quand la rivale est vue", scouts)
        local ka = r.factions[1] and r.factions[1].know_age
        ctx.check(ka ~= nil and ka <= 20 * 3600, "l'attaque lancee apres la vue part avec un savoir frais (age en ticks)", tostring(ka))
      end
    end,
  }
end
