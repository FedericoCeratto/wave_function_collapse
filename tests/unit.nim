# Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3 License, see LICENSE file
#
## Wave Function Collapse - unit testing

from tables import len
from times import epochTime
import md5, unittest
import sequtils

import wave_function_collapse
import tests/utils


proc mhash(s: string): string =
  let h = $toMD5(s)
  h[0..3]

suite "Unit tests - 2D":

  setup:
    echo ""
    set_lcg_seed(0)
    let t0 = epochTime()

  teardown:
    let rt = epochTime() - t0
    if rt > 0.1:
      echo "       runtime: ", int(rt * 1000), "ms"

  test "Red Maze sample":
    const input_fn = "tests/data/input/Red Maze"
    let (colors, sample) = load_image(input_fn)
    var s = ""
    for line in sample:
      for c in line:
        s.add $c[0]
    check s == "0000011101210111"
    check colors.len == 3

  test "init wave":
    var wave = newWave(3, 3)
    check wave.len == 3
    check wave[0].len == 3
    check wave[0][0].len == 0
    check wave.mhash() == "da39"

  test "init changes":
    var changes = newChanges(3, 3)
    check changes.mhash() == "0f58"

  test "Red Maze":
    const
      width = 48
      height = 48
      N = 2
      periodicInput = false
      periodicOutput = false
      symmetry = 8
      ground = 4
      input_fn = "tests/data/input/Red Maze"

    checkpoint "build model"

    var wave = newWave(width, height)

    let (colors, sample) = load_image(input_fn)
    let (weights, ordering) = generate_weights_and_ordering(sample, N, symmetry, colors.len, periodicInput)
    let (patterns, stationary) = build_overlapping_model(wave, colors, weights, ordering,
      N, width, height, periodicOutput, symmetry, ground)
    let propagator = build_overlapping_propagator(patterns, N)
    check colors.len == 3
    check patterns == @[@[0, 0, 0, 1], @[0, 0, 1, 0], @[0, 1, 0, 0], @[1, 0, 0, 0], @[0, 0, 1, 1], @[0, 1, 0, 1], @[1, 0, 1, 0], @[1, 1, 0, 0], @[1, 1, 1, 2], @[1, 1, 2, 1], @[1, 2, 1, 1], @[2, 1, 1, 1]]
    #check stationary == @[8, 8, 8, 8, 16, 16, 16, 16, 8, 8, 8, 8]

    var changes = newChanges(width, height)
    check changes.mhash() == "847d"
    check wave.mhash() == "f42b"

    let result = observe(wave, changes, stationary)
    check result == "none"
    check changes.mhash() == "f2b3"
    check wave.mhash() == "616e"

    while propagate(wave, changes, propagator, N, periodicOutput) == true:
      discard

    check changes.mhash() == "847d"
    check wave.mhash() == "555e"

    check observe(wave, changes, stationary) == "none"
    check changes.mhash() == "b03a"
    check wave.mhash() == "9a7f"

    while propagate(wave, changes, propagator, N, periodicOutput) == true:
      discard

    check changes.mhash() == "847d"
    check wave.mhash() == "34a8"

