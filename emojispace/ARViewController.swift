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
import FontAwesome_swift
import ChameleonFramework
import Hero
import Hokusai


enum ARDrawingMode: String {
    case text = "text"
    case image = "image"
}


struct ARViewModel {
    var selectedText: String?
    var selectedImage: UIImage?
    var drawingMode: ARDrawingMode
}

//protocol ARViewDrawingModeDelegate {
//    func didChange(to mode: ARDrawingMode)
//}

class ARViewController: UIViewController {

    private var previewView: UIView!

    private var imagePreview: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var imageGallery: UIImagePickerController = {
        let gallery = UIImagePickerController()
        gallery.delegate = self
        gallery.sourceType = .photoLibrary
        gallery.allowsEditing = true
        return gallery
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
        textField.heroID = "textField"
        return textField
    }()

    init(_ initialText: String) {
        self.viewModel.selectedText = initialText
        super.init(nibName: nil, bundle: nil)
    }

    init(with drawingMode: ARDrawingMode) {
        self.viewModel.drawingMode = drawingMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var arSceneKitScene: ESARSceneKitScene = {
        guard let scene = SKScene(fileNamed: "ESARSceneKitScene") as? ESARSceneKitScene else {
            fatalError("Scene named `ESARSceneKitScene` not found!")
        }
        return scene
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(sceneView)
        constrain(sceneView) {
            $0.edges == $0.superview!.edges
        }
        sceneView.presentScene(self.arSceneKitScene)

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
            UIBarButtonItem(title: String.fontAwesomeIcon(name: .sliders), style: .plain, target: self, action: #selector(showOptionSelector))
        let attributes = [NSAttributedStringKey.font: UIFont.fontAwesome(ofSize: 25)]
        for buttonItem in navigationItem.rightBarButtonItems! {
            buttonItem.setTitleTextAttributes(attributes, for: .normal)
        }

        sceneView.session.run(ARWorldTrackingSessionConfiguration())
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

        if let touchLocation = touches.first?.location(in: sceneView) {

            // Create a transform with a translation of 0.4 meters in front of the camera
            // Add to plane
            if let hit = sceneView.hitTest(touchLocation, types: .featurePoint).first {
                let translation = matrix_identity_float4x4
                let transform = simd_mul(hit.worldTransform, translation)
                DispatchQueue.main.async {
                    self.sceneView.session.add(anchor: ARAnchor(transform: transform))
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    @objc func showOptionSelector(_ sender: UIBarButtonItem) {
        let alert = Hokusai()
        _ = alert.addButton("Record Video") {
            self.startRecording()
        }
        _ = alert.addButton("Enter Text") {
            self.handleTextModeSelected()
        }
        _ = alert.addButton("Select Image") {
            self.handleImageModeSelected()
        }
        _ = alert.addButton("Reset Session") {
            self.handleRefreshSelected()
        }
        alert.colorScheme = .karasu
        alert.show()
        alert.cancelButtonTitle = "Cancel"
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
        // Create and configure a node for the anchor added to the view's session.
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

    @objc func handleImageModeSelected() {
        self.viewModel.drawingMode = .image
        self.emojiTextField.isHidden = true

        present(imageGallery, animated: true, completion: nil)
    }

    @objc func handleRefreshSelected() {
        sceneView.session.pause()
        sceneView.session.run(ARWorldTrackingSessionConfiguration())
    }

    @objc func handleTextModeSelected() {
        self.viewModel.drawingMode = .text
        self.emojiTextField.isHidden = !self.emojiTextField.isHidden
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
