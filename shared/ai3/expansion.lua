--[[
  Lot EXPANSION : le BUT « expansion » du cerveau (shared/ai3/buts.lua l'appelle par un crochet de cinq lignes) et son
  ÉMISSION (shared/ai3/cerveau.lua l'enregistre dans P.EMIT). Les règles sont dans shared/ai3/besoin.lua (pures, testées par
  tests/besoin_test.lua) ; ce fichier les branche sur la situation du cerveau. PUR (aucune API Factorio), aucun nom du jeu :
  les types d'avant-poste, leurs produits et leurs places viennent de shared/team/config.lua (T), les débits de foreuse de
  la situation (`s.drill_rate`, lus sur les PROTOTYPES par script/ai3/besoin.lua).

  Quand une matière a un BESOIN (demande projetée × croissance du capital − production − stock couvert) et que ses gisements
  connus sont exploités à 80 % ou plus, le cerveau n'attend pas qu'un site soit épuisé :
    - un site est retenu : le but « expansion:<type> » BÂTIT un NOUVEL avant-poste (jamais l'agrandissement d'un ancien,
      que la famille « extraction » fait déjà), avec ses tourelles (couverture), comme le dépliage de l'extraction ;
    - aucun site : le but demande des sites (E.site_needs) : la prospection d'IA2-b cherche, puis l'exploration d'IA3-f envoie
      un éclaireur (script/ai3/exploration.lua, auto_requests : demande « site » qui se ferme sur « trouvé » quand un
      gisement de plus est connu, même pour une ressource déjà exploitée) ; le projet reste BLOQUÉ « site:<type> » (aucune
      place parmi les K projets) ;
    - l'exploration reste vaine trois fois de suite : « productivite » (voir Be.expansion) : ce fichier ne crée plus de but, la
      suite est aux modules de productivité du lot LEVIERS ; la décision est gardée dans st.exp pour le journal.
  Un seul chantier d'expansion à la fois (Be.pick). Gardes : économie faite (fer II ou économie saturée), armée de départ
  faite (factions), pas en guerre.

  État persistant (global) : st.ex[type] = { tries, since, last_fail } ; st.exp[type] = { act, why, need, sat } (journal) ;
  st.ex_active = type du chantier courant. Nombres, chaînes et tables seulement.
]]

local T = require("shared.team.config")
local Be = require("shared.ai3.besoin")
local Planner = require("shared.team.planner")

local Ex = {}

Ex.BASE = 54 -- valeur du but : juste sous la croissance par manque durable (B.GROW 55) : l'ancien avant-poste d'abord

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

--- Lecture d'un type d'avant-poste dans la situation : { drills, capacity, outposts, free, sat_pct, production, demand,
--- need, projected }. L'exploitation (sat_pct) est celle des gisements BÂTIS (foreuses posées ÷ places de leurs avant-postes) :
--- un site retenu qui attend n'est pas exploité, c'est justement lui que le but ouvre. `s` = situation du cerveau (shared/ai3/cerveau.lua, C.situation).
function Ex.read(s, kind)
  local spec = T.outposts[kind]
  local drills, capacity, n = 0, 0, 0
  for _, o in ipairs(s.outposts or {}) do
    if o.kind == kind then
      n = n + 1
      drills = drills + (o.drills or 0)
      capacity = capacity + (o.full and (o.drills or 0) or T.max_drills(kind))
    end
  end
  local free = (s.sites or {})[kind] or 0
  local rate = s.drill_rate and s.drill_rate[kind]
  local out = { outposts = n, drills = drills, capacity = capacity, free = free, sat_pct = Be.saturation(drills, capacity) }
  if not rate then return out end
  local m = {
    demand = Be.rate_of_kept((s.need or {})[spec.product]),
    production = drills * rate,
    stock = (s.stock or {})[spec.product] or 0,
    factor = Be.factor(s.growth, Be.CYCLES),
  }
  out.demand, out.production = m.demand, m.production
  out.need, out.projected = Be.need(m)
  return out
end

--- Candidats de la pensée : { key = type, need, projected, act, why } pour chaque type dont la décision n'est pas « none ».
--- Garde l'état de décision (st.ex) et le journal (st.exp).
function Ex.decide(s, st)
  st.ex = st.ex or {}
  st.exp = st.exp or {}
  local allowed = (s.economy_done and not s.at_war and (st.army_done or s.is_player)) and true or false
  local cands = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local r = Ex.read(s, kind)
    local ex = st.ex[kind] or Be.new_ex()
    st.ex[kind] = ex
    local act, why
    if r.outposts == 0 then act, why = "none", "amorcage"
    elseif (s.pending or {})[kind] and s.pending[kind] > 0 then act, why = "none", "chantier"
    elseif r.need == nil then act, why = "none", "sans mesure"
    else
      act, why = Be.expansion({ need = r.need, sat_pct = r.sat_pct, free_sites = r.free, allowed = allowed }, ex, s.tick or 0)
    end
    st.exp[kind] = { act = act, why = why, need = r.need and math.floor(r.need * 10) / 10 or nil, sat = r.sat_pct,
      free = r.free, tries = ex.tries }
    if act == "open" or act == "explore" then
      cands[#cands + 1] = { key = kind, need = r.need, projected = r.projected, act = act, why = why }
    end
  end
  return cands
end

--- Crochet de shared/ai3/buts.lua (B.generate) : ajoute le but « expansion » à la liste. w = poids des familles.
function Ex.goals(goals, s, st, w)
  local cands = Ex.decide(s, st)
  if #cands == 0 then
    st.ex_active = nil
    return goals
  end
  local pick = nil
  for _, c in ipairs(cands) do
    if c.key == st.ex_active then pick = c.key end -- le chantier courant reste (inertie)
  end
  pick = pick or Be.pick(cands)
  st.ex_active = pick
  for _, c in ipairs(cands) do
    if c.key == pick then
      goals[#goals + 1] = { key = "expansion:" .. pick, family = "extraction", kind = "expansion", outpost = pick,
        value = clamp(math.floor(Ex.BASE * ((w or {}).extraction or 1000) / 1000), 1, 100), act = c.act,
        why = T.outposts[pick].product }
    end
  end
  return goals
end

local function count_kind(view, kind)
  local n = 0
  for _, o in ipairs(view.outposts or {}) do if o.kind == kind then n = n + 1 end end
  return n
end

--- Émission d'un projet « expansion » (shared/ai3/projets.lua : P.EMIT.expansion = Ex.emit(P), enregistré par
--- shared/ai3/cerveau.lua). Même contrat que les autres méthodes : rend un statut ("ok", "en_cours", "matiere", "bloque", cause).
function Ex.emit(P)
  return function(E, proj, g)
    local view, kind = E.view, g.outpost
    local spec = T.outposts[kind]
    if not spec then return "bloque", "type:" .. tostring(kind) end
    if (view.pending[kind] or 0) > 0 then return "en_cours" end
    -- Des sites sont demandés tant que le but vit (prospection, puis exploration d'IA3-f).
    E.site_needs[kind] = math.max(E.site_needs[kind] or 0, 1)
    local key = "build:" .. kind
    if E.open[key] then return "en_cours" end
    -- Prévoyance bornée : le kit n'est préparé que pour un site déjà retenu (posé à brève échéance), jamais pendant la recherche.
    if Be.ahead(0, view.sites[kind] or 0) <= 0 then return "bloque", "site:" .. kind end
    local df = view.defend_first and true or false
    local turret_ok = df and (E.book:handcraftable(P.TURRET) or (E.avail[P.TURRET] or 0) > 0) or false
    local list = Planner.outpost_items(kind)
    if turret_ok and count_kind(view, kind) > 0 then
      local items = list
      list = {}
      for _, it in ipairs(items) do list[#list + 1] = it end
      local nt = T.defend_turrets(spec.drills)
      list[#list + 1] = { P.TURRET, nt }
      list[#list + 1] = { T.turret_ammo, nt * T.defend_ammo }
    end
    if P.take(E, list) then
      P.add(E, { key = key, kind = "build", prio = proj.prio + P.FINISH_BONUS, outpost_kind = kind, items = list,
        ia3 = proj.id, why = proj.key })
      return "ok"
    end
    P.want(E, proj, list, proj.prio, false, kind)
    return "matiere"
  end
end

return Ex
