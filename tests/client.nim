import ../ezpipe, std/[os, oids]

if paramCount() != 1:
  quit "param count != 1"

let pipe = initIpcPipeClient(parseOid(paramStr(1)))

pipe.send("hello")
echo pipe.recv()
pipe.send("bye")
echo pipe.recv()