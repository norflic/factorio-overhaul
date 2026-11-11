--[[
  Lot P1-ELAGAGE (DC, 11/11) : routine périodique et découpée par tranches qui repère les entités zombies. Première règle :
  une foreuse de l'équipe dont la zone de minage ne porte plus aucune ressource est démontée, son objet rendu au coffre.
  Règle PURE (aucun accès au moteur) : le relevé et le démontage sont injectés (io.list, io.left, io.retire).
  Complète script/team/gisement.lua (qui ne juge que les foreuses à combustion des avant-postes).
]]
local E = {}

E.EVERY = 4 * 3600   -- une ronde complète toutes les 4 min
E.SLICE = 600        -- une tranche toutes les 10 s pendant la ronde
E.PER_SLICE = 20     -- foreuses examinées au plus par tranche

--- Une tranche. st : état (table simple) ; io.list() rend la liste triée des foreuses de l'équipe (relue en début de ronde) ;
--- io.left(d) rend le nombre de ressources sous la zone de minage ; io.retire(d) démonte et rend l'objet. Rend le nombre démonté.
function E.step(st, tick, io)
  st.next = st.next or 0
  if tick < st.next then return 0 end
  if not st.queue then st.queue, st.i = io.list(), 1 end
  local n, cut = 0, 0
  while st.i <= #st.queue and n < E.PER_SLICE do
    local d = st.queue[st.i]
    st.i, n = st.i + 1, n + 1
    if io.valid(d) and io.left(d) == 0 then
      io.retire(d)
      cut = cut + 1
    end
  end
  st.cut = (st.cut or 0) + cut
  if st.i > #st.queue then
    st.queue, st.i, st.next = nil, nil, tick + E.EVERY
  else
    st.next = tick + E.SLICE
  end
  return cut
end

return E
