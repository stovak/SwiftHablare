import Testing
import Foundation
import SwiftData
@testable import SwiftHablare

@Suite(.serialized)
@MainActor
struct AIDataCoordinatorTests {

    // MARK: - Test Model

    @Model
    final class TestArticleForDataCoordinator {
        var id: UUID
        var title: String
        var content: String
        var summary: String
        var imageData: Data
        var metadata: String

        init(id: UUID = UUID(), title: String = "", content: String = "", summary: String = "", imageData: Data = Data(), metadata: String = "") {
            self.id = id
            self.title = title
            self.content = content
            self.summary = summary
            self.imageData = imageData
            self.metadata = metadata
        }
    }

    // MARK: - Helper Methods

    private func createTestContainer() throws -> ModelContainer {
        try TestHelpers.testContainer(for: TestArticleForDataCoordinator.self)
    }

    private func createSuccessResponse(content: ResponseContent, requestID: UUID = UUID()) -> AIResponseData {
        AIResponseData(
            requestID: requestID,
            providerID: "test-provider",
            content: content,
            metadata: ["model": "test-model"]
        )
    }

    private func createErrorResponse(error: AIServiceError, requestID: UUID = UUID()) -> AIResponseData {
        AIResponseData(
            requestID: requestID,
            providerID: "test-provider",
            error: error,
            metadata: [:]
        )
    }

    // MARK: - Initialization Tests

    @Test("AIDataCoordinator initializes with default parameters")
    func testInitialization() {
        let coordinator = AIDataCoordinator()
        #expect(coordinator.willMergeResponse == nil)
        #expect(coordinator.didMergeResponse == nil)
        #expect(coordinator.didFailMerge == nil)
    }

    @Test("AIDataCoordinator initializes with custom validator and binder")
    func testInitializationWithCustomDependencies() {
        let validator = AIContentValidator()
        let binder = AIPropertyBinder()
        let coordinator = AIDataCoordinator(validator: validator, binder: binder)
        #expect(coordinator.willMergeResponse == nil)
    }

    // MARK: - Text Response Merge Tests

    @Test("AIDataCoordinator merges text response into String property")
    func testMergeTextResponse() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator(title: "Original Title")
        context.insert(article)

