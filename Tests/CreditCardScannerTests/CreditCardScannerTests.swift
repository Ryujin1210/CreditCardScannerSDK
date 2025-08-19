import XCTest
@testable import CreditCardScanner

/// CreditCardScanner SDK 테스트
final class CreditCardScannerTests: XCTestCase {
    
    /// 룬 알고리즘 테스트
    func testLuhnAlgorithm() {
        // 유효한 카드 번호들
        let validCardNumbers = [
            "4111111111111111", // Visa 테스트 카드
            "5555555555554444", // Mastercard 테스트 카드
            "378282246310005",  // American Express 테스트 카드
            "6011111111111117"  // Discover 테스트 카드
        ]
        
        for cardNumber in validCardNumbers {
            XCTAssertTrue(
                CreditCardValidator.isValidCardNumber(cardNumber),
                "카드 번호 \(cardNumber)는 유효해야 합니다"
            )
        }
        
        // 무효한 카드 번호들
        let invalidCardNumbers = [
            "4111111111111112", // 마지막 자리가 틀림
            "1234567890123456", // 임의의 번호
            "0000000000000000", // 모두 0
            "1111111111111111"  // 모두 1
        ]
        
        for cardNumber in invalidCardNumbers {
            XCTAssertFalse(
                CreditCardValidator.isValidCardNumber(cardNumber),
                "카드 번호 \(cardNumber)는 무효해야 합니다"
            )
        }
    }
    
    /// 카드 타입 식별 테스트
    func testCardTypeIdentification() {
        let testCases = [
            ("4111111111111111", CardType.visa),
            ("5555555555554444", CardType.mastercard),
            ("378282246310005", CardType.americanExpress),
            ("6011111111111117", CardType.discover),
            ("1234567890123456", CardType.unknown)
        ]
        
        for (cardNumber, expectedType) in testCases {
            let identifiedType = CreditCardValidator.identifyCardType(cardNumber)
            XCTAssertEqual(
                identifiedType,
                expectedType,
                "카드 번호 \(cardNumber)의 타입은 \(expectedType.rawValue)이어야 합니다"
            )
        }
    }
    
    /// 카드 번호 포맷팅 테스트
    func testCardNumberFormatting() {
        let testCases = [
            ("4111111111111111", "4111 1111 1111 1111"),
            ("5555-5555-5555-4444", "5555 5555 5555 4444"),
            ("378282246310005", "3782 8224 6310 005")
        ]
        
        for (input, expected) in testCases {
            let formatted = CreditCardValidator.formatCardNumber(input)
            XCTAssertEqual(
                formatted,
                expected,
                "카드 번호 \(input)의 포맷팅 결과는 \(expected)이어야 합니다"
            )
        }
    }
    
    /// 숫자 추출 테스트
    func testDigitExtraction() {
        let testCases = [
            ("4111-1111-1111-1111", "4111111111111111"),
            ("4111 1111 1111 1111", "4111111111111111"),
            ("Card: 4111111111111111", "4111111111111111"),
            ("abc123def456", "123456")
        ]
        
        for (input, expected) in testCases {
            let extracted = CreditCardValidator.extractDigits(from: input)
            XCTAssertEqual(
                extracted,
                expected,
                "문자열 \(input)에서 추출된 숫자는 \(expected)이어야 합니다"
            )
        }
    }
    
    /// 보안 데이터 암호화/복호화 테스트
    func testSecureCardData() {
        let cardNumber = "4111111111111111"
        let expiryDate = "12/2025"
        
        let secureData = SecurityManager.secureCardData(
            cardNumber: cardNumber,
            expiryDate: expiryDate
        )
        
        // 복호화 테스트
        XCTAssertEqual(secureData.cardNumber, cardNumber, "복호화된 카드 번호가 일치해야 합니다")
        XCTAssertEqual(secureData.expiryDate, expiryDate, "복호화된 유효기간이 일치해야 합니다")
        
        // 마스킹 테스트
        let maskedNumber = secureData.maskedCardNumber
        XCTAssertNotNil(maskedNumber, "마스킹된 카드 번호가 생성되어야 합니다")
        XCTAssertTrue(maskedNumber!.contains("****"), "마스킹된 카드 번호에는 *가 포함되어야 합니다")
        XCTAssertTrue(maskedNumber!.hasPrefix("4111"), "마스킹된 카드 번호는 앞 4자리를 보여야 합니다")
        XCTAssertTrue(maskedNumber!.hasSuffix("1111"), "마스킹된 카드 번호는 뒤 4자리를 보여야 합니다")
    }
    
