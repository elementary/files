#!/usr/bin/env python3

import sys
import re

with open(sys.argv[1], 'r') as desktop_file:
    #Find original icon name
    pattern = re.compile("^Icon=(.*)$")
    original_icon_name = ""
    for line in desktop_file:
        result = pattern.search(line)
        if result is not None:
            original_icon_name = result.group(1)

    #Couldn't find original icon name, assume everything is OK
    if original_icon_name == "":
        exit(0)

    desktop_file.seek(0)

    failed = False
    pattern = re.compile("^Icon\[(.*?)\]=(.*)$")
    for line in desktop_file:
        result = pattern.search(line)
        if result is not None:
            if result.group(2) != original_icon_name:
                print("Icon in %s.po has been translated!" % (result.group(1)))
                failed = True

    if failed:
        exit(1)

exit(0)
