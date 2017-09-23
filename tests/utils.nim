# Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3 License, see LICENSE file
#
## Utilities

import md5
from strutils import toLower
import securehash

import wave_function_collapse

proc mhash*(wave: Wave): string =
  var s = newStringOfCap(wave.len * wave[0].len * wave[0][0].len)
  for square in wave:
    for column in square:
      for cell in column:
        s.add if cell: "1" else: "0"
  return toLower($secureHash(s))[0..3]

proc mhash*(prop: Propagator): string =
  var s = ""
  for cube in prop:
    for square in cube:
      for column in square:
        for cell in column:
          s.add $cell
  return toLower($secureHash(s))[0..3]

proc mhash*(stationary: Stationary): string =
  var s = ""
  for item in stationary:
    s.add $item
  return toLower($secureHash(s))[0..3]

proc describe*(wave: Wave): string {.discardable.} =
  result = $wave.len & "x" & $wave[0].len & "x" & $wave[0][0].len & " " & mhash wave
  echo "Wave: ", result


proc mhash*(changes: Changes): string =
  var s = newStringOfCap(changes.len * changes[0].len)
  for x in 0..<changes.len:
    for y in 0..<changes[0].len:
      s.add if changes[x][y]: "1" else: "0"
  return toLower($secureHash(s))[0..3]



