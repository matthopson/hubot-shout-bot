module.exports = (robot) ->
  userRegexp = new RegExp(/@?([\w .\-]+)\?*$/)
  # TODO: Add ability to change the "shout" term to anything else.

  removeAtSymbolFromUsername = (username) ->
    if username.charAt(0) is '@'
      username = username.substring(1)
    return username

  getLeaderboard = ->
    leaderboard = robot.brain.get('leaderboard') || {}
    unless leaderboard?
      robot.brain.set('leaderboard', leaderboard)
    # TODO: Add server sync
    return leaderboard

  setLeaderboard = (data) ->
    robot.brain.set('leaderboard', data)
    # TODO: Add server sync

  userGiveShout = (user, count=1) ->
    username = removeAtSymbolFromUsername(user)
    user = getUserByName(username)
    return unless user

    leaderboard = getLeaderboard()
    leaderboard[user.id] = (leaderboard[user.id] || 0) + count

    # Migrate from username keys (v1.3)
    if leaderboard.hasOwnProperty(username)
      leaderboard[user.id] += leaderboard[username] || 0
      delete leaderboard[username]

    setLeaderboard(leaderboard)
    # TODO: Perhaps return info about the user?
    return true

  userGetShouts = (user) ->
    username = removeAtSymbolFromUsername(user)
    user = getUserByName(username)
    return unless user

    leaderboard = getLeaderboard()
    shoutCount = leaderboard[user.id] || 0

    # Migrate from username keys (v1.3)
    if leaderboard.hasOwnProperty(username)
      shoutCount += leaderboard[username] || 0

    return shoutCount

  getUserName = (res) ->
    return res.match[1]

  getUserByName = (username) ->
    # TODO: Handle cases where it would return more than one
    return robot.brain.usersForFuzzyName(removeAtSymbolFromUsername(username))[0]

  getUserById = (userId) ->
    return robot.brain.userForId(userId)

  getClientUser = (username) ->
    user = getUserByName(username)
    # TODO: Dig into how these ids map with clients other than slack.
    # For now do this ridiculous business.
    return robot.brain.data.users[user.id]

  getTriggerEmoji = ->
    robot.brain.get('emojiTrigger') || null

  setTriggerEmoji = (emoji) ->
    robot.brain.set('emojiTrigger', emoji)


  robot.hear /(@[\w.\-]+)(\s\w+)?\s*(:[\w\d_\-]*\:)\s*(.*)?/, (res) ->
    emojiTrigger = getTriggerEmoji()
    return unless emojiTrigger

    fullMatch = res.message.text
    userNames = fullMatch.match(/@[\w.\-]+/g)
    matchedEmojis = fullMatch.match(/:[\w\d_\-]*\:/g)
    matchedEmojiCount = 0
    senderName = res.message.user.name

    matchedEmojis.forEach((matchedEmoji) ->
      if matchedEmoji is emojiTrigger
        matchedEmojiCount += 1
    )

    if matchedEmojiCount > 0
      userNames.forEach((userName) ->
        if removeAtSymbolFromUsername(userName) is senderName and false
          # NOTE: This is disabled for testing.
          res.reply 'Woah, there ' + userName + '! Self-shouts are not cool, bro.'
        else
          if userGiveShout(userName, matchedEmojiCount)
            clientUser = getClientUser(userName)
            clientSender = getClientUser(senderName)

            if matchedEmojiCount > 1
              shoutCountText = matchedEmojiCount + ' shout outs'
            else
              shoutCountText = 'a shout'

            robot.messageRoom clientUser.id,
              'Congrats! You just recieved ' + shoutCountText + ' from @' + senderName + '!'
            # Respond to the sender
            robot.messageRoom clientSender.id, 'You gave ' + shoutCountText + ' to ' + userName + '! ' +
              'Since I\'m currently in BETA you have unlimited shouts to give!'
      )

  robot.respond /Set a trigger emoji (\:[\w\d_\-]*\:)/, (res) ->
    emoji = res.match[1].trim()
    if emoji?
      setTriggerEmoji(emoji)
      res.reply 'Ok, when I see ' + emoji + ', I\'ll give a shout out!'
    else
      res.reply 'I\'m sorry, something went wrong. Did you set an emoji?'

  robot.hear /I\'d like to give a shout out to @?([\w .\-]+)\?*$/i, (res) ->
    userName = getUserName(res)
    res.reply 'Congrats @' + userName + '!'

  robot.respond /Show me my shouts/, (res) ->
    shoutCount = userGetShouts(res.message.user.name)
    if shoutCount > 0
      res.reply 'You have received ' + shoutCount + ' shouts!'
    else
      res.reply 'Sadly, you have received no shouts - but that doesn\'t mean you should stop being awesome.'

  robot.respond /Show me the trigger emoji/, (res) ->
    res.reply getTriggerEmoji()

  robot.respond /Show me the leaderboard/, (res) ->
    # TODO: Clean up the display of the leaderboard.
    leaderboard = getLeaderboard()
    leaderboardTxt = '\n:: Shout Leaderboard ::'
    position = 0
    Object.keys(leaderboard).forEach((userId) ->
      shoutCount = leaderboard[userId]
      user = getUserById(userId)
      if user?
        position++
        leaderboardTxt += '\n' +
          position + '. ' + user.name + ' - ' + shoutCount + '\n'
    )
    res.reply leaderboardTxt
