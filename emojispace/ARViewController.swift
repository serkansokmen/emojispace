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


enum ARDrawingMode: String {
    case text = "text"
    case image = "image"
}


struct ARViewModel {
    var selectedText: String?
    var drawingMode: ARDrawingMode
}

//protocol ARViewDrawingModeDelegate {
//    func didChange(to mode: ARDrawingMode)
//}

class ARViewController: UIViewController {

    private var previewView: UIView!

    private var viewModel: ARViewModel = {
        return ARViewModel(
            selectedText: "",
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

    private lazy var arScene: ARScene = {
        guard let scene = SKScene(fileNamed: "ARScene") as? ARScene else {
            fatalError("Scene named `ARScene` not found!")
        }
        return scene
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(sceneView)
        constrain(sceneView) {
            $0.edges == $0.superview!.edges
        }
        sceneView.presentScene(self.arScene)

        view.addSubview(emojiTextField)
        emojiTextField.isHidden = self.viewModel.drawingMode == .text
        constrain(emojiTextField) {
            $0.top == $0.superview!.topMargin
            $0.left == $0.superview!.leftMargin
            $0.right == $0.superview!.rightMargin
            $0.height == 50
        }

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: String.fontAwesomeIcon(name: .videoCamera), style: .plain, target: self, action: #selector(startRecording)),
            UIBarButtonItem(title: String.fontAwesomeIcon(name: .font), style: .plain, target: self, action: #selector(handleTextModeSelected)),
            UIBarButtonItem(title: String.fontAwesomeIcon(name: .pictureO), style: .plain, target: self, action: #selector(handleImageModeSelected)),
        ]
        let attributes = [NSAttributedStringKey.font: UIFont.fontAwesome(ofSize: 20)]
        for buttonItem in navigationItem.rightBarButtonItems! {
            buttonItem.setTitleTextAttributes(attributes, for: .normal)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)


        // Create a session configuration
        let configuration = ARWorldTrackingSessionConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)

        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardClose),
                                               name: Notification.Name.UIKeyboardWillHide,
                                               object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}

extension ARViewController: ARSKViewDelegate {
    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
        // Create and configure a node for the anchor added to the view's session.
        let labelNode = SKLabelNode(text: self.viewModel.selectedText)
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = .center
        return labelNode;
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

    @objc func handleImageModeSelected(_ sender: UIBarButtonItem) {
        self.viewModel.drawingMode = .image
        self.emojiTextField.isHidden = true
    }

    @objc func handleTextModeSelected(_ sender: UIBarButtonItem) {
        self.viewModel.drawingMode = .text
        self.emojiTextField.isHidden = !self.emojiTextField.isHidden
    }

    @objc func handleKeyboardClose(_ notification: Notification) {
        //        print(notification)
        self.emojiTextField.isHidden = true
    }
}

extension ARViewController: RPPreviewViewControllerDelegate {

    @objc func startRecording() {
        let recorder = RPScreenRecorder.shared()
        recorder.startRecording{ [unowned self] (error) in
            if let unwrappedError = error {
                print(unwrappedError.localizedDescription)
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: String.fontAwesomeIcon(name: .stopCircle),
                                                                         style: .plain,
                                                                         target: self,
                                                                         action: #selector(self.stopRecording))
            }
        }
    }

    @objc func stopRecording() {
        let recorder = RPScreenRecorder.shared()
        recorder.stopRecording { [unowned self] (preview, error) in
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: String.fontAwesomeIcon(name: .videoCamera),
                                                                     style: .plain,
                                                                     target: self,
                                                                     action: #selector(self.startRecording))

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
