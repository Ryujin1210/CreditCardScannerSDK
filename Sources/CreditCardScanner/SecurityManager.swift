import Foundation
import CryptoKit

/// 보안 관리자 - 신용카드 정보의 안전한 처리를 담당
public class SecurityManager {
    
    /// 민감한 데이터를 안전하게 저장하는 구조체
    public struct SecureCardData {
        private let encryptedCardNumber: Data
        private let encryptedExpiryDate: Data
        private let symmetricKey: SymmetricKey
        
        /// 카드 번호 (복호화하여 반환)
        public var cardNumber: String? {
            return SecurityManager.decrypt(data: encryptedCardNumber, key: symmetricKey)
        }
        
        /// 유효기간 (복호화하여 반환)
        public var expiryDate: String? {
            return SecurityManager.decrypt(data: encryptedExpiryDate, key: symmetricKey)
        }
        
        /// 마스킹된 카드 번호 반환 (앞 4자리와 뒤 4자리만 표시)
        public var maskedCardNumber: String? {
            guard let cardNumber = self.cardNumber else { return nil }
            let cleanNumber = CreditCardValidator.extractDigits(from: cardNumber)
            
            if cleanNumber.count >= 8 {
                let first4 = String(cleanNumber.prefix(4))
                let last4 = String(cleanNumber.suffix(4))
                let middle = String(repeating: "*", count: cleanNumber.count - 8)
                return "\(first4)\(middle)\(last4)"
            }
            
            return String(repeating: "*", count: cleanNumber.count)
        }
        
        fileprivate init(cardNumber: String, expiryDate: String, key: SymmetricKey) {
            self.symmetricKey = key
            self.encryptedCardNumber = SecurityManager.encrypt(text: cardNumber, key: key)
            self.encryptedExpiryDate = SecurityManager.encrypt(text: expiryDate, key: key)
        }
    }
    
    /// 신용카드 정보를 안전하게 암호화하여 저장
    /// - Parameters:
    ///   - cardNumber: 카드 번호
    ///   - expiryDate: 유효기간
    /// - Returns: 암호화된 카드 데이터
    public static func secureCardData(cardNumber: String, expiryDate: String) -> SecureCardData {
        let key = SymmetricKey(size: .bits256)
        return SecureCardData(cardNumber: cardNumber, expiryDate: expiryDate, key: key)
    }
    
    /// 문자열을 AES-GCM으로 암호화
    /// - Parameters:
    ///   - text: 암호화할 텍스트
    ///   - key: 암호화 키
    /// - Returns: 암호화된 데이터
    private static func encrypt(text: String, key: SymmetricKey) -> Data {
        do {
            let data = Data(text.utf8)
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined ?? Data()
        } catch {
            return Data()
        }
    }
    
    /// AES-GCM으로 암호화된 데이터를 복호화
    /// - Parameters:
    ///   - data: 암호화된 데이터
    ///   - key: 복호화 키
    /// - Returns: 복호화된 문자열
    private static func decrypt(data: Data, key: SymmetricKey) -> String? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    /// 메모리에서 민감한 데이터를 안전하게 제거
    /// - Parameter string: 제거할 문자열의 메모리 주소
    public static func securelyWipeMemory(of string: inout String) {
        // Swift String의 메모리를 직접 조작하는 것은 제한적이므로
        // 새로운 더미 데이터로 덮어쓰기
        let dummyData = String(repeating: "0", count: string.count)
        string = dummyData
        string = ""
    }
    
    /// 임시 파일이나 캐시에서 민감한 데이터 흔적 제거
    public static func clearTemporaryData() {
        // UserDefaults에서 관련 데이터 제거
        let userDefaults = UserDefaults.standard
        let keysToRemove = userDefaults.dictionaryRepresentation().keys.filter {
            $0.contains("card") || $0.contains("credit") || $0.contains("scan")
        }
        
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
        
        // 메모리 캐시 정리
        URLCache.shared.removeAllCachedResponses()
        
        // 임시 디렉토리 정리
        clearTemporaryDirectory()
    }
    
