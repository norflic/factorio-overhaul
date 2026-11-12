--[[
  Lot COLLECTE (carte de l'IA, 7/11) : le facteur de besoin du marché (b.need_mult) survit-il à Ia3.after_poles ?
  Constat (déduit du code par le lead, prouvé ici au moteur simulé) : Ia3.after_poles (script/ai3/cerveau.lua) rappelle Board.sync SANS plan ni vue
  quand il retire du fond (matière saturée) ; Board.sync remettait alors b.need_mult et b.hold_left à nil (board.lua) et le marché (E4, Board.assign
  trois ticks plus tard) lisait nil : le x 1,5 d'un minage de la plaque qui manque (market_ctx.mult_of) ne jouait jamais.
  Séquence jouée : E1 (Board.sync avec plan et vue, Poles.think, Ia3.after_poles) puis E4 (Board.assign), votre équipe, 3 600 ticks, matières
  imposées saturées. On compte, à chaque Board.assign, si b.need_mult est posé.
    sans le correctif (mutant : la ligne de restitution retirée) : au moins un Board.assign lit nil après un retrait de fond ;
    avec : aucun.
  Puis la vraie formule de note (shared/ai3/marche.lua) : la collecte en urgence (94, critique) passe devant le minage de fer urgent (90) avec et sans
  facteur de besoin ; la collecte ordinaire (55) perd contre tout minage de priorité > 55, même sans facteur.
  Usage : lua5.2 tests/need_mult_test.lua   (depuis la racine du mod ; quelques secondes)
]]
package.path = "./?.lua;" .. package.path

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[NEED-MULT] ECHEC : " .. name) end
end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local Mk = require("tests.mock_engine")

local function patches()
  local out, names = {}, { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

--- Une partie neuve (cerveau.lua éventuellement muté). Rend les compteurs { sync_full, sync_bare, dropped, assign_set, assign_nil }.
local function scenario(cerveau_src)
  if cerveau_src then
    package.preload["script.ai3.cerveau"] = function() return assert(load(cerveau_src, "=cerveau", "t"))() end
  end
  local st = { sync_full = 0, sync_bare = 0, dropped = 0, assign_set = 0, assign_nil = 0 }
  local okg, err = pcall(function()
    Mk.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, seed = 7 })
    local s = game.surfaces[1]
    local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
    chest.insert({ name = "coal", count = 200 })
    Mk.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
    local Board = require("script.team.board")
    local Ia3 = require("script.ai3.cerveau")
    local State = require("script.faction.state")
    local osync, oassign, oafter = Board.sync, Board.assign, Ia3.after_poles
    Board.sync = function(f, planned, tick, plan, view, book)
      if plan and view then st.sync_full = st.sync_full + 1 else st.sync_bare = st.sync_bare + 1 end
      return osync(f, planned, tick, plan, view, book)
    end
    Board.assign = function(f, tick, ...)
      if f.is_player then
        if Board.get(f).need_mult then st.assign_set = st.assign_set + 1 else st.assign_nil = st.assign_nil + 1 end
      end
      return oassign(f, tick, ...)
    end
    Ia3.after_poles = function(f, tick)
      local fp = State.faction("player")
      if fp and fp.team then
        fp.team.ia3 = fp.team.ia3 or {}
        fp.team.ia3.saturated = { stone = true, coal = true, ["copper-ore"] = true, ["iron-ore"] = true }
        fp.team.ia3.other_short = true
        -- Lot TESTS-VERTS : PURGE-MINE (77c26cc8, F544) a retiré le minage à la main du fond dans cette partie : plus aucune tâche de
        -- fond d'une matière saturée n'arrivait au tableau, et Ia3.after_poles n'avait rien à retirer. Une tâche de fond d'une matière
        -- saturée (agrandir l'avant-poste de pierre, sans objet) est posée avant son passage : le retrait et la resynchronisation sans
        -- plan ni vue ont lieu comme avant.
        if f == fp then
          Board.add(f, { { key = "need-mult:fond", kind = "extend", prio = 1, outpost_kind = "stone", fond = true } }, tick)
        end
      end
      local d = oafter(f, tick)
      st.dropped = st.dropped + (d or 0)
      return d
    end
    Mk.run_ticks(3600)
  end)
  package.preload["script.ai3.cerveau"] = nil
  if not okg then check("partie au moteur simule : " .. tostring(err), false) end
  return st
end

local base = scenario(nil)
check("la scène retire du fond (Ia3.after_poles resynchronise le tableau sans plan ni vue)", base.dropped > 0 and base.sync_bare >= 1)
check("E1 puis E4 : des synchronisations completes ont eu lieu", base.sync_full >= 5)
check("avec le correctif : aucun Board.assign ne lit un facteur de besoin absent (nil: " .. base.assign_nil .. ")", base.assign_nil == 0 and base.assign_set >= 5)

local src = read("script/ai3/cerveau.lua")
local cut = src:gsub("[ \t]*b%.need_mult, b%.hold_left = need_mult, hold_left\r?\n", "", 1)
check("le mutant (restitution retirée) a bien changé la source", cut ~= src)
local mut = scenario(cut)
check("mutant sans restitution : au moins un Board.assign lit nil apres un retrait de fond (" .. mut.assign_nil .. ")", mut.assign_nil >= 1)

-- La vraie formule de note.
local M = require("shared.ai3.marche")
local npc = { id = 1, pos = { x = 0, y = 0 } }
local home = { x = 0, y = 0 }
local function score(t, mult) return M.score(npc, t, 0, home, mult) end
local urgent = { kind = "carry", prio = 94, critical = true, no_rush = true }
local plain = { kind = "carry", prio = 55 }
local mine90 = { kind = "mine", prio = 90, resource = "iron-ore" }
local mine60 = { kind = "mine", prio = 60, resource = "iron-ore" }
local mine45 = { kind = "mine", prio = 45, resource = "iron-ore" }
check("sans facteur de besoin : la collecte en urgence (141) passe devant le minage urgent du fer (90)", score(urgent, 1) > score(mine90, 1))
check("avec le facteur 1,5 : 141 contre 135, encore devant", score(urgent, 1) > score(mine90, M.NEED_SHORT))
check("collecte ordinaire (55) : perd contre un minage de priorité 60 même sans facteur", score(plain, 1) < score(mine60, 1))
check("collecte ordinaire (55) : bat un minage à 45 sans facteur, le perd avec le facteur 1,5 (67)", score(plain, 1) > score(mine45, 1) and score(plain, 1) < score(mine45, M.NEED_SHORT))

print(string.format("[NEED-MULT] BILAN : %d OK, %d ECHEC(S) ; mutant refuse", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
