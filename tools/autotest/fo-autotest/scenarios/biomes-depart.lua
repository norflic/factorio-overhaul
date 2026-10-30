--[[
  Scénario GREFFÉ « biomes-depart » (lot BIOMES-SUIVI, 30/10) : un DÉPART dans un biome du mod sans arbre (plaine de
  cristal, champs de cratères) a-t-il du BOIS à portée ? Depuis la piste AMELIO-BIOMES (0.6.22), aucun arbre vanilla ne
  pousse plus sur les biomes du mod (W.no_vanilla_entities) ; la plaine de cristal n'a aucun arbre à elle. Le bois est une
  ressource de départ (X0 : « wood », époque 1, placement « start » ; labo à combustible, poteaux, coffres).

  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui <lot> -- 420 biomes-depart <source>

  Méthode : graines G(k) = 1000 + 7919 k, k = 1..N, sur des surfaces créées avec les réglages de nauvis (une par tick,
  supprimée aussitôt). Pour chaque graine : chunks autour de (0, 0) dans un rayon de 1 chunk ; part du biome dans un
  disque de 12 tuiles autour du départ. Départ « dans » un biome : au moins la moitié du disque. Pour les MAX_DEPARTS
  premiers départs de chaque biome : chunks jusqu'à 6 chunks (192 tuiles), arbres et BOIS (produits de minage « wood »)
  à moins de 64, 128 et RAYON_BOIS tuiles du départ, arbre le plus proche, part du biome à moins de 64 tuiles.
  Contrôle : chaque départ dans la plaine de cristal a au moins BOIS_MIN bois à moins de RAYON_BOIS tuiles.
  Les cratères sont relevés au journal (hors bilan).
]]

local N = 300
local MAX_DEPARTS = 6
local RAYON_BOIS = 150 -- tuiles : « rayon de départ » (une course à pied de 20 s environ)
local BOIS_MIN = 100 -- bois : labo à combustible (4), une trentaine de poteaux (15), coffres (2 chacun), réserve
local CHECK = 420

local BIOMES = { { tile = "fo-crystal-flats", key = "cristal", controle = true }, { tile = "fo-crater-fields", key = "crateres" } }

local function graine(k) return 1000 + 7919 * k end

local function new_surface(name, seed)
  local mgs = game.surfaces[1].map_gen_settings
  mgs.seed = seed
  if game.surfaces[name] then game.delete_surface(name) end
  return game.create_surface(name, mgs)
end

local BOIS = {} -- bois par nom d'arbre (cache)
local function bois_de(e)
  local n = e.name
  if BOIS[n] == nil then
    local q = 0
    local mp = e.prototype.mineable_properties
    for _, p in ipairs((mp and mp.products) or {}) do
      if p.name == "wood" then q = q + (p.amount or ((p.amount_min or 0) + (p.amount_max or 0)) / 2) * (p.probability or 1) end
    end
    BOIS[n] = q
  end
  return BOIS[n]
end

local function mesure(s, b)
  s.request_to_generate_chunks({ 0, 0 }, 6)
  s.force_generate_chunk_requests()
  local m = { arbres = { 0, 0, 0 }, bois = { 0, 0, 0 }, proche = nil, noms = {} }
  local R = { 64, 128, RAYON_BOIS }
  for _, e in ipairs(s.find_entities_filtered({ position = { 0, 0 }, radius = RAYON_BOIS, type = "tree" })) do
    local d = math.sqrt(e.position.x ^ 2 + e.position.y ^ 2)
    local w = bois_de(e)
    for i = 1, 3 do
      if d <= R[i] then m.arbres[i], m.bois[i] = m.arbres[i] + 1, m.bois[i] + w end
    end
    if not m.proche or d < m.proche then m.proche = d end
    m.noms[e.name] = (m.noms[e.name] or 0) + 1
  end
  local tout = s.count_tiles_filtered({ position = { 0, 0 }, radius = 64 })
  m.part64 = tout > 0 and s.count_tiles_filtered({ position = { 0, 0 }, radius = 64, name = b.tile }) / tout or 0
  return m
end

return {
  description = "BIOMES-SUIVI : bois a portee d'un depart dans un biome du mod sans arbre",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.k = 0
    st.departs = {}
    st.vus = {}
    for _, b in ipairs(BIOMES) do st.departs[b.key] = {}; st.vus[b.key] = 0 end
    ctx.log("init : " .. N .. " graines a partir de " .. graine(1) .. ", reglages de nauvis (graine " .. game.surfaces[1].map_gen_settings.seed .. ")")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick < 2 or st.k >= N then return end
    st.k = st.k + 1
    local seed = graine(st.k)
    local name = "fo-depart-" .. st.k
    local s = new_surface(name, seed)
    s.request_to_generate_chunks({ 0, 0 }, 1)
    s.force_generate_chunk_requests()
    local tout = s.count_tiles_filtered({ position = { 0, 0 }, radius = 12 })
    for _, b in ipairs(BIOMES) do
      local nb = s.count_tiles_filtered({ position = { 0, 0 }, radius = 12, name = b.tile })
      if tout > 0 and nb * 2 >= tout then
        st.vus[b.key] = st.vus[b.key] + 1
        if #st.departs[b.key] < MAX_DEPARTS then
          local m = mesure(s, b)
          m.seed, m.part12 = seed, nb / tout
          local noms = {}
          for n in pairs(m.noms) do noms[#noms + 1] = n end
          table.sort(noms)
          for i, n in ipairs(noms) do noms[i] = n .. " " .. m.noms[n] end
          m.noms = nil
          st.departs[b.key][#st.departs[b.key] + 1] = m
          ctx.log(string.format("depart %s graine %d : biome %.0f %% (12 t), %.0f %% (64 t) ; arbres a 64/128/%d t : %d/%d/%d ;"
            .. " bois %d/%d/%d ; arbre le plus proche %s ; %s", b.key, seed, 100 * m.part12, 100 * m.part64, RAYON_BOIS,
            m.arbres[1], m.arbres[2], m.arbres[3], m.bois[1], m.bois[2], m.bois[3],
            m.proche and string.format("%.0f t", m.proche) or "aucun", table.concat(noms, ", ")))
        end
      end
    end
    game.delete_surface(s)
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.log(string.format("graines vues : %d ; departs dans la plaine de cristal %d, dans les crateres %d", st.k, st.vus.cristal,
      st.vus.crateres))
    ctx.check(st.k == N, "toutes les graines vues", tostring(st.k) .. " / " .. N)
    local d = st.departs.cristal
    ctx.check(#d >= 3, "au moins 3 departs dans la plaine de cristal trouves", tostring(#d))
    local pauvres = {}
    for _, m in ipairs(d) do
      if m.bois[3] < BOIS_MIN then pauvres[#pauvres + 1] = string.format("%d (%d bois)", m.seed, m.bois[3]) end
    end
    ctx.check(#d > 0 and #pauvres == 0, string.format("chaque depart dans la plaine de cristal a au moins %d bois a moins de %d tuiles",
      BOIS_MIN, RAYON_BOIS), #pauvres == 0 and (#d .. " depart(s)") or table.concat(pauvres, ", "))
  end,
}