#  test "Simple Knot":
#    const
#      width = 48
#      height = 48
#      N = 3
#      periodicInput = false
#      periodicOutput = true
#      symmetry = 8
#      ground = 4
#      input_fn = "tests/data/input/Simple Knot"
#
#    var wave = newWave(width, height)
#
#    let (colors, patterns, stationary, weights) = build_overlapping_model(wave, input_fn, N, width, height, periodicInput,
#      periodicOutput, symmetry, ground)
#    check colors.len == 3
#    check patterns == @[@[0, 0, 0, 0, 0, 0, 0, 0, 0], @[0, 0, 0, 0, 0, 1, 0, 0, 1], @[0, 0, 0, 1, 0, 0, 1, 0, 0], @[0, 1, 1, 0, 0, 0, 0, 0, 0], @[1, 1, 0, 0, 0, 0, 0, 0, 0], @[1, 0, 0, 1, 0, 0, 0, 0, 0], @[0, 0, 1, 0, 0, 1, 0, 0, 0], @[0, 0, 0, 0, 0, 0, 1, 1, 0], @[0, 0, 0, 0, 0, 0, 0, 1, 1], @[0, 0, 0, 0, 1, 1, 0, 1, 0], @[0, 0, 0, 1, 1, 0, 0, 1, 0], @[0, 1, 0, 0, 1, 1, 0, 0, 0], @[0, 1, 0, 1, 1, 0, 0, 0, 0], @[0, 0, 0, 1, 1, 1, 1, 0, 0], @[0, 0, 0, 1, 1, 1, 0, 0, 1], @[0, 1, 0, 0, 1, 0, 0, 1, 1], @[0, 1, 0, 0, 1, 0, 1, 1, 0], @[0, 0, 1, 1, 1, 1, 0, 0, 0], @[1, 0, 0, 1, 1, 1, 0, 0, 0], @[1, 1, 0, 0, 1, 0, 0, 1, 0], @[0, 1, 1, 0, 1, 0, 0, 1, 0], @[0, 0, 0, 1, 1, 1, 0, 0, 0], @[0, 1, 0, 0, 1, 0, 0, 1, 0], @[0, 0, 1, 0, 0, 1, 0, 0, 1], @[1, 0, 0, 1, 0, 0, 1, 0, 0], @[1, 1, 1, 0, 0, 0, 0, 0, 0], @[0, 0, 0, 0, 0, 0, 1, 1, 1], @[1, 1, 1, 1, 0, 0, 1, 0, 0], @[1, 1, 1, 0, 0, 1, 0, 0, 1], @[1, 0, 0, 1, 0, 0, 1, 1, 1], @[0, 0, 1, 0, 0, 1, 1, 1, 1], @[0, 0, 1, 0, 0, 1, 0, 0, 2], @[1, 0, 0, 1, 0, 0, 2, 0, 0], @[1, 1, 2, 0, 0, 0, 0, 0, 0], @[2, 1, 1, 0, 0, 0, 0, 0, 0], @[2, 0, 0, 1, 0, 0, 1, 0, 0], @[0, 0, 2, 0, 0, 1, 0, 0, 1], @[0, 0, 0, 0, 0, 0, 2, 1, 1], @[0, 0, 0, 0, 0, 0, 1, 1, 2], @[0, 1, 0, 0, 1, 0, 0, 2, 0], @[0, 0, 0, 1, 1, 2, 0, 0, 0], @[0, 0, 0, 2, 1, 1, 0, 0, 0], @[0, 2, 0, 0, 1, 0, 0, 1, 0], @[0, 0, 1, 0, 0, 2, 1, 1, 1], @[1, 0, 0, 2, 0, 0, 1, 1, 1], @[1, 2, 1, 0, 0, 1, 0, 0, 1], @[1, 2, 1, 1, 0, 0, 1, 0, 0], @[1, 1, 1, 2, 0, 0, 1, 0, 0], @[1, 1, 1, 0, 0, 2, 0, 0, 1], @[1, 0, 0, 1, 0, 0, 1, 2, 1], @[0, 0, 1, 0, 0, 1, 1, 2, 1], @[0, 1, 0, 0, 2, 0, 1, 1, 1], @[0, 0, 1, 1, 2, 1, 0, 0, 1], @[1, 0, 0, 1, 2, 1, 1, 0, 0], @[1, 1, 1, 0, 2, 0, 0, 1, 0], @[0, 0, 0, 0, 0, 0, 0, 0, 1], @[0, 0, 0, 0, 0, 0, 1, 0, 0], @[0, 0, 1, 0, 0, 0, 0, 0, 0], @[1, 0, 0, 0, 0, 0, 0, 0, 0], @[0, 0, 2, 1, 1, 1, 0, 0, 2], @[2, 0, 0, 1, 1, 1, 2, 0, 0], @[2, 1, 2, 0, 1, 0, 0, 1, 0], @[0, 1, 0, 0, 1, 0, 2, 1, 2], @[0, 2, 0, 1, 1, 1, 0, 2, 0], @[0, 1, 0, 2, 1, 2, 0, 1, 0]]
#
#    check stationary == @[272, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 24, 24, 48, 48, 48, 48, 12, 12, 12, 12, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 12, 12, 12, 12, 4, 4, 4, 4, 4, 4]
#
#
#    var changes = newChanges(width, height)
#    check changes.mhash() == "847d"
#    check wave.mhash() == "9022"
#
#    let result = observe(wave, changes, stationary, weights)
#    check result == "none"
#    check changes.mhash() == "f2b3"
#    check wave.mhash() == "b32d"
#
#    while propagate(wave, changes, propagator, N, periodicOutput) == true:
#      discard
#
#    check changes.mhash() == "847d"
#    check wave.mhash() == ""
#
#    check observe(wave, changes, stationary, weights) == "none"
#    check changes.mhash() == "b03a"
#    check wave.mhash() == ""
#
#    while propagate(wave, changes, propagator, N, periodicOutput) == true:
#      discard
#
#    check changes.mhash() == "847d"
#    check wave.mhash() == ""


  test "Skylinesample":
    const input_fn = "tests/data/input/Skyline"
    let (colors, sample) = load_image(input_fn)
    var s = ""
    for line in sample:
      for c in line:
        s.add $c[0]
    check s == "000000000000000000333331111400000001111111111111111122140000000122111111122112212214000000012212211112211221111400000001111221221111111111140000000111111122111112211114000000012212211112211221221400000001221221111221111122140000000111111111111111111114000000000000000000333331221400000000000000000033333122140000000000000000003333311114000000000000033333333331111400000000000003333333333122140000000000000333333333312214001111111111111111111111111400122122122122112211221221140012212212212211221122122114001111111111111111111111111400111111122111122122111122140012212212212212212212212214001221221111221111111221111400111111111111111111111111140000000000000333333333312214000000000000033333333331221400000000000003333333333111140000000000000000003333312214000000000000000000333331221400000000000000000033333111140000111111111111111111111114000012212211112212212211221400001221221221221221221122140000111111122111111111111114000011111111111111112211111400001221122112211221221221140000122112211221122111122114000011111111111111111111111400000000000000000033333122140000000000000000003333312214"
    check colors.len == 5
    let SMX = 39 # sample.len
    let SMY = 28 # sample[0][0].len
    const N = 3

    checkpoint "- load_image"

    let pat1 = patternFromSample(sample, 20, 20, N)
    check pat1 == @[@[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1]]

    let pat15_2 = patternFromSample(sample, 15, 2, N)
    check pat15_2 == @[@[1], @[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2]]
    check reflect(pat15_2, N) == @[@[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1]]

    let pat15_20 = patternFromSample(sample, 15, 20, N)
    check pat15_20 == @[@[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1]]
    check rotate(pat15_20, N) == @[@[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1]]

    const p0:Sam = @[@[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1]]
    let p1 = reflect(p0, N)
    assert p1 == @[@[1], @[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2]]
    let p2 = rotate(p0, N)
    assert p2 == @[@[1], @[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2]]
    let p3 = reflect(p2, N)
    assert p3 == @[@[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1]]
    let p4 = rotate(p2, N)
    assert p4 == @[@[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1]]
    let p5 = reflect(p4, N)
    assert p5 == @[@[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1]]
    let p6 = rotate(p4, N)
    assert p6 == @[@[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1]]
    assert reflect(p6, N) == @[@[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1]]


  test "Skylinesample2":
    const
      N = 3
      ground = -1
      height = 48
      input_fn = "tests/data/input/Skyline"
      periodicInput = true
      periodicOutput = true
      symmetry = 2
      width = 48

    var wave = newWave(width, height)
    let (colors, sample) = load_image(input_fn)
    require colors.len == 5

    let (weights, ordering) = generate_weights_and_ordering(sample, N, symmetry, colors.len, periodicInput)
    require weights.len == 170
    require ordering.len == 170

    let (patterns, stationary) = build_overlapping_model(wave, colors, weights, ordering,
      N, width, height, periodicOutput, symmetry, ground)

    let propagator = build_overlapping_propagator(patterns, N)
    require propagator[0][0].len == 170



  test "Skyline":
    const
      N = 3
      ground = -1
      height = 48
      input_fn = "tests/data/input/Skyline"
      periodicInput = true
      periodicOutput = true
      symmetry = 2
      width = 48

    var wave = newWave(width, height)
    checkpoint "- wave created"

    let (colors, sample) = load_image(input_fn)
    require colors.len == 5
    require sample.len == 39
    require sample[0].len == 28
    checkpoint "- load_image"

    let (weights, ordering) = generate_weights_and_ordering(sample, N, symmetry, colors.len, periodicInput)
    let (patterns, stationary) = build_overlapping_model(wave, colors, weights, ordering,
      N, width, height, periodicOutput, symmetry, ground)
    let propagator = build_overlapping_propagator(patterns, N)

    require propagator[0][0].len == 170
    check wave[0][0].len == len(stationary)
    check 170 == patterns.len
    check 170 == stationary.len
    checkpoint "- model built"

    check stationary == @[368, 6, 6, 6, 6, 36, 6, 6, 6, 6, 12, 12, 6, 6, 60, 60, 14, 14, 88, 88, 37, 37, 14, 14, 88, 88, 38, 38, 7, 7, 20, 20, 6, 6, 6, 6, 21, 21, 7, 7, 3, 3, 11, 11, 13, 13, 13, 13, 4, 4, 18, 18, 7, 7, 14, 11, 11, 14, 3, 3, 1, 1, 4, 4, 2, 2, 2, 2, 10, 6, 6, 6, 6, 1, 1, 3, 3, 2, 2, 2, 2, 10, 6, 6, 6, 6, 12, 6, 6, 6, 6, 74, 28, 28, 6, 6, 1, 1, 4, 4, 2, 2, 9, 9, 2, 2, 5, 5, 4, 4, 2, 2, 2, 2, 3, 3, 1, 1, 2, 2, 2, 2, 1, 1, 2, 2, 2, 1, 1, 6, 6, 18, 1, 1, 1, 1, 4, 1, 1, 1, 1, 1, 1, 4, 4, 6, 6, 2, 2, 2, 2, 1, 1, 2, 1, 1, 1, 1, 1, 1, 3, 3, 18, 18, 12, 12, 12, 6, 78, 78]

    var changes = newChanges(width, height)
    check changes.mhash() == "847d"
    #check wave.mhash() == "242b"

    prepare_overlapping(wave, changes, propagator, N, ground, periodicOutput)

    let result = observe(wave, changes, stationary)
    check result == "none"
    check changes.mhash() == "f2b3"

    if false: #FIXME
      check wave.mhash() == ""
      checkpoint "- prepare_overlapping"

      while propagate(wave, changes, propagator, N, periodicOutput) == true:
        discard

      check changes.mhash() == "847d"
      check wave.mhash() == ""

      check observe(wave, changes, stationary) == "none"
      check changes.mhash() == "b03a"
      check wave.mhash() == ""

      while propagate(wave, changes, propagator, N, periodicOutput) == true:
        discard

      check changes.mhash() == "847d"
      check wave.mhash() == ""

  test "generate_weights_and_ordering":
    const
      N = 3
      symmetry = 2
      color_count = 5
      periodicInput = true
      sample = @[@[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[4]], @[@[0], @[0], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[4]], @[@[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[3], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[2], @[2], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[1], @[2], @[2], @[1], @[1], @[1], @[1], @[2], @[2], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]], @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3], @[3], @[3], @[3], @[3], @[1], @[2], @[2], @[1], @[4]]]


    const pat: Pattern = @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[1]]

    let b = to_index(pat, 5)
    check b == 1

    const pat2: Pattern = @[@[0], @[0], @[0], @[0], @[0], @[0], @[0], @[0], @[3]]
    check to_index(pat2, 5) == 3


    let (weights, ordering) = generate_weights_and_ordering(sample, N, symmetry, color_count, periodicInput)
    check weights.len == 170

  test "index":
    const pat: Pattern = @[@[1], @[1], @[1], @[2], @[2], @[1], @[2], @[2], @[1]]
    const color_count = 5
    assert 492061 == to_index(pat, color_count)

  test "Hogs":
    const
      N = 3
      ground = 0
      height = 48
      input_fn = "tests/data/input/Hogs"
      periodicInput = true
      periodicOutput = true
      symmetry = 8
      width = 48

    var wave = newWave(width, height)
    checkpoint "- wave created"

    let (colors, sample) = load_image(input_fn)
    checkpoint "- load_image"
    require colors.len == 2
    require sample.len == 17
    require sample[0].len == 17

    let (weights, ordering) = generate_weights_and_ordering(sample, N, symmetry, colors.len, periodicInput)
    require ordering == @[1, 4, 64, 256, 2, 8, 32, 128, 0, 11, 38, 200, 416, 23, 89, 308, 464, 186, 257, 68, 33, 12, 66, 258, 264, 96, 132, 129, 204, 417, 102, 267, 133, 97, 268, 322, 40, 130, 320, 260, 65, 5]
    checkpoint "- generate_weights_and_ordering"

    let (patterns, stationary) = build_overlapping_model(wave, colors, weights, ordering,
      N, width, height, periodicOutput, symmetry, ground)
    require stationary == @[136, 136, 136, 136, 78, 78, 78, 78, 480, 80, 80, 80, 80, 96, 96, 96, 96, 96, 20, 20, 6, 6, 6, 6, 6, 6, 6, 6, 16, 16, 16, 16, 2, 2, 2, 2, 4, 4, 2, 2, 2, 2]

    checkpoint "- build_overlapping_model"

    let propagator = build_overlapping_propagator(patterns, N)
    require mhash(propagator) == "dd22"
    checkpoint "- propagator"

    var changes = newChanges(width, height)
    require changes.mhash() == "847d"
    require stationary.mhash() == "e9fb"
    require wave.mhash() == "3078"
    checkpoint "- changes"

    let result = observe(wave, changes, stationary)
    require result == "none"
    require changes.mhash() == "f2b3"
    require stationary.mhash() == "e9fb"
    require wave.mhash() == "0be5"
    checkpoint "- observe"

    while propagate(wave, changes, propagator, N, periodicOutput) == true:
      discard
      # should ran 3 times

    require changes.mhash() == "847d"
    require stationary.mhash() == "e9fb"
    require wave.mhash() == "e0ae"

    require observe(wave, changes, stationary) == "none"
    require wave.mhash() == "79c1"

    while propagate(wave, changes, propagator, N, periodicOutput) == true:
      discard

    require wave.mhash() == "68d3"

    if false:
      var prop_cnt = 0
      var ob_cnt = 0
      while true:
        ob_cnt.inc
        if observe(wave, changes, stationary) != "none":
          break
        prop_cnt.inc
        while propagate(wave, changes, propagator, N, periodicOutput) == true:
          prop_cnt.inc
      echo "observed ", ob_cnt, " propagate ran ", prop_cnt, " times"

  test "weighted_random":
    const
      distribution = @[136, 136, 136, 136, 78, 78, 78, 78, 480, 80, 80, 80, 80, 96, 96, 96, 96, 96, 20, 20, 6, 6, 6, 6, 6, 6, 6, 6, 16, 16, 16, 16, 2, 2, 2, 2, 4, 4, 2, 2, 2, 2]
    check distribution.weighted_random(0.00000574858859181404113769531250) == 0

  test "weighted_random":
    const distribution = @[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 96, 96, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    check distribution.weighted_random(0.65515700215473771095275878906250) == 14

  test "weighted_random":
    const distribution = @[0, 0, 0, 0, 0, 78, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    check distribution.weighted_random(0.08291847538203001022338867187500) == 5

  test "weighted_random":
    const distribution = @[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    check distribution.weighted_random(0.71884191036224365234375000000000) == 11

  test "weighted_random":
    const distribution = @[0, 0, 136, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    check distribution.weighted_random(0.19905230775475502014160156250000) == 2

  test "Trick Knot":
    const
      N = 3
      ground = 0
      height = 48
      input_fn = "tests/data/input/Trick Knot"
      periodicInput = true
      periodicOutput = true
      symmetry = 8
      width = 48

    var wave = newWave(width, height)
    checkpoint "- wave created"

    let (colors, sample) = load_image(input_fn)
    checkpoint "- load_image"
    require colors.len == 3
    require sample.len == 17
    require sample[0].len == 17

    let (weights, ordering) = generate_weights_and_ordering(sample, N, symmetry, colors.len, periodicInput)
    require ordering == @[0, 28, 252, 2916, 8748, 6804, 756, 12, 4, 113, 345, 3753, 15633, 368, 376, 3784, 15888, 18576, 12744, 9336, 3056, 377, 3785, 15897, 19305, 757, 6813, 9477, 13, 9952, 10168, 12136, 12352, 10201, 10193, 12113, 12121, 10921, 16753, 18673, 12841, 10192, 12112, 19569, 19337, 15929, 4049, 19314, 19306, 15898, 3794, 1106, 6938, 10346, 16626, 9729, 9505, 6817, 769, 3793, 15889, 18577, 12753, 10065, 9617, 6929, 1105, 12109, 10165, 9949, 9925, 1, 9, 729, 6561, 4020, 15668, 15692, 4260, 6204, 17852, 15908, 4044, 12035, 10787, 16195, 14947, 10138, 9706, 7738, 12106, 10030, 11950]

    checkpoint "- generate_weights_and_ordering"

    let (patterns, stationary) = build_overlapping_model(wave, colors, weights, ordering,
      N, width, height, periodicOutput, symmetry, ground)
    require stationary == @[592, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 80, 80, 80, 80, 104, 104, 104, 104, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 88, 88, 12, 12, 12, 12, 16, 16, 16, 16, 16, 16, 16, 16, 20, 20, 20, 20, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 12, 12, 12, 12, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4]

    checkpoint "- build_overlapping_model"

    let propagator = build_overlapping_propagator(patterns, N)
    require mhash(propagator) == "22a7"
    checkpoint "- propagator"

    var changes = newChanges(width, height)
    require changes.mhash() == "847d"
    require stationary.mhash() == "1744"
    require wave.mhash() == "d592"

    let result = observe(wave, changes, stationary)
    require result == "none"
    require changes.mhash() == "f2b3"
    require wave.mhash() == "7b4f"

    var pcnt = 0
    while propagate(wave, changes, propagator, N, periodicOutput):
      pcnt.inc

    require changes.mhash() == "847d"
    require wave.mhash() == "d4eb"
    #require pcnt == 5

    require observe(wave, changes, stationary) == "none"
    require wave.mhash() == "432b"

    pcnt = 0
    while propagate(wave, changes, propagator, N, periodicOutput):
      pcnt.inc

    require wave.mhash() == "9766"

    var prop_cnt = 0
    var ob_cnt = 0
    while true:
      ob_cnt.inc
      if observe(wave, changes, stationary) != "none":
        break
      prop_cnt.inc
      while propagate(wave, changes, propagator, N, periodicOutput) == true:
        prop_cnt.inc
    echo "observed ", ob_cnt, " propagate ran ", prop_cnt, " times"
    check ob_cnt == 510
    let ratio = prop_cnt.float / 3188.0
    if ratio > 1.0:
      echo "**** speed hit ", ratio, " ****"
    #check prop_cnt == 5010

    let img_data = graphics_comp(wave, colors, patterns, width, height, N)
    check mhash(img_data) == "b322"
    #let outfn = "/home/fede/projects/nim-WaveFunctionCollapse/out.png"
    #savePNG32(outfn, img_data, wave.len, wave[0].len, 16)
    #echo outfn, " written"

echo "done"
