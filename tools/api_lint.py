#!/usr/bin/env python3
"""
Vérifie les appels d'API du mod contre la documentation machine de la version installée
(doc-html/runtime-api.json, livrée avec Factorio).

Usage :  python3 tools/api_lint.py <chemin vers doc-html> [racine du mod]

Contrôles :
  1. game.X / script.X / rendering.X / commands.X : le membre existe sur la classe globale.
  2. defines.events.X / defines.direction.X : la constante existe.
  3. Membres d'objets utilisés via des variables (liste RECEIVERS ci-dessous) : le membre existe.
  4. Forme d'appel : f({ ... }) exige une méthode "takes_table", f(a, b) l'interdit.
"""
import json
import pathlib
import re
import sys

GLOBAL_CLASSES = {
    "game": "LuaGameScript",
    "script": "LuaBootstrap",
    "rendering": "LuaRendering",
    "commands": "LuaCommandProcessor",
    "remote": "LuaRemote",
}

# Membres accédés sur des objets non globaux : (classe(s) candidate(s), membre)
RECEIVERS = [
    (["LuaSurface"], "request_path"),
    (["LuaSurface"], "find_non_colliding_position"),
    (["LuaSurface"], "create_entity"),
    (["LuaSurface"], "index"),
    (["LuaControl", "LuaEntity"], "walking_state"),
    (["LuaEntity"], "color"),
    (["LuaEntity"], "unit_number"),
    (["LuaEntity"], "valid"),
    (["LuaControl", "LuaEntity"], "position"),
    (["LuaControl", "LuaEntity"], "force"),
    (["LuaControl", "LuaEntity"], "surface"),
    (["LuaEntity"], "destroy"),
    (["LuaPlayer", "LuaControl"], "character"),
    (["LuaPlayer"], "admin"),
    (["LuaPlayer"], "index"),
    (["LuaPlayer"], "print"),
    (["LuaPlayer"], "valid"),
    (["LuaForce"], "name"),
    (["LuaEntityPrototype"], "running_speed"),
    (["LuaEntityPrototype"], "collision_box"),
    (["LuaEntityPrototype"], "collision_mask"),
    (["LuaProfiler"], "restart"),
    (["LuaProfiler"], "stop"),
    (["LuaProfiler"], "add"),
    (["LuaProfiler"], "divide"),
    (["LuaSettings"], "global"),
    # Factions, monde
    (["LuaSurface"], "create_unit_group"),
    (["LuaSurface"], "find_entities_filtered"),
    (["LuaSurface"], "can_place_entity"),
    (["LuaSurface"], "request_to_generate_chunks"),
    (["LuaSurface"], "force_generate_chunk_requests"),
    (["LuaSurface"], "is_chunk_generated"),
    (["LuaSurface"], "get_tile"),
    (["LuaTile"], "name"),
    (["LuaUnitGroup"], "add_member"),
    (["LuaUnitGroup", "LuaEntity"], "set_command"),
    (["LuaUnitGroup"], "start_moving"),
    (["LuaUnitGroup"], "members"),
    (["LuaUnitGroup"], "group_number"),
    (["LuaForce"], "set_cease_fire"),
    (["LuaForce"], "get_cease_fire"),
    (["LuaForce"], "set_ammo_damage_modifier"),
    (["LuaForce"], "set_turret_attack_modifier"),
    (["LuaForce"], "chart"),
    (["LuaForce"], "get_spawn_position"),
    (["LuaControl", "LuaEntity"], "insert"),
    (["LuaControl", "LuaEntity"], "get_inventory"),
    (["LuaInventory"], "get_item_count"),
    (["LuaEntity"], "active"),
    (["LuaEntity"], "operable"),
    (["LuaEntity"], "die"),
    (["LuaEntity"], "damage"),
    (["LuaEntity"], "health"),
    (["LuaEntity"], "prototype"),
    (["LuaEntity"], "name"),
    (["LuaEntityPrototype"], "resource_category"),
    (["LuaEntityPrototype"], "max_health"),
]


SCALARS = {"string", "boolean", "bool", "double", "float", "int", "int8", "int16", "int32", "int64",
           "uint", "uint8", "uint16", "uint32", "uint64", "LocalisedString", "ForceIdentification",
           "SurfaceIdentification", "PlayerIdentification", "LuaEntity"}


def first_param_is_table(spec):
    """Méthode positionnelle dont le 1er paramètre est une table (Command, ChunkPosition, ItemStack...)."""
    params = sorted(spec.get("parameters", []), key=lambda p: p.get("order", 0))
    if not params:
        return False
    t = params[0].get("type")
    if isinstance(t, dict):
        return True
    if t == "LocalisedString":  # chaîne OU table {"clé", ...} : les deux sont valides
        return True
    return t not in SCALARS


