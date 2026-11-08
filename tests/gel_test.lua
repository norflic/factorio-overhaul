--[[
  Lot X10-GEL : LA règle commune de zone et de réveil (shared/faction/gel.lua), hors jeu. fo-logs/2026-11-07_X10/L1_CRITERES.md §3.2.
    G1  poste figé, joueur dans la boîte de réveil (224) : « eveille », « joueur proche » ; entre 224 et 256 : reste figé.
    G2  poste actif, joueur à moins de 256 : jamais figé, le calme repart de zéro.
    G3  poste actif, aucun joueur ni cause : figé à Gel.CALM ticks de calme exactement, pas un tick avant.
    G4  causes de faction (S10) : menace, attaque, perte, ennemi près du QG : réveil ; votre équipe jamais figée.
    G5  garde fermée : sans boîte (aucun point), sans liste de joueurs : jamais figé ; réglage éteint : tout réveillé.
    G6  poste inapte (unfit) ou menace locale (hazard) : réveil avec cette cause, calme remis à zéro.
    G7  Gel.decide_all (raccourci de la faction) = Gel.decide poste par poste : 4 000 tirages (postes, joueurs, causes, ticks).
    G9  garnisons (Q7) : Gel.soldier_unfit (votre équipe, groupe, mission, ordre changé, blessé, en route : jamais figé ; au repos à son
        point : apte, au bord exact du rayon + marge compris) ; Gel.soldier_point (clé « rôle:x:y:aid » de shared/ai3/soldats.lua).
    Mutants (texte de la source changé) : tous vus.
  Usage : lua5.2 tests/gel_test.lua   (depuis la racine du mod ; shared/faction/cadence.lua de la branche x10-s10 requis)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local quiet = false
local function check(c, msg)
  if c then ok_n = ok_n + 1; if not quiet and os.getenv("FO_VERBOSE") then print("[GEL] OK : " .. msg) end
  else fail_n = fail_n + 1; if not quiet then print("[GEL] ECHEC : " .. msg) end end
  return c
end

local SRC_PATH = "shared/faction/gel.lua"
local fh = assert(io.open(SRC_PATH, "rb"))
local SOURCE = fh:read("*a")
fh:close()
local function load_gel(text) return assert(load(text, "=" .. SRC_PATH))() end

local function S(o)
  o = o or {}
  local army = o.army_out
  if army == nil then army = false end -- armée rentrée par défaut (le calme de S10 l'exige)
  return { is_player = o.is_player, players = o.players == nil and {} or o.players, threatened_until = o.threatened_until,
    attack_t = o.attack_t, hit_t = o.hit_t, lost_t = o.lost_t, base_alert = o.base_alert, army_out = army, off = o.off }
end
if not pcall(require, "shared.faction.cadence") then
  print("[GEL] ECHEC : shared/faction/cadence.lua absent (branche x10-s10 a fusionner)")
  os.exit(1)
end

local function cases(G)
  local f0 = fail_n
  local pts = { { x = 0, y = 0 }, { x = 10, y = 4 } }
  local bx = G.boxes(pts)

  -- G1
  do
    local st = { frozen = true }
    local a, why = G.decide(st, bx, S({ players = { { x = 10 + 223, y = 0 } } }), nil, 1000)
    check(a == "eveille" and why == "joueur proche", "G1 : joueur a 223 tuiles de la boite : reveil (" .. tostring(a) .. ", " .. tostring(why) .. ")")
    a = G.decide(st, bx, S({ players = { { x = 10 + 240, y = 0 } } }), nil, 1000)
    check(a == nil, "G1 : joueur a 240 tuiles : reste fige (hysteresis)")
  end
  -- G2
  do
    local st = { frozen = false, calm = 10 }
    local a = G.decide(st, bx, S({ players = { { x = 10 + 250, y = 0 } } }), nil, 5000)
    check(a == nil and st.calm == nil, "G2 : joueur a 250 tuiles : jamais fige, calme remis a zero")
  end
  -- G3
  do
    local st = { frozen = false }
    local s = S({ players = { { x = 10 + 300, y = 0 } } })
    local a0 = G.decide(st, bx, s, nil, 100)
    local a1 = G.decide(st, bx, s, nil, 100 + G.CALM - 1)
    local a2, why = G.decide(st, bx, s, nil, 100 + G.CALM)
    check(a0 == nil and a1 == nil and a2 == "fige" and why == "loin et calme", "G3 : fige a " .. G.CALM .. " ticks de calme exactement (" ..
      tostring(a1) .. ", " .. tostring(a2) .. ")")
  end
  -- G4
  do
    local T = 10000
    local function wake(o)
      local st = { frozen = true }
      local a, why = G.decide(st, bx, S(o), nil, T)
      return a, why
    end
    local a, w = wake({ threatened_until = T + 1 })
    check(a == "eveille" and w == "menace", "G4 : menace : reveil (" .. tostring(w) .. ")")
    a, w = wake({ attack_t = T - 100 })
    check(a == "eveille" and w == "attaque", "G4 : attaque : reveil (" .. tostring(w) .. ")")
    a, w = wake({ hit_t = T - 100 })
    check(a == "eveille" and w == "attaque", "G4 : coup recu (hit_t, S10) : reveil (" .. tostring(w) .. ")")
    a, w = wake({ lost_t = T - 100 })
    check(a == "eveille" and w == "perte", "G4 : perte : reveil (" .. tostring(w) .. ")")
    a, w = wake({ base_alert = true })
    check(a == "eveille" and w == "ennemi pres du QG", "G4 : ennemi pres du QG : reveil (" .. tostring(w) .. ")")
    a, w = wake({ army_out = true })
    check(a == "eveille" and w == "armee dehors", "G4 : armee dehors : reveil (" .. tostring(w) .. ")")
    a, w = wake({ army_out = "?" })
    check(a == "eveille", "G4 : etat de l'armee inconnu : reveil (garde fermee) (" .. tostring(w) .. ")")
    a, w = wake({ is_player = true })
    check(a == "eveille" and w == "votre equipe", "G4 : votre equipe : jamais figee (" .. tostring(w) .. ")")
    local st = { frozen = false }
    for t = 0, 3000, 20 do G.decide(st, bx, S({ is_player = true }), nil, t) end
    check(st.calm == nil, "G4 : votre equipe : le calme ne demarre jamais")
    local u, why = G.faction_cause(S({ attack_t = T - 10 }), T)
    check(u and why == "attaque", "G4 : Gel.faction_cause rend la cause de la faction")
  end
  -- G5
  do
    local st = { frozen = false }
    for t = 0, 2000, 20 do G.decide(st, G.boxes({}), S(), nil, t) end
    check(st.calm == nil, "G5 : sans point : jamais fige (zone inconnue)")
    st = { frozen = false }
    local a
    for t = 0, 2000, 20 do a = G.decide(st, bx, { players = nil, army_out = false }, nil, t) or a end
    check(a == nil and st.calm == nil, "G5 : sans liste de joueurs : jamais fige")
    st = { frozen = true }
    local why
    a, why = G.decide(st, bx, S({ off = true }), nil, 10)
    check(a == "eveille" and why == "reglage", "G5 : reglage eteint : reveil (" .. tostring(why) .. ")")
  end
  -- G6
  do
    local st = { frozen = true }
    local a, why = G.decide(st, bx, S(), { hazard = "ennemi au poste" }, 10)
    check(a == "eveille" and why == "ennemi au poste", "G6 : menace locale : reveil (" .. tostring(why) .. ")")
    st = { frozen = false, calm = 0 }
    a, why = G.decide(st, bx, S(), { unfit = "a relire" }, 5000)
    check(a == nil and st.calm == nil and why == "a relire", "G6 : poste inapte : jamais fige, calme remis a zero")
  end
  -- G7 équivalence du raccourci
  do
    local seed = 7112026
    -- bits hauts (8/11 : les bits bas d'un générateur congruentiel modulo 2^31 ont une période courte, voir G10)
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return math.floor(seed / 65536) % n end
    local diff = 0
    for trial = 1, 200 do
      local posts_a, posts_b, allp = {}, {}, {}
      for i = 1, 1 + rnd(6) do
        local p = { { x = rnd(2000) - 1000, y = rnd(2000) - 1000 } }
        p[2] = { x = p[1].x + rnd(20), y = p[1].y + rnd(20) }
        for _, q in ipairs(p) do allp[#allp + 1] = q end
        local b = (rnd(10) == 0) and nil or G.boxes(p)
        local fz = rnd(2) == 0
        local unfit = (rnd(8) == 0) and "a relire" or nil
        posts_a[#posts_a + 1] = { id = i, st = { frozen = fz }, boxes = b, unfit = unfit }
        posts_b[#posts_b + 1] = { id = i, st = { frozen = fz }, boxes = b, unfit = unfit }
      end
      local fbox = G.boxes(allp)
      for step = 1, 20 do
        local tick = step * 20 * (1 + rnd(40))
        local players = {}
        for _ = 1, rnd(3) do players[#players + 1] = { x = rnd(4000) - 2000, y = rnd(4000) - 2000 } end
        local s = S({ players = players, attack_t = (rnd(15) == 0) and tick - 10 or nil, army_out = rnd(20) == 0, off = rnd(40) == 0 })
        local out_a = G.decide_all(posts_a, s, fbox, tick)
        local out_b = {}
        for _, p in ipairs(posts_b) do
          local a, why = G.decide(p.st, p.boxes, s, p, tick)
          if a then out_b[#out_b + 1] = { id = p.id, action = a, cause = why } end
        end
        local function key(list) local t = {} for _, o in ipairs(list) do t[#t + 1] = o.id .. ":" .. o.action .. ":" .. tostring(o.cause) end return table.concat(t, ";") end
        if key(out_a) ~= key(out_b) then diff = diff + 1 end
        for k, p in ipairs(posts_a) do
          if p.st.calm ~= posts_b[k].st.calm then diff = diff + 1 end
        end
        -- l'action s'applique (le runtime écrit frozen)
        for _, o in ipairs(out_a) do posts_a[o.id].st.frozen = (o.action == "fige") end
        for _, o in ipairs(out_b) do posts_b[o.id].st.frozen = (o.action == "fige") end
      end
    end
    check(diff == 0, "G7 : decide_all = decide poste par poste sur 4 000 tirages (" .. diff .. " ecart(s))")
  end
  -- G8 raccourci de la faction : bande de 224 à 256 tuiles, joueurs inconnus
  do
    local p = { { id = 1, st = { frozen = false }, boxes = bx } }
    local fbox = G.boxes(pts)
    local s = S({ players = { { x = 10 + 240, y = 0 } } })
    local froze = false
    for t = 0, 3000, 20 do
      for _, o in ipairs(G.decide_all(p, s, fbox, t)) do if o.action == "fige" then froze = true end end
    end
    check(not froze, "G8 : joueur a 240 tuiles (entre 224 et 256) : decide_all ne fige jamais")
    p = { { id = 1, st = { frozen = false }, boxes = bx }, { id = 2, st = { frozen = true }, boxes = bx } }
    froze = false
    local woke = false
    for t = 0, 3000, 20 do
      for _, o in ipairs(G.decide_all(p, { players = nil, army_out = false }, fbox, t)) do
        if o.action == "fige" then froze = true end
        if o.action == "eveille" and o.cause == "joueurs inconnus" then woke = true; p[2].st.frozen = false end
      end
    end
    check(not froze and woke, "G8 : joueurs inconnus : decide_all ne fige rien et reveille le poste fige")
  end
  -- G10 (C19, 8/11, décision du lead) : SAUTER les postes figés calmes quand la faction est loin et calme (Gel.skip_quiet, Gel.quiet)
  -- donne exactement la décision de TOUS les postes : mêmes actions, mêmes causes, même état (calm, frozen), sur 4 000 tirages.
  do
    local seed = 8112026
    -- bits HAUTS du générateur (les bits bas d'un générateur congruentiel modulo 2^31 ont une période courte : avec `seed % n`, aucun
    -- poste n'était à la fois figé et calme au moment d'un saut, et G10 ne prouvait rien)
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return math.floor(seed / 65536) % n end
    local diff, skipped, skips = 0, 0, 0
    for trial = 1, 200 do
      local posts_a, posts_b, allp = {}, {}, {}
      for i = 1, 1 + rnd(8) do
        local p = { { x = rnd(2000) - 1000, y = rnd(2000) - 1000 } }
        p[2] = { x = p[1].x + rnd(20), y = p[1].y + rnd(20) }
        for _, q in ipairs(p) do allp[#allp + 1] = q end
        local b = (rnd(12) == 0) and nil or G.boxes(p)
        local fz = rnd(3) > 0
        local unfit = (rnd(8) == 0) and "a relire" or nil
        local hz = (rnd(10) == 0) and "ennemi pres du poste" or nil
        posts_a[#posts_a + 1] = { id = i, st = { frozen = fz }, boxes = b, unfit = unfit, hazard = hz }
        posts_b[#posts_b + 1] = { id = i, st = { frozen = fz }, boxes = b, unfit = unfit, hazard = hz }
      end
      local fbox = (rnd(15) == 0) and nil or G.boxes(allp)
      for step = 1, 20 do
        local tick = step * 20 * (1 + rnd(40))
        local players = {}
        for _ = 1, rnd(3) do players[#players + 1] = { x = rnd(6000) - 3000, y = rnd(6000) - 3000 } end
        if rnd(30) == 0 then players = nil end
        local s = S({ players = players, attack_t = (rnd(12) == 0) and tick - 10 or nil, threatened_until = (rnd(25) == 0) and tick + 50 or nil,
          army_out = rnd(20) == 0, off = rnd(40) == 0 })
        if players == nil then s.players = nil end
        local out_a = G.decide_all(posts_a, s, fbox, tick)
        local sub = posts_b
        if G.skip_quiet(s, fbox, tick) then
          skips = skips + 1
          sub = {}
          for _, p in ipairs(posts_b) do if G.quiet(p) then skipped = skipped + 1 else sub[#sub + 1] = p end end
        end
        local out_b = G.decide_all(sub, s, fbox, tick)
        local function key(list) local t = {} for _, o in ipairs(list) do t[#t + 1] = o.id .. ":" .. o.action .. ":" .. tostring(o.cause) end return table.concat(t, ";") end
        if key(out_a) ~= key(out_b) then diff = diff + 1 end
        for k, p in ipairs(posts_a) do
          if p.st.calm ~= posts_b[k].st.calm then diff = diff + 1 end
        end
        for _, o in ipairs(out_a) do posts_a[o.id].st.frozen = (o.action == "fige") end
        for _, o in ipairs(out_b) do posts_b[o.id].st.frozen = (o.action == "fige") end
      end
    end
    check(diff == 0 and skips > 200 and skipped > 500, string.format(
      "G10 : postes figes calmes sautes (faction loin et calme) = decision de tous les postes : %d ecart(s) sur 4 000 tirages (%d guets sautes, %d postes sautes)",
      diff, skips, skipped))
  end
  -- G11 (C19) : guets étalés : aucun tick de la période ne porte deux guets ; chaque faction 1 à SLOT_MAX a un tick propre par kind,
  -- une fois par période (retard maximal d'un réveil par le guet ≤ Gel.GUET) ; Gel.slot et Gel.guet_of se répondent ; guet commun
  -- aux ticks 0 (usines) et 1 (garnisons) ; faction sans tick propre (0, 10, 2,5, nom) : nil (guettée au guet commun).
  do
    local bad = 0
    local seen = { usines = {}, garnisons = {} }
    for k = 0, G.GUET - 1 do
      local a, b = G.guet_of(k, "usines"), G.guet_of(k, "garnisons")
      if a ~= nil and b ~= nil then bad = bad + 1 end
      for kind, w in pairs({ usines = a, garnisons = b }) do
        if type(w) == "number" then
          if G.slot(w, kind) ~= k then bad = bad + 1 end
          seen[kind][w] = (seen[kind][w] or 0) + 1
        end
      end
    end
    for fid = 1, G.SLOT_MAX do
      if seen.usines[fid] ~= 1 or seen.garnisons[fid] ~= 1 then bad = bad + 1 end
    end
    check(bad == 0 and G.SLOT_MAX >= 4, "G11 : aucun tick ne porte deux guets ; factions 1 a " .. G.SLOT_MAX .. " guettees une fois par periode de "
      .. G.GUET .. " ticks, par kind (" .. bad .. " ecart(s))")
    check(G.guet_of(0, "usines") == "commun" and G.guet_of(1, "garnisons") == "commun" and G.slot(0, "usines") == nil and G.slot(G.SLOT_MAX + 1, "usines") == nil
      and G.slot(2.5, "garnisons") == nil and G.slot("banc:A", "usines") == nil, "G11 : guet commun aux ticks 0 et 1 ; sans tick propre : nil")
  end
  -- G9 garnisons
  do
    local function U(o) return G.soldier_unfit(o) end
    local ok = { health = 1, d = 3 }
    check(U(ok) == nil, "G9 : soldat au repos a son point, en pleine sante : apte")
    check(U({ health = 1, d = 18 + 6 }) == nil and U({ health = 1, d = 18 + 6.01 }) == "en route",
      "G9 : garnison du QG : apte a 24 tuiles de son point, en route au-dela")
    check(U({ role = "guard", health = 1, d = 10 }) == nil and U({ role = "guard", health = 1, d = 10.5 }) == "en route",
      "G9 : garde : apte a 10 tuiles (4 + 6), en route au-dela")
    check(U({ role = "patrol", health = 1, d = 18 }) == nil and U({ role = "patrol", health = 1, d = 19 }) == "en route",
      "G9 : patrouille : apte a 18 tuiles (12 + 6), en route au-dela")
    check(U({ is_player = true, health = 1, d = 0 }) == "votre equipe", "G9 : votre equipe : jamais figee (Q9)")
    check(U({ group = true, health = 1, d = 0 }) == "groupe", "G9 : soldat d'un groupe : jamais fige")
    local missions = { "escort", "clear", "defense", "hunt", "muster" }
    local all = true
    for _, r in ipairs(missions) do if U({ role = r, health = 1, d = 0 }) ~= "mission" then all = false end end
    check(all, "G9 : escorte, nettoyage, defense, chasse, regroupement : missions, jamais figees")
    check(U({ changed = true, health = 1, d = 0 }) == "ordre", "G9 : ordre change : reveille")
    check(U({ health = 0.99, d = 0 }) == "blesse" and U({ d = 0 }) == "blesse", "G9 : blesse (ou sante inconnue) : jamais fige")
    check(U({ health = 1 }) == "en route", "G9 : distance inconnue : jamais fige")
    local p = G.soldier_point("guard:40:-7:", { x = 0, y = 14 })
    check(p.x == 40.5 and p.y == -6.5, "G9 : point d'une garde lu dans sa cle (40.5, -6.5)")
    p = G.soldier_point("patrol:-120:33:12", { x = 0, y = 14 })
    check(p.x == -119.5 and p.y == 33.5, "G9 : point d'une patrouille lu dans sa cle")
    p = G.soldier_point(nil, { x = 0, y = 14 })
    check(p.x == 0 and p.y == 14, "G9 : sans ordre : place au QG")
  end
  return fail_n - f0
end

cases(load_gel(SOURCE))

local MUTANTS = {
  { "cause de faction ignoree", "  if up then return true, why end\n  return false, nil", "  return false, nil" },
  { "hysteresis coupee (calme)", "if tick - st.calm >= Gel.CALM then return \"fige\", why end", "do return \"fige\", why end" },
  { "boite de gel = boite de reveil", "local box = boxes and (frozen and boxes.wake or boxes.freeze) or nil", "local box = boxes and boxes.wake or nil" },
  { "raccourci sur la boite de reveil", "not any_player_in(fbox.freeze, s.players)", "not any_player_in(fbox.wake, s.players)" },
  { "poste inapte ignore", "local block = (s.off and \"reglage\") or (post and (post.unfit or post.hazard)) or nil", "local block = (s.off and \"reglage\") or nil" },
  { "garnison : mission figee", "if not r then return \"mission\" end", "if not r then r = 18 end" },
  { "garnison : blesse fige", "o.health < 0.999 then return \"blesse\" end", "o.health < 0 then return \"blesse\" end" },
  { "garnison : votre equipe figee", "if o.is_player then return \"votre equipe\" end", "" },
  { "garnison : marge d'arrivee ignoree", "o.d > r + Gel.ARRIVED_MARGIN then", "o.d > r then" },
  { "garnison : ordre change ignore", "if o.changed then return \"ordre\" end", "" },
  { "coup recu (hit_t) oublie", "hit_t = s.hit_t, ", "" },
  { "un fige jamais relu apres une cause de faction (C19)", "  if Gel.faction_cause(s, tick) then return false end\n", "" },
  { "fige a relire saute (C19)", "p.st.frozen == true and not p.unfit and not p.hazard", "p.st.frozen == true and not p.hazard" },
  { "fige menace saute (C19)", "p.st.frozen == true and not p.unfit and not p.hazard", "p.st.frozen == true and not p.unfit" },
  { "saut avec un joueur dans la boite de la faction (C19)", "  return not any_player_in(fbox.freeze, s.players)\nend", "  return true\nend" },
  { "deux guets au meme tick (C19)", "local base = (kind == \"garnisons\") and 1 or 0", "local base = 0" },
  { "faction sans tick propre (C19)", "if fid >= 1 and fid <= Gel.SLOT_MAX then return fid end", "if fid >= 1 and fid < Gel.SLOT_MAX then return fid end" },
  { "garde fermee ouverte (joueurs inconnus)", "if type(box) ~= \"table\" or type(players) ~= \"table\" then return true end", "if type(box) ~= \"table\" or type(players) ~= \"table\" then return false end" },
}
quiet = true
local seen, missed = 0, {}
for _, mu in ipairs(MUTANTS) do
  local s, e = SOURCE:find(mu[2], 1, true)
  if not s then missed[#missed + 1] = mu[1] .. " (texte introuvable)" else
    local before = fail_n
    local okl, M = pcall(load_gel, SOURCE:sub(1, s - 1) .. mu[3] .. SOURCE:sub(e + 1))
    local okc = okl and pcall(cases, M)
    local died = (fail_n > before) or not okc or not okl
    fail_n = before
    if died then seen = seen + 1 else missed[#missed + 1] = mu[1] end
  end
end
quiet = false
check(#missed == 0, string.format("mutants : %d/%d vus%s", seen, #MUTANTS, #missed > 0 and (" ; NON VUS : " .. table.concat(missed, " ; ")) or ""))

print(string.format("[GEL] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
