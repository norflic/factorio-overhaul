--[[
  Lot AGES, dernier maillon : le gel du centre n'est pas indéfini. PUR (aucune API Factorio, aucun nom d'objet), testé hors jeu
  (tests/degel_test.lua, avec mutants).

  Mesure (fo-logs/2026-11-02_AGES, essai 4, graine 271828182, 3 h) : le centre décidé attendait 138 min (emerald) et 118 min (scarlet),
  dont 128 et 87 min de gel par la reconstruction (shared/team/reconstruction.lua, Rc.hold_upgrades) ou par la pile (shared/ai3/pile.lua,
  hold) : ces deux gardes arrêtent TOUT paiement d'amélioration tant qu'une pièce se refait ou qu'un cadre réparer / protéger /
  survivre retient, et d'autres pertes rouvrent un cadre dès que le précédent se ferme.
  Principe du DC : « protéger d'abord, puis améliorer ». Règle : la protection reste, mais le gel du centre ne dépasse pas Dg.AFTER
  ticks CUMULÉS. Passé ce temps, le centre (lui seul) passe quand la défense minimale du QG est tenue (le plancher de S1,
  shared/team/survie_qg.lua : hors de péril) ; dès que la défense repasse sous le plancher, le gel reprend (le cumul reste).
  Dg.AFTER = 20 min : la durée que le jeu accorde déjà à une seule pièce perdue (Rc.HOLD_MAX) ; un site tenu par l'ennemi ne gèle pas
  les améliorations plus longtemps que cela.
  Le cumul repart à zéro quand le centre change (niveau suivant : autre clé) ou n'est plus payable.
  Déterminisme : entiers, aucune horloge mesurée (le tick de la partie), aucun hasard.
]]

local Dg = {}

Dg.AFTER = 20 * 3600     -- ticks de gel cumulés avant que le centre puisse passer
Dg.DT_MAX = 5 * 3600     -- un pas plus long que 5 min (partie chargée, pensée absente) n'en compte que 5

--- Un pas. st = état précédent (nil au début) ; a = { key (clé du centre payable, nil : aucun), open (le centre est payable : aucune
--- condition ne le bloque), held (une garde gèle les améliorations), floor_ok (défense minimale tenue), tick }.
--- Rend l'état { key, frozen, last, active } : active = le centre passe malgré le gel.
function Dg.step(st, a)
  a = a or {}
  local tick = tonumber(a.tick) or 0
  if not a.key then return { key = nil, frozen = 0, last = tick, active = false } end
  if not st or st.key ~= a.key then st = { key = a.key, frozen = 0, last = tick, active = false } end
  local dt = tick - (st.last or tick)
  if dt < 0 then dt = 0 end
  if dt > Dg.DT_MAX then dt = Dg.DT_MAX end
  local frozen = st.frozen or 0
  if a.open and a.held then frozen = frozen + dt end
  return { key = a.key, frozen = frozen, last = tick,
    active = (a.open and a.held and a.floor_ok and frozen >= Dg.AFTER) and true or false }
end

return Dg
