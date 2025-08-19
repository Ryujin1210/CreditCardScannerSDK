//
//  CreditCardScannerViewController.swift
//  CreditCardScannerJEI
//
//  Created by JEI on 8/19/25.
//

//
//  CreditCardScannerViewController.swift
//  CreditCardScannerJEI
//
//  Created by JEI on 8/19/25.
//

import UIKit
import VisionKit

// 스캔 결과(신용카드 정보)를 전달하기 위한 Delegate 프로토콜
@available(iOS 16.0, *)
public protocol CreditCardScannerDelegate: AnyObject {
    @available(iOS 16.0, *)
    func creditCardScanner(_ scanner: CreditCardScannerViewController, didFinishScanWith card: CreditCard)
    func creditCardScannerDidCancel(_ scanner: CreditCardScannerViewController)
}

// 스캔된 신용카드 정보를 담을 구조체
public struct CreditCard {
    public var number: String?
    public var expirationDate: String?
    public var name: String?
}

@available(iOS 16.0, *)
public class CreditCardScannerViewController: UIViewController {
    
    public weak var delegate: CreditCardScannerDelegate?
    private var dataScanner: DataScannerViewController?
    
    // 세로 카드 번호 처리를 위한 버퍼
    private var recognizedTextBuffer: [String] = []
    private var lastProcessedTime: Date = Date()
    private let processingDelay: TimeInterval = 0.5 // 0.5초 딜레이
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupDataScanner()
        setupCancelButton()
    }
    
    private func setupCancelButton() {
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("취소", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        cancelButton.layer.cornerRadius = 20
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.creditCardScannerDidCancel(self)
        dismiss(animated: true)
    }
    
    private func setupDataScanner() {
        guard DataScannerViewController.isSupported else {
            showUnsupportedDeviceAlert()
            return
        }
        
        let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .text()
        ]
        
        dataScanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .accurate, // 정확도 향상
            isHighlightingEnabled: true
        )
        
        if let dataScanner = dataScanner {
            dataScanner.delegate = self
            addChild(dataScanner)
            view.addSubview(dataScanner.view)
            dataScanner.view.frame = view.bounds
            dataScanner.didMove(toParent: self)
        }
    }
    
    private func showUnsupportedDeviceAlert() {
        let alert = UIAlertController(
            title: "지원되지 않는 기기",
            message: "이 기기는 텍스트 스캔을 지원하지 않습니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        try? dataScanner?.startScanning()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dataScanner?.stopScanning()
    }
}

