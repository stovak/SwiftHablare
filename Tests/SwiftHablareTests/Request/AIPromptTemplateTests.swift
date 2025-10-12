import Testing
import Foundation
@testable import SwiftHablare

struct AIPromptTemplateTests {

    @Test("AIPromptTemplate renders simple template")
    func testSimpleRender() throws {
        let template = AIPromptTemplate(template: "Hello {{name}}!")

        let result = try template.render(variables: ["name": "World"])

        #expect(result == "Hello World!")
    }

    @Test("AIPromptTemplate renders with multiple variables")
    func testMultipleVariables() throws {
        let template = AIPromptTemplate(
            template: "Generate a {{style}} {{type}} about {{topic}}"
        )

        let result = try template.render(variables: [
            "style": "professional",
            "type": "article",
            "topic": "AI"
        ])

        #expect(result == "Generate a professional article about AI")
    }

    @Test("AIPromptTemplate renders with spaces around variables")
    func testVariablesWithSpaces() throws {
        let template = AIPromptTemplate(template: "Hello {{ name }}!")

        let result = try template.render(variables: ["name": "World"])

        #expect(result == "Hello World!")
    }

    @Test("AIPromptTemplate uses default values")
    func testDefaultValues() throws {
        let template = AIPromptTemplate(
            template: "Style: {{style}}, Topic: {{topic}}",
            defaultValues: ["style": "casual"]
        )

        let result = try template.render(variables: ["topic": "testing"])

        #expect(result == "Style: casual, Topic: testing")
    }

    @Test("AIPromptTemplate provided values override defaults")
    func testOverrideDefaults() throws {
        let template = AIPromptTemplate(
            template: "Style: {{style}}",
            defaultValues: ["style": "casual"]
        )

        let result = try template.render(variables: ["style": "formal"])

        #expect(result == "Style: formal")
    }

    @Test("AIPromptTemplate throws on missing required variable")
    func testMissingVariable() {
        let template = AIPromptTemplate(template: "Hello {{name}}!")

        #expect(throws: AIServiceError.self) {
            _ = try template.render(variables: [:])
        }
    }

    @Test("AIPromptTemplate extracts variables")
    func testExtractVariables() {
        let template = AIPromptTemplate(
            template: "{{a}} and {{b}} and {{c}}"
        )

        let variables = template.extractVariables()

        #expect(variables == Set(["a", "b", "c"]))
    }

    @Test("AIPromptTemplate extracts unique variables")
    func testExtractUniqueVariables() {
        let template = AIPromptTemplate(
            template: "{{name}} said hello to {{name}}"
        )

        let variables = template.extractVariables()

        #expect(variables == Set(["name"]))
    }

    @Test("AIPromptTemplate validates with all variables")
    func testValidateSuccess() {
        let template = AIPromptTemplate(template: "{{a}} {{b}}")

        let isValid = template.validate(variables: ["a": "1", "b": "2"])

        #expect(isValid == true)
    }

    @Test("AIPromptTemplate validates with defaults")
    func testValidateWithDefaults() {
        let template = AIPromptTemplate(
            template: "{{a}} {{b}}",
            defaultValues: ["a": "default"]
        )

        let isValid = template.validate(variables: ["b": "2"])

        #expect(isValid == true)
    }

    @Test("AIPromptTemplate validates fails with missing variables")
    func testValidateFails() {
        let template = AIPromptTemplate(template: "{{a}} {{b}}")

        let isValid = template.validate(variables: ["a": "1"])

        #expect(isValid == false)
    }

    @Test("AIPromptTemplate creates request")
    func testCreateRequest() throws {
        let template = AIPromptTemplate(template: "Hello {{name}}!")

        let request = try template.createRequest(
            variables: ["name": "World"],
            parameters: ["temperature": "0.7"],
            timeout: 30.0,
            useCache: false
        )

        #expect(request.prompt == "Hello World!")
        #expect(request.parameters["temperature"] == "0.7")
        #expect(request.timeout == 30.0)
        #expect(request.useCache == false)
    }

    @Test("AIPromptTemplate simple factory")
    func testSimpleFactory() throws {
        let template = AIPromptTemplate.simple("Hello {{name}}!")

        let result = try template.render(variables: ["name": "World"])

        #expect(result == "Hello World!")
    }

    @Test("AIPromptTemplate withDefaults factory")
    func testWithDefaultsFactory() throws {
        let template = AIPromptTemplate.withDefaults(
            "Style: {{style}}",
            commonVariables: ["style": "default"]
        )

        let result = try template.render(variables: [:])

        #expect(result == "Style: default")
    }

    @Test("AIPromptTemplate handles empty template")
    func testEmptyTemplate() throws {
        let template = AIPromptTemplate(template: "")

        let result = try template.render(variables: [:])

        #expect(result == "")
    }

    @Test("AIPromptTemplate handles template with no variables")
    func testNoVariables() throws {
        let template = AIPromptTemplate(template: "Hello World!")

        let result = try template.render(variables: [:])

        #expect(result == "Hello World!")
    }

    @Test("AIPromptTemplate is Sendable")
    func testSendable() async {
        let template = AIPromptTemplate(template: "{{test}}")

        await Task {
            // Should compile without warnings
            let _ = template.template
        }.value
    }
}
