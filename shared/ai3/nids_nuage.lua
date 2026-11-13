--[[
  Lot S42-DEFENSE (chantier 6.3 du DC : raids préventifs). NIDS SOUS LE NUAGE. PUR (aucune API Factorio, aucun nom d'objet), testé hors jeu
  par tests/s42_defense_test.lua.

  Constat (journal de la partie du DC, 0.7.96) : la chaîne du raid préventif EXISTE (shared/ai3/armee.lua, A.estimate ; porte
  Pc.raid_gate : « champ sans vague (aucune pollution ne l'atteint) ») mais elle ne lit que les nids CONNUS de l'équipe
  (script/ai3/prevision.lua, nests_of), et un nid n'est connu que si un PNJ est passé devant. emerald émet 2 400 de pollution par
  minute, perd sa centrale à 141 min et ses tourelles du QG jusqu'à 222 min, avec « 0 nid(s) connu(s) » à CHAQUE relevé de 0 à 249 min :
  aucune vague prévue (101 lignes « RATE »), aucun champ menaçant, aucun raid.

  Règle : un nid que le nuage de pollution de l'équipe ATTEINT se dénonce (l'équipe lit son nuage ; c'est lui qui réveille le nid).
    * candidats = nids relevés autour d'UN site de l'équipe par passage (tour de rôle : Nn.site_index), avec la pollution à leur case ;
    * gardés : pollution ≥ Nn.P_MIN, à moins de `r` tuiles d'un site, pas déjà connus (à Nn.SAME tuiles près) ;
    * au plus Nn.MAX_NEW nids nouveaux par passage, les plus proches d'un site d'abord (égalité : x puis y).
  Le reste (vague prévue, alerte, recrutement, regroupement, raid contre le champ le plus proche, une cible à la fois) est la chaîne
  existante, inchangée. Coupure de banc : Nn.ON = false.
]]

local Nn = {}

Nn.ON = true
Nn.P_MIN = 1      -- pollution à la case du nid : le nuage l'atteint
Nn.SAME = 3       -- tuiles : un candidat aussi près d'un nid connu est ce nid (comme D.KINDS.spawner.same, shared/ai3/danger.lua)
Nn.MAX_NEW = 4    -- nids nouveaux par passage au plus

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v or nil end

--- Site relevé au passage n° `turn` (0, 1, 2…) parmi `n` sites : tour de rôle. Rend l'indice (1..n) ou nil sans site.
function Nn.site_index(turn, n)
  n = math.floor(num(n) or 0)
  if n < 1 then return nil end
  return (math.floor(num(turn) or 0) % n) + 1
end

--- cands = { { x, y, p } } (nids relevés, pollution à leur case) ; sites = { { x, y } } ; known = { { x, y } } (nids déjà connus) ;
--- r = portée (tuiles) d'un site. Rend la liste triée { { x, y, p, dd } } des nids à faire connaître (au plus Nn.MAX_NEW).
function Nn.pick(cands, sites, known, r)
  local out = {}
  local r2 = (num(r) or 0) ^ 2
  local same2 = Nn.SAME * Nn.SAME
  for _, c in ipairs(cands or {}) do
    local x, y, p = num(c.x), num(c.y), num(c.p) or 0
    if x and y and p >= Nn.P_MIN then
      local best
      for _, s in ipairs(sites or {}) do
        local dd = (x - s.x) ^ 2 + (y - s.y) ^ 2
        if not best or dd < best then best = dd end
      end
      local dup = false
      for _, k in ipairs(known or {}) do
        if (x - k.x) ^ 2 + (y - k.y) ^ 2 <= same2 then dup = true break end
      end
      for _, o in ipairs(out) do
        if (x - o.x) ^ 2 + (y - o.y) ^ 2 <= same2 then dup = true break end
      end
      if best and best <= r2 and not dup then out[#out + 1] = { x = x, y = y, p = p, dd = best } end
    end
  end
  table.sort(out, function(a, b)
    if a.dd ~= b.dd then return a.dd < b.dd end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  while #out > Nn.MAX_NEW do out[#out] = nil end
  return out
end

return Nn
