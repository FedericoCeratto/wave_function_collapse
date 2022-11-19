#
# Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
# Released under LGPLv3 License, see LICENSE file
#
## Wave Function Collapse
#

import colors,
  math,
  os,
  sequtils,
  strutils,
  tables

# TODO: optional
import nimPNG
import gifwriter

type
  Wave* = seq[seq[seq[bool]]] # FMX, FMY, patterns.len, flag
  Changes* = seq[seq[bool]]
  Sample = seq[seq[seq[int]]]
  Pattern* = seq[seq[int]] # N * N sequence of color indexes
  Patterns = seq[seq[int]]
  Weights = Table[int, int]
  Ordering = seq[int]
  Point = tuple[x, y: int]
  Colors = seq[colors.Color]
  Stationary* = seq[int]
  GraphicOutput = seq[seq[colors.Color]]
  Propagator* = seq[seq[seq[seq[int]]]]

  WFC = object
    wave: Wave
    changes: Changes
    pattern: Pattern

iterator iter_points(wave: Wave): Point {.inline.} =
  ## Iterate wave points
  let width = wave.len
  let height = wave[0].len
  for x in 0..width-1:
    for y in 0..height-1:
      yield (x, y)


## Define `lcg` to use a Linear congruential generator

when defined(lcg):

  var lcg_state = 0

  proc set_lcg_seed*(seed: int) =
    lcg_state = seed

  proc randomfloat(): float =
    ## Linear congruential generator
    ## Generate numbers between 0.0 and 1.0
    const
      modulus = 2 ^ 31 - 1
      a = 1103515245
      c = 12345
    lcg_state = (a * lcg_state + c) mod modulus
    return lcg_state.float / float(2 ^ 31)

else:
  # use random module
  import random

  proc randomfloat(): float =
    random(1.0)



proc find_lowest_entropy_cell(wave: Wave): Point =
  ## Find lowest entropy cell
  let num_patterns = wave[0][0].len

  var min_entropy_found = 9999
  for p in wave.iter_points():
    var entropy = 0
    var candidate_patterns_cnt = 0
    for t in wave[p.x][p.y]:
      if t:
        candidate_patterns_cnt.inc
        entropy.inc

    if candidate_patterns_cnt == 1:
      # Only one patter: the cell is final, ignore it
      continue

    if candidate_patterns_cnt == 0:
      raise newException(Exception, "Failed to converge to a solution")

    if entropy < min_entropy_found:
      min_entropy_found = entropy
      result = p



proc clear(changes: var Changes, wave: Wave) =
  let FMX = wave.len
  let FMY = wave[0].len
  changes = newSeqWith(FMX, newSeqWith(FMY, false))

proc pow(base, exp: int): int =
  if exp < 0:
    if base * base != 1: return 0
    elif (exp and 1) == 0: return 1
    else: return base

  return base ^ exp

proc agrees(p1, p2: seq[int], N, dx, dy: int): bool =
  ##
  let
    xmin = max(0, dx)
    xmax = if dx < 0: dx + N else: N
    ymin = max(0, dy)
    ymax = if dy < 0: dy + N else: N
  for y in ymin..ymax-1:
    for x in xmin..xmax-1:
      if p1[x + N * y] != p2[x - dx + N * (y - dy)]:
        return false
  return true

type Sam* = seq[seq[int]]

proc patternFromSample*(sample: Sample, x, y, N: int): Sam =
  ## x,y: starting point in the PNG image, N: tile size
  result = newSeqWith(N * N, newSeqWith(1, 0))
  let SMX = sample.len
  let SMY = sample[0].len
  for dy in 0..N-1:
    for dx in 0..N-1:
      result[dx + dy * N][0] = sample[(x + dx) mod SMX][(y + dy) mod SMY][0]


