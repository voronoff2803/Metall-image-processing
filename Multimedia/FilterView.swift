//
//  Filter.swift
//  Multimedia
//
//  Created by Alexey Voronov on 14/04/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import UIKit
import MetalKit
import Metal

class FilterView: UIView {
    var metalView:UIImageView!=nil
    var histogram: [UInt32] = [UInt32](repeating: 0, count: 256)
    private let histogramView = UIView()
    var info: String = ""
    
    var parametrs = ["input 1", "input 2", "input 3"]
    var slider: UISlider = UISlider()
    var value: Float = 0.5
    var value2: Float = 0.5
    var value3: Float = 0.5
    var parentFilter: FilterView?
    var parentFilter2: FilterView?
    var parentFilter3: FilterView?
    var parentFilter4: FilterView?
    private var pixelsCount: Int = 0
    var kernelName: String! = "kernel_task3"
    private var valueUniform:MTLBuffer!=nil
    private var value2Uniform:MTLBuffer!=nil
    private var value3Uniform:MTLBuffer!=nil
    var inImageTexture:MTLTexture!=nil
    var inImageTexture2:MTLTexture!=nil
    var inImageTexture3:MTLTexture!=nil
    var outImageTexture:MTLTexture!=nil
    private var library:MTLLibrary!=nil
    private let device:MTLDevice! = MTLCreateSystemDefaultDevice()
    private var commandQueue:MTLCommandQueue!=nil
    private var pipeline:MTLComputePipelineState!=nil
    private let threadGroupCount = MTLSizeMake(16, 16, 1)
    private var threadGroups:MTLSize?
    private var histogramUniform:MTLBuffer!=nil
    
