-- Lot REINVEST (ordre du DC, 11/11) : une équipe à UNE colonne de fonderie ouvre la 2e et la 3e dès les premières plaques. Maillon coupé :
-- Th.CFG.slots (shared/team/thermique.lua) valait 2 pour 3 créneaux réels (SLOTS = cur, cur2, cur3, script/team/migration_champ.lua) : la
-- bande du combustible et une bande de fer tenaient les 2 créneaux, la colonne du cuivre (ou la suivante) attendait.
-- Usage (depuis la racine du mod) : lua5.2 tests/reinvest_test.lua
package.path = "./?.lua;" .. package.path

local function read(path)
  local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s
end
local SRC = read("shared/team/thermique.lua")
local MIG = read("script/team/migration_champ.lua")

-- nombre de créneaux réels lus dans le source de la migration (aucun nom d'objet)
local function real_slots(src)
  local list = src:match("local SLOTS = (%b{})")
  local n = 0
  for _ in (list or ""):gmatch('"[^"]+"') do n = n + 1 end
  return n
end

local function verdict(src)
  local chunk = load(src, "=thermique", "t")
  if not chunk then return false, "chargement" end
  local ok, Th = pcall(chunk)
  if not ok or type(Th) ~= "table" then return false, "module" end
  local fails = {}
  local function check(c, m) if not c then fails[#fails + 1] = m end end
  local n = real_slots(MIG)
  check(n == 3, "3 créneaux réels dans la migration")
  check(Th.CFG.slots == n, "Th.CFG.slots = créneaux réels")
  -- une colonne finie (hors créneaux), le combustible et une 2e bande de la plaque clé en cours : la 3e colonne (autre plaque) part
  local busy = { total = 2, ids = {}, key = "a", stuck = {}, a = 1, c = 1 }
  local s, w = Th.free_slot("b", busy)
  check(s == true and w == "libre", "2 chantiers en cours : une 3e colonne part (" .. tostring(w) .. ")")
  -- trois chantiers : le quatrième attend (pas de créneau inventé)
  busy = { total = 3, ids = {}, key = "a", stuck = {}, a = 1, b = 1, c = 1 }
  s, w = Th.free_slot("d", busy)
  check(s == false and w == "creneaux", "3 chantiers : un 4e attend (" .. tostring(w) .. ")")
  -- un seul chantier : une autre plaque part
  busy = { total = 1, ids = {}, key = "a", stuck = {}, c = 1 }
  s = Th.free_slot("b", busy)
  check(s == true, "1 chantier : une 2e colonne part")
  return #fails == 0, table.concat(fails, " ; ")
end

local ok, why = verdict(SRC)
print("== reinvest : source actuel : " .. (ok and "VERT" or ("ROUGE : " .. why)))

local mutants = {
  { "slots = 2 (avant la coupe)", "  slots = 3,", "  slots = 2," },
  { "slots = 1", "  slots = 3,", "  slots = 1," },
  { "slots = 4 (créneau inventé)", "  slots = 3,", "  slots = 4," },
  { "total ignoré", "if (busy.total or 0) >= cfg.slots then", "if false then" },
  { "seuil strict", "if (busy.total or 0) >= cfg.slots then", "if (busy.total or 0) > cfg.slots then" },
  { "seuil à un de moins", "if (busy.total or 0) >= cfg.slots then", "if (busy.total or 0) + 1 >= cfg.slots then" },
}
local survivors = 0
for _, mu in ipairs(mutants) do
  local a, b = SRC:find(mu[2], 1, true)
  if not a then print("  MUTANT INAPPLICABLE : " .. mu[1]); survivors = survivors + 1
  else
    local msrc = SRC:sub(1, a - 1) .. mu[3] .. SRC:sub(b + 1)
    local mok = verdict(msrc)
    if mok then print("  MUTANT SURVIVANT : " .. mu[1]); survivors = survivors + 1 else print("  mutant refuse : " .. mu[1]) end
  end
end
print(string.format("reinvest : %s, mutants refuses %d/%d", ok and "OK" or "ECHEC", #mutants - survivors, #mutants))
if not ok or survivors > 0 then os.exit(1) end
