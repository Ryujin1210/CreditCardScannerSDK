import SwiftUI
import AVFoundation

/// SwiftUI용 신용카드 스캔 카메라 뷰
public struct CameraView: View {
    
    /// 스캔 완료 콜백
    public let onScanComplete: (OCREngine.ScanResult) -> Void
    
    /// 취소 콜백
    public let onCancel: () -> Void
    
    /// 카메라 권한 상태
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    
    /// 스캔 상태
    @State private var scanState: ScanState = .ready
    
    /// 스캔 결과 메시지
    @State private var resultMessage: String = "카드를 가이드라인 안에 맞춰주세요"
    
    /// 스캔 상태 열거형
    public enum ScanState {
        case ready
        case scanning
        case success
        case failed
        
        public var backgroundColor: Color {
            switch self {
            case .ready:
                return Color.black.opacity(0.7)
            case .scanning:
                return Color.orange.opacity(0.8)
            case .success:
                return Color.green.opacity(0.8)
            case .failed:
                return Color.red.opacity(0.8)
            }
        }
    }
    
    public init(
        onScanComplete: @escaping (OCREngine.ScanResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onScanComplete = onScanComplete
        self.onCancel = onCancel
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraPermission == .authorized {
                // 카메라 뷰
                CameraPreviewView(
                    onScanComplete: handleScanResult,
                    onScanStateChange: { state, message in
                        withAnimation {
                            scanState = state
                            resultMessage = message
                        }
                    }
                )
                .ignoresSafeArea()
                
                // 카드 가이드라인 오버레이
                CardGuideOverlay()
                    .ignoresSafeArea()
                
                // UI 요소들
                VStack {
                    // 상단 결과 표시
                    HStack {
                        Text(resultMessage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(scanState.backgroundColor)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        // 닫기 버튼
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // 하단 스캔 버튼
                    Button(action: {
                        // CameraPreviewView에서 스캔 실행
                    }) {
                        Text("스캔하기")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 150, height: 50)
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                    .disabled(scanState == .scanning)
                    .opacity(scanState == .scanning ? 0.6 : 1.0)
                    .padding(.bottom, 30)
                }
                
            } else if cameraPermission == .denied {
                // 권한 거부 상태
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("카메라 권한이 필요합니다")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("설정에서 카메라 권한을 허용해주세요")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button("설정으로 이동") {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                }
                
            } else {
                // 로딩 상태
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("카메라를 준비하는 중...")
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
    }
    
    /// 카메라 권한 확인
    private func checkCameraPermission() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        
        if cameraPermission == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        }
    }
    
    /// 스캔 결과 처리
    private func handleScanResult(_ result: OCREngine.ScanResult) {
        withAnimation {
            if result.cardNumber != nil && result.expiryDate != nil {
                scanState = .success
                resultMessage = """
                카드번호: \(result.cardNumber!)
                유효기간: \(result.expiryDate!)
                신뢰도: \(Int(result.confidence * 100))%
                """
            } else if result.cardNumber != nil || result.expiryDate != nil {
                scanState = .failed
                var message = "부분 인식:\n"
                if let cardNumber = result.cardNumber {
                    message += "카드번호: \(cardNumber)\n"
                }
                if let expiryDate = result.expiryDate {
                    message += "유효기간: \(expiryDate)\n"
                }
                message += "신뢰도: \(Int(result.confidence * 100))%"
                resultMessage = message
            } else {
                scanState = .failed
                resultMessage = "카드 정보를 인식할 수 없습니다.\n다시 시도해주세요."
            }
        }
        
        // 성공한 경우 콜백 호출
        if scanState == .success {
            onScanComplete(result)
            
            // 1.5초 후 자동 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onCancel()
            }
        }
        
        // 3초 후 기본 상태로 복원
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                scanState = .ready
                resultMessage = "카드를 가이드라인 안에 맞춰주세요"
            }
        }
    }
}

/// 카메라 프리뷰를 위한 UIViewControllerRepresentable
private struct CameraPreviewView: UIViewControllerRepresentable {
    
