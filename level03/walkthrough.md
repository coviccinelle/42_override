RELRO               STACK CANARY       NX               PIE             RPATH        RUNPATH         FILE
Partial RELRO 🟡    Canary found 🟢     NX enabled 🟢    No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level03/level03
-----
---

# 📒 NHẬT KÝ KHAI THÁC: LEVEL 03 @ OVERRIDE

## 1. Phân tích tĩnh (Static Analysis)

Khác với các bài trước, `level03` có các lớp bảo vệ khá đầy đủ (**Canary found**, **NX enabled**), báo hiệu rằng chúng ta không thể dùng các chiêu thức tràn bộ đệm (Buffer Overflow) thông thường.

### Lỗ hổng nằm ở Logic:

Khi dịch ngược bằng Ghidra, chúng ta thấy chuỗi logic sau:

1. **Hàm `main**`: Nhận mật khẩu từ người dùng và gọi hàm `test(param_1, param_2)`.
2. **Hàm `test**`: Tính toán giá trị hiệu số: `ctx = param_2 - param_1`.
3. **Hàm `decrypt(ctx)**`: Dùng giá trị `ctx` này để giải mã một mảng dữ liệu bí mật.

---

## 2. Giải mã toán học (Reverse Engineering the Logic)

Trong hàm `decrypt`, chương trình thực hiện phép toán **XOR** trên một mảng Hex tĩnh để tạo ra chuỗi kiểm tra.

### Phép toán XOR bí mật:

Chương trình lấy mảng `local_21` (bắt đầu bằng `0x51`) XOR với biến `ctx`. Nếu kết quả là chuỗi `"Congratulations!"`, bạn thắng.

* **Dữ liệu gốc:** `0x51` (ký tự đầu tiên của mảng bí mật).
* **Mục tiêu:** Chữ `'C'` (ký tự đầu tiên của "Congratulations!").
* **Công thức:** $0x51 \oplus \text{ctx} = \text{'C'}$

Áp dụng tính chất của XOR: Nếu $A \oplus B = C$ thì $A \oplus C = B$.

* $0x51$ (Thập phân: $81$)
* $'C'$ (ASCII: $67$)
* $81 \oplus 67 = \mathbf{18}$ (Đây là con số "Ma thuật" ta cần tìm).

---

## 3. Khám phá thực tế bằng GDB (Dynamic Analysis)

Tại sao nhập `18` vào chương trình lại không được? Đó là vì Ghidra đã hiển thị thiếu thông tin về cách hàm `test` nhận tham số.

### Bước ngoặt từ GDB:

Khi sử dụng lệnh `x/2wd $ebp+8` trong GDB, chúng ta phát hiện ra cấu trúc thực sự của Stack khi hàm `test` chạy:

* **`param_1`**: Giá trị bạn nhập vào (Ví dụ: `1234`).
* **`param_2`**: Một con số cố định được chương trình tự nạp vào Stack là `322424845`.

### Công thức cuối cùng:

Để hàm `decrypt` nhận được giá trị `18`, ta cần thỏa mãn phương trình:


$$\text{param\_2} - \text{param\_1} = 18$$

$$\mathbf{322424845} - \text{Mật khẩu} = 18$$

$$\Rightarrow \text{Mật khẩu} = 322424845 - 18 = \mathbf{322424827}$$

---

## 4. Các bước giải quyết (Step-by-Step)

1. **Tính toán giá trị đích:** Lấy ký tự đầu mảng XOR với chữ 'C' để ra số `18`.
2. **Sử dụng GDB:** Đặt `break test`, chạy chương trình và dùng `x/2wd $ebp+8` để tìm "con số bí mật" đang nằm trên Stack (`322424845`).
3. **Tính toán bù trừ:** Lấy số bí mật trừ đi 18 để ra mật khẩu cần nhập.
4. **Thực thi:** Nhập mật khẩu đã tính toán để lấy Shell.

---

## 5. Bài học rút ra

* **Đừng tin hoàn toàn vào Decompiler:** Ghidra rất mạnh nhưng đôi khi nó không hiển thị đúng các tham số được đẩy lên Stack một cách thủ công. GDB luôn là "trọng tài" chính xác nhất.
* **XOR là phép toán đảo ngược:** Chỉ cần biết kết quả mong muốn và dữ liệu gốc, bạn luôn tìm được "khóa" (Key) bằng cách XOR chúng với nhau.
* **Giá trị rác trên Stack:** Đôi khi các bài Lab lợi dụng việc "nhặt" lại dữ liệu cũ trên Stack để làm tham số ẩn, buộc người chơi phải dùng Debugger để soi.