    /// 보안 검증 테스트
    func testSecurityValidation() {
        // 유효한 카드
        let validCardData = SecurityManager.secureCardData(
            cardNumber: "4111111111111111",
            expiryDate: "12/2025"
        )
        
        let validResult = SecurityManager.validateSecureCardData(validCardData)
        XCTAssertTrue(validResult.isValid, "유효한 카드 데이터는 검증을 통과해야 합니다")
        
        // 무효한 카드 (잘못된 번호)
        let invalidCardData = SecurityManager.secureCardData(
            cardNumber: "1234567890123456",
            expiryDate: "12/2025"
        )
        
        let invalidResult = SecurityManager.validateSecureCardData(invalidCardData)
        XCTAssertFalse(invalidResult.isValid, "무효한 카드 데이터는 검증에 실패해야 합니다")
        XCTAssertTrue(
            invalidResult.securityIssues.contains(.invalidCardNumber),
            "무효한 카드 번호 이슈가 감지되어야 합니다"
        )
    }
    
    /// SDK 설정 테스트
    func testSDKConfiguration() {
        let customConfig = CreditCardScanner.Configuration(
            isAutoScanEnabled: true,
            confidenceThreshold: 0.9,
            isSecurityValidationEnabled: false,
            allowTestCards: true,
            cameraQuality: .veryHigh
        )
        
        let scanner = CreditCardScanner(configuration: customConfig)
        
        XCTAssertEqual(scanner.configuration.confidenceThreshold, 0.9)
        XCTAssertTrue(scanner.configuration.isAutoScanEnabled)
        XCTAssertFalse(scanner.configuration.isSecurityValidationEnabled)
        XCTAssertTrue(scanner.configuration.allowTestCards)
        XCTAssertEqual(scanner.configuration.cameraQuality, .veryHigh)
    }
    
    /// 에러 메시지 테스트
    func testErrorMessages() {
        let errors: [ScanError] = [
            .cameraNotAvailable,
            .permissionDenied,
            .processingError,
            .lowConfidence(0.5),
            .incompleteData,
            .userCancelled,
            .testCardNotAllowed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "모든 에러는 설명이 있어야 합니다")
        }
    }
    
    /// 성능 테스트
    func testPerformance() {
        let cardNumbers = Array(repeating: "4111111111111111", count: 1000)
        
        measure {
            for cardNumber in cardNumbers {
                _ = CreditCardValidator.isValidCardNumber(cardNumber)
            }
        }
    }
    
    /// 메모리 누수 테스트
    func testMemoryManagement() {
        weak var weakScanner: CreditCardScanner?
        
        autoreleasepool {
            let scanner = CreditCardScanner()
            weakScanner = scanner
            
            // 스캐너 사용
            _ = scanner.createCameraViewController { _ in }
        }
        
        // 메모리에서 해제되었는지 확인
        XCTAssertNil(weakScanner, "스캐너는 메모리에서 해제되어야 합니다")
    }
    
    /// 동시성 테스트
    func testConcurrency() {
        let expectation = self.expectation(description: "Concurrent validation")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        for i in 0..<10 {
            queue.async {
                let cardNumber = "411111111111111\(i % 2)" // 절반은 유효, 절반은 무효
                _ = CreditCardValidator.isValidCardNumber(cardNumber)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    /// 엣지 케이스 테스트
    func testEdgeCases() {
        // 빈 문자열
        XCTAssertFalse(CreditCardValidator.isValidCardNumber(""))
        
        // 너무 짧은 번호
        XCTAssertFalse(CreditCardValidator.isValidCardNumber("123"))
        
        // 너무 긴 번호
        XCTAssertFalse(CreditCardValidator.isValidCardNumber("12345678901234567890"))
        
        // 문자가 포함된 번호
        XCTAssertFalse(CreditCardValidator.isValidCardNumber("411a111111111111"))
        
        // 특수문자만 포함
        XCTAssertEqual(CreditCardValidator.extractDigits(from: "!@#$%^&*()"), "")
    }
}