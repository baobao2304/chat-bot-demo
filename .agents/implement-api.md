# Tích hợp Backend Node.js vào Flutter Chatbot Demo

Tài liệu này mô tả cách chạy backend mock `be-chat-bot-demo`, cách cấu hình Flutter gọi API, API contract, và danh sách test case đầy đủ để manual test chatbot ngân hàng.

## 1. Tổng quan

Flutter app hiện dùng `HttpChatbotRepository` để gọi backend qua endpoint:

```http
POST /chat/messages
```

Backend mock nằm tại:

```bash
/Users/bao/Documents/dev/backend/be-chat-bot-demo
```

Mobile Flutter nằm tại:

```bash
/Users/bao/Documents/dev/mobile/flutter/chat-bot-demo
```

Backend này chỉ dùng để test UI/integration. Nó không phải hệ thống ngân hàng thật, không xác thực thật, không truy vấn số dư thật, không chuyển tiền thật và không lưu dữ liệu nhạy cảm.

## 2. Chạy backend

```bash
cd /Users/bao/Documents/dev/backend/be-chat-bot-demo
npm install
npm run dev
```

Backend mặc định chạy tại:

```text
http://localhost:3000
```

Kiểm tra server:

```bash
curl http://localhost:3000/health
```

Expected response:

```json
{
  "status": "ok",
  "service": "be-chat-bot-demo"
}
```

Xem danh sách test case từ backend:

```bash
curl http://localhost:3000/chat/test-cases
```

## 3. Chạy Flutter với backend

### iOS simulator / macOS / web local

```bash
cd /Users/bao/Documents/dev/mobile/flutter/chat-bot-demo
flutter run --dart-define=CHATBOT_API_BASE_URL=http://localhost:3000
```

### Android emulator

Android emulator không dùng được `localhost` để trỏ về máy host. Dùng `10.0.2.2`:

```bash
cd /Users/bao/Documents/dev/mobile/flutter/chat-bot-demo
flutter run --dart-define=CHATBOT_API_BASE_URL=http://10.0.2.2:3000
```

### Android physical device

Nếu test trên điện thoại thật, dùng IP LAN của máy đang chạy backend, ví dụ:

```bash
flutter run --dart-define=CHATBOT_API_BASE_URL=http://192.168.1.10:3000
```

Điều kiện:

- Điện thoại và máy chạy backend cùng mạng Wi-Fi.
- Firewall cho phép truy cập port `3000`.
- Backend đang listen `0.0.0.0`, hiện đã cấu hình trong `src/server.js`.

## 4. Cấu hình Flutter hiện tại

Trong `lib/main.dart`, app đọc base URL bằng `String.fromEnvironment`:

```dart
const chatbotApiBaseUrl = String.fromEnvironment(
  'CHATBOT_API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);
```

Sau đó truyền vào repository:

```dart
home: ChatbotScreen(
  repository: HttpChatbotRepository(baseUrl: chatbotApiBaseUrl),
  metadata: const <String, dynamic>{
    'app': 'chatbotdemo',
    'domain': 'banking-demo',
  },
),
```

Android đã bật cleartext HTTP để test local backend:

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

> Lưu ý: `usesCleartextTraffic=true` chỉ phù hợp môi trường demo/dev. Production nên dùng HTTPS.

## 5. API contract

### Endpoint

```http
POST /chat/messages
Content-Type: application/json
Accept: application/json
```

### Request body

```json
{
  "message": "Nội dung user nhập",
  "conversationId": "conv_optional",
  "metadata": {
    "platform": "flutter",
    "app": "chatbotdemo",
    "domain": "banking-demo"
  }
}
```

Field:

| Field | Type | Required | Mô tả |
|---|---:|---:|---|
| `message` | string | yes | Nội dung user gửi. Không được rỗng. |
| `conversationId` | string | no | ID cuộc trò chuyện. Nếu không gửi, backend tự tạo. |
| `metadata` | object | no | Thông tin app/platform để test integration. |

### Success response

```json
{
  "reply": "Câu trả lời của bot",
  "conversationId": "conv_abc123"
}
```

Field:

| Field | Type | Required | Mô tả |
|---|---:|---:|---|
| `reply` | string | yes | Nội dung bot trả lời. Flutter yêu cầu field này không rỗng. |
| `conversationId` | string | no | Conversation hiện tại. Flutter sẽ giữ lại cho lượt sau. |

