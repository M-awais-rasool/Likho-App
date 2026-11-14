import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

func fail(_ m: String) -> Never { FileHandle.standardError.write((m + "\n").data(using: .utf8)!); exit(1) }

let a = CommandLine.arguments
guard a.count >= 7 else { fail("usage: encode <framesDir> <audio.m4a> <out.mp4> <w> <h> <fps>") }
let framesDir = a[1], audioPath = a[2], outPath = a[3]
let W = Int(a[4])!, H = Int(a[5])!, FPS = Int32(a[6])!

let fm = FileManager.default
let frames = try! fm.contentsOfDirectory(atPath: framesDir)
    .filter { $0.hasSuffix(".jpg") }.sorted()
guard !frames.isEmpty else { fail("no frames in \(framesDir)") }
print("frames: \(frames.count)")

let tmp = NSTemporaryDirectory() + "likho_video_only.mp4"
try? fm.removeItem(atPath: tmp)
try? fm.removeItem(atPath: outPath)

let writer = try! AVAssetWriter(outputURL: URL(fileURLWithPath: tmp), fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W,
    AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 12_000_000,
        AVVideoMaxKeyFrameIntervalKey: 60,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoAllowFrameReorderingKey: true,
    ],
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: W,
        kCVPixelBufferHeightKey as String: H,
    ])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let cs = CGColorSpaceCreateDeviceRGB()
let queue = DispatchQueue(label: "encode")
let done = DispatchSemaphore(value: 0)
var i = 0

input.requestMediaDataWhenReady(on: queue) {
    while input.isReadyForMoreMediaData {
        if i >= frames.count {
            input.markAsFinished()
            done.signal()
            return
        }
        let url = URL(fileURLWithPath: framesDir + "/" + frames[i])
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fail("bad frame \(frames[i])") }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
        guard let buf = pb else { fail("no pixel buffer") }
        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf),
                            width: W, height: H, bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                            space: cs,
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
        CVPixelBufferUnlockBaseAddress(buf, [])
        adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: FPS))
        if i % 150 == 0 { print("  encoded \(i)") }
        i += 1
    }
}
done.wait()
let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
finished.wait()
if writer.status != .completed { fail("writer failed: \(String(describing: writer.error))") }
print("video track written")

// ---- mux with the audio -------------------------------------------------
let comp = AVMutableComposition()
let vAsset = AVURLAsset(url: URL(fileURLWithPath: tmp))
let aAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))
let vTrack = vAsset.tracks(withMediaType: .video).first!
let dur = vTrack.timeRange.duration
let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try! cv.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: vTrack, at: .zero)
if let aTrack = aAsset.tracks(withMediaType: .audio).first {
    let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let aDur = min(dur, aTrack.timeRange.duration)
    try! ca.insertTimeRange(CMTimeRange(start: .zero, duration: aDur), of: aTrack, at: .zero)
} else {
    print("WARNING: no audio track found")
}
let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
export.outputURL = URL(fileURLWithPath: outPath)
export.outputFileType = .mp4
export.shouldOptimizeForNetworkUse = true
let sem = DispatchSemaphore(value: 0)
export.exportAsynchronously { sem.signal() }
sem.wait()
if export.status != .completed { fail("export failed: \(String(describing: export.error))") }
try? fm.removeItem(atPath: tmp)
let size = (try! fm.attributesOfItem(atPath: outPath)[.size] as! NSNumber).intValue
print("wrote \(outPath)  \(size / 1024 / 1024) MB")
