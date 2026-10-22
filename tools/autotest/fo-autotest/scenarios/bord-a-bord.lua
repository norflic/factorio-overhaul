--[[
  Scénario GREFFÉ « bord-a-bord » (suite « défense dense », 22/10) : le contact EXACT entre une zone de recherche et
  la boîte de collision d'une entité, en moteur réel. Le moteur simulé (tests/mock_engine.lua, touches_area)
  EXCLUAIT le contact bord à bord dans find_entities_filtered{area}, choix jamais observé (RD_LOG E47), jusqu'au
  22/10 : le premier passage de ce banc l'a contredit (21 écarts), et touches_area a été aligné (intervalles fermés,
  RD_LOG E53). Ce banc compare chaque cas à la règle que le moteur simulé applique (RÈGLE ci-dessous) : un écart est
  un ECHEC, à corriger en alignant le moteur simulé (puis rejouer tous les bancs hors jeu).

  Entités (force neutre, zone vidée) : un mur de pierre (boîte ± 0,29), une mitrailleuse vanilla (± 0,7) et une
  tourelle laser de niveau 7 du mod (3×3, ± 1,2). Les zones sont bâties sur la boîte RENDUE par le moteur
  (bounding_box) : leurs bords tombent exactement sur ceux de la boîte, quelle que soit la représentation interne.
  Cas, pour chacune : zone égale à la boîte (témoin), contact par chacun des 4 bords, par 2 coins, chevauchement de
  1/256 (témoin), écart de 1/256 (témoin), zone NULLE sur le bord et dedans ; position seule (sans rayon) sur le
  bord, au coin et dedans ; position + rayon : centre à distance exacte du rayon, à 1/256 au-delà, et cercle qui
  touche la boîte sans contenir le centre. find_entities_filtered et count_entities_filtered, chacun.
]]

local X0, Y0, X1, Y1 = 290, 330, 360, 360
local CY = Y0 + 10.5
local Q = 1 / 256

--- RÈGLE du moteur simulé (tests/mock_engine.lua) : zone → la boîte touche-t-elle la zone ; position + rayon →
--- distance du CENTRE ; position seule : le moteur simulé l'ignore (aucun usage du mod), la doc 1.1.91 dit « the
--- given position is within the entity's collision box » (bord compris ou non : observé ici, journalisé seulement).
--- STRICT = true : contact bord à bord exclu (choix du moteur simulé jusqu'au 22/10 ; premier passage de ce banc,
--- 22/10 à 19 h 48 : 21 écarts, tous des contacts exacts RENDUS par le moteur réel, RD_LOG E53). STRICT = false :
--- contact compris, la règle du moteur simulé depuis son alignement.
local STRICT = false

local function rule_area(b, a)
  if STRICT then return b.x0 < a.x1 and a.x0 < b.x1 and b.y0 < a.y1 and a.y0 < b.y1 end
  return b.x0 <= a.x1 and a.x0 <= b.x1 and b.y0 <= a.y1 and a.y0 <= b.y1
end

local function rule_radius(c, p, r)
  local dx, dy = c.x - p.x, c.y - p.y
  return dx * dx + dy * dy <= r * r
end

local function g(v) return string.format("%.17g", v) end

