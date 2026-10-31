-- Scénario greffé du lot BI-0 (31/10) : TAILLES DES DÉCHIQUETEURS. Une taille k par famille (image et boîtes), le moucheron
-- de l'essaim en corps de petit cracheur nain, le nid d'essaim à deux fois plus d'unités et de naissances.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui BI0 -- 2500 bi-tailles <source>                    (contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache" --qui BI0 -- 2500 bi-tailles <source>
-- Galerie (carte de béton) : 7 rangées (sans famille, puis les 6 familles), 4 paliers (1, 4, 8, 12) × 2 types (déchiqueteur,
-- cracheur) par rangée, un mur à gauche de chaque rangée pour l'échelle, unités IMMOBILES (active = false) tournées vers l'ouest.
-- Deux nids loin de la galerie et l'un de l'autre : le nid d'essaim et un nid témoin (ignée), sans rien autour ; au tick de
-- contrôle, le nid d'essaim a produit plus d'unités que le témoin, sans dépasser son plafond de 14, et toutes sont de l'essaim.
-- Table : fo-shots/bi-tailles-sites.tsv.

local X0, Y0 = 4200, 3000
local PAS_X, PAS_Y = 8, 9
local PALIERS = { 1, 4, 8, 12 }
local NIDS = { essaim = { 4200, 3300, "fo-swarm-nest" }, temoin = { 4200, 3420, "fo-pyro-nest" } }
local ORDRE_NIDS = { "essaim", "temoin" }
local PLAFOND_ESSAIM = 14
local TICK_CONTROLE = 2400

-- demi-côté attendu de la collision, écrit en dur (PLAN §5 ter, indépendant de la règle) : biter palier 1 / 8 / 12
local BOITE_BITER = {
  armored = { 0.23, 0.84, 0.87 }, pyro = { 0.20, 0.73, 0.76 }, brood = { 0.22, 0.81, 0.84 },
  storm = { 0.18, 0.66, 0.68 }, toxic = { 0.25, 0.90, 0.90 }, swarm = { 0.12, 0.44, 0.46 },
}
-- cracheur : palier 1 = 0,3 (petit cracheur vanilla) × k ; paliers 8 et 12 : mêmes boîtes que le déchiqueteur (base 0,4)
local BOITE_CRACHEUR_1 = { armored = 0.345, pyro = 0.30, brood = 0.33, storm = 0.27, toxic = 0.375, swarm = 0.18 }
local FAMILLES = { "armored", "pyro", "brood", "storm", "toxic", "swarm" }
local TN = { "small", "medium", "big", "behemoth", "colossal", "titan", "apex", "primordial", "ancestral", "abyssal",
  "cataclysmic", "eternal" }

local function nom(kind, palier, famille)
  if famille then return "fo-" .. famille .. "-" .. TN[palier] .. "-" .. kind end
  if palier <= 4 then return TN[palier] .. "-" .. kind end
  return "fo-" .. TN[palier] .. "-" .. kind
end

local function proche(a, b, tol) return a ~= nil and math.abs(a - b) <= tol end

