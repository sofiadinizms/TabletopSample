/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Simplify math for 2D poses.
*/
import TabletopKit
import Spatial
import RealityKit

extension Double {
   // The linear interpolation of a Double, from one given value to another, by a specified factor.
   static func lerp(lhs: Self, rhs: Self, factor: Self) -> Self {
       lhs + (rhs - lhs) * factor
   }
}

extension TableVisualState.Point2D {
    static func lerp(lhs: Self, rhs: Self, factor: Double) -> Self {
        .init(x: Double.lerp(lhs: lhs.x, rhs: rhs.x, factor: factor),
              y: Double.lerp(lhs: lhs.y, rhs: rhs.y, factor: factor))
    }
}

extension TableVisualState.Pose2D {
    static func lerp(lhs: Self, rhs: Self, factor: Double) -> Self {
        .init(position: TableVisualState.Point2D.lerp(lhs: lhs.position, rhs: rhs.position, factor: factor),
              rotation: Angle2D(radians: Double.lerp(lhs: lhs.rotation.radians, rhs: rhs.rotation.radians, factor: factor)))
    }
}

func transformPoint(pose: TableVisualState.Pose2D, point: SIMD2<Double>) -> SIMD2<Double> {
    let sinTheta = sin(pose.rotation)
    let cosTheta = cos(pose.rotation)
    let rotatedP = simd_double2(x: point.x * cosTheta + point.y * sinTheta,
                                y: point.x * -sinTheta + point.y * cosTheta)
    return rotatedP + pose.position.vector
}

extension TableVisualState.Pose2D {
    static func * (lhs: TableVisualState.Pose2D, rhs: TableVisualState.Pose2D) -> TableVisualState.Pose2D {
        let position = transformPoint(pose: rhs, point: lhs.position.vector)
        let rotation = lhs.rotation + rhs.rotation
        return TableVisualState.Pose2D(position: .init(vector: position), rotation: rotation)
    }
}
