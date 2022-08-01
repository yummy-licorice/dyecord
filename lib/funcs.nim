import terminal, chroma, pixie, colors
include prelude

var
  flipName: string
  convName: string
  lumaName: string

proc fileName(file: string): void =
  flipName = "flip-" & splitFile(file).name & ".png"
  convName = "conv-" & splitFile(file).name & ".png"
  lumaName = "luma-" & splitFile(file).name & ".png"

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
