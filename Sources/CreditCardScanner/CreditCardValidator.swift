import Foundation

/// 신용카드 번호 검증을 위한 유틸리티 클래스
public struct CreditCardValidator {
    
    /// 룬(Luhn) 알고리즘을 사용하여 신용카드 번호가 유효한지 검증
    /// - Parameter cardNumber: 검증할 신용카드 번호 (숫자만 포함된 문자열)
    /// - Returns: 유효한 카드 번호인 경우 true, 아닌 경우 false
    public static func isValidCardNumber(_ cardNumber: String) -> Bool {
        let cleanedNumber = cardNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        // 숫자만 포함된 문자열인지 확인
        guard cleanedNumber.allSatisfy({ $0.isNumber }) else { return false }
        
        // 카드 번호 길이 검증 (13-19자리)
        guard cleanedNumber.count >= 13 && cleanedNumber.count <= 19 else { return false }
        
        return luhnAlgorithm(cleanedNumber)
    }
    
    /// 룬(Luhn) 알고리즘 구현
    /// - Parameter cardNumber: 검증할 카드 번호
    /// - Returns: 룬 알고리즘 검증 결과
    private static func luhnAlgorithm(_ cardNumber: String) -> Bool {
        let digits = cardNumber.reversed().compactMap { Int(String($0)) }
        var sum = 0
        
        for (index, digit) in digits.enumerated() {
            if index % 2 == 1 { // 홀수 위치 (오른쪽에서부터 두 번째, 네 번째, ...)
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else { // 짝수 위치
                sum += digit
            }
        }
        
        return sum % 10 == 0
    }
    
    /// 카드 번호에서 숫자만 추출
    /// - Parameter input: 원본 문자열
    /// - Returns: 숫자만 포함된 문자열
    public static func extractDigits(from input: String) -> String {
        return input.filter { $0.isNumber }
    }
    
    /// 카드 번호를 표준 형식으로 포맷팅 (4자리씩 공백으로 구분)
    /// - Parameter cardNumber: 포맷팅할 카드 번호
    /// - Returns: 포맷팅된 카드 번호 (예: "1234 5678 9012 3456")
    public static func formatCardNumber(_ cardNumber: String) -> String {
        let cleanedNumber = extractDigits(from: cardNumber)
        var formatted = ""
        
        for (index, character) in cleanedNumber.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted += String(character)
        }
        
        return formatted
    }
    
    /// 카드 타입 식별
    /// - Parameter cardNumber: 카드 번호
    /// - Returns: 카드 타입
    public static func identifyCardType(_ cardNumber: String) -> CardType {
        let cleanedNumber = extractDigits(from: cardNumber)
        
        // Visa: 4로 시작, 13-19자리
        if cleanedNumber.hasPrefix("4") && (cleanedNumber.count == 13 || cleanedNumber.count == 16 || cleanedNumber.count == 19) {
            return .visa
        }
        
        // Mastercard: 5로 시작하거나 2221-2720 범위, 16자리
        if cleanedNumber.count == 16 {
            if cleanedNumber.hasPrefix("5") {
                return .mastercard
            }
            if let firstFour = Int(String(cleanedNumber.prefix(4))), firstFour >= 2221 && firstFour <= 2720 {
                return .mastercard
            }
        }
        
        // American Express: 34 또는 37로 시작, 15자리
        if cleanedNumber.count == 15 && (cleanedNumber.hasPrefix("34") || cleanedNumber.hasPrefix("37")) {
            return .americanExpress
        }
        
        // Discover: 6으로 시작, 16자리
        if cleanedNumber.count == 16 && cleanedNumber.hasPrefix("6") {
            return .discover
        }
        
        return .unknown
    }
}

/// 신용카드 타입 열거형
public enum CardType: String, CaseIterable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case americanExpress = "American Express"
    case discover = "Discover"
    case unknown = "Unknown"
    
    /// 각 카드 타입별 색상 (UIColor 호환)
    public var brandColor: (red: Double, green: Double, blue: Double) {
        switch self {
        case .visa:
            return (red: 0.0, green: 0.4, blue: 0.8) // Visa 블루
        case .mastercard:
            return (red: 0.9, green: 0.2, blue: 0.2) // Mastercard 레드
        case .americanExpress:
            return (red: 0.0, green: 0.6, blue: 0.5) // Amex 그린
        case .discover:
            return (red: 1.0, green: 0.4, blue: 0.0) // Discover 오렌지
        case .unknown:
            return (red: 0.5, green: 0.5, blue: 0.5) // 회색
        }
    }
}