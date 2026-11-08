--[[
  Lot DEBUG-CERVEAU : dessin des zones sur la carte, visible du SEUL joueur qui regarde (rendering avec players = { index }).
  Une zone (bloc) = un rectangle (couleur = état réel : vert marche, orange dégradé, rouge arrêté, gris prévu ou en construction) et un texte à deux
  lignes (production attribuée, débit lu / visé, cause principale, X/N en marche ; puis ce que le cerveau en sait et depuis quand). Un écart qui compte
  ajoute un disque rouge ou orange au coin de la zone.
  V2 (directive du DC du 8/11) : sur chaque bloc, « ENTRÉE <objet> » sur les coffres d'entrée (p.quais) et « SORTIE » sur les coffres de sortie (p.outs) ;
  un trait par ligne enregistrée (liaison de quai bleu, tronc de bus jaune, branche de piquage magenta ; pointillé tant que le projet n'est pas fini)
  avec un disque à l'arrivée, le coffre d'entrée marqué « TAMPON <- source » et le répartiteur de piquage marqué « REPARTITEUR ».
  COÛT : au plus Rendu.BUDGET objets par redessin, classés par importance (zones, puis entrées et sorties de la zone retenue et des zones à écart, puis
  liaisons) ; les objets sont recréés à chaque redessin (1 s) et vivent un peu plus longtemps (time_to_live) : si le mod perdait leurs numéros, ils
  s'éteindraient seuls. Leurs numéros sont rangés dans l'état de la vue (nombres).
]]

local Lg = require("shared.debug.lignes")
local Bl = require("shared.debug.blocs")

local Rendu = {}

Rendu.TTL = 150
Rendu.BUDGET = 260   -- objets de rendu au plus par redessin et par joueur
Rendu.COLORS = {
  vert = { r = 0.25, g = 0.85, b = 0.3, a = 1 },
  orange = { r = 1, g = 0.62, b = 0.1, a = 1 },
  rouge = { r = 1, g = 0.2, b = 0.2, a = 1 },
  gris = { r = 0.62, g = 0.62, b = 0.62, a = 1 },
}
Rendu.SEL = { r = 1, g = 1, b = 1, a = 1 }
Rendu.SEV_COLOR = { alerte = { r = 1, g = 0.1, b = 0.1, a = 1 }, attention = { r = 1, g = 0.6, b = 0.1, a = 1 } }
Rendu.DRAW_KINDS = { module = true, fonderie = true, labos = true, centrale = true, champ = true, site = true, quartier = true, avant_poste = true }
Rendu.IN_COLOR = { r = 0.35, g = 0.8, b = 1, a = 1 }
Rendu.OUT_COLOR = { r = 1, g = 0.75, b = 0.3, a = 1 }
Rendu.LINK_COLOR = { quai = { r = 0.3, g = 0.6, b = 1, a = 1 }, bus = { r = 1, g = 0.9, b = 0.2, a = 1 }, piquage = { r = 1, g = 0.3, b = 0.9, a = 1 } }
Rendu.MANY = 12      -- au-delà de ce nombre de zones, entrées et sorties ne sont écrites que sur la zone retenue et celles à écart

--- Réglages du joueur (settings/debug_cerveau.lua) ; absents : valeurs par défaut.
function Rendu.options(player)
  local o = { texts = true, only_gaps = false }
  local ok, s = pcall(settings.get_player_settings, player)
  if ok and s then
    if s["fo-dbg-cerveau-textes"] then o.texts = s["fo-dbg-cerveau-textes"].value == true end
    if s["fo-dbg-cerveau-ecarts-seuls"] then o.only_gaps = s["fo-dbg-cerveau-ecarts-seuls"].value == true end
  end
  return o
end

function Rendu.clear(v)
  for _, id in ipairs(v.render or {}) do
    if rendering.is_valid(id) then rendering.destroy(id) end
  end
  v.render = {}
end

local function text_of(row, now)
  local z = row.z
  local line1 = Lg.label({ kind = z.kind, product = z.product, rate_meas = z.rate_meas, rate_nom = z.rate_nom, color = row.color, cause = row.cause,
    n = z.n, run = z.run })
  local ec = row.ecart
  if ec.kind == "non_applicable" then return line1 end
  local ago = ec.age and Lg.ago(ec.age) or Lg.ago(nil)
  local line2 = { "fo-dbg-cerveau.zone-ia", ec.text, ago }
  return { "", line1, "\n", line2 }
end

--- Redessine les zones de `rows` pour le joueur. `sel` : clé de la zone retenue (cadre plus épais). `links` : lignes de Bl.lines (ou nil).
--- Rend le nombre d'objets créés.
function Rendu.draw(player, v, rows, sel, opts, now, surface, links)
  Rendu.clear(v)
  surface = surface or player.surface
  local ids = {}
  local me = { player.index }
  local function room() return #ids < Rendu.BUDGET end
  -- 1. zones (rectangle, disque d'écart, texte)
  for _, row in ipairs(rows) do
    local z = row.z
    if room() and Rendu.DRAW_KINDS[z.kind] and z.x0 and z.x1 and (not opts.only_gaps or row.sev == "alerte" or row.sev == "attention") then
      local col = Rendu.COLORS[row.color] or Rendu.COLORS.gris
      local selected = row.key == sel
      ids[#ids + 1] = rendering.draw_rectangle({ color = selected and Rendu.SEL or col, width = selected and 5 or 2, filled = false,
        left_top = { z.x0, z.y0 }, right_bottom = { z.x1, z.y1 }, surface = surface, time_to_live = Rendu.TTL, players = me })
      if selected then
        ids[#ids + 1] = rendering.draw_rectangle({ color = { r = col.r, g = col.g, b = col.b, a = 0.18 }, filled = true,
          left_top = { z.x0, z.y0 }, right_bottom = { z.x1, z.y1 }, surface = surface, time_to_live = Rendu.TTL, players = me, draw_on_ground = true })
      end
      local sevc = Rendu.SEV_COLOR[row.sev]
      if sevc then
        ids[#ids + 1] = rendering.draw_circle({ color = sevc, radius = 0.9, filled = true, target = { z.x1, z.y0 }, surface = surface,
          time_to_live = Rendu.TTL, players = me })
      end
      if opts.texts then
        ids[#ids + 1] = rendering.draw_text({ text = text_of(row, now), surface = surface, target = { z.x0, z.y0 - 0.3 }, color = col, scale = 1.0,
          alignment = "left", vertical_alignment = "bottom", time_to_live = Rendu.TTL, players = me })
      end
    end
  end
  -- 2. entrées et sorties reconnues par le cerveau (p.quais, p.outs)
  if opts.texts then
    local many = #rows > Rendu.MANY
    for _, row in ipairs(rows) do
      local z = row.z
      if z.io and Rendu.DRAW_KINDS[z.kind] and (not many or row.key == sel or row.sev == "alerte" or row.sev == "attention") then
        for _, q in ipairs(z.io.ins or {}) do
          if room() then
            ids[#ids + 1] = rendering.draw_text({ text = q.item and { "fo-dbg-cerveau.io-entree", { "item-name." .. q.item } } or { "fo-dbg-cerveau.io-entree-sans" },
              surface = surface, target = { q.x, q.y - 0.9 }, color = Rendu.IN_COLOR, scale = 0.8, alignment = "center", time_to_live = Rendu.TTL, players = me })
          end
        end
        for _, o in ipairs(z.io.outs or {}) do
          if room() then
            ids[#ids + 1] = rendering.draw_text({ text = z.product and { "fo-dbg-cerveau.io-sortie", { "item-name." .. z.product } } or { "fo-dbg-cerveau.io-sortie-sans" },
              surface = surface, target = { o.x, o.y - 0.9 }, color = Rendu.OUT_COLOR, scale = 0.8, alignment = "center", time_to_live = Rendu.TTL, players = me })
          end
        end
      end
    end
  end
  -- 3. liaisons enregistrées, tampons, répartiteurs
  for _, l in ipairs(links or {}) do
    if room() then
      local col = Rendu.LINK_COLOR[l.kind] or Rendu.LINK_COLOR.quai
      local dashed = not l.done
      ids[#ids + 1] = rendering.draw_line({ color = col, width = 3, from = { l.from.x, l.from.y }, to = { l.to.x, l.to.y }, surface = surface, time_to_live = Rendu.TTL,
        players = me, dash_length = dashed and 0.5 or nil, gap_length = dashed and 0.5 or nil })
      if room() then
        ids[#ids + 1] = rendering.draw_circle({ color = col, radius = 0.45, filled = true, target = { l.to.x, l.to.y }, surface = surface, time_to_live = Rendu.TTL, players = me })
      end
      if opts.texts and room() then
        ids[#ids + 1] = rendering.draw_text({ text = { "fo-dbg-cerveau.lien-ligne", { "fo-dbg-cerveau.lien-" .. l.kind }, l.item and { "item-name." .. l.item } or "?" },
          surface = surface, target = { (l.from.x + l.to.x) / 2, (l.from.y + l.to.y) / 2 - 0.6 }, color = col, scale = 0.8, alignment = "center",
          time_to_live = Rendu.TTL, players = me })
      end
    end
  end
  if opts.texts then
    for _, b in ipairs(Bl.buffers(links)) do
      if room() then
        local src = b.source and { "fo-dbg-cerveau.lien-source-bloc", tostring(b.source) } or { "fo-dbg-cerveau.lien-source-tapis" }
        ids[#ids + 1] = rendering.draw_text({ text = { "fo-dbg-cerveau.lien-tampon", src }, surface = surface, target = { b.x, b.y + 0.7 },
          color = Rendu.LINK_COLOR[b.kind] or Rendu.LINK_COLOR.quai, scale = 0.8, alignment = "center", time_to_live = Rendu.TTL, players = me })
      end
    end
    for _, s in ipairs(Bl.splitters(links)) do
      if room() then
        ids[#ids + 1] = rendering.draw_text({ text = { "fo-dbg-cerveau.lien-repartiteur", s.item and { "item-name." .. s.item } or "?" }, surface = surface,
          target = { s.x, s.y - 0.9 }, color = Rendu.LINK_COLOR.piquage, scale = 0.8, alignment = "center", time_to_live = Rendu.TTL, players = me })
      end
    end
  end
  v.render = ids
  return #ids
end

return Rendu
