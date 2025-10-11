import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

struct DataStructureCapabilityTests {

    // Test model for capability declarations
    @Model
    final class TestProduct {
        var name: String = ""
        var productDescription: String = ""
        var price: Double = 0.0

        init(name: String = "", productDescription: String = "", price: Double = 0.0) {
            self.name = name
            self.productDescription = productDescription
            self.price = price
        }
    }

    @Test("Model capability can be created")
    func testModelCapability() {
        let capability = DataStructureCapability.model(
            TestProduct.self,
            properties: [
                .property(\TestProduct.productDescription, constraints: .init(minLength: 50, maxLength: 500))
            ]
        )

        #expect(capability.modelType != nil)
        #expect(capability.modelType?.contains("TestProduct") == true)
        #expect(capability.properties.count == 1)
        #expect(capability.properties[0].propertyName == "productDescription")
    }

    @Test("Protocol capability can be created")
    func testProtocolCapability() {
        let capability = DataStructureCapability.protocol(
            (any AIGeneratable).self,
            typeConstraints: [
                .canGenerate(.string),
                .canGenerate(.data)
            ]
        )

        #expect(capability.protocolType != nil)
        #expect(capability.protocolType?.contains("AIGeneratable") == true)
        #expect(capability.typeConstraints.count == 2)
    }

    @Test("PropertyCapability stores property information")
    func testPropertyCapability() {
        let constraints = PropertyConstraints(minLength: 10, maxLength: 100)
        let property = PropertyCapability(propertyName: "testProperty", constraints: constraints)

        #expect(property.propertyName == "testProperty")
        #expect(property.constraints?.minLength == 10)
        #expect(property.constraints?.maxLength == 100)
    }

    @Test("PropertyCapability can be created from KeyPath")
    func testPropertyCapabilityFromKeyPath() {
        let property = PropertyCapability.property(
            \TestProduct.productDescription,
            constraints: .init(minLength: 50)
        )

        #expect(property.propertyName == "productDescription")
        #expect(property.constraints?.minLength == 50)
    }

    @Test("PropertyConstraints stores all constraint types")
    func testPropertyConstraints() {
        let constraints = PropertyConstraints(
            minLength: 10,
            maxLength: 100,
            additionalConstraints: ["tone": "professional", "format": "markdown"]
        )

        #expect(constraints.minLength == 10)
        #expect(constraints.maxLength == 100)
        #expect(constraints.additionalConstraints["tone"] == "professional")
        #expect(constraints.additionalConstraints["format"] == "markdown")
    }

    @Test("PropertyConstraints with nil values")
    func testPropertyConstraintsWithNils() {
        let constraints = PropertyConstraints(minLength: nil, maxLength: nil)

        #expect(constraints.minLength == nil)
        #expect(constraints.maxLength == nil)
        #expect(constraints.additionalConstraints.isEmpty)
    }

    @Test("TypeConstraint canGenerate works")
    func testTypeConstraintCanGenerate() {
        let constraint = TypeConstraint.canGenerate(.string)

        if case .canGenerate(let type) = constraint {
            #expect(type == .string)
        } else {
            Issue.record("Expected canGenerate case")
        }
    }

    @Test("TypeConstraint cannotGenerate works")
    func testTypeConstraintCannotGenerate() {
        let constraint = TypeConstraint.cannotGenerate(.int)

        if case .cannotGenerate(let type) = constraint {
            #expect(type == .int)
        } else {
            Issue.record("Expected cannotGenerate case")
        }
    }

    @Test("SwiftType enum has all common types")
    func testSwiftTypeEnum() {
        #expect(SwiftType.string.rawValue == "String")
        #expect(SwiftType.int.rawValue == "Int")
        #expect(SwiftType.double.rawValue == "Double")
        #expect(SwiftType.bool.rawValue == "Bool")
        #expect(SwiftType.data.rawValue == "Data")
        #expect(SwiftType.url.rawValue == "URL")
        #expect(SwiftType.date.rawValue == "Date")
        #expect(SwiftType.uuid.rawValue == "UUID")
    }

    @Test("DataStructureCapability model type accessor")
    func testModelTypeAccessor() {
        let modelCap = DataStructureCapability.model(
            TestProduct.self,
            properties: []
        )

        let protocolCap = DataStructureCapability.protocol(
            (any AIGeneratable).self,
            typeConstraints: []
        )

        #expect(modelCap.modelType != nil)
        #expect(protocolCap.modelType == nil)
        #expect(modelCap.protocolType == nil)
        #expect(protocolCap.protocolType != nil)
    }

    @Test("DataStructureCapability properties accessor")
    func testPropertiesAccessor() {
        let properties = [
            PropertyCapability.property(\TestProduct.name),
            PropertyCapability.property(\TestProduct.productDescription)
        ]

        let capability = DataStructureCapability.model(
            TestProduct.self,
            properties: properties
        )

        #expect(capability.properties.count == 2)

        // Protocol capability should have empty properties
        let protocolCap = DataStructureCapability.protocol(
            (any AIGeneratable).self,
            typeConstraints: []
        )
        #expect(protocolCap.properties.isEmpty)
    }

    @Test("DataStructureCapability typeConstraints accessor")
    func testTypeConstraintsAccessor() {
        let constraints = [
            TypeConstraint.canGenerate(.string),
            TypeConstraint.canGenerate(.data)
        ]

        let capability = DataStructureCapability.protocol(
            (any AIGeneratable).self,
            typeConstraints: constraints
        )

        #expect(capability.typeConstraints.count == 2)

        // Model capability should have empty constraints
        let modelCap = DataStructureCapability.model(
            TestProduct.self,
            properties: []
        )
        #expect(modelCap.typeConstraints.isEmpty)
    }

    @Test("Complex capability declaration")
    func testComplexCapabilityDeclaration() {
        let capability = DataStructureCapability.model(
            TestProduct.self,
            properties: [
                .property(\TestProduct.name, constraints: .init(minLength: 1, maxLength: 100)),
                .property(\TestProduct.productDescription, constraints: .init(
                    minLength: 50,
                    maxLength: 500,
                    additionalConstraints: ["tone": "professional", "format": "markdown"]
                )),
                .property(\TestProduct.price)
            ]
        )

        #expect(capability.properties.count == 3)
        #expect(capability.properties[0].propertyName == "name")
        #expect(capability.properties[1].propertyName == "productDescription")
        #expect(capability.properties[2].propertyName == "price")

        #expect(capability.properties[1].constraints?.minLength == 50)
        #expect(capability.properties[1].constraints?.additionalConstraints["tone"] == "professional")
    }

    @Test("DataStructureCapability is Sendable")
    func testSendable() async {
        let capability = DataStructureCapability.model(
            TestProduct.self,
            properties: []
        )

        await Task {
            // Should compile without warnings due to Sendable conformance
            let _ = capability.modelType
        }.value
    }

    @Test("PropertyCapability works with multiple property types")
    func testPropertyCapabilityWithMultipleTypes() {
        let stringProp = PropertyCapability.property(\TestProduct.name)
        let doubleProp = PropertyCapability.property(\TestProduct.price)

        #expect(stringProp.propertyName == "name")
        #expect(doubleProp.propertyName == "price")
    }
}
