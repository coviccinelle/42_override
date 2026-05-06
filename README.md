# 42_override

checksec Explainations:

đây là bảng thuật ngữ cực kỳ quan trọng nếu bạn đang dấn thân vào mảng **Pwnable** hoặc **Binary Security**. Những cái tên này thực chất là các "lớp giáp" bảo vệ một file thực thi (binary) trước các cuộc tấn công khai thác lỗ hổng.

Dưới đây là giải thích đơn giản và thực tế nhất cho từng cái:

### 1. STACK CANARY (Chim yến trong mỏ than)
*   **Nó là gì:** Một giá trị ngẫu nhiên được đặt ngay **trước** địa chỉ trả về (return address) trong stack.
*   **Cơ chế:** Trước khi một hàm kết thúc, chương trình sẽ kiểm tra xem giá trị này còn nguyên vẹn không.
*   **Mục đích:** Chống **Stack Overflow**. Nếu một hacker cố tình ghi đè stack để chiếm quyền điều khiển, họ sẽ làm thay đổi giá trị Canary này. Chương trình phát hiện sự thay đổi và lập tức tự sát (`SIGABRT`) để ngăn chặn việc thực thi mã độc.



---

### 2. NX (No-Execute)
*   **Nó là gì:** Một kỹ thuật đánh dấu các vùng nhớ (như Stack hoặc Heap) là **không thể thực thi**.
*   **Mục đích:** Chống lại việc thực thi **Shellcode**. Ngày xưa, hacker thường nhét mã độc vào stack rồi nhảy vào đó để chạy. Với NX, dù hacker có nhét được mã vào memory, chương trình cũng không cho phép chạy mã ở đó.
*   **Tên khác:** Trên Windows nó được gọi là **DEP** (Data Execution Prevention).

---

### 3. PIE (Position Independent Executable)
*   **Nó là gì:** Làm cho toàn bộ file thực thi có thể chạy ở bất kỳ địa chỉ nào trong bộ nhớ.
*   **Mục đích:** Kết hợp với **ASLR** (Address Space Layout Randomization) để làm xáo trộn địa chỉ bộ nhớ mỗi khi chương trình chạy.
*   **Hiệu quả:** Hacker sẽ không biết chính xác hàm `system` hay địa chỉ các biến nằm ở đâu để mà "nhắm bắn". Muốn khai thác được, họ phải tìm cách "leak" (làm lộ) địa chỉ bộ nhớ trước.

---

### 4. RELRO (Relocation Read-Only)
*   **Nó là gì:** Bảo vệ bảng **GOT** (Global Offset Table) — nơi lưu trữ địa chỉ các hàm thư viện (như `printf`, `system`).
*   **Phân loại:**
    *   **Partial RELRO:** Một phần bảng GOT vẫn có thể bị ghi đè.
    *   **Full RELRO:** Toàn bộ bảng GOT sẽ được đặt ở chế độ **Chỉ đọc (Read-Only)** sau khi chương trình load xong.
*   **Mục đích:** Ngăn chặn kỹ thuật **GOT Hijacking** (thay đổi địa chỉ hàm `printf` thành `system`).

---

### 5. RPATH và RUNPATH
Hai cái này liên quan đến việc chương trình tìm các thư viện liên kết động (`.so` hoặc `.dll`) ở đâu khi nó khởi chạy.

*   **RPATH (Run Path):** Là một đường dẫn cứng được nhúng vào file thực thi. Hệ thống sẽ ưu tiên tìm thư viện ở đây **trước cả** biến môi trường `LD_LIBRARY_PATH`.
*   **RUNPATH:** Tương tự như RPATH, nhưng nó có độ ưu tiên thấp hơn. Nếu có `LD_LIBRARY_PATH`, hệ thống sẽ dùng cái đó trước rồi mới ngó tới RUNPATH.
*   **Rủi ro bảo mật:** Nếu một chương trình có RPATH/RUNPATH trỏ đến một folder mà hacker có quyền ghi (như `/tmp`), hacker có thể bỏ một file thư viện giả mạo vào đó để chương trình load nhầm mã độc (**Library Preloading Attack**).

---

### Tóm tắt bằng hình ảnh ẩn dụ:
| Thuật ngữ | Ẩn dụ cho dễ hiểu |
| :--- | :--- |
| **Stack Canary** | Cái bẫy chuông ở cửa, ai bước qua mà không biết là chuông reo. |
| **NX** | Biển báo "Cấm diễn thuyết" tại khu vực để đồ (chỉ cho chứa dữ liệu, không cho chạy mã). |
| **PIE/ASLR** | Ngôi nhà di động, mỗi ngày nằm ở một tọa độ khác nhau trên bản đồ. |
| **RELRO** | Khóa tủ hồ sơ quan trọng (GOT) lại, không cho ai sửa đổi địa chỉ bên trong. |
| **RPATH/RUNPATH** | Tờ giấy ghi địa chỉ "Tìm mua đồ ở cửa hàng này này". |