return {
  description = "Contact exact zone/boite de collision en moteur reel (find_entities_filtered, count_entities_filtered)",
  base = nil,
  check_tick = 30,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.prepare_area(X0, Y0, X1, Y1, "grass-1")
    for _, en in ipairs(s.find_entities_filtered({ area = { { X0 - 48, Y0 - 48 }, { X1 + 48, Y1 + 48 } }, force = "enemy" })) do
      if en.valid then en.destroy() end
    end
    st.names = { "stone-wall", "gun-turret", "fo-lvl-laser-7" }
    st.pos = { { X0 + 10.5, CY }, { X0 + 25, CY - 0.5 }, { X0 + 40.5, CY } }
    st.made = 0
    for i, name in ipairs(st.names) do
      if game.entity_prototypes[name] and s.create_entity({ name = name, position = st.pos[i], force = "neutral" }) then st.made = st.made + 1 end
    end
    ctx.check(st.made == 3, "entites posees", st.made .. "/3")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick ~= 5 or st.done then return end
    st.done = true
    local s = ctx.surface()
    local diverge, total = {}, 0
    for i, name in ipairs(st.names) do
      local ent = s.find_entities_filtered({ name = name, position = st.pos[i] })[1]
      if not ent then
        ctx.fail(name .. " : introuvable par sa position")
      else
        local bb = ent.bounding_box
        local b = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
        local c = ent.position
        ctx.log(string.format("%s en (%s, %s) : boite (%s, %s) - (%s, %s) ; boite x 256 : %s, %s, %s, %s", name, g(c.x), g(c.y), g(b.x0), g(b.y0), g(b.x1), g(b.y1),
          g(b.x0 * 256), g(b.y0 * 256), g(b.x1 * 256), g(b.y1 * 256)))
        local function area_case(label, a, temoin)
          local found = 0
          for _, o in ipairs(s.find_entities_filtered({ area = { { a.x0, a.y0 }, { a.x1, a.y1 } }, name = name })) do if o == ent then found = found + 1 end end
          local counted = s.count_entities_filtered({ area = { { a.x0, a.y0 }, { a.x1, a.y1 } }, name = name })
          local want = rule_area(b, a)
          total = total + 1
          local seen = found == 1
          local txt = string.format("zone (%s, %s)-(%s, %s) : find %s, count %d ; regle du moteur simule : %s", g(a.x0), g(a.y0), g(a.x1), g(a.y1),
            seen and "TROUVEE" or "absente", counted, want and "trouvee" or "absente")
          if temoin ~= nil then
            ctx.check(seen == temoin and counted == (temoin and 1 or 0), name .. " : " .. label .. " (temoin)", txt)
          else
            ctx.log("OBSERVATION " .. name .. " : " .. label .. " : " .. txt)
          end
          if seen ~= want or counted ~= (seen and 1 or 0) then diverge[#diverge + 1] = name .. "/" .. label end
        end
        local function pos_case(label, p, inclusive_guess)
          local found = 0
          for _, o in ipairs(s.find_entities_filtered({ position = p, name = name })) do if o == ent then found = found + 1 end end
          local counted = s.count_entities_filtered({ position = p, name = name })
          ctx.log(string.format("OBSERVATION %s : position seule %s (%s, %s) : find %s, count %d", name, label, g(p.x), g(p.y), found == 1 and "TROUVEE" or "absente", counted))
          st.pos_obs = st.pos_obs or {}
          st.pos_obs[#st.pos_obs + 1] = name .. "/" .. label .. "=" .. (found == 1 and "oui" or "non")
        end
        local function radius_case(label, p, r)
          local found = 0
          for _, o in ipairs(s.find_entities_filtered({ position = p, radius = r, name = name })) do if o == ent then found = found + 1 end end
          local counted = s.count_entities_filtered({ position = p, radius = r, name = name })
          local want = rule_radius(c, p, r)
          total = total + 1
          ctx.log(string.format("OBSERVATION %s : rayon %s, position (%s, %s), rayon %s : find %s, count %d ; regle du moteur simule (distance du centre) : %s", name, label,
            g(p.x), g(p.y), g(r), found == 1 and "TROUVEE" or "absente", counted, want and "trouvee" or "absente"))
          if (found == 1) ~= want or counted ~= found then diverge[#diverge + 1] = name .. "/rayon " .. label end
        end
        local cy = (b.y0 + b.y1) / 2
        area_case("zone egale a la boite", b, true)
        area_case("chevauchement de 1/256 a l'est", { x0 = b.x1 - Q, y0 = b.y0, x1 = b.x1 + 1, y1 = b.y1 }, true)
        area_case("ecart de 1/256 a l'est", { x0 = b.x1 + Q, y0 = b.y0, x1 = b.x1 + 1, y1 = b.y1 }, false)
        area_case("contact bord est", { x0 = b.x1, y0 = b.y0, x1 = b.x1 + 1, y1 = b.y1 })
        area_case("contact bord ouest", { x0 = b.x0 - 1, y0 = b.y0, x1 = b.x0, y1 = b.y1 })
        area_case("contact bord nord", { x0 = b.x0, y0 = b.y0 - 1, x1 = b.x1, y1 = b.y0 })
        area_case("contact bord sud", { x0 = b.x0, y0 = b.y1, x1 = b.x1, y1 = b.y1 + 1 })
        area_case("contact coin sud-est", { x0 = b.x1, y0 = b.y1, x1 = b.x1 + 1, y1 = b.y1 + 1 })
        area_case("contact coin nord-ouest", { x0 = b.x0 - 1, y0 = b.y0 - 1, x1 = b.x0, y1 = b.y0 })
        area_case("zone nulle sur le bord est", { x0 = b.x1, y0 = cy, x1 = b.x1, y1 = cy })
        area_case("zone nulle dedans", { x0 = c.x, y0 = c.y, x1 = c.x, y1 = c.y })
        pos_case("dedans", { x = c.x, y = c.y })
        pos_case("sur le bord est", { x = b.x1, y = cy })
        pos_case("sur le bord ouest", { x = b.x0, y = cy })
        pos_case("au coin sud-est", { x = b.x1, y = b.y1 })
        radius_case("centre a distance exacte (3)", { x = c.x + 3, y = c.y }, 3)
        radius_case("centre a 1/256 au-dela", { x = c.x + 3, y = c.y }, 3 - Q)
        radius_case("cercle qui touche la boite, centre hors du cercle", { x = b.x1 + 1, y = c.y }, 1)
        -- Cercle centré à 1/4 de tuile à l'est de la boîte, de rayon = distance au centre de l'entité - 1/256 : il entre
        -- dans la boîte (de demi-largeur - 1/4 - 1/256, positif pour les trois entités) sans contenir le centre.
        -- Premier passage : un rayon fixe de 1 contenait le centre du mur (cas mal nommé, corrigé).
        local d = b.x1 + 0.25 - c.x
        radius_case("cercle qui entre dans la boite sans atteindre le centre", { x = b.x1 + 0.25, y = c.y }, d - Q)
      end
    end
    st.diverge = diverge
    st.total = total
    ctx.check(#diverge == 0, "moteur reel conforme a la regle du moteur simule (zone : " .. (STRICT and "contact bord a bord EXCLU" or "contact bord a bord INCLUS")
      .. " ; rayon : distance du centre, bord compris)", (#diverge > 0 and ("ecarts : " .. table.concat(diverge, ", ")) or "aucun ecart") .. " (" .. total .. " cas compares)")
    ctx.log("positions seules : " .. table.concat(st.pos_obs or {}, " "))
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.done == true, "cas joues au tick 5", tostring(st.total) .. " cas")
  end,
}
