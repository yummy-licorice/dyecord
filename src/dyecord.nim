include prelude
import dotenv,
       dimscord,
       dimscmd,
       asyncdispatch,
       options,
       osproc

import ../lib/funcs

# Read the secrets file
load()
let token = getenv("TOKEN")
let prefix = getenv("BOT_PREFIX")

# Dimscord setup
let discord = newDiscordClient(token)
var cmd = discord.newHandler() # Must be var

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as " & $r.user

proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
    discard await cmd.handleMessage(prefix, s, msg) # Returns true if a command was handled
    # You can also pass in a list of prefixes
    # discard await cmd.handleMessage(@["$$", "&"], s, msg)

proc interactionCreate (s: Shard, i: Interaction) {.event(discord).} =
    discard await cmd.handleInteraction(s, i)

# Message commands
cmd.addChat("ping") do ():
    discard await discord.api.sendMessage(
            msg.channelID,
            embeds = @[Embed(
                title: some "🏓 Pong!",
                description: some fmt"My ping is: {$s.latency}ms",
                color: some 0x36393f
        )]
    )

cmd.addChat("convert") do (url: string, colors: seq[string]):
    try:
        var filename = url.split("/")[url.split("/").len - 1]
        var imageDir = getCurrentDir() / "images"
        discard execShellCmd(fmt"wget {url} -O {imageDir}/{filename}")
        echo "Downloaded {filename}"
        var file = imageDir / filename
        var convName = "conv-" & filename.splitFile().name & ".png"
        col(file, false, colors)
        removeFile(imageDir / filename)
        echo "File removed"
        let convUrl = execCmdEx(fmt"curl -s -F'file=@{convName}' https://0x0.st")[0]
        discard await discord.api.sendMessage(
            msg.channelID,
            embeds = @[Embed(
                title: some "📷 Image converted!",
                description: some fmt"{convUrl}",
                color: some 0x36393f,
                image: some EmbedImage(url: convUrl)
            )]
            #files = @[DiscordFile(
            #    name: convName,
            #    body: convName
            #)]
        )
        removeFile getCurrentDir() / convName
        echo "File removed"
    except:
        discard await discord.api.sendMessage(
            msg.channelID,
            embeds = @[Embed(
                title: some "Error",
                description: some getCurrentExceptionMsg(),
                color: some 0x36393f
            )]
        )
        return

# Start the bot
waitFor discord.startSession()
