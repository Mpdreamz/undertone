import CoreGraphics

/// A rectangle with Apple's continuous corners (the "squircle" macOS windows use), not circular arcs: each corner
/// curves in over about 1.53 times its radius along the edges. The curve is the published construction of iOS 7's
/// rounded rectangle, which matches macOS 26's window corners: measured, a 26-point continuous corner covers a
/// toolbar window's corner where a circle needs 35.5.
public enum ContinuousCorners {
    /// Each corner as three cubic Béziers, in units of the radius, from the top edge round to the left edge of the
    /// top-left corner.
    private static let segments: [(CGPoint, CGPoint, CGPoint)] = [
        (CGPoint(x: 1.08849299, y: 0), CGPoint(x: 0.86840701, y: 0), CGPoint(x: 0.63149399, y: 0.07491100)),
        (
            CGPoint(x: 0.37282401, y: 0.16905001),
            CGPoint(x: 0.16905001, y: 0.37282401),
            CGPoint(x: 0.07491100, y: 0.63149399)
        ),
        (CGPoint(x: 0, y: 0.86840701), CGPoint(x: 0, y: 1.08849299), CGPoint(x: 0, y: 1.52866483)),
    ]
    private static let reach: CGFloat = 1.52866483

    public static func path(_ rect: CGRect, radius: CGFloat) -> CGPath {
        // The corners may not overlap: shrink the radius on a small rectangle.
        let r = max(min(radius, min(rect.width, rect.height) / (2 * reach)), 0)
        let path = CGMutablePath()
        guard r > 0 else {
            path.addRect(rect)
            return path
        }
        // The same corner four times, mirrored into place: (x, y) in corner units measured inwards from the corner.
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
        ]
        // Where each segment starts: the point on the top edge, then each segment's end.
        let starts = [CGPoint(x: reach, y: 0)] + segments.dropLast().map(\.2)
        for (index, (origin, sx, sy)) in corners.enumerated() {
            func point(_ p: CGPoint) -> CGPoint {
                CGPoint(x: origin.x + sx * p.x * r, y: origin.y + sy * p.y * r)
            }
            // Going round, the corners alternate: from the horizontal edge to the vertical one, then the other way.
            if index % 2 == 0 {
                if index == 0 { path.move(to: point(starts[0])) } else { path.addLine(to: point(starts[0])) }
                for (c1, c2, end) in segments {
                    path.addCurve(to: point(end), control1: point(c1), control2: point(c2))
                }
            } else {
                path.addLine(to: point(segments[segments.count - 1].2))
                for i in segments.indices.reversed() {
                    path.addCurve(to: point(starts[i]), control1: point(segments[i].1), control2: point(segments[i].0))
                }
            }
        }
        path.closeSubpath()
        return path
    }
}
