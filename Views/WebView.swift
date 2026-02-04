import SwiftUI
import WebKit
import PhotosUI
import UniformTypeIdentifiers

// MARK: - ARKA PLAN MOTORU (Kamera Hilesi ve Prezi Yükleyici)
class WebViewStore: ObservableObject {
    let umingleView: WKWebView
    let preziView: WKWebView

    init() {
        // 1. Umingle Yapılandırması (Kamerayı Kandıran Kısım)
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let hookJS = """
        (function() {
            // Sanal bir tuval (canvas) oluştur
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d');
            
            // Swift'ten gelen görüntüleri tuvale çizen fonksiyon
            window.drawToFakeCamera = function(b64) {
                var img = new Image();
                img.onload = function() {
                    ctx.clearRect(0, 0, canvas.width, canvas.height);
                    ctx.drawImage(img, 0, 0, 1280, 720);
                };
                img.src = 'data:image/jpeg;base64,' + b64;
            };

            // Tuvalden bir video akışı (stream) al ve gerçek kamera gibi siteye yuttur
            var stream = canvas.captureStream(25);
            navigator.mediaDevices.getUserMedia = function(constraints) {
                return Promise.resolve(stream);
            };
            
            // Cihaz listesinde sanal bir kamera varmış gibi göster
            navigator.mediaDevices.enumerateDevices = function() {
                return Promise.resolve([{
                    deviceId: "virtual-cam",
                    kind: "videoinput",
                    label: "Sanal Sunum Kamerası"
                }]);
            };
        })();
        """
        let script = WKUserScript(source: hookJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        self.umingleView = WKWebView(frame: .zero, configuration: config)
        self.umingleView.load(URLRequest(url: URL(string: "https://umingle.com")!))

        // 2. Prezi Yapılandırması (Görüntü Kaynağı)
        self.preziView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 720))
        // !!! BURAYA KENDİ PREZİ LİNKİNİ YAPIŞTIR !!!
        let preziURL = "https://prezi.com/view/KENDI_LINKIN_BURAYA/" 
        self.preziView.load(URLRequest(url: URL(string: preziURL)!))
    }
}

// MARK: - ANA GÖRÜNÜM (Arayüz ve Butonlar)
struct WebView: View {
    // Uygulama girişi için gerekli url parametresi
    let url: URL 
    
    @StateObject private var store = WebViewStore()
    // Saniyede ~16 kare yakalama hızı
    let timer = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Ana Ekran (Umingle Sitesi)
            RepresentableWebView(webView: store.umingleView)
                .ignoresSafeArea()

            // Kontrol Paneli (Umingle'ın üzerinde yüzer)
            VStack {
                HStack(spacing: 30) {
                    // GERİ BUTONU
                    Button { sendKey(37) } label: {
                        ControlIcon(icon: "arrow.left.circle.fill", color: .blue)
                    }

                    // TAM EKRAN (PRESENT) BUTONU
                    Button { activatePresent() } label: {
                        Text("TAM EKRAN")
                            .font(.caption.bold())
                            .padding(10)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    // İLERİ BUTONU
                    Button { sendKey(39) } label: {
                        ControlIcon(icon: "arrow.right.circle.fill", color: .green)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
            }
            .padding(.bottom, 30)
        }
        .onReceive(timer) { _ in
            syncFrames()
        }
    }

    // MARK: - KONTROL FONKSİYONLARI

    private func activatePresent() {
        let js = """
        var btn = document.querySelector('.present-button') || document.querySelector('[data-test-id="present-button"]');
        if(btn){ btn.click(); } else {
            document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 80, which: 80}));
        }
        """
        store.preziView.evaluateJavaScript(js)
    }

    private func sendKey(_ key: Int) {
        let js = "document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: \(key),提名: \(key)}));"
        store.preziView.evaluateJavaScript(js)
    }

    private func syncFrames() {
        let config = WKSnapshotConfiguration()
        store.preziView.takeSnapshot(with: config) { image, _ in
            guard let img = image, let data = img.jpegData(compressionQuality: 0.6) else { return }
            let base64 = data.base64EncodedString()
            let js = "if(window.drawToFakeCamera){ window.drawToFakeCamera('\(base64)'); }"
            store.umingleView.evaluateJavaScript(js)
        }
    }
}

// MARK: - YARDIMCI YAPILAR

struct RepresentableWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ControlIcon: View {
    let icon: String
    let color: Color
    var body: some View {
        Image(systemName: icon)
            .resizable()
            .frame(width: 45, height: 45)
            .foregroundColor(color)
    }
}
