module.exports = (robot) ->
  emojiTrigger = null
  leaderboard = {}
  userRegexp = new RegExp(/@?([\w .\-]+)\?*$/)
  # TODO: Add ability to change the "shout" term to anything else.

  removeAtSymbolFromUsername = (username) ->
    if username.charAt(0) is '@'
      username = username.substring(1)
    return username

  getLeaderboard = () ->
    leaderboard = robot.brain.get('leaderboard') || {}
    unless leaderboard?
      robot.brain.set('leaderboard', leaderboard)
    # TODO: Add server sync
    return leaderboard

  setLeaderboard = (data) ->
    leaderboard = data
    robot.brain.set('leaderboard', data)
    # TODO: Add server sync

  userGiveShout = (user) ->
    username = removeAtSymbolFromUsername(user)

    # TODO: Do a user lookup and store by :id key rather than username
    leaderboard = getLeaderboard()
    unless leaderboard.hasOwnProperty(username)
      leaderboard[username] = 0
    leaderboard[username] += 1
    console.log(leaderboard)
    setLeaderboard(leaderboard)

  userGetShouts = (user) ->
    username = removeAtSymbolFromUsername(user)
    leaderboard = getLeaderboard()
    return leaderboard[username] || 0

  getUserName = (res) ->
    return res.match[1]

  setEmoji = (emoji) ->
    emojiTrigger = emoji

    robot.hear /(@[\w.\-]+)(\s\w+)?\s*(:[\w\d_\-]*\:)\s*(.*)?/, (res) ->
      fullMatch = res.message.text
      userNames = fullMatch.match(/@[\w.\-]+/g)
      matchedEmoji = fullMatch.match(/:[\w\d_\-]*\:/)[0]

      if matchedEmoji is emoji
        if userNames.length > 1
          userNamesString = userNames.join(', ').replace(/,\s([^,]+)$/, ' and $1')
        else
          userNamesString = userNames[0]

        # TODO: Allow multiple users to recieve shout in a single command.
        if removeAtSymbolFromUsername(userNamesString) is res.message.user.name
          res.reply 'Woah, there ' + userNamesString + '! Self-shouts are not cool, bro.'
        else
          userGiveShout(userNamesString)
          res.reply 'Congrats ' + userNamesString + '!'

  robot.respond /Set a trigger emoji (\:[\w\d_\-]*\:)/, (res) ->
    emoji = res.match[1].trim()
    if emoji?
      setEmoji(emoji)
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

  robot.respond /Show me the leaderboard/, (res) ->
    # TODO: Clean up the display of the leaderboard.
    leaderboard = getLeaderboard()
    leaderboardTxt = '\n:: Shout Leaderboard ::'
    position = 0
    Object.keys(leaderboard).forEach((username) ->
      shoutCount = leaderboard[username]
      position++
      leaderboardTxt += '\n' +
        position + '. ' + username + ' - ' + shoutCount + '\n'
    )
    res.reply leaderboardTxt
