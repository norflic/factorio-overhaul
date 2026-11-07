--[[
  Lot VIDEO-L5 « CONFIRMATION OBSERVÉE » : banc HORS JEU de shared/ai3/confirmation.lua. Lancement, depuis la racine du mod :
    lua5.2 tests/confirmation_test.lua
  Sections :
     1. module posé sans courant : jamais une capacité, échec à Cf.STALL avec la cause « courant » ;
     2. module posé et nourri : confirmé à la première production ;
     3. pas de second ordre pendant l'attente (Cf.holds), levé à la confirmation ET à l'échec ;
     4. jamais compté deux fois (second engagement sans effet, une catégorie par id) ;
     5. un engagé ne bloque jamais au-delà du délai (progrès continu : borne absolue Cf.MAX_AGE) ;
     6. ré-émission identique, une fois par fenêtre, sans toucher aux horloges ;
     7. compteur non monotone (coffre de sortie vidé par la collecte), première lecture sans base ;
     8. une baisse n'est jamais une production ;
     9. arrêt d'un confirmé (Cf.QUIET), sortie pleine gardée (Cf.KEEP), reprise ;
    10. perte (lost, relevé complet) ;
    11. échec puis production tardive ;
    12. fermé par défaut (intention sans id, sans objet, tick absent) ;
    13. échec non effacé par un nouvel engagement ; Cf.forget ;
    14. le défaut du 7/11 (IA_WORKFLOW D1, D2) : four à sortie pleine et foreuse sans courant ;
    15. déterminisme (ordre d'insertion), carnet sans fonction ;
    16. coût en INSTRUCTIONS (debug.sethook, jamais os.clock) ;
    17. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Les objets sont des chaînes opaques (aucun nom du jeu).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end

local PATH = "shared/ai3/confirmation.lua"
local function load_cf(mutate)
  local src = slurp(PATH)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. PATH)
  if not fn then return nil, err end
  return fn()
end

-- Sérialisation canonique (clés triées) pour comparer deux rendus.
local function ser(v)
  local t = type(v)
  if t == "table" then
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    local parts = {}
    for _, k in ipairs(ks) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then return string.format("%q", v)
  elseif t == "number" then return string.format("%.10g", v)
  else return tostring(v) end
end

local MIN = 3600

local function has_function(v, seen)
  seen = seen or {}
  if type(v) == "function" then return true end
  if type(v) ~= "table" or seen[v] then return false end
  seen[v] = true
  for k, x in pairs(v) do
    if has_function(k, seen) or has_function(x, seen) then return true end
  end
  return false
end

local function find_id(list, id)
  for _, e in ipairs(list or {}) do if e.id == id then return e end end
  return nil
end

local function run_all(Cf)
  local STALL, MAX_AGE, RETRY, QUIET = Cf.STALL, Cf.MAX_AGE, Cf.RETRY, Cf.QUIET

  -- 1. Sans courant.
  section("1. module pose sans courant")
  do
    local b = Cf.new()
    check(Cf.engage(b, { id = 1, item = "objet-a", rate = 2 }, 0) == true, "1 : engagement")
    local failed_at, first = nil, nil
    for t = MIN, STALL + MIN, MIN do
      local r = Cf.step(b, { [1] = { count = 0, cause = "courant" } }, t)
      if t < STALL then
        check((r.cap["objet-a"] or 0) == 0, "1 : jamais une capacite avant l'echec (t=" .. t .. ")")
        check((r.pending["objet-a"] or 0) == 2, "1 : engage compte en attente (t=" .. t .. ")")
      end
      if #r.failed_now > 0 and not failed_at then failed_at, first = t, r.failed_now[1] end
    end
    check(failed_at == STALL, "1 : echec a Cf.STALL exactement (" .. tostring(failed_at) .. ")")
    check(first and first.cause == "courant", "1 : cause « courant » (" .. tostring(first and first.cause) .. ")")
    check(Cf.state(b, 1) == "echec", "1 : etat echec")
    local r = Cf.step(b, { [1] = { count = 0 } }, STALL + 2 * MIN)
    check((r.cap["objet-a"] or 0) == 0 and (r.pending["objet-a"] or 0) == 0, "1 : apres l'echec : ni capacite ni attente")
    check((r.failed["objet-a"] or 0) == 2, "1 : poids compte en echec")
  end

  -- 2. Nourri.
  section("2. module pose et nourri")
  do
    local b = Cf.new()
    Cf.engage(b, { id = 2, item = "objet-a", rate = 3, base = 0 }, 0)
    local r0 = Cf.step(b, { [2] = { count = 0 } }, MIN)
    check((r0.cap["objet-a"] or 0) == 0, "2 : pas de capacite avant la production")
    local r = Cf.step(b, { [2] = { count = 4 } }, 2 * MIN)
    check(#r.confirmed_now == 1 and r.confirmed_now[1].id == 2, "2 : confirme a la premiere production")
    check((r.cap["objet-a"] or 0) == 3, "2 : capacite = son poids (" .. tostring(r.cap["objet-a"]) .. ")")
    check((r.pending["objet-a"] or 0) == 0, "2 : plus en attente")
    -- Base connue : la première lecture au-dessus de la base suffit.
    local b2 = Cf.new()
    Cf.engage(b2, { id = 7, item = "objet-a", base = 0 }, 0)
    local r2 = Cf.step(b2, { [7] = { count = 9 } }, MIN)
    check(Cf.state(b2, 7) == "confirme" and (r2.cap["objet-a"] or 0) == 1, "2 : base 0, premiere lecture 9 : confirme (poids 1 par defaut)")
  end

  -- 3. Pas de second ordre pendant l'attente.
  section("3. decision suspendue pendant l'attente")
  do
    local b = Cf.new()
    Cf.engage(b, { id = 1, item = "objet-a" }, 0)
    Cf.engage(b, { id = 2, item = "objet-b", base = 0 }, 0)
    local r = Cf.step(b, {}, MIN)
    check(Cf.holds(r, "objet-a") ~= nil, "3 : objet-a suspendu tant qu'un id est engage")
    check(Cf.holds(r, "objet-c") == nil, "3 : un objet sans intention n'est pas suspendu")
    local ia, oa = Cf.match(b, "objet-a")
    check(ia == 1 and oa == 0, "3 : intention 1, observe 0")
    r = Cf.step(b, { [2] = { count = 1 } }, 2 * MIN)
    check(Cf.holds(r, "objet-b") == nil, "3 : confirmation : suspension levee")
    local ib, ob = Cf.match(b, "objet-b")
    check(ib == 1 and ob == 1, "3 : intention et observation concordent")
    local held_until = nil
    for t = 3 * MIN, STALL + MIN, MIN do
      r = Cf.step(b, {}, t)
      if Cf.holds(r, "objet-a") then held_until = t end
    end
    check(Cf.holds(r, "objet-a") == nil, "3 : echec : suspension levee")
    check(held_until ~= nil and held_until < STALL, "3 : suspendu jusqu'a l'echec seulement")
  end

  -- 4. Jamais deux fois.
  section("4. jamais compte deux fois")
  do
    local b = Cf.new()
    check(Cf.engage(b, { id = 5, item = "objet-a", rate = 2, base = 0 }, 0) == true, "4 : premier engagement")
    local ok, why = Cf.engage(b, { id = 5, item = "objet-a", rate = 2, base = 0 }, MIN)
    check(ok == false and why ~= nil, "4 : second engagement du meme id sans effet")
    local ok2 = Cf.engage(b, { id = 5, item = "objet-b" }, MIN)
    check(ok2 == false, "4 : meme id pour un autre objet refuse")
    local r = Cf.step(b, { [5] = { count = 1 } }, 2 * MIN)
    check((r.cap["objet-a"] or 0) == 2, "4 : capacite comptee une fois (" .. tostring(r.cap["objet-a"]) .. ")")
    -- Une catégorie par id, sur un carnet mêlé (tous les états).
    local b2 = Cf.new()
    for i = 1, 12 do Cf.engage(b2, { id = i, item = (i % 2 == 0) and "objet-a" or "objet-b", rate = i, base = 0 }, 0) end
    local total = 0
    for i = 1, 12 do total = total + i end
    -- 1-3 confirmés, 4-6 confirmés puis arrêtés (sortie / courant), 7-9 engagés, 10-12 en échec
    local obs = {}
    for i = 1, 6 do obs[i] = { count = 1 } end
    Cf.step(b2, obs, MIN)
    for t = 2 * MIN, STALL, MIN do
      local o = {}
      for i = 1, 3 do o[i] = { count = t } end
      o[4] = { count = 1, cause = "sortie" }
      o[5] = { count = 1, cause = "courant" }
      o[6] = { count = 1, cause = "sortie" }
      Cf.step(b2, o, t)
    end
    -- engagés de plus, récents
    for i = 7, 9 do Cf.forget(b2, i) Cf.engage(b2, { id = i, item = (i % 2 == 0) and "objet-a" or "objet-b", rate = i }, STALL + QUIET) end
    local o = {}
    for i = 1, 3 do o[i] = { count = 2 * STALL } end
    local r2 = Cf.step(b2, o, STALL + QUIET + MIN)
    local sum = 0
    for _, it in ipairs(r2.items) do
      sum = sum + (r2.cap[it] or 0) + (r2.pending[it] or 0) + (r2.stopped[it] or 0) + (r2.failed[it] or 0)
    end
    check(sum == total, "4 : capacite + attente + arretes + echecs = poids total (" .. sum .. " contre " .. total .. ")")
    check(r2.n.confirme + r2.n.arrete + r2.n.engage + r2.n.echec == 12, "4 : 12 ids, un etat chacun")
  end

  -- 5. Borne absolue.
  section("5. un engage ne bloque jamais au-dela du delai")
  do
    local b = Cf.new()
    Cf.engage(b, { id = 1, item = "objet-a", progress = 0 }, 0)
    local failed_at = nil
    local step = MIN / 2
    for k = 1, math.floor(MAX_AGE / step) + 4 do
      local t = k * step
      -- progrès à chaque lecture, jamais de production
      local r = Cf.step(b, { [1] = { count = 0, progress = k } }, t)
      if #r.failed_now > 0 and not failed_at then failed_at = t end
      -- un engagement répété ne doit rien repousser
      Cf.engage(b, { id = 1, item = "objet-a", progress = 0 }, t)
    end
    check(failed_at == MAX_AGE, "5 : progres continu : echec a Cf.MAX_AGE (" .. tostring(failed_at) .. ")")
    -- Propriété : quel que soit le motif de progrès, aucun engagé ne survit à t0 + MAX_AGE.
    local seed = 12345
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end
    local worst = 0
    for trial = 1, 20 do
      local bb = Cf.new()
      local t0 = rnd(5) * MIN
      Cf.engage(bb, { id = trial, item = "objet-a", progress = 0 }, t0)
      local p, t = 0, t0
      while Cf.state(bb, trial) == "engage" and t < t0 + 3 * MAX_AGE do
        t = t + (1 + rnd(4)) * MIN / 2
        if rnd(3) > 0 then p = p + 1 end
        Cf.step(bb, { [trial] = { count = 0, progress = p } }, t)
      end
      if t - t0 > worst then worst = t - t0 end
    end
    check(worst <= MAX_AGE + 2 * MIN, "5 : 20 motifs : echec au plus a Cf.MAX_AGE (+ un pas de lecture) (" .. worst / MIN .. " min)")
    -- Sans progrès : échec à STALL, même avec des ré-émissions entre-temps.
    local b3 = Cf.new()
    Cf.engage(b3, { id = 9, item = "objet-a" }, 0)
    local fail3, retries = nil, 0
    for t = MIN, STALL + MIN, MIN do
      local r = Cf.step(b3, {}, t)
      retries = retries + #r.retry
      if #r.failed_now > 0 and not fail3 then fail3 = t end
    end
    check(fail3 == STALL and retries >= 1, "5 : sans progres : echec a Cf.STALL malgre " .. retries .. " re-emission(s) (" .. tostring(fail3) .. ")")
  end

  -- 6. Ré-émission identique.
  section("6. re-emission identique")
  do
    local spec = { gen = "gabarit-x", args = { 3, "nord" }, pos = { x = 12, y = -4 } }
    local b = Cf.new()
    Cf.engage(b, { id = "m-1", item = "objet-a", recipe = "recette-a", rate = 2, spec = spec }, 0)
    local times = {}
    local last = nil
    for t = MIN, STALL - MIN, MIN do
      local r = Cf.step(b, {}, t)
      for _, e in ipairs(r.retry) do times[#times + 1] = t last = e end
    end
    check(#times == 1 and times[1] == RETRY, "6 : une re-emission a Cf.RETRY, aucune avant ni a chaque pensee (" .. table.concat(times, ",") .. ")")
    check(last and ser(last.spec) == ser(spec), "6 : specification rendue identique")
    check(last and last.id == "m-1" and last.item == "objet-a" and last.recipe == "recette-a" and last.rate == 2, "6 : meme id, objet, recette, poids")
    check(last and last.spec ~= spec, "6 : une copie (l'appelant ne modifie pas le carnet)")
    -- Avec une fenêtre plus longue : une re-émission par fenêtre de Cf.RETRY.
    Cf.STALL = 4 * RETRY
    local b2 = Cf.new()
    Cf.engage(b2, { id = 3, item = "objet-a" }, 0)
    local t2, tries = {}, 0
    for t = MIN, Cf.STALL - MIN, MIN do
      local r = Cf.step(b2, {}, t)
      for _, e in ipairs(r.retry) do t2[#t2 + 1] = t / MIN tries = e.tries end
    end
    Cf.STALL = STALL
    check(#t2 == 3 and tries == 3, "6 : fenetre de 4 x Cf.RETRY : 3 re-emissions (" .. table.concat(t2, ",") .. ")")
    -- Le progrès remet la fenêtre de ré-émission à zéro (le chantier avance : rien à relancer).
    local b3 = Cf.new()
    Cf.engage(b3, { id = 4, item = "objet-a", progress = 0 }, 0)
    local n3 = 0
    for t = MIN, STALL - MIN, MIN do
      local r = Cf.step(b3, { [4] = { progress = t / MIN } }, t)
      n3 = n3 + #r.retry
    end
    check(n3 == 0, "6 : chantier qui avance : aucune re-emission (" .. n3 .. ")")
  end

  -- 7. Compteur non monotone.
  section("7. compteur non monotone, premiere lecture sans base")
  do
    local b = Cf.new()
    Cf.engage(b, { id = 1, item = "objet-a" }, 0)
    Cf.step(b, { [1] = { count = 5 } }, MIN)
    check(Cf.state(b, 1) == "engage", "7 : premiere lecture sans base : reference seulement (un reste n'est pas une preuve)")
    Cf.step(b, { [1] = { count = 0 } }, 2 * MIN)
    check(Cf.state(b, 1) == "engage", "7 : coffre vide par la collecte : pas une production")
    Cf.step(b, { [1] = { count = 3 } }, 3 * MIN)
    check(Cf.state(b, 1) == "confirme", "7 : hausse apres la collecte : confirme")
    -- Base au-dessus de la première lecture (coffre vidé avant la lecture), puis hausse.
    local b2 = Cf.new()
    Cf.engage(b2, { id = 2, item = "objet-a", base = 10 }, 0)
    Cf.step(b2, { [2] = { count = 4 } }, MIN)
    check(Cf.state(b2, 2) == "engage", "7 : lecture sous la base : pas une production")
    Cf.step(b2, { [2] = { count = 6 } }, 2 * MIN)
    check(Cf.state(b2, 2) == "confirme", "7 : hausse depuis la lecture precedente : confirme")
    -- Lectures non finies ignorées.
    local b3 = Cf.new()
    Cf.engage(b3, { id = 3, item = "objet-a", base = 0 }, 0)
    Cf.step(b3, { [3] = { count = 0 / 0 } }, MIN)
    Cf.step(b3, { [3] = { count = math.huge } }, 2 * MIN)
    check(Cf.state(b3, 3) == "engage", "7 : NaN et infini ne sont pas des lectures")
  end

  -- 8. Baisse.
  section("8. une baisse n'est jamais une production")
  do
    local b = Cf.new()
    Cf.engage(b, { id = 1, item = "objet-a" }, 0)
    local conf = false
    for k = 1, 10 do
      local r = Cf.step(b, { [1] = { count = 100 - 7 * k, cause = "entree" } }, k * MIN)
      if #r.confirmed_now > 0 then conf = true end
    end
    check(not conf and Cf.state(b, 1) == "echec", "8 : lectures en baisse : jamais confirme, echec a Cf.STALL")
  end

  -- 9. Arrêt d'un confirmé.
  section("9. arret d'un confirme, sortie pleine gardee, reprise")
  do
    local b = Cf.new()
    Cf.engage(b, { id = 1, item = "objet-a", rate = 5, base = 0 }, 0)
    Cf.engage(b, { id = 2, item = "objet-a", rate = 7, base = 0 }, 0)
    Cf.step(b, { [1] = { count = 1 }, [2] = { count = 1 } }, MIN)
    local stop_t = nil
    local r
    for t = 2 * MIN, MIN + QUIET + MIN, MIN do
      r = Cf.step(b, { [1] = { count = 1, cause = "sortie" }, [2] = { count = 1, cause = "courant" } }, t)
      if #r.stopped_now > 0 and not stop_t then stop_t = t end
    end
    check(stop_t == MIN + QUIET, "9 : arrete apres Cf.QUIET sans hausse (" .. tostring(stop_t) .. ")")
    check(Cf.state(b, 1) == "arrete" and Cf.state(b, 2) == "arrete", "9 : les deux arretes")
    check((r.cap["objet-a"] or 0) == 5, "9 : sortie pleine : capacite gardee ; sans courant : retiree (" .. tostring(r.cap["objet-a"]) .. ")")
    check((r.stopped["objet-a"] or 0) == 7, "9 : sans courant compte en arretes")
    check(Cf.holds(r, "objet-a") == nil, "9 : un arrete ne suspend pas la decision (le plafond L13 borne les poses)")
    r = Cf.step(b, { [1] = { count = 2 }, [2] = { count = 2 } }, MIN + QUIET + 2 * MIN)
    check(Cf.state(b, 2) == "confirme" and (r.cap["objet-a"] or 0) == 12, "9 : hausse : de nouveau confirme, capacite 12")
    -- La production a effacé la vieille cause « sortie » : un nouvel arrêt sans cause lue ne garde pas la capacité.
    local t1 = MIN + QUIET + 2 * MIN
    for t = t1 + MIN, t1 + QUIET, MIN do r = Cf.step(b, { [1] = { count = 2 }, [2] = { count = 2 } }, t) end
    check(Cf.state(b, 1) == "arrete" and (r.cap["objet-a"] or 0) == 0 and (r.stopped["objet-a"] or 0) == 12,
      "9 : nouvel arret sans cause : la vieille « sortie » ne garde rien (" .. tostring(r.cap["objet-a"]) .. ")")
  end

  -- 10. Perte.
  section("10. perte")
  do
    local b = Cf.new()
    Cf.engage(b, { id = 1, item = "objet-a" }, 0)
    Cf.engage(b, { id = 2, item = "objet-a", base = 0 }, 0)
    Cf.engage(b, { id = 3, item = "objet-a" }, 0)
    local r = Cf.step(b, { [1] = { lost = true }, [2] = { count = 1 } }, MIN)
    check(#r.lost_now == 1 and r.lost_now[1].id == 1 and r.lost_now[1].cause == Cf.CAUSE_LOST, "10 : lost : retire avec la cause « perdu »")
    check(Cf.state(b, 1) == nil, "10 : id perdu oublie")
    r = Cf.step(b, { [2] = { count = 2 } }, 2 * MIN, { complete = true })
    check(find_id(r.lost_now, 3) ~= nil and Cf.state(b, 3) == nil, "10 : releve complet : id absent perdu")
    check(Cf.state(b, 2) == "confirme", "10 : id lu garde")
    check(Cf.holds(r, "objet-a") == nil, "10 : plus aucun engage : plus de suspension")
  end

  -- 11. Production tardive.
  section("11. echec puis production tardive")
  do
    local b = Cf.new()
    Cf.engage(b, { id = 1, item = "objet-a", rate = 4 }, 0)
    for t = MIN, STALL, MIN do Cf.step(b, { [1] = { count = 0, cause = "courant" } }, t) end
    check(Cf.state(b, 1) == "echec", "11 : echec")
    local r = Cf.step(b, { [1] = { count = 2 } }, STALL + MIN)
    check(Cf.state(b, 1) == "confirme" and (r.cap["objet-a"] or 0) == 4, "11 : la production tardive est une capacite reelle")
    check(r.confirmed_now[1] and r.confirmed_now[1].late == true, "11 : marquee tardive")
    check(Cf.holds(r, "objet-a") == nil, "11 : aucune suspension")
  end

  -- 12. Fermé par défaut.
  section("12. ferme par defaut")
  do
    local b = Cf.new()
    check(Cf.engage(b, { item = "objet-a" }, 0) == false, "12 : intention sans id refusee")
    check(Cf.engage(b, { id = {}, item = "objet-a" }, 0) == false, "12 : id table refuse")
    check(Cf.engage(b, { id = 0 / 0, item = "objet-a" }, 0) == false, "12 : id NaN refuse")
    check(Cf.engage(b, { id = 1 }, 0) == false, "12 : intention sans objet refusee")
    check(Cf.engage(b, { id = 1, item = "objet-a" }, nil) == false, "12 : tick absent refuse")
    check(Cf.engage(nil, { id = 1, item = "objet-a" }, 0) == false, "12 : carnet absent refuse")
    Cf.engage(b, { id = 1, item = "objet-a" }, 0)
    local r, why = Cf.step(b, {}, nil)
    check(r == nil and why ~= nil, "12 : pas sans tick : rien n'avance")
    check(Cf.state(b, 1) == "engage", "12 : etat garde")
    local ok = Cf.engage(b, { id = 2, item = "objet-a", rate = -3 }, 0)
    local r2 = Cf.step(b, { [2] = { count = 1 } }, MIN)
    check(ok and (r2.pending["objet-a"] or 0) == 2, "12 : poids negatif ramene a 1")
  end

  -- 13. Échec non effacé par un nouvel engagement.
  section("13. echec garde, Cf.forget")
  do
    local b = Cf.new()
    Cf.engage(b, { id = 1, item = "objet-a" }, 0)
    for t = MIN, STALL, MIN do Cf.step(b, {}, t) end
    local ok = Cf.engage(b, { id = 1, item = "objet-a" }, STALL + MIN)
    check(ok == false and Cf.state(b, 1) == "echec", "13 : re-engager un echec ne le rouvre pas (aucune suspension sans fin)")
    check(Cf.forget(b, 1) == true and Cf.state(b, 1) == nil, "13 : forget efface")
    check(Cf.engage(b, { id = 1, item = "objet-a" }, STALL + MIN) == true, "13 : apres forget : intention nouvelle")
    check(Cf.forget(b, 99) == false, "13 : forget d'un id inconnu")
    -- Liste triée du carnet tenue à l'engagement, à l'oubli et à la perte ; rebâtie si elle manque (carnet d'une autre version).
    local b2 = Cf.new()
    for _, id in ipairs({ 9, "m-b", 3, "m-a", 12, 1 }) do Cf.engage(b2, { id = id, item = "objet-a" }, 0) end
    Cf.forget(b2, 3)
    Cf.step(b2, { [12] = { lost = true } }, MIN)
    check(ser(b2.list) == ser({ 1, 9, "m-a", "m-b" }), "13 : liste triee tenue (" .. ser(b2.list) .. ")")
    b2.list = nil
    local r = Cf.step(b2, {}, 2 * MIN)
    check(r and r.n.engage == 4 and ser(b2.list) == ser({ 1, 9, "m-a", "m-b" }), "13 : carnet sans liste : rebatie")
  end

  -- 14. Le défaut du 7/11.
  section("14. defaut du 7/11 : four a sortie pleine, foreuse sans courant")
  do
    local b = Cf.new()
    -- four du champ : produit, remplit son coffre, puis plus rien ne sort (collecte non servie)
    Cf.engage(b, { id = 101, item = "plaque-x", rate = 18.75, base = 0 }, 0)
    -- foreuse électrique posée : jamais de courant
    Cf.engage(b, { id = 102, item = "minerai-x", rate = 30, base = 0 }, 0)
    local r
    for t = MIN, 40 * MIN, MIN do
      local c = math.min(t / MIN * 18, 100)
      r = Cf.step(b, { [101] = { count = c, cause = (c >= 100) and "sortie" or nil }, [102] = { count = 0, cause = "courant" } }, t)
    end
    check(Cf.state(b, 102) == "echec" and (r.cap["minerai-x"] or 0) == 0, "14 : foreuse sans courant : jamais une capacite")
    check((r.cap["plaque-x"] or 0) == 18.75, "14 : four a sortie pleine : capacite gardee (la collecte manque, pas le four)")
    check(Cf.state(b, 101) == "arrete", "14 : four arrete (cause « sortie »)")
  end

  -- 15. Déterminisme.
  section("15. determinisme, carnet sans fonction")
  do
    local function scenario(order)
      local b = Cf.new()
      local ids = {}
      for i = 1, 30 do ids[i] = (i % 3 == 0) and ("m-" .. i) or i end
      local seq = {}
      for i = 1, 30 do seq[i] = ids[order[i]] end
      for _, id in ipairs(seq) do
        local n = type(id) == "number" and id or tonumber(id:sub(3))
        Cf.engage(b, { id = id, item = "objet-" .. (n % 4), rate = n, base = (n % 2 == 0) and 0 or nil,
          spec = { k = n, f = function() end } }, 0)
      end
      local out = {}
      for t = MIN, 30 * MIN, MIN do
        local obs = {}
        for _, id in ipairs(seq) do
          local n = type(id) == "number" and id or tonumber(id:sub(3))
          if n % 5 ~= 0 then obs[id] = { count = (n % 3 == 0) and 0 or math.floor(t / MIN / (1 + n % 4)), cause = (n % 7 == 0) and "entree" or nil } end
          if n == 11 and t == 12 * MIN then obs[id] = { lost = true } end
        end
        out[#out + 1] = ser(Cf.step(b, obs, t))
      end
      return table.concat(out, "\n"), b
    end
    local fwd, rev, mix = {}, {}, {}
    for i = 1, 30 do fwd[i] = i rev[i] = 31 - i mix[i] = ((i * 7) % 30) + 1 end
    local a, ba = scenario(fwd)
    local c = scenario(rev)
    local d = scenario(mix)
    check(a == c and a == d, "15 : meme rendu quel que soit l'ordre d'insertion")
    check(not has_function(ba), "15 : carnet sans fonction (spec copiee sans sa fonction)")
  end

  -- 16. Coût en instructions.
  section("16. cout en instructions (debug.sethook)")
  do
    local function instr(fn)
      local c = 0
      debug.sethook(function() c = c + 1 end, "", 1)
      fn()
      debug.sethook()
      return c
    end
    local function steady(n)
      local b = Cf.new()
      for i = 1, n do Cf.engage(b, { id = i, item = "objet-" .. (i % 8), rate = 1, base = 0 }, 0) end
      local function obs_at(t)
        local o = {}
        for i = 1, n do
          if i % 4 == 0 then o[i] = { count = 0, cause = "courant" }
          elseif i % 4 == 1 then o[i] = { count = t }
          else o[i] = { count = 1, cause = "sortie" } end
        end
        return o
      end
      for t = MIN, 20 * MIN, MIN do Cf.step(b, obs_at(t), t) end
      local o = obs_at(21 * MIN)
      return instr(function() Cf.step(b, o, 21 * MIN) end)
    end
    local i10, i100, i1000 = steady(10), steady(100), steady(1000)
    local eb = Cf.new()
    local ie = instr(function() Cf.engage(eb, { id = 1, item = "objet-a", rate = 2, spec = { a = 1, b = { 2, 3 } } }, 0) end)
    if not quiet then
      print(string.format("   Cf.step : %d instructions pour 10 ids, %d pour 100, %d pour 1000 (%.0f par id a 1000) ; Cf.engage : %d",
        i10, i100, i1000, i1000 / 1000, ie))
    end
    check(i100 < 30000, "16 : 100 ids sous 3 x 10^4 instructions par pas (" .. i100 .. ")")
    check(i1000 < 15 * i100, "16 : croissance quasi lineaire (1000 ids < 15 x 100 ids)")
  end
end

-- Banc sur la règle d'origine.
local Cf0 = assert(load_cf())
run_all(Cf0)

-- 17. Mutants.
section("17. mutants")
local MUTANTS = {
  { "capacite comptee des l'engagement", { 'return u.state == "confirme" or (u.state == "arrete"', 'return u.state == "confirme" or u.state == "engage" or (u.state == "arrete"' } },
  { "ordre engage sans issue (aucun echec)", { "if tick - u.t0 >= Cf.MAX_AGE or idle >= Cf.STALL then", "if false then" } },
  { "progres repousse la borne absolue", { "if tick - u.t0 >= Cf.MAX_AGE or idle >= Cf.STALL then", "if idle >= Cf.STALL then" } },
  { "second ordre permis pendant l'attente", { "res.hold[it] = string.format(", "local _ = string.format(" } },
  { "un id compte dans deux categories", { '  elseif u.state == "engage" then\n    res.pending', '  end if u.state == "engage" or u.state == "confirme" then\n    res.pending' } },
  { "re-engagement remet les horloges a zero", { "  if old then\n", "  if false then\n" } },
  { "re-emission remet l'horloge du progres", { "u.t_retry, u.tries = tick, u.tries + 1", "u.t_retry, u.tries, u.t_prog = tick, u.tries + 1, tick" } },
  { "re-emission a chaque pensee", { "(u.t_retry == nil or tick - u.t_retry >= Cf.RETRY)", "true" } },
  { "une baisse comptee comme production", { "local rose = ref ~= nil and o.count > ref", "local rose = ref ~= nil and o.count ~= ref" } },
  { "une production n'efface pas la cause d'un arret passe", { "if rose and not given then u.cause = nil end", "" } },
  { "premiere lecture sans base confirme (x or 0)", { "if ref == nil then ref = u.base end", "if ref == nil then ref = u.base or 0 end" } },
  { "un echec suspend encore la decision", { 'else res.failed[it] = (res.failed[it] or 0) + u.rate end', 'else res.failed[it] = (res.failed[it] or 0) + u.rate local h = oldest[it] or { n = 0, t0 = u.t0 } h.n = h.n + 1 oldest[it] = h end' } },
  { "arret jamais detecte", { 'elseif u.state == "confirme" and Cf.QUIET ~= nil and', 'elseif false and' } },
  { "sortie pleine retiree de la capacite", { "Cf.KEEP = { sortie = true }", "Cf.KEEP = {}" } },
  { "perte ignoree", { '(type(o) == "table" and o.lost) or ', 'false or ' } },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local mod, err = load_cf(m[2])
  local dead
  if not mod then
    quiet = false
    check(false, "mutant '" .. m[1] .. "' : " .. tostring(err))
    quiet = true
    dead = false
  else
    local p0, f0 = passes, failures
    local okrun, e = pcall(run_all, mod)
    local nf = failures - f0
    dead = (not okrun) or nf > 0
    passes, failures = p0, f0
    quiet = false
    print(string.format("   %s : %s", m[1], (not okrun) and ("PLANTAGE " .. tostring(e)) or (nf .. " controle(s) en echec")))
    quiet = true
  end
  if dead then killed = killed + 1 else
    quiet = false
    check(false, "mutant SURVIVANT : " .. m[1])
    quiet = true
  end
end
quiet = false
print(string.format("   mutants refuses : %d / %d", killed, #MUTANTS))
check(killed == #MUTANTS, "tous les mutants sont refuses")

print(string.format("[CONFIRMATION] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refuses", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
