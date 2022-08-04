include prelude
import dotenv,
       dimscord,
       dimscmd,
       asyncdispatch,
       options,
       osproc,
       parsetoml,
       dimscord/restapi/requester,
       json,
       sysinfo

import ../lib/[funcs, palettes]

# Read the secrets file
var token: string
var imgurID: string

try:
  load()
  token = getenv("TOKEN")
  imgurID = getenv("IMGUR_ID")
except:
  token = getenv("TOKEN")
  imgurID = getenv("IMGUR_ID")

# Parse the config file
var
  parsed = parsetoml.parseFile(getCurrentDir() / "config.toml")
  prefix = $(parsed["Config"]["prefix"])
  perms = $(parsed["Config"]["permissions"])
  ownerID = $(parsed["Config"]["owner_id"])
  appID = $(parsed["Config"]["app_id"])
  inviteLink = fmt"https://discord.com/api/oauth2/authorize?client_id={appID}&permissions={perms}&scope=applications.commands%20bot"
  guildID = $(parsed["Config"]["guild_id"])
  guildInvite = $(parsed["Config"]["permissions"])
  localCommands = parsed["Switches"]["local_slash"].getBool()

# Dimscord setup
let discord = newDiscordClient(token)
var cmd = discord.newHandler() # Must be var
var guilds: seq[string]

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  await s.updateStatus(activity = some ActivityStatus(
      name: "with images",
      kind: atPlaying
  ), status = "online")

  echo "Ready as " & $r.user
  let j = (waitFor discord.api.request(
         "GET",
         endpointOAuth2Application()
  ))
  echo j
  await cmd.registerCommands


proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
  discard await cmd.handleMessage(prefix, s, msg) # Returns true if a command was handled
    # You can also pass in a list of prefixes
    # discard await cmd.handleMessage(@["$$", "&"], s, msg)


proc interactionCreate (s: Shard, i: Interaction) {.event(discord).} =
  discard await cmd.handleInteraction(s, i)

# Slash commands
var defaultGuildID = ""

if localCommands:
  defaultGuildID = guildID

cmd.addSlash("ping", guildID = defaultGuildID) do ():
  ## Return bot ping
  let response = InteractionResponse(
      kind: irtChannelMessageWithSource,
      data: some InteractionApplicationCommandCallbackData(
        embeds: @[Embed(
            title: some "🏓 Pong!",
            description: some fmt"My ping is: {$s.latency}ms",
            color: some 0x36393f
    )]
  )
  )
  await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("convert", guildID = defaultGuildID) do (url {.help: "The url of the file to convert".}: string,
    palette {.help: "The palette to convert to".}: string):
  ## Convert an image to a specific set of colors
  try:
    var filename = url.split("/")[url.split("/").len - 1]
    var imageDir = getCurrentDir() / "images"
    let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
          embeds: @[Embed(
              title: some "📷 Converting",
              description: some fmt"Please give me a moment...",
              color: some 0x36393f
      )]
      #files = @[DiscordFile(
      #    name: convName,
      #    body: convName
      #)]
    )
    )
    await discord.api.createInteractionResponse(i.id, i.token, response)
    discard execShellCmd(fmt"curl -O {url}")
    echo "Downloaded {filename}"
    var file = filename
    var convName = "conv-" & filename.splitFile().name & ".png"
    var col: seq[string]
    for k, v in pal.fieldPairs:
      if k == palette:
        col = v
    if col.len == 0:
      let response = InteractionResponse(
          kind: irtChannelMessageWithSource,
          data: some InteractionApplicationCommandCallbackData(
            embeds: @[Embed(
                title: some "Error",
                description: some fmt"Palette {palette} not found",
                color: some 0x36393f
        )]
      )
      )
      await discord.api.createInteractionResponse(i.id, i.token, response)
    col(file, false, col)
    removeFile(imageDir / filename)
    echo "File removed"
    let convUrl = execCmdEx(fmt"curl -s --location --request POST 'https://api.imgur.com/3/image' --header 'Authorization: Client-ID {imgurID}' --form 'image=@{convName}' | jq .data.link")[
        0].replace("\"", "")
    discard await discord.api.editInteractionResponse(appID, i.token,
        message_id = "@original", embeds = @[
        Embed(
            title: some "📷 Image converted!",
            description: some fmt"{convUrl}",
            color: some 0x36393f,
            image: some EmbedImage(url: convUrl)
      )]
    )
    removeFile getCurrentDir() / convName
    echo "File removed"
  except:
    discard await discord.api.editInteractionResponse(appID, i.token,
        message_id = "@original", embeds = @[
        Embed(
            title: some "Error",
            description: some getCurrentExceptionMsg(),
            color: some 0x36393f,
      )]
    )
