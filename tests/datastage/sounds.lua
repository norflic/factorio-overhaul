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
]]

local M = {}

local EXT = { ogg = true, wav = true, voc = true }

local function ext_of(s)
  return (s:match("%.([%w]+)$") or ""):lower()
end

--- En-tête d'un fichier son : true, ou false et le motif.
function M.header_ok(path, ext)
  local f = io.open(path, "rb")
  if not f then return false, "absent" end
  local head = f:read(20) or ""
  f:close()
  if ext == "ogg" then
    return head:sub(1, 4) == "OggS", "en-tête OggS attendu"
  elseif ext == "wav" then
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
        local ok, why = M.header_ok(path, ext)
        if ok then
          c = { true }
        elseif why == "absent" then
          c = { false, "manquant", "absent" }
        else
          c = { false, "pas un son", why }
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
