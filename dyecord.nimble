# Package

version = "0.1.0"
author = "Luke"
description = "Dye as a discord bot"
license = "GPL-3.0-or-later"
srcDir = "src"
bin = @["dyecord"]


# Dependencies

requires "nim >= 1.4.8"
requires "pixie"
requires "https://github.com/Infinitybeond1/dimscord#head"
requires "https://github.com/Infinitybeond1/dimscmd#head"
requires "parsetoml"
requires "dotenv#head"

task b, "Build the bot":
  exec "nimble build -d:release -d:dimscordDebug --verbose -d:ssl"

task r, "Run the bot":
  exec "nimble build -d:release -d:dimscordDebug --verbose -d:ssl && ./dyecord"