proc rotate*(sample: Sam, N: int): Sam =
  ## rotate counterclockwise
  result = newSeqWith(N * N, newSeqWith(1, 0))
  for y in 0..N-1:
    for x in 0..N-1:
      result[N - 1 - y + x * N][0] = sample[x + y * N][0]

  var result2 = newSeqWith(N * N, newSeqWith(0, 0))
  for y in 0..N-1:
    for x in 0..N-1:
      result2[(N-x-1) + (N-y-1) * N] = result[x + y * N]
  return result2


proc reflect*(sample: Sam, N: int): Sam =
  ## Reflect
  result = newSeqWith(N * N, newSeqWith(1, 0))
  for y in 0..<N:
    for x in 0..<N:
      result[N - 1 - x + y * N][0] = sample[x + y * N][0]


proc to_index*(p: Pattern, color_count: int): int =
  result = 0
  var power = 1
  for i in 0..p.high:
    let qq = p[len(p) - 1 - i]
    let tot = sum(qq)
    result.inc (tot * power)
    power *= color_count

proc patternFromIndex*(ind, power, N, color_count: int): seq[int] =
  ##
  var residue = ind
  var power = power
  result = newSeqWith(N * N, 0)

  for i in 0..<result.len:
    power = power div color_count
    var count = 0
    while (residue >= power):
      residue -= power
      count.inc

    result[i] = count

  return result


proc savePNG32*(fname, data: string, width, height,
    zoom: int): bool {.discardable.} =
  ##
  var o = ""
  doAssert width * height * 4 == data.len
  for y in 0..height-1:
    for zy in 0..zoom-1:
      for x in 0..width-1:
        let i = (x + y * width) * 4
        for zx in 0..zoom-1:
          o.add data[i..i+3]

  doAssert o.len == width * height * 4 * zoom * zoom
  doAssert fname.savePNG32(o, width * zoom, height * zoom) == true
  return true


proc get_pixel(img: PNGResult, x, y: int): colors.Color =
  ## Extract color from PNG
  let
    index = (x + y * img.width) * 4
    r = img.data[index].int
    g = img.data[index + 1].int
    b = img.data[index + 2].int
  rgb(r, g, b)


proc save_tile(n, N: int, t: seq[int], colors: Colors) =
  ##
  doAssert N * N == t.len
  var data = ""
  echo "--"
  for colnum in t:
    let c = colors[colnum].extractRGB()
    let bytes = chr(c.r) & chr(c.g) & chr(c.b) & chr(255)
    data.add bytes
    echo colors[colnum]
    echo repr bytes
  let fname = "tile_$#.png" % $n
  doAssert fname.savePNG32(data, N, N) == true

proc build_overlapping_propagator*(patterns: Patterns, N: int): Propagator =
  ##
  var propagator: Propagator = newSeqWith(2*N - 1,
    newSeqWith(1,
      newSeqWith(1,
        newSeqWith(0, 0))))
  #assert propagator.len == 3
  let T = patterns.len

  var agree_cnt = 0
  var agree_check_cnt = 0

  for x in 0..propagator.high:
    propagator[x] = newSeqWith(2*N-1,
        newSeqWith(1,
          newSeqWith(1, 0)))
    for y in 0..2*N-2:
      propagator[x][y] = newSeqWith(T, newSeqWith(1, 0))
      for t in 0..<T:
        propagator[x][y][t] = newSeqWith(1, 0)
        var list = newSeq[int]()
        for t2 in 0..<T:
          agree_check_cnt.inc
          if agrees(patterns[t], patterns[t2], N, x - N + 1, y - N + 1):
            list.add t2
            agree_cnt.inc

          propagator[x][y][t] = newSeq[int](list.len)
          for c in 0..list.high:
            propagator[x][y][t][c] = list[c]


  when defined(testing):
    echo "agree ratio: ", agree_cnt.float / agree_check_cnt.float
    echo "agree cnt: ", agree_cnt
    echo "agree checks: ", agree_check_cnt
    doAssert len(propagator) == 2 * N - 1
    doAssert propagator[0][0].len == T
  return propagator

