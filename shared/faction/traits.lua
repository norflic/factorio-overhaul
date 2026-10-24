--[[
  Caractère des factions tiré de la graine de la carte (lot IA2-0, « graine et caractère »). PUR : aucune API
  Factorio, testable hors jeu (tests/traits_test.lua). Conception : fo-logs/2026-10-24_ANALYSE/IA_ADAPTATIVE.md §B6.1 ;
  choix provisoires D-16 (RD_LOG) : personnalité TIRÉE à chaque partie, pas collée à la couleur.

  - Flux aléatoires Park-Miller (multiplicateur 48271, comme script/core/rng.lua), à état DANS la faction
    (`f.rng = { seed, state, draws }`, nombres seulement : rien de non sérialisable dans `global`). Un flux par
    faction (sel = numéro de la faction) : un tirage de plus chez l'une ne décale pas les autres. Le flux de la
    PARTIE (sel 0) ne sert qu'à répartir les personnalités. Le flux global de rng.lua (compagnons, défense de
    tours) n'est pas touché.
  - Personnalités : les 4 archétypes de F.personalities (conquérant, technocrate, bâtisseur, équilibré) sont
    RÉPARTIS entre les factions par une permutation tirée de la graine (Fisher-Yates) : une partie a toujours un
    archétype de chaque (4 factions), mais Écarlate peut être bâtisseur et Émeraude conquérant.
  - 8 traits, entiers pour mille, tirés à la fondation à ±SPREAD (25 %) autour de l'archétype : ambition,
    prudence, agressivite, curiosite, rancune, opportunisme, discipline, ruse.
  - Caractère EFFECTIF (Tr.character) : les grandeurs que la v0 lit (aggression, keep, caution) suivent les traits
    mais restent BORNÉES à l'enveloppe des 4 archétypes (minimum et maximum de F.personalities) : les bornes des
    niveaux de difficulté testées par tests/pvp_test.lua (grâce, taille minimale, garnison gardée, rapport de
    force) ne sortent pas de ce qui est déjà vérifié pour les archétypes.
  - Seuil d'attaque entre factions : multiplicateur tiré à ±JITTER (20 %) à chaque attaque lancée (Tr.jitter) ;
    la guerre CONTRE LE JOUEUR (S.player_*) n'est pas touchée.

  Entiers et comparaisons seulement pour les tirages ; aucun `pairs` ; aucune trigonométrie.
]]

local F = require("shared.faction.config")

local Tr = {}

Tr.MOD = 2147483647
Tr.MUL = 48271
Tr.SPREAD = 250  -- traits : ±25 % autour de l'archétype (pour mille)
Tr.JITTER = 200  -- seuil d'attaque entre factions : ±20 % (pour mille)
Tr.SALT_GAME = 0 -- flux de la partie (répartition des personnalités) ; factions : sel = numéro de la faction

Tr.ORDER = { "ambition", "prudence", "agressivite", "curiosite", "rancune", "opportunisme", "discipline", "ruse" }

-- Archétypes (pour mille). ambition = appétit (greed), prudence = prudence face au joueur (caution),
-- agressivite = agressivité (aggression), curiosite = recherche (research) : × 1 000 des valeurs de
-- F.personalities. Les 4 derniers traits n'ont pas encore de lecteur en v0 (chef d'IA2-a, mémoire d'IA2-c).
Tr.ARCHETYPES = {
  conqueror  = { ambition = 1000, prudence = 750,  agressivite = 1500, curiosite = 800,  rancune = 1300, opportunisme = 1200, discipline = 800,  ruse = 900 },
  technocrat = { ambition = 1000, prudence = 950,  agressivite = 800,  curiosite = 1600, rancune = 900,  opportunisme = 1000, discipline = 1200, ruse = 1300 },
  builder    = { ambition = 1500, prudence = 1000, agressivite = 700,  curiosite = 1000, rancune = 800,  opportunisme = 800,  discipline = 1300, ruse = 800 },
  balanced   = { ambition = 1000, prudence = 900,  agressivite = 1000, curiosite = 1000, rancune = 1000, opportunisme = 1000, discipline = 1000, ruse = 1000 },
}

--- Enveloppe d'une grandeur sur les 4 archétypes (minimum, maximum), dans l'ordre fixe de F.factions.
local function envelope(field)
  local lo, hi
  for _, def in ipairs(F.factions) do
    local v = F.personalities[def.personality][field]
    if v ~= nil then
      if lo == nil or v < lo then lo = v end
      if hi == nil or v > hi then hi = v end
    end
  end
  return { lo, hi }
end
Tr.ENVELOPE = { aggression = envelope("aggression"), keep = envelope("keep"), caution = envelope("caution") }

local function clamp(x, env)
  if x < env[1] then return env[1] end
  if x > env[2] then return env[2] end
  return x
end

