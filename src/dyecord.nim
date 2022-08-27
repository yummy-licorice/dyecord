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

type pe = enum
  decay
  darkdecay
  decayce
  articblush
  catppuccin
  ok
  nord

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
  status = $(parsed["Config"]["status"])

# Dimscord setup
let discord = newDiscordClient(token)
var cmd = discord.newHandler() # Must be var

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  await s.updateStatus(activity = some ActivityStatus(
      name: status,
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

var dmsg = initTable[string, string]()

proc messageDelete (s: Shard, m: Message, exists: bool) {.event(discord).} =
  if not m.author.bot:
    dmsg[get(m.guild_id)] = m.content & ":::" & m.author.username
    echo dmsg[get(m.guild_id)]
  else:
    dmsg["bot"] = m.content & ":::" & m.author.username
    echo dmsg["bot"]

proc respEmbed(i: Interaction, title, description: string): void =
  let response = InteractionResponse(
      kind: irtChannelMessageWithSource,
      data: some InteractionApplicationCommandCallbackData(
        embeds: @[Embed(
            title: some title,
            description: some description,
            color: some 0x36393f
    )]
  )
  )
  waitFor discord.api.createInteractionResponse(i.id, i.token, response)


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

cmd.addSlash("snipe", guildID = defaultGuildID) do ():
  ## Snipe the last deleted message
  try:
    let sm = dmsg[i.guild_id.get()].split(":::")
    let user = sm[1]
    let msg = sm[0]

    let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
          embeds: @[Embed(
              title: some "Sniped!",
              description: some "From: $#\nContent: $#" % [user, msg],
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
              title: some "Error!",
              description: some "Could not find any recently deleted messages in this server!",
              color: some 0x36393f
      )]
    )
    )
    await discord.api.createInteractionResponse(i.id, i.token, response)
cmd.addSlash("convert", guildID = defaultGuildID) do (url {.help: "The url of the file to convert".}: string,
    palette {.help: "The palette to convert to (list palettes by running /list)".}: pe):
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
      if k == $palette:
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
  try:
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
  except:
    let response = InteractionResponse(
      kind: irtChannelMessageWithSource,
      data: some InteractionApplicationCommandCallbackData(
        embeds: @[Embed(
          title: some "Error!",
          description: some "Could not get computer specs",
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

cmd.addSlash("kill", guildID = defaultGuildID) do (
  code {.help: "The exit code to quit with".}: Option[int]):
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
    let c = code.get(0)
    if c == 0 or c == 1:
      let response = InteractionResponse(
          kind: irtChannelMessageWithSource,
          data: some InteractionApplicationCommandCallbackData(
            embeds: @[Embed(
                title: some "💀 Killing...",
                description: some fmt"Bot killed with code {c}",
                color: some 0x36393f
        )]
      )
      )
      await discord.api.createInteractionResponse(i.id, i.token, response)
      quit(c)
    else:
      let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
          embeds: @[Embed(
            title: some "Error",
            description: some "The exit code must be a binary integer (0 or 1)",
            color: some 0x36393f
        )]
      )
      )
      await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("repo", guildID = defaultGuildID) do ():
  ## Get bot source code repository
  let response = InteractionResponse(
    kind: irtChannelMessageWithSource,
    data: some InteractionApplicationCommandCallbackData(
      embeds: @[Embed(
        title: some "🐙 Repo",
        description: some "https://github.com/Infinitybeond1/dyecord",
        color: some 0x36393f
    )]
  )
  )
  await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("list", guildID = defaultGuildID) do ():
  ## List the availible color palettes
  var p: seq[string]
  for k, v in pal.fieldPairs:
    discard v
    p.add(k)
  let response = InteractionResponse(
    kind: irtChannelMessageWithSource,
    data: some InteractionApplicationCommandCallbackData(
      embeds: @[Embed(
        title: some "Palettes",
        description: some p.join("\n"),
        color: some 0x36393f
    )]
  )
  )
  await discord.api.createInteractionResponse(i.id, i.token, response)

cmd.addSlash("kick", guildID = defaultGuildID) do (
  user {.help: "The user to kick".}: User,
    reason {.help: "The reason you are kicking the user".}: Option[string]):
  ## Kick a member from your server
  var canUse = false
  for perm in i.member.get().permissions:
    if $perm == "Kick Members":
      canUse = true
    echo $perm
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
  let r = reason.get("No reason provided")
  let guild = await discord.api.getGuild i.guild_id.get()
  try:
    let dm = (await discord.api.createUserDm(user.id))
    discard await discord.api.sendMessage(dm.id, embeds = @[Embed(
      title: some fmt"You have been kicked from {guild.name}",
      description: some fmt"You were kicked from {guild.name}\nReason: {r}",
      color: some 0x36393f
    )])
  finally:
    await discord.api.removeGuildMember(i.guild_id.get(), user.id, reason = r)
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
#    let response = InteractionResponse(
#      kind: irtChannelMessageWithSource,
#      data: some InteractionApplicationCommandCallbackData(
#        embeds: @[Embed(
#          title: some "Kicked!",
#          description: some fmt"User {user.username} was kicked for {r}",
#          color: some 0x36393f
#      )]
#    )
#    )
#    await discord.api.createInteractionResponse(i.id, i.token, response)

# Start the bot
#

cmd.addSlash("clear_snipes", guildID = defaultGuildID) do ():
  ## Clear the snipe database (owner only)
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
    dmsg = initTable[string, string]()
    i.respEmbed("Cleared!", "Cleared the sniped messages database")

waitFor discord.startSession()
