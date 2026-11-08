--[[
  Lot TV-PILOTE : micro-banc (palier 3) des cinq points « pilotage » contre le moteur réel. Ce banc NE prouve PAS une partie entière ; il
  prouve que le code branché s'exécute dans le moteur, avec ses réglages ALLUMÉS par défaut, et laisse au journal du mod la chaîne
  déclencheur -> décision -> action -> effet :
    W04  « [FO-GARDES] N garde(s) inventoriee(s) » au premier passage de la capitalisation ;
    D02  « [FO-AMORCE] <faction> : kit minimal : ... | main avant la 1re production, hors liste : ... » au premier relevé ;
    V88  « [FO-DEFAUT] <faction> : <cause> -> <signal> -> levier <levier> ... » : le banc NOTE des défauts (remote fo-capi bench_defaut :
         courant, sortie, chantier occupe, et une cause hors de la table) ; le relevé suivant les range par défaut (Df.route) ; la cause
         hors table donne « defaut sans levier » ;
    V10  « [FO-ARMEE] <faction> : famille armee, part N pour mille ; besoins [...] ; reserve [...] » : la décision de la capitalisation
         est hâtée (fo-ind hasten), ses parts delta + alpha sont lues par le cerveau à la pensée suivante ;
    G02  les deux réglages fo-war-armee-famille et fo-war-plafonds existent et valent vrai SANS que le banc les écrive.
  Le banc est le cerveau de la décision hâtée : un banc court ne peut pas attendre la première décision (vers le tick 3 300).
  Lancement : banc.py --out <archive> --qui TV-PILOTE -- 2400 tv-pilote <copie figée>, puis py -3.9 -B tools/autotest/tv_pilote.py <archive>
  Journal : [FO-TV-PILOTE] (ce banc) ; [FO-GARDES], [FO-AMORCE], [FO-DEFAUT], [FO-ARMEE], [FO-CAPI] (le mod).
]]

local function teams(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

return {
  description = "TV-PILOTE : gardes, kit d'amorcage, defauts vers levier, famille armee, plafonds de surete",
  base = nil,
  check_tick = 2300,

  init = function(ctx)
    local st = ctx.state()
    local ok = ctx.remote("fo-pvp", "set_difficulty", "normal")
    ctx.check(ok == true, "difficulte Normal imposee avant la guerre (les factions declarent la guerre)", tostring(ok))
    for _, s in ipairs({ { "fo-war-industrie", true }, { "fo-war-ia3e", true }, { "fo-war-capi", true } }) do
      local v = ctx.call("war_setting", s[1], s[2])
      ctx.check(v == s[2], "reglage " .. s[1] .. " = " .. tostring(s[2]), tostring(v))
    end
    -- G02 et V10 : les deux reglages du lot valent VRAI par defaut, sans que le banc les ecrive
    st.armee_on = settings.global["fo-war-armee-famille"] and settings.global["fo-war-armee-famille"].value
    st.plafonds_on = settings.global["fo-war-plafonds"] and settings.global["fo-war-plafonds"].value
    ctx.check(st.armee_on == true, "fo-war-armee-famille allume par defaut", tostring(st.armee_on))
    ctx.check(st.plafonds_on == true, "fo-war-plafonds allume par defaut", tostring(st.plafonds_on))
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
    ctx.check(ctx.call("war_fund", 20000) == 2, "2 factions financees")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 100 then
      local tm = teams(ctx)
      st.key = tm[1] and tm[1].key
      ctx.check(st.key ~= nil, "une faction relevee")
    end
    if not st.key then return end
    -- V88 : defauts notes des que la capitalisation a cree son etat, AVANT son premier releve (le releve les range)
    if not st.noted and e.tick >= 200 and e.tick % 30 == 0 then
      local a = ctx.remote("fo-capi", "bench_defaut", st.key, "courant", "iron-gear-wheel")
      local b = ctx.remote("fo-capi", "bench_defaut", st.key, "sortie", "iron-plate")
      local c = ctx.remote("fo-capi", "bench_defaut", st.key, "chantier occupe", "copper-cable")
      local d = ctx.remote("fo-capi", "bench_defaut", st.key, "cause-inventee-par-le-banc", "stone-brick")
      if a == true and b == true and c == true and d == true then
        st.noted = e.tick
        ctx.log("defauts notes au tick " .. e.tick .. " : courant, sortie, chantier occupe, cause inventee")
      end
    end
    -- V10 : la decision est hatee des que le releve des machines existe ; ses parts sont lues a la pensee suivante
    if st.noted and not st.hastened and e.tick >= 300 and e.tick % 60 == 0 then
      if ctx.remote("fo-ind", "hasten", st.key) == true then
        st.hastened = e.tick
        ctx.log("decision hatee au tick " .. e.tick)
      end
    end
    if e.tick > 0 and e.tick % 600 == 0 then
      local s = ctx.remote("fo-capi", "status", st.key)
      local pvp = ctx.remote("fo-pvp", "status")
      local declared = 0
      for _, fp in ipairs(pvp and pvp.factions or {}) do if fp.declared then declared = declared + 1 end end
      ctx.log(string.format("tick %d : decisions %s, ordres ouverts %s, factions en guerre declaree %d", e.tick, tostring(s and s.decisions),
        tostring(s and #s.open), declared))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.noted ~= nil, "defauts notes au releve de la capitalisation")
    ctx.check(st.hastened ~= nil, "la decision de la capitalisation a ete hatee")
    local s = st.key and ctx.remote("fo-capi", "status", st.key) or nil
    ctx.check(s ~= nil and (s.decisions or 0) >= 1, "la capitalisation a decide au moins une fois (" .. tostring(s and s.decisions) .. ")")
    log(string.format("[FO-TV-PILOTE] %s : defauts notes tick %s, decision hatee tick %s, decisions %s", tostring(st.key), tostring(st.noted),
      tostring(st.hastened), tostring(s and s.decisions)))
  end,
}
