-- Scénario greffé du lot TIRS (28/10) : COMPOSITE, tirs-degats (K9) et tirs-ages (15 âges) joués dans UNE seule partie
-- (un démarrage de moteur, un ticket de file au lieu de deux). Les deux scénarios sont ceux du lot, inchangés :
-- chacun reçoit un contexte à lui (état propre ; intitulés des contrôles préfixés « degats : » / « ages : »).
--   banc.py --qui TIRS -- 1300 tirs-tout <source>
-- Zones disjointes (degats : x -3400 à -2900, y -3400 à -3000 ; ages : P0 (-2600, -2600) ± 180) : aucune tourelle ne
-- voit la cible d'une autre. Le BILAN est unique ([FO-TIRS-TOUT]) ; les lignes du tableau des dégâts gardent leur marque
-- « TIRS-DEGATS-TABLE ». Contrôle au tick du plus long (ages : 1 200) ; la fenêtre de mesure de degats se ferme à 1 000.
-- Les images (shots) et le son ne sont pas repris : tirs-ages --captures et tirs-son restent des demandes à part.

local A = require("scenarios/tirs-ages")
local D = require("scenarios/tirs-degats")

local PARTS = { { nom = "degats", s = D }, { nom = "ages", s = A } }

-- contexte d'une partie : celui du banc, avec un état propre et des intitulés préfixés (aucune fonction dans global)
local function sous_ctx(ctx, nom)
  local c = setmetatable({}, { __index = ctx })
  function c.state()
    local st = ctx.state()
    st[nom] = st[nom] or {}
    return st[nom]
  end
  function c.ok(check, detail) return ctx.ok(nom .. " : " .. check, detail) end
  function c.fail(check, detail) return ctx.fail(nom .. " : " .. check, detail) end
  function c.check(cond, check, detail) return ctx.check(cond, nom .. " : " .. check, detail) end
  return c
end

local function crochet(nom_crochet)
  return function(ctx, ...)
    for _, p in ipairs(PARTS) do
      local f = p.s[nom_crochet]
      local st = ctx.state()
      st.morts = st.morts or {}
      if f and not (nom_crochet == "tick" and st.morts[p.nom]) then
        local ok, err = pcall(f, sous_ctx(ctx, p.nom), ...)
        if not ok then
          ctx.fail(p.nom .. " : erreur Lua dans " .. nom_crochet, tostring(err))
          if nom_crochet == "tick" then st.morts[p.nom] = true end -- comme le banc : un tick en erreur est coupé
        end
      end
    end
  end
end

return {
  description = "TIRS : composite, K9 (degats par niveau) et 15 ages (habillage du tir) dans une seule partie",
  base = nil,
  check_tick = math.max(D.check_tick, A.check_tick),
  init = crochet("init"),
  tick = crochet("tick"),
  finish = crochet("finish"),
}
