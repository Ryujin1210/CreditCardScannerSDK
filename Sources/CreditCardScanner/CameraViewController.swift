import UIKit
import AVFoundation
import Vision

/// UIKit용 신용카드 스캔 카메라 뷰 컨트롤러
public class CameraViewController: UIViewController {
    
    /// 스캔 완료 델리게이트
    public weak var delegate: CameraViewControllerDelegate?
    
    /// 카메라 세션
    private var captureSession: AVCaptureSession?
    
    /// 비디오 프리뷰 레이어
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// 카메라 출력
    private var videoOutput: AVCaptureVideoDataOutput?
    
    /// OCR 엔진
    private let ocrEngine = OCREngine()
    
    /// 카드 가이드라인 오버레이 뷰
    private let cardGuideOverlay = CardGuideOverlayView()
    
    /// 스캔 결과 표시 레이블
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 스캔 버튼
    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("스캔하기", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    /// 닫기 버튼
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("✕", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 22
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    /// 마지막 스캔 시간 (중복 스캔 방지)
    private var lastScanTime: Date = Date.distantPast
    
    /// 스캔 간격 (초)
    private let scanInterval: TimeInterval = 1.0
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        setupActions()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCamera()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }
    
    /// UI 설정
    private func setupUI() {
        view.backgroundColor = .black
        
        // 카드 가이드라인 추가
        view.addSubview(cardGuideOverlay)
        cardGuideOverlay.translatesAutoresizingMaskIntoConstraints = false
        
        // 결과 레이블 추가
        view.addSubview(resultLabel)
        
        // 스캔 버튼 추가
        view.addSubview(scanButton)
        
        // 닫기 버튼 추가
        view.addSubview(closeButton)
        
        // 오토레이아웃 설정
        NSLayoutConstraint.activate([
            // 카드 가이드라인
            cardGuideOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardGuideOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardGuideOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            cardGuideOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 결과 레이블
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            resultLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            resultLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            // 스캔 버튼
            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            scanButton.widthAnchor.constraint(equalToConstant: 150),
            scanButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 닫기 버튼
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 초기 상태
        resultLabel.text = "카드를 가이드라인 안에 맞춰주세요"
    }
    
    /// 카메라 설정
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .hd1920x1080
        
        guard let captureSession = captureSession else { return }
        
        // 카메라 입력 설정
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            showAlert(title: "카메라 오류", message: "카메라에 접근할 수 없습니다.")
            return
        }
        
        captureSession.addInput(input)
        
        // 비디오 출력 설정
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.video.queue"))
        
        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // 프리뷰 레이어 설정
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer.insertSublayer(previewLayer, at: 0)
        }
    }
    
    /// 액션 설정
    private func setupActions() {
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    }
    
    /// 카메라 시작
    private func startCamera() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    /// 카메라 중지
    private func stopCamera() {
        captureSession?.stopRunning()
    }
    
    /// 레이아웃 업데이트
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    /// 스캔 버튼 액션
    @objc private func scanButtonTapped() {
        // 현재 프레임 캡처하여 스캔 수행
        captureCurrentFrame()
    }
    
    /// 닫기 버튼 액션
    @objc private func closeButtonTapped() {
        delegate?.cameraViewControllerDidCancel(self)
    }
    
    /// 현재 프레임 캡처
    private func captureCurrentFrame() {
        guard let connection = videoOutput?.connection(with: .video) else { return }
        
        // 현재 시간 확인 (중복 스캔 방지)
        let now = Date()
        guard now.timeIntervalSince(lastScanTime) >= scanInterval else { return }
        lastScanTime = now
        
        // 스캔 상태 표시
        DispatchQueue.main.async { [weak self] in
            self?.resultLabel.text = "스캔 중..."
            self?.resultLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        }
    }
    
