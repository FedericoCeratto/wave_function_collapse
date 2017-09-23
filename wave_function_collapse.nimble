# Package

version       = "0.1.0"
author        = "Federico Ceratto"
description   = "Wave function collapse pattern generator"
license       = "LGPLv3"

skipDirs = @["tests"]

# Dependencies

requires "nim >= 0.17.2"

task tests_unit, "Unit tests":
  exec "nim c -p:. -r -d:testing -d:lcg tests/unit.nim"

task tests_functional, "Functional tests":
  exec "nim c -p:. -r -d:testing -d:lcg tests/functional.nim"

task gifs_2d, "Generate 2D gifs":
  exec "nim c -p:. -r -d:testing -d:lcg tests/gifs_2d.nim"