_LUA_LONG = re.compile(r"\[(=*)\[.*?\]\1\]", re.S)


def strip_lua_text(text):
    """Remplace commentaires et chaînes Lua par des blancs : un nom d'API cité dans un texte
    (documentation, message) n'est pas un appel. Les retours à la ligne sont conservés."""
    out, i, n = [], 0, len(text)
    blank = lambda s: re.sub(r"[^\n]", " ", s)
    while i < n:
        c = text[i]
        if text.startswith("--", i):
            m = _LUA_LONG.match(text, i + 2)
            end = m.end() if m else (text.find("\n", i) if text.find("\n", i) >= 0 else n)
            out.append(blank(text[i:end])); i = end
        elif c == "[" and _LUA_LONG.match(text, i):
            m = _LUA_LONG.match(text, i)
            out.append(blank(text[i:m.end()])); i = m.end()
        elif c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            out.append(c + blank(text[i + 1:j]) + (c if j < n else "")); i = j + 1
        else:
            out.append(c); i += 1
    return "".join(out)


def main():
    doc = pathlib.Path(sys.argv[1])
    root = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else ".")
    api = json.loads((doc / "runtime-api.json").read_text(encoding="utf-8"))
    classes = {c["name"]: c for c in api["classes"]}

    def members(cls):
        out = {}
        seen = set()
        stack = [cls]
        while stack:
            name = stack.pop()
            if name in seen or name not in classes:
                continue
            seen.add(name)
            c = classes[name]
            for m in c.get("methods", []):
                out[m["name"]] = ("method", m)
            for a in c.get("attributes", []):
                out[a["name"]] = ("attribute", a)
            stack.extend(c.get("base_classes", []) or [])
        return out

    defines = {d["name"]: {v["name"] for v in d.get("values", [])} for d in api["defines"]}
    errors, checked = [], 0

    # .claude/ contient les worktrees des agents (copies du mod en cours de travail) : jamais lintés ici.
    lua_files = [p for p in root.rglob("*.lua")
                 if not {"tests", ".claude", ".git"} & set(p.relative_to(root).parts)]
    src = {p: strip_lua_text(p.read_text(encoding="utf-8")) for p in lua_files}

    for path, text in src.items():
        for var, cls in GLOBAL_CLASSES.items():
            for m in re.finditer(r"(?<![\w.\"'])" + var + r"\.(\w+)(\s*\(\s*(\{|\))?)?", text):
                name, call, brace = m.group(1), m.group(2), m.group(3)
                mem = members(cls)
                checked += 1
                if name not in mem:
                    errors.append(f"{path}: {var}.{name} absent de {cls}")
                    continue
                kind, spec = mem[name]
                if call and kind == "method" and brace != ")":
                    takes_table = spec.get("takes_table", False)
                    if brace and not takes_table and not first_param_is_table(spec):
                        errors.append(f"{path}: {var}.{name}({{...}}) mais la méthode est positionnelle")
                    if not brace and takes_table:
                        errors.append(f"{path}: {var}.{name}(...) mais la méthode attend une table")
        for kind in ("events", "direction"):
            for m in re.finditer(r"defines\." + kind + r"\.(\w+)", text):
                checked += 1
                if m.group(1) not in defines[kind]:
                    errors.append(f"{path}: defines.{kind}.{m.group(1)} inconnu")

    all_text = "\n".join(src.values())
    for cands, name in RECEIVERS:
        if not re.search(r"\." + name + r"\b", all_text):
            continue
        checked += 1
        found = [c for c in cands if name in members(c)]
        if not found:
            errors.append(f"membre .{name} introuvable sur {cands}")
            continue
        kind, spec = members(found[0])[name]
        if kind == "method":
            for m in re.finditer(r"(\w+)\." + name + r"\s*\(\s*(\{|\))?", all_text):
                if m.group(1) in GLOBAL_CLASSES or m.group(2) == ")":
                    continue  # appel sur un objet global (contrôlé plus haut) ou sans argument
                takes_table = spec.get("takes_table", False)
                if m.group(2) and not takes_table and not first_param_is_table(spec):
                    errors.append(f".{name}({{...}}) mais {found[0]}.{name} est positionnelle")
                if not m.group(2) and takes_table:
                    errors.append(f".{name}(...) mais {found[0]}.{name} attend une table")

    print(f"API {api.get('application_version')} : {checked} usages vérifiés, {len(errors)} erreur(s)")
    for e in errors:
        print("  " + e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