    let onScanComplete: (OCREngine.ScanResult) -> Void
    let onScanStateChange: (CameraView.ScanState, String) -> Void
    
    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        let controller = CameraPreviewViewController()
        controller.onScanComplete = onScanComplete
        controller.onScanStateChange = { state, message in
            let scanState: CameraView.ScanState
            switch state {
            case .ready: scanState = .ready
            case .scanning: scanState = .scanning
            case .success: scanState = .success
            case .failed: scanState = .failed
            }
            onScanStateChange(scanState, message)
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {
        // 업데이트 로직이 필요한 경우 여기에 구현
    }
}

/// SwiftUI용 카메라 프리뷰 컨트롤러
private class CameraPreviewViewController: UIViewController {
    
    var onScanComplete: ((OCREngine.ScanResult) -> Void)?
    var onScanStateChange: ((PreviewScanState, String) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let ocrEngine = OCREngine()
    private var lastScanTime: Date = Date.distantPast
    private let scanInterval: TimeInterval = 1.0
    
    enum PreviewScanState {
        case ready, scanning, success, failed
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .hd1920x1080
        
        guard let captureSession = captureSession else { return }
        
        // 카메라 입력 설정
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
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
    
    private func startCamera() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopCamera() {
        captureSession?.stopRunning()
    }
    
    /// 현재 프레임을 캡처하여 스캔 수행
    func scanCurrentFrame() {
        guard let videoOutput = videoOutput,
              let connection = videoOutput.connection(with: .video) else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastScanTime) >= scanInterval else { return }
        lastScanTime = now
        
        onScanStateChange?(.scanning, "스캔 중...")
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraPreviewViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 자동 스캔 비활성화 - 수동 스캔만 지원
        // 실시간 자동 스캔을 원할 경우 여기서 구현
    }
}

/// 카드 가이드라인 오버레이 SwiftUI 뷰
private struct CardGuideOverlay: View {
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 전체 반투명 배경
                Color.black.opacity(0.5)
                
                // 카드 영역 계산
                let cardWidth = geometry.size.width * 0.8
                let cardHeight = cardWidth * 0.63 // 신용카드 표준 비율
                let cardFrame = CGRect(
                    x: (geometry.size.width - cardWidth) / 2,
                    y: (geometry.size.height - cardHeight) / 2,
                    width: cardWidth,
                    height: cardHeight
                )
                
                // 카드 영역을 투명하게 만들기
                Rectangle()
                    .frame(width: cardWidth, height: cardHeight)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .blendMode(.destinationOut)
                
                // 가이드라인 테두리
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cardWidth, height: cardHeight)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // 모서리 강조선
                CardCornerIndicators(cardFrame: cardFrame)
                    .stroke(Color.blue, lineWidth: 3)
            }
        }
        .compositingGroup()
    }
}

/// 카드 모서리 강조 표시기
private struct CardCornerIndicators: Shape {
    let cardFrame: CGRect
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerLength: CGFloat = 20
        
        // 좌상단
        path.move(to: CGPoint(x: cardFrame.minX, y: cardFrame.minY + cornerLength))
        path.addLine(to: CGPoint(x: cardFrame.minX, y: cardFrame.minY))
        path.addLine(to: CGPoint(x: cardFrame.minX + cornerLength, y: cardFrame.minY))
        
        // 우상단
        path.move(to: CGPoint(x: cardFrame.maxX - cornerLength, y: cardFrame.minY))
        path.addLine(to: CGPoint(x: cardFrame.maxX, y: cardFrame.minY))
        path.addLine(to: CGPoint(x: cardFrame.maxX, y: cardFrame.minY + cornerLength))
        
        // 좌하단
        path.move(to: CGPoint(x: cardFrame.minX, y: cardFrame.maxY - cornerLength))
        path.addLine(to: CGPoint(x: cardFrame.minX, y: cardFrame.maxY))
        path.addLine(to: CGPoint(x: cardFrame.minX + cornerLength, y: cardFrame.maxY))
        
        // 우하단
        path.move(to: CGPoint(x: cardFrame.maxX - cornerLength, y: cardFrame.maxY))
        path.addLine(to: CGPoint(x: cardFrame.maxX, y: cardFrame.maxY))
        path.addLine(to: CGPoint(x: cardFrame.maxX, y: cardFrame.maxY - cornerLength))
        
        return path
    }
}

// MARK: - 사용 예제
#if DEBUG
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(
            onScanComplete: { result in
                print("스캔 완료: \(result)")
            },
            onCancel: {
                print("스캔 취소")
            }
        )
    }
}
#endif