proc generate_weights_and_ordering*(sample: Sample, N, symmetry,
    color_count: int, periodicInput: bool): (Weights, Ordering) =
  ##
  assert symmetry <= 8, "Unexpected symmetry value > 8: " & $symmetry
  let
    SMX = sample.len
    SMY = sample[0].len
    ylimit = if periodicInput: SMY else: SMY - N + 1
    xlimit = if periodicInput: SMX else: SMX - N + 1
  var weights: Weights = initTable[int, int]()
  var ordering: Ordering = @[]
  var candidate_patterns_cnt = 0

  for y in 0..<ylimit:
    for x in 0..<xlimit:
      var ps = newSeqWith(8, newSeqWith(1, newSeqWith(0, 0)))
      # ps: 8 patterns generated from ps[0] using reflection
      # and rotation; sized N * N
      ps[0] = patternFromSample(sample, x, y, N)
      ps[1] = reflect(ps[0], N)
      ps[2] = rotate(ps[0], N)
      ps[3] = reflect(ps[2], N)
      ps[4] = rotate(ps[2], N)
      ps[5] = reflect(ps[4], N)
      ps[6] = rotate(ps[4], N)
      ps[7] = reflect(ps[6], N)

      for k in 0..<symmetry:
        candidate_patterns_cnt.inc
        let ind: int = to_index(ps[k], color_count)
        if not weights.hasKey(ind):
          weights.add(ind, 1)
          ordering.add(ind)
          #save_tile(weights.len, N, ps[k], colors)
        else:
          weights[ind].inc

  when defined(testing):
    echo "candidates patterns: ", candidate_patterns_cnt, " weights|saved: ", weights.len
    echo "ratio weights/candidate_patterns_cnt ",
      100.0 * weights.len.float / candidate_patterns_cnt.float
    echo "ordering ", ordering.len
  return (weights, ordering)

proc load_image*(fname: string): (Colors, Sample) =
  ## Load PNG image, catalog colors
  let png_fn =
    if fname.endswith(".png"):
      fname
    else:
      fname & ".png"

  let bitmap = loadPNG32(png_fn)

  if bitmap == nil:
    echo "failed to load $#" % png_fn
    quit(1)
  #if png.width mod png.width != 0:
  #  echo "err"
  when defined(testing):
    echo "image $# loaded - dimensions: $# $#" % [png_fn, $bitmap.width,
        $bitmap.height]
  assert bitmap.width * bitmap.height * 4 == bitmap.data.len
  let SMX = bitmap.width
  let SMY = bitmap.height

  # enumerate colors
  var sample = newSeqWith(SMX, newSeqWith(SMY, newSeqWith(0, 0)))
  var colors: seq[colors.Color] = @[]

  # Scan whole image, catalog colors
  for y in 0..<SMY:
    for x in 0..<SMX:
      let color = bitmap.get_pixel(x, y)
      var i = 0
      for c in colors:
        if c == color: break
        i.inc
      sample[x][y] = @[i]
      #FIXME different from py
      if i == colors.len:
        colors.add color

  return (colors, sample)

proc init_depth*(wave: var Wave, depth: int) =
  ## init wave matrix with depth
  let X = wave.len
  let Y = wave[0].len
  for x in 0..<X:
    for y in 0..<Y:
      wave[x][y] = newSeqWith(depth, true)


proc build_overlapping_model*(wave: var Wave, colors: Colors, weights: Weights,
    ordering: Ordering, N, width, height: int, periodicOutput: bool, symmetry, ground: int):
    (Patterns, Stationary) =
  ## Create and return: patterns, stationary
  ## Initialize wave matrix
  let W = colors.len ^ (N * N)

  doAssert weights.len == ordering.len
  let T = weights.len

  # Create patterns
  var patterns: Patterns = @[]
  var stationary = newSeq[int](T)

  let color_count = colors.len
  for counter, w in ordering:
    patterns.add patternFromIndex(w, W, N, color_count)
    stationary[counter] = weights[w]

  when defined(testing):
    echo "patterns: ", patterns.len, "x", patterns[0].len
    echo "colors: ", colors.len
    echo "periodicOutput: ", periodicOutput
    assert T == patterns.len

  assert len(patterns) == T
  wave.init_depth(T)

  return (patterns, stationary)

