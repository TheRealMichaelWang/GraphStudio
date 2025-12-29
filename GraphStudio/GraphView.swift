//
//  GraphView.swift
//  GraphStudio
//
//  Created by Michael Wang on 12/22/25.
//

import SwiftUI
import SceneKit

struct CameraState {
    var distance: Float = 10
    var yaw: Float = 0        // left-right rotation around Y
    var pitch: Float = -Float.pi/6 // up-down rotation around X
}

struct Graph3DSceneView: UIViewRepresentable {
    @Binding var camera: CameraState
    @Binding var items: [GraphItem]
    
    class Coordinator {
        let surfacesContainer = SCNNode()
        var cameraNode: SCNNode?
        var surfacesByID: [UUID: SCNNode] = [:]
    }
    
    private func makeAxisNode(direction: SCNVector3, length: CGFloat, color: UIColor, radius: CGFloat = 0.02) -> SCNNode {
        let cyl = SCNCylinder(radius: radius, height: length)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .physicallyBased
        cyl.materials = [mat]
        let node = SCNNode(geometry: cyl)
        // Center cylinder so that it spans from -length/2 to +length/2 along its local Y
        node.position = SCNVector3(0, 0, 0)
        // Rotate cylinder's local Y axis to match the desired world direction
        // direction should be unit along one axis: X(1,0,0), Y(0,1,0), Z(0,0,1)
        if direction.x == 1 && direction.y == 0 && direction.z == 0 {
            // rotate from Y to X: -Z 90°
            node.eulerAngles = SCNVector3(0, 0, Float.pi/2)
        } else if direction.x == 0 && direction.y == 0 && direction.z == 1 {
            // rotate from Y to Z: X 90°
            node.eulerAngles = SCNVector3(Float.pi/2, 0, 0)
        } else {
            // Y axis needs no rotation
            node.eulerAngles = SCNVector3Zero
        }
        return node
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.isPlaying = true
        
        //camera
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.usesOrthographicProjection = false
        cameraNode.position = SCNVector3(0, 0, 10)
        scene.rootNode.addChildNode(cameraNode)
        context.coordinator.cameraNode = cameraNode
        applyCameraTransform(to: cameraNode, state: camera)
        
        //ambient light
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.intensity = 200
        scene.rootNode.addChildNode(ambientNode)
        
        // directional light
        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.eulerAngles = SCNVector3(-Float.pi/3, Float.pi/4, 0)
        directional.light?.intensity = 800
        scene.rootNode.addChildNode(directional)
        
        scene.rootNode.addChildNode(context.coordinator.surfacesContainer)
        
        let axesContainer = SCNNode()
        let axisLength: CGFloat = 50
        let xAxis = makeAxisNode(direction: SCNVector3(1,0,0), length: axisLength, color: .systemRed)
        let yAxis = makeAxisNode(direction: SCNVector3(0,0,1), length: axisLength, color: .systemGreen)
        let zAxis = makeAxisNode(direction: SCNVector3(0,1,0), length: axisLength, color: .systemBlue)
        axesContainer.addChildNode(xAxis)
        axesContainer.addChildNode(yAxis)
        axesContainer.addChildNode(zAxis)
        scene.rootNode.addChildNode(axesContainer)
        
        return view
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        if let cameraNode = context.coordinator.cameraNode {
            applyCameraTransform(to: cameraNode, state: camera)
        }
        
        // Sync surfaces with items
        let currentIDs = Set(items.map { $0.id })
        // Remove missing
        for (id, node) in context.coordinator.surfacesByID where !currentIDs.contains(id) {
            node.removeFromParentNode()
            context.coordinator.surfacesByID.removeValue(forKey: id)
        }
    
        //update/re-render edited
        for var item in items where item.hasEdited
        {
            guard let node = context.coordinator.surfacesByID[item.id] else { continue }
            
            node.removeFromParentNode()
            context.coordinator.surfacesByID.removeValue(forKey: item.id)
            
            let uiColor: UIColor
            #if canImport(UIKit)
            uiColor = UIColor(item.color)
            #else
            uiColor = .systemTeal
            #endif
            
            let editedNode = SurfaceBuilder.makeSurfaceNode(
                evaluator: item.evaluator,
                xRange: -5...5,
                yRange: -5...5,
                xCount: 80,
                yCount: 80,
                color: uiColor
            )
            context.coordinator.surfacesContainer.addChildNode(editedNode)
            context.coordinator.surfacesByID[item.id] = editedNode
            
            item.hasEdited = false
        }
        
        // Add new
        for item in items where context.coordinator.surfacesByID[item.id] == nil {
            let uiColor: UIColor
            #if canImport(UIKit)
            uiColor = UIColor(item.color)
            #else
            uiColor = .systemTeal
            #endif
            let node = SurfaceBuilder.makeSurfaceNode(
                evaluator: item.evaluator,
                xRange: -5...5,
                yRange: -5...5,
                xCount: 80,
                yCount: 80,
                color: uiColor
            )
            context.coordinator.surfacesContainer.addChildNode(node)
            context.coordinator.surfacesByID[item.id] = node
        }
    }
    
    private func applyCameraTransform(to node: SCNNode, state: CameraState) {
        // Position the camera on a sphere around origin
        let r = state.distance
        let x = r * sinf(state.pitch) * cosf(state.yaw)
        let y = r * sinf(state.pitch) * sinf(state.yaw)
        let z = r * cosf(state.pitch)
        node.position = SCNVector3(x, z, y)

        // Look at origin
        //node.look(at: SCNVector3(0, 0, 0))
        node.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        //node.camera?.fieldOfView = 50
    }
}

struct GraphView: View {
    @Binding var items: [GraphItem]
    @State var camera: CameraState = CameraState()
    
    @State private var dragStartYaw: Float = 0
    @State private var dragStartPitch: Float = 0
    @State private var hasActiveDrag: Bool = false
        
    var body: some View {
        Graph3DSceneView(camera: $camera, items: $items)
            .ignoresSafeArea()
            .gesture(dragGesture)
            .gesture(pinchGesture)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Capture starting values on first change
                if !hasActiveDrag {
                    hasActiveDrag = true
                    dragStartYaw = camera.yaw
                    dragStartPitch = camera.pitch
                }

                // Tuned sensitivities for non-compounding updates
                let yawSensitivity: Float = 0.002
                let pitchSensitivity: Float = 0.0028

                let newYaw = dragStartYaw + Float(value.translation.width) * yawSensitivity
                var newPitch = dragStartPitch + Float(value.translation.height) * pitchSensitivity

                // Clamp pitch away from the poles so yaw remains effective
                let minPitch: Float = -Float.pi + 0.15
                let maxPitch: Float = -0.15
                newPitch = max(minPitch, min(maxPitch, newPitch))

                camera.yaw = newYaw
                camera.pitch = newPitch
            }
            .onEnded { _ in
                hasActiveDrag = false
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                // scale is relative; map to distance smoothly
                let minDist: Float = 2
                let maxDist: Float = 100
                // interpret scale around 1.0; clamp
                let newDist = camera.distance / Float(scale)
                camera.distance = max(minDist, min(maxDist, newDist))
            }
    }
}

#Preview {
    GraphView(items: .constant([]))
}