// DataScannerViewControllerDelegate 채택
@available(iOS 16.0, *)
extension CreditCardScannerViewController: DataScannerViewControllerDelegate {
    public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        processRecognizedItems(allItems)
    }
    
    public func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        processRecognizedItems(allItems)
    }
    
    private func processRecognizedItems(_ items: [RecognizedItem]) {
        let currentTime = Date()
        
        // 텍스트 아이템들을 버퍼에 수집
        var currentTexts: [String] = []
        for item in items {
            switch item {
            case .text(let text):
                currentTexts.append(text.transcript)
            default:
                break
            }
        }
        
        // 버퍼 업데이트
        recognizedTextBuffer = currentTexts
        
        // 일정 시간이 지난 후 처리 (안정화를 위해)
        if currentTime.timeIntervalSince(lastProcessedTime) > processingDelay {
            lastProcessedTime = currentTime
            
            // 가로형 카드 번호 찾기
            if let card = findHorizontalCardInfo(from: recognizedTextBuffer) {
                if card.number != nil {
                    delegate?.creditCardScanner(self, didFinishScanWith: card)
                    dismiss(animated: true)
                    return
                }
            }
            
            // 세로형 카드 번호 찾기
            if let card = findVerticalCardInfo(from: recognizedTextBuffer) {
                if card.number != nil {
                    delegate?.creditCardScanner(self, didFinishScanWith: card)
                    dismiss(animated: true)
                    return
                }
            }
        }
    }
    
    // 가로형 카드 정보 찾기
    private func findHorizontalCardInfo(from texts: [String]) -> CreditCard? {
        var creditCard = CreditCard()
        
        for text in texts {
            // 카드 번호 찾기
            if creditCard.number == nil {
                if let cardNumber = findCardNumber(in: text) {
                    creditCard.number = cardNumber
                }
            }
            
            // 만료일 찾기
            if creditCard.expirationDate == nil {
                if let expDate = findExpirationDate(in: text) {
                    creditCard.expirationDate = expDate
                }
            }
            
            // 이름 찾기
            if creditCard.name == nil {
                if let name = findCardholderName(in: text) {
                    creditCard.name = name
                }
            }
        }
        
        return creditCard.number != nil ? creditCard : nil
    }
    
    // 세로형 카드 정보 찾기
    private func findVerticalCardInfo(from texts: [String]) -> CreditCard? {
        var creditCard = CreditCard()
        
        // 4자리 숫자 그룹 수집
        var digitGroups: [String] = []
        for text in texts {
            let cleaned = text.replacingOccurrences(of: " ", with: "")
                             .replacingOccurrences(of: "-", with: "")
            
            // 4자리 숫자 패턴 찾기
            if let regex = try? NSRegularExpression(pattern: "\\b\\d{4}\\b") {
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                let matches = regex.matches(in: cleaned, options: [], range: range)
                
                for match in matches {
                    let group = (cleaned as NSString).substring(with: match.range)
                    digitGroups.append(group)
                }
            }
        }
        
        // 4개의 그룹이 모였을 때 카드 번호 조합 시도
        if digitGroups.count >= 4 {
            // 연속된 4개 그룹으로 카드 번호 생성
            for i in 0...(digitGroups.count - 4) {
                let potentialCardNumber = digitGroups[i..<i+4].joined()
                if isValidCardNumber(potentialCardNumber) {
                    creditCard.number = formatCardNumber(potentialCardNumber)
                    break
                }
            }
        }
        
        // 만료일과 이름 찾기
        for text in texts {
            if creditCard.expirationDate == nil {
                if let expDate = findExpirationDate(in: text) {
                    creditCard.expirationDate = expDate
                }
            }
            
            if creditCard.name == nil {
                if let name = findCardholderName(in: text) {
                    creditCard.name = name
                }
            }
        }
        
        return creditCard.number != nil ? creditCard : nil
    }
    
    // 정규식을 사용한 신용카드 번호 추출 (가로형)
    private func findCardNumber(in text: String) -> String? {
        let cleanedText = text.replacingOccurrences(of: " ", with: "")
                             .replacingOccurrences(of: "-", with: "")
        
        // 13자리에서 19자리의 숫자 패턴
        let patterns = [
            "\\b\\d{16}\\b",           // 16자리 연속
            "\\b\\d{4}\\s*\\d{4}\\s*\\d{4}\\s*\\d{4}\\b", // 4-4-4-4 패턴
            "\\b\\d{15}\\b",           // 15자리 (AMEX)
            "\\b\\d{14}\\b",           // 14자리 (Diners)
            "\\b\\d{13}\\b"            // 13자리
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: text.utf16.count)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    let number = (text as NSString).substring(with: match.range)
                    let digitsOnly = number.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                    
                    if isValidCardNumber(digitsOnly) {
                        return formatCardNumber(digitsOnly)
                    }
                }
            }
        }
        
        return nil
    }
    
    // 만료일 찾기
    private func findExpirationDate(in text: String) -> String? {
        // MM/YY, MM/YYYY, MM YY 패턴
        let patterns = [
            "(0[1-9]|1[0-2])\\s*/\\s*(\\d{2}|\\d{4})",
            "(0[1-9]|1[0-2])\\s+(\\d{2}|\\d{4})",
            "VALID\\s+THRU\\s+(0[1-9]|1[0-2])\\s*/\\s*(\\d{2})",
            "EXP\\s+(0[1-9]|1[0-2])\\s*/\\s*(\\d{2})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: text.utf16.count)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    return (text as NSString).substring(with: match.range)
                }
            }
        }
        
        return nil
    }
    
    // 카드 소유자 이름 찾기
    private func findCardholderName(in text: String) -> String? {
        // 대문자 알파벳으로 이루어진 이름 패턴
        let pattern = "\\b[A-Z]{2,}\\s+[A-Z]{2,}\\b"
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let name = (text as NSString).substring(with: match.range)
                // 일반적인 카드 레이블 제외
                let excludedWords = ["VALID", "THRU", "MEMBER", "SINCE", "VISA", "MASTERCARD", "DEBIT", "CREDIT"]
                for word in excludedWords {
                    if name.contains(word) {
                        return nil
                    }
                }
                return name
            }
        }
        
        return nil
    }
    
    // Luhn 알고리즘을 사용한 카드 번호 유효성 검증
    private func isValidCardNumber(_ number: String) -> Bool {
        let digitsOnly = number.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        
        guard digitsOnly.count >= 13 && digitsOnly.count <= 19 else {
            return false
        }
        
        var sum = 0
        let reversedDigits = digitsOnly.reversed().map { Int(String($0))! }
        
        for (index, digit) in reversedDigits.enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        
        return sum % 10 == 0
    }
    
    // 카드 번호 포맷팅
    private func formatCardNumber(_ number: String) -> String {
        let digitsOnly = number.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        
        // 4자리씩 그룹화
        var formatted = ""
        for (index, char) in digitsOnly.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted += String(char)
        }
        
        return formatted
    }
}