proc on_boundary(p: Point): bool =
  #TODO
  false

proc weighted_random*(distribution: seq[int], randval: float): int =
  ## Pick distribution element
  let total = sum(distribution)
  if total == 0:
    return int(distribution.len.float * randval)
  var x = 0.0
  for i, v in distribution:
    x += distribution[i].float / total.float
    if randval <= x:
      return i
  return 0

proc observe*(wave: var Wave, changes: var Changes,
    stationary: Stationary): string =
  ## Observe WFC
  var
    observed_min = 1000.0
    observed_sum = 0.0
    main_sum = 0.0
    log_sum = 0.0
    noise = 0.0
    entropy = 0.0
    argminx = -1
    argminy = -1
    amount = 0
    w: seq[bool] = @[]

  let T = stationary.len
  let log_t = math.ln T.float

  var log_prob = newSeqWith(T, 0.0)
  for t, s in stationary:
    log_prob[t] = math.ln s.float

  assert wave[0][0].len == stationary.len, $wave[0][0].len & " <--> " &
      $stationary.len

  let FMX = wave.len
  let FMY = wave[0].len
  # Find the point of minimum entropy
  for x in 0..<FMX:
    for y in 0..<FMY:
      # TODO: if self.OnBoundary(x, y):
      if false:
        continue
      w = wave[x][y]
      amount = 0
      observed_sum = 0
      for t, bit in w:
        if w[t]:
          amount.inc
          observed_sum += stationary[t].float

      if 0 == observed_sum:
        return "false"

      when defined(testing):
        noise = 0.000_001 * 0.5
      else:
        # TODO: this seems useless
        noise = 0.000_001 * randomfloat()

      if 1 == amount:
        entropy = 0
      elif T == amount:
        entropy = log_t
      else:
        main_sum = 0
        log_sum = math.ln observed_sum
        for t in 0..<T:
          if w[t]:
            main_sum += stationary[t].float * log_prob[t]
        entropy = log_sum - main_sum / observed_sum
      if entropy > 0 and (entropy + noise < observed_min):
        observed_min = entropy + noise
        argminx = x
        argminy = y

  # No minimum entropy, so mark everything as being observed
  if (-1 == argminx) and (-1 == argminy):
    var observed = newSeqWith(FMY, newSeqWith(FMX, 0))
    for x in 0..<FMX:
      for y in 0..<FMY:
        for t in 0..<T:
          if wave[x][y][t]:
            observed[x][y] = t
            break

    return "true"

  # A minimum point has been found, so prep it for propogation.
  var distribution = newSeqWith(T, 0)
  for t in 0..<T:
    distribution[t] =
      if wave[argminx][argminy][t]:
        stationary[t]
      else:
        0

  let r = weighted_random(distribution, randomfloat())
  for t in 0..<T:
    wave[argminx][argminy][t] = (t == r)

  changes[argminx][argminy] = true

  return "none"


