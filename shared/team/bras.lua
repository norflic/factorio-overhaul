--[[
  Lot PLANDIR (T2) : bras de la centrale à vapeur. PUR (aucune API Factorio), testé hors jeu par tests/bras_test.lua.

  La centrale démarre avec des bras À COMBUSTION (avec un bras électrique, pas de charbon sans courant ni de courant sans
  charbon : 0 kW au banc ia1-build-plaine, 27/10). Dès que la centrale produit, ses bras passent à l'électrique (le
  Directeur Créatif, 27/10 : « des bras électriques dès que l'électricité existe »). Si le courant tombe PUIS que les
  chaudières sont à sec, la panne se verrouille toute seule (le bras électrique ne rapporte plus de charbon sans
  courant) : les bras repassent à combustion, qui repartent seuls, et y restent HOLD ticks.
]]
local B = {}

B.EVERY = 300        -- ticks entre deux relevés de la centrale
B.LIVE_CHECKS = 3    -- relevés de suite où la centrale produit avant de passer à l'électrique
B.DEAD_CHECKS = 12   -- relevés de suite sans courant et chaudière à sec avant de revenir à la combustion (60 s)
B.HOLD = 72000       -- ticks (20 min) pendant lesquels la centrale reste à combustion après une panne

--- Etat neuf d'une centrale : à combustion.
function B.new()
  return { mode = "burner", live = 0, dead = 0, hold_until = 0, reverts = 0, upgrades = 0 }
end

--- Un relevé. obs = { power = énergie produite (> 0 : la centrale produit), dry = une chaudière est à sec,
--- arms = bras électriques disponibles au coffre (nombre) }. Rend "upgrade", "revert" ou nil ; l'appelant applique
--- l'action puis appelle B.applied. Le compteur de relevés avance ici.
function B.observe(st, obs, tick)
  if (obs.power or 0) > 0 then
    st.live, st.dead = st.live + 1, 0
  else
    st.live = 0
    if obs.dry then st.dead = st.dead + 1 else st.dead = 0 end
  end
  if st.mode == "burner" then
    if st.live >= B.LIVE_CHECKS and tick >= st.hold_until and (obs.arms or 0) > 0 then return "upgrade" end
  elseif st.dead >= B.DEAD_CHECKS then
    return "revert"
  end
  return nil
end

--- L'action a été appliquée (n = bras remplacés ; 0 : rien n'a pu l'être, l'action sera redemandée).
function B.applied(st, action, n, tick)
  if (n or 0) <= 0 then return end
  if action == "upgrade" then
    st.mode, st.upgrades = "electric", st.upgrades + 1
  elseif action == "revert" then
    st.mode, st.reverts = "burner", st.reverts + 1
    st.hold_until = tick + B.HOLD
  end
  st.live, st.dead = 0, 0
end

return B
