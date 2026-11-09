--[[
  Lot ZERO-IDLE-3 : banc HORS JEU des PLACES ÉLASTIQUES des projets (shared/ai3/projets.lua, P.update, 5e argument `idle`).
  Lancement : lua5.2 tests/places_elastiques_test.lua (depuis la racine du mod).

  Défaut mesuré (fo-logs/2026-11-08_ZERO-IDLE-3/base2-neuve, scarlet, 8 PNJ, K = 4) : la centrale (valeur 64, 5e but) attend de 4 à 12,3 min
  derrière extraction x4 et capital:command pendant que 1 à 4 PNJ sont libres. Règle : un PNJ SANS TÂCHE ouvre un projet de plus que les K
  places, au plus P.IDLE_K_MAX, sticky tant que le but existe, servi après les projets ordinaires et l'armée de l'équipe.

  Sections : 1. le cas mesuré ; 2. aucun PNJ libre : la règle d'avant, ligne pour ligne ; 3. plafond et ordre ; 4. sticky (pas de va-et-vient) ;
  5. ordre de service ; 6. permanents et fond non comptés ; 7. déterminisme ; 8. coût (debug.sethook) ; 9. mutants.
]]
package.path = "./?.lua;" .. package.path
local P = require("shared.ai3.projets")
P.IDLE_K_ON = true -- la regle est eteinte par defaut (shared/ai3/projets.lua) : ce banc l'allume

local passes, failures = 0, 0
local QUIET = false
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not QUIET then print("  ECHEC : " .. msg) end
  end
  return cond
end
local function section(name) if not QUIET then print("== " .. name) end end

-- Les buts de scarlet à 4 min (valeurs lues au journal [FO-IA3C]).
local function goals()
  return {
    { key = "extraction:iron", family = "extraction", kind = "stock", value = 86 },
    { key = "extraction:coal", family = "extraction", kind = "stock", value = 84 },
    { key = "extraction:copper", family = "extraction", kind = "stock", value = 77 },
    { key = "extraction:stone", family = "extraction", kind = "stock", value = 65 },
    { key = "auto:centrale", family = "capital", kind = "module", value = 64, product = "centrale", status = "reserve" },
    { key = "recherche", family = "recherche", kind = "research", value = 60 },
    { key = "capital:command:2:136", family = "capital", kind = "stock", value = 36 },
  }
end