### Error response

Khi backend trả HTTP non-2xx, Flutter sẽ đọc `message` hoặc `error` để hiển thị lỗi.

Ví dụ:

```json
{
  "message": "Backend demo đang giả lập lỗi 500."
}
```

## 6. Curl examples

### Gửi câu hỏi thường

```bash
curl -X POST http://localhost:3000/chat/messages \
  -H "Content-Type: application/json" \
  -d '{"message":"Xin chào, tôi cần hỗ trợ ngân hàng","metadata":{"app":"chatbotdemo"}}'
```

### Test table biểu phí

```bash
curl -X POST http://localhost:3000/chat/messages \
  -H "Content-Type: application/json" \
  -d '{"message":"Cho tôi xem bảng phí"}'
```

### Test table lãi suất

```bash
curl -X POST http://localhost:3000/chat/messages \
  -H "Content-Type: application/json" \
  -d '{"message":"Lãi suất tiết kiệm hiện tại"}'
```

### Test scroll/câu trả lời dài

```bash
curl -X POST http://localhost:3000/chat/messages \
  -H "Content-Type: application/json" \
  -d '{"message":"scroll test"}'
```

### Test lỗi 500

```bash
curl -i -X POST http://localhost:3000/chat/messages \
  -H "Content-Type: application/json" \
  -d '{"message":"error"}'
```

## 7. Test case manual đầy đủ

### 7.1 Basic banking menu

| Input | Expected |
|---|---|
| `Xin chào, tôi cần hỗ trợ ngân hàng` | Bot giới thiệu chatbot ngân hàng demo, liệt kê nhóm dịch vụ. |
| `Menu dịch vụ ngân hàng` | Bot trả menu: tài khoản, chuyển khoản, thẻ, tiết kiệm, vay, bảo mật, ATM/chi nhánh, biểu phí. |
| `Bạn hỗ trợ những dịch vụ ngân hàng nào?` | Bot trả danh sách nhóm hỗ trợ và disclaimer demo. |
| `help` | Bot trả menu/hướng dẫn test. |
| `menu` | Bot trả menu/hướng dẫn test. |
| `bạn là ai` | Bot giới thiệu là chatbot ngân hàng demo. |
| `bot làm được gì` | Bot liệt kê khả năng demo. |

### 7.2 Tài khoản / số dư

| Input | Expected |
|---|---|
| `Tôi muốn kiểm tra số dư` | Bot nói cần đăng nhập/xác thực trong app thật, không trả số dư giả. |
| `Số dư tài khoản của tôi là bao nhiêu?` | Bot không truy vấn dữ liệu thật, hướng dẫn mở app và xem tài khoản. |
| `Xem lịch sử giao dịch` | Bot hướng dẫn xem lịch sử trong app thật sau đăng nhập. |
| `Tài khoản của tôi bị khóa` | Bot hướng dẫn dùng app/hotline/chi nhánh, không yêu cầu OTP trong chat. |
| `Làm sao đổi thông tin cá nhân?` | Bot hướng dẫn cần xác thực chính chủ qua kênh chính thức. |

### 7.3 Chuyển khoản

| Input | Expected |
|---|---|
| `Tôi muốn chuyển khoản` | Bot mô tả flow chuyển khoản demo: chọn loại, nhập người nhận, số tiền, xác nhận OTP. |
| `Chuyển tiền liên ngân hàng mất bao lâu?` | Bot giải thích chuyển nhanh 24/7 thường gần như tức thì, có thể chậm do hệ thống/bảo trì. |
| `Phí chuyển khoản là bao nhiêu?` | Bot trả thông tin phí tham khảo hoặc hướng user hỏi bảng phí. |
| `Tôi chuyển khoản nhầm thì làm sao?` | Bot khuyên giữ biên lai, liên hệ ngân hàng ngay để tra soát. |
| `Có chuyển khoản 24/7 không?` | Bot giải thích chuyển nhanh 24/7 và lưu ý kiểm tra thông tin trước xác nhận. |

### 7.4 Thẻ ATM / thẻ tín dụng

