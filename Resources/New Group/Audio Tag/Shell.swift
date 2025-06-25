import Foundation

enum ShellError: Error {
  case nonZeroExit(code: Int32, output: String)
}

/// Run a one-line shell command via `/bin/bash -l -c`
/// Returns combined stdout+stderr or throws on non-zero exit.
@discardableResult
func runShell(_ cmd: String) throws -> String {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/bin/bash")
  task.arguments     = ["-l", "-c", cmd]

  let pipe = Pipe()
  task.standardOutput = pipe
  task.standardError  = pipe

  try task.run()
  task.waitUntilExit()

  let data   = pipe.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: data, encoding: .utf8) ?? ""

  guard task.terminationStatus == 0 else {
    throw ShellError.nonZeroExit(code: task.terminationStatus,
                                output: output)
  }
  return output
}
