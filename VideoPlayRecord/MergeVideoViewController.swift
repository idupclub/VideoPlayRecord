//
//  MergeVideoViewController.swift
//  VideoPlayRecord
//
//  Created by Andy on 2/1/15.
//  Copyright (c) 2015 Ray Wenderlich. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import AssetsLibrary
import MediaPlayer
import CoreMedia

class MergeVideoViewController: UIViewController {
  var firstAsset: AVAsset?
  var secondAsset: AVAsset?
  var audioAsset: AVAsset?
  var loadingAssetOne = false
  
  @IBOutlet var activityMonitor: UIActivityIndicatorView!
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  func savedPhotosAvailable() -> Bool {
    if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) == false {
      let alert = UIAlertController(title: "Not Available", message: "No Saved Album found", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
      present(alert, animated: true, completion: nil)
      return false
    }
    return true
  }
  
  func startMediaBrowserFromViewController(_ viewController: UIViewController!, usingDelegate delegate : (UINavigationControllerDelegate & UIImagePickerControllerDelegate)!) -> Bool {
    
    if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) == false {
      return false
    }
    
    let mediaUI = UIImagePickerController()
    mediaUI.sourceType = .savedPhotosAlbum
    mediaUI.mediaTypes = [kUTTypeMovie as NSString as String]
    mediaUI.allowsEditing = true
    mediaUI.delegate = delegate
    present(mediaUI, animated: true, completion: nil)
    return true
  }
  
  func exportDidFinish(_ session: AVAssetExportSession) {
    if session.status == AVAssetExportSessionStatus.completed {
      let outputURL = session.outputURL
      let library = ALAssetsLibrary()
      if library.videoAtPathIs(compatibleWithSavedPhotosAlbum: outputURL) {
        library.writeVideoAtPath(toSavedPhotosAlbum: outputURL,
                                                   completionBlock: nil)
      }
    }
    
    activityMonitor.stopAnimating()
    firstAsset = nil
    secondAsset = nil
    audioAsset = nil
  }
  
  @IBAction func loadAssetOne(_ sender: AnyObject) {
    if savedPhotosAvailable() {
      loadingAssetOne = true
      startMediaBrowserFromViewController(self, usingDelegate: self)
    }
  }
  
  
  @IBAction func loadAssetTwo(_ sender: AnyObject) {
    if savedPhotosAvailable() {
      loadingAssetOne = false
      startMediaBrowserFromViewController(self, usingDelegate: self)
    }
  }
  
  
  @IBAction func loadAudio(_ sender: AnyObject) {
    let mediaPickerController = MPMediaPickerController(mediaTypes: .any)
    mediaPickerController.delegate = self
    mediaPickerController.prompt = "Select Audio"
    present(mediaPickerController, animated: true, completion: nil)
  }
  
  func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImageOrientation, isPortrait: Bool) {
    var assetOrientation = UIImageOrientation.up
    var isPortrait = false
    if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
      assetOrientation = .right
      isPortrait = true
    } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
      assetOrientation = .left
      isPortrait = true
    } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
      assetOrientation = .up
    } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
      assetOrientation = .down
    }
    return (assetOrientation, isPortrait)
  }
  
  func videoCompositionInstructionForTrack(_ track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
    let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    let assetTrack = asset.tracks(withMediaType: AVMediaTypeVideo)[0]
    
    let transform = assetTrack.preferredTransform
    let assetInfo = orientationFromTransform(transform)
    
    var scaleToFitRatio = UIScreen.main.bounds.width / assetTrack.naturalSize.width
    if assetInfo.isPortrait {
      scaleToFitRatio = UIScreen.main.bounds.width / assetTrack.naturalSize.height
      let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
      instruction.setTransform(assetTrack.preferredTransform.concatenating(scaleFactor),
                               at: kCMTimeZero)
    } else {
      let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
      var concat = assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(CGAffineTransform(translationX: 0, y: UIScreen.main.bounds.width / 2))
      if assetInfo.orientation == .down {
        let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(M_PI))
        let windowBounds = UIScreen.main.bounds
        let yFix = assetTrack.naturalSize.height + windowBounds.height
        let centerFix = CGAffineTransform(translationX: assetTrack.naturalSize.width, y: yFix)
        concat = fixUpsideDown.concatenating(centerFix).concatenating(scaleFactor)
      }
      instruction.setTransform(concat, at: kCMTimeZero)
    }
    
    return instruction
  }
  
  
  @IBAction func merge(_ sender: AnyObject) {
    if let firstAsset = firstAsset, let secondAsset = secondAsset {
      activityMonitor.startAnimating()
      
      // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
      let mixComposition = AVMutableComposition()
      
      // 2 - Create two video tracks
      let firstTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
      do {
        try firstTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, firstAsset.duration), of: firstAsset.tracks(withMediaType: AVMediaTypeVideo)[0], at: kCMTimeZero)
      } catch _ {
        print("Failed to load first track")
      }
      
      let secondTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
      do {
        try secondTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, secondAsset.duration), of: secondAsset.tracks(withMediaType: AVMediaTypeVideo)[0], at: firstAsset.duration)
      } catch _ {
        print("Failed to load second track")
      }
      
      // 2.1
      let mainInstruction = AVMutableVideoCompositionInstruction()
      mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, secondAsset.duration))
      
      // 2.2
      let firstInstruction = videoCompositionInstructionForTrack(firstTrack, asset: firstAsset)
      firstInstruction.setOpacity(0.0, at: firstAsset.duration)
      let secondInstruction = videoCompositionInstructionForTrack(secondTrack, asset: secondAsset)
      
      // 2.3
      mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
      let mainComposition = AVMutableVideoComposition()
      mainComposition.instructions = [mainInstruction]
      mainComposition.frameDuration = CMTimeMake(1, 30)
      mainComposition.renderSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
      
      // 3 - Audio track
      if let loadedAudioAsset = audioAsset {
        let audioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: 0)
        do {
          try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, secondAsset.duration)),
                                         of: loadedAudioAsset.tracks(withMediaType: AVMediaTypeAudio)[0] ,
                                         at: kCMTimeZero)
        } catch _ {
          print("Failed to load Audio track")
        }
      }
      
      // 4 - Get path
      let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .long
      dateFormatter.timeStyle = .short
      let date = dateFormatter.string(from: Date())
      let savePath = (documentDirectory as NSString).appendingPathComponent("mergeVideo-\(date).mov")
      let url = URL(fileURLWithPath: savePath)
      
      // 5 - Create Exporter
      guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
      exporter.outputURL = url
      exporter.outputFileType = AVFileTypeQuickTimeMovie
      exporter.shouldOptimizeForNetworkUse = true
      exporter.videoComposition = mainComposition
      
      // 6 - Perform the Export
      exporter.exportAsynchronously() {
        DispatchQueue.main.async { _ in
          self.exportDidFinish(exporter)
        }
      }
    }
  }
  
}