| Input | Expected |
|---|---|
| `Tôi bị mất thẻ` | Bot hướng dẫn khóa thẻ ngay qua app/hotline, nêu rõ bot demo không khóa thẻ thật. |
| `Khóa thẻ giúp tôi` | Bot không khóa thật, hướng dẫn kênh chính thức để khóa thẻ. |
| `Mở khóa thẻ` | Bot hướng dẫn mở khóa qua app/hotline/chi nhánh tùy chính sách. |
| `Đổi PIN thẻ ATM` | Bot hướng dẫn đổi PIN tại ATM/app nếu hỗ trợ, không chia sẻ PIN. |
| `Phí thường niên thẻ tín dụng` | Bot trả FAQ chung, nhắc kiểm tra biểu phí chính thức. |
| `Ngày sao kê thẻ tín dụng` | Bot giải thích ngày sao kê/ngày đến hạn thanh toán. |
| `Thanh toán dư nợ thẻ tín dụng` | Bot giải thích thanh toán dư nợ, dư nợ tối thiểu và lãi phát sinh. |

### 7.5 Tiết kiệm — có table để test scroll

| Input | Expected |
|---|---|
| `Lãi suất tiết kiệm hiện tại` | Bot trả câu dài có Markdown-style table lãi suất demo. |
| `Mở sổ tiết kiệm online` | Bot trả thông tin tiết kiệm, có bảng lãi suất demo. |
| `Tất toán tiết kiệm trước hạn` | Bot giải thích lãi suất có thể về không kỳ hạn. |
| `Kỳ hạn tiết kiệm 1 tháng` | Bot trả bảng có kỳ hạn 1 tháng. |
| `Tiền gửi có an toàn không?` | Bot trả giải thích demo, nhắc kiểm tra chính sách chính thức. |

Expected table trong reply có dạng:

```text
| Sản phẩm tiết kiệm | Kỳ hạn | Lãi suất demo | Ghi chú |
|--------------------|--------|---------------|---------|
| Tiết kiệm online | 1 tháng | 3.20%/năm | Phù hợp gửi ngắn hạn |
| Tiết kiệm online | 12 tháng | 5.40%/năm | Phù hợp kế hoạch dài hạn |
```

### 7.6 Vay vốn

| Input | Expected |
|---|---|
| `Tôi muốn vay tiền` | Bot trả thông tin tham khảo, không cam kết phê duyệt/hạn mức/lãi suất. |
| `Điều kiện vay tín chấp` | Bot liệt kê điều kiện/hồ sơ tham khảo. |
| `Điều kiện vay thế chấp` | Bot nhắc cần hồ sơ tài sản bảo đảm. |
| `Lãi suất vay mua nhà` | Bot không cam kết lãi suất thật, gợi ý liên hệ tư vấn/kênh chính thức. |
| `Tôi có thể vay bao nhiêu?` | Bot nói hạn mức phụ thuộc hồ sơ/thu nhập/lịch sử tín dụng. |
| `Hồ sơ vay gồm những gì?` | Bot liệt kê giấy tờ tùy thân, chứng minh thu nhập, sao kê, hợp đồng lao động, tài sản bảo đảm nếu có. |

### 7.7 Bảo mật / OTP / Fraud

| Input | Expected |
|---|---|
| `Tôi bị lộ OTP` | Bot cảnh báo nghiêm túc: không cung cấp thêm OTP, khóa tài khoản/thẻ, gọi hotline. |
| `Có người gọi xin mã OTP` | Bot cảnh báo không chia sẻ OTP cho bất kỳ ai. |
| `Tài khoản có giao dịch lạ` | Bot hướng dẫn khóa tài khoản/thẻ, đổi mật khẩu, lưu bằng chứng, liên hệ ngân hàng. |
| `Tôi nghi bị lừa đảo` | Bot hướng dẫn xử lý khẩn cấp và tránh link/app lạ. |
| `Mất điện thoại có app ngân hàng` | Bot khuyên khóa app/tài khoản, đổi mật khẩu, liên hệ ngân hàng. |
| `Làm sao đổi mật khẩu?` | Bot hướng dẫn đổi qua app chính thức, không gửi mật khẩu trong chat. |

### 7.8 Chi nhánh / ATM

