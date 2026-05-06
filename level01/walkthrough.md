
---

# 📒 NHẬT KÝ KHAI THÁC: LEVEL01 @ OVERRIDE

## 1. Quan sát thực thể (Reconnaissance)
Bước đầu tiên luôn là kiểm tra các lớp bảo vệ của file bằng lệnh `checksec`.

*   **NX (No-Execute): Disabled 🔴** $\rightarrow$ Đây là "chìa khóa" quan trọng nhất. Nó cho phép ta thực thi mã (shellcode) ngay trên vùng nhớ Stack hoặc Data.
*   **PIE: Disabled 🔴** $\rightarrow$ Các địa chỉ trong chương trình là cố định, không thay đổi mỗi lần chạy.
*   **Canary: No 🔴** $\rightarrow$ Không có "chim yến" canh cửa, ta có thể ghi đè thoải mái lên địa chỉ trả về (Return Address) mà không bị phát hiện giữa chừng.



---

## 2. Phân tích mã nguồn (Reverse Engineering)
Dùng Ghidra để đọc logic chương trình, ta phát hiện 3 điểm mấu chốt:

### A. Lỗ hổng Logic (The "Fake" Auth)
Trong hàm `main`, dù ta nhập đúng password hay sai, chương trình đều thực hiện:
```c
if ((local_14 == 0) || (local_14 != 0)) {
    puts("nope, incorrect password...\n");
}
```
$\rightarrow$ **Kết luận:** Không bao giờ đăng nhập được bằng cách thông thường. Phải tìm cách "bẻ lái" luồng thực thi của CPU.

### B. Lỗ hổng Buffer Overflow (The Vulnerability)
Tại hàm `main`, biến `local_54` (nơi chứa password) được khai báo là:
*   `char local_54[64];` (Dung lượng 64 bytes).
*   Nhưng lệnh `fgets(local_54, 100, stdin);` cho phép nạp vào tới **100 bytes**.
$\rightarrow$ **Kết luận:** Ta dư ra $100 - 64 = 36$ bytes để ghi đè lên các vùng nhớ nhạy cảm phía sau mảng này trên Stack (bao gồm EBP và quan trọng nhất là EIP).

### C. Nơi đặt "Bom" (Shellcode Placement)
Hàm `verify_user_name` nhận username và lưu vào biến toàn cục `a_user_name`.
*   Vì biến này nằm ở phân đoạn `.bss` (địa chỉ cố định) và **NX disabled**, ta có thể biến username thành một cái "kho" chứa mã độc (shellcode).

---

## 3. Xây dựng Payload (Exploit Construction)

Mục tiêu của chúng ta là: **Khi hàm `main` kết thúc (lệnh `ret`), CPU thay vì quay về hệ điều hành thì phải nhảy đến nơi ta đặt Shellcode.**

### Bước 1: Chuẩn bị Shellcode
Ta dùng một đoạn mã máy (Assembly) có nhiệm vụ gọi hàm hệ thống `execve("/bin/sh")`.
*   Username nhập vào: `"dat_wil" + <Shellcode>`
*   Tại sao cần `"dat_wil"`? Vì chương trình kiểm tra 7 ký tự đầu, nếu không khớp nó sẽ thoát ngay lập tức.

### Bước 2: Tìm địa chỉ nhảy (Target Address)
Ta tìm địa chỉ của `a_user_name` bằng lệnh `nm`.
*   Giả sử địa chỉ là `0x0804a040`.
*   Vì 7 byte đầu là `"dat_wil"`, ta cần nhảy vào `0x0804a040 + 7 = 0x0804a047`.

### Bước 3: Tính toán khoảng cách (Offset)
Biến `local_54` rộng 64 bytes. Sau đó là các biến khác và EBP cũ.
*   Qua thử nghiệm (hoặc dùng GDB), ta thấy cần khoảng **80 bytes** rác (`A`) để lấp đầy từ đầu biến `local_54` đến vị trí của địa chỉ trả về (EIP).



---

## 4. Thực thi (Execution)
Câu lệnh cuối cùng kết nối mọi thứ lại:
```bash
(python -c 'print "dat_wil" + "SHELLCODE_HERE"'; python -c 'print "A"*80 + "\x47\xa0\x04\x08"'; cat) | ./level01
```

1.  **Phần 1 (Username):** Gửi "bom" (shellcode) vào bộ nhớ.
2.  **Phần 2 (Password):** Gửi 80 chữ A để tràn bộ đệm, sau đó ghi đè địa chỉ `0x0804a047` vào ô nhớ EIP.
3.  **Lệnh `cat`:** Giữ cho đường truyền luôn mở. Khi CPU nhảy vào shellcode và thực thi `/bin/sh`, lệnh `cat` cho phép ta gõ các lệnh như `whoami`, `ls` vào cái shell mới đó.

---

## 5. Bài học rút ra
*   **Always check bounds:** Lỗi bắt nguồn từ việc `fgets` đọc nhiều hơn kích thước mảng cho phép.
*   **NX & PIE:** Nếu hai cái này được bật, cách làm trên sẽ thất bại. Khi đó ta sẽ cần các kỹ thuật cao cấp hơn như **ROP (Return Oriented Programming)** hoặc **Information Leak**.
*   **Little Endian:** Khi viết địa chỉ vào payload, phải viết ngược (ví dụ `08 04 a0 47` thành `\x47\xa0\x04\x08`).</Shellcode>
*   

