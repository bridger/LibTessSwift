import UIKit
import XCTest
import LibTessSwift

class Tests: XCTestCase {
    
    static var _loader: DataLoader = DataLoader()
    
    public struct TestCaseData: CustomStringConvertible {
        public var AssetName: String
        public var Winding: WindingRule
        public var ElementSize: Int
        
        public var description: String {
            return "\(Winding), \(AssetName), \(ElementSize)"
        }
    }

    public class TestData {
        public var ElementSize: Int
        public var Indices: [Int]
        
        init(indices: [Int], elementSize: Int) {
            self.Indices = indices
            self.ElementSize = elementSize
        }
    }
    
    public var OutputTestData = false
    public var TestDataPath = "./" // Path.Combine("..", "..", "TessBed", "TestData")
    
    public func testTesselate_WithSingleTriangle_ProducesSameTriangle() throws {
        let data = "0,0,0\n0,1,0\n1,1,0"
        var indices: [Int] = []
        let expectedIndices = [0, 1, 2]
        
        let tess = try setupTess(withString: data)
        
        let (_, elements) = try tess.tessellate(windingRule: WindingRule.evenOdd, elementType: ElementType.polygons, polySize: 3)
        
        for i in 0..<tess.elementCount {
            for j in 0..<3 {
                let index = elements[i * 3 + j]
                indices.append(index)
            }
        }

        XCTAssertEqual(expectedIndices, indices)
    }
    
    // From https://github.com/memononen/libtess2/issues/14
    public func testTesselate_WithThinQuad_DoesNotCrash() throws {
        let data = "9.5,7.5,-0.5\n9.5,2,-0.5\n9.5,2,-0.4999999701976776123\n9.5,7.5,-0.4999999701976776123"
        
        let tess = try setupTess(withString: data)
        
        try tess.tessellate(windingRule: WindingRule.evenOdd, elementType: ElementType.polygons, polySize: 3)
    }
    
    
    // From https://github.com/speps/LibTessDotNet/issues/1
    public func testTesselate_WithIssue1Quad_ReturnsSameResultAsLibtess2() throws {
        let data = "50,50\n300,50\n300,200\n50,200"
        var indices: [Int] = []
        let expectedIndices = [ 0, 1, 2, 1, 0, 3 ]
        
        let tess = try setupTess(withString: data)
        
        let (_, elements) = try tess.tessellate(windingRule: WindingRule.evenOdd, elementType: ElementType.polygons, polySize: 3)
        
        for i in 0..<tess.elementCount {
            for j in 0..<3 {
                let index = elements[i * 3 + j]
                indices.append(index)
            }
        }
        
        XCTAssertEqual(expectedIndices, indices)
    }
    
    // From https://github.com/speps/LibTessDotNet/issues/1
    public func testTesselate_WithNoEmptyPolygonsTrue_RemovesEmptyPolygons() throws {
        let data = "2,0,4\n2,0,2\n4,0,2\n4,0,0\n0,0,0\n0,0,4"
        var indices: [Int] = []
        let expectedIndices = [ 0, 1, 2, 2, 3, 4, 3, 1, 5 ]
        
        let tess = try setupTess(withString: data)
        tess.noEmptyPolygons = true
        let (_, elements) = try tess.tessellate(windingRule: .evenOdd, elementType: .polygons, polySize: 3)
        
        for i in 0..<tess.elementCount {
            for j in 0..<3 {
                let index = elements[i * 3 + j]
                indices.append(index)
            }
        }
        XCTAssertEqual(expectedIndices, indices)
    }
    
    public func testTesselate_HelperStaticMethodVector3() throws {
        let data = "50,50,10\n300,50,20\n300,200,5\n50,200,30"
        let expectedIndices = [ 0, 1, 2, 1, 0, 3 ]
        let expectedVerts = [ CVector3(50, 200, 30), CVector3(300, 50, 20), CVector3(300, 200, 5), CVector3(50, 50, 10) ]
        
        let reader = DDStreamReader.fromString(data)
        let pset = try DataLoader.LoadDat(reader: reader)
        
        let (verts, indices) = try TessC.tesselate3d(polygon: pset.polygons[0].points)
        
        func floatEq(_ f1: TESSreal, _ f2: TESSreal) -> Bool {
            return abs(f1 - f2) < .leastNormalMagnitude
        }
        
        XCTAssert(expectedVerts.elementsEqual(verts, by: { exp, out -> Bool in
            return floatEq(exp.x, out.x) && floatEq(exp.y, out.y) && floatEq(exp.z, out.z)
        }), "Polygons do not match - expected: \(expectedVerts) received: \(verts)")
        
        XCTAssertEqual(expectedIndices, indices)
    }
    
    public func testTesselate_HelperStaticMethodVector2() throws {
        let data = "50,50\n300,50\n300,200\n50,200"
        let expectedIndices = [ 0, 1, 2, 1, 0, 3 ]
        let expectedVerts = [ CVector3(50, 200, 0), CVector3(300, 50, 0), CVector3(300, 200, 0), CVector3(50, 50, 0) ]
        
        let reader = DDStreamReader.fromString(data)
        let pset = try DataLoader.LoadDat(reader: reader)
        
        let (verts, indices) = try TessC.tesselate2d(polygon: pset.polygons[0].points)
        
        func floatEq(_ f1: TESSreal, _ f2: TESSreal) -> Bool {
            return abs(f1 - f2) < .leastNormalMagnitude
        }
        
        XCTAssert(expectedVerts.elementsEqual(verts, by: { exp, out -> Bool in
            return floatEq(exp.x, out.x) && floatEq(exp.y, out.y) && floatEq(exp.z, out.z)
        }), "Polygons do not match - expected: \(expectedVerts) received: \(verts)")
        
        XCTAssertEqual(expectedIndices, indices)
    }
    
