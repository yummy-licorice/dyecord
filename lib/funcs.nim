import terminal, chroma, pixie, colors, dimscord, options, asyncdispatch, strformat
include prelude

var
  flipName: string
  convName: string
  lumaName: string

proc fileName(file: string): void =
  flipName = "flip-" & splitFile(file).name & ".png"
  convName = "conv-" & splitFile(file).name & ".png"
  lumaName = "luma-" & splitFile(file).name & ".png"

proc normalizeHex*(hex: string): string =
  var h = hex.replace("#", "")
  if h.len == 3:
    return fmt"{h[0]}{h[0]}{h[1]}{h[1]}{h[2]}{h[2]}"
  elif h.len == 6:
    return h

proc col*(imgPath: string, bar: bool, colors: seq[string]): void =
  stdout.styledWriteLine(fgYellow, "Converting: ", fgWhite, splitFile(
      imgPath).name & splitFile(imgPath).ext & " ...")
  fileName(imgPath)
  var imageFile = readImage(imgPath)
  let h = imageFile.height
  let w = imageFile.width
  let colorsRGB = colors.prepareClosestColor()
  var newImg = copy(imageFile)
  for y in 1..h:
    for x in 1..w:
      newImg.setColor(x = x, y = y, color = getClosestColor(
          colorsRGB, newImg.getColor(x, y)))

  newImg.save(convName)
  stdout.styledWriteLine(fgGreen, "Completed: ", fgWhite, splitFile(
      imgPath).name & splitFile(imgPath).ext & "\n")

export convName
