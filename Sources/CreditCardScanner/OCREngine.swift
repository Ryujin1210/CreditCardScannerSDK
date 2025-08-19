import Foundation
import Vision
import UIKit

/// OCR 엔진 - Vision Framework를 사용하여 신용카드 정보를 추출
public class OCREngine: ObservableObject {
    
    /// OCR 스캔 결과를 나타내는 구조체
    public struct ScanResult {
        public let cardNumber: String?
        public let expiryDate: String?
        public let confidence: Float
        public let cardType: CardType
        
        public init(cardNumber: String?, expiryDate: String?, confidence: Float, cardType: CardType) {
            self.cardNumber = cardNumber
            self.expiryDate = expiryDate
            self.confidence = confidence
            self.cardType = cardType
        }
    }
    
    /// 스캔 완료 콜백
    public typealias ScanCompletion = (ScanResult) -> Void
    
    private var scanCompletion: ScanCompletion?
    
    public init() {}
    
    /// 이미지에서 신용카드 정보를 추출
    /// - Parameters:
    ///   - image: 스캔할 이미지
    ///   - completion: 스캔 완료 콜백
    public func scanCreditCard(from image: UIImage, completion: @escaping ScanCompletion) {
        self.scanCompletion = completion
        
        guard let cgImage = image.cgImage else {
            completion(ScanResult(cardNumber: nil, expiryDate: nil, confidence: 0.0, cardType: .unknown))
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextRecognition(request: request, error: error)
        }
        
        // OCR 정확도 향상을 위한 설정
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"] // 영어 숫자 인식에 최적화
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            completion(ScanResult(cardNumber: nil, expiryDate: nil, confidence: 0.0, cardType: .unknown))
        }
    }
    
    /// 텍스트 인식 결과를 처리
    private func handleTextRecognition(request: VNRequest, error: Error?) {
        guard error == nil,
              let observations = request.results as? [VNRecognizedTextObservation] else {
            scanCompletion?(ScanResult(cardNumber: nil, expiryDate: nil, confidence: 0.0, cardType: .unknown))
            return
        }
        
        var recognizedTexts: [(text: String, confidence: Float, boundingBox: CGRect)] = []
        
        // 모든 인식된 텍스트를 수집
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            recognizedTexts.append((
                text: topCandidate.string,
                confidence: topCandidate.confidence,
                boundingBox: observation.boundingBox
            ))
        }
        
        // 카드 번호와 유효기간 추출
        let cardNumber = extractCardNumber(from: recognizedTexts)
        let expiryDate = extractExpiryDate(from: recognizedTexts)
        
        // 전체 신뢰도 계산
        let overallConfidence = calculateOverallConfidence(recognizedTexts)
        
        // 카드 타입 식별
        let cardType = cardNumber != nil ? CreditCardValidator.identifyCardType(cardNumber!) : .unknown
        
        let result = ScanResult(
            cardNumber: cardNumber,
            expiryDate: expiryDate,
            confidence: overallConfidence,
            cardType: cardType
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.scanCompletion?(result)
        }
    }
    
    /// 인식된 텍스트에서 신용카드 번호를 추출
    /// 다양한 레이아웃 지원: 1줄(가로/세로), 2줄(가로/세로)
    private func extractCardNumber(from texts: [(text: String, confidence: Float, boundingBox: CGRect)]) -> String? {
        var potentialNumbers: [String] = []
        
        // 각 텍스트에서 숫자만 추출
        for textInfo in texts {
            let cleanText = CreditCardValidator.extractDigits(from: textInfo.text)
            
            // 4자리 이상의 숫자 그룹만 고려
            if cleanText.count >= 4 {
                potentialNumbers.append(cleanText)
            }
        }
        
        // 1. 단일 라인에서 완전한 카드 번호 찾기 (13-19자리)
        for number in potentialNumbers {
            if number.count >= 13 && number.count <= 19 && CreditCardValidator.isValidCardNumber(number) {
                return CreditCardValidator.formatCardNumber(number)
            }
        }
        
        // 2. 여러 텍스트를 조합하여 카드 번호 구성 (2줄 레이아웃 지원)
        let combinedAttempts = generateCardNumberCombinations(from: texts)
        for attempt in combinedAttempts {
            let cleanAttempt = CreditCardValidator.extractDigits(from: attempt)
            if cleanAttempt.count >= 13 && cleanAttempt.count <= 19 && CreditCardValidator.isValidCardNumber(cleanAttempt) {
                return CreditCardValidator.formatCardNumber(cleanAttempt)
            }
        }
        
        // 3. 부분 번호들을 위치 기반으로 정렬하여 조합
        let sortedByPosition = sortTextsByPosition(texts)
        let positionBasedNumber = combineNumbersByPosition(sortedByPosition)
        
        if let validNumber = positionBasedNumber,
           CreditCardValidator.isValidCardNumber(validNumber) {
            return CreditCardValidator.formatCardNumber(validNumber)
        }
        
        return nil
    }
    
    /// 여러 텍스트를 조합하여 가능한 카드 번호 생성
    private func generateCardNumberCombinations(from texts: [(text: String, confidence: Float, boundingBox: CGRect)]) -> [String] {
        var combinations: [String] = []
        let numberTexts = texts.filter { CreditCardValidator.extractDigits(from: $0.text).count >= 4 }
        
        // 2개 텍스트 조합
        for i in 0..<numberTexts.count {
            for j in 0..<numberTexts.count {
                if i != j {
                    let combined = numberTexts[i].text + numberTexts[j].text
                    combinations.append(combined)
                }
            }
        }
        
        // 3개 텍스트 조합 (일부 카드는 3개 그룹으로 나뉠 수 있음)
        for i in 0..<numberTexts.count {
            for j in 0..<numberTexts.count {
                for k in 0..<numberTexts.count {
                    if i != j && j != k && i != k {
                        let combined = numberTexts[i].text + numberTexts[j].text + numberTexts[k].text
                        combinations.append(combined)
                    }
                }
            }
        }
        
        return combinations
    }
    
    /// 텍스트를 위치(Y좌표, X좌표 순)로 정렬
    private func sortTextsByPosition(_ texts: [(text: String, confidence: Float, boundingBox: CGRect)]) -> [(text: String, confidence: Float, boundingBox: CGRect)] {
        return texts.sorted { first, second in
            // Y좌표가 다르면 Y좌표로 정렬 (위에서 아래로)
            if abs(first.boundingBox.midY - second.boundingBox.midY) > 0.1 {
                return first.boundingBox.midY > second.boundingBox.midY // Vision 좌표계는 아래가 0
            }
            // 같은 줄이면 X좌표로 정렬 (왼쪽에서 오른쪽으로)
            return first.boundingBox.midX < second.boundingBox.midX
        }
    }
    
    /// 위치 기반으로 정렬된 텍스트들을 조합하여 카드 번호 생성
    private func combineNumbersByPosition(_ sortedTexts: [(text: String, confidence: Float, boundingBox: CGRect)]) -> String? {
        let numberTexts = sortedTexts.filter { CreditCardValidator.extractDigits(from: $0.text).count >= 4 }
        guard !numberTexts.isEmpty else { return nil }
        
        var combinedNumber = ""
        
        for textInfo in numberTexts {
            let digits = CreditCardValidator.extractDigits(from: textInfo.text)
            combinedNumber += digits
            
            // 중간에 유효한 카드 번호가 되면 반환
            if combinedNumber.count >= 13 && combinedNumber.count <= 19 {
                if CreditCardValidator.isValidCardNumber(combinedNumber) {
                    return combinedNumber
                }
            }
        }
        
        return nil
    }
    
    /// 인식된 텍스트에서 유효기간을 추출 (MM/YY 또는 MM/YYYY 형식)
    private func extractExpiryDate(from texts: [(text: String, confidence: Float, boundingBox: CGRect)]) -> String? {
        let datePatterns = [
            #"(\d{2})/(\d{2})"#,           // MM/YY
            #"(\d{2})/(\d{4})"#,           // MM/YYYY
            #"(\d{2})\s*\/\s*(\d{2})"#,    // MM / YY (공백 포함)
            #"(\d{2})\s*\/\s*(\d{4})"#,    // MM / YYYY (공백 포함)
            #"(\d{2})\s+(\d{2})"#,         // MM YY (슬래시 없음)
            #"(\d{2})\s+(\d{4})"#          // MM YYYY (슬래시 없음)
        ]
        
        for textInfo in texts {
            let text = textInfo.text
            
            for pattern in datePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                    
                    let monthRange = Range(match.range(at: 1), in: text)!
                    let yearRange = Range(match.range(at: 2), in: text)!
                    
                    let month = String(text[monthRange])
                    let year = String(text[yearRange])
                    
                    // 월 유효성 검사 (01-12)
                    if let monthInt = Int(month), monthInt >= 1 && monthInt <= 12 {
                        // 연도가 2자리면 20XX로 변환
                        let fullYear = year.count == 2 ? "20" + year : year
                        return "\(month)/\(fullYear)"
                    }
                }
            }
        }
        
        return nil
    }
    
    /// 전체 신뢰도 계산
    private func calculateOverallConfidence(_ texts: [(text: String, confidence: Float, boundingBox: CGRect)]) -> Float {
        guard !texts.isEmpty else { return 0.0 }
        
        let totalConfidence = texts.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(texts.count)
    }
}