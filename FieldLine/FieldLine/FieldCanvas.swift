import SwiftUI
struct FieldCanvas: View {
    let geometry: FieldGeometry
    var selected: Segment?
    var position: Point?
    var positionAccuracy: Double?
    var positionIsStale = false
    var markedCorners: Set<String> = []
    var inferredCorners: Set<String> = []
    var directionMarker: Point?
    var body: some View {
        Canvas { context, size in
            let inset = 26.0
            let scale = min((size.width-inset*2)/geometry.spec.width, (size.height-inset*2)/geometry.spec.length)
            let origin = CGPoint(x: (size.width-geometry.spec.width*scale)/2, y: (size.height-geometry.spec.length*scale)/2)
            func screen(_ p: Point) -> CGPoint { .init(x: origin.x+p.x*scale, y: origin.y+p.y*scale) }
            let rect = CGRect(x: origin.x, y: origin.y, width: geometry.spec.width*scale, height: geometry.spec.length*scale)
            context.fill(Path(roundedRect: rect.insetBy(dx: -12, dy: -12), cornerRadius: 18), with: .color(Color(red: 0.06, green: 0.24, blue: 0.2)))
            for segment in geometry.segments {
                var path = Path(); path.move(to: screen(geometry.point(segment.from))); path.addLine(to: screen(geometry.point(segment.to)))
                let isBuildOut = segment.id.hasPrefix("BOL-")
                context.stroke(path, with: .color(segment.id == selected?.id ? .yellow : .white.opacity(0.8)),
                               style: StrokeStyle(lineWidth: segment.id == selected?.id ? 4 : 1.5,
                                                  dash: isBuildOut ? [6, 4] : []))
                if isBuildOut {
                    let midpoint = screen(geometry.point(segment.from))
                    context.draw(Text("回撤线").font(.system(size: 10, weight: .semibold)).foregroundColor(.white),
                                 at: CGPoint(x: size.width / 2, y: midpoint.y - 12))
                }
            }
            for circle in geometry.circles {
                var path = Path()
                path.addArc(center: screen(circle.center), radius: circle.radius*scale, startAngle: .degrees(circle.startAngle), endAngle: .degrees(circle.endAngle), clockwise: false)
                context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
            }
            for node in geometry.nodes {
                let p = screen(node.point)
                context.fill(Path(ellipseIn: CGRect(x: p.x-2, y: p.y-2, width: 4, height: 4)), with: .color(.white))
                if ["A", "B", "C", "D"].contains(node.id) {
                    let label = CGPoint(x: p.x + (node.point.x == 0 ? -13 : 13), y: p.y)
                    context.draw(Text(node.id).font(.system(size: 15, weight: .bold)).foregroundColor(.primary), at: label)
                }
            }
            for corner in ["A", "B", "C", "D"] where markedCorners.contains(corner) {
                let p = screen(geometry.point(corner))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20)),
                             with: .color(.teal))
                context.draw(Text("✓").font(.system(size: 13, weight: .heavy)).foregroundColor(.white), at: p)
            }
            for corner in ["A", "B", "C", "D"] where inferredCorners.contains(corner) {
                let p = screen(geometry.point(corner))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)),
                             with: .color(Color(red: 0.06, green: 0.24, blue: 0.2)))
                context.stroke(Path(ellipseIn: CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20)),
                               with: .color(.orange), lineWidth: 2.5)
                context.draw(Text("推").font(.system(size: 11, weight: .heavy)).foregroundColor(.orange), at: p)
            }
            if let directionMarker {
                let p = screen(directionMarker)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)),
                             with: .color(.orange))
                context.draw(Text("方向点").font(.system(size: 10, weight: .bold)).foregroundColor(.orange),
                             at: CGPoint(x: p.x + 10, y: p.y - 12), anchor: .leading)
            }
            if let position {
                let p = screen(position)
                let color: Color = positionIsStale || (positionAccuracy ?? 0) > NavigationThresholds.weakAccuracy ? .orange : .cyan
                context.fill(Path(ellipseIn: CGRect(x: p.x-11, y: p.y-11, width: 22, height: 22)), with: .color(color.opacity(0.25)))
                context.fill(Path(ellipseIn: CGRect(x: p.x-6, y: p.y-6, width: 12, height: 12)), with: .color(color))
                context.draw(Text(positionIsStale ? "上次位置" : "你").font(.system(size: 12, weight: .bold)).foregroundColor(color),
                             at: CGPoint(x: p.x + 14, y: p.y - 15), anchor: .leading)
            }
        }
        .accessibilityLabel("足球场俯视图，\(geometry.spec.length.formatted()) 米长，\(geometry.spec.width.formatted()) 米宽；A 左上、B 右上、C 右下、D 左下")
    }
}
