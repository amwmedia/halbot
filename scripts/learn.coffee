# Description:
#   Teach hubot about words and what they mean to you
#
# Commands:
#   hubot <word> is <phrase> - teach hubot what this word means to you
#   hubot what is <word> - tells you something hubot knows
#   hubot who told you - tells you who taught him the last term
#   hubot who told you <word> is <term> - tells you who taught him the term specified
#   hubot what words do you know - tells you all the words that hubot knows about
#   hubot what do you think - tells you something random that he knows
#
# Examples:
#   hubot holman is an ego surfer
#   hubot holman is not an ego surfer
# 
# Author:
#   amwmedia

inflection = require "inflection"
module.exports = (robot) ->

  alreadyKnowResponses = [
    'I know.',
    'Duh!',
    'I knew that.',
    'Right.'
  ]

  doNotKnowResponses = [
    'I don\'t know.',
    'Got me.',
    'I have no idea.',
    'Does not compute.'
  ]

  memory = robot.brain.get('learned') || {}
  memory.words ?= {}

  if process.env.HUBOT_AUTH_ADMIN?
    robot.logger.warning 'The HUBOT_AUTH_ADMIN environment variable is set not going to load roles.coffee, you should delete it'
    return

  getAmbiguousUserText = (users) ->
    "Be more specific, I know #{users.length} people named like that: #{(user.name for user in users).join(", ")}"

  robot.respond /(who|what) (is|are) @?(\w+)\??$/i, (msg) ->
    action = msg.match[2].trim()
    word = msg.match[3].trim()
    key = inflection.singularize(word)

    memory.words[key] ?= []
    wordData = memory.words[key]

    if not wordData.length
      msg.send msg.random(doNotKnowResponses)
    else
      memory.lastRecall = msg.random wordData
      msg.send [memory.lastRecall.word, memory.lastRecall.action, memory.lastRecall.term].join(' ')

  robot.respond /who (told|taught) you( that)?\??$/i, (msg) ->
    last = memory.lastRecall || {}
    if not last.user
      msg.send 'told me what?'
    else if last.user == msg.message.user.name.toLowerCase()
      msg.send 'you did'
    else
      msg.send last.user

  robot.respond /who (told|taught) you( that)? @?(\w+) (is|are) (.*)\??/i, (msg) ->
    action = msg.match[4].trim()
    word = msg.match[3].trim()
    term = msg.match[5].trim()
    key = inflection.singularize(word)

    lookup = {}

    if memory.words[key]
      lookup = (m for m in memory.words[key] when m.term is term)
      lookup = if lookup.length then lookup[0] else {}

    if not lookup.user
      msg.send msg.random(doNotKnowResponses)
    else
      if lookup.user == msg.message.user.name.toLowerCase()
        msg.send 'you did'
      else
        msg.send lookup.user

  robot.respond /@?(\w+) (is|are) (.*)/i, (msg) ->
    word = msg.match[1].trim()
    key = inflection.singularize(word)
    action = msg.match[2].trim()
    term = msg.match[3].trim()

    unless word in ['', 'who', 'what', 'where', 'when', 'why']
      unless term.match(/^not\s+/i)
        memory.words[key] ?= []
        wordData = memory.words[key]
        recall = (m for m in wordData when m.term is term)

        if recall.length
          msg.send msg.random(alreadyKnowResponses) + ' ' + recall[0].user + ' told me.'
        else
          wordData.push {
            word: word,
            action: action,
            term: term,
            user: msg.message.user.name.toLowerCase()
          }
          robot.brain.set('learned', memory)
          msg.send 'thanks for teaching me about ' + word

  robot.respond /@?(\w+) (is|are) not (.*)/i, (msg) ->
    word = msg.match[1].trim()
    key = inflection.singularize(word)
    action = msg.match[2].trim()
    term = msg.match[3].trim()

    unless word in ['', 'who', 'what', 'where', 'when', 'why']
      unless term.match(/^not\s+/i)
        memory.words[key] ?= []
        wordData = memory.words[key]
        recall = (m for m in wordData when m.term is term)

        if not recall.length
          msg.send msg.random alreadyKnowResponses
        else
          memory.words[key] = (m for m in wordData when m.term is not term)
          if not memory.words[key].length
            delete memory.words[key]
          robot.brain.set('learned', memory)
          msg.send 'Ok, ' + [word, action, 'not', term].join(' ')

  robot.respond /what( words)? do you know\??/i, (msg) ->
    words = (memory.words[m][0].word for m in Object.keys(memory.words) when memory.words[m].length)
    if words.length
      msg.send 'so far I know about ' + words.join(', ')
    else
      msg.send 'nothing.'

  robot.respond /what do you think\??/i, (msg) ->
    if not (Object.keys memory.words).length
      msg.send msg.random doNotKnowResponses
    else
      key = msg.random Object.keys memory.words
      lookup = msg.random memory.words[key]

      memory.lastRecall = lookup
      robot.brain.set('learned', memory)

      msg.send [lookup.word, lookup.action, lookup.term].join(' ')