---------------------------------------------------------------------------------------------------
-- Flux
---------------------------------------------------------------------------------------------------
--- Graine d'un flux : graine de la carte (entier ≥ 0 quelconque) mélangée au sel. Arithmétique exacte en double.
function Tr.seed(map_seed, salt)
  local M = Tr.MOD
  local a = (math.floor(map_seed or 0) % M) * 31 % M
  local b = (math.floor(salt or 0) % M) * 7919 % M
  local s = (a + b + 104729) % (M - 1) + 1
  for _ = 1, 4 do s = (s * Tr.MUL) % M end
  return s
end

function Tr.new_stream(map_seed, salt)
  local s = Tr.seed(map_seed, salt)
  return { seed = s, state = s, draws = 0 }
end

--- Tirage suivant du flux (entier de 1 à MOD - 1).
function Tr.next(stream)
  local x = (stream.state * Tr.MUL) % Tr.MOD
  stream.state = x
  stream.draws = (stream.draws or 0) + 1
  return x
end

--- Entier uniforme dans [a, b].
function Tr.range(stream, a, b)
  return a + (Tr.next(stream) % (b - a + 1))
end

---------------------------------------------------------------------------------------------------
-- Tirages de la fondation
---------------------------------------------------------------------------------------------------
--- Personnalités des n premières factions (F.factions), tirées de la graine : permutation des archétypes.
function Tr.personalities(map_seed, n)
  local list = {}
  for i, def in ipairs(F.factions) do list[i] = def.personality end
  local st = Tr.new_stream(map_seed, Tr.SALT_GAME)
  for i = #list, 2, -1 do
    local j = Tr.range(st, 1, i)
    list[i], list[j] = list[j], list[i]
  end
  local out = {}
  for i = 1, math.min(n or #list, #list) do out[i] = list[i] end
  return out
end

--- 8 traits (pour mille) tirés du flux autour de l'archétype `personality`.
function Tr.draw_traits(stream, personality)
  local A = Tr.ARCHETYPES[personality] or Tr.ARCHETYPES.balanced
  local t = {}
  for _, k in ipairs(Tr.ORDER) do
    local u = Tr.range(stream, 1000 - Tr.SPREAD, 1000 + Tr.SPREAD)
    t[k] = math.floor(A[k] * u / 1000 + 0.5)
  end
  return t
end

--- Multiplicateur (pour mille) du seuil de la prochaine attaque entre factions.
function Tr.jitter(stream)
  return Tr.range(stream, 1000 - Tr.JITTER, 1000 + Tr.JITTER)
end

--- Fondation d'une faction : flux (sel = numéro de la faction), traits, premier multiplicateur de seuil.
function Tr.found(map_seed, index, personality)
  local st = Tr.new_stream(map_seed, index)
  local traits = Tr.draw_traits(st, personality)
  local jitter = Tr.jitter(st)
  return st, traits, jitter
end

---------------------------------------------------------------------------------------------------
-- Caractère effectif
---------------------------------------------------------------------------------------------------
--- Caractère effectif d'une faction : table au format de F.personalities (lue par shared/faction/strategy.lua
--- à la place de l'archétype), plus `archetype` (clé de la personnalité) et `traits`. Sans traits : l'archétype
--- tel quel (mêmes nombres que F.personalities).
function Tr.character(personality, traits)
  local P = F.personalities[personality] or F.personalities.balanced
  local key = F.personalities[personality] and personality or "balanced"
  if not traits then
    return { archetype = key, greed = P.greed, aggression = P.aggression, research = P.research, keep = P.keep,
      caution = P.caution }
  end
  local A = Tr.ARCHETYPES[key]
  local E = Tr.ENVELOPE
  local aggr = clamp(traits.agressivite / 1000, E.aggression)
  return {
    archetype = key, traits = traits,
    greed = traits.ambition / 1000,
    research = traits.curiosite / 1000,
    -- Contre le JOUEUR (S.player_*) : tailles, garnison gardée et rapport de force de l'ARCHÉTYPE. Mesuré (campagne
    -- de tests/pvp_test.lua, section IA2-0) : avec agressivité, garnison gardée et prudence tirées, l'ordre strict
    -- des niveaux tombait pour 2 caractères sur 16 (technocrate à garnison gardée 0,40, conquérant à 1,274).
    aggression = P.aggression, keep = P.keep, caution = P.caution,
    -- Délai de grâce : agressivité TIRÉE (même diviseur à tous les niveaux : l'ordre des niveaux est gardé).
    grace_aggression = aggr,
    -- Guerre ENTRE factions (S.attack) : agressivité et garnison gardée tirées.
    war_aggression = aggr,
    war_keep = clamp(P.keep * traits.prudence / A.prudence, E.keep),
  }
end

--- Texte court des traits (journal).
function Tr.describe(traits)
  if not traits then return "-" end
  local parts = {}
  for _, k in ipairs(Tr.ORDER) do parts[#parts + 1] = k .. "=" .. tostring(traits[k]) end
  return table.concat(parts, " ")
end

return Tr
