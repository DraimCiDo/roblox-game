#!/usr/bin/env python3
"""Переупаковывает готовую сцену Studio для сборки Rojo."""
import argparse
import copy
import json
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


LAB_NAME = "CORPA — испытательная лаборатория"
ASSETS = Path(__file__).resolve().parents[1] / "assets"
SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}


def restore_text(value: str) -> str:
    """Восстанавливает кириллицу, которую некоторые версии Studio экранируют как Latin-1."""
    try:
        decoded = value.encode("latin-1").decode("utf-8")
    except UnicodeError:
        return value
    return decoded if re.search(r"[А-Яа-яЁё—]", decoded) else value


def model_xml(place: ET.Element, item: ET.Element) -> ET.Element:
    model = copy.deepcopy(item)
    if any(child.get("class") in SCRIPT_CLASSES for child in model.iter("Item")):
        raise ValueError("Модель сцены содержит игровой код. Скрипты должны храниться в src/.")

    shared = place.find("SharedStrings")
    tag_values = {entry.get("md5"): entry.text for entry in shared} if shared is not None else {}
    xml = ET.Element("roblox", {"version": place.get("version", "4")})
    for props in model.iter("Properties"):
        for prop in list(props):
            name = prop.get("name")
            if name in {"Name", "Text", "ActionText", "ObjectText"} and prop.tag == "string" and prop.text:
                prop.text = restore_text(prop.text)
            if prop.tag == "SharedString" and name == "Tags":
                prop.tag = "BinaryString"
                prop.text = tag_values[prop.text]
            if prop.tag == "AssetContentMap" and name == "VoxelGridAssetContentMap":
                if len(prop) or (prop.text or "").strip() not in {"", "{}", "[]"}:
                    raise ValueError("Сцена с внешними секциями Terrain требует локальной копии с вокселями.")
                props.remove(prop)
    xml.append(model)
    if shared is not None:
        xml.append(copy.deepcopy(shared))
    return xml


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place", type=Path, help="Плейс в формате Roblox XML (.rbxlx), сохранённый в Studio")
    args = parser.parse_args()

    place = ET.parse(args.place).getroot()
    workspace = place.find("Item[@class='Workspace']")
    if workspace is None:
        parser.error("В плейсе отсутствует Workspace.")
    lab = next(
        (item for item in workspace.findall("Item")
         if restore_text(item.findtext("Properties/string[@name='Name']", "")) == LAB_NAME),
        None,
    )
    pieces = {
        "CorpaLab": lab,
        "CorpaTerrain": workspace.find("Item[@class='Terrain']"),
        "CorpaLighting": place.find("Item[@class='Lighting']"),
    }

    with tempfile.TemporaryDirectory() as directory:
        temp = Path(directory)
        for name, piece in pieces.items():
            if piece is None:
                parser.error(f"В плейсе отсутствует {name}.")
            ET.ElementTree(model_xml(place, piece)).write(temp / f"{name}.rbxmx", encoding="utf-8")
            project = temp / f"{name}.project.json"
            project.write_text(json.dumps({"name": name, "tree": {"$path": f"{name}.rbxmx"}}), encoding="utf-8")
            subprocess.run(["rojo", "build", str(project), "-o", str(temp / f"{name}.rbxm")], check=True)
        for name in pieces:
            shutil.copyfile(temp / f"{name}.rbxm", ASSETS / f"{name}.rbxm")


if __name__ == "__main__":
    main()
