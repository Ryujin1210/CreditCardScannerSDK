import Foundation
import UIKit
import SwiftUI

/// 신용카드 스캐너 SDK의 메인 인터페이스
public class CreditCardScanner {
    
    /// SDK 설정
    public struct Configuration {
        /// 자동 스캔 활성화 여부
        public let isAutoScanEnabled: Bool
        
        /// 스캔 신뢰도 임계값 (0.0 - 1.0)
        public let confidenceThreshold: Float
        
        /// 보안 검증 활성화 여부
        public let isSecurityValidationEnabled: Bool
        
        /// 테스트 카드 허용 여부
        public let allowTestCards: Bool
        
        /// 카메라 품질 설정
        public let cameraQuality: CameraQuality
        
        /// 기본 설정
        public static let `default` = Configuration(
            isAutoScanEnabled: false,
            confidenceThreshold: 0.8,
            isSecurityValidationEnabled: true,
            allowTestCards: false,
            cameraQuality: .high
        )
        
        public init(
            isAutoScanEnabled: Bool = false,
            confidenceThreshold: Float = 0.8,
            isSecurityValidationEnabled: Bool = true,
            allowTestCards: Bool = false,
            cameraQuality: CameraQuality = .high
        ) {
            self.isAutoScanEnabled = isAutoScanEnabled
            self.confidenceThreshold = confidenceThreshold
            self.isSecurityValidationEnabled = isSecurityValidationEnabled
            self.allowTestCards = allowTestCards
            self.cameraQuality = cameraQuality
        }
    }
    
    /// 카메라 품질 설정
    public enum CameraQuality {
        case medium, high, veryHigh
        
        var sessionPreset: String {
            switch self {
            case .medium:
                return "hd1280x720"
            case .high:
                return "hd1920x1080"
            case .veryHigh:
                return "hd4K3840x2160"
            }
        }
    }
    
    /// 스캔 결과
    public struct ScanResult {
        public let cardNumber: String?
        public let expiryDate: String?
        public let cardType: CardType
        public let confidence: Float
        public let secureData: SecurityManager.SecureCardData?
        public let validationResult: ValidationResult?
        
        public init(
            cardNumber: String?,
            expiryDate: String?,
            cardType: CardType,
            confidence: Float,
            secureData: SecurityManager.SecureCardData? = nil,
            validationResult: ValidationResult? = nil
        ) {
            self.cardNumber = cardNumber
            self.expiryDate = expiryDate
            self.cardType = cardType
            self.confidence = confidence
            self.secureData = secureData
            self.validationResult = validationResult
        }
    }
    
    /// 스캔 완료 콜백
    public typealias ScanCompletion = (Result<ScanResult, ScanError>) -> Void
    
    /// 현재 설정
    public let configuration: Configuration
    
    /// OCR 엔진
    private let ocrEngine = OCREngine()
    
    /// 초기화
    /// - Parameter configuration: SDK 설정
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    /// UIKit용 카메라 뷰 컨트롤러 생성
    /// - Parameter completion: 스캔 완료 콜백
    /// - Returns: 카메라 뷰 컨트롤러
    public func createCameraViewController(completion: @escaping ScanCompletion) -> UIViewController {
        let cameraViewController = CameraViewController()
        cameraViewController.delegate = CameraDelegate(scanner: self, completion: completion)
        return cameraViewController
    }
    
    /// SwiftUI용 카메라 뷰 생성
    /// - Parameter completion: 스캔 완료 콜백
    /// - Returns: SwiftUI 카메라 뷰
    public func createCameraView(completion: @escaping ScanCompletion) -> some View {
        return CameraView(
            onScanComplete: { [weak self] ocrResult in
                guard let self = self else { return }
                self.processScanResult(ocrResult, completion: completion)
            },
            onCancel: {
                completion(.failure(.userCancelled))
            }
        )
    }
    
    /// 이미지에서 직접 스캔
    /// - Parameters:
    ///   - image: 스캔할 이미지
    ///   - completion: 스캔 완료 콜백
    public func scanImage(_ image: UIImage, completion: @escaping ScanCompletion) {
        ocrEngine.scanCreditCard(from: image) { [weak self] ocrResult in
            guard let self = self else {
                completion(.failure(.processingError))
                return
            }
            
            self.processScanResult(ocrResult, completion: completion)
        }
    }
    
    /// OCR 결과를 처리하여 최종 결과 생성
    internal func processScanResult(_ ocrResult: OCREngine.ScanResult, completion: @escaping ScanCompletion) {
        // 신뢰도 확인
        guard ocrResult.confidence >= configuration.confidenceThreshold else {
            completion(.failure(.lowConfidence(ocrResult.confidence)))
            return
        }
        
        // 카드 번호와 유효기간이 모두 있는지 확인
        guard let cardNumber = ocrResult.cardNumber,
              let expiryDate = ocrResult.expiryDate else {
            completion(.failure(.incompleteData))
            return
        }
        
        // 보안 데이터 생성
        let secureData = SecurityManager.secureCardData(
            cardNumber: cardNumber,
            expiryDate: expiryDate
        )
        
        // 보안 검증
        var validationResult: ValidationResult? = nil
        if configuration.isSecurityValidationEnabled {
            validationResult = SecurityManager.validateSecureCardData(secureData)
            
            // 테스트 카드 검사
            if !configuration.allowTestCards,
               let validation = validationResult,
               validation.securityIssues.contains(.testCardDetected) {
                completion(.failure(.testCardNotAllowed))
                return
            }
            
            // 보안 검증 실패 시
            if let validation = validationResult,
               !validation.isValid,
               validation.securityIssues.contains(where: { $0.severity == .high }) {
                completion(.failure(.securityValidationFailed(validation)))
                return
            }
        }
        
        // 성공 결과 생성
        let result = ScanResult(
            cardNumber: cardNumber,
            expiryDate: expiryDate,
            cardType: ocrResult.cardType,
            confidence: ocrResult.confidence,
            secureData: secureData,
            validationResult: validationResult
        )
        
        completion(.success(result))
        
        // 메모리 정리
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            SecurityManager.clearTemporaryData()
        }
    }
    
    /// SDK 정보 반환
    public static var version: String {
        return "1.0.0"
    }
    
    /// 지원되는 카드 타입 목록
    public static var supportedCardTypes: [CardType] {
        return CardType.allCases.filter { $0 != .unknown }
    }
}

