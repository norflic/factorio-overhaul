--[[
  Lot DEBUG-CERVEAU : dessin des zones sur la carte, visible du SEUL joueur qui regarde (rendering avec players = { index }).
  Une zone = un rectangle (couleur = état réel : vert marche, orange dégradé, rouge arrêté, gris prévu ou en construction) et un texte à deux
  lignes (production attribuée, débit lu / visé, cause principale ; puis ce que le cerveau en sait et depuis quand). Un écart qui compte
  (le cerveau croit que ça marche alors que non, lecture périmée, jamais lue) ajoute un disque rouge ou orange au coin de la zone.
  Les objets sont recréés à chaque redessin (1 s) et vivent un peu plus longtemps (time_to_live) : si le mod perdait leurs numéros, ils
  s'éteindraient seuls. Leurs numéros sont rangés dans l'état de la vue (nombres), pour être détruits au redessin et à la fermeture.
]]

local Lg = require("shared.debug.lignes")

local Rendu = {}

Rendu.TTL = 150
Rendu.COLORS = {
  vert = { r = 0.25, g = 0.85, b = 0.3, a = 1 },
  orange = { r = 1, g = 0.62, b = 0.1, a = 1 },
  rouge = { r = 1, g = 0.2, b = 0.2, a = 1 },
  gris = { r = 0.62, g = 0.62, b = 0.62, a = 1 },
}
Rendu.SEL = { r = 1, g = 1, b = 1, a = 1 }
Rendu.SEV_COLOR = { alerte = { r = 1, g = 0.1, b = 0.1, a = 1 }, attention = { r = 1, g = 0.6, b = 0.1, a = 1 } }
Rendu.DRAW_KINDS = { module = true, fonderie = true, labos = true, centrale = true, champ = true, site = true, quartier = true, avant_poste = true }

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
  local line1 = Lg.label({ kind = z.kind, product = z.product, rate_meas = z.rate_meas, rate_nom = z.rate_nom, color = row.color, cause = row.cause })
  local ec = row.ecart
  if ec.kind == "non_applicable" then return line1 end
  local ago = ec.age and Lg.ago(ec.age) or Lg.ago(nil)
  local line2 = { "fo-dbg-cerveau.zone-ia", ec.text, ago }
  return { "", line1, "\n", line2 }
end

--- Redessine les zones de `rows` pour le joueur. `sel` : clé de la zone retenue (cadre plus épais).
function Rendu.draw(player, v, rows, sel, opts, now, surface)
  Rendu.clear(v)
  surface = surface or player.surface
  local ids = {}
  local n = 0
  for _, row in ipairs(rows) do
    local z = row.z
    if Rendu.DRAW_KINDS[z.kind] and z.x0 and z.x1 and (not opts.only_gaps or row.sev == "alerte" or row.sev == "attention") then
      n = n + 1
      local col = Rendu.COLORS[row.color] or Rendu.COLORS.gris
      local selected = row.key == sel
      ids[#ids + 1] = rendering.draw_rectangle({ color = selected and Rendu.SEL or col, width = selected and 5 or 2, filled = false,
        left_top = { z.x0, z.y0 }, right_bottom = { z.x1, z.y1 }, surface = surface, time_to_live = Rendu.TTL, players = { player.index } })
      if selected then
        ids[#ids + 1] = rendering.draw_rectangle({ color = { r = col.r, g = col.g, b = col.b, a = 0.18 }, filled = true,
          left_top = { z.x0, z.y0 }, right_bottom = { z.x1, z.y1 }, surface = surface, time_to_live = Rendu.TTL, players = { player.index },
          draw_on_ground = true })
      end
      local sevc = Rendu.SEV_COLOR[row.sev]
      if sevc then
        ids[#ids + 1] = rendering.draw_circle({ color = sevc, radius = 0.9, filled = true, target = { z.x1, z.y0 }, surface = surface,
          time_to_live = Rendu.TTL, players = { player.index } })
      end
      if opts.texts then
        ids[#ids + 1] = rendering.draw_text({ text = text_of(row, now), surface = surface, target = { z.x0, z.y0 - 0.3 }, color = col, scale = 1.0,
          alignment = "left", vertical_alignment = "bottom", time_to_live = Rendu.TTL, players = { player.index } })
      end
    end
  end
  v.render = ids
  return n
end

return Rendu
