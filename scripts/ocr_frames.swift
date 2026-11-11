// OCR a directory of frames named NNNNN.jpg (frame index = second, fps=1) with Apple Vision.
// Usage: ocr_frames <dir> <out.json>
// Output: [{"t": seconds, "lines": [{"text":..., "conf":..., "box":[x,y,w,h]}]}]  (only frames with text)
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: ocr_frames <dir> <out.json>"); exit(2) }
let dir = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])

struct Line: Codable { let text: String; let conf: Float; let box: [Double] }
struct Frame: Codable { let t: Double; let lines: [Line] }

let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "jpg" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

var frames: [Frame] = []
for f in files {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["ko-KR", "en-US"]
    req.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(url: f, options: [:])
    try handler.perform([req])
    let lines: [Line] = (req.results ?? []).compactMap { obs in
        guard let c = obs.topCandidates(1).first else { return nil }
        let b = obs.boundingBox
        return Line(text: c.string, conf: c.confidence,
                    box: [b.origin.x, b.origin.y, b.width, b.height].map { (Double($0) * 1000).rounded() / 1000 })
    }
    if !lines.isEmpty {
        // ffmpeg fps=1 numbering starts at 1 → frame N ≈ second N-1 (+0.5 centre)
        let n = Double(f.deletingPathExtension().lastPathComponent) ?? 0
        frames.append(Frame(t: max(0, n - 0.5), lines: lines))
    }
}
let enc = JSONEncoder()
enc.outputFormatting = [.withoutEscapingSlashes]
try enc.encode(frames).write(to: out)
print("\(files.count) frames, \(frames.count) with text -> \(out.path)")
