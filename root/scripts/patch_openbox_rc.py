#!/usr/bin/env python3

import argparse
import sys
import xml.etree.ElementTree as ET


def patch_rc_xml(path: str, target_menu_id: str) -> bool:
    tree = ET.parse(path)
    root = tree.getroot()

    namespace = ""
    if root.tag.startswith("{"):
        namespace = root.tag.split("}", 1)[0].strip("{")

    def qname(tag: str) -> str:
        if namespace:
            return f"{{{namespace}}}{tag}"
        return tag

    changed = False

    for context in root.findall(f".//{qname('context')}"):
        context_name = context.attrib.get("name", "").strip()
        if context_name in {"Root", "Desktop"}:
            continue

        for mousebind in context.findall(qname("mousebind")):
            if mousebind.attrib.get("button") != "Right":
                continue
            if mousebind.attrib.get("action") != "Press":
                continue

            for action in mousebind.findall(qname("action")):
                if action.attrib.get("name") != "ShowMenu":
                    continue
                menu = action.find(qname("menu"))
                if menu is None:
                    continue
                current = (menu.text or "").strip()
                if current == target_menu_id:
                    continue
                if current not in {"client-menu", "window-right-click-menu"}:
                    continue
                menu.text = target_menu_id
                changed = True

    if changed:
        tree.write(path, encoding="utf-8", xml_declaration=True)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description="Patch Openbox rc.xml right-click menu")
    parser.add_argument("rc_path", help="Path to rc.xml")
    parser.add_argument(
        "--target-menu-id",
        default="window-right-click-menu",
        help="Menu ID to bind for window right-click menu",
    )
    args = parser.parse_args()

    try:
        changed = patch_rc_xml(args.rc_path, args.target_menu_id)
    except Exception as exc:
        print(f"failed: {exc}", file=sys.stderr)
        return 1

    print("changed" if changed else "unchanged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
