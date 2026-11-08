--[[
  Lot ZERO-IDLE : journal [FO-ZERO-IDLE] (une ligne par minute et par équipe où un PNJ est resté libre). La décision est PURE
  (shared/ai3/zero_idle.lua, appelée par C.think) ; son résumé est gardé dans f.team.ia3.zi_last (nombres et chaînes). Ici : cumul de la
  minute dans f.team.ia3.zi_acc, puis la ligne. Aucune décision ne dépend de ce module.
]]

local ZI = require("shared.ai3.zero_idle")

local ZIrt = {}

ZIrt.EVERY = 3600 -- une ligne par minute de partie

--- Après la pensée pure (script/ai3/cerveau.lua, Ia3.plan_b) : cumule le résumé de cette pensée ; écrit la ligne de la minute.
--- `minute` : minute de partie de l'équipe (entier).
function ZIrt.after(f, st, tick, minute)
  if not st then return end
  -- État lisible par la vue du cerveau (DEBUG-CERVEAU, lecture seule) : f.team.zero_idle.last, mots fixes (ZI.word).
  if f.team then f.team.zero_idle = { last = ZI.last(st.zi_last, tick) } end
  st.zi_acc = ZI.note(st.zi_acc, st.zi_last)
  st.zi_t = st.zi_t or tick
  if tick - st.zi_t >= ZIrt.EVERY then
    st.zi_t = tick
    local line = ZI.line(f.key or "player", minute, st.zi_acc)
    if line then log(line) end
    st.zi_acc = nil
  end
end

return ZIrt
