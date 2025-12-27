import Foundation
import SceneKit
import MathParser
import UIKit

struct SurfaceBuilder {
    static func makeSurfaceNode(
        evaluator: Evaluator,
        xRange: ClosedRange<Double>,
        yRange: ClosedRange<Double>,
        xCount: Int,
        yCount: Int,
        color: UIColor
    ) -> SCNNode {
        let clampedXCount = max(2, xCount)
        let clampedYCount = max(2, yCount)

        // Generate sample positions
        var positions: [SCNVector3] = []
        positions.reserveCapacity(clampedXCount * clampedYCount)

        // Precompute grids
        let xStep = (xRange.upperBound - xRange.lowerBound) / Double(clampedXCount - 1)
        let yStep = (yRange.upperBound - yRange.lowerBound) / Double(clampedYCount - 1)

        for j in 0..<clampedYCount {
            let y = yRange.lowerBound + Double(j) * yStep
            for i in 0..<clampedXCount {
                let x = xRange.lowerBound + Double(i) * xStep
                let z = evaluator.eval(variables: { name in
                    switch name.lowercased() {
                    case "x": return x
                    case "y": return y
                    default: return 0
                    }
                })
                positions.append(SCNVector3(Float(x), Float(z), Float(y)))
            }
        }

        // Indices (two triangles per quad)
        var indices: [CInt] = []
        indices.reserveCapacity((clampedXCount - 1) * (clampedYCount - 1) * 6)
        for j in 0..<(clampedYCount - 1) {
            for i in 0..<(clampedXCount - 1) {
                let a = CInt(j * clampedXCount + i)
                let b = CInt(j * clampedXCount + i + 1)
                let c = CInt((j + 1) * clampedXCount + i)
                let d = CInt((j + 1) * clampedXCount + i + 1)
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }

        let vertexSource = SCNGeometrySource(vertices: positions)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<CInt>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<CInt>.size
        )

        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])

        // Basic material
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased
        material.isDoubleSided = true
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        return node
    }
}
