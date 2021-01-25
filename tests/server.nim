import ../ezpipe, std/oids

let pipe = initIpcPipeServer()

echo pipe.id

pipe.accept()

while true:
  case pipe.recv():
  of "hello":
    pipe.send("world")
  of "bye":
    pipe.send("bye")
    break
  else:
    quit "invalid"