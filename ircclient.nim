import os
import sockets
import strutils
import threadpool
import tables
import macros
  
#global
var current_channel{.threadvar.}: string

proc parseCommand(s, command) = 
  if command.startswith("quit"):
    send(s, "QUIT :Irc client exited\r\n")
    s.close()
    system.quit()
  if command.startswith("join"):
    var channel = strip(split(command, " ")[1])
    send(s, "JOIN $#\r\n" % [channel])
    current_channel = channel
    echo("Channel switched to $#" % [channel])
  if command.startswith("chan"):
    var channel = strip(split(command, " ")[1])
    current_channel = channel
    send(s, "NAMES $#\r\n" % [current_channel])
    echo("[Channel switched to $#]" % [channel])

proc readInput(s, channel) = 
  var channel = channel
  while true:
    stdout.write("[$#]>" % [channel])
    var input = readLine(stdin)
    if input.startswith("/"):
      var command = input[1.. -1]
      parseCommand(s, command)
    else:
      send(s, "PRIVMSG $# :$#\r\n" % [channel, input])
    channel = current_channel

proc parseData(s, channel) =
  var data = TaintedString""
  var messages = initTable[string, seq[string]]()
  var clear = false
  var channel = channel
  var current_channel = channel
  while true:
    readLine(s, data)
    data = strip(data)
    if data.contains("End of /NAMES list"):
      channel = split(data, " ")[3]
      current_channel = channel
      var q = os.execShellCmd("clear")
      echo("[Current channel is]:$#" % [current_channel])
    if data.contains(" PRIVMSG "):
      channel = split(data, " PRIVMSG ")[1]
      channel = split(channel, " :")[0]
      var name = split(data, "!")[0][1.. -1]
      var message = split(data, "PRIVMSG $# :" % [channel])[1]
      message = "[$#][$#]$#" % [channel, name, message]
      echo(message)
      if messages.hasKey(channel):
        messages.mget(channel).add(message)
      else:
        messages[channel] = @[]
        messages.mget(channel).add(message)
      if messages.hasKey(current_channel):
        var q = os.execShellCmd("clear")
        for message in messages[current_channel]:
          echo(message)
    else:
      echo(strip(data))
    if data.startswith("PING "):
      var hashbit = strip(split(" ", data)[1])
      send(s, "PONG $#\r\n" % [hashbit])
    if data.contains(" 376 "):
      send(s, "JOIN $#\r\n" % [channel])

proc main() =
  #Get the basic details from the user to connect to the IRC Server
  stdout.write("[Enter username]:")
  var name = readLine(stdin)
  stdout.write("[Enter host]:")
  var host = readLine(stdin)
  stdout.write("[Enter port]:")
  var port = readLine(stdin)
  stdout.write("[Enter channel]:") 
  var channel: string = readLine(stdin)
  var s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP, buffered = true)
  connect(s, host, Port(parseInt(port)), AF_INET)
  send(s, "NICK $#\r\n" % [name])
  send(s, "USER $# $# $# :$#\r\n" % [name, name, name, name])
  current_channel = channel
  spawn(parseData(s, channel))
  readInput(s, channel)
main()