proc propagate*(wave: var Wave, changes: var Changes, propagator: Propagator,
    N: int, periodicOutput: bool): bool =
  let FMX = wave.len
  let FMY = wave[0].len
  let T = wave[0][0].len
  assert T == propagator[0][0].len
  var change = false
  var b = false
  var i_one = 0

  for x1 in 0..<FMX:
    for y1 in 0..<FMY:
      if not changes[x1][y1]:
        continue
      changes[x1][y1] = false
      for dx in (1 - N)..<N:
        for dy in (1 - N)..<N:
          var x2 = (x1 + dx) mod FMX
          if x2 < 0:
            x2 += FMX
          var y2 = (y1 + dy) mod FMY
          if y2 < 0:
            y2 += FMY

          if (not periodicOutput) and (x2 + N > FMX or y2 + N > FMY):
            continue

          let w1 = wave[x1][y1]
          let w2 = wave[x2][y2]
          let p = propagator[(N - 1) - dx][(N - 1) - dy]

          for t2 in 0..<T:
            if not w2[t2]:
              continue

            b = false
            var prop = p[t2]
            i_one = 0
            while (i_one < len(prop)) and not b:
              b = w1[prop[i_one]]
              i_one.inc

            if not b:
              changes[x2][y2] = true
              change = true
              assert wave[x2][y2][t2] == true
              wave[x2][y2][t2] = false

  return change


proc count_flags(flags: seq[bool]): int =
  result = 0
  for f in flags:
    if f:
      result.inc

proc newWave*(width, height: int): Wave =
  ## init wave matrix with zero depth
  newSeqWith(width,
    newSeqWith(height,
      newSeqWith(0, true)))

proc newChanges*(width, height: int): Changes =
  newSeqWith(width, newSeqWith(height, false))

proc prepare_overlapping*(wave: var Wave, changes: var Changes,
    propagator: Propagator, N, ground: int, periodicOutput: bool) =
  ##
  let T = wave[0][0].len
  var ground = ((ground + T) mod T)
  if ground == 0:
    return

  let FMX = wave.len
  let FMY = wave[0].len
  doAssert ground > -1
  doAssert ground <= T

  for x in 0..<FMX:
    for t in 0..<T:
      if t != ground:
        wave[x][FMY - 1][t] = false
      changes[x][FMY - 1] = true
      for y in 0..<FMY-1: # yep, "<FMY-1"
        wave[x][y][ground] = false
        changes[x][y] = true

  var pcount = 0
  while propagate(wave, changes, propagator, N, periodicOutput):
    pcount.inc


proc generate_image*(fname: string, width, height, N: int,
    periodicInput = false): (Wave, Colors, Patterns) =
  var wave = newWave(width, height)

  const
    periodicOutput = false
    symmetry = 8
    ground = 4
    overlapping = false

  let (colors, sample) = load_image(fname)
  echo("generate_weights_and_ordering ", N, " ", symmetry, " ", colors.len, " ", periodicInput)
  let (weights, ordering) = generate_weights_and_ordering(sample, N, symmetry,
      colors.len, periodicInput)
  let (patterns, stationary) = build_overlapping_model(
      wave, colors, weights, ordering, N, width, height,
      periodicOutput, symmetry, ground)
  let propagator = build_overlapping_propagator(patterns, N)

  var proptime = 0.0
  var obtime = 0.0

  var changes: Changes = newSeqWith(wave.len, newSeqWith(wave[0].len, false))

  prepare_overlapping(wave, changes, propagator, N, ground, periodicOutput)

  echo "Wave params: ", wave.len, "x", wave[0].len, "x", wave[0][0].len

  for cycle in 0..900:
    #let before = hash wave
    #echo "entering observe ", cycle, " -> ", mhash wave, " ", mhash changes
    let result = observe(wave, changes, stationary)
    #echo "exiting observe ", cycle, " -> ", mhash wave, " ", mhash changes
    #if cycle <= hw_after.len:
    #  assert wave.hash() == hw_after[cycle]
    #let after = hash wave
    #echo (cycle, " ", before[0..3], " ", after[0..3], " ", $lcg_state)

    if result == "true":
      break
    elif result == "false":
      echo "ERROR: failed to converge"
      break

    var pcount = 0
    while propagate(wave, changes, propagator, N, periodicOutput) == true:
      pcount.inc


  return (wave, colors, patterns)



