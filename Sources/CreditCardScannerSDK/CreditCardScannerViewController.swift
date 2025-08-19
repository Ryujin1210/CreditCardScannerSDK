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

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupDataScanner()
    }

    private func setupDataScanner() {
        guard DataScannerViewController.isSupported else {
            // 데이터 스캐너를 지원하지 않는 기기 처리
            return
        }

        let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .text()
        ]

        dataScanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
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
        var creditCard = CreditCard()

        for item in items {
            switch item {
            case .text(let text):
                let transcript = text.transcript
                if let cardNumber = findCardNumber(in: transcript) {
                    creditCard.number = cardNumber
                }
                // 여기에 만료일, 이름 등을 찾는 로직 추가
            default:
                break
            }
        }

        // 유효한 카드 번호가 인식되면 결과 전달
        if let _ = creditCard.number {
            delegate?.creditCardScanner(self, didFinishScanWith: creditCard)
            dismiss(animated: true)
        }
    }

    // 정규식을 사용한 신용카드 번호 추출
    private func findCardNumber(in text: String) -> String? {
        // 공백 및 하이픈 제거
        let cleanedText = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")

        // 13자리에서 16자리의 숫자 패턴
        let regex = try? NSRegularExpression(pattern: "\\b\\d{13,16}\\b")
        let range = NSRange(location: 0, length: cleanedText.utf16.count)
        if let match = regex?.firstMatch(in: cleanedText, options: [], range: range) {
            return (cleanedText as NSString).substring(with: match.range)
        }
        return nil
    }
}
