import std/[oids, strformat], ezutils, winim/lean

type IpcPipe* = object
  id: Oid
  handle: Handle

proc `=destroy`*(self: var IpcPipe) =
  discard CloseHandle(self.handle)

proc `=copy`*(self: var IpcPipe, rhs: IpcPipe) {.error.}

proc id*(self: IpcPipe): Oid {.genref.} = self.id

proc newOSError(ctx: string): ref OSError =
  result = newException(OSError, ctx)
  result.errorCode = GetLastError()

proc initIpcPipeServer*(id: Oid = genOid(); size: int32 = 0): IpcPipe {.genrefnew.} =
  result.id = id
  let name = newWideCString fmt"\\.\pipe\ezipc-{id}"
  result.handle = CreateNamedPipe(
    name,
    FILE_FLAG_FIRST_PIPE_INSTANCE or PIPE_ACCESS_DUPLEX,
    PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_WAIT or PIPE_REJECT_REMOTE_CLIENTS,
    2, size, size, 0, nil)
  if result.handle == INVALID_HANDLE_VALUE:
    raise newOSError("failed to create pipe")

proc initIpcPipeClient*(id: Oid; size: int32 = 0): IpcPipe {.genrefnew.} =
  result.id = id
  let name = newWideCString fmt"\\.\pipe\ezipc-{id}"
  if WaitNamedPipe(name, NMPWAIT_WAIT_FOREVER) == 0:
    raise newOSError("failed to wait pipe")
  result.handle = CreateFile(
    name,
    GENERIC_READ or GENERIC_WRITE,
    0, nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0)
  if result.handle == INVALID_HANDLE_VALUE:
    raise newOSError("failed to open pipe")
  var dwMode: DWORD = PIPE_READMODE_MESSAGE
  if SetNamedPipeHandleState(result.handle, addr dwMode, nil, nil) == 0:
    raise newOSError("failed to set pipe state")

proc accept*(self: IpcPipe) {.genref.} =
  if ConnectNamedPipe(self.handle, nil) == 0:
    raise newOSError("failed to connect pipe")

proc send*(self: IpcPipe, content: string) {.genref.} =
  let tmp = content.cstring
  if WriteFile(self.handle, cast[LPVOID](tmp), DWORD content.len, nil, nil) == 0:
    raise newOSError("failed to write to pipe")

proc recv*(self: IpcPipe): string {.genref.} =
  var xlen: DWORD
  var buffer: array[65536, uint8]
  if ReadFile(self.handle, cast[LPVOID](addr buffer), DWORD sizeof(typeof(buffer)), addr xlen, nil) == 0:
    raise newOSError("failed to read from pipe")
  result = %$buffer.toOpenArray(0, int xlen - 1)