--- Nombre d'unités de la force ennemie autour d'un nid et nombre d'unités d'un autre nom que celui de l'essaim.
local function compter(s, nid, prefixe)
  local n, autres = 0, 0
  for _, u in ipairs(s.find_entities_filtered({ type = "unit", force = "enemy", position = nid.position, radius = 60 })) do
    n = n + 1
    if prefixe and u.name:sub(1, #prefixe) ~= prefixe then autres = autres + 1 end
  end
  return n, autres
end

return {
  description = "BI-0 : tailles des dechiqueteurs par famille (boites, moucheron en corps de cracheur nain), nid d'essaim",
  base = nil,
  check_tick = TICK_CONTROLE,
  shots_delay = TICK_CONTROLE + 20,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites, st.suivi = {}, {}
    ctx.prepare_area(X0 - 10, Y0 - 10, X0 + #PALIERS * 2 * PAS_X + 6, Y0 + 7 * PAS_Y + 4, "concrete")
    for _, cle in ipairs(ORDRE_NIDS) do
      local n = NIDS[cle]
      ctx.prepare_area(n[1] - 40, n[2] - 40, n[1] + 40, n[2] + 40, "grass-1")
    end
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 150, Y0 - 150 }, { X0 + 400, Y0 + 520 } } })) do
      en.destroy()
    end

    -- galerie : rangée 0 sans famille, rangées 1 à 6 les familles
    local poses = 0
    for r = 0, #FAMILLES do
      local famille = FAMILLES[r]
      local y = Y0 + r * PAS_Y
      s.create_entity({ name = "stone-wall", position = { X0 - 3.5, y + 0.5 }, force = "player" })
      for c, palier in ipairs(PALIERS) do
        for k, kind in ipairs({ "biter", "spitter" }) do
          local x = X0 + ((c - 1) * 2 + (k - 1)) * PAS_X
          local u = s.create_entity({ name = nom(kind, palier, famille), position = { x, y }, force = "enemy" })
          if u then
            poses = poses + 1
            u.active = false
            pcall(function() u.orientation = 0.75 end)
          end
          st.sites[#st.sites + 1] = { famille = famille or "base", palier = palier, kind = kind, x = x, y = y, u = u, rang = r }
        end
      end
    end
    ctx.check(poses == (#FAMILLES + 1) * #PALIERS * 2, "galerie : 7 rangees x 4 paliers x 2 types posees",
      poses .. " / " .. (#FAMILLES + 1) * #PALIERS * 2)

    -- nids : le nid d'essaim et le témoin, rien autour
    st.nids = {}
    for _, cle in ipairs(ORDRE_NIDS) do
      local n = NIDS[cle]
      st.nids[cle] = s.create_entity({ name = n[3], position = { n[1], n[2] }, force = "enemy" })
    end
    ctx.check(st.nids.essaim ~= nil and st.nids.temoin ~= nil, "nid d'essaim et nid temoin poses")

    -- boîtes des prototypes contre le tableau écrit en dur
    local p = game.entity_prototypes
    local mauvaises, n = {}, 0
    local function demi(proto) return proto and proto.collision_box.right_bottom.x end
    for _, famille in ipairs(FAMILLES) do
      local att = BOITE_BITER[famille]
      for i, palier in ipairs({ 1, 8, 12 }) do
        n = n + 1
        local d = demi(p[nom("biter", palier, famille)])
        if not proche(d, att[i], 0.0075) then mauvaises[#mauvaises + 1] = string.format("%s biter %d : %s", famille, palier, tostring(d)) end
      end
      n = n + 1
      local d1 = demi(p[nom("spitter", 1, famille)])
      if not proche(d1, BOITE_CRACHEUR_1[famille], 0.0075) then mauvaises[#mauvaises + 1] = famille .. " cracheur 1 : " .. tostring(d1) end
      for i, palier in ipairs({ 8, 12 }) do
        n = n + 1
        local d = demi(p[nom("spitter", palier, famille)])
        if not proche(d, att[i + 1], 0.0075) then mauvaises[#mauvaises + 1] = string.format("%s cracheur %d : %s", famille, palier, tostring(d)) end
      end
    end
    ctx.check(#mauvaises == 0, "boites de collision des 6 familles aux paliers 1, 8 et 12 (biters et cracheurs) = tableau du PLAN",
      n .. " mesures" .. (#mauvaises > 0 and (" ; ecarts : " .. table.concat(mauvaises, " ; ")) or ""))
    local plafond = true
    for _, famille in ipairs(FAMILLES) do
      for palier = 1, 12 do
        for _, kind in ipairs({ "biter", "spitter" }) do
          local pr = p[nom(kind, palier, famille)]
          if not pr or pr.collision_box.right_bottom.x > 0.9 + 1e-6 then plafond = false end
        end
      end
    end
    ctx.check(plafond, "aucune boite de famille au-dela de 0,9 (144 prototypes)")
    -- sans famille : boites vanilla et du palier, inchangées
    ctx.check(proche(demi(p["small-biter"]), 0.2, 0.006) and proche(demi(p["fo-eternal-biter"]), 0.76, 0.006) and
      proche(demi(p["fo-primordial-biter"]), 0.4 * 2.2 / 1.2, 0.006), "sans famille : boites vanilla et de palier inchangees")
    -- nid d'essaim : prototypes
    local ne, nt = p["fo-swarm-nest"], p[NIDS.temoin[3]]
    ctx.check(ne and nt and ne.max_count_of_owned_units == PLAFOND_ESSAIM and nt.max_count_of_owned_units == 7 and
      ne.max_friends_around_to_spawn == 2 * nt.max_friends_around_to_spawn, "nid d'essaim : plafond de 14 unites (7 au temoin), amis alentour x2",
      ne and (ne.max_count_of_owned_units .. " / " .. ne.max_friends_around_to_spawn))
  end,

  tick = function(ctx, e)
    if e.tick % 300 ~= 0 or e.tick == 0 then return end
    local s, st = ctx.surface(), ctx.state()
    local a, b = st.nids.essaim, st.nids.temoin
    if a and a.valid and b and b.valid then
      local na = compter(s, a)
      local nb = compter(s, b)
      st.suivi[#st.suivi + 1] = string.format("%d:%d/%d", e.tick, na, nb)
    end
  end,

  finish = function(ctx)
    local s, st = ctx.surface(), ctx.state()
    local a, b = st.nids.essaim, st.nids.temoin
    local vivants = 0
    for _, c in ipairs(st.sites) do if c.u and c.u.valid then vivants = vivants + 1 end end
    ctx.check(vivants == #st.sites, "galerie : toutes les unites sont toujours la", vivants .. " / " .. #st.sites)
    ctx.check(a and a.valid and b and b.valid, "les deux nids sont toujours la")
    if not (a and a.valid and b and b.valid) then return end
    local na, autres = compter(s, a, "fo-swarm-")
    local nb = compter(s, b)
    ctx.log("suivi des naissances (tick:essaim/temoin) : " .. table.concat(st.suivi, " "))
    ctx.check(na >= 8 and na <= PLAFOND_ESSAIM, "nid d'essaim : entre 8 et 14 unites au tick " .. TICK_CONTROLE, na)
    ctx.check(autres == 0, "toutes les unites du nid d'essaim sont de l'essaim", autres .. " autres")
    ctx.check(nb >= 1 and nb <= 7, "nid temoin : 1 a 7 unites (plafond vanilla 7)", nb)
    ctx.check(na > nb, "le nid d'essaim a produit plus d'unites que le temoin", na .. " contre " .. nb)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tgenre\tfamille\tpalier\tx\ty" }
    local colonnes = #PALIERS * 2
    local xg0, xg1 = X0 - 5, X0 + (colonnes - 1) * PAS_X + 5
    -- une capture par rangée (zoom 1), de jour
    for r = 0, #FAMILLES do
      local famille = FAMILLES[r] or "base"
      local cx, cy = (xg0 + xg1) / 2, Y0 + r * PAS_Y - 1
      local nm = string.format("rang%d-%s-z1", r, famille)
      add(nm, cx, cy, 1, 0, { res = { math.ceil((xg1 - xg0) * 32), math.ceil(PAS_Y * 32) }, info = false, aa = true })
      L[#L + 1] = string.format("%s\trang\t%s\t0\t%.2f\t%.2f", nm, famille, cx, cy)
    end
    -- toute la galerie, vue d'ensemble au zoom 0,5
    local cy_tot = Y0 + (#FAMILLES * PAS_Y) / 2 - 1
    add("galerie-z05", (xg0 + xg1) / 2, cy_tot, 0.5, 0, { res = { math.ceil((xg1 - xg0) * 16), math.ceil((#FAMILLES + 1) * PAS_Y * 16) },
      info = false, aa = true })
    L[#L + 1] = string.format("galerie-z05\tgalerie\t\t0\t%.2f\t%.2f", (xg0 + xg1) / 2, cy_tot)
    -- une colonne de paliers pour toutes les familles (deux types côte à côte), zoom 1 ; palier 1 aussi au zoom 2
    for c, palier in ipairs(PALIERS) do
      local x0 = X0 + (c - 1) * 2 * PAS_X - PAS_X / 2
      local w, h = 2 * PAS_X, (#FAMILLES + 1) * PAS_Y
      local cx, cy = x0 + w / 2 - 0.5, Y0 + (#FAMILLES * PAS_Y) / 2 - 1
      local nm = string.format("palier%02d-z1", palier)
      add(nm, cx, cy, 1, 0, { res = { math.ceil(w * 32), math.ceil(h * 32) }, info = false, aa = true })
      L[#L + 1] = string.format("%s\tpalier\t\t%d\t%.2f\t%.2f", nm, palier, cx, cy)
      if palier == 1 then
        local n2 = "palier01-z2"
        add(n2, cx, cy, 2, 0, { res = { math.ceil(w * 64), math.ceil(h * 64) }, info = false, aa = true })
        L[#L + 1] = string.format("%s\tpalier\t\t1\t%.2f\t%.2f", n2, cx, cy)
      end
    end
    -- les deux nids et leurs unités
    for _, cle in ipairs(ORDRE_NIDS) do
      local n = NIDS[cle]
      local nm = "nid-" .. cle .. "-z1"
      add(nm, n[1], n[2], 1, 0, { res = { 1280, 800 }, info = false, aa = true })
      L[#L + 1] = string.format("%s\tnid\t%s\t0\t%.2f\t%.2f", nm, cle, n[1], n[2])
    end
    game.write_file("fo-shots/bi-tailles-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
