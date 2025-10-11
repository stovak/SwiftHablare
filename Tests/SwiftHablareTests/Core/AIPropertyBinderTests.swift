import Testing
import SwiftData
import Foundation
@testable import SwiftHablare

@Suite(.serialized)
struct AIPropertyBinderTests {

    // MARK: - Test Models

    @Model
    final class TestArticle {
        var title: String = ""
        var content: String = ""
        var wordCount: Int = 0
        var publishedAt: Date?
        var tags: [String] = []

        init(title: String = "", content: String = "") {
            self.title = title
            self.content = content
        }
    }

    @Model
    final class TestProduct {
        var name: String = ""
        var price: Double = 0.0
        var inStock: Bool = false
        var imageData: Data?

        init(name: String = "") {
            self.name = name
        }
    }

    // MARK: - String Binding Tests

    @Test("AIPropertyBinder binds string to string property")
    func testBindStringToString() async throws {
        let binder = AIPropertyBinder()
        let article = TestArticle()
        let context = try ModelContext(ModelContainer(for: TestArticle.self))

        try binder.bind(
            value: "Test Title",
            to: article,
            property: \TestArticle.title,
            context: context
        )

        #expect(article.title == "Test Title")
    }

    @Test("AIPropertyBinder converts string to int")
    func testBindStringToInt() async throws {
        let binder = AIPropertyBinder()
        let article = TestArticle()
        let context = try ModelContext(ModelContainer(for: TestArticle.self))

        try binder.bind(
            value: "42",
            to: article,
            property: \TestArticle.wordCount,
            context: context
        )

        #expect(article.wordCount == 42)
    }

    @Test("AIPropertyBinder converts string to bool")
    func testBindStringToBool() async throws {
        let binder = AIPropertyBinder()
        let product = TestProduct()
        let context = try ModelContext(ModelContainer(for: TestProduct.self))

        // Test "true"
        try binder.bind(
            value: "true",
            to: product,
            property: \TestProduct.inStock,
            context: context
        )
        #expect(product.inStock == true)

        // Test "false"
        try binder.bind(
            value: "false",
            to: product,
            property: \TestProduct.inStock,
            context: context
        )
        #expect(product.inStock == false)

        // Test "yes"
        try binder.bind(
            value: "yes",
            to: product,
            property: \TestProduct.inStock,
            context: context
        )
        #expect(product.inStock == true)
    }

    @Test("AIPropertyBinder converts string to double")
    func testBindStringToDouble() async throws {
        let binder = AIPropertyBinder()
        let product = TestProduct()
        let context = try ModelContext(ModelContainer(for: TestProduct.self))

        try binder.bind(
            value: "19.99",
            to: product,
            property: \TestProduct.price,
            context: context
        )

        #expect(product.price == 19.99)
    }

    @Test("AIPropertyBinder converts string to Data")
    func testBindStringToData() async throws {
        let binder = AIPropertyBinder()
        let product = TestProduct()
        let context = try ModelContext(ModelContainer(for: TestProduct.self))

        try binder.bind(
            value: "Hello, World!",
            to: product,
            property: \TestProduct.imageData,
            context: context
        )

        #expect(product.imageData != nil)
        #expect(String(data: product.imageData!, encoding: .utf8) == "Hello, World!")
    }

    // MARK: - Number Binding Tests

    @Test("AIPropertyBinder binds int to int property")
    func testBindIntToInt() async throws {
        let binder = AIPropertyBinder()
        let article = TestArticle()
        let context = try ModelContext(ModelContainer(for: TestArticle.self))

        try binder.bind(
            value: 100,
            to: article,
            property: \TestArticle.wordCount,
            context: context
        )

        #expect(article.wordCount == 100)
    }

    @Test("AIPropertyBinder converts int to double")
    func testBindIntToDouble() async throws {
        let binder = AIPropertyBinder()
        let product = TestProduct()
        let context = try ModelContext(ModelContainer(for: TestProduct.self))

        try binder.bind(
            value: 42,
            to: product,
            property: \TestProduct.price,
            context: context
        )

        #expect(product.price == 42.0)
    }

    @Test("AIPropertyBinder converts double to int")
    func testBindDoubleToInt() async throws {
        let binder = AIPropertyBinder()
        let article = TestArticle()
        let context = try ModelContext(ModelContainer(for: TestArticle.self))

        try binder.bind(
            value: 42.7,
            to: article,
            property: \TestArticle.wordCount,
            context: context
        )

        #expect(article.wordCount == 42)
    }

    // MARK: - Data Binding Tests

    @Test("AIPropertyBinder binds Data to Data property")
    func testBindDataToData() async throws {
        let binder = AIPropertyBinder()
        let product = TestProduct()
        let context = try ModelContext(ModelContainer(for: TestProduct.self))

        let testData = "Test Data".data(using: .utf8)!

        try binder.bind(
            value: testData,
            to: product,
            property: \TestProduct.imageData,
            context: context
        )

        #expect(product.imageData == testData)
    }

    @Test("AIPropertyBinder converts Data to String")
    func testBindDataToString() async throws {
        let binder = AIPropertyBinder()
        let article = TestArticle()
        let context = try ModelContext(ModelContainer(for: TestArticle.self))

        let testData = "Test Content".data(using: .utf8)!

        try binder.bind(
            value: testData,
            to: article,
            property: \TestArticle.content,
            context: context
        )

        #expect(article.content == "Test Content")
    }

    // MARK: - Error Handling Tests

    @Test("AIPropertyBinder throws on invalid conversion")
    func testBindInvalidConversion() async throws {
        let binder = AIPropertyBinder()
        let article = TestArticle()
        let context = try ModelContext(ModelContainer(for: TestArticle.self))

        do {
            try binder.bind(
                value: "not a number",
                to: article,
                property: \TestArticle.wordCount,
                context: context
            )
            Issue.record("Expected dataBindingError")
        } catch let error as AIServiceError {
            if case .dataBindingError = error {
                // Expected
            } else {
                Issue.record("Expected dataBindingError, got \(error)")
            }
        }
    }

    @Test("AIPropertyBinder throws on incompatible types")
    func testBindIncompatibleTypes() async throws {
        let binder = AIPropertyBinder()
        let article = TestArticle()
        let context = try ModelContext(ModelContainer(for: TestArticle.self))

        do {
            // Try to bind an array to a string property
            try binder.bind(
                value: [1, 2, 3],
                to: article,
                property: \TestArticle.title,
                context: context
            )
            Issue.record("Expected dataBindingError")
        } catch let error as AIServiceError {
            if case .dataBindingError = error {
                // Expected
            } else {
                Issue.record("Expected dataBindingError, got \(error)")
            }
        }
    }

    // MARK: - Edge Cases

    @Test("AIPropertyBinder handles empty string")
    func testBindEmptyString() async throws {
        let binder = AIPropertyBinder()
        let article = TestArticle()
        let context = try ModelContext(ModelContainer(for: TestArticle.self))

        try binder.bind(
            value: "",
            to: article,
            property: \TestArticle.title,
            context: context
        )

        #expect(article.title == "")
    }

    @Test("AIPropertyBinder handles zero values")
    func testBindZeroValues() async throws {
        let binder = AIPropertyBinder()
        let article = TestArticle()
        let context = try ModelContext(ModelContainer(for: TestArticle.self))

        try binder.bind(
            value: 0,
            to: article,
            property: \TestArticle.wordCount,
            context: context
        )

        #expect(article.wordCount == 0)
    }
}
