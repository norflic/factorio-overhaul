--[[
  Lot VIDEO-L13 « PLAFONDS ET GARDES FERMÉES PAR DÉFAUT » : banc HORS JEU de shared/ai3/plafonds.lua (et de son usage avec la
  confirmation observée du lot L5, shared/ai3/confirmation.lua). Lancement, depuis la racine du mod :
    lua5.2 tests/plafonds_test.lua
  Sections :
     1. entrée absente : refus, la garde nomme l'entrée ;
     2. entrées invalides (NaN, infini, négatif, chaîne) : refus ;
     3. plafond relatif à la demande (Pf.K × la demande), ordres ouverts compris ;
     4. première unité d'un objet demandé ;
     5. demande nulle : rien ;
     6. plafond absolu en nombre (Pf.HARD), réglages k et hard par objet ;
     7. registre de la décision entière (Pf.take) ;
     8. un décompte ne rouvre jamais une entrée absente ;
     9. Pf.room : la plus grande taille qui passe, contre la force brute ;
    10. comparaison fermée par défaut (Pf.test) ;
    11. places d'ordres ouverts (Pf.open_room, comparé à Ca.OPEN_MAX) ;
    12. les « silos sans fin » : garde à entrée absente, machines jamais nourries (L5 seul, L5 + L13) ;
    13. déterminisme ;
    14. coût en INSTRUCTIONS (debug.sethook, jamais os.clock) ;
    15. mutants : chaque règle retirée fait échouer au moins un contrôle.
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

local PATH = "shared/ai3/plafonds.lua"
local function load_pf(mutate)
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
local Cf = dofile("shared/ai3/confirmation.lua")

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

local function has(s, sub) return type(s) == "string" and s:find(sub, 1, true) ~= nil end

local function base_state() return { demand = 10, posed = 0, open = 0, n_posed = 0, n_open = 0 } end

local function run_all(Pf)
  -- 1. Entrée absente.
  section("1. entree absente : garde fermee")
  do
    for _, f in ipairs({ "demand", "posed", "open", "n_posed", "n_open" }) do
      local s = base_state()
      s[f] = nil
      local ok, why = Pf.fits(s, { rate = 1, n = 1 }, "objet-a")
      check(ok == false and has(why, "entree absente : " .. f), "1 : " .. f .. " absent : refus nomme (" .. tostring(why) .. ")")
    end
    for _, f in ipairs({ "rate", "n" }) do
      local add = { rate = 1, n = 1 }
      add[f] = nil
      local ok, why = Pf.fits(base_state(), add, "objet-a")
      check(ok == false and has(why, "entree absente : add." .. f), "1 : add." .. f .. " absent : refus (" .. tostring(why) .. ")")
    end
    local ok1 = Pf.fits(nil, { rate = 1, n = 1 }, "objet-a")
    local ok2 = Pf.fits(base_state(), nil, "objet-a")
    check(ok1 == false and ok2 == false, "1 : releve ou ajout absent : refus")
    local ok3, why3 = Pf.fits(base_state(), { rate = 1, n = 1 }, "objet-a")
    check(ok3 == true, "1 : entrees presentes : accorde (" .. tostring(why3) .. ")")
  end

  -- 2. Entrées invalides.
  section("2. entrees invalides")
  do
    local cases = { { 0 / 0, "invalide" }, { math.huge, "invalide" }, { -math.huge, "invalide" }, { -1, "negative" },
      { "12", "non numerique" }, { true, "non numerique" } }
    for _, c in ipairs(cases) do
      local s = base_state()
      s.posed = c[1]
      local ok, why = Pf.fits(s, { rate = 1, n = 1 }, "objet-a")
      check(ok == false and has(why, c[2]), "2 : posed = " .. tostring(c[1]) .. " : refus « " .. c[2] .. " » (" .. tostring(why) .. ")")
    end
    local v, why = Pf.input(0, "x")
    check(v == 0 and why == nil, "2 : zero est une entree valide")
  end

  -- 3. Plafond relatif.
  section("3. plafond relatif a la demande")
  do
    local s = { demand = 10, posed = 15, open = 0, n_posed = 3, n_open = 0 }
    check(Pf.fits(s, { rate = 5, n = 1 }, "objet-a") == true, "3 : 15 + 5 = 20 = 2 x 10 : accorde")
    local ok, why = Pf.fits(s, { rate = 6, n = 1 }, "objet-a")
    check(ok == false and has(why, "x demande"), "3 : 15 + 6 > 20 : refus (" .. tostring(why) .. ")")
    local s2 = { demand = 10, posed = 10, open = 8, n_posed = 2, n_open = 2 }
    local ok2 = Pf.fits(s2, { rate = 4, n = 1 }, "objet-a")
    check(ok2 == false, "3 : les ordres ouverts comptent (10 + 8 + 4 > 20)")
    check(Pf.fits(s2, { rate = 2, n = 1 }, "objet-a") == true, "3 : 10 + 8 + 2 = 20 : accorde")
  end

  -- 4. Première unité.
  section("4. premiere unite")
  do
    local s = { demand = 1, posed = 0, open = 0, n_posed = 0, n_open = 0 }
    local ok, why = Pf.fits(s, { rate = 60, n = 1 }, "objet-a")
    check(ok == true and has(why, "premiere unite"), "4 : une machine de 60/min pour 1/min demande : accordee (" .. tostring(why) .. ")")
    check(Pf.fits(s, { rate = 120, n = 2 }, "objet-a") == false, "4 : deux unites d'un coup : refus")
    local s2 = { demand = 1, posed = 60, open = 0, n_posed = 1, n_open = 0 }
    check(Pf.fits(s2, { rate = 60, n = 1 }, "objet-a") == false, "4 : une deja posee : la suivante est refusee")
    local s3 = { demand = 1, posed = 0, open = 60, n_posed = 0, n_open = 1 }
    check(Pf.fits(s3, { rate = 60, n = 1 }, "objet-a") == false, "4 : une deja ouverte : la suivante est refusee")
  end

  -- 5. Demande nulle.
  section("5. demande nulle")
  do
    local s = { demand = 0, posed = 0, open = 0, n_posed = 0, n_open = 0 }
    local ok, why = Pf.fits(s, { rate = 1, n = 1 }, "objet-a")
    check(ok == false and has(why, "demande nulle"), "5 : demande nulle : refus (" .. tostring(why) .. ")")
  end

  -- 6. Plafond absolu.
  section("6. plafond absolu en nombre")
  do
    local s = { demand = 1e6, posed = 0, open = 0, n_posed = Pf.HARD - 1, n_open = 0 }
    check(Pf.fits(s, { rate = 1, n = 1 }, "objet-a") == true, "6 : HARD - 1 + 1 : accorde")
    local ok, why = Pf.fits(s, { rate = 2, n = 2 }, "objet-a")
    check(ok == false and has(why, "au plus"), "6 : HARD - 1 + 2 : refus (" .. tostring(why) .. ")")
    local s2 = { demand = 1e6, posed = 0, open = 0, n_posed = 3, n_open = 1, hard = 4 }
    check(Pf.fits(s2, { rate = 1, n = 1 }, "objet-a") == false, "6 : hard = 4 par objet : 3 + 1 + 1 refuse")
    local s3 = { demand = 10, posed = 25, open = 0, n_posed = 1, n_open = 0, k = 3 }
    check(Pf.fits(s3, { rate = 5, n = 1 }, "objet-a") == true, "6 : k = 3 : 25 + 5 = 30 accorde")
    local s4 = { demand = 10, posed = 0, open = 0, n_posed = 0, n_open = 0, k = 0 / 0 }
    check(Pf.fits(s4, { rate = 1, n = 1 }, "objet-a") == false, "6 : k invalide : refus")
    local s5 = { demand = 10, posed = 0, open = 0, n_posed = 0, n_open = 0, hard = -1 }
    check(Pf.fits(s5, { rate = 1, n = 1 }, "objet-a") == false, "6 : hard invalide : refus")
  end

  -- 7. Registre.
  section("7. registre de la decision entiere")
  do
    local src = { ["objet-a"] = { demand = 10, posed = 8, open = 0, n_posed = 2, n_open = 0 } }
    local l = Pf.ledger(src)
    local add = { rate = 8, n = 2 }
    check(Pf.fits_item(l, "objet-a", add) == true, "7 : premier ajout : 8 + 8 <= 20")
    check(Pf.take(l, "objet-a", add) == true, "7 : decompte")
    local ok, why = Pf.fits_item(l, "objet-a", add)
    check(ok == false, "7 : second ajout de la meme decision : 8 + 8 + 8 > 20 (" .. tostring(why) .. ")")
    check(src["objet-a"].open == 0, "7 : le releve de l'appelant n'est pas touche")
    local ok2, why2 = Pf.fits_item(l, "objet-b", add)
    check(ok2 == false and has(why2, "aucun releve"), "7 : objet absent du registre : refus (" .. tostring(why2) .. ")")
  end

  -- 8. Un décompte ne rouvre jamais une entrée absente.
  section("8. decompte sans entree absente")
  do
    local l = Pf.ledger({ ["objet-a"] = { demand = 10, posed = 0, n_posed = 0, n_open = 0 } }) -- open absent
    check(Pf.take(l, "objet-a", { rate = 1, n = 1 }) == false, "8 : decompte refuse sur une entree absente")
    check(Pf.fits_item(l, "objet-a", { rate = 1, n = 1 }) == false, "8 : la garde reste fermee")
    check(Pf.take(l, "objet-a", { rate = 0 / 0, n = 1 }) == false, "8 : ajout invalide : decompte refuse")
  end

  -- 9. Pf.room contre la force brute.
  section("9. Pf.room : plus grande taille qui passe")
  do
    local seed = 4242
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end
    local bad = 0
    for _ = 1, 200 do
      local s = { demand = rnd(40), posed = rnd(60), open = rnd(20), n_posed = rnd(30), n_open = rnd(10), hard = 20 + rnd(50) }
      local unit, want = 1 + rnd(12), rnd(70)
      local n = Pf.room(s, unit, want, "objet-a")
      local brute = 0
      for k = 1, want do
        if Pf.fits(s, { rate = k * unit, n = k }, "objet-a") then brute = k else break end
      end
      if n ~= brute then bad = bad + 1 end
    end
    check(bad == 0, "9 : 200 cas : dichotomie = force brute (" .. bad .. " ecart(s))")
    local n0, why0 = Pf.room(base_state(), nil, 3, "objet-a")
    check(n0 == 0 and why0 ~= nil, "9 : debit unitaire absent : 0")
    local n1, why1 = Pf.room({ demand = 10, posed = 0, open = 0, n_posed = 0, n_open = 0 }, 4, 9, "objet-a")
    check(n1 == 5 and why1 ~= nil, "9 : 10/min, 4/min par unite : 5 unites (20/min), refus de la 6e (" .. n1 .. ")")
  end

  -- 10. Pf.test.
  section("10. comparaison fermee par defaut")
  do
    check(Pf.test(nil, "<", 100, "stock") == false, "10 : valeur absente : fermee (le bug des silos : absent lu comme 0 < 100)")
    check(Pf.test(50, ">=", nil, "stock") == false, "10 : limite absente : fermee")
    check(Pf.test(50, "<", 100, "stock") == true, "10 : 50 < 100")
    check(Pf.test(150, "<", 100, "stock") == false, "10 : 150 non < 100")
    check(Pf.test(100, "<=", 100, "stock") == true and Pf.test(100, ">=", 100, "stock") == true, "10 : bornes incluses")
    check(Pf.test(1, "~=", 2, "stock") == false, "10 : operateur inconnu : fermee")
    check(Pf.test(0 / 0, ">", -1, "stock") == false, "10 : NaN : fermee")
  end

  -- 11. Places d'ordres ouverts.
  section("11. places d'ordres ouverts (compare a Ca.OPEN_MAX)")
  do
    local n0, why0 = Pf.open_room(nil, 16)
    check(n0 == 0 and has(why0, "absente"), "11 : liste absente : 0 place (Ca.decide en lirait 16)")
    local full = {}
    for i = 1, 16 do full[i] = { key = "k" .. i } end
    local n1, why1 = Pf.open_room(full, 16)
    check(n1 == 0 and has(why1, "16 ordres ouverts"), "11 : 16 ouverts sur 16 : 0 (" .. tostring(why1) .. ")")
    check(Pf.open_room({ {}, {}, {} }, 16) == 13, "11 : 3 ouverts : 13 places")
    check(Pf.open_room({}, nil) == 0, "11 : plafond absent : 0")
  end

  -- 12. Silos sans fin.
  section("12. silos sans fin : garde a entree absente, machines jamais nourries")
  do
    -- a. La garde de l'auteur : « en manque » quand le signal d'un mod absent vaut 0.
    local stock_signal = nil -- le mod qui l'écrivait n'est pas là
    local naive, closed = 0, 0
    for _ = 1, 50 do
      if (stock_signal or 0) < 100 then naive = naive + 1 end
      if Pf.test(stock_signal, "<", 100, "stock") then closed = closed + 1 end
    end
    check(naive == 50 and closed == 0, "12a : garde naive : 50 poses ; garde fermee : 0")
    -- b. Machines posées qui ne produisent jamais (sans courant). Demande 10/min, 4/min par machine, une décision par minute.
    local MIN = 3600
    local function play(mode, cycles)
      local b = Cf.new()
      local posed, ever_max, refused_cap = 0, 0, 0
      for c = 1, cycles do
        local t = c * MIN
        local obs = {}
        for i = 1, posed do obs[i] = { count = 0, cause = "courant" } end
        local r = Cf.step(b, obs, t)
        local cap
        if mode == "avant" then cap = posed * 4 else cap = r.cap["objet-a"] or 0 end
        local manque = 10 - cap
        if manque > 0 and (mode == "avant" or not Cf.holds(r, "objet-a")) then
          local ok = true
          if mode == "L5+L13" then
            ok = Pf.fits({ demand = 10, posed = posed * 4, open = 0, n_posed = posed, n_open = 0 }, { rate = 4, n = 1 }, "objet-a")
            if not ok then refused_cap = refused_cap + 1 end
          end
          if ok then
            posed = posed + 1
            Cf.engage(b, { id = posed, item = "objet-a", rate = 4, base = 0 }, t)
          end
        end
        if posed > ever_max then ever_max = posed end
      end
      return posed, ever_max, refused_cap
    end
    local p_avant = play("avant", 600)
    check(p_avant == 3, "12b : avant L5 : 3 machines posees comptent 12/min de capacite, 0 produit (le defaut D1 : manque masque) (" .. p_avant .. ")")
    local p_l5 = play("L5", 600)
    check(p_l5 >= 50, "12b : L5 seul : le manque reste vu, une machine de plus a chaque echec : " .. p_l5 .. " en 600 min (sans fin)")
    local p_both, max_both, refused = play("L5+L13", 600)
    check(p_both == 5 and max_both == 5, "12b : L5 + L13 : au plus 2 x 10/min = 5 machines de 4/min (" .. p_both .. ")")
    check(refused > 0, "12b : refus « plafond » ecrits ensuite (" .. refused .. ")")
  end

  -- 13. Déterminisme.
  section("13. determinisme")
  do
    local function run(order)
      local states = {}
      for _, i in ipairs(order) do
        states["objet-" .. i] = { demand = i, posed = i % 3, open = 0, n_posed = i % 3, n_open = 0 }
      end
      local l = Pf.ledger(states)
      local out = {}
      for k = 1, 3 do
        for i = 1, 12 do
          local it = "objet-" .. i
          local add = { rate = k, n = 1 }
          local ok, why = Pf.fits_item(l, it, add)
          if ok then Pf.take(l, it, add) end
          out[#out + 1] = tostring(ok) .. ":" .. tostring(why)
        end
      end
      return table.concat(out, "\n") .. ser(l)
    end
    local fwd, rev = {}, {}
    for i = 1, 12 do fwd[i] = i rev[i] = 13 - i end
    check(run(fwd) == run(rev), "13 : meme rendu quel que soit l'ordre d'insertion")
  end

  -- 14. Coût.
  section("14. cout en instructions (debug.sethook)")
  do
    local function instr(fn)
      local c = 0
      debug.sethook(function() c = c + 1 end, "", 1)
      fn()
      debug.sethook()
      return c
    end
    local s = { demand = 10, posed = 6, open = 2, n_posed = 2, n_open = 1 }
    local i_fits = instr(function() Pf.fits(s, { rate = 4, n = 1 }, "objet-a") end)
    local i_room = instr(function() Pf.room({ demand = 1000, posed = 0, open = 0, n_posed = 0, n_open = 0 }, 4, 64, "objet-a") end)
    local states = {}
    for i = 1, 50 do states["objet-" .. i] = { demand = i, posed = 0, open = 0, n_posed = 0, n_open = 0 } end
    local i_ledger = instr(function() Pf.ledger(states) end)
    local i_open = instr(function() Pf.open_room({ {}, {}, {} }, 16) end)
    if not quiet then
      print(string.format("   Pf.fits : %d instructions ; Pf.room (64 unites) : %d ; Pf.ledger (50 objets) : %d ; Pf.open_room : %d",
        i_fits, i_room, i_ledger, i_open))
    end
    check(i_fits < 1500, "14 : Pf.fits sous 1 500 instructions (" .. i_fits .. ")")
    check(i_room < 12 * i_fits, "14 : Pf.room en O(log n) appels (" .. i_room .. ")")
  end

  -- 16. Lot VIDEO-COUVERTURE 5 (critère C5.4, TODO W02) : le relevé du courant. Écrit avant le code.
  --     nil = AUCUNE centrale finie (amorçage : le premier ordre électrique la demande, script/ai3/automatisation.lua submit) ;
  --     un relevé PRÉSENT sans capacité (centrale finie, capacité pas encore lue) ferme la garde et nomme l'entrée.
  section("16. releve du courant : fermé quand la mesure manque")
  do
    check(Pf.power_missing(nil) == nil, "16 : pas de releve (aucune centrale finie) : amorcage, pas un refus de cette garde")
    local why = Pf.power_missing({})
    check(type(why) == "string" and why:find("entree absente", 1, true) and why:find("power.have_kw", 1, true),
      "16 : releve sans capacite : refus ecrit qui nomme l'entree (" .. tostring(why) .. ")")
    check(Pf.power_missing({ used_kw = 12 }) ~= nil, "16 : used_kw seul ne remplace pas la capacite")
    check(Pf.power_missing({ have_kw = 0 / 0 }) ~= nil and Pf.power_missing({ have_kw = -5 }) ~= nil
      and Pf.power_missing({ have_kw = "90" }) ~= nil and Pf.power_missing({ have_kw = math.huge }) ~= nil,
      "16 : capacite NaN, negative, texte ou infinie : refus")
    check(Pf.power_missing({ have_kw = 0 }) == nil and Pf.power_missing({ have_kw = 90, used_kw = 36 }) == nil,
      "16 : capacite lue (meme 0 kW) : la garde est ouverte, le calcul du courant decide")
    check(Pf.power_why({}) == "courant : entree absente : power.have_kw" and Pf.power_why(nil) == nil and Pf.power_why({ have_kw = 5 }) == nil,
      "16 : texte du refus pour le journal (" .. tostring(Pf.power_why({})) .. ")")
  end
end

local Pf0 = assert(load_pf())
run_all(Pf0)

-- 15. Mutants.
section("15. mutants")
local MUTANTS = {
  { "garde ouverte sur entree absente (absent lu comme 0)", { 'if v == nil then return nil, "entree absente : " .. name end', "if v == nil then return 0 end" } },
  { "NaN et infini acceptes", { "if v ~= v or v == math.huge or v == -math.huge then", "if false then" } },
  { "negatif accepte", { 'if v < 0 then return nil, "entree negative', 'if false then return nil, "entree negative' } },
  { "plafond absolu retire", { "if n_after > hard + Pf.EPS then", "if false then" } },
  { "plafond sans rapport a la demande", { "local cap = k * vals.demand", "local cap = math.huge" } },
  { "ordres ouverts non comptes", { 'local after = vals.posed + vals.open + vals["add.rate"]', 'local after = vals.posed + vals["add.rate"]' } },
  { "registre non decompte", { "s.open, s.n_open = o + r, no + n", "s.open, s.n_open = o, no" } },
  { "premiere unite sans condition", { 'if first and vals["add.n"] <= 1 + Pf.EPS then', 'if vals["add.n"] <= 1 + Pf.EPS then' } },
  { "demande nulle ouverte", { 'if vals.demand <= Pf.EPS then return false, "plafond " .. who .. " : demande nulle" end', "" } },
  { "places ouvertes sur liste absente", { 'if type(open) ~= "table" then return 0, "ordres ouverts : entree absente" end', 'if type(open) ~= "table" then open = {} end' } },
  { "decompte qui remplace une entree absente", { "if o == nil or no == nil or r == nil or n == nil then return false end", "o, no, r, n = o or 0, no or 0, r or 0, n or 0" } },
  { "comparaison ouverte sur limite absente", { "if b == nil then return false, wb end", "if b == nil then b = 0 end" } },
  { "releve du courant sans capacite : garde ouverte (W02)", { 'local _, why = Pf.input(pw.have_kw, "power.have_kw")', 'local _, why = 0, nil' } },
  { "releve du courant : capacite lue comme 0 (W02)", { 'local _, why = Pf.input(pw.have_kw, "power.have_kw")', 'local _, why = Pf.input(pw.have_kw or 0, "power.have_kw")' } },
  { "texte du refus sans l'entree nommee (W02)", { '(\"courant : \" .. why)', '(\"courant\")' } },
  { "releve absent refuse (amorcage bloque, W02)", { "if pw == nil then return nil end", 'if pw == nil then return "entree absente : power" end' } },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local mod, err = load_pf(m[2])
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

print(string.format("[PLAFONDS] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refuses", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
