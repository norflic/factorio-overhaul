--[[
  Banc « c3-releve » du lot C3 EXTENSION (point 1 RELÈVE, 2 POSTURE, 6 SURVIE ; AUDIT_PLAFONDS n°24, 25, 30) : un avant-poste PLEIN est relevé par
  un 2e site du même minerai, demandé PUIS bâti, sans PNJ mort.

  Terrain (autour du QG d'UNE faction, Paisible) : les gisements naturels de 4 minerais sont retirés dans 450 tuiles, puis posés :
  charbon (0, +40), cuivre (-40, 0), pierre (0, -40), fer A (+50, 0, rayon 5 : le premier avant-poste de fer) et fer B (-90, +50, rayon 6 :
  le 2e site, à 103 tuiles du QG, en deçà de Ex.SAFE_D : pas d'escorte exigée ; l'escorte d'un site loin est testée hors jeu).
  Cadre : au premier avant-poste de fer posé, le banc le marque PLEIN (« fo-ext » set_full : le gisement couvert, ce que la pose de paires
  met des minutes à établir). Variante « allure » : la faction est financée (fer saturé) et la date de la dernière extension est reculée
  (set_last) : la relève part par la cause « extension » (la base grandit MÊME SI tout est saturé, critère 6) ; sans financement
  (« plein »), la cause est « plein » (le produit n'est pas saturé).
  Témoin : réglage maître fo-war-industrie ÉTEINT (les règles d'avant) sur la MÊME carte : aucune relève, le fer B n'est jamais demandé.
  Relevé chaque minute : avant-postes (type, foreuses, plein), sites, état de la relève (st.ext.why), morts de PNJ.
  Contrôles : voir finish. Lancement : banc.py ... -- 20000 c3-releve <source> ; journaux : [FO-C3-RELEVE-<TAG>] + [FO-EXTENSION] du mod.
]]
local MIN = 3600
local CHECK = 19700 -- (le contrôle précède la fin du banc de 20 000 ticks)
local RADIUS_WIPE = 450

local function disc(s, name, cx, cy, r, amount)
  local n = 0
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r then
        if s.create_entity({ name = name, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = amount }) then n = n + 1 end
      end
    end
  end
  return n
end

local function count_kind(status, kind)
  local n = 0
  for _, o in ipairs(status.outposts or {}) do if o.kind == kind then n = n + 1 end end
  return n
end

--- tag : "plein" (faction non financée) ou "allure" (financée + allure échue) ; on : réglage maître allumé (faux : le témoin).
return function(tag, on)
  local TAG = "FO-C3-RELEVE-" .. string.upper(tag) .. (on and "" or "-TEMOIN")
  return {
    description = "C3 EXTENSION : un avant-poste plein est releve par un 2e site (" .. tag .. (on and "" or ", temoin") .. ")",
    base = nil,
    check_tick = CHECK,

    init = function(ctx)
      local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-industrie", on)
      ctx.check(v == on, "reglage maitre fo-war-industrie " .. (on and "allume" or "eteint"), tostring(v))
      ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-workers", 8) == 8, "faction a 8 ouvriers")
      ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") ~= nil, "difficulte Paisible")
      ctx.check(ctx.call("war_start", 1, 100) == true, "guerre lancee (1 faction)")
      if tag == "allure" then ctx.call("war_fund", 2500) end
      local rows = ctx.remote("fo-ia1", "teams") or {}
      local key = rows[1] and rows[1].key
      ctx.check(key ~= nil and key ~= "player", "une faction", tostring(key))
      if not key then return end
      local st = ctx.state()
      st.key = key
      local ext = ctx.remote("fo-ext", "status", key)
      ctx.check(ext ~= nil and ext.hq ~= nil, "etat de la faction lu (fo-ext)")
      if not (ext and ext.hq) then return end
      local hq = { x = math.floor(ext.hq.x), y = math.floor(ext.hq.y) }
      st.hq = hq
      local s = ctx.surface()
      s.request_to_generate_chunks(hq, 15)
      s.force_generate_chunk_requests()
      local wiped = 0
      for _, e in ipairs(s.find_entities_filtered({ area = { { hq.x - RADIUS_WIPE, hq.y - RADIUS_WIPE }, { hq.x + RADIUS_WIPE, hq.y + RADIUS_WIPE } },
        name = { "iron-ore", "copper-ore", "coal", "stone" } })) do
        if e.valid then e.destroy() wiped = wiped + 1 end
      end
      st.n = { coal = disc(s, "coal", hq.x, hq.y + 40, 4, 3000), copper = disc(s, "copper-ore", hq.x - 40, hq.y, 4, 3000),
        stone = disc(s, "stone", hq.x, hq.y - 40, 3, 3000), ironA = disc(s, "iron-ore", hq.x + 50, hq.y, 5, 3000),
        ironB = disc(s, "iron-ore", hq.x - 90, hq.y + 50, 6, 3000) }
      ctx.log(string.format("[%s] QG (%d, %d) ; %d tuiles de minerai naturel retirees ; gisements : charbon %d, cuivre %d, pierre %d, fer A %d (+50, 0), fer B %d (-90, +50)",
        TAG, hq.x, hq.y, wiped, st.n.coal, st.n.copper, st.n.stone, st.n.ironA, st.n.ironB))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.key or e.tick % 300 ~= 0 or e.tick == 0 then return end
      local ext = ctx.remote("fo-ext", "status", st.key)
      if not ext then return end
      local iron = count_kind(ext, "iron")
      if iron >= 1 and not st.full_at then
        st.full_at = e.tick
        local n = ctx.remote("fo-ext", "set_full", st.key, "iron")
        ctx.log(string.format("[%s] tick %d : %d avant-poste(s) de fer marque(s) PLEINS (cadre du banc)", TAG, e.tick, n or -1))
        if tag == "allure" then ctx.remote("fo-ext", "set_last", st.key, -100000) end
      end
      if iron >= 2 and not st.second_at then
        st.second_at = e.tick
        ctx.log(string.format("[%s] tick %d : 2e avant-poste de fer POSE (%d avant-postes en tout)", TAG, e.tick, #ext.outposts))
      end
      local why_iron = ext.ext and ext.ext.why and ext.ext.why.iron
      if why_iron and why_iron:find("but", 1, true) and not st.goal_at then
        st.goal_at = e.tick
        ctx.log(string.format("[%s] tick %d : but de releve du fer : %s", TAG, e.tick, why_iron))
      end
      if e.tick % MIN == 0 then
        local parts = {}
        for _, o in ipairs(ext.outposts) do parts[#parts + 1] = string.format("%s#%d %dfor%s", o.kind, o.id, o.drills, o.full and " PLEIN" or "") end
        local why = ext.ext and ext.ext.why or {}
        ctx.log(string.format("[%s] minute %d | avant-postes {%s} | sites fer %d | releve fer: %s | pousse %s | PNJ %d morts %d | etendue %s rayon %s",
          TAG, math.floor(e.tick / MIN), table.concat(parts, " "), ext.sites.iron or 0, tostring(why.iron), tostring(ext.ext and ext.ext.push),
          ext.workers, ext.lost, tostring(ext.ext and ext.ext.extent), tostring(ext.ext and ext.ext.radius)))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      if not st.key then return end
      local ext = ctx.remote("fo-ext", "status", st.key)
      local iron = ext and count_kind(ext, "iron") or 0
      ctx.log(string.format("[%s] fin : %d avant-poste(s) de fer, premier plein a %s, but de releve a %s, 2e avant-poste a %s, PNJ morts %s",
        TAG, iron, tostring(st.full_at), tostring(st.goal_at), tostring(st.second_at), tostring(ext and ext.lost)))
      if ext and ext.ext then
        for _, e in ipairs(ext.ext.log or {}) do ctx.log(string.format("[%s] journal de la releve : %s (tick %d)", TAG, e.text, e.tick)) end
      end
      ctx.check(st.full_at ~= nil, "un premier avant-poste de fer a ete pose (cadre du banc)", tostring(st.full_at))
      if on then
        ctx.check(st.goal_at ~= nil, "un but de releve du fer a ete emis (cause au journal)", tostring(st.goal_at))
        ctx.check(iron >= 2, "le 2e site de fer est BATI (avant-poste de fer n°2)", tostring(iron))
        ctx.check((ext and ext.lost or 99) <= 1, "survie : au plus 1 PNJ mort pendant la releve", tostring(ext and ext.lost))
      else
        ctx.check(st.goal_at == nil, "temoin : aucun but de releve (reglage maitre eteint)", tostring(st.goal_at))
        ctx.check(iron == 1, "temoin : le fer B n'est jamais demande (1 seul avant-poste de fer)", tostring(iron))
      end
    end,
  }
end
