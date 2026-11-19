#!/usr/bin/env python3
"""Генерирует блок Catalog.Branches и Catalog.Perks из scripts/perks_spec.py и вставляет его в Catalog.luau.

Запуск: python3 scripts/gen_perks.py   (затем stylua src). Блок лежит между маркерами BEGIN/END.
Стоимости считает scripts/balance.py. Структуру дерева и пороги правят в perks_spec.py.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from balance import perk_costs  # noqa: E402
from perks_spec import BRANCHES, EFFECTS, PERKS  # noqa: E402

CATALOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "shared", "Config", "Catalog.luau")
BEGIN = "-- <PERKS:BEGIN> Блок создаётся scripts/gen_perks.py, вручную не править."
END = "-- <PERKS:END>"


def luau_list(values):
    return "{ " + ", ".join(str(v) for v in values) + " }"


def render():
    costs = perk_costs()
    lines = [BEGIN, "Catalog.Branches = {"]
    for key, name in BRANCHES:
        lines.append(f'\t{{ Key = "{key}", Name = "{name}" }},')
    lines.append("}")
    lines.append("local E = Catalog.Effects")
    lines.append("Catalog.Perks = {")
    for spec in PERKS:
        lines.append("\t{")
        lines.append(f'\t\tKey = "{spec["key"]}",')
        lines.append(f'\t\tName = "{spec["name"]}",')
        lines.append(f'\t\tBranch = "{spec["branch"]}",')
        lines.append(f"\t\tCosts = {luau_list(costs[spec['key']])},")
        lines.append(f"\t\tOpened = {luau_list(spec['opened'])},")
        if spec["parent"]:
            lines.append(f'\t\tParent = "{spec["parent"]}",')
            lines.append(f"\t\tRequired = {spec['req']},")
        if spec["needs"]:
            needs = ", ".join(f'{{ Key = "{key}", Level = {level} }}' for key, level in spec["needs"])
            lines.append(f"\t\tNeeds = {{ {needs} }},")
        lines.append("\t\tDescribe = function(level)")
        lines.append(f"\t\t\treturn {spec['text']}")
        lines.append("\t\tend,")
        lines.append("\t},")
    lines.append("} :: { Perk }")
    lines.append(END)
    return "\n".join(lines)


def effects_block():
    rows = "\n".join(f"\t{key} = {value}," for key, value in EFFECTS.items())
    return f"Catalog.Effects = {{\n{rows}\n}}"


def main():
    with open(CATALOG, encoding="utf-8") as handle:
        text = handle.read()
    block = render()
    if BEGIN in text:
        text = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), lambda _: block, text, flags=re.S)
    else:
        start = text.index("Catalog.Branches = {")
        end = text.index("} :: { Perk }", start) + len("} :: { Perk }")
        text = text[:start] + block + text[end:]
    start = text.index("Catalog.Effects = {")
    end = text.index("\n}\n", start) + 2
    text = text[:start] + effects_block() + text[end:]
    with open(CATALOG, "w", encoding="utf-8") as handle:
        handle.write(text)
    print(f"Навыков: {len(PERKS)}")


if __name__ == "__main__":
    main()