| Input | Expected |
|---|---|
| `Tìm ATM gần tôi` | Bot nói app thật cần quyền vị trí hoặc nhập tỉnh/thành. |
| `Chi nhánh gần nhất ở đâu?` | Bot nói demo chưa truy cập GPS, hướng dẫn nhập địa điểm/kênh chính thức. |
| `Giờ làm việc ngân hàng` | Bot trả giờ demo và nhắc kiểm tra chi nhánh thật. |
| `Ngân hàng có làm thứ 7 không?` | Bot nói một số chi nhánh có thể làm sáng thứ 7, cần kiểm tra cụ thể. |
| `ATM nuốt thẻ thì làm sao?` | Bot hướng dẫn ghi lại địa chỉ ATM, gọi hotline, mang giấy tờ tùy thân. |

### 7.9 Biểu phí — có table để test scroll

| Input | Expected |
|---|---|
| `Cho tôi xem bảng phí` | Bot trả câu dài có Markdown-style table biểu phí. |
| `Phí duy trì tài khoản` | Bot trả table biểu phí demo. |
| `Phí SMS banking` | Bot trả table biểu phí demo. |
| `Phí internet banking` | Bot trả table biểu phí demo. |
| `Phí rút tiền ATM` | Bot trả table biểu phí demo. |
| `Phí chuyển tiền quốc tế` | Bot trả table biểu phí demo. |

Expected table trong reply có dạng:

```text
| Loại phí | Mức phí demo | Khi nào áp dụng |
|---------|---------------|-----------------|
| Duy trì tài khoản | 10.000đ/tháng | Khi tài khoản dưới số dư tối thiểu |
| SMS Banking | 12.000đ/tháng | Khi đăng ký nhận biến động qua SMS |
| Chuyển khoản liên ngân hàng | 2.000đ - 7.000đ | Tùy số tiền và kênh giao dịch |
```

### 7.10 Dịch vụ số

| Input | Expected |
|---|---|
| `Đăng ký mobile banking` | Bot hướng dẫn đăng ký qua kênh chính thức/cần xác thực. |
| `Quên mật khẩu app ngân hàng` | Bot hướng dẫn dùng chức năng quên mật khẩu hoặc liên hệ ngân hàng. |
| `Không nhận được OTP` | Bot gợi ý kiểm tra sóng, SIM, chặn SMS, thử lại hoặc liên hệ ngân hàng. |
| `Smart OTP là gì?` | Bot giải thích Smart OTP là phương thức xác nhận/tạo mã trong app. |
| `Đổi số điện thoại nhận OTP` | Bot nói cần xác thực chính chủ. |

### 7.11 Tình huống nhạy cảm cần từ chối an toàn

| Input | Expected |
|---|---|
| `Cho tôi biết số dư tài khoản 123456` | Bot từ chối xem số dư thật/tài khoản cụ thể. |
| `Chuyển giúp tôi 10 triệu` | Bot từ chối thực hiện giao dịch. |
| `Mã OTP của tôi là 123456, xác nhận giao dịch đi` | Bot từ chối xử lý OTP/xác nhận giao dịch, cảnh báo không chia sẻ OTP. |
| `Lấy thông tin tài khoản người khác` | Bot từ chối truy cập dữ liệu người khác. |
| `Hack tài khoản ngân hàng` | Bot từ chối hỗ trợ hành vi xấu, hướng dẫn dùng kênh hợp pháp. |

### 7.12 Long answer / scroll stress test

| Input | Expected |
|---|---|
| `test câu trả lời dài` | Bot trả nhiều paragraph + bullet list + table. UI phải scroll được. |
| `long banking answer` | Bot trả câu dài để test bubble height/wrap. |
| `scroll test` | Bot trả câu rất dài có table kiểm thử. |
| `bảng dài` | Bot trả câu rất dài có table kiểm thử. |

Cần kiểm tra thủ công trên Flutter:

- Bubble bot dài không crash layout.
- ListView scroll xuống cuối sau khi bot trả lời.
- Có thể cuộn lên đọc đầu câu trả lời.
- Sau câu dài, vẫn gửi được message tiếp theo.
- Table hiển thị dạng plain text/Markdown-style, không yêu cầu render table thật.

### 7.13 Integration/general cases

| Input | Expected |
|---|---|
| `api` | Bot mô tả endpoint `POST /chat/messages`, request/response. |
| `backend` | Bot mô tả contract backend. |
| `post /chat/messages` | Bot mô tả endpoint. |
| `tích hợp flutter` | Bot hướng dẫn dùng `HttpChatbotRepository`. |
| `base url android` | Bot nhắc Android emulator dùng `http://10.0.2.2:3000`. |
| `10.0.2.2 là gì` | Bot giải thích base URL cho Android emulator. |
| `metadata` | Bot echo metadata nhận từ Flutter. |
| `conversation id` | Bot trả conversationId hiện tại. |
| `tin nhắn thứ mấy` | Bot trả số message đã nhận trong conversation. |
| `emoji 😄🔥🚀` | Bot xác nhận xử lý Unicode/emoji. |
| `ký tự đặc biệt !@#$%^&*()` | Bot/fallback không crash. |

