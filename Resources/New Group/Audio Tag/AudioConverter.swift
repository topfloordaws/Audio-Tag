import Foundation

struct AudioConverter {
  /// Convert any audio file → MP3 (libmp3lame VBR quality 2)
  func toMP3(input: URL, output: URL) throws {
    // We quote paths in case they have spaces
    let cmd = """
      ffmpeg -y -i '\(input.path)' \
      -codec:a libmp3lame -qscale:a 2 \
      '\(output.path)'
      """
    try runShell(cmd)
  }

  /// Convert any audio file → M4A (AAC 192 kbps)
  func toM4A(input: URL, output: URL) throws {
    let cmd = """
      ffmpeg -y -i '\(input.path)' \
      -codec:a aac -b:a 192k \
      '\(output.path)'
      """
    try runShell(cmd)
  }

  /// WAV → MP3 (simply delegates)
  func wavToMP3(input: URL, output: URL) throws {
    try toMP3(input: input, output: output)
  }

  /// MP3 → WAV (default PCM)
  func mp3ToWAV(input: URL, output: URL) throws {
    let cmd = "ffmpeg -y -i '\(input.path)' '\(output.path)'"
    try runShell(cmd)
  }
}
//
//  AudioConverter.swift
//  Audio Tag
//
//  Created by Dawson Pham on 6/24/25.
//