    /// 임시 디렉토리에서 관련 파일들 제거
    private static func clearTemporaryDirectory() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil
            )
            
            for url in contents {
                if url.lastPathComponent.contains("card") ||
                   url.lastPathComponent.contains("scan") ||
                   url.lastPathComponent.contains("ocr") {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            // 에러 무시 (권한 문제 등)
        }
    }
    
    /// 카드 정보 유효성 검증 (보안 관점)
    /// - Parameter cardData: 검증할 카드 데이터
    /// - Returns: 검증 결과
    public static func validateSecureCardData(_ cardData: SecureCardData) -> ValidationResult {
        var issues: [SecurityIssue] = []
        
        // 카드 번호 검증
        if let cardNumber = cardData.cardNumber {
            if !CreditCardValidator.isValidCardNumber(cardNumber) {
                issues.append(.invalidCardNumber)
            }
            
            // 테스트 카드 번호 검사
            if isTestCardNumber(cardNumber) {
                issues.append(.testCardDetected)
            }
        } else {
            issues.append(.cardNumberNotReadable)
        }
        
        // 유효기간 검증
        if let expiryDate = cardData.expiryDate {
            if !isValidExpiryDate(expiryDate) {
                issues.append(.invalidExpiryDate)
            }
        } else {
            issues.append(.expiryDateNotReadable)
        }
        
        return ValidationResult(
            isValid: issues.isEmpty,
            securityIssues: issues
        )
    }
    
    /// 테스트 카드 번호인지 확인
    /// - Parameter cardNumber: 카드 번호
    /// - Returns: 테스트 카드 여부
    private static func isTestCardNumber(_ cardNumber: String) -> Bool {
        let cleanNumber = CreditCardValidator.extractDigits(from: cardNumber)
        
        // 일반적인 테스트 카드 번호들
        let testCardNumbers = [
            "4111111111111111", // Visa 테스트 카드
            "4012888888881881", // Visa 테스트 카드
            "5555555555554444", // Mastercard 테스트 카드
            "5105105105105100", // Mastercard 테스트 카드
            "378282246310005",  // Amex 테스트 카드
            "371449635398431",  // Amex 테스트 카드
            "6011111111111117", // Discover 테스트 카드
            "6011000990139424"  // Discover 테스트 카드
        ]
        
        return testCardNumbers.contains(cleanNumber)
    }
    
    /// 유효기간이 유효한지 확인
    /// - Parameter expiryDate: 유효기간 (MM/YY 또는 MM/YYYY 형식)
    /// - Returns: 유효성 여부
    private static func isValidExpiryDate(_ expiryDate: String) -> Bool {
        let components = expiryDate.components(separatedBy: "/")
        guard components.count == 2,
              let month = Int(components[0]),
              let year = Int(components[1]) else {
            return false
        }
        
        // 월 범위 확인 (1-12)
        guard month >= 1 && month <= 12 else {
            return false
        }
        
        // 현재 날짜와 비교
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        // 2자리 연도를 4자리로 변환
        let fullYear = year < 100 ? 2000 + year : year
        
        // 만료일이 현재보다 미래인지 확인
        if fullYear > currentYear {
            return true
        } else if fullYear == currentYear {
            return month >= currentMonth
        } else {
            return false
        }
    }
}

// MARK: - 보안 관련 데이터 구조체

/// 보안 검증 결과
public struct ValidationResult {
    public let isValid: Bool
    public let securityIssues: [SecurityIssue]
    
    /// 경고 메시지 생성
    public var warningMessage: String? {
        guard !securityIssues.isEmpty else { return nil }
        
        let messages = securityIssues.map { $0.localizedDescription }
        return messages.joined(separator: "\n")
    }
}

/// 보안 이슈 열거형
public enum SecurityIssue: CaseIterable {
    case invalidCardNumber
    case invalidExpiryDate
    case testCardDetected
    case cardNumberNotReadable
    case expiryDateNotReadable
    case suspiciousPattern
    
    public var localizedDescription: String {
        switch self {
        case .invalidCardNumber:
            return "유효하지 않은 카드 번호입니다."
        case .invalidExpiryDate:
            return "유효하지 않은 만료일입니다."
        case .testCardDetected:
            return "테스트 카드가 감지되었습니다."
        case .cardNumberNotReadable:
            return "카드 번호를 읽을 수 없습니다."
        case .expiryDateNotReadable:
            return "유효기간을 읽을 수 없습니다."
        case .suspiciousPattern:
            return "의심스러운 패턴이 감지되었습니다."
        }
    }
    
    public var severity: SecuritySeverity {
        switch self {
        case .invalidCardNumber, .invalidExpiryDate:
            return .high
        case .testCardDetected:
            return .medium
        case .cardNumberNotReadable, .expiryDateNotReadable:
            return .low
        case .suspiciousPattern:
            return .high
        }
    }
}

/// 보안 이슈 심각도
public enum SecuritySeverity {
    case low, medium, high
    
    public var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .low:
            return (red: 1.0, green: 0.8, blue: 0.0) // 황색
        case .medium:
            return (red: 1.0, green: 0.5, blue: 0.0) // 주황색
        case .high:
            return (red: 1.0, green: 0.0, blue: 0.0) // 빨간색
        }
    }
}