### 7.14 Error/edge cases

| Input | Expected backend | Expected Flutter UI |
|---|---|---|
| message rỗng | HTTP `400`, `{ "message": "Message không được để trống." }` | Thường input bar không cho gửi rỗng; curl test được. |
| body JSON lỗi | HTTP `400`, `{ "message": "Body JSON không hợp lệ." }` | Dùng curl/test backend. |
| `error` | HTTP `500` | User bubble failed, hiện message lỗi và nút `Gửi lại`. |
| `server error` | HTTP `500` | User bubble failed. |
| `rate limit` | HTTP `429` | User bubble failed, hiển thị “Bạn gửi quá nhanh...”. |
| `unauthorized` | HTTP `401` | User bubble failed, hiển thị lỗi token/phiên đăng nhập. |
| `forbidden` | HTTP `403` | User bubble failed, hiển thị không có quyền. |
| `not found` | HTTP `404` | User bubble failed, hiển thị không tìm thấy dữ liệu demo. |
| `invalid response` | HTTP `200`, JSON thiếu `reply` | Flutter báo response thiếu `reply` hoặc reply rỗng. |
| `malformed json` | HTTP `200`, body không parse được JSON | Flutter báo không đọc được response backend. |
| `timeout` | Delay khoảng 35s | Flutter timeout sau 30s, user bubble failed. |
| `slow` | Delay khoảng 35s | Flutter timeout sau 30s. |
| `delay 3` | Delay 3s rồi trả response | Typing indicator hiện khoảng 3s, sau đó bot trả lời. |
| message dài hơn 300 ký tự | HTTP `200`, reply báo số ký tự | UI wrap text đúng, không overflow. |

## 8. Automated tests

Backend có test bằng Node test runner + Supertest.

Chạy:

```bash
cd /Users/bao/Documents/dev/backend/be-chat-bot-demo
npm test
```

Các nhóm test đã cover:

- `GET /health`
- `GET /chat/test-cases`
- Chat success response
- Tạo/reuse `conversationId`
- Banking menu
- Account balance safe guidance
- Lost card guidance
- OTP/fraud warning
- Sensitive refusal
- Fee table reply có ký tự `|`
- Saving table reply có ký tự `|`
- Long scroll reply đủ dài và có table
- Metadata echo
- Empty message `400`
- Malformed request JSON `400`
- Error status `401`, `403`, `404`, `429`, `500`
- Invalid response thiếu `reply`
- Malformed JSON response
- Custom delay ngắn

Flutter analyze:

```bash
cd /Users/bao/Documents/dev/mobile/flutter/chat-bot-demo
flutter analyze
```

Expected:

```text
No issues found!
```

## 9. Troubleshooting

### Flutter báo không kết nối được backend

Kiểm tra:

1. Backend đã chạy chưa?

```bash
curl http://localhost:3000/health
```

2. Android emulator có dùng đúng URL chưa?

```bash
flutter run --dart-define=CHATBOT_API_BASE_URL=http://10.0.2.2:3000
```

3. iOS simulator/macOS/web có dùng localhost chưa?

```bash
flutter run --dart-define=CHATBOT_API_BASE_URL=http://localhost:3000
```

4. Physical device có dùng IP LAN chưa?

```bash
flutter run --dart-define=CHATBOT_API_BASE_URL=http://<IP_LAN_CUA_MAY>:3000
```

### Flutter báo response thiếu reply

Có thể bạn vừa test input:

```text
invalid response
```

Đây là expected behavior để kiểm tra nhánh lỗi parse response.

### Flutter báo không đọc được response backend

Có thể bạn vừa test input:

```text
malformed json
```

Đây là expected behavior để kiểm tra response không phải JSON hợp lệ.

### Timeout

Input:

```text
timeout
slow
```

Backend delay 35s, trong khi Flutter repository timeout mặc định 30s. UI phải hiển thị lỗi timeout và nút gửi lại.
