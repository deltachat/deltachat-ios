#!/usr/bin/env python3
from __future__ import annotations

import argparse
import logging
import re
import sys
from pathlib import Path
from typing import TextIO

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-5s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

try:
    from lxml import etree
except:
    logging.error(
        "It seems lxml dependency is not installed, to install run: pip install lxml"
    )
    sys.exit(1)


def get_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Delta Chat Android->iOS translations converter"
    )
    parser.add_argument(
        "input",
        help="one or more paths to XML translations files to process",
        nargs="+",
        type=Path,
    )
    parser.add_argument(
        "output", help="the output folder of the generated files", type=Path
    )
    return parser


def generate_stringsdict(plurals: list, xml: TextIO) -> None:
    xml.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    xml.write(
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    )
    xml.write('<plist version="1.0">\n')
    xml.write("<dict>\n")
    for elem in plurals:
        key = elem.attrib["name"]
        xml.write(f"\t<key>{key}</key>\n")
        xml.write("\t<dict>\n")
        xml.write("\t\t<key>NSStringLocalizedFormatKey</key>\n")
        xml.write("\t\t<string>%#@localized_format_key@</string>\n")
        xml.write("\t\t<key>localized_format_key</key>\n")
        xml.write("\t\t<dict>\n")
        xml.write("\t\t\t<key>NSStringFormatSpecTypeKey</key>\n")
        xml.write("\t\t\t<string>NSStringPluralRuleType</string>\n")
        xml.write("\t\t\t<key>NSStringFormatValueTypeKey</key>\n")
        xml.write("\t\t\t<string>d</string>\n")
        for quantity in ["zero", "one", "two", "few", "many", "other"]:
            item = elem.find(f'item[@quantity="{quantity}"]')
            if item is not None:
                xml.write(f"\t\t\t<key>{quantity}</key>\n")
                xml.write(f"\t\t\t<string>{item.text}</string>\n")
        xml.write("\t\t</dict>\n")
        xml.write("\t</dict>\n")
    xml.write("</dict>\n")
    xml.write("</plist>\n")


def normalize_text(text: str) -> str:
    text = re.sub(r"([^\\])(\")", r"\1\\\2", text)  # escape double quotes
    text = text.replace("&quot;", r"\"")
    text = text.replace("&lt;", "<")
    text = text.replace("&gt;", ">")
    text = text.replace("&amp;", "&")
    text = text.replace("$s", "$@")
    return text.replace("%s", "%1$@")


def get_resources(paths: list[Path]):
    for path in paths:
        resources = etree.parse(path).getroot()
        strings = len(resources.findall("string"))
        plurals = len(resources.findall("plurals"))
        logging.info(f"Processing {str(path)!r}: {strings} strings, {plurals} plurals")
        for element in resources:
            yield path, element


def main() -> None:
    args = get_parser().parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    localizable = args.output / "Localizable.strings"
    infoplist = args.output / "InfoPlist.strings"
    plurals = []
    plurals_keys: dict[str, str] = {}
    strings_keys: dict[str, str] = {}

    with localizable.open("w") as loc, infoplist.open("w") as inf:
        for path, element in get_resources(args.input):
            if element.tag is etree.Comment:
                for line in element.text.strip().split("\n"):
                    loc.write(f"// {line}\n")
            elif element.tag == "string":
                name = element.attrib["name"]
                if name in strings_keys:
                    logging.error(
                        f'On file {path}: <string name="{name}"> found but an element with the same name was already added from file {strings_keys[name]}'
                    )
                    sys.exit(1)
                strings_keys[name] = path
                text = normalize_text(element.text)

                if text.count("%1$@") > 1:
                    msg = "Placeholder mismatch. A source file contained "
                    if element.text.count("%s") > 1:
                        msg += "more than one '%s'"
                    elif element.text.count("%1$@") > 1:
                        msg += "more than one '%1$@'"
                    else:
                        msg += "'%s' and '%1$s'"
                    msg += (
                        " in the same resource which we are not willing to fix automatically."
                        f" Please fix the input source on tranisfex first! context:\n{element.text!r}"
                    )
                    logging.error(msg)

                if name.startswith("InfoPlist_"):
                    name = name.removeprefix("InfoPlist_")
                    inf.write(f"""{name} = "{text}";\n""")
                else:
                    loc.write(f""""{name}" = "{text}";\n""")
            elif element.tag == "plurals":
                name = element.attrib["name"]
                if name in plurals_keys:
                    logging.error(
                        f'On file {path}: <plurals name="{name}"> found but an element with the same name was already added from file {plurals_keys[name]}'
                    )
                    sys.exit(1)
                plurals_keys[name] = path
                plurals.append(element)
            else:
                logging.warning("Unexpected element was ignored: %s", element)

        with (args.output / "Localizable.stringsdict").open("w") as strdict:
            generate_stringsdict(plurals or [], strdict)


if __name__ == "__main__":
    main()
