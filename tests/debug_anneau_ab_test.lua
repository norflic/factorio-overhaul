--[[
  Lot DEBUG-CERVEAU : preuve A/B HORS JEU que le crochet de l'anneau (Capi.Anneau.note, script/ai3/capitalisation.lua decide_finish) ne change
  AUCUNE décision de la capitalisation. Même partie du moteur simulé que tests/capi_decide_test.lua (--run etapes 3), jouée trois fois,
  chaque passage dans son propre processus :
    A  crochet normal (l'anneau se remplit) ;
    B  crochet coupé (FO_CD_ANNEAU=off) ;
    M  MUTANT : un crochet qui écrit dans la décision (FO_CD_ANNEAU=mut) : l'A/B doit le voir.
  Attendu : A et B identiques octet à octet (état global SANS l'espace de l'anneau, et journal), l'anneau de A non vide, celui de B vide, M différent.
  Lancement, depuis la racine du mod : lua5.2 tests/debug_anneau_ab_test.lua   (quelques minutes ; un seul processus lua à la fois)
]]
package.path = "./?.lua;" .. package.path
local LUA = arg[-1] or "lua5.2"
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function slurp(path)
  local h = io.open(path, "rb")
  if not h then return nil end
  local t = h:read("*a")
  h:close()
  return t
end
local base = os.getenv("TEMP") or os.getenv("TMP") or "."
local tok = (os.tmpname() or ""):gsub("[^%w]", "")
local dir
for i = 0, 99 do
  local d = string.format("%s%sanneauab_%d_%s_%d", base, string.char(92), os.time(), tok, i)
  if os.execute('mkdir "' .. d .. '" 2>nul') == true then dir = d break end
end
assert(dir, "aucun dossier de sorties neuf")

local function pass(tag, env)
  local out = dir .. "/ab_" .. tag
  local cmd = string.format('set "FO_CD_ANNEAU=%s" && set "FO_CD_MUT=" && set "FO_CD_INJ=" && set "FO_CD_OUBLI=" && %s tests/capi_decide_test.lua --run etapes 3 "%s" 2>&1', env, LUA, out)
  local h = io.popen(cmd)
  local text = h:read("*a")
  h:close()
  local fini = text:find("[CAPI-DECIDE-RUN] etapes fini", 1, true) ~= nil
  return fini, out, text
end
local okA, A = pass("A", "")
local okB, B = pass("B", "off")
local okM, M = pass("M", "mut")
check(okA and okB and okM, "les trois passages vont au bout (A " .. tostring(okA) .. ", B " .. tostring(okB) .. ", M " .. tostring(okM) .. ")")
local gA, gB, gM = slurp(A .. "_global.txt"), slurp(B .. "_global.txt"), slurp(M .. "_global.txt")
local jA, jB, jM = slurp(A .. "_journal.txt"), slurp(B .. "_journal.txt"), slurp(M .. "_journal.txt")
check(gA ~= nil and gA == gB, "A et B : etat global identique octet a octet (hors anneau)")
check(jA ~= nil and jA == jB, "A et B : journal identique octet a octet")
local nA, nB = tonumber(slurp(A .. "_anneau.txt") or ""), tonumber(slurp(B .. "_anneau.txt") or "")
check(nA ~= nil and nA > 0, "A : l'anneau s'est rempli (" .. tostring(nA) .. " entrees) : le crochet a bien joue")
check(nB == 0, "B : l'anneau est vide (crochet coupe)")
check(gM ~= nil and gM ~= gA, "MUTANT : un crochet qui modifie la decision est vu par l'A/B")
print(string.format("[DEBUG-ANNEAU-AB] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
