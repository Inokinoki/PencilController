//
//  ViewController.swift
//  PencilController
//
//  Created by Simon Gladman on 21/11/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//  Modified by inoki on 1/22/22.
//

import UIKit
import SceneKit

class ViewController: UIViewController
{
    let label = UILabel()
    
    let halfPi = CGFloat(M_PI_2)
    let pi = CGFloat(M_PI)
    
    let ciContext = CIContext(eaglContext: EAGLContext(api: EAGLRenderingAPI.openGLES2)!,
        options: [CIContextOption.workingColorSpace: NSNull()])

    let coreImage = CIImage(image: UIImage(named: "DSCF0786.jpg")!)!
    
    let imageView = UIImageView()
    
    let sceneKitView = SCNView()
    let scene = SCNScene()
    let cylinderNode = SCNNode(geometry: SCNCapsule(capRadius: 0.05, height: 1))
    let plane = SCNNode(geometry: SCNPlane(width: 20, height: 20))
    
    let hueAdjust = CIFilter(name: "CIHueAdjust")!
    let colorControls = CIFilter(name: "CIColorControls")!
    let gammaAdjust = CIFilter(name: "CIGammaAdjust")!
    let exposureAdjust = CIFilter(name: "CIExposureAdjust")!
    
    let hueSaturationButton = ChunkyButton(title: "Hue\nSaturation", filteringMode: .HueSaturation)
    let brightnessContrastButton = ChunkyButton(title: "Brightness\nContrast", filteringMode: .BrightnessContrast)
    let gammaExposureButton = ChunkyButton(title: "Gamma\nExposure", filteringMode: .GammaExposure)
    
    var hueAngle: CGFloat = 0
    var saturation: CGFloat = 1
    var brightness: CGFloat = 0
    var contrast: CGFloat = 1
    var gamma: CGFloat = 1
    var exposure: CGFloat = 0
    
    var pencilOn = false
    
    var filteringMode = FilteringMode.Off
    {
        didSet
        {
            label.isHidden = filteringMode == .Off
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        
        view.addSubview(imageView)
        view.addSubview(label)
        view.addSubview(sceneKitView)
        
        view.addSubview(hueSaturationButton)
        view.addSubview(brightnessContrastButton)
        view.addSubview(gammaExposureButton)
       
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 36, weight: UIFont.Weight.semibold)
        
        label.textAlignment = NSTextAlignment.center
        label.text = "flexmonkey.blogspot.co.uk"
        label.textColor = UIColor.white
        label.isHidden = true
        
        imageView.contentMode = UIView.ContentMode.center
        
        sceneKitView.scene = scene
        sceneKitView.backgroundColor = UIColor.clear
        addLights()
        
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true

        camera.xFov = 45
        camera.yFov = 45
        
        let cameraNode = SCNNode()
        
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 20)
        
        cylinderNode.position = SCNVector3(0, 0, 0)
        cylinderNode.pivot = SCNMatrix4MakeTranslation(0, 0.5, 0)
        