    /// 알림 표시
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            self?.present(alert, animated: true)
        }
    }
    
    /// 스캔 결과 표시 및 델리게이트 호출
    private func handleScanResult(_ result: OCREngine.ScanResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let cardNumber = result.cardNumber, let expiryDate = result.expiryDate {
                // 성공적인 스캔
                self.resultLabel.text = """
                카드번호: \(cardNumber)
                유효기간: \(expiryDate)
                신뢰도: \(Int(result.confidence * 100))%
                """
                self.resultLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
                
                // 델리게이트에 결과 전달
                self.delegate?.cameraViewController(self, didScanCard: result)
                
                // 자동으로 닫기 (옵션)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.delegate?.cameraViewControllerDidCancel(self)
                }
                
            } else if result.cardNumber != nil || result.expiryDate != nil {
                // 부분적인 스캔
                var message = "부분 인식:\n"
                if let cardNumber = result.cardNumber {
                    message += "카드번호: \(cardNumber)\n"
                }
                if let expiryDate = result.expiryDate {
                    message += "유효기간: \(expiryDate)\n"
                }
                message += "신뢰도: \(Int(result.confidence * 100))%"
                
                self.resultLabel.text = message
                self.resultLabel.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.8)
                
            } else {
                // 스캔 실패
                self.resultLabel.text = "카드 정보를 인식할 수 없습니다.\n다시 시도해주세요."
                self.resultLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
            }
            
            // 3초 후 기본 상태로 복원
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.resultLabel.text = "카드를 가이드라인 안에 맞춰주세요"
                self.resultLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 자동 스캔은 비활성화하고, 수동 스캔만 지원
        // 실시간 자동 스캔을 원할 경우 여기서 OCR 수행
    }
}

// MARK: - CameraViewControllerDelegate
public protocol CameraViewControllerDelegate: AnyObject {
    /// 카드 스캔 완료
    func cameraViewController(_ viewController: CameraViewController, didScanCard result: OCREngine.ScanResult)
    
    /// 스캔 취소
    func cameraViewControllerDidCancel(_ viewController: CameraViewController)
}

// MARK: - 카드 가이드라인 오버레이 뷰
private class CardGuideOverlayView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 전체 화면을 반투명하게 만들기
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(rect)
        
        // 카드 영역 계산 (3:2 비율)
        let cardWidth: CGFloat = rect.width * 0.8
        let cardHeight: CGFloat = cardWidth * 0.63 // 신용카드 표준 비율
        let cardRect = CGRect(
            x: (rect.width - cardWidth) / 2,
            y: (rect.height - cardHeight) / 2,
            width: cardWidth,
            height: cardHeight
        )
        
        // 카드 영역을 투명하게 만들기
        context.setBlendMode(.clear)
        context.fill(cardRect)
        
        // 가이드라인 테두리 그리기
        context.setBlendMode(.normal)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.stroke(cardRect)
        
        // 모서리 강조선 그리기
        let cornerLength: CGFloat = 20
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(3.0)
        
        // 좌상단
        context.move(to: CGPoint(x: cardRect.minX, y: cardRect.minY + cornerLength))
        context.addLine(to: CGPoint(x: cardRect.minX, y: cardRect.minY))
        context.addLine(to: CGPoint(x: cardRect.minX + cornerLength, y: cardRect.minY))
        
        // 우상단
        context.move(to: CGPoint(x: cardRect.maxX - cornerLength, y: cardRect.minY))
        context.addLine(to: CGPoint(x: cardRect.maxX, y: cardRect.minY))
        context.addLine(to: CGPoint(x: cardRect.maxX, y: cardRect.minY + cornerLength))
        
        // 좌하단
        context.move(to: CGPoint(x: cardRect.minX, y: cardRect.maxY - cornerLength))
        context.addLine(to: CGPoint(x: cardRect.minX, y: cardRect.maxY))
        context.addLine(to: CGPoint(x: cardRect.minX + cornerLength, y: cardRect.maxY))
        
        // 우하단
        context.move(to: CGPoint(x: cardRect.maxX - cornerLength, y: cardRect.maxY))
        context.addLine(to: CGPoint(x: cardRect.maxX, y: cardRect.maxY))
        context.addLine(to: CGPoint(x: cardRect.maxX, y: cardRect.maxY - cornerLength))
        
        context.strokePath()
    }
}