        let response = createSuccessResponse(content: .text("AI Generated Content"))

        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.content,
            context: context
        )

        #expect(article.content == "AI Generated Content")
    }

    @Test("AIDataCoordinator mergeTextResponse convenience method")
    func testMergeTextResponseConvenience() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createSuccessResponse(content: .text("Test Summary"))

        try await coordinator.mergeTextResponse(
            response,
            into: article,
            property: \.summary,
            context: context
        )

        #expect(article.summary == "Test Summary")
    }

    // MARK: - Data Response Merge Tests

    @Test("AIDataCoordinator merges data response into Data property")
    func testMergeDataResponse() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let testData = Data("Test Image Data".utf8)
        let response = createSuccessResponse(content: .data(testData))

        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.imageData,
            context: context
        )

        #expect(article.imageData == testData)
    }

    @Test("AIDataCoordinator mergeDataResponse convenience method")
    func testMergeDataResponseConvenience() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let testData = Data("Image Data".utf8)
        let response = createSuccessResponse(content: .data(testData))

        try await coordinator.mergeDataResponse(
            response,
            into: article,
            property: \.imageData,
            context: context
        )

        #expect(article.imageData == testData)
    }

    // MARK: - Audio and Image Response Tests

    @Test("AIDataCoordinator merges audio response")
    func testMergeAudioResponse() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let audioData = Data("Audio Data".utf8)
        let response = createSuccessResponse(content: .audio(audioData, format: .mp3))

        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.imageData,
            context: context
        )

        #expect(article.imageData == audioData)
    }

    @Test("AIDataCoordinator merges image response")
    func testMergeImageResponse() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let imageData = Data("Image Data".utf8)
        let response = createSuccessResponse(content: .image(imageData, format: .png))

        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.imageData,
            context: context
        )

        #expect(article.imageData == imageData)
    }

    // MARK: - Structured Response Tests

    @Test("AIDataCoordinator merges structured response")
    func testMergeStructuredResponse() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let structuredData: [String: SendableValue] = [
            "title": .string("Test Title"),
            "count": .int(42)
        ]
        let response = createSuccessResponse(content: .structured(structuredData))

        // Structured data gets stored in metadata as String (JSON encoded)
        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.metadata,
            context: context,
            transform: { content in
                // Convert structured to string for metadata field
                if let data = content.dataContent,
                   let string = String(data: data, encoding: .utf8) {
                    return string
                }
                return "{}"
            }
        )

        #expect(article.metadata.isEmpty == false)
    }

    // MARK: - Error Handling Tests

    @Test("AIDataCoordinator throws error for failed response")
    func testMergeFailedResponse() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createErrorResponse(error: .providerError("Test error"))

        await #expect(throws: AIServiceError.self) {
            try await coordinator.mergeResponse(
                response,
                into: article,
                property: \.content,
                context: context
            )
        }
    }

    @Test("AIDataCoordinator throws error when text response is not text content")
    func testMergeTextResponseWithNonTextContent() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createSuccessResponse(content: .data(Data("test".utf8)))

        await #expect(throws: AIServiceError.self) {
            try await coordinator.mergeTextResponse(
                response,
                into: article,
                property: \.content,
                context: context
            )
        }
    }

    // MARK: - Callback Tests

    @Test("AIDataCoordinator invokes willMergeResponse callback")
    func testWillMergeResponseCallback() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        var callbackInvoked = false
        coordinator.willMergeResponse = { _ in
            callbackInvoked = true
        }

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createSuccessResponse(content: .text("Test"))

        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.content,
            context: context
        )

        #expect(callbackInvoked == true)
    }

    @Test("AIDataCoordinator invokes didMergeResponse callback on success")
    func testDidMergeResponseCallback() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        var callbackInvoked = false
        var receivedResponse: AIResponseData?
        coordinator.didMergeResponse = { response in
            callbackInvoked = true
            receivedResponse = response
        }

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createSuccessResponse(content: .text("Test"))

        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.content,
            context: context
        )

        #expect(callbackInvoked == true)
        #expect(receivedResponse?.requestID == response.requestID)
    }

    @Test("AIDataCoordinator invokes didFailMerge callback on error")
    func testDidFailMergeCallback() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        var callbackInvoked = false
        var receivedError: Error?
        coordinator.didFailMerge = { _, error in
            callbackInvoked = true
            receivedError = error
        }

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createErrorResponse(error: .providerError("Test error"))

        do {
            try await coordinator.mergeResponse(
                response,
                into: article,
                property: \.content,
                context: context
            )
        } catch {
            // Expected to throw
        }

        #expect(callbackInvoked == true)
        #expect(receivedError != nil)
    }

    // MARK: - Transform Tests

    @Test("AIDataCoordinator applies custom transform")
    func testCustomTransform() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createSuccessResponse(content: .text("lowercase text"))

        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.content,
            context: context,
            transform: { content in
                guard let text = content.text else {
                    throw AIServiceError.dataConversionError("Not text")
                }
                return text.uppercased()
            }
        )

        #expect(article.content == "LOWERCASE TEXT")
    }

    @Test("AIDataCoordinator transform error propagates")
    func testTransformError() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createSuccessResponse(content: .text("test"))

        await #expect(throws: AIServiceError.self) {
            try await coordinator.mergeResponse(
                response,
                into: article,
                property: \.content,
                context: context,
                transform: { _ in
                    throw AIServiceError.dataConversionError("Transform failed")
                }
            )
        }
    }

    // MARK: - Validation Tests

    @Test("AIDataCoordinator validates response with constraints")
    func testValidationWithConstraints() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createSuccessResponse(content: .text("Valid content"))

        // This test validates that validation is called, actual validation logic tested in AIContentValidatorTests
        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.content,
            context: context,
            constraints: ["minLength": "5"]
        )

        #expect(article.content == "Valid content")
    }

    @Test("AIDataCoordinator validateResponse checks success")
    func testValidateResponseSuccess() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .text("Test"))

        // Should not throw
        try await coordinator.validateResponse(response, constraints: [:])
    }

    @Test("AIDataCoordinator validateResponse throws for failed response")
    func testValidateResponseFailure() async throws {
        let coordinator = AIDataCoordinator()

        let response = createErrorResponse(error: .providerError("Test"))

        await #expect(throws: AIServiceError.self) {
            try await coordinator.validateResponse(response, constraints: [:])
        }
    }

    @Test("AIDataCoordinator validates text content")
    func testValidateTextContent() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .text("Test text"))

        try await coordinator.validateResponse(response, constraints: [:])
    }

    @Test("AIDataCoordinator validates data content")
    func testValidateDataContent() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .data(Data("test".utf8)))

        try await coordinator.validateResponse(response, constraints: [:])
    }

    @Test("AIDataCoordinator validates audio content")
    func testValidateAudioContent() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .audio(Data("audio".utf8), format: .mp3))

        try await coordinator.validateResponse(response, constraints: [:])
    }

    @Test("AIDataCoordinator validates image content")
    func testValidateImageContent() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .image(Data("image".utf8), format: .png))

        try await coordinator.validateResponse(response, constraints: [:])
    }

    @Test("AIDataCoordinator validates structured content")
    func testValidateStructuredContent() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .structured(["key": .string("value")]))

        try await coordinator.validateResponse(response, constraints: [:])
    }

    // MARK: - Batch Operation Tests

    @Test("AIDataCoordinator mergeBatch processes multiple responses")
    func testMergeBatch() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article1 = TestArticleForDataCoordinator()
        let article2 = TestArticleForDataCoordinator()
        let article3 = TestArticleForDataCoordinator()
        context.insert(article1)
        context.insert(article2)
        context.insert(article3)

        let responses = [
            createSuccessResponse(content: .text("Content 1")),
            createSuccessResponse(content: .text("Content 2")),
            createSuccessResponse(content: .text("Content 3"))
        ]

        let results = await coordinator.mergeBatch(
            responses: responses,
            into: [article1, article2, article3],
            property: \.content,
            context: context
        )

        #expect(results.count == 3)
        for result in results {
            switch result {
            case .success:
                #expect(Bool(true))
            case .failure:
                #expect(Bool(false), "Expected success but got failure")
            }
        }
        #expect(article1.content == "Content 1")
        #expect(article2.content == "Content 2")
        #expect(article3.content == "Content 3")
    }

    @Test("AIDataCoordinator mergeBatch handles partial failures")
    func testMergeBatchPartialFailure() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article1 = TestArticleForDataCoordinator()
        let article2 = TestArticleForDataCoordinator()
        let article3 = TestArticleForDataCoordinator()
        context.insert(article1)
        context.insert(article2)
        context.insert(article3)

        let responses = [
            createSuccessResponse(content: .text("Content 1")),
            createErrorResponse(error: .providerError("Error")),
            createSuccessResponse(content: .text("Content 3"))
        ]

        let results = await coordinator.mergeBatch(
            responses: responses,
            into: [article1, article2, article3],
            property: \.content,
            context: context
        )

        #expect(results.count == 3)
        switch results[0] {
        case .success: #expect(Bool(true))
        case .failure: #expect(Bool(false), "Expected success")
        }
        switch results[1] {
        case .success: #expect(Bool(false), "Expected failure")
        case .failure: #expect(Bool(true))
        }
        switch results[2] {
        case .success: #expect(Bool(true))
        case .failure: #expect(Bool(false), "Expected success")
        }
        #expect(article1.content == "Content 1")
        #expect(article2.content == "")
        #expect(article3.content == "Content 3")
    }

    @Test("AIDataCoordinator mergeBatch validates count mismatch")
    func testMergeBatchCountMismatch() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article1 = TestArticleForDataCoordinator()
        context.insert(article1)

        let responses = [
            createSuccessResponse(content: .text("Content 1")),
            createSuccessResponse(content: .text("Content 2"))
        ]

        let results = await coordinator.mergeBatch(
            responses: responses,
            into: [article1],
            property: \.content,
            context: context
        )

        #expect(results.count == 2)
        for result in results {
            switch result {
            case .success: #expect(Bool(false), "Expected failure")
            case .failure: #expect(Bool(true))
            }
        }
    }

    // MARK: - Process Response Tests

    @Test("AIDataCoordinator processResponse extracts String")
    func testProcessResponseString() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .text("Test String"))

        let result: String = try coordinator.processResponse(response, as: String.self)

        #expect(result == "Test String")
    }

    @Test("AIDataCoordinator processResponse extracts Data")
    func testProcessResponseData() async throws {
        let coordinator = AIDataCoordinator()

        let testData = Data("Test Data".utf8)
        let response = createSuccessResponse(content: .data(testData))

        let result: Data = try coordinator.processResponse(response, as: Data.self)

        #expect(result == testData)
    }

    @Test("AIDataCoordinator processResponse with transform")
    func testProcessResponseWithTransform() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .text("42"))

        let result: Int = try coordinator.processResponse(response, as: Int.self) { content in
            guard let text = content.text, let number = Int(text) else {
                throw AIServiceError.dataConversionError("Cannot convert to Int")
            }
            return number
        }

        #expect(result == 42)
    }

    @Test("AIDataCoordinator processResponse throws for failed response")
    func testProcessResponseFailed() async throws {
        let coordinator = AIDataCoordinator()

        let response = createErrorResponse(error: .providerError("Error"))

        #expect(throws: AIServiceError.self) {
            let _: String = try coordinator.processResponse(response, as: String.self)
        }
    }

    @Test("AIDataCoordinator processResponse converts String to Data")
    func testProcessResponseStringToData() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .text("Test"))

        let result: Data = try coordinator.processResponse(response, as: Data.self)

        #expect(result == Data("Test".utf8))
    }

    @Test("AIDataCoordinator processResponse converts Data to String")
    func testProcessResponseDataToString() async throws {
        let coordinator = AIDataCoordinator()

        let response = createSuccessResponse(content: .data(Data("Test".utf8)))

        let result: String = try coordinator.processResponse(response, as: String.self)

        #expect(result == "Test")
    }

    // MARK: - Validation Rule Registration Tests

    @Test("AIDataCoordinator registers custom validation rule")
    func testRegisterValidationRule() {
        let coordinator = AIDataCoordinator()

        let rule = AIContentValidator.ValidationRule(
            name: "custom",
            validate: { _ in true },
            errorMessage: "Custom validation failed"
        )

        coordinator.registerValidationRule(rule)
        // If this doesn't crash, the rule was registered
    }

    // MARK: - Context Save Tests

    @Test("AIDataCoordinator saves context after merge")
    func testContextSave() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let response = createSuccessResponse(content: .text("Saved Content"))

        try await coordinator.mergeResponse(
            response,
            into: article,
            property: \.content,
            context: context
        )

        // Verify the model was saved by checking it can be fetched
        let descriptor = FetchDescriptor<TestArticleForDataCoordinator>()
        let articles = try context.fetch(descriptor)

        #expect(articles.count == 1)
        #expect(articles.first?.content == "Saved Content")
    }

    // MARK: - Multiple Response Merge Tests

    @Test("AIDataCoordinator mergeMultipleResponses throws unsupported")
    func testMergeMultipleResponses() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let article = TestArticleForDataCoordinator()
        context.insert(article)

        let responses: [(response: AIResponseData, property: PartialKeyPath<TestArticleForDataCoordinator>)] = [
            (createSuccessResponse(content: .text("Title")), \TestArticleForDataCoordinator.title),
            (createSuccessResponse(content: .text("Content")), \TestArticleForDataCoordinator.content)
        ]

        #expect(throws: AIServiceError.self) {
            try coordinator.mergeMultipleResponses(responses, into: article, context: context)
        }
    }

    @Test("AIDataCoordinator createAndMergeResponse throws unsupported")
    func testCreateAndMergeResponse() async throws {
        let coordinator = AIDataCoordinator()
        let container = try createTestContainer()
        let context = ModelContext(container)

        let response = createSuccessResponse(content: .text("Test"))

        #expect(throws: AIServiceError.self) {
            let _: TestArticleForDataCoordinator = try coordinator.createAndMergeResponse(
                response,
                modelType: TestArticleForDataCoordinator.self,
                property: \.content,
                context: context
            )
        }
    }
}