    public func testTesselate_CalledTwiceOnSameInstance_DoesNotCrash() throws {
        let data = "0,0,0\n0,1,0\n1,1,0"
        var indices: [Int] = []
        let expectedIndices = [ 0, 1, 2 ]
        
        let reader = DDStreamReader.fromString(data)
        
        let pset = try DataLoader.LoadDat(reader: reader)
        guard let tess = TessC() else {
            throw TestError.tessInitError
        }
        
        // Call once
        PolyConvert.ToTessC(pset: pset, tess: tess)
        let (_, elements) = try tess.tessellate(windingRule: .evenOdd, elementType: .polygons, polySize: 3)
        
        for i in 0..<tess.elementCount {
            for j in 0..<3 {
                let index = elements[i * 3 + j]
                indices.append(index)
            }
        }

        XCTAssertEqual(expectedIndices, indices)

        // Call twice
        PolyConvert.ToTessC(pset: pset, tess: tess)
        let (_, elements2) = try tess.tessellate(windingRule: .evenOdd, elementType: .polygons, polySize: 3)

        indices.removeAll()
        for i in 0..<tess.elementCount {
            for j in 0..<3 {
                let index = elements2[i * 3 + j]
                indices.append(index)
            }
        }

        XCTAssertEqual(expectedIndices, indices)
    }
    
    public func testTessellate_WithAssets_ReturnsExpectedTriangulation() {
        
        let bundle = Bundle(for: type(of: self))
        
        // Multi-task the test
        let queue = OperationQueue()
        
        for data in GetTestCaseData() {
            queue.addOperation {
                autoreleasepool {
                    do {
                        let pset = try Tests._loader.GetAsset(name: data.AssetName)!.Polygons!
                        
                        guard let tess = TessC() else {
                            print("Failed to generate proper tesselator instance")
                            return
                        }
                        
                        PolyConvert.ToTessC(pset: pset, tess: tess)
                        try tess.tessellate(windingRule: data.Winding, elementType: .polygons, polySize: data.ElementSize)
                        
                        guard let resourceName = bundle.path(forResource: data.AssetName, ofType: "testdat") else {
                            print("Could not find resulting test asset \(data.AssetName).testdat for test data \(data.AssetName).dat")
                            return
                        }
                        
                        let reader = try DDUnbufferedFileReader(fileUrl: URL(fileURLWithPath: resourceName))
                        
                        guard let testData = self.ParseTestData(data.Winding, data.ElementSize, reader) else {
                            XCTFail("Unexpected empty data for test result for \(data.AssetName)")
                            return
                        }
                        
                        XCTAssertEqual(testData.ElementSize, data.ElementSize)
                        
                        var indices: [Int] = []
                        
                        for i in 0..<tess.elementCount {
                            for j in 0..<data.ElementSize {
                                let index = tess.elements![i * data.ElementSize + j]
                                indices.append(index)
                            }
                        }
                        
                        if(testData.Indices != indices) {
                            XCTFail("Failed test: winding: \(data.Winding.description) file: \(data.AssetName) element size: \(data.ElementSize)")
                        }
                    } catch {
                        XCTFail("Failed test: winding: \(data.Winding.description) file: \(data.AssetName) element size: \(data.ElementSize) - caught unexpected error \(error)")
                    }
                }
            }
        }
        
        let expec = expectation(description: "")
        
        // Sometimes, Xcode complains about a blocked main thread during tests
        // Use XCTest's expectation to wrap the operation above
        DispatchQueue.global().async {
            queue.waitUntilAllOperationsAreFinished()
            expec.fulfill()
        }
        
        waitForExpectations(timeout: 200, handler: nil)
    }
    
    func GetTestCaseData() -> [TestCaseData] {
        var data: [TestCaseData] = []
        
        let windings: [WindingRule] = [
            .evenOdd,
            .nonZero,
            .positive,
            .negative,
            .absGeqTwo
        ]
        
        for winding in windings {
            for name in Tests._loader.AssetNames {
                data.append(TestCaseData(AssetName: name, Winding: winding, ElementSize: 3))
            }
        }
        
        return data
    }
    
    public func ParseTestData(_ winding: WindingRule, _ elementSize: Int, _ reader: StreamLineReader) -> TestData? {
        var lines: [String] = []
        
        var found = false
        
        while true {
            
            let breakOut: Bool = autoreleasepool {
                guard var line = reader.readLine() else {
                    return true
                }
                
                line = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if (found && line.isEmpty) {
                    return true
                }
                if (found) {
                    lines.append(line)
                }
                let parts = line.components(separatedBy: " ")
                if(parts.count < 2) {
                    return false
                }
                
                if (parts.first == winding.description && Int(parts.last!) == elementSize) {
                    found = true
                }
                
                return false
            }
            
            if(breakOut) {
                break
            }
        }
        
        var indices: [Int] = []
        for line in lines {
            let parts = line.components(separatedBy: " ")
            if (parts.count != elementSize) {
                continue
            }
            for part in parts {
                indices.append(Int(part)!)
            }
        }
        if (found) {
            return TestData(indices: indices, elementSize: elementSize)
        }
        return nil
    }
    
    func setupTess(withString string: String) throws -> TessC {
        let reader = DDStreamReader.fromString(string)
        
        let pset = try DataLoader.LoadDat(reader: reader)
        guard let tess = TessC() else {
            throw TestError.tessInitError
        }
        
        PolyConvert.ToTessC(pset: pset, tess: tess)
        
        return tess
    }
    
    enum TestError: Error {
        case tessInitError
    }
}
