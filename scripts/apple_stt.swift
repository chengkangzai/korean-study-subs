// Apple on-device speech-to-text (macOS 26 SpeechAnalyzer) -> JSON lines
// Usage: swift apple_stt.swift <audio file> <out.json> [locale=ko_KR]
import AVFoundation
import Foundation
import Speech

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: apple_stt <audio> <out.json> [locale]")
    exit(2)
}
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let locale = Locale(identifier: args.count > 3 ? args[3] : "ko_KR")

let transcriber = SpeechTranscriber(
    locale: locale,
    transcriptionOptions: [],
    reportingOptions: [],
    attributeOptions: [.audioTimeRange, .transcriptionConfidence]
)

// Download the on-device model if missing
if let req = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
    FileHandle.standardError.write("downloading \(locale.identifier) model...\n".data(using: .utf8)!)
    try await req.downloadAndInstall()
}

let analyzer = SpeechAnalyzer(modules: [transcriber])
let file = try AVAudioFile(forReading: inURL)

struct Word: Codable { let t: String; let s: Double; let e: Double; let c: Double? }
struct Seg: Codable { let start: Double; let end: Double; let text: String; let words: [Word] }

let collector = Task { () -> [Seg] in
    var segs: [Seg] = []
    for try await result in transcriber.results {
        let txt = result.text
        var words: [Word] = []
        for run in txt.runs {
            let piece = String(txt[run.range].characters)
            if let r = run.audioTimeRange {
                words.append(Word(t: piece, s: r.start.seconds, e: r.end.seconds,
                                  c: run.transcriptionConfidence))
            }
        }
        let st = words.first?.s ?? result.range.start.seconds
        let en = words.last?.e ?? result.range.end.seconds
        segs.append(Seg(start: st, end: en, text: String(txt.characters), words: words))
    }
    return segs
}

if let last = try await analyzer.analyzeSequence(from: file) {
    try await analyzer.finalizeAndFinish(through: last)
} else {
    await analyzer.cancelAndFinishNow()
}
let segs = try await collector.value
let enc = JSONEncoder()
enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
try enc.encode(segs).write(to: outURL)
print("\(segs.count) segments -> \(outURL.path)")
