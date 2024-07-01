// Copyright 2024 Cii
//
// This file is part of Rasen.
//
// Rasen is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Rasen is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Rasen.  If not, see <http://www.gnu.org/licenses/>.

import struct Foundation.UUID

typealias UUColor = UU<Color>
extension UU: Serializable where Value == Color {}
extension UU: Protobuf where Value == Color {
    typealias PB = PBUUColor
    init(_ pb: PBUUColor) throws {
        let value = try Color(pb.value)
        let id = try UUID(pb.id)
        self.init(value, id: id)
    }
    var pb: PBUUColor {
        .with {
            $0.value = value.pb
            $0.id = id.pb
        }
    }
}

struct Plane {
    var topolygon = Topolygon(), uuColor = UU(Color())
}
extension Plane: Protobuf {
    init(_ pb: PBPlane) throws {
        if let topolygon = try? Topolygon(pb.topolygon), !topolygon.isEmpty {
            self.topolygon = topolygon
        } else {
            let polygon = try Polygon(pb.polygon)
            topolygon = Topolygon(polygon: polygon, holePolygons: [])
        }
        
        uuColor = (try? UUColor(pb.uuColor)) ?? UU(Color())
        if uuColor.value.rgbColorSpace != Color.defaultColorSpace {
            uuColor.value.rgbColorSpace = Color.defaultColorSpace
        }
    }
    var pb: PBPlane {
        .with {
            if topolygon.holePolygons.isEmpty {
                $0.polygon = topolygon.polygon.pb
            } else {
                $0.topolygon = topolygon.pb
            }
            $0.uuColor = uuColor.pb
        }
    }
}
extension Plane: Hashable, Codable {}
extension Plane: AppliableTransform {
    static func * (lhs: Plane, rhs: Transform) -> Plane {
        Plane(topolygon: lhs.topolygon * rhs, uuColor: lhs.uuColor)
    }
}
extension Plane {
    var path: Path {
        Path(topolygon)
    }
    var isEmpty: Bool {
        topolygon.isEmpty
    }
    var bounds: Rect? {
        topolygon.bounds
    }
    var pointCentroid: Point? {
        topolygon.pointCentroid
    }
}
extension Array where Element == Plane {
    var bounds: Rect? {
        var rect = Rect?.none
        for element in self {
            rect = rect + element.bounds
        }
        return rect
    }
}