proc graphics(wave: Wave, colors: Colors, patterns: Patterns, width, height,
    N: int): string =
  result = ""
  let FMX = wave.len
  let FMY = wave[0].len
  #result = newSeqOfCap[seq[Color]](FMX)
  for y in 0..FMY-1:
    #result[y] = newSeqOfCap[Color](FMX)
    for x in 0..FMX-1:
      var
        contributors = 0
        r = 0
        g = 0
        b = 0
      for dy in 0..N-1:
        for dx in 0..N-1:
          var sx = x - dx
          var sy = y - dy
          if (sx < 0):
            sx += FMX
          if (sy < 0):
            sy += FMY

          if (x + N > FMX) or (y + N > FMY):
            continue

          for index, flag in wave[x][y]:
            if flag:
              contributors.inc
              let colnum = patterns[index][dx + dy * N]
              #echo x, " ", y, " ", dx, " ", dy, " ", colnum
              let c = colors[colnum].extractRGB()
              r += c.r
              g += c.g
              b += c.b
      if contributors == 0:
        #echo x, " ", y, " ", r, " ", g, " ", b, " ", contributors
        result.add "\0\0\0\0"
      else:
        r = r div contributors
        g = g div contributors
        b = b div contributors
        #echo x, " ", y, " ", r, " ", g, " ", b, " ", contributors
        let bytes = chr(r) & chr(g) & chr(b) & chr(255)
        result.add bytes

  doAssert result.len == FMX * FMY * 4

proc graphics_comp*(wave: Wave, colors: Colors, patterns: Patterns, width,
    height, N: int): string =
  ##
  result = ""
  let FMX = wave.len
  let FMY = wave[0].len
  let T = 12 #FIXME
  for y in 0..<FMY:
    for x in 0..<FMX:
      let w = wave[x][y]
      assert w.len == T
      var pcnt = 0
      for p in w:
        if p: pcnt.inc
      if pcnt == 0:
        let bytes = chr(255) & chr(100) & chr(100) & chr(100)
        result.add bytes
      elif pcnt == 1:
        for t, patval in w:
          if patval:
            let c = colors[patterns[t][0]].extractRGB()
            let bytes = chr(c.r) & chr(c.g) & chr(c.b) & chr(255)
            result.add bytes
            break # pick only the first pattern
      else:
        var r, g, b = 0
        for t, patval in w:
          if patval:
            let c = colors[patterns[t][0]].extractRGB()
            r += int(c.r / pcnt)
            g += int(c.g / pcnt)
            b += int(c.b / pcnt)
        let bytes = chr(r) & chr(g) & chr(b) & chr(255)
        result.add bytes
  doAssert result.len == FMX * FMY * 4

proc render_image*(wave: Wave, colors: Colors, patterns: Patterns,
    zoom = 1): seq[gifwriter.Color] =
  ## Render image into a sequence of Color of length FMX * FMY * zoom * zoom
  let FMX = wave.len
  let FMY = wave[0].len
  let T = wave[0][0].len # TODO: is it right?
  result = newSeq[gifwriter.Color](FMX * FMY * zoom * zoom)
  for y in 0..<FMY:
    for x in 0..<FMX:
      let img_index = x * zoom + y * FMX * zoom * zoom
      let w = wave[x][y]
      var pcnt = 0
      for p in w:
        if p: pcnt.inc
      var r, g, b = 0
      for t, patval in w:
        if patval:
          let c = colors[patterns[t][0]].extractRGB()
          r += int(c.r / pcnt)
          g += int(c.g / pcnt)
          b += int(c.b / pcnt)
      let o = gifwriter.Color(r: r.uint8, g: g.uint8, b: b.uint8)
      for zx in 0..<zoom:
        for zy in 0..<zoom:
          result[img_index + zx + zy * FMX * zoom] = o


