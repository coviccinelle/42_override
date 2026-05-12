RELRO                STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
Partial RELRO 🟡     Canary found 🟢        NX enabled 🟢      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level06/level06

--------------

# 📒 NHẬT KÝ KHAI THÁC: LEVEL 06 @ OVERRIDE

## 1. Dấu hiệu nhận biết & Rào cản

* **Mục tiêu:** Vượt qua hàm `auth()` để kích hoạt `system("/bin/sh")`.
* **Bảo mật:**
* `Canary found`: Chống tràn bộ đệm ghi đè EIP.
* `NX enabled`: Chống thực thi Shellcode trên Stack.
* `ptrace(PTRACE_TRACEME)`: Cơ chế chống Debug (Anti-debugging). Nếu phát hiện đang bị GDB theo dõi, chương trình sẽ tự ngắt.



---

## 2. Giải phẫu Logic thuật toán `auth()`

Thay vì tìm lỗi bộ nhớ, ta thực hiện **Reverse Engineering** để tìm ra quy luật sinh Serial từ Login. Thuật toán này là một hàm băm (Hash) có thể dự đoán được.

### Bước 1: Khởi tạo giá trị (The Seed)

Chương trình lấy ký tự thứ 4 (vị trí `index 3`) của Login để làm móng.


$$local\_14 = (Login[3] \oplus 0x1337) + 0x5eeded$$

### Bước 2: Vòng lặp nhào nặn (The Hashing Loop)

Chương trình duyệt qua từng ký tự của Login (từ đầu đến cuối). Với mỗi ký tự, nó cập nhật giá trị Serial theo công thức:


$$Serial_{mới} = Serial_{cũ} + (Ký\_tự[i] \oplus Serial_{cũ}) \pmod{1337}$$

> **Ghi chú:** `0x539` trong mã máy chính là `1337` trong hệ thập phân.

---

## 3. Quá trình khai thác (The Keygen Strategy)

Do có cơ chế chống GDB, việc ngồi soi thanh ghi để lấy kết quả rất khó khăn. Giải pháp tối ưu là viết một script **Keygen** để tự tính Serial.

### Script Python "Bất bại" (One-liner)

Để tránh lỗi thụt lề khi copy-paste, hãy dùng lệnh một dòng này. Bạn chỉ cần thay `viiiit` bằng Login bạn muốn:

```bash
python -c 'l="viiiit"; s=(ord(l[3])^0x1337)+0x5eeded; [exec("v=(ord(c)^s)%1337\ns+=v") for c in l]; print(f"Login: {l}\nSerial: {s}")'

```

---

## 4. Bảng đối chiếu kết quả (Ví dụ)

| Login (Username) | Ký tự làm móng | Giá trị Seed | Serial cuối cùng |
| --- | --- | --- | --- |
| `gemini` | `i` | `6226121` | `6232354` |
| `viiiit` | `i` | `6226121` | `6232354` |
| `admin1` | `i` | `6226121` | `6232408` |

*(Lưu ý: "gemini" và "viiiit" có cùng ký tự thứ 4 là 'i' và cùng độ dài nên Serial có thể giống nhau).*

---

## 5. Các bước thực hiện thành công

1. **Chọn Login:** Chọn một chuỗi bất kỳ dài trên 6 ký tự (Ví dụ: `gemini`).
2. **Tính Serial:** Chạy script Python để lấy con số tương ứng.
3. **Vượt rào:** Chạy `./level06`, nhập Login đã chọn và dán số Serial vào.
4. **Chiếm quyền:** Sau khi thấy chữ `Authenticated!`, gõ `whoami` để xác nhận và lấy flag ở `/home/users/level07/.pass`.

---

## 6. Bài học rút ra

* **Logic Flaw:** Khi thuật toán kiểm tra bản quyền nằm hoàn toàn ở phía Client (Local), hacker có thể dịch ngược và tự tạo ra chìa khóa.
* **Anti-Debug Bypass:** Cơ chế `ptrace` bảo vệ chương trình khỏi GDB, nhưng không bảo vệ được chương trình khỏi việc bị đọc mã nguồn và mô phỏng lại thuật toán bằng ngôn ngữ khác (Python).
* **Indentation Matters:** Trong Python, khoảng trắng không chỉ để cho đẹp, nó là cấu trúc lệnh. Khi dùng môi trường tương tác, hãy ưu tiên dùng lệnh một dòng (One-liner) để đảm bảo tính ổn định.