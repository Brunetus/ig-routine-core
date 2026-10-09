import Vision
import AppKit
// Default: one line per image, the WIDEST face: `path x y w h` (or NONE / ERR).
// With --all as the first argument: `path n x y w h x y w h ...`, widest first,
// so the caller can tell when someone else is in the picture (2026-10-01).
var args = Array(CommandLine.arguments.dropFirst())
let all = args.first == "--all"
if all { args.removeFirst() }
for p in args {
  guard let img = NSImage(contentsOfFile: p), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print(p, "ERR"); continue }
  let req = VNDetectFaceRectanglesRequest()
  try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
  let W = Double(cg.width), H = Double(cg.height)
  let faces = (req.results ?? []).sorted { $0.boundingBox.width > $1.boundingBox.width }
  if all {
    if faces.isEmpty { print(p, "NONE"); continue }
    var out = "\(p) \(faces.count)"
    for f in faces {
      let b = f.boundingBox
      out += " \(Int(b.minX*W)) \(Int((1-b.maxY)*H)) \(Int(b.width*W)) \(Int(b.height*H))"
    }
    print(out)
  } else if let f = faces.first {
    let b = f.boundingBox
    print(p, Int(b.minX*W), Int((1-b.maxY)*H), Int(b.width*W), Int(b.height*H))
  } else { print(p, "NONE") }
}
