import SwiftUI
import Charts

struct RadarChartData: Identifiable {
    let id = UUID()
    let category: String
    let value: Double // 0.0 to 1.0
}

struct RadarChartView: View {
    let data: [String: [RadarChartData]] // Model Name -> Data Points
    let axes: [String]
    let colors: [String: Color]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Grid
                RadarGrid(categories: axes, steps: 4)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                
                // Data Polygons
                ForEach(Array(data.keys), id: \.self) { model in
                    if let points = data[model] {
                        RadarPolygon(
                            data: points,
                            axes: axes,
                            radius: min(geometry.size.width, geometry.size.height) / 2
                        )
                        .fill(colors[model, default: .blue].opacity(0.3))
                        .stroke(colors[model, default: .blue], lineWidth: 2)
                    }
                }
            }
            .frame(width: min(geometry.size.width, geometry.size.height),
                   height: min(geometry.size.width, geometry.size.height))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

// MARK: - Shapes

struct RadarGrid: Shape {
    let categories: [String]
    let steps: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angleStep = 2 * .pi / Double(categories.count)
        
        // Concentric polygons
        for i in 1...steps {
            let currentRadius = radius * Double(i) / Double(steps)
            for j in 0..<categories.count {
                let angle = Double(j) * angleStep - .pi / 2
                let point = CGPoint(
                    x: center.x + CGFloat(cos(angle) * currentRadius),
                    y: center.y + CGFloat(sin(angle) * currentRadius)
                )
                if j == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
        
        // Spokes
        for j in 0..<categories.count {
            let angle = Double(j) * angleStep - .pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(Foundation.cos(angle) * Double(radius)),
                y: center.y + CGFloat(Foundation.sin(angle) * Double(radius))
            )
            path.move(to: center)
            path.addLine(to: point)
        }
        
        return path
    }
}

struct RadarPolygon: Shape {
    let data: [RadarChartData]
    let axes: [String]
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let angleStep = 2 * .pi / Double(axes.count)
        
        for (i, axis) in axes.enumerated() {
            let value = data.first(where: { $0.category == axis })?.value ?? 0
            let angle = Double(i) * angleStep - .pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle) * value * Double(radius)),
                y: center.y + CGFloat(sin(angle) * value * Double(radius))
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
