#!/usr/bin/env python3
"""
Convertit doc-html/prototype-api.json (+ les defines de runtime-api.json) en un module Lua
consommé par le banc data-stage (tests/datastage/harness.lua).

Usage : python3 tests/datastage/schema_gen.py <chemin vers doc-html> > tests/datastage/schema.lua
"""
import json
import pathlib
import re
import sys


def lua(v, indent=0):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(v, list):
        return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", k) and k not in ("and", "or", "not", "end", "function", "nil", "true", "false", "local", "return", "then", "if", "else", "elseif", "for", "while", "do", "repeat", "until", "break", "in", "goto"):
                parts.append(f"{k}={lua(x)}")
            else:
                parts.append(f"[{lua(k)}]={lua(x)}")
        return "{" + ",".join(parts) + "}"
    raise TypeError(type(v))


def slim_type(t):
    """Réduit un type JSON à l'essentiel pour le validateur."""
    if isinstance(t, str):
        return t
    ct = t.get("complex_type")
    out = {"ct": ct}
    if ct == "union":
        out["options"] = [slim_type(o) for o in t["options"]]
    elif ct == "array":
        out["value"] = slim_type(t["value"])
    elif ct == "dictionary":
        out["key"] = slim_type(t["key"])
        out["value"] = slim_type(t["value"])
    elif ct == "literal":
        out["value"] = t["value"]
    elif ct == "tuple":
        out["values"] = [slim_type(x) for x in t["values"]]
    elif ct == "type":
        out["value"] = slim_type(t["value"])
    elif ct == "struct":
        pass
    return out


def slim_props(props):
    out = {}
    for p in props or []:
        out[p["name"]] = {
            "type": slim_type(p["type"]),
            "optional": bool(p.get("optional")) or p.get("default") is not None,
            "alt": p.get("alt_name"),
        }
    return out


def main():
    doc = pathlib.Path(sys.argv[1])
    proto_api = json.loads((doc / "prototype-api.json").read_text(encoding="utf-8"))
    runtime_api = json.loads((doc / "runtime-api.json").read_text(encoding="utf-8"))

    classes = {}
    for p in proto_api["prototypes"]:
        classes[p["name"]] = {
            "parent": p.get("parent"),
            "typename": p.get("typename"),
            "abstract": bool(p.get("abstract")),
            "props": slim_props(p.get("properties")),
            "custom": p.get("custom_properties") is not None,
        }
    types = {}
    for t in proto_api["types"]:
        types[t["name"]] = {
            "type": slim_type(t["type"]),
            "parent": t.get("parent"),
            "props": slim_props(t.get("properties")),
        }

    # XxxID -> classe de base référencée (d'après la description "The name of a [X](prototype:X)")
    id_refs = {}
    for name, t in ((t["name"], t) for t in proto_api["types"]):
        if not name.endswith("ID"):
            continue
        m = re.search(r"prototype:(\w+)", t.get("description", ""))
        if m:
            id_refs[name] = m.group(1)

    # defines (runtime) : valeurs = rang, suffisant pour l'étape data
    def defines_tree(entries):
        out = {}
        for d in entries:
            node = {}
            for i, v in enumerate(d.get("values", []) or []):
                node[v["name"]] = v.get("order", i)
            if d.get("subkeys"):
                node.update(defines_tree(d["subkeys"]))
            out[d["name"]] = node
        return out

    schema = {
        "version": proto_api.get("application_version"),
        "classes": classes,
        "types": types,
        "id_refs": id_refs,
        "defines": defines_tree(runtime_api["defines"]),
    }
    sys.stdout.write("-- GÉNÉRÉ par schema_gen.py depuis la doc " + str(schema["version"]) + " : ne pas éditer.\nreturn " + lua(schema) + "\n")


if __name__ == "__main__":
    main()