// MARK: - 스캔 에러
public enum ScanError: Error, LocalizedError {
    case cameraNotAvailable
    case permissionDenied
    case processingError
    case lowConfidence(Float)
    case incompleteData
    case userCancelled
    case testCardNotAllowed
    case securityValidationFailed(ValidationResult)
    
    public var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "카메라를 사용할 수 없습니다."
        case .permissionDenied:
            return "카메라 권한이 거부되었습니다."
        case .processingError:
            return "이미지 처리 중 오류가 발생했습니다."
        case .lowConfidence(let confidence):
            return "스캔 신뢰도가 낮습니다: \(Int(confidence * 100))%"
        case .incompleteData:
            return "카드 정보가 완전하지 않습니다."
        case .userCancelled:
            return "사용자가 스캔을 취소했습니다."
        case .testCardNotAllowed:
            return "테스트 카드는 허용되지 않습니다."
        case .securityValidationFailed(let validation):
            return validation.warningMessage ?? "보안 검증에 실패했습니다."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .cameraNotAvailable:
            return "기기의 카메라가 올바르게 작동하는지 확인해주세요."
        case .permissionDenied:
            return "설정에서 카메라 권한을 허용해주세요."
        case .processingError:
            return "다시 시도해주시거나, 다른 이미지를 사용해주세요."
        case .lowConfidence:
            return "조명을 개선하고 카드를 명확하게 촬영해주세요."
        case .incompleteData:
            return "카드 번호와 유효기간이 모두 보이도록 촬영해주세요."
        case .userCancelled:
            return nil
        case .testCardNotAllowed:
            return "실제 카드를 사용해주세요."
        case .securityValidationFailed:
            return "유효한 카드인지 확인해주세요."
        }
    }
}

// MARK: - 내부 델리게이트
private class CameraDelegate: CameraViewControllerDelegate {
    private let scanner: CreditCardScanner
    private let completion: CreditCardScanner.ScanCompletion
    
    init(scanner: CreditCardScanner, completion: @escaping CreditCardScanner.ScanCompletion) {
        self.scanner = scanner
        self.completion = completion
    }
    
    func cameraViewController(_ viewController: CameraViewController, didScanCard result: OCREngine.ScanResult) {
        scanner.processScanResult(result, completion: completion)
    }
    
    func cameraViewControllerDidCancel(_ viewController: CameraViewController) {
        completion(.failure(.userCancelled))
    }
}

// MARK: - 편의 확장
public extension CreditCardScanner {
    
    /// 빠른 스캔을 위한 편의 메서드 (기본 설정 사용)
    /// - Parameter completion: 스캔 완료 콜백
    /// - Returns: UIKit 카메라 뷰 컨트롤러
    static func quickScanViewController(completion: @escaping ScanCompletion) -> UIViewController {
        let scanner = CreditCardScanner()
        return scanner.createCameraViewController(completion: completion)
    }
    
    /// 빠른 스캔을 위한 편의 메서드 (기본 설정 사용)
    /// - Parameter completion: 스캔 완료 콜백
    /// - Returns: SwiftUI 카메라 뷰
    static func quickScanView(completion: @escaping ScanCompletion) -> some View {
        let scanner = CreditCardScanner()
        return scanner.createCameraView(completion: completion)
    }
}

// MARK: - 사용 예제 (주석)
/*
 
 // UIKit 사용 예제
 let configuration = CreditCardScanner.Configuration(
     isAutoScanEnabled: false,
     confidenceThreshold: 0.8,
     isSecurityValidationEnabled: true
 )
 
 let scanner = CreditCardScanner(configuration: configuration)
 let cameraVC = scanner.createCameraViewController { result in
     switch result {
     case .success(let scanResult):
         print("카드 번호: \(scanResult.cardNumber ?? "없음")")
         print("유효기간: \(scanResult.expiryDate ?? "없음")")
         print("카드 타입: \(scanResult.cardType.rawValue)")
         print("신뢰도: \(scanResult.confidence)")
         
         // 마스킹된 카드 번호 사용
         if let maskedNumber = scanResult.secureData?.maskedCardNumber {
             print("마스킹된 번호: \(maskedNumber)")
         }
         
     case .failure(let error):
         print("스캔 실패: \(error.localizedDescription)")
     }
 }
 
 present(cameraVC, animated: true)
 
 // SwiftUI 사용 예제
 struct ContentView: View {
     @State private var showingScanner = false
     @State private var scanResult: String = ""
     
     var body: some View {
         VStack {
             Text(scanResult)
                 .padding()
             
             Button("카드 스캔하기") {
                 showingScanner = true
             }
         }
         .sheet(isPresented: $showingScanner) {
             CreditCardScanner.quickScanView { result in
                 switch result {
                 case .success(let scanResult):
                     self.scanResult = "스캔 성공: \(scanResult.cardType.rawValue)"
                 case .failure(let error):
                     self.scanResult = "스캔 실패: \(error.localizedDescription)"
                 }
                 showingScanner = false
             }
         }
     }
 }
 
 */