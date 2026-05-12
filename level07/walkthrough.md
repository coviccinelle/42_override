RELRO                STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
Partial RELRO 🟡     Canary found 🟢     NX disabled 🔴      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level07/level07

------------------ 
---

# 📒 NHẬT KÝ KHAI THÁC: LEVEL 07 @ OVERRIDE

## 1. Dấu hiệu và Lỗ hổng (The Vulnerability)

Chương trình cung cấp một dịch vụ lưu trữ số đơn giản. Tuy nhiên, qua dịch ngược mã nguồn, chúng ta phát hiện lỗ hổng **Out-of-Bounds (OOB) Write** tại hàm `store_number`.

* **Lỗi logic:** Chương trình nhận một `Index` từ người dùng nhưng không kiểm tra giới hạn trên (Upper bound). Nó tin tưởng hoàn toàn vào con số bạn nhập vào để tính toán địa chỉ ghi dữ liệu:
`*(uint *)(uVar2 * 4 + param_1) = uVar1;`
* **Rào cản (Sandbox):** Tác giả đã cài cắm hai "chốt chặn":
1. `index % 3 == 0`: Không cho phép ghi vào các index chia hết cho 3.
2. `number >> 24 == 0xb7`: Không cho phép nạp các số bắt đầu bằng byte `0xb7` (nhằm chặn các địa chỉ thư viện `libc` trên một số hệ thống).



---

## 2. Giải mã cấu trúc Stack (Stack Forensics)

Để điều khiển chương trình, chúng ta cần tìm **Saved EIP** (địa chỉ trả về) của hàm `main`. Đây là "vô lăng" điều hướng CPU.

Dựa trên dữ liệu thực tế từ GDB của bạn:

* **Địa chỉ Saved EIP:** `0xffffd30c`
* **Địa chỉ bắt đầu mảng (Index 1):** `0xffffd148` $\rightarrow$ **Index 0** nằm tại `0xffffd144`.

**Phép toán xác định mục tiêu:**
Sử dụng LaTeX để tính toán khoảng cách:


$$Distance = EIP\_address - Array\_start\_address = 0xffffd30c - 0xffffd144 = 0x1c8$$

$$0x1c8 \text{ (Hex)} = 456 \text{ (Bytes)}$$

$$\text{Target Index} = \frac{456}{4} = \mathbf{114}$$

---

## 3. Kỹ thuật "Vượt rào" bằng Integer Overflow

Mục tiêu của chúng ta là ghi vào **Index 114**, nhưng $114 \pmod 3 = 0$ nên bị hệ thống chặn.

**Mẹo Hacker:** Chúng ta lợi dụng việc máy tính sử dụng số nguyên 32-bit không dấu. Khi một số vượt quá giới hạn $2^{32}$, nó sẽ "quay vòng" (wrap around) về 0.

Để tìm một Index mới trỏ cùng vào một vị trí bộ nhớ nhưng không chia hết cho 3:


$$\text{New Index} = 114 + \frac{2^{32}}{4} = 114 + 1,073,741,824 = \mathbf{1,073,741,938}$$

Kiểm tra logic:

* $1,073,741,938 \pmod 3 = 1$ $\rightarrow$ **Thỏa mãn điều kiện, vượt qua bộ lọc!**
* Khi nhân với 4 (kích thước `int`): $1,073,741,938 \times 4 = 4,294,967,752$.
* Trong bộ nhớ 32-bit: $4,294,967,752 \equiv 456 \pmod{2^{32}}$.
* Kết quả: Nó trỏ chính xác vào độ dời 456 bytes (Index 114) mà chúng ta cần.

---

## 4. Chiến thuật Tấn công: Ret2Libc

Do Stack đã bị xóa sạch biến môi trường, chúng ta sử dụng kỹ thuật **Ret2Libc** để mượn các hàm có sẵn trong thư viện C chuẩn.

Chúng ta đã thiết lập một "chuỗi lệnh giả" trên Stack bắt đầu từ vị trí EIP (Index 114):

1. **Index 114 (EIP):** Ghi địa chỉ hàm `system()`. Khi `main` kết thúc, CPU sẽ nhảy vào đây thay vì thoát chương trình.
2. **Index 115 (Return Address):** Ghi địa chỉ hàm `exit()`. Sau khi `system` chạy xong, nó sẽ nhảy về đây để thoát "êm đẹp" mà không gây lỗi.
3. **Index 116 (Argument 1):** Ghi địa chỉ của chuỗi `"/bin/sh"`. Đây là tham số mà hàm `system()` sẽ lấy để thực thi.

---

## 5. Kết quả thực thi cuối cùng

Bạn đã nhập trình tự các lệnh "vàng":

1. `store` $\rightarrow$ `4159090384` $\rightarrow$ `1073741938` (Đưa `system` vào EIP).
2. `store` $\rightarrow$ `4159040368` $\rightarrow$ `115` (Đưa `exit` vào sau EIP).
3. `store` $\rightarrow$ `4160264172` $\rightarrow$ `116` (Đưa `"/bin/sh"` vào tham số).
4. `quit` $\rightarrow$ Kích hoạt chuỗi nổ.

**Kết quả:** Chương trình thực hiện `system("/bin/sh")` và trao cho bạn quyền kiểm soát Shell dưới danh nghĩa người dùng cấp cao hơn.

---

### Bài học rút ra:

* **Đừng tin vào mã nguồn tĩnh:** Ghidra báo `0x1bc`, nhưng thực tế trên máy lại là `0x1c8`. Luôn luôn tin vào dữ liệu **Live Debugging** từ GDB.
* **Toán học là vũ khí:** Integer Overflow không chỉ là một lỗi lập trình, nó là một chiếc chìa khóa vạn năng để mở những cánh cửa bị khóa.
* **Ret2Libc:** Khi bạn không thể đưa mã độc (Shellcode) vào, hãy tìm cách điều khiển những gì đã có sẵn.
----------------

Tóm tắt "vở kịch" trong CPU:
Màn 1 (main kết thúc): CPU gọi lệnh ret, thấy địa chỉ system ở Index 114ad (EIP). Nó nhảy đến đó.

Màn 2 (Vào system): system bắt đầu chạy. Nó nhìn xuống Stack.

Màn 3 (Tìm tham số): Nó thấy ô ngay dưới nó là exit (nó nghĩ: "À, xong việc mình sẽ về đây"). Nó nhìn xuống ô tiếp theo nữa và thấy "/bin/sh" (nó nghĩ: "Ok, mình sẽ chạy cái này").

Màn 4 (Khai hỏa): Shell /bin/sh được mở ra với quyền của level08.

Logic ở đây là: Chúng ta không phá hủy chương trình, chúng ta chỉ tái cấu trúc lại Stack để đánh lừa CPU rằng nó đang thực hiện một lệnh gọi hàm hoàn toàn hợp lệ!