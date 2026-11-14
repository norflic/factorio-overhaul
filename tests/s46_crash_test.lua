package.path = "./?.lua;" .. package.path
local Om = require("shared.team.outil_main")
local n, bad = 0, 0
local function check(c, m) n = n + 1 if not c then bad = bad + 1 print("ECHEC " .. m) end end

local function stack(name)
  local s = { valid = true, valid_for_read = name ~= nil, name = name }
  function s.set_stack(t) s.valid_for_read, s.name = true, t.name return true end
  return s
end
local function player(cs, clear_ok)
  local p = { valid = true, cursor_stack = cs, clears = 0 }
  function p.clear_cursor() p.clears = p.clears + 1 if clear_ok and p.cursor_stack then p.cursor_stack.valid_for_read, p.cursor_stack.name = false, nil end return clear_ok end
  return p
end

check(Om.give(nil, "t", true) == "joueur", "joueur nil")
check(Om.give({ valid = false }, "t", true) == "joueur", "joueur invalide")
check(Om.give(player(stack(nil), true), "t", false) == "prototype", "prototype absent")
check(Om.give(player(nil, true), "t", true) == "main", "cursor_stack nil")
local p = player(stack("t"), true)
check(Om.give(p, "t", true) == "deja" and p.clears == 0, "outil deja en main : rien")
p = player(stack("fer"), false)
check(Om.give(p, "t", true) == "inventaire" and p.cursor_stack.name == "fer", "inventaire plein : main gardee")
p = player(stack("fer"), true)
check(Om.give(p, "t", true) == "ok" and p.cursor_stack.name == "t", "outil pose")
p = player(stack(nil), true)
check(Om.give(p, "t", true) == "ok" and p.cursor_stack.name == "t", "main vide : outil pose")

print(string.format("s46_crash : %d OK, %d ECHEC", n - bad, bad))
os.exit(bad == 0 and 0 or 1)