proc writeout_image(fname: string, wave: Wave, colors: Colors,
    patterns: Patterns, width, height, N: int, zoom = 1) =
  var data = ""
  let FMX = wave.len
  let FMY = wave[0].len
  echo "PAT LEN ", patterns.len
  for y in 0..FMY-1:
    let dy = if y < FMY - N + 1: 0 else: N - 1
    for x in 0..FMX-1:
      let dx = if x < FMX - N + 1: 0 else: N - 1

      var pat: Pattern
      #echo wave[x][y].len  67
      #for i, flag in wave[x][y]:
      #  if flag == true:
      #    pat = patterns[i]
      #    break

      #for dy in 0..N-1:
      #  for dx in 0..N-1:
      #    #colors[pat[dx + dy * N]].extractRGB()
      #    discard

      #let c = colors[pat[5]].extractRGB()
      # FIXME
      #let c = colors[pat[1]].extractRGB()
      #let bytes = chr(c.r) & chr(c.g) & chr(c.b) & chr(255)
      #doAssert data.len == (x + y * FMX) * 4
      #data.add bytes
      #doAssert bytes.len == 4

      #let c = colors2[patterns[observed[x - dx][y - dy]][dx + dy * N]]

      #bitmapData[x + y * FMX] = unchecked((int)0xff000000 | (c.R << 16) | (c.G << 8) | c.B)
      break

  if existsFile(fname):
    echo "overwriting!"
    #quit(1)

  data.add repeat('\0', FMX * FMY * 4 - data.len)
  doAssert data.len == FMX * FMY * 4
  if zoom == 1:
    doAssert fname.savePNG32(data, width, height) == true
    echo width, " x ", height, " z=1 $# written" % fname
  else:
    var data2 = newSTring(data.len * zoom * zoom)
    for y in 0..FMY-1:
      for x in 0..FMX-1:
        let src_index = x * 4 + y * FMY * 4
        let src = data[src_index .. src_index+3]
        assert src.len == 4
        for dy in 0..zoom-1:
          for dx in 0..zoom-1:
            let dst_index = (x * zoom + dx + (y * zoom + dy) * zoom * FMY) * 4
            for pos, v in src:
              data2[dst_index + pos] = v

    doAssert data2.len == FMX * FMY * 4 * zoom * zoom
    doAssert fname.savePNG32(data2, FMX * zoom, FMY * zoom) == true
    echo FMX * zoom, " x ", FMY * zoom, " $# written" % fname

proc write_png*(fname, data: string, wave: Wave, overwrite = false) =
  ## Write static PNG image to disk
  let FMX = wave.len
  let FMY = wave[0].len
  assert data.len == FMX * FMY * 4
  if existsFile(fname):
    if overwrite:
      removeFile(fname)
    else:
      raise newException(IOError, "File exists")
  doAssert savePNG32(fname, data, FMX, FMY, 16) == true



proc generate_2d_animated_gif*(input_fn, output_basefn: string, width, height,
    N: int, periodicInput = false,
    ground = 0, symmetry = 8, fps = 10.0, zoom = 4, maxcycles = 8000,
        frame_to_cycle_interval = 10) =
  ## Generate and write out animated GIF
  const
    periodicOutput = true

  var wave = newWave(width, height)
  let (colors, sample) = load_image(input_fn)
  let (weights, ordering) = generate_weights_and_ordering(sample, N, symmetry,
      colors.len, periodicInput)
  let (patterns, stationary) = build_overlapping_model(wave, colors, weights,
    ordering,
    N, width, height, periodicOutput, symmetry, ground)
  let propagator = build_overlapping_propagator(patterns, N)
  var changes = newChanges(width, height)

  # output gif
  var gif = newGif("$#.gif" % output_basefn, width * 4, height * 4, fps = fps)

  for cycle in 0..maxcycles:
    if observe(wave, changes, stationary) != "none":
      break
    while propagate(wave, changes, propagator, N, periodicOutput):
      discard
    if (cycle mod frame_to_cycle_interval) == 0:
      let gif_frame = render_image(wave, colors, patterns, zoom = 4)
      gif.write(gif_frame, 0.0, false)
