--[[
  Règle « sons » du banc de l'étape data (lot S0, 24/10) : tout fichier son cité par un prototype EXISTE, a un
  format que le moteur 1.1.91 lit, et commence par l'en-tête de ce format.

  Doc prototype-api.json 1.1.91 (Sound.filename, SoundDefinition.filename) : « Supported sound file formats are
  .ogg, .wav and .voc ». En-têtes contrôlés : « OggS » (Ogg), « RIFF » … « WAVE » (wav), « Creative Voice File »
  (voc).
  Un fichier est un son si :
    - son extension est .ogg, .wav ou .voc (quel que soit le chemin de la clé) ;
    - ou s'il est cité sous une clé dont le nom contient « sound » (working_sound, attack_parameters.sound,
      ambient-sound, mined_sound…) et que ce n'est pas une image (.png) : une autre extension y est refusée
      (« format », par exemple un .mp3 que le moteur ne lit pas).
  Les sons de utility-sounds (core) sont sous des clés sans « sound » (gui_click…) : ils sont reconnus par leur
  extension. Les fichiers de vibration de manette (clés *vibration*, GameControllerVibrationData, .bnvib, cités sous
  vehicle_impact_sound) ne sont pas des sons : leur sous-arbre n'est pas « clé sound ».
  Étalonnage : la règle tourne d'abord sur TOUTE la vanilla ; une seule violation vanilla veut dire qu'elle lit mal
  le format (le banc échoue : « étalonnage vanilla »).

  OGG (lot S0-suite, mineur 2 de la vérification de S0) : « OggS » ne suffit plus. Le fichier entier est relu page par
  page (structure Ogg, RFC 3533 ; en-têtes Vorbis I, spécification Xiph §4.2), sans décoder l'audio :
    - CODEC : le premier paquet doit être l'en-tête d'identification VORBIS (« \1vorbis ») ; Opus (« OpusHead »),
      FLAC dans Ogg (« \127FLAC »), Speex ou autre : refusé (« codec »). Toute la vanilla est en Vorbis (1 422 .ogg de
      data\, relevé du 24/10) ; que le moteur 1.1.91 lise Opus ou FLAC dans Ogg n'est pas prouvé ;
    - EN-TÊTES (« Vorbis invalide ») : identification seule sur la première page, 30 octets, version 0, au moins une
      voie, fréquence non nulle, tailles de bloc 2^6 à 2^13 (petite <= grande), bit de fin ; puis les paquets de
      commentaires (« \3vorbis ») et de réglages (« \5vorbis ») ;
    - STRUCTURE (« tronqué ») : chaque page commence par « OggS » (version 0) juste après la précédente, sa table de
      segments et son corps tiennent dans le fichier, un seul flux (même numéro de série), numéros de page suivis,
      début de flux (BOS) sur la première page, fin de flux (EOS) sur la DERNIÈRE et seulement elle, et position
      (granule) de la dernière page > 0 : un fichier coupé au milieu d'une page, coupé juste entre deux pages (EOS
      absent) ou privé d'une page est refusé.
  Les sommes CRC des pages ne sont pas recalculées (trop lent en Lua sur les 1 287 fichiers vanilla) : un octet abîmé
  DANS l'audio passe ; tools/sound/sons.py --check les vérifie pour les fichiers du mod.
]]

local M = {}

local EXT = { ogg = true, wav = true, voc = true }

local function ext_of(s)
  return (s:match("%.([%w]+)$") or ""):lower()
end

local function u32(s, i)
  local a, b, c, d = s:byte(i, i + 3)
  return a + b * 256 + c * 65536 + d * 16777216
end

local function bit(v, k) -- bit k (0 = poids faible) d'un octet
  return math.floor(v / 2 ^ k) % 2 == 1
end

