//
//  MASONTests.swift
//  MASON
//
//  Created by Michael Ash on 11/18/14.
//  Copyright (c) 2014 mikeash. All rights reserved.
//

import Cocoa
import XCTest

import MASON

class MASONTests: XCTestCase {
    func assertErrorsEqual(error: MASONObject.Error, expectedTypeName: String, actualTypeName: String, keyPath: MASONObject.Error.Element...) {
        XCTAssertEqual(error.expectedTypeName, expectedTypeName, "Wrong expected type name")
        XCTAssertEqual(error.actualTypeName, actualTypeName, "Wrong actual type name")
        XCTAssertEqual(error.keyPath.count, keyPath.count, "Key path counts don't match")
        for (element1, element2) in Zip2(error.keyPath, keyPath) {
            XCTAssertEqual(element1, element2, "Wrong key path element")
        }
    }
    
    func testSimpleDictGet() {
        let dict = [ "key": "value" ]
        let obj = MASONObject(dict)
        
        let value = obj.dict["key"].string
        XCTAssertEqual(value, "value")
        XCTAssertEqual(obj.errors.count, 0)
    }
    
    func testNoKeyGet() {
        let dict = [:]
        let obj = MASONObject(dict)
        
        let value = obj.dict["key"].string
        XCTAssertEqual(obj.errors.count, 1)
        assertErrorsEqual(obj.errors[0], expectedTypeName: "string", actualTypeName: "nil", keyPath: .Key("key"))
    }
    
    func testWrongTypeDictGet() {
        let dict = [ "key": "value" ]
        let obj = MASONObject(dict)
        
        let value = obj.dict["key"].double
        XCTAssertEqual(obj.errors.count, 1)
        assertErrorsEqual(obj.errors[0], expectedTypeName: "number", actualTypeName: "NSString", keyPath: .Key("key"))
    }
    
    func testSimpleArrayGet() {
        let array = [ "one", "two" ]
        let obj = MASONObject(array)
        
        let value1 = obj.array[0].string
        let value2 = obj.array[1].string
        XCTAssertEqual(value1, "one")
        XCTAssertEqual(value2, "two")
        XCTAssertEqual(obj.errors.count, 0)
    }
    
    func testArrayOutOfBounds() {
        let array = [ "one", "two" ]
        let obj = MASONObject(array)
        
        let value = obj.array[2].string
        XCTAssertEqual(obj.errors.count, 1)
        assertErrorsEqual(obj.errors[0], expectedTypeName: "string", actualTypeName: "nil", keyPath: .Index(2))
    }
    
    func testDeepGet() {
        let dict = [
            "key": [
                "array": [
                    1,
                    2,
                    [
                        "anotherKey": "value"
                    ]
                ]
            ]
        ]
        let obj = MASONObject(dict)
        
        let value = obj.dict["key"].dict["array"].array[2].dict["anotherKey"].string
        XCTAssertEqual(value, "value")
        XCTAssertEqual(obj.errors.count, 0)
    }
    
    func testDeepGetFailure() {
        let dict = [
            "key": [
                "array": [
                    1,
                    2,
                    [
                        "anotherKey": "value"
                    ]
                ]
            ]
        ]
        let obj = MASONObject(dict)
        
        let value1 = obj.dict["key"].dict["array"].array[2].dict["anotherKey"].double
        let value2 = obj.dict["key"].dict["array"].array[2].string
        XCTAssertEqual(obj.errors.count, 2)
        assertErrorsEqual(obj.errors[0], expectedTypeName: "number", actualTypeName: "NSString", keyPath: .Key("key"), .Key("array"), .Index(2), .Key("anotherKey"))
        assertErrorsEqual(obj.errors[1], expectedTypeName: "string", actualTypeName: "NSDictionary", keyPath: .Key("key"), .Key("array"), .Index(2))
    }
    
    func testDeepGetShallowDictFailure() {
        let dict = [:]
        let obj = MASONObject(dict)
        
        let value = obj.dict["key"].dict["key"].dict["key"].dict["key"].dict["key"].dict["key"].dict["key"]
        XCTAssertEqual(obj.errors.count, 1)
        assertErrorsEqual(obj.errors[0], expectedTypeName: "dictionary", actualTypeName: "nil", keyPath: .Key("key"))
    }
    
    func testExample() {
        struct Image {
            let name: String
            let width: Int
            let height: Int
        }
        
        func DecodeImages(json: MASONObject) -> [Image] {
            let jsonImages = json.dict["images"]
            return jsonImages.array.map{
                Image(name: $0.dict["name"].string, width: Int($0.dict["width"].double), height: Int($0.dict["height"].double))
            }
        }
        
        let dict1 = [
            "images": [
                [
                    "name": "whatever",
                    "width": 320,
                    "height": 240
                ],
                [
                    "name": "whatever2",
                    "width": 64,
                    "height": 64
                ]
            ]
        ]
        let (images1, errors1) = Decode(dict1, DecodeImages)
        XCTAssertTrue(images1 != nil)
        XCTAssertTrue(errors1 == nil)
        XCTAssertEqual(images1!.count, 2)
        XCTAssertEqual(images1![0].name, "whatever")
        XCTAssertEqual(images1![1].width, 64)
        
        let dict2 = [
            "images": [
                [
                    "name": "whatever",
                    "width": 320,
                    "height": 240
                ],
                [
                    "name": "whatever2",
                    "height": 64
                ]
            ]
        ]
        let (images2, errors2) = Decode(dict2, DecodeImages)
        XCTAssertTrue(images2 == nil)
        XCTAssertTrue(errors2 != nil)
        XCTAssertEqual(errors2!.count, 1)
        assertErrorsEqual(errors2![0], expectedTypeName: "number", actualTypeName: "nil", keyPath: .Key("images"), .Index(1), .Key("width"))
        
        let dict3 = [:]
        let (images3, errors3) = Decode(dict2, DecodeImages)
        XCTAssertTrue(images3 == nil)
        XCTAssertTrue(errors3 != nil)
        assertErrorsEqual(errors3![0], expectedTypeName: "dictionary", actualTypeName: "nil", keyPath: .Key("images"))
    }
}
