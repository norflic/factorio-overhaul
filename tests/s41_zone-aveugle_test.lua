--[[
  s41 zone-aveugle : la bande du champ n'est plus « jamais lue ». Le releve des champs (Champ.report) garde sa lecture (p.champ_read, regle
  pure Rv.field_read), la vue « Cerveau » la lit (Lec.reads, source « champ ») avec sa propre peremption (Ec.compare, read.stale).
  Usage, depuis la racine du mod :   lua5.2 tests/s41_zone-aveugle_test.lua
]]
package.path = "./?.lua;" .. package.path
local Rv = require("shared.team.ravitaillement")
local Ec = require("shared.debug.ecart")
local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[S41-ZONE-AVEUGLE] ECHEC : " .. name) end
end
local function read(p) local h = assert(io.open(p, "rb")) local s = h:read("*a") h:close() return s end

-- §1 regle de lecture
local r = Rv.field_read(60, 20, 24, 16, 7200)
check("constat du DC : 24 fours a sec, 16 pleins -> arret, combustible, date gardee", r.verdict == "arret" and r.why == "combustible" and r.tick == 7200 and r.nofuel == 24 and r.full == 16)
r = Rv.field_read(40, 20, 3, 16, 1)
check("plus de fours pleins que de fours a sec -> arret, sortie", r.verdict == "arret" and r.why == "sortie")
r = Rv.field_read(40, 40, 0, 0, 1)
check("tout tourne -> marche, sans cause", r.verdict == "marche" and r.why == nil)
r = Rv.field_read(40, 0, 0, 0, 1)
check("rien ne tourne, ni a sec ni plein -> inconnu", r.verdict == "inconnu" and r.why == nil)
r = Rv.field_read(nil, nil, nil, nil, nil)
check("entrees absentes -> inconnu, jamais d'erreur", r.verdict == "inconnu" and r.tick == 0 and r.n == 0)

-- §2 ecart : une lecture « champ » sort la zone de « jamais lu » et porte sa peremption
local now = 100000
local rouge = { color = "rouge" }
check("sans lecture : jamais lu (constat du DC)", Ec.compare({}, rouge, now).kind == "jamais_lu")
local lec = { src = "champ", verdict = "arret", why = "combustible", tick = now - 4 * 3600, stale = 7 * 3600 }
local e = Ec.compare({ lec }, rouge, now)
check("lecture de 4 min, peremption propre de 7 min : lue, verdict arret, cause combustible", e.kind ~= "jamais_lu" and e.kind ~= "perime" and e.verdict == "arret" and e.why == "combustible" and e.src == "champ")
lec.stale = nil
check("sans peremption propre : seuil commun (2 min) -> perime, comme avant", Ec.compare({ lec }, rouge, now).kind == "perime")
lec.stale, lec.tick = 7 * 3600, now - 8 * 3600
check("lecture de 8 min : perimee", Ec.compare({ lec }, rouge, now).kind == "perime")

-- §3 cablage (texte)
local cp, lp = read("script/team/champ.lua"), read("script/debug/lecture.lua")
local function count(text, pat) local n, i = 0, 1 while true do local a, b = text:find(pat, i, true) if not a then return n end n, i = n + 1, b + 1 end end
check("un seul ecrivain de p.champ_read, par la regle", count(cp, "p.champ_read = ") == 1
  and cp:find("p.champ_read = Rv.field_read(pd.fn + pd.dn, pd.run, pd.fnofuel, pd.ffull, tick)", 1, true) ~= nil and count(lp, "champ_read = ") == 0)
check("la vue lit la lecture gardee, source « champ »", lp:find('out[#out + 1] = { src = "champ", verdict = cr.verdict, why = cr.why, tick = cr.tick, stale = Lec.CHAMP_STALE }', 1, true) ~= nil)
for _, lang in ipairs({ "fr", "en" }) do
  local cfg = read("locale/" .. lang .. "/debug_cerveau.cfg")
  check("texte de la source « champ » (" .. lang .. ")", cfg:find("\nsource-champ=", 1, true) ~= nil and cfg:find("\ncause-combustible=", 1, true) ~= nil and cfg:find("\ncause-sortie=", 1, true) ~= nil)
end

print(string.format("[S41-ZONE-AVEUGLE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
