
RELRO             STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
Full RELRO 🟢     Canary found 🟢     NX disabled 🔴      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level08/level08
--------------

**CWD (Current Working Directory) Manipulation** kết hợp với **Directory Mirroring**.

---

# 📒 NHẬT KÝ KHAI THÁC: LEVEL 08 @ OVERRIDE

## 1. Phân tích mục tiêu & Đặc quyền

* **Binary:** `/home/users/level08/level08`
* **Đặc quyền:** Có bit **SUID của `level09**`. Điều này nghĩa là binary có "thượng phương bảo kiếm", nó có thể đọc bất cứ file nào mà `level09` có quyền truy cập, bao gồm cả file mật khẩu `/home/users/level09/.pass`.
* **Tính năng:** Chương trình đóng vai trò là một công cụ backup. Nó đọc file bạn yêu cầu và ghi bản sao vào đường dẫn: `./backups/[tên_file_của_bạn]`.

---

## 2. Lỗ hổng: Đường dẫn tương đối (Relative Path)

Binary sử dụng đường dẫn tương đối `./backups/` thay vì đường dẫn tuyệt đối (như `/var/log/backups/`).

* **Logic khai thác:** Binary sẽ tìm thư mục `backups` ngay tại nơi bạn đang đứng (`.` đại diện cho thư mục hiện hành).
* **Vấn đề tại thư mục nhà:** Tại `/home/users/level08`, thư mục `backups` thuộc quyền sở hữu của `level09` và bạn không có quyền tạo thêm thư mục con trong đó. Điều này ngăn cản chương trình tạo bản sao nếu file đầu vào có đường dẫn sâu (như `/home/users/...`).

---

## 3. Chiến thuật: Gương soi thư mục (Directory Mirroring)

Vì chương trình không đủ thông minh để tự tạo các thư mục cha (nó chỉ dùng hàm `open()` với cờ `O_CREAT` cho file cuối cùng), bạn đã thực hiện chiến thuật "xây cầu trước khi đi".

### Bước 1: Thay đổi môi trường thực thi

Bạn di chuyển sang `/tmp`. Đây là "vùng đất tự do", nơi người dùng bình thường có quyền `rwx` (đọc, ghi, thực thi) để tạo bất cứ thứ gì mình muốn.

### Bước 2: Xây dựng cấu trúc "gương"

Khi bạn đưa file `/home/users/level09/.pass` vào, binary sẽ cố gắng ghi vào:
`./backups/` + `home/users/level09/.pass`

Bạn đã thủ công tạo ra toàn bộ cấu trúc này trong `/tmp`:

1. `mkdir backups`
2. `mkdir backups/home`
3. `mkdir backups/home/users`
4. `mkdir backups/home/users/level09`

### Bước 3: Kích hoạt "Proxy"

Khi bạn chạy binary: `/home/users/level08/level08 /home/users/level09/.pass`

1. Binary dùng quyền SUID để đọc file mật khẩu thật.
2. Nó nhìn thấy thư mục `./backups/home/users/level09/` đã tồn tại sẵn trong `/tmp`.
3. Nó tạo file `.pass` bên trong đó và chép nội dung mật khẩu vào.

---

## 4. Kết quả & Bài học

* **Flag tìm thấy:** `fjAwpJNs2vvkFLRebEvAQ2hFZ4uQBWfHRsP62d8S`
* **Lý do thành công:** Bạn đã kiểm soát được **ngữ cảnh thực thi** của chương trình. Bằng cách thay đổi thư mục làm việc, bạn đã hướng một tác vụ đặc quyền (ghi file) vào một vị trí do bạn toàn quyền kiểm soát.

> **Ghi chú bảo mật:** Đây là lý do tại sao các chương trình SUID an toàn luôn phải sử dụng **Đường dẫn tuyệt đối** (Absolute Paths) và hạn chế tối đa việc tin tưởng vào môi trường do người dùng thiết lập (như thư mục hiện hành hay biến môi trường).

---