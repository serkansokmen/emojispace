//
//  ViewController.swift
//  emojispace
//
//  Created by Serkan Sokmen on 26/06/2017.
//  Copyright © 2017 Serkan Sokmen. All rights reserved.
//

import UIKit
import SpriteKit
import ARKit
import Cartography
import ReplayKit
import ChameleonFramework
import Vision


enum ARDrawingMode: String {
    case text = "text"
    case image = "image"
    case vision = "vision"
}


struct ARViewModel {
    var selectedText: String?
    var selectedImage: UIImage?
    var drawingMode: ARDrawingMode
}

class ARViewController: UIViewController {

    private var previewView: UIView!
    private var model: VNCoreMLModel
    private var handler: VNSequenceRequestHandler
    private var requests = [VNRequest]()

    private var imagePreview: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var viewModel: ARViewModel = {
        return ARViewModel(
            selectedText: "",
            selectedImage: nil,
            drawingMode: .text
        )
    }()

    private lazy var sceneView: ARSKView = {
        let sceneView = ARSKView(frame: .zero)
        sceneView.delegate = self
        sceneView.showsNodeCount = false
        sceneView.showsFPS = false
        return sceneView
    }()

    private lazy var emojiTextField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.placeholder = "Enter some characters"
        textField.font = UIFont.systemFont(ofSize: 15)
        textField.borderStyle = .roundedRect
        textField.autocorrectionType = .no
        textField.keyboardType = .default
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.contentVerticalAlignment = .center
        textField.backgroundColor = .white
        textField.delegate = self
        return textField
    }()

    init(withModel model: VNCoreMLModel) {

        self.model = model
        self.handler = VNSequenceRequestHandler()

        super.init(nibName: nil, bundle: nil)

        let objectsRequest = VNDetectRectanglesRequest(completionHandler: self.handleDetectedRectangles)
        objectsRequest.minimumSize = 0.1
        objectsRequest.maximumObservations = 20

        self.requests = [objectsRequest]
    }

    private func handleDetectedRectangles(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            let results = request.results as! [VNObservation]
            print(results)
            // draw rectangles
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

//    private lazy var arSceneKitScene: ESARSceneKitScene = {
//        guard let scene = SKScene(fileNamed: "ESARSceneKitScene") as? ESARSceneKitScene else {
//            fatalError("Scene named `ESARSceneKitScene` not found!")
//        }
//        return scene
//    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(sceneView)
        constrain(sceneView) {
            $0.edges == $0.superview!.edges
        }

        let scene = SKScene(size: self.view.frame.size)
        sceneView.presentScene(scene)

        view.addSubview(emojiTextField)
        emojiTextField.isHidden = self.viewModel.drawingMode == .text
        constrain(emojiTextField) {
            $0.top == $0.superview!.topMargin
            $0.left == $0.superview!.leftMargin
            $0.right == $0.superview!.rightMargin
            $0.height == 50
        }

//        view.addSubview(imagePreview)
//        constrain(imagePreview) {
//            $0.top == $0.superview!.top
//            $0.right == $0.superview!.right
//            $0.width == 200
//            $0.height == 200
//        }

        navigationItem.rightBarButtonItem =
            UIBarButtonItem(title: "Options", style: .plain, target: self, action: #selector(showOptionSelector))

        sceneView.session.run(ARWorldTrackingConfiguration())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Run the view's session
//        sceneView.session.run(ARWorldTrackingSessionConfiguration())

        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardClose),
                                               name: Notification.Name.UIKeyboardWillHide,
                                               object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewWillDisappear(animated)

        // Pause the view's session
//        sceneView.session.pause()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        view.endEditing(true)
        super.touchesBegan(touches, with: event)

        if let touchLocation = touches.first?.location(in: sceneView),
            let currentFrame = sceneView.session.currentFrame {

            switch self.viewModel.drawingMode {
            case .vision:

                var translation = matrix_identity_float4x4
                translation.columns.3.z = -0.4
                let transform = simd_mul(currentFrame.camera.transform, translation)

                let classificationRequest = VNCoreMLRequest(model: self.model, completionHandler: { request, error in

                    guard let results = request.results else {
                        print ("No results")
                        return
                    }
                    let result = results.prefix(through: 4)
                        .flatMap { $0 as? VNClassificationObservation }
                        .filter { $0.confidence > 0.3 }
                        .map { $0.identifier }.joined(separator: ", ")
                    // Add a new anchor to the session
                    let anchor = ARAnchor(transform: transform)

                    // Set the identifier
                    guard result != ARBridge.shared.anchorsToIdentifiers[anchor] else {
                        return
                    }

                    DispatchQueue.main.async {
                        self.sceneView.session.add(anchor: anchor)
                        ARBridge.shared.anchorsToIdentifiers[anchor] = result
                    }
                })
                classificationRequest.imageCropAndScaleOption = .centerCrop

                DispatchQueue.global(qos: .background).async {
                    try? self.handler.perform(self.requests + [classificationRequest], on: currentFrame.capturedImage)
                }

            default:
                if let hit = sceneView.hitTest(touchLocation, types: .featurePoint).first {
                    let translation = matrix_identity_float4x4
                    let transform = simd_mul(hit.worldTransform, translation)
                    DispatchQueue.main.async {
                        self.sceneView.session.add(anchor: ARAnchor(transform: transform))
                    }
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    @objc func showOptionSelector(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Options", message: "Please select an option", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Record Video", style: .default, handler: { _ in
            self.startRecording()
        }))
        alert.addAction(UIAlertAction(title: "Use Text Input", style: .default, handler: { _ in
            self.viewModel.drawingMode = .text
            self.emojiTextField.isHidden = false
        }))
        alert.addAction(UIAlertAction(title: "Use Image", style: .default, handler: { _ in
            self.viewModel.drawingMode = .image
            self.emojiTextField.isHidden = true

            let gallery = UIImagePickerController()
            gallery.delegate = self
            gallery.sourceType = .photoLibrary
            gallery.allowsEditing = true

            self.present(gallery, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Use Vision to Recognize", style: .default, handler: { _ in
            self.viewModel.drawingMode = .vision
            self.emojiTextField.isHidden = true
        }))
        alert.addAction(UIAlertAction(title: "Reset Session", style: .default, handler: { _ in
            self.sceneView.session.pause()
            self.sceneView.session.run(ARWorldTrackingConfiguration())
        }))
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ARViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {

        guard let pickedImage = info[UIImagePickerControllerEditedImage] as? UIImage else {
            dismiss(animated: true, completion: nil)
            return
        }

        self.imagePreview.image = resizeImage(image: pickedImage, newWidth: 1600)
        self.viewModel.drawingMode = .image
        self.viewModel.selectedImage = self.imagePreview.image
        dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

}

// MARK: - ARSKViewDelegate
extension ARViewController: ARSKViewDelegate {
    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {

        switch self.viewModel.drawingMode {

        case .image:
            guard let selectedImage = self.viewModel.selectedImage?.copy() as? UIImage else { return nil }
            let node = SKSpriteNode(texture: SKTexture(image: selectedImage),
                                    size: CGSize(width: selectedImage.size.width * 0.02,
                                                 height: selectedImage.size.height * 0.02))
            return node

        case .text:
            let labelNode = SKLabelNode(text: self.viewModel.selectedText)
            labelNode.horizontalAlignmentMode = .center
            labelNode.verticalAlignmentMode = .center
            return labelNode

        case .vision:
            if let identifier = ARBridge.shared.anchorsToIdentifiers[anchor] {
                let labelNode = SKLabelNode(text: identifier)
                labelNode.horizontalAlignmentMode = .center
                labelNode.verticalAlignmentMode = .center
                labelNode.preferredMaxLayoutWidth = 240
                labelNode.numberOfLines = 0
                labelNode.lineBreakMode = .byWordWrapping
                labelNode.fontName = UIFont.boldSystemFont(ofSize: 12).fontName
                return labelNode
            }
            return nil
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user

    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay

    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}

// MARK: - UITextFieldDelegate
extension ARViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text else { return false }
        guard text.characters.count > 0 else { return false }
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.viewModel.selectedText = textField.text
    }
}


// MARK: - Image Related
extension ARViewController {
//    private lazy var sceneView: ARSKView = {
//        let sceneView = ARSKView(frame: .zero)
//        sceneView.delegate = self
//        sceneView.showsNodeCount = false
//        sceneView.showsFPS = false
//        sceneView.backgroundColor = .clear
//
//        return sceneView
//    }()

    override public var prefersStatusBarHidden: Bool {
        return true
    }

    @objc func handleKeyboardClose(_ notification: Notification) {
        //        print(notification)
        self.emojiTextField.isHidden = true
    }

    func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage? {
        let scale = newWidth / image.size.width
        let newHeight = image.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}

// MARK: - RPPreviewViewControllerDelegate
extension ARViewController: RPPreviewViewControllerDelegate {

    @objc func startRecording() {
        let recorder = RPScreenRecorder.shared()
        if recorder.isRecording {
            stopRecording()
        } else {
            recorder.startRecording{ (error) in
                if let unwrappedError = error {
                    print(unwrappedError.localizedDescription)
                }
            }
        }
    }

    @objc func stopRecording() {
        let recorder = RPScreenRecorder.shared()
        recorder.stopRecording { [unowned self] (preview, error) in
            if let unwrappedPreview = preview {
                unwrappedPreview.previewControllerDelegate = self
                self.present(unwrappedPreview, animated: true)
            }
        }
    }

    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        dismiss(animated: true)
    }
}
