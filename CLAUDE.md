# CreditCardScanner SDK

> 🔒 **보안 우선** iOS용 신용카드 OCR 스캐닝 SDK  
> Vision Framework 기반의 고정밀 카드 정보 추출 솔루션

## 📋 개요

CreditCardScanner는 iOS Vision Framework를 활용하여 신용카드의 카드번호와 유효기간을 실시간으로 인식하고 추출하는 상업용 SDK입니다. UIKit과 SwiftUI를 모두 지원하며, 강력한 보안 기능과 사용자 친화적인 UI를 제공합니다.

### 🎯 핵심 기능

- **실시간 카드 인식**: Vision Framework 기반의 고정밀 텍스트 인식
- **자동 포커싱**: 카드 모양 가이드라인을 통한 정확한 스캔 영역 제공
- **다중 카드 지원**: Visa, MasterCard, AMEX 등 주요 카드사 지원
- **보안 강화**: 메모리 내 데이터 암호화 및 자동 삭제
- **크로스 플랫폼**: UIKit, SwiftUI 동시 지원

## 🛠 기술 스택

- **Core**: Swift 5.5+, iOS 16.0+
- **Computer Vision**: Vision Framework, VNRecognizeTextRequest
- **UI Framework**: UIKit, SwiftUI
- **Camera**: AVFoundation, AVCaptureSession
- **Security**: CryptoKit, SecureEnclave 호환
- **코드 주석**: 유지보수를 위한 각 기능별 한글 주석처리

## 📦 설치

### Swift Package Manager
