-- Lot THERMO-0915 : créneaux de migration élargis en excédent électrique (shared/team/thermique.lua, Th.slot_cfg) et leur branchement
-- (script/team/migration_champ.lua). Usage (depuis la racine du mod) : lua5.2 tests/thermo_surplus_test.lua
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local Th = dofile("shared/team/thermique.lua")
local base = Th.CFG

-- 1. sans excédent : réglage inchangé (début de partie)
local c, w = Th.slot_cfg(nil, nil, true)
check(c == base and not w, "sans centrale : réglage de base")
c, w = Th.slot_cfg(1000, 0, true)
check(c == base and not w, "aucune demande servie : réglage de base")
c, w = Th.slot_cfg(1000, 600, true)
check(c == base and not w, "marge 1,67x < seuil : réglage de base")
c, w = Th.slot_cfg(2500, 1000, false)
check(c == base and not w, "réseau malade : réglage de base")

-- 2. excédent (partie du DC : 2,5x la demande) : créneaux élargis, lus au réglage (rien en dur)
c, w = Th.slot_cfg(2500, 1000, true)
check(w, "marge 2,5x : élargi")
check(c.slots == base.surplus_slots and c.slots > base.slots, "créneaux élargis")
check(c.per_mineral == base.surplus_per_mineral and c.per_mineral > base.per_mineral, "deux par minerai")
check(c.cover_ratio == base.cover_ratio, "le reste du réglage est hérité")
check(base.slots == 3 and base.per_mineral == 1, "le réglage de base n'est pas modifié")
-- seuil lu au réglage passé
local custom = setmetatable({ surplus_ratio = 3.0 }, { __index = base })
c, w = Th.slot_cfg(2500, 1000, true, custom)
check(not w, "seuil lu au réglage (3x)")

-- 3. free_slot avec le réglage élargi : un 2e chantier de fer et un 4e créneau
c, w = Th.slot_cfg(1800, 180, true)
check(not w and c.slots == Th.CFG.slots, "centrale neuve a vide (10x la demande, banc THERMO-eada6505) : pas d'elargissement")
c, w = Th.slot_cfg(2500, 1000, true)
check(w, "2,5x la demande en charge (partie du DC) : elargie")
local wide = Th.slot_cfg(2500, 1000, true)
local busy = { total = 3, iron = 1, copper = 1, coal = 1, key = "iron", stuck = {} }
check(not Th.free_slot("stone", busy), "base : 3 créneaux pris, pierre refusée")
check(Th.free_slot("stone", busy, wide), "excédent : pierre au 4e créneau")
check(Th.free_slot("iron", busy, wide), "excédent : 2e chantier de fer")
busy = { total = 5, iron = 2, copper = 2, coal = 1, key = "iron", stuck = {} }
check(not Th.free_slot("stone", busy, wide), "excédent : 5 créneaux au plus")

-- 4. branchement : migration_champ passe le réglage élargi et borne la prise de créneau
local fh = assert(io.open("script/team/migration_champ.lua", "rb"))
local src = fh:read("*a"); fh:close()
check(src:find('local SLOTS = { "cur", "cur2", "cur3", "cur4", "cur5" }', 1, true) ~= nil, "5 créneaux réels")
check(src:find("if i > slot_cfg.slots then return end", 1, true) ~= nil, "claim borné au réglage")
check(src:find("Th.free_slot(o.kind, busy, slot_cfg)", 1, true) ~= nil, "start_next lit le réglage élargi")
check(src:find("busy.total >= slot_cfg.slots", 1, true) ~= nil, "think lit le réglage élargi")
check(src:find("Th.slot_cfg(gr and gr.capacity, gr and gr.power", 1, true) ~= nil, "marge lue au jeu (capacité / production servie)")
check(Th.CFG.surplus_slots <= 5, "surplus_slots <= créneaux réels")

print(string.format("[THERMO-SURPLUS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