cmd.addSlash("invite", guildID = defaultGuildID) do ():
  ## Return bot invite link
  let response = InteractionResponse(
      kind: irtChannelMessageWithSource,
      data: some InteractionApplicationCommandCallbackData(
        embeds: @[Embed(
            title: some "Invite me!",
            description: some fmt"""[Click here]({inviteLink})""",
            color: some 0x36393f
    )]
  )
  )
  await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("eval", guildID = defaultGuildID) do (
  code {.help: "The code to evaluate".}: string):
  ## Evaluate some nim code (owner only)
  if i.member.get().user.id != ownerID:
    let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
          embeds: @[Embed(
              title: some "Error",
              description: some "Only the bot owner can use this command!",
              color: some 0x36393f
      )]
    )
    )
    await discord.api.createInteractionResponse(i.id, i.token, response)
  else:
    try:
      var result = execCmdEx("nim --eval:'$#' --verbosity:0" % [code])[
          0].strip()
      let response = InteractionResponse(
          kind: irtChannelMessageWithSource,
          data: some InteractionApplicationCommandCallbackData(
            embeds: @[Embed(
                title: some "📝 Eval result",
                description: some fmt"```{result}```",
                color: some 0x36393f
        )]
      )
      )
      await discord.api.createInteractionResponse(i.id, i.token, response)
    except:
      let response = InteractionResponse(
          kind: irtChannelMessageWithSource,
          data: some InteractionApplicationCommandCallbackData(
            embeds: @[Embed(
                title: some "Error",
                description: some getCurrentExceptionMsg(),
                color: some 0x36393f
        )]
      )
      )
      await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("stats", guildID = defaultGuildID) do ():
  ## Return computer stats
  let response = InteractionResponse(
      kind: irtChannelMessageWithSource,
      data: some InteractionApplicationCommandCallbackData(
        embeds: @[Embed(
            title: some "💻 Stats",
            description: some fmt"""```OS: {getOsName()}
Manufacturer: {getMachineManufacturer()}
CPU: {getCpuName()}
CPU Speed: {getCpuGhz()}
CPU Cores: {getNumTotalCores()}
CPU Manufacturer: {getCpuManufacturer()}
HOST: {getMachineModel()}
GPU: {getGpuName()}```""",
            color: some 0x36393f
    )]
  )
  )
  await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("purge", guildID = defaultGuildID) do (
  messages {.help: "Number of messages to delete".}: Option[int]):
  ## Purge the given amount of messages
  let userPerms = i.member.get().permissions
  let mc = messages.get(100)
  var canUse = false
  for perm in userPerms:
    if $perm == "Manage Messages":
      canUse = true
    #echo $perm
  if not canUse:
    let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
          embeds: @[Embed(
              title: some "Error",
              description: some "You don't have permission to use this command!",
              color: some 0x36393f
      )]
    )
    )
    await discord.api.createInteractionResponse(i.id, i.token, response)
  else:
    try:
      let msgs = await discord.api.getChannelMessages(i.channel_id.get,
          limit = mc)
      let response = InteractionResponse(
          kind: irtChannelMessageWithSource,
          data: some InteractionApplicationCommandCallbackData(
            embeds: @[Embed(
                title: some "🗑 Puring...",
                description: some fmt"Purging {mc} messages",
                color: some 0x36393f
        )]
      )
      )
      await discord.api.createInteractionResponse(i.id, i.token, response)
      var m: seq[string]
      for msg in msgs:
        m.add(msg.id)
      await discord.api.bulkDeleteMessages(i.channel_id.get, m)
      discard await discord.api.editInteractionResponse(appID, i.token,
          message_id = "@original", embeds = @[Embed(
              title: some "🗑 Purged!",
              description: some fmt"Purged {mc} messages",
              color: some 0x36393f
        )]
      )
    except:
      let response = InteractionResponse(
          kind: irtChannelMessageWithSource,
          data: some InteractionApplicationCommandCallbackData(
            embeds: @[Embed(
                title: some "Error",
                description: some getCurrentExceptionMsg(),
                color: some 0x36393f
        )]
      )
      )
      await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("server", guildID = defaultGuildID) do ():
  ## Return the invite for the support server
  let response = InteractionResponse(
      kind: irtChannelMessageWithSource,
      data: some InteractionApplicationCommandCallbackData(
        embeds: @[Embed(
            title: some "🌎 Server Invite",
            description: some fmt"[Click here]({guildInvite}) to join the server",
            color: some 0x36393f
    )]
  )
  )
  await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("kill", guildID = defaultGuildID) do ():
  ## Kill the bot (owner only)
  if i.member.get().user.id != ownerID:
    let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
          embeds: @[Embed(
              title: some "Error",
              description: some "Only the bot owner can use this command!",
              color: some 0x36393f
      )]
    )
    )
    await discord.api.createInteractionResponse(i.id, i.token, response)
  else:
    let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
          embeds: @[Embed(
              title: some "💀 Killing...",
              description: some "Killing the bot",
              color: some 0x36393f
      )]
    )
    )
    await discord.api.createInteractionResponse(i.id, i.token, response)
    quit(0)

# Start the bot
waitFor discord.startSession()