local function goals_big()
  local g = goals()
  g[#g + 1] = { key = "x1", family = "x", kind = "stock", value = 30 }
  g[#g + 1] = { key = "x2", family = "x", kind = "stock", value = 20 }
  g[#g + 1] = { key = "x3", family = "x", kind = "stock", value = 10 }
  return g
end

-- 4 projets ordinaires, un projet BLOQUE classe apres les K places (54 x 1,2 d'inertie = 64 < 65), puis un candidat.
local function goals_bk()
  return {
    { key = "extraction:iron", family = "extraction", kind = "stock", value = 86 },
    { key = "extraction:coal", family = "extraction", kind = "stock", value = 84 },
    { key = "extraction:copper", family = "extraction", kind = "stock", value = 77 },
    { key = "extraction:stone", family = "extraction", kind = "stock", value = 65 },
    { key = "bk", family = "x", kind = "stock", value = 54 },
    { key = "cand", family = "x", kind = "stock", value = 40 },
  }
end

local function keys_of(list)
  local out = {}
  for _, p in ipairs(list) do out[#out + 1] = p.key end
  return table.concat(out, " ")
end
local function by_key(st, key)
  for _, p in ipairs(st.projects) do if p.key == key then return p end end
  return { key = key, state = "attente", virtual = true } -- un but qui n'a pas de place n'a pas de projet : il attend
end
local function active_keys(st)
  local out = {}
  for _, p in ipairs(st.projects) do if p.state == "actif" then out[#out + 1] = p.key end end
  table.sort(out)
  return table.concat(out, " ")
end

section("1. le cas mesure : K = 4, 5e but, PNJ libres")
do
  local st = {}
  local order, K, extra = P.update(st, goals(), 0, 8, 0)
  check(K == 4, "K = 4 avec 8 PNJ")
  check(extra == 0, "aucun PNJ libre : aucun projet de plus")
  check(by_key(st, "auto:centrale").state == "attente", "sans PNJ libre, la centrale attend (la regle d'avant)")
  local st2 = {}
  local order2, K2, extra2 = P.update(st2, goals(), 0, 8, 1)
  check(K2 == 4, "K inchange")
  check(extra2 == 1, "1 PNJ libre : 1 projet de plus, " .. tostring(extra2))
  local c = by_key(st2, "auto:centrale")
  check(c and c.state == "actif" and c.extra == true, "1 PNJ libre : la centrale (5e) passe en actif, marquee extra")
  check(by_key(st2, "recherche").state == "attente", "le 6e but attend toujours (un seul PNJ libre)")
  local seen = {}
  for _, p in ipairs(order2) do seen[p.key] = true end
  check(seen["auto:centrale"], "la centrale est dans l'ordre de service")
end

section("2. aucun PNJ libre : la regle d'avant")
do
  for _, idle in ipairs({ 0, nil }) do
    local st = {}
    local order = P.update(st, goals(), 0, 8, idle)
    check(active_keys(st) == "extraction:coal extraction:copper extraction:iron extraction:stone", "idle=" .. tostring(idle) .. " : 4 projets actifs, " .. active_keys(st))
    for _, p in ipairs(st.projects) do check(not p.extra, "pas de marque extra sans PNJ libre") end
    check(#order == 4, "quatre projets a deplier")
  end
  local keep = P.IDLE_K_ON
  P.IDLE_K_ON = false
  local st = {}
  local _, _, extra = P.update(st, goals(), 0, 8, 5)
  check(extra == 0 and by_key(st, "auto:centrale").state == "attente", "interrupteur P.IDLE_K_ON faux : la regle d'avant")
  P.IDLE_K_ON = keep
end

section("3. plafond P.IDLE_K_MAX et ordre du classement")
do
  local st = {}
  local _, _, extra = P.update(st, goals_big(), 0, 8, 10)
  check(extra == P.IDLE_K_MAX, "10 PNJ libres, 6 buts hors des K places : au plus P.IDLE_K_MAX projets de plus, " .. tostring(extra))
  check(by_key(st, "x1").state == "attente", "le 4e but hors des K places attend")
  check(by_key(st, "auto:centrale").extra and by_key(st, "recherche").extra and by_key(st, "capital:command:2:136").extra,
    "les 3 buts suivants dans l'ordre du classement (64, 60, 36)")
  local st2 = {}
  local _, _, e2 = P.update(st2, goals(), 0, 8, 2)
  check(e2 == 2 and by_key(st2, "auto:centrale").extra and by_key(st2, "recherche").extra
    and by_key(st2, "capital:command:2:136").state == "attente", "2 PNJ libres : les 2 premiers du classement, pas le 3e")
end

section("4. sticky : le projet de plus reste ouvert quand le PNJ libre est pris par lui")
do
  local st = {}
  P.update(st, goals(), 0, 8, 2)
  local _, _, e = P.update(st, goals(), 60, 8, 0) -- plus aucun PNJ libre (ils travaillent pour ces projets)
  check(e == 2, "0 PNJ libre a la pensee suivante : les 2 projets de plus restent, " .. tostring(e))
  check(by_key(st, "auto:centrale").state == "actif" and by_key(st, "recherche").state == "actif", "toujours actifs")
  check(by_key(st, "capital:command:2:136").state == "attente", "le 3e n'est pas ouvert sans PNJ libre")
  -- le but disparait : le projet est ferme
  local g = goals()
  table.remove(g, 5)
  P.update(st, g, 120, 8, 0)
  check(by_key(st, "auto:centrale").virtual, "le but fini ferme le projet de plus")
  -- une place K se libere : le projet de plus devient ordinaire (plus de marque)
  local st3 = {}
  P.update(st3, goals(), 0, 8, 1)
  local g3 = goals()
  table.remove(g3, 1) -- extraction:iron finie
  P.update(st3, g3, 60, 8, 0)
  local c = by_key(st3, "auto:centrale")
  check(c and c.state == "actif" and not c.extra, "une place K libre : la centrale devient ordinaire (plus extra)")
end

section("5. ordre de service : le projet de plus passe APRES les ordinaires, l'armee et le fond")
do
  local g = goals()
  g[#g + 1] = { key = "armee", family = "armee", kind = "army", value = 83, permanent = true }
  g[#g + 1] = { key = "armee-joueur", family = "armee", kind = "army", value = 50, permanent = true, late = true }
  g[#g + 1] = { key = "fond-x", family = "capital", kind = "invest", value = 40, fond = true }
  local st = {}
  local order = P.update(st, g, 0, 8, 1)
  local pos = {}
  for i, p in ipairs(order) do pos[p.key] = i end
  check(pos["auto:centrale"] ~= nil, "la centrale est servie")
  for _, k in ipairs({ "extraction:iron", "extraction:coal", "extraction:copper", "extraction:stone", "armee", "armee-joueur" }) do
    check(pos[k] and pos[k] < pos["auto:centrale"], k .. " est servi AVANT le projet de plus (" .. keys_of(order) .. ")")
  end
  check(pos["fond-x"] and pos["fond-x"] < pos["auto:centrale"], "le fond (agrandir foreuses et fours) est servi AVANT le projet de plus")
end

section("5 bis. priorite des taches du projet de plus : au plancher, derriere toutes les autres")
do
  local st = {}
  P.update(st, goals(), 0, 8, 2)
  local c, r = by_key(st, "auto:centrale"), by_key(st, "recherche")
  check(c.extra and c.prio <= P.EXTRA_PRIO and r.prio <= P.EXTRA_PRIO, "les projets de plus ont la priorite du plancher (" .. tostring(c.prio) .. ", " .. tostring(r.prio) .. ")")
  local o = by_key(st, "extraction:stone")
  check(o.prio > P.EXTRA_PRIO, "un projet ordinaire garde sa priorite de valeur (" .. tostring(o.prio) .. " > " .. P.EXTRA_PRIO .. ")")
  -- devenu ordinaire (une place K se libere), il retrouve sa priorite de valeur
  local g = goals()
  table.remove(g, 1)
  P.update(st, g, 60, 8, 0)
  check(not by_key(st, "auto:centrale").extra and by_key(st, "auto:centrale").prio > P.EXTRA_PRIO, "ordinaire : priorite de valeur retrouvee")
end

section("6. permanents et fond ne comptent pas, un bloque ne prend pas la place")
do
  local g = goals()
  g[#g + 1] = { key = "armee", family = "armee", kind = "army", value = 83, permanent = true }
  local st = {}
  local _, _, e = P.update(st, g, 0, 8, 0)
  check(e == 0, "l'armee permanente n'est pas un projet de plus")
  local st2 = {}
  P.update(st2, goals(), 0, 8, 1) -- la centrale est le projet de plus
  by_key(st2, "auto:centrale").state = "bloque"
  local _, _, e2 = P.update(st2, goals(), 60, 8, 3)
  check(by_key(st2, "auto:centrale").state == "bloque" and not by_key(st2, "auto:centrale").extra, "un projet bloque reste bloque, sans marque extra")
  check(e2 == 2 and by_key(st2, "recherche").extra and by_key(st2, "capital:command:2:136").extra, "le bloque ne prend pas de place : les 2 suivants s'ouvrent, " .. tostring(e2))
  local st2b = { projects = { { id = 9, key = "bk", family = "x", state = "bloque", opened = 0 } }, next_id = 10 }
  local _, _, e2b = P.update(st2b, goals_bk(), 60, 8, 1) -- UN PNJ libre : le bloque (classe apres les K places) ne consomme pas son droit
  check(e2b == 1 and by_key(st2b, "cand").extra and by_key(st2b, "bk").state == "bloque", "un PNJ libre ouvre le suivant meme si un bloque le precede, " .. tostring(e2b))
end

section("7. determinisme")
do
  local function run()
    local st = {}
    local lines = {}
    for t = 0, 5 do
      local order, K, e = P.update(st, goals(), t * 60, 8, t % 3)
      lines[#lines + 1] = keys_of(order) .. "|" .. K .. "|" .. e
    end
    return table.concat(lines, "\n")
  end
  check(run() == run(), "deux passages identiques")
  local st = {}
  P.update(st, goals(), 0, 8, 2)
  local function pure(v, seen)
    seen = seen or {}
    local t = type(v)
    if t == "function" or t == "userdata" or t == "thread" then return false end
    if t == "table" then
      if seen[v] then return true end
      seen[v] = true
      for k, x in pairs(v) do
        if not pure(k, seen) or not pure(x, seen) then return false end
      end
    end
    return true
  end
  check(pure(st), "st.projects ne porte que des donnees (global sauvegardable)")
end

section("8. cout : pire cas en instructions (debug.sethook), 60 buts, 10 PNJ libres")
do
  local g = {}
  for i = 1, 60 do g[#g + 1] = { key = "g" .. i, family = "x", kind = "stock", value = 20 + (i % 70) } end
  local st = {}
  P.update(st, g, 0, 30, 10)
  local count = 0
  debug.sethook(function() count = count + 1 end, "", 1000)
  for t = 1, 20 do P.update(st, g, t * 60, 30, 10) end
  debug.sethook()
  local per = count * 1000 / 20
  check(per < 400000, string.format("moins de 400 000 instructions par pensee (mesure : %d)", per))
  if not QUIET then print(string.format("  cout : %d instructions Lua par pensee", per)) end
end

local function body(opts)
  -- rejoue les sections essentielles sur la regle courante (pour les mutants) : rend le nombre d'echecs
  QUIET = true
  local f0 = failures
  local st = {}
  local order, K, e = P.update(st, goals(), 0, 8, 1)
  check(e == 1 and by_key(st, "auto:centrale").extra, "m1")
  local st0 = {}
  local _, _, e0 = P.update(st0, goals(), 0, 8, 0)
  check(e0 == 0 and by_key(st0, "auto:centrale").state == "attente", "m2")
  local st3 = {}
  local _, _, e3 = P.update(st3, goals_big(), 0, 8, 10)
  check(e3 == P.IDLE_K_MAX, "m3")
  local st4 = {}
  P.update(st4, goals(), 0, 8, 2)
  local _, _, e4 = P.update(st4, goals(), 60, 8, 0)
  check(e4 == 2, "m4 sticky")
  local g = goals()
  g[#g + 1] = { key = "armee-joueur", family = "armee", kind = "army", value = 50, permanent = true, late = true }
  local st5 = {}
  local o5 = P.update(st5, g, 0, 8, 1)
  local pc, pa
  for i, p in ipairs(o5) do if p.key == "auto:centrale" then pc = i end if p.key == "armee-joueur" then pa = i end end
  check(pc and pa and pa < pc, "m5 ordre de service")
  local st7 = {}
  P.update(st7, goals(), 0, 8, 1)
  check(by_key(st7, "auto:centrale").prio <= P.EXTRA_PRIO, "m7 priorite du plancher")
  local st6 = { projects = { { id = 9, key = "bk", family = "x", state = "bloque", opened = 0 } }, next_id = 10 }
  local _, _, e6 = P.update(st6, goals_bk(), 60, 8, 1)
  check(e6 == 1 and by_key(st6, "cand").extra, "m6 bloque")
  QUIET = false
  return failures - f0
end

section("9. mutants")
do
  -- source de la regle, relue et mutee dans une copie chargee a part
  local f = io.open("shared/ai3/projets.lua", "rb")
  local src = f:read("*a")
  f:close()
  local function load_mut(from, to)
    local a, b = src:find(from, 1, true)
    if not a then return nil, "motif introuvable : " .. from end
    local mutated = src:sub(1, a - 1) .. to .. src:sub(b + 1)
    local chunk, err = load(mutated, "=mut", "t")
    if not chunk then return nil, err end
    return chunk
  end
  local mutants = {
    { "plafond supprime", "and n_extra < P.IDLE_K_MAX then", "then" },
    { "pas de sticky", "if p and p.extra then extra = true", "if false then extra = true" },
    { "un seul PNJ libre en ouvre autant que voulu", "elseif idle_n > 0 and new_extra < idle_n then", "elseif idle_n > 0 then" },
    { "la regle ouvre sans PNJ libre", "elseif idle_n > 0 and new_extra < idle_n then", "elseif true then" },
    { "extra a sa priorite de valeur", "if p.prio > P.EXTRA_PRIO then p.prio = P.EXTRA_PRIO end", "" },
    { "extra servi avec les ordinaires", "if p.extra then xtra[#xtra + 1] = p", "if false then xtra[#xtra + 1] = p" },
    { "extra servi avant le fond", "for _, p in ipairs(fond) do out[#out + 1] = p end\n  for _, p in ipairs(xtra) do out[#out + 1] = p end", "for _, p in ipairs(xtra) do out[#out + 1] = p end\n  for _, p in ipairs(fond) do out[#out + 1] = p end" },
    { "un bloque prend une place de plus", "and not (p and p.state == \"bloque\")", "" },
  }
  for _, m in ipairs(mutants) do
    local chunk, err = load_mut(m[2], m[3])
    if not chunk then
      check(false, "mutant '" .. m[1] .. "' : " .. tostring(err))
    else
      package.loaded["shared.ai3.projets"] = nil
      local ok, Pm = pcall(chunk)
      if ok then Pm.IDLE_K_ON = true end -- (la copie mutee reprend le defaut eteint du module)
      if not ok then
        check(false, "mutant '" .. m[1] .. "' ne charge pas : " .. tostring(Pm))
      else
        local saved = P
        P = Pm
        -- les helpers du test lisent P : on rejoue le corps sur la regle mutee
        local p0, f0 = passes, failures
        local okb, nfail = pcall(body)
        passes, failures = p0, f0
        P = saved
        QUIET = false
        local detected = (not okb) or (nfail > 0)
        if not detected then
          -- seul le test d'ordre (section 5) voit certains mutants : le rejouer
          local g = goals()
          g[#g + 1] = { key = "armee-joueur", family = "armee", kind = "army", value = 50, permanent = true, late = true }
          g[#g + 1] = { key = "fond-x", family = "capital", kind = "invest", value = 40, fond = true }
          local st = {}
          local okc, order = pcall(Pm.update, st, g, 0, 8, 1)
          if okc then
            local pos = {}
            for i, p in ipairs(order) do pos[p.key] = i end
            if not (pos["armee-joueur"] and pos["auto:centrale"] and pos["armee-joueur"] < pos["auto:centrale"]) then detected = true end
            if not (pos["fond-x"] and pos["auto:centrale"] and pos["fond-x"] < pos["auto:centrale"]) then detected = true end
          end
        end
        check(detected, "mutant detecte : " .. m[1])
      end
    end
  end
  package.loaded["shared.ai3.projets"] = nil
end

print(string.format("[PLACES-ELASTIQUES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
