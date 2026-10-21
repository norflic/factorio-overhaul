--[[
  Générateur pseudo-aléatoire déterministe (Park-Miller, "minimal standard", multiplicateur 48271).

  - État dans le stockage persistant : identique sur tous les clients, survit aux sauvegardes.
  - Arithmétique exacte en double : (2^31 - 2) * 48271 < 2^53.
  - Testable hors-jeu (tests/run.lua).
]]

local Storage = require("script.core.storage")

local RNG = {}

local M = 2147483647
local A = 48271

Storage.declare("rng", function()
  return { state = 20261020 }
end)

function RNG.next()
  local s = Storage.ns("rng")
  local x = (s.state * A) % M
  s.state = x
  return x
end

--- Flottant uniforme dans [0, 1).
function RNG.float()
  return (RNG.next() - 1) / (M - 1)
end

--- Entier uniforme dans [a, b].
function RNG.range(a, b)
  return a + (RNG.next() % (b - a + 1))
end

return RNG
