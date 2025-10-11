import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

struct AIGeneratableTests {

    // Test model implementing AIGeneratable
    @Model
    final class TestArticle: AIGeneratable {
        var title: String = ""
        var content: String = ""
        var summary: String = ""

        static var aiGenerationSchema: AIGenerationSchema {
            AIGenerationSchema {
                AIProperty(\TestArticle.title)
                    .providers(["openai", "anthropic"])
                    .constraints(minLength: 10, maxLength: 100)
                    .promptTemplate("Generate a title for: {content}")
                    .required()

                AIProperty(\TestArticle.content)
                    .providers(["openai"])
                    .constraints(minLength: 100, maxLength: 5000)
                    .optional()

                AIProperty(\TestArticle.summary)
                    .providers(["openai", "anthropic"])
                    .inputProperty("content")
                    .constraints(maxLength: 200)
            }
        }

        init(title: String = "", content: String = "", summary: String = "") {
            self.title = title
            self.content = content
            self.summary = summary
        }
    }

    @Test("AIGenerationSchema can be constructed")
    func testSchemaConstruction() {
        let schema = TestArticle.aiGenerationSchema

        #expect(schema.properties.count == 3)
    }

    @Test("AIProperty stores property information correctly")
    func testAIPropertySpec() {
        let property = AIProperty(\TestArticle.title)
            .providers(["openai", "anthropic"])
            .constraints(minLength: 10, maxLength: 100)
            .promptTemplate("Test template")
            .required()

        #expect(property.propertyName == "title")
        #expect(property.allowedProviders == ["openai", "anthropic"])
        #expect(property.minLength == 10)
        #expect(property.maxLength == 100)
        #expect(property.promptTemplate == "Test template")
        #expect(property.required == true)
    }

    @Test("AIProperty optional() method works")
    func testAIPropertyOptional() {
        let property = AIProperty(\TestArticle.content)
            .optional()

        #expect(property.required == false)
    }

    @Test("AIProperty inputProperty works")
    func testAIPropertyInputProperty() {
        let property = AIProperty(\TestArticle.summary)
            .inputProperty("content")

        #expect(property.inputPropertyName == "content")
    }

    @Test("AIProperty addConstraint works")
    func testAIPropertyAddConstraint() {
        let property = AIProperty(\TestArticle.title)
            .addConstraint(key: "tone", value: "professional")
            .addConstraint(key: "format", value: "markdown")

        #expect(property.additionalConstraints["tone"] == "professional")
        #expect(property.additionalConstraints["format"] == "markdown")
    }

    @Test("AIGenerationSchemaBuilder builds correctly")
    func testSchemaBuilder() {
        let schema = AIGenerationSchema {
            AIProperty(\TestArticle.title)
            AIProperty(\TestArticle.content)
            AIProperty(\TestArticle.summary)
        }

        #expect(schema.properties.count == 3)
        #expect(schema.properties[0].propertyName == "title")
        #expect(schema.properties[1].propertyName == "content")
        #expect(schema.properties[2].propertyName == "summary")
    }

    @Test("AIGenerationSchema can be constructed directly")
    func testSchemaDirectConstruction() {
        let properties = [
            AIProperty(\TestArticle.title),
            AIProperty(\TestArticle.content)
        ]

        let schema = AIGenerationSchema(properties: properties)

        #expect(schema.properties.count == 2)
    }

    @Test("Schema properties maintain configuration")
    func testSchemaPropertiesMaintainConfiguration() {
        let schema = TestArticle.aiGenerationSchema

        let titleProp = schema.properties.first { $0.propertyName == "title" }
        #expect(titleProp != nil)
        #expect(titleProp?.allowedProviders.contains("openai") == true)
        #expect(titleProp?.minLength == 10)
        #expect(titleProp?.maxLength == 100)
        #expect(titleProp?.required == true)

        let contentProp = schema.properties.first { $0.propertyName == "content" }
        #expect(contentProp != nil)
        #expect(contentProp?.required == false)

        let summaryProp = schema.properties.first { $0.propertyName == "summary" }
        #expect(summaryProp != nil)
        #expect(summaryProp?.inputPropertyName == "content")
    }

    @Test("AIPropertySpec builder methods are chainable")
    func testPropertySpecChaining() {
        let property = AIProperty(\TestArticle.title)
            .providers(["openai"])
            .constraints(minLength: 5, maxLength: 50)
            .promptTemplate("Generate: {title}")
            .required()
            .addConstraint(key: "style", value: "formal")

        #expect(property.propertyName == "title")
        #expect(property.allowedProviders == ["openai"])
        #expect(property.minLength == 5)
        #expect(property.maxLength == 50)
        #expect(property.promptTemplate == "Generate: {title}")
        #expect(property.required == true)
        #expect(property.additionalConstraints["style"] == "formal")
    }

    @Test("AIProperty without constraints")
    func testAIPropertyWithoutConstraints() {
        let property = AIProperty(\TestArticle.title)

        #expect(property.propertyName == "title")
        #expect(property.allowedProviders.isEmpty)
        #expect(property.minLength == nil)
        #expect(property.maxLength == nil)
        #expect(property.promptTemplate == nil)
        #expect(property.required == false)
        #expect(property.inputPropertyName == nil)
        #expect(property.transformFunction == nil)
        #expect(property.additionalConstraints.isEmpty)
    }

    @Test("AIPropertySpec is Sendable")
    func testAIPropertySpecSendable() async {
        let property = AIProperty(\TestArticle.title)

        await Task {
            // Should compile without warnings due to Sendable conformance
            let _ = property.propertyName
        }.value
    }

    @Test("AIGenerationSchema is Sendable")
    func testAIGenerationSchemaSendable() async {
        let schema = TestArticle.aiGenerationSchema

        await Task {
            // Should compile without warnings due to Sendable conformance
            let _ = schema.properties.count
        }.value
    }

    @Test("TestArticle schema has correct property count")
    func testSchemaPropertyCount() {
        let articleSchema = TestArticle.aiGenerationSchema

        #expect(articleSchema.properties.count == 3)
        #expect(articleSchema.properties[0].propertyName == "title")
        #expect(articleSchema.properties[1].propertyName == "content")
        #expect(articleSchema.properties[2].propertyName == "summary")
    }

    @Test("Property names are extracted correctly from KeyPath")
    func testPropertyNameExtraction() {
        let titleProp = AIProperty(\TestArticle.title)
        let contentProp = AIProperty(\TestArticle.content)
        let summaryProp = AIProperty(\TestArticle.summary)

        #expect(titleProp.propertyName == "title")
        #expect(contentProp.propertyName == "content")
        #expect(summaryProp.propertyName == "summary")
    }

    @Test("Constraints only for strings")
    func testConstraintsOnlyForStrings() {
        // This test verifies that constraints are optional and can be omitted
        let property = AIProperty(\TestArticle.title)
            .providers(["openai"])

        #expect(property.minLength == nil)
        #expect(property.maxLength == nil)

        // And that they can be set
        let constrained = property.constraints(minLength: 10, maxLength: 100)
        #expect(constrained.minLength == 10)
        #expect(constrained.maxLength == 100)
    }
}