--- Flux Ogg Vorbis complet ? data = contenu du fichier. Rend true, ou false, le genre (« pas un son », « codec »,
--- « Vorbis invalide », « tronqué ») et le motif.
function M.ogg_vorbis(data)
  local n = #data
  if data:sub(1, 4) ~= "OggS" then return false, "pas un son", "en-tête OggS attendu" end
  local pos, pages, serial, eos_page = 1, 0, nil, nil
  local first_nseg, first_seg
  local packets, cur, cur_len = {}, {}, 0 -- les 3 premiers paquets (64 premiers octets de chacun, et leur longueur)
  local last_gran_ok = false
  while pos <= n do
    if pos + 26 > n then
      return false, "tronqué", string.format("page %d : en-tête de page incomplet (octet %d sur %d)", pages, pos - 1, n)
    end
    if data:sub(pos, pos + 3) ~= "OggS" then
      return false, "tronqué", string.format("page %d : signature OggS absente à l'octet %d (fichier coupé ou abîmé)", pages, pos - 1)
    end
    if data:byte(pos + 4) ~= 0 then
      return false, "tronqué", string.format("page %d : version Ogg %d (0 attendue)", pages, data:byte(pos + 4))
    end
    local flag = data:byte(pos + 5)
    local ser, seq = u32(data, pos + 14), u32(data, pos + 18)
    local nseg = data:byte(pos + 26)
    if pos + 26 + nseg > n then
      return false, "tronqué", string.format("page %d : table de segments coupée (fichier de %d octets)", pages, n)
    end
    local body = 0
    for k = 1, nseg do body = body + data:byte(pos + 26 + k) end
    local b0 = pos + 27 + nseg
    if b0 + body - 1 > n then
      return false, "tronqué", string.format("page %d : %d octets annoncés, %d présents (fichier coupé)", pages, body, n - b0 + 1)
    end
    if pages == 0 then
      if not bit(flag, 1) then return false, "tronqué", "première page sans marque de début de flux (BOS)" end
      serial, first_nseg, first_seg = ser, nseg, data:byte(pos + 27)
    else
      if ser ~= serial then return false, "tronqué", string.format("page %d : autre flux (numéro de série différent)", pages) end
      if bit(flag, 1) then return false, "tronqué", string.format("page %d : second début de flux (BOS)", pages) end
    end
    if seq ~= pages then
      return false, "tronqué", string.format("page %d : numéro de page %d (page manquante ou en trop)", pages, seq)
    end
    if eos_page then return false, "tronqué", string.format("page %d après la fin du flux (EOS)", pages) end
    if bit(flag, 2) then eos_page = pages end
    -- granule (8 octets) : ni 0 ni -1 sur la dernière page (contrôlé à la fin)
    local g = data:sub(pos + 6, pos + 13)
    last_gran_ok = g ~= string.rep("\0", 8) and g ~= string.rep("\255", 8) and data:byte(pos + 13) < 128
    -- paquets d'en-tête : segments de 255 = suite du même paquet
    if #packets < 3 then
      local off = b0
      for k = 1, nseg do
        local s = data:byte(pos + 26 + k)
        if cur_len < 64 then cur[#cur + 1] = data:sub(off, off + math.min(s, 64 - cur_len) - 1) end
        cur_len = cur_len + s
        off = off + s
        if s < 255 then
          packets[#packets + 1] = { head = table.concat(cur), len = cur_len }
          cur, cur_len = {}, 0
          if #packets >= 3 then break end
        end
      end
    end
    pos = b0 + body
    pages = pages + 1
  end
  local p1 = packets[1]
  if not p1 then return false, "tronqué", "aucun paquet complet" end
  local h = p1.head
  if h:sub(1, 8) == "OpusHead" then return false, "codec", "flux OPUS dans Ogg (le moteur 1.1.91 : Ogg Vorbis)" end
  if h:sub(1, 5) == "\127FLAC" then return false, "codec", "flux FLAC dans Ogg (le moteur 1.1.91 : Ogg Vorbis)" end
  if h:sub(1, 8) == "Speex   " then return false, "codec", "flux Speex dans Ogg (le moteur 1.1.91 : Ogg Vorbis)" end
  if h:sub(1, 7) ~= "\1vorbis" then
    return false, "codec", "premier paquet " .. string.format("%q", h:sub(1, 8)) .. " : pas l'en-tête d'identification Vorbis"
  end
  if first_nseg ~= 1 or first_seg ~= 30 or p1.len ~= 30 then
    return false, "Vorbis invalide", "en-tête d'identification : 30 octets seuls sur la première page attendus"
  end
  local ver, ch, rate = u32(h, 8), h:byte(12), u32(h, 13)
  local bs = h:byte(29)
  local bs0, bs1 = bs % 16, math.floor(bs / 16)
  if ver ~= 0 then return false, "Vorbis invalide", "version Vorbis " .. ver .. " (0 attendue)" end
  if ch < 1 then return false, "Vorbis invalide", "0 voie" end
  if rate < 1 then return false, "Vorbis invalide", "fréquence nulle" end
  if bs0 < 6 or bs1 > 13 or bs0 > bs1 then
    return false, "Vorbis invalide", string.format("tailles de bloc 2^%d et 2^%d (2^6 à 2^13, petite <= grande)", bs0, bs1)
  end
  if h:byte(30) % 2 ~= 1 then return false, "Vorbis invalide", "bit de fin de l'en-tête d'identification absent" end
  if not (packets[2] and packets[2].head:sub(1, 7) == "\3vorbis") then
    return false, "Vorbis invalide", "en-tête de commentaires (« \\3vorbis ») absent ou coupé"
  end
  if not (packets[3] and packets[3].head:sub(1, 7) == "\5vorbis") then
    return false, "Vorbis invalide", "en-tête de réglages (« \\5vorbis ») absent ou coupé"
  end
  if eos_page ~= pages - 1 then
    return false, "tronqué", "dernière page sans marque de fin de flux (EOS) : fichier coupé entre deux pages"
  end
  if not last_gran_ok then return false, "tronqué", "position (granule) de la dernière page nulle ou invalide" end
  return true
end

--- En-tête d'un fichier son : true, ou false, le motif et le genre (« pas un son » par défaut).
function M.header_ok(path, ext)
  local f = io.open(path, "rb")
  if not f then return false, "absent" end
  if ext == "ogg" then
    local data = f:read("*a") or ""
    f:close()
    local ok, kind, why = M.ogg_vorbis(data)
    if ok then return true end
    return false, why, kind
  end
  local head = f:read(20) or ""
  f:close()
  if ext == "wav" then
    return head:sub(1, 4) == "RIFF" and head:sub(9, 12) == "WAVE", "en-tête RIFF/WAVE attendu"
  elseif ext == "voc" then
    return head:sub(1, 19) == "Creative Voice File", "en-tête Creative Voice File attendu"
  end
  return false, "format inconnu"
end

--- Vérificateur : roots = { core = dir, base = dir, [mod] = dir }. Rend un objet avec .check(raw, only).
function M.new(roots)
  local self = { roots = roots, cache = {}, files_seen = {} }

  local function check_file(out, where, name, in_sound_key)
    local ext = ext_of(name)
    self.files_seen[name] = true
    if not EXT[ext] then
      out[#out + 1] = { where = where, what = "format", msg = name .. " (." .. ext .. " : le moteur 1.1.91 lit .ogg, .wav et .voc)" }
      return
    end
    local c = self.cache[name]
    if not c then
      local mod, rest = name:match("^__([%w%-_]+)__/(.+)$")
      if not mod or not roots[mod] then
        c = { false, "manquant", "mod inconnu" }
      else
        local path = roots[mod] .. "/" .. rest
        local ok, why, kind = M.header_ok(path, ext)
        if ok then
          c = { true }
        elseif why == "absent" then
          c = { false, "manquant", "absent" }
        else
          c = { false, kind or "pas un son", why }
        end
      end
      self.cache[name] = c
    end
    if not c[1] then
      out[#out + 1] = { where = where, what = c[2], msg = name .. " (" .. c[3] .. ")" }
    end
  end

  local function walk(out, where, t, counts, seen, in_sound)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    local fn = t.filename
    if type(fn) == "string" then
      local ext = ext_of(fn)
      if EXT[ext] or (in_sound and ext ~= "png") then
        counts.defs = counts.defs + 1
        check_file(out, where .. ".filename", fn, in_sound)
      end
    end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local lk = type(k) == "string" and k:lower() or ""
      local sub = in_sound or lk:find("sound", 1, true) ~= nil
      -- vibrations de manette (GameControllerVibrationData.filename, .bnvib) : pas des sons
      if lk:find("vibration", 1, true) then sub = false end
      walk(out, where .. "." .. tostring(k), t[k], counts, seen, sub)
    end
  end

  --- Contrôle les prototypes de raw (only : ensemble « type/nom », ou nil = tous). Rend violations et comptes.
  function self.check(raw, only)
    local out = {}
    local counts = { defs = 0, protos = 0, with_sound = 0 }
    local types = {}
    for ty in pairs(raw) do types[#types + 1] = ty end
    table.sort(types)
    for _, ty in ipairs(types) do
      local names = {}
      for n in pairs(raw[ty]) do names[#names + 1] = n end
      table.sort(names)
      for _, n in ipairs(names) do
        if not only or only[ty .. "/" .. n] then
          counts.protos = counts.protos + 1
          local before = counts.defs
          walk(out, ty .. "/" .. n, raw[ty][n], counts, {}, ty:find("sound", 1, true) ~= nil)
          if counts.defs > before then counts.with_sound = counts.with_sound + 1 end
        end
      end
    end
    return out, counts
  end

  --- Nombre de fichiers son distincts lus.
  function self.nfiles()
    local n = 0
    for _ in pairs(self.files_seen) do n = n + 1 end
    return n
  end

  return self
end

return M