        plane.opacity = 0.000001
        
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cylinderNode)
        scene.rootNode.addChildNode(plane)
        
        cylinderNode.opacity = 0
        
        applyFilter()
        
        hueSaturationButton.addTarget(self, action: #selector(self.filterButtonTouchDown(_:)), for: UIControl.Event.touchDown)
        hueSaturationButton.addTarget(self, action: #selector(self.filterButtonTouchEnded(_:)), for: UIControl.Event.touchUpInside)
        
        brightnessContrastButton.addTarget(self, action: #selector(self.filterButtonTouchDown(_:)), for: UIControl.Event.touchDown)
        brightnessContrastButton.addTarget(self, action: #selector(self.filterButtonTouchEnded(_:)), for: UIControl.Event.touchUpInside)
        
        gammaExposureButton.addTarget(self, action: #selector(self.filterButtonTouchDown(_:)), for: UIControl.Event.touchDown)
        gammaExposureButton.addTarget(self, action: #selector(self.filterButtonTouchEnded(_:)), for: UIControl.Event.touchUpInside)
    }

    @objc func filterButtonTouchDown(_ button: ChunkyButton)
    {
        filteringMode = button.filteringMode
        
        updateLabel()
        
        if pencilOn
        {
            SCNTransaction.animationDuration = 0.25
            cylinderNode.opacity = 1
        }
    }
    
    @objc func filterButtonTouchEnded(_ button: ChunkyButton)
    {
        filteringMode = .Off
        
        SCNTransaction.animationDuration = 0.25
        cylinderNode.opacity = 0
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        guard let touch = touches.first,
            filteringMode != .Off &&
                touch.type == UITouch.TouchType.stylus else
        {
            return
        }
        pencilOn = true
        
        pencilTouchHandler(touch: touch)

        SCNTransaction.animationDuration = 0.25
        cylinderNode.opacity = 1
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        guard let touch = touches.first,
            filteringMode != .Off &&
                touch.type == UITouch.TouchType.stylus else
        {
            return
        }
        
        pencilTouchHandler(touch: touch)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        guard touches.first?.type == UITouch.TouchType.stylus else
        {
            return
        }
        
        pencilOn = false
        SCNTransaction.animationDuration = 0.25
        cylinderNode.opacity = 0
    }
    
    func pencilTouchHandler(touch: UITouch)
    {
        guard let hitTestResult:SCNHitTestResult = sceneKitView.hitTest(touch.location(in: view), options: nil).filter( { $0.node == plane }).first else
        {
            return
        }
        
        SCNTransaction.animationDuration = 0
        
        cylinderNode.position = SCNVector3(hitTestResult.localCoordinates.x, hitTestResult.localCoordinates.y, 0)
        cylinderNode.eulerAngles = SCNVector3(touch.altitudeAngle, 0.0, 0 - touch.azimuthAngle(in: view) - halfPi)
        
        switch filteringMode
        {
        case .HueSaturation:
            hueAngle = pi + touch.azimuthAngle(in: view)
            saturation = 8 * ((halfPi - touch.altitudeAngle) / halfPi)
            
        case .BrightnessContrast:
            brightness = touch.azimuthUnitVector(in: view).dx * ((halfPi - touch.altitudeAngle) / halfPi)
            contrast = 1 + touch.azimuthUnitVector(in: view).dy * -((halfPi - touch.altitudeAngle) / halfPi)

        case .GammaExposure:
            gamma = 1 + touch.azimuthUnitVector(in: view).dx * ((halfPi - touch.altitudeAngle) / halfPi)
            exposure = touch.azimuthUnitVector(in: view).dy * -((halfPi - touch.altitudeAngle) / halfPi)
            
        case .Off:
            ()
        }
        
        updateLabel()
        applyFilter()
    }


    
    func applyFilter()
    {
        hueAdjust.setValue(coreImage,
            forKey: kCIInputImageKey)
        hueAdjust.setValue(hueAngle,
            forKey: kCIInputAngleKey)
        
        colorControls.setValue(hueAdjust.value(forKey: kCIOutputImageKey) as! CIImage,
            forKey: kCIInputImageKey)
        colorControls.setValue(saturation,
            forKey: kCIInputSaturationKey)
        colorControls.setValue(brightness,
            forKey: kCIInputBrightnessKey)
        colorControls.setValue(contrast,
            forKey: kCIInputContrastKey)
        
        exposureAdjust.setValue(colorControls.value(forKey: kCIOutputImageKey) as! CIImage,
            forKey: kCIInputImageKey)
        exposureAdjust.setValue(exposure,
            forKey: kCIInputEVKey)
        
        gammaAdjust.setValue(exposureAdjust.value(forKey: kCIOutputImageKey) as! CIImage,
            forKey: kCIInputImageKey)
        gammaAdjust.setValue(gamma,
            forKey: "inputPower")

        
        let cgImage = ciContext.createCGImage(gammaAdjust.value(forKey: kCIOutputImageKey) as! CIImage, from: coreImage.extent)
        
        imageView.image =  UIImage(cgImage: cgImage!)
    }
    
    func updateLabel()
    {
        switch filteringMode
        {
        case .HueSaturation:
            label.text = String(format: "↻Hue: %.2f°", hueAngle * 180 / pi) + "      " +  String(format: "∢Saturation: %.2f", saturation)
            
        case .BrightnessContrast:
            label.text = String(format: "⇔Brightness: %.2f", brightness) + "      " +  String(format: "⇕Contrast: %.2f", contrast)

        case .GammaExposure:
            label.text = String(format: "⇔Gamma: %.2f", gamma) + "      " +  String(format: "⇕Exposure: %.2f", exposure)
            
        case .Off:
            ()
        }
    }
    
    func addLights()
    {
        // ambient light...
        
        let ambientLight = SCNLight()
        ambientLight.type = SCNLight.LightType.ambient
        ambientLight.color = UIColor(white: 0.15, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        
        scene.rootNode.addChildNode(ambientLightNode)
        
        // omni light...
        
        let omniLight = SCNLight()
        omniLight.type = SCNLight.LightType.omni
        omniLight.color = UIColor(white: 1.0, alpha: 1.0)
        let omniLightNode = SCNNode()
        omniLightNode.light = omniLight
        omniLightNode.position = SCNVector3(x: -10, y: 10, z: 30)
        
        scene.rootNode.addChildNode(omniLightNode)
    }
    
    override func viewDidLayoutSubviews()
    {
        label.frame = CGRect(x: 0,
            y: topLayoutGuide.length,
            width: view.frame.width,
            height: label.intrinsicContentSize.height)
        
        imageView.frame = view.bounds
        sceneKitView.frame = view.bounds
        
        // Slightly cobbled together layout :)
        
        hueSaturationButton.frame = CGRect(x: 0,
            y: view.frame.height - hueSaturationButton.intrinsicContentSize.height,
            width: hueSaturationButton.intrinsicContentSize.width,
            height: hueSaturationButton.intrinsicContentSize.height)
        
        brightnessContrastButton.frame = CGRect(x: hueSaturationButton.intrinsicContentSize.width + 20,
            y: view.frame.height - hueSaturationButton.intrinsicContentSize.height,
            width: hueSaturationButton.intrinsicContentSize.width,
            height: hueSaturationButton.intrinsicContentSize.height)
        
        gammaExposureButton.frame = CGRect(x: hueSaturationButton.intrinsicContentSize.width + 20 + hueSaturationButton.intrinsicContentSize.width + 20,
            y: view.frame.height - hueSaturationButton.intrinsicContentSize.height,
            width: hueSaturationButton.intrinsicContentSize.width,
            height: hueSaturationButton.intrinsicContentSize.height)
    }

}

enum FilteringMode
{
    case Off
    case HueSaturation
    case BrightnessContrast
    case GammaExposure
}

class ChunkyButton: UIButton
{
    let defaultColor = UIColor(red: 0.25, green: 0.25, blue: 0.75, alpha: 0.5)
    let highlightedColor = UIColor(red: 0.25, green: 0.25, blue: 0.75, alpha: 1)
    
    let filteringMode: FilteringMode
    
    required init(title: String, filteringMode: FilteringMode)
    {
        self.filteringMode = filteringMode
        
        super.init(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 0, height: 0)))
        
        titleLabel?.numberOfLines = 2
        setTitle(title, for: UIControl.State.normal)
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        
        backgroundColor = defaultColor
        setTitleColor(UIColor.white, for: UIControl.State.highlighted)
        setTitleColor(UIColor.lightGray, for: UIControl.State.normal)
        
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 2
        layer.cornerRadius = 5
        
        // self.intrinsicContentSize = CGSize(width: super.intrinsicContentSize.width + 20,
        //    height: super.intrinsicContentSize.height + 10)
    }
    
    override var isHighlighted: Bool
    {
        didSet
        {
            backgroundColor = isHighlighted ? highlightedColor : defaultColor
        }
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    /*
    override func intrinsicContentSize() -> CGSize
    {
        return CGSize(width: super.intrinsicContentSize().width + 20,
            height: super.intrinsicContentSize().height + 10)
    }
     */
}