    init(frame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100), image: UIImage, kernelName: String) {
        super.init(frame: frame)
        self.loadUIImage(uiimage: image)
        self.kernelName = kernelName
    }
    
    init(frame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100), parentFilter: FilterView, kernelName: String) {
        super.init(frame: frame)
        self.parentFilter = parentFilter
        self.kernelName = kernelName

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        setup()
    }
    
    func loadUIImage(uiimage: UIImage) {
        let textureLoader = MTKTextureLoader(device: self.device!)
        let kciOptions = [MTKTextureLoader.Option.SRGB: true,
                          MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft] as [MTKTextureLoader.Option : Any]
        let imageTexture = try! textureLoader.newTexture(cgImage: uiimage.cgImage!, options: kciOptions)
        inImageTexture = imageTexture
    }
    
    func getUIImage() -> UIImage {
        return outImageTexture.uiImage()
    }
    
    
    func processImage() {
        print("in process: \(self.kernelName)")
        reloadInputTextures()
        threadGroups = MTLSizeMake(
                (inImageTexture.width+threadGroupCount.width)/threadGroupCount.width - 1,
                (inImageTexture.height+threadGroupCount.height)/threadGroupCount.height - 1, 1)
        pixelsCount = (threadGroups!.width * threadGroups!.height * threadGroupCount.width * threadGroupCount.height)
        
        if inImageTexture != nil{
            memcpy(self.valueUniform.contents(), &self.value, MemoryLayout<Float>.size)
            memcpy(self.value2Uniform.contents(), &self.value2, MemoryLayout<Float>.size)
            memcpy(self.value3Uniform.contents(), &self.value3, MemoryLayout<Float>.size)
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            
            let blitEncoder = commandBuffer!.makeBlitCommandEncoder()
            setupBlitEncoder(blitEncoder: blitEncoder!)
            blitEncoder!.endEncoding()
            
            let encoder = commandBuffer!.makeComputeCommandEncoder()
            setupEncoder(encoder: encoder!)
            encoder!.dispatchThreadgroups(threadGroups!, threadsPerThreadgroup: threadGroupCount)
            encoder!.endEncoding()
            
            commandBuffer!.commit()
            commandBuffer!.waitUntilCompleted()

            self.metalView.image = self.getUIImage()
            
            memcpy(&self.histogram, self.histogramUniform.contents(), MemoryLayout<UInt32>.size * 256)
            
            drawGraph(data: histogram)
        }
    }
    
    func setupBlitEncoder(blitEncoder: MTLBlitCommandEncoder) {
        blitEncoder.__fill(histogramUniform, range: NSMakeRange(0, MemoryLayout<UInt32>.size * 256), value: 0)
    }
    
    func setupEncoder(encoder: MTLComputeCommandEncoder) {
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(inImageTexture, index: 0)
        encoder.setTexture(inImageTexture2, index: 1)
        encoder.setTexture(inImageTexture3, index: 3)
        encoder.setTexture(outImageTexture, index: 2)
        encoder.setBuffer(self.valueUniform, offset: 0, index: 0)
        encoder.setBuffer(self.value2Uniform, offset: 0, index: 1)
        encoder.setBuffer(self.value3Uniform, offset: 0, index: 3)
        encoder.setBuffer(self.histogramUniform, offset: 0, index: 2)
    }
    
    func setup() {
        reloadInputTextures()
        self.subviews.forEach({$0.removeFromSuperview()})
        histogramView.frame = CGRect(x: 0, y: frame.height - 50, width: frame.width, height: 50)
        histogramView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        histogramView.layer.masksToBounds = true
        let textureDesc = MTLTextureDescriptor()
        textureDesc.textureType = .type2D
        textureDesc.pixelFormat = .rgba8Unorm
        textureDesc.width = inImageTexture.width
        textureDesc.height = inImageTexture.height
        textureDesc.usage = [ .shaderRead, .shaderWrite ]
        
        outImageTexture = device.makeTexture(descriptor: textureDesc)
        histogramUniform = self.device.makeBuffer(length: MemoryLayout<UInt32>.size * 256, options: [])
        valueUniform = self.device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        value2Uniform = self.device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        value3Uniform = self.device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        
        commandQueue = device.makeCommandQueue()
        library = self.device.makeDefaultLibrary()
        
        let function:MTLFunction! = library.makeFunction(name: kernelName)
        pipeline = try! self.device.makeComputePipelineState(function: function)
        
        metalView = UIImageView(frame: self.bounds)
        metalView.contentMode = .scaleAspectFill
        self.addSubview(metalView)
        
        addSubview(histogramView)
        setupLabel()
        setupSlider()
    }
    
    func setupSlider() {
        slider = UISlider(frame: CGRect(x: frame.width - 110, y: frame.height / 2 - 40, width: 180, height: 40))
        slider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2))
        slider.maximumValue = 1.0
        slider.minimumValue = 0.01
        slider.tintColor = .gray
        slider.value = value
        slider.alpha = 0.63
        slider.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        addSubview(slider)
    }
    
    @objc func  valueChanged() {
        value = slider.value
    }
    
    func drawGraph(data: [UInt32], color: UIColor = UIColor.white) {
        histogramView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        for (index,item) in data.enumerated() {
            if item > 0 {
                let barLayer = CALayer()
                let value = (CGFloat(item) / CGFloat(pixelsCount / 20)) * histogramView.frame.height
                barLayer.frame = CGRect(x: CGFloat(index) * histogramView.frame.width / CGFloat(data.count), y: histogramView.frame.height - value, width: histogramView.frame.width / CGFloat(data.count), height: value)
                barLayer.backgroundColor = color.cgColor
                histogramView.layer.addSublayer(barLayer)
            }
        }
    }
    
    func reloadInputTextures() {
        if parentFilter != nil {
            inImageTexture = parentFilter?.outImageTexture
        }
        if parentFilter2 != nil {
            inImageTexture2 = parentFilter2?.outImageTexture
        }
        if parentFilter3 != nil {
            inImageTexture3 = parentFilter3?.outImageTexture
        }
    }
    
    func setupLabel() {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: 33))
        label.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        label.numberOfLines = 2
        label.font = label.font.withSize(13)
        label.text = "  " + kernelName + " | " + info
        label.textColor = .white
        label.shadowColor = .black
        label.shadowOffset = CGSize(width: -1, height:  1)
        self.addSubview(label)
    }
}
