--[[
  Lot RECON : MIGRATION. La sauvegarde est créée par main 0.6.5 (DOUBLE source : fo-logs/2026-10-28_RECON/src-temoin, à GARDER,
  = git archive 5ceea7e + feuilles), guerre de 2 factions à 800 tuiles du départ qui ne se connaissent pas, lancée à la création
  (aucun tick joué : le chef et `mem.k` / `f.recon` sont créés par le code du lot à la première pensée, comme sur toute
  sauvegarde 0.6.5 rechargée). Le benchmark la recharge avec le code du lot.
  Attendu à 20 700 ticks : la partie continue sans erreur ; chaque faction tient une connaissance (statut « inconnue ») de
  l'autre ; aucune attaque entre factions ; au moins un soldat éclaireur parti ; la sonde refuse l'attaque.
  Lancement : banc.py --creation <src-temoin> --out <archive> -- 21000 recon-migration <source>. Journal : [FO-RECON-MIGRATION].
]]
local TAG = "[FO-RECON-MIGRATION] "
return {
  description = "RECON : sauvegarde 0.6.5 (sans connaissance des rivales) rechargee avec le lot",
  base = nil,
  check_tick = 20700,

  init = function(ctx)
    local st = ctx.state()
    st.version_create = script.active_mods["factorio-overhaul"]
    st.create_has_recon = (pcall(remote.call, "factorio-overhaul", "recon_status")) -- la source de création (0.6.5) ne l'a pas
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 60, 6, 800)
    remote.call("factorio-overhaul", "war_fund", 3000)
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", guerre " .. tostring(st.war))
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.log(TAG .. "creation avec " .. tostring(st.version_create) .. ", benchmark avec " .. tostring(script.active_mods["factorio-overhaul"]))
    ctx.check(st.create_has_recon == false, "la sauvegarde vient d'une source SANS la reconnaissance (main 0.6.5)",
      tostring(st.create_has_recon))
    local r = ctx.call("recon_status")
    ctx.check(#r.factions == 2, "2 factions vivantes apres le chargement", #r.factions)
    local attacks, scouts, unknown = 0, 0, 0
    for _, f in ipairs(r.factions) do
      attacks, scouts = attacks + f.attacks, scouts + f.scouts
      for _, x in ipairs(f.rivals) do if x.status == "inconnue" then unknown = unknown + 1 end end
    end
    ctx.check(unknown == 2, "chaque faction tient une connaissance de l'autre (inconnue)", unknown)
    ctx.check(attacks == 0, "0 attaque entre factions qui ne se voient pas", attacks)
    ctx.check(scouts >= 1, "au moins un soldat eclaireur parti apres le chargement", scouts)
    local a, b = r.factions[1], r.factions[2]
    local pa = a and b and ctx.call("recon_probe", a.key, b.key)
    ctx.check(pa == false, "la sonde refuse l'attaque d'une rivale jamais vue", tostring(pa))
  end,
}