extension MergeVideoViewController: UIImagePickerControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    let mediaType = info[UIImagePickerControllerMediaType] as! NSString
    dismiss(animated: true, completion: nil)
    
    if mediaType == kUTTypeMovie {
      let avAsset = AVAsset(url:info[UIImagePickerControllerMediaURL] as! URL)
      var message = ""
      if loadingAssetOne {
        message = "Video one loaded"
        firstAsset = avAsset
      } else {
        message = "Video two loaded"
        secondAsset = avAsset
      }
      let alert = UIAlertController(title: "Asset Loaded", message: message, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
      present(alert, animated: true, completion: nil)
    }
  }
  
}

extension MergeVideoViewController: UINavigationControllerDelegate {
  
}

extension MergeVideoViewController: MPMediaPickerControllerDelegate {
  func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
    let selectedSongs = mediaItemCollection.items
    if selectedSongs.count > 0 {
      let song = selectedSongs[0]
      if let url = song.value(forProperty: MPMediaItemPropertyAssetURL) as? URL {
        audioAsset = (AVAsset(url:url) )
        dismiss(animated: true, completion: nil)
        let alert = UIAlertController(title: "Asset Loaded", message: "Audio Loaded", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler:nil))
        present(alert, animated: true, completion: nil)
      } else {
        dismiss(animated: true, completion: nil)
        let alert = UIAlertController(title: "Asset Not Available", message: "Audio Not Loaded", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler:nil))
        present(alert, animated: true, completion: nil)
      }
    } else {
      dismiss(animated: true, completion: nil)
    }
  }
  
  func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
    dismiss(animated: true, completion: nil)
  }
}
