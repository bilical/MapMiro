//
//  ContentView.swift
//  MapMiro
//
//  Created by Bilical on 2025/3/7.
//

import SwiftUI
import MapKit
import Combine

// 导入自定义视图和工具类
// 注意：在实际项目中，这些类应该已经可以被访问，因为它们在同一个模块中
// 但由于我们是分开创建的文件，所以这里直接在同一个文件中引用它们的代码

// 多边形覆盖物视图，用于在地图上绘制多边形
struct PolygonOverlay: View {
    // 多边形的点坐标数组
    var points: [CLLocationCoordinate2D]
    
    // 多边形的填充颜色
    var fillColor: Color = .red.opacity(0.3)
    
    // 多边形的边框颜色
    var strokeColor: Color = .red
    
    // 多边形的边框宽度
    var lineWidth: CGFloat = 2.0
    
    // 地图区域，用于坐标转换
    var region: MKCoordinateRegion
    
    // 地图视图的尺寸，用于坐标转换
    var mapSize: CGSize
    
    var body: some View {
        // 如果点数量不足3个，则不绘制多边形
        if points.count < 3 {
            EmptyView()
        } else {
            // 绘制多边形
            Path { path in
                // 移动到第一个点
                let firstPoint = self.pointForCoordinate(points[0])
                path.move(to: firstPoint)
                
                // 连接其余的点
                for i in 1..<points.count {
                    let point = self.pointForCoordinate(points[i])
                    path.addLine(to: point)
                }
                
                // 闭合路径
                path.closeSubpath()
            }
            .fill(fillColor)
            .overlay(
                Path { path in
                    // 移动到第一个点
                    let firstPoint = self.pointForCoordinate(points[0])
                    path.move(to: firstPoint)
                    
                    // 连接其余的点
                    for i in 1..<points.count {
                        let point = self.pointForCoordinate(points[i])
                        path.addLine(to: point)
                    }
                    
                    // 闭合路径
                    path.closeSubpath()
                }
                .stroke(strokeColor, lineWidth: lineWidth)
            )
        }
    }
    
    // 将地理坐标转换为屏幕坐标
    private func pointForCoordinate(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
        // 计算经纬度与中心点的差值
        let latitudeDelta = region.span.latitudeDelta
        let longitudeDelta = region.span.longitudeDelta
        
        // 计算相对位置（0-1范围内）
        let x = (coordinate.longitude - (region.center.longitude - longitudeDelta / 2)) / longitudeDelta
        let y = 1 - (coordinate.latitude - (region.center.latitude - latitudeDelta / 2)) / latitudeDelta
        
        // 转换为屏幕坐标
        return CGPoint(
            x: x * mapSize.width,
            y: y * mapSize.height
        )
    }
}

// 用于在地图上显示点的视图
struct PointMarker: View {
    // 点的坐标
    var coordinate: CLLocationCoordinate2D
    
    // 点的颜色
    var color: Color = .red
    
    // 点的大小
    var size: CGFloat = 10
    
    // 地图区域，用于坐标转换
    var region: MKCoordinateRegion
    
    // 地图视图的尺寸，用于坐标转换
    var mapSize: CGSize
    
    var body: some View {
        // 将地理坐标转换为屏幕坐标
        let point = pointForCoordinate(coordinate)
        
        // 绘制圆点
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(point)
    }
    
    // 将地理坐标转换为屏幕坐标
    private func pointForCoordinate(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
        // 计算经纬度与中心点的差值
        let latitudeDelta = region.span.latitudeDelta
        let longitudeDelta = region.span.longitudeDelta
        
        // 计算相对位置（0-1范围内）
        let x = (coordinate.longitude - (region.center.longitude - longitudeDelta / 2)) / longitudeDelta
        let y = 1 - (coordinate.latitude - (region.center.latitude - latitudeDelta / 2)) / latitudeDelta
        
        // 转换为屏幕坐标
        return CGPoint(
            x: x * mapSize.width,
            y: y * mapSize.height
        )
    }
}

// 地图工具类，提供各种地图相关的计算和功能
class MapUtils {
    // 地球半径（米）
    static let earthRadius: Double = 6371000.0
    
    // 计算多边形面积（平方米）
    // 使用球面几何学计算地理多边形的面积
    static func calculatePolygonArea(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        // 如果点数量少于3个，则无法形成多边形
        guard coordinates.count >= 3 else { return 0 }
        
        // 使用球面多边形面积公式
        var total = 0.0
        
        // 将经纬度转换为弧度
        let radianCoordinates = coordinates.map { coord -> (lat: Double, lon: Double) in
            return (lat: coord.latitude * .pi / 180, lon: coord.longitude * .pi / 180)
        }
        
        // 计算球面多边形面积
        let n = radianCoordinates.count
        
        // 使用球面多边形公式计算
        for i in 0..<n {
            let j = (i + 1) % n
            let k = (i + 2) % n
            
            let a = radianCoordinates[i]
            let b = radianCoordinates[j]
            
            // 计算相邻两点之间的经度差
            var dLon = b.lon - a.lon
            
            // 处理经度跨越180度的情况
            if dLon > .pi {
                dLon -= 2 * .pi
            } else if dLon < -.pi {
                dLon += 2 * .pi
            }
            
            // 使用球面几何公式计算面积贡献
            total += dLon * sin(a.lat)
        }
        
        // 计算最终面积
        let area = abs(total) * earthRadius * earthRadius / 2.0
        
        return area
    }
    
    // 计算两点之间的方位角
    private static func calculateBearing(_ p1: (lat: Double, lon: Double), _ p2: (lat: Double, lon: Double)) -> Double {
        let y = sin(p2.lon - p1.lon) * cos(p2.lat)
        let x = cos(p1.lat) * sin(p2.lat) - sin(p1.lat) * cos(p2.lat) * cos(p2.lon - p1.lon)
        return atan2(y, x)
    }
    
    // 计算球面三角形面积
    private static func sphericalTriangleArea(_ p1: (lat: Double, lon: Double), _ p2: (lat: Double, lon: Double), _ p3: (lat: Double, lon: Double)) -> Double {
        // 计算三个点的笛卡尔坐标
        let v1 = sphericalToCartesian(p1)
        let v2 = sphericalToCartesian(p2)
        let v3 = sphericalToCartesian(p3)
        
        // 计算三角形的三个边的单位向量
        let e1 = normalizeVector(crossProduct(v2, v3))
        let e2 = normalizeVector(crossProduct(v3, v1))
        let e3 = normalizeVector(crossProduct(v1, v2))
        
        // 计算三角形的三个角
        let angle1 = acos(dotProduct(e2, e3))
        let angle2 = acos(dotProduct(e3, e1))
        let angle3 = acos(dotProduct(e1, e2))
        
        // 计算球面三角形的面积（球面超额公式）
        let excessAngle = angle1 + angle2 + angle3 - .pi
        
        return excessAngle
    }
    
    // 将球面坐标（纬度、经度）转换为笛卡尔坐标
    private static func sphericalToCartesian(_ p: (lat: Double, lon: Double)) -> (x: Double, y: Double, z: Double) {
        let x = cos(p.lat) * cos(p.lon)
        let y = cos(p.lat) * sin(p.lon)
        let z = sin(p.lat)
        return (x, y, z)
    }
    
    // 计算两个向量的点积
    private static func dotProduct(_ v1: (x: Double, y: Double, z: Double), _ v2: (x: Double, y: Double, z: Double)) -> Double {
        return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    }
    
    // 计算两个向量的叉积
    private static func crossProduct(_ v1: (x: Double, y: Double, z: Double), _ v2: (x: Double, y: Double, z: Double)) -> (x: Double, y: Double, z: Double) {
        let x = v1.y * v2.z - v1.z * v2.y
        let y = v1.z * v2.x - v1.x * v2.z
        let z = v1.x * v2.y - v1.y * v2.x
        return (x, y, z)
    }
    
    // 归一化向量
    private static func normalizeVector(_ v: (x: Double, y: Double, z: Double)) -> (x: Double, y: Double, z: Double) {
        let magnitude = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if magnitude == 0 {
            return (0, 0, 0)
        }
        return (v.x / magnitude, v.y / magnitude, v.z / magnitude)
    }
    
    // 计算球面三角形的超额角（spherical excess）
    private static func computeSphericalExcess(_ p1: (lat: Double, lon: Double), _ p2: (lat: Double, lon: Double), _ p3: (lat: Double, lon: Double)) -> Double {
        // 计算边的长度（大圆距离）
        let a = greatCircleDistance(p1, p2)
        let b = greatCircleDistance(p2, p3)
        let c = greatCircleDistance(p3, p1)
        
        // 计算半周长
        let s = (a + b + c) / 2
        
        // 使用L'Huilier公式计算球面三角形的超额角
        let tanQE = sqrt(
            tan(s/2) *
            tan((s-a)/2) *
            tan((s-b)/2) *
            tan((s-c)/2)
        )
        
        return 4 * atan(tanQE)
    }
    
    // 计算两点间的大圆距离（弧度）
    private static func greatCircleDistance(_ p1: (lat: Double, lon: Double), _ p2: (lat: Double, lon: Double)) -> Double {
        let dLon = p2.lon - p1.lon
        
        let cosP1Lat = cos(p1.lat)
        let sinP1Lat = sin(p1.lat)
        let cosP2Lat = cos(p2.lat)
        let sinP2Lat = sin(p2.lat)
        
        let cosDLon = cos(dLon)
        let sinDLon = sin(dLon)
        
        let a = cosP2Lat * sinDLon
        let b = cosP1Lat * sinP2Lat - sinP1Lat * cosP2Lat * cosDLon
        let c = sinP1Lat * sinP2Lat + cosP1Lat * cosP2Lat * cosDLon
        
        return atan2(sqrt(a * a + b * b), c)
    }
    
    // 格式化面积显示
    static func formatArea(_ area: Double) -> String {
        if area < 10000 {
            // 小于1万平方米，显示平方米
            return String(format: "%.1f 平方米", area)
        } else if area < 1000000 {
            // 小于100万平方米，显示平方公里（保留2位小数）
            return String(format: "%.2f 平方公里", area / 1000000)
        } else {
            // 大于等于100万平方米，显示平方公里（保留1位小数）
            return String(format: "%.1f 平方公里", area / 1000000)
        }
    }
    
    // 创建相同形状的多边形，保持原始形状但移动到新的中心点
    // 使用第一个点作为参考点，而不是中心点，以保持形状完全一致
    static func createSameShapePolygon(originalPoints: [CLLocationCoordinate2D], newCenter: CLLocationCoordinate2D, scale: Double = 1.0) -> [CLLocationCoordinate2D] {
        // 如果点数量少于3个，则无法形成多边形
        guard originalPoints.count >= 3 else { return [] }
        
        // 使用第一个点作为参考点
        let referencePoint = originalPoints[0]
        
        // 计算原始多边形的中心点（仅用于确定新多边形的位置）
        let originalCenter = calculatePolygonCenter(originalPoints)
        
        // 计算参考点到中心点的偏移量
        let refToCenterLatOffset = originalCenter.latitude - referencePoint.latitude
        let refToCenterLonOffset = originalCenter.longitude - referencePoint.longitude
        
        // 计算新的参考点位置（使新多边形的中心位于newCenter）
        let newReferencePoint = CLLocationCoordinate2D(
            latitude: newCenter.latitude - refToCenterLatOffset,
            longitude: newCenter.longitude - refToCenterLonOffset
        )
        
        // 创建新的多边形点
        var newPoints: [CLLocationCoordinate2D] = []
        
        // 对每个点进行平移，保持相对于参考点的位置关系
        for point in originalPoints {
            // 计算点相对于参考点的偏移量
            let latOffset = (point.latitude - referencePoint.latitude) * scale
            let lonOffset = (point.longitude - referencePoint.longitude) * scale
            
            // 将偏移量应用到新的参考点
            let newLat = newReferencePoint.latitude + latOffset
            let newLon = newReferencePoint.longitude + lonOffset
            
            // 添加新的点
            newPoints.append(CLLocationCoordinate2D(latitude: newLat, longitude: newLon))
        }
        
        return newPoints
    }
    
    // 计算多边形的中心点
    static func calculatePolygonCenter(_ points: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        // 如果点数量为0，返回默认值
        guard !points.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        // 计算所有点的平均值
        var sumLat: Double = 0
        var sumLon: Double = 0
        
        for point in points {
            sumLat += point.latitude
            sumLon += point.longitude
        }
        
        let avgLat = sumLat / Double(points.count)
        let avgLon = sumLon / Double(points.count)
        
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }
    
    // 创建相同面积的多边形
    // 在指定中心点创建一个与给定面积相同的圆形
    static func createEqualAreaCircle(center: CLLocationCoordinate2D, area: Double) -> [CLLocationCoordinate2D] {
        // 计算圆的半径（米）
        let radius = sqrt(area / .pi)
        
        // 创建32个点的圆形
        return createCirclePoints(center: center, radiusMeters: radius, numPoints: 32)
    }
    
    // 根据中心点和半径（米）创建圆形的点集合
    static func createCirclePoints(center: CLLocationCoordinate2D, radiusMeters: Double, numPoints: Int) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        
        // 计算1度纬度对应的米数
        let metersPerLatDegree = 111320.0 // 地球赤道周长/360
        
        // 计算1度经度在当前纬度对应的米数
        let metersPerLonDegree = metersPerLatDegree * cos(center.latitude * .pi / 180)
        
        // 计算纬度和经度的偏移量
        let latOffset = radiusMeters / metersPerLatDegree
        let lonOffset = radiusMeters / metersPerLonDegree
        
        // 创建圆形点
        for i in 0..<numPoints {
            let angle = Double(i) * 2 * .pi / Double(numPoints)
            let lat = center.latitude + latOffset * sin(angle)
            let lon = center.longitude + lonOffset * cos(angle)
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        return points
    }
    
    // 将屏幕坐标转换为地图坐标
    static func convertPointToCoordinate(point: CGPoint, mapRect: CGRect, region: MKCoordinateRegion) -> CLLocationCoordinate2D {
        // 计算相对位置（0-1范围内）
        let x = point.x / mapRect.width
        let y = point.y / mapRect.height
        
        // 计算经纬度
        let longitude = region.center.longitude - (region.span.longitudeDelta / 2) + x * region.span.longitudeDelta
        let latitude = region.center.latitude + (region.span.latitudeDelta / 2) - y * region.span.latitudeDelta
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // 计算多边形的周长（米）
    static func calculatePolygonPerimeter(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        
        var perimeter: Double = 0
        
        // 计算所有相邻点之间的距离
        for i in 0..<coordinates.count {
            let j = (i + 1) % coordinates.count // 循环回到第一个点
            
            let p1 = (
                lat: coordinates[i].latitude * .pi / 180,
                lon: coordinates[i].longitude * .pi / 180
            )
            let p2 = (
                lat: coordinates[j].latitude * .pi / 180,
                lon: coordinates[j].longitude * .pi / 180
            )
            
            // 使用大圆距离计算两点之间的距离
            let distance = greatCircleDistance(p1, p2) * earthRadius
            perimeter += distance
        }
        
        return perimeter
    }
    
    // 格式化长度显示
    static func formatLength(_ length: Double) -> String {
        if length < 1000 {
            // 小于1千米，显示米
            return String(format: "%.1f 米", length)
        } else {
            // 大于等于1千米，显示千米
            return String(format: "%.2f 千米", length / 1000)
        }
    }
}

// 固定位置的多边形覆盖物视图
struct FixedPolygonOverlay: View {
    // 多边形的点坐标数组
    var points: [CLLocationCoordinate2D]
    
    // 多边形的填充颜色
    var fillColor: Color = .red.opacity(0.3)
    
    // 多边形的边框颜色
    var strokeColor: Color = .red
    
    // 多边形的边框宽度
    var lineWidth: CGFloat = 2.0
    
    // 地图视图的尺寸
    var mapSize: CGSize
    
    // 地图的当前缩放级别（span）
    var mapSpan: MKCoordinateSpan
    
    // 将地理坐标转换为屏幕坐标
    private func projectToScreen(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
        // 计算经纬度与中心点的差值
        let latitudeDelta = mapSpan.latitudeDelta
        let longitudeDelta = mapSpan.longitudeDelta
        
        // 计算多边形中心点
        let center = MapUtils.calculatePolygonCenter(points)
        
        // 将坐标转换为相对于地图中心的偏移量（-1到1的范围）
        let x = (coordinate.longitude - center.longitude) / longitudeDelta + 0.5
        let y = (coordinate.latitude - center.latitude) / latitudeDelta + 0.5
        
        // 转换为屏幕坐标
        return CGPoint(
            x: x * mapSize.width,
            y: (1 - y) * mapSize.height
        )
    }
    
    var body: some View {
        // 如果点数量不足3个，则不绘制多边形
        if points.count < 3 {
            EmptyView()
        } else {
            // 绘制多边形
            Path { path in
                // 将第一个点投影到屏幕空间
                let firstPoint = projectToScreen(points[0])
                path.move(to: firstPoint)
                
                // 连接其余的点
                for i in 1..<points.count {
                    let point = projectToScreen(points[i])
                    path.addLine(to: point)
                }
                
                // 闭合路径
                path.closeSubpath()
            }
            .fill(fillColor)
            .overlay(
                Path { path in
                    // 将第一个点投影到屏幕空间
                    let firstPoint = projectToScreen(points[0])
                    path.move(to: firstPoint)
                    
                    // 连接其余的点
                    for i in 1..<points.count {
                        let point = projectToScreen(points[i])
                        path.addLine(to: point)
                    }
                    
                    // 闭合路径
                    path.closeSubpath()
                }
                .stroke(strokeColor, lineWidth: lineWidth)
            )
        }
    }
}

// 缩放按钮组件
struct ZoomButtons: View {
    var onZoomIn: () -> Void
    var onZoomOut: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 放大按钮
            Button(action: onZoomIn) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.black)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            
            // 缩小按钮
            Button(action: onZoomOut) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.black)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.8))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

// 收藏视图
struct FavoritesView: View {
    var body: some View {
        VStack {
            Text("收藏功能将在后续版本实现")
                .foregroundColor(.gray)
                .padding()
            Spacer()
        }
        .navigationTitle("收藏")
    }
}

// 设置视图
struct SettingsView: View {
    var body: some View {
        VStack {
            Text("设置功能将在后续版本实现")
                .foregroundColor(.gray)
                .padding()
            Spacer()
        }
        .navigationTitle("设置")
    }
}

// 地图主视图
struct MapView: View {
    // 状态变量，用于存储上方地图的区域
    @State private var topRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074), // 北京坐标
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // 状态变量，用于存储下方地图的区域
    @State private var bottomRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 31.2397, longitude: 121.4998), // 上海东方明珠坐标
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // 状态变量，用于存储用户在上方地图绘制的点
    @State private var drawnPoints: [CLLocationCoordinate2D] = []
    
    // 状态变量，用于存储下方地图显示的等面积多边形点
    @State private var equalAreaPoints: [CLLocationCoordinate2D] = []
    
    // 状态变量，用于存储是否正在绘制
    @State private var isDrawing = false
    
    // 状态变量，用于存储计算的面积
    @State private var calculatedArea: Double = 0
    
    // 状态变量，用于存储地图视图的尺寸
    @State private var topMapSize: CGSize = .zero
    @State private var bottomMapSize: CGSize = .zero
    
    // 状态变量，用于存储是否显示搜索界面
    @State private var showingSearch = false
    
    // 状态变量，用于存储搜索文本
    @State private var searchText = ""
    
    // 状态变量，用于存储下方地图的初始中心点
    @State private var bottomMapInitialCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack {
                    Button(action: {
                        // 清除绘制的点
                        drawnPoints.removeAll()
                        equalAreaPoints.removeAll()
                        calculatedArea = 0
                    }) {
                        Image(systemName: "trash")
                            .padding()
                    }
                    
                    Spacer()
                    
                    Text("MapMiro")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        // 切换绘制模式
                        isDrawing.toggle()
                    }) {
                        Image(systemName: isDrawing ? "pencil.slash" : "pencil")
                            .padding()
                    }
                }
                .padding(.horizontal)
                .background(Color.gray.opacity(0.2))
                
                // 上方地图
                ZStack {
                    // 使用GeometryReader获取地图视图的尺寸
                    GeometryReader { mapGeometry in
                        ZStack {
                            Map(initialPosition: .region(topRegion)) {
                                // 这里可以添加地图标记等内容
                            }
                            .onAppear {
                                topMapSize = mapGeometry.size
                            }
                            .onChange(of: mapGeometry.size) { _, newSize in
                                topMapSize = newSize
                            }
                            .onMapCameraChange { context in
                                // 更新topRegion以反映地图的当前位置
                                topRegion = MKCoordinateRegion(
                                    center: context.region.center,
                                    span: context.region.span
                                )
                            }
                            
                            // 绘制多边形
                            if !drawnPoints.isEmpty {
                                PolygonOverlay(
                                    points: drawnPoints,
                                    fillColor: .blue.opacity(0.3),
                                    strokeColor: .blue,
                                    region: topRegion,
                                    mapSize: topMapSize
                                )
                            }
                            
                            // 绘制点标记
                            ForEach(0..<drawnPoints.count, id: \.self) { index in
                                PointMarker(
                                    coordinate: drawnPoints[index],
                                    color: .blue,
                                    region: topRegion,
                                    mapSize: topMapSize
                                )
                            }
                        }
                        .contentShape(Rectangle()) // 确保整个区域可以接收手势
                        .onTapGesture { location in
                            // 如果在绘制模式，添加点
                            if isDrawing {
                                // 将点击位置转换为地图坐标
                                let tapPoint = CGPoint(x: location.x, y: location.y)
                                let mapRect = CGRect(origin: .zero, size: topMapSize)
                                let coordinate = MapUtils.convertPointToCoordinate(
                                    point: tapPoint,
                                    mapRect: mapRect,
                                    region: topRegion
                                )
                                
                                // 添加点
                                drawnPoints.append(coordinate)
                                
                                // 如果有至少3个点，计算面积
                                if drawnPoints.count >= 3 {
                                    calculatedArea = MapUtils.calculatePolygonArea(drawnPoints)
                                    
                                    // 创建相同形状的多边形，固定在下方地图中央
                                    equalAreaPoints = MapUtils.createSameShapePolygon(
                                        originalPoints: drawnPoints,
                                        newCenter: bottomRegion.center
                                    )
                                }
                            }
                        }
                    }
                    
                    // 如果在绘制模式，显示绘制提示
                    if isDrawing {
                        Text("点击地图添加点")
                            .font(.caption)
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(8)
                            .position(x: topMapSize.width / 2, y: 20)
                    }
                    
                    // 添加缩放按钮
                    ZoomButtons(
                        onZoomIn: {
                            // 放大地图（减小span值）
                            topRegion.span = MKCoordinateSpan(
                                latitudeDelta: max(topRegion.span.latitudeDelta * 0.5, 0.001),
                                longitudeDelta: max(topRegion.span.longitudeDelta * 0.5, 0.001)
                            )
                        },
                        onZoomOut: {
                            // 缩小地图（增加span值）
                            topRegion.span = MKCoordinateSpan(
                                latitudeDelta: min(topRegion.span.latitudeDelta * 2.0, 180.0),
                                longitudeDelta: min(topRegion.span.longitudeDelta * 2.0, 180.0)
                            )
                        }
                    )
                    .position(x: topMapSize.width - 50, y: topMapSize.height - 50)
                }
                .frame(height: geometry.size.height * 0.4)
                
                // 中间控制栏
                HStack {
                    Button(action: {
                        // 显示搜索界面
                        showingSearch = true
                    }) {
                        Image(systemName: "magnifyingglass")
                            .padding()
                    }
                    .sheet(isPresented: $showingSearch) {
                        // 搜索界面
                        VStack {
                            HStack {
                                TextField("搜索位置", text: $searchText)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                
                                Button("取消") {
                                    showingSearch = false
                                }
                            }
                            .padding()
                            
                            // 这里可以添加搜索结果列表
                            Text("搜索功能将在后续版本实现")
                                .foregroundColor(.gray)
                                .padding()
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // 同步两个地图的比例尺
                        bottomRegion = MKCoordinateRegion(
                            center: bottomRegion.center,
                            span: topRegion.span
                        )
                        
                        // 如果有多边形，更新多边形以适应新的缩放级别
                        if !drawnPoints.isEmpty && drawnPoints.count >= 3 {
                            equalAreaPoints = MapUtils.createSameShapePolygon(
                                originalPoints: drawnPoints,
                                newCenter: bottomRegion.center
                            )
                        }
                    }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .padding()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // 分享功能（暂未实现）
                    }) {
                        Image(systemName: "square.and.arrow.up")
        .padding()
                    }
                }
                .padding(.horizontal)
                .background(Color.gray.opacity(0.2))
                
                // 下方地图
                ZStack {
                    // 使用GeometryReader获取地图视图的尺寸
                    GeometryReader { mapGeometry in
                        Map(initialPosition: .region(bottomRegion)) {
                            // 这里可以添加地图标记等内容
                        }
                        .onAppear {
                            bottomMapSize = mapGeometry.size
                            // 保存初始中心点
                            bottomMapInitialCenter = bottomRegion.center
                        }
                        .onChange(of: mapGeometry.size) { _, newSize in
                            bottomMapSize = newSize
                        }
                        // 使用id修饰符来监听地图缩放级别变化
                        .id("\(bottomRegion.span.latitudeDelta),\(bottomRegion.span.longitudeDelta)")
                        .onMapCameraChange { context in
                            // 更新bottomRegion以反映地图的当前位置
                            let newRegion = MKCoordinateRegion(
                                center: context.region.center,
                                span: context.region.span
                            )
                            
                            // 只有当span发生变化时才更新，避免无限循环
                            if abs(bottomRegion.span.latitudeDelta - newRegion.span.latitudeDelta) > 0.0001 ||
                               abs(bottomRegion.span.longitudeDelta - newRegion.span.longitudeDelta) > 0.0001 {
                                bottomRegion = newRegion
                                
                                // 如果有多边形，更新多边形以适应新的缩放级别
                                if !drawnPoints.isEmpty && drawnPoints.count >= 3 {
                                    equalAreaPoints = MapUtils.createSameShapePolygon(
                                        originalPoints: drawnPoints,
                                        newCenter: newRegion.center
                                    )
                                }
                            } else {
                                // 如果只是位置变化，只更新中心点
                                bottomRegion.center = newRegion.center
                            }
                        }
                    }
                    
                    // 绘制固定位置的多边形
                    if !equalAreaPoints.isEmpty {
                        FixedPolygonOverlay(
                            points: equalAreaPoints,
                            fillColor: .purple.opacity(0.3),
                            strokeColor: .purple,
                            mapSize: bottomMapSize,
                            mapSpan: bottomRegion.span
                        )
                    }
                    
                    // 添加缩放按钮
                    ZoomButtons(
                        onZoomIn: {
                            // 放大地图（减小span值）
                            bottomRegion.span = MKCoordinateSpan(
                                latitudeDelta: max(bottomRegion.span.latitudeDelta * 0.5, 0.001),
                                longitudeDelta: max(bottomRegion.span.longitudeDelta * 0.5, 0.001)
                            )
                        },
                        onZoomOut: {
                            // 缩小地图（增加span值）
                            bottomRegion.span = MKCoordinateSpan(
                                latitudeDelta: min(bottomRegion.span.latitudeDelta * 2.0, 180.0),
                                longitudeDelta: min(bottomRegion.span.longitudeDelta * 2.0, 180.0)
                            )
                        }
                    )
                    .position(x: bottomMapSize.width - 50, y: bottomMapSize.height - 50)
                }
                .frame(height: geometry.size.height * 0.4)
                
                // 底部信息栏
                HStack {
                    HStack(spacing: 8) {
                        //Text("面积: \(MapUtils.formatArea(calculatedArea))")
                        //    .font(.caption)
                        if drawnPoints.count >= 2 {
                            Text("周长: \(MapUtils.formatLength(MapUtils.calculatePolygonPerimeter(drawnPoints)))")
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    Text("MapMiro v0.22")
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
}

struct ContentView: View {
    var body: some View {
        MapView() // 移除TabView，暂时只显示地图功能
    }
}

// 预览代码添加配置
#Preview {
    ContentView()
        .environment(\.colorScheme, .light) // 指定预览的颜色方案
}
