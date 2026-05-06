RELRO             STACK CANARY          NX              PIE             RPATH        RUNPATH         FILE
Partial RELRO 🟡   No canary found 🔴   NX enabled 🟢    No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level00/level00

--------

-------- Ghidra --------

bool main(void)

{
  int local_14 [4];
  
  puts("***********************************");
  puts("* \t     -Level00 -\t\t  *");
  puts("***********************************");
  printf("Password:");
  __isoc99_scanf(&DAT_08048636,local_14);
  if (local_14[0] != 0x149c) {
    puts("\nInvalid Password!");
  }
  else {
    puts("\nAuthenticated!");
    system("/bin/sh");
  }
  return local_14[0] != 0x149c;
}

---------- Translate 0x149c to decimal => 5276 !!!

Tại sao Ghidra hiển thị local_14[4] mà scanf lại dùng &DAT_08048636?
Nếu bạn click đúp vào DAT_08048636 trong Ghidra, bạn sẽ thấy nó là chuỗi định dạng "%d".

scanf("%d", local_14) nghĩa là nó đọc một số nguyên và lưu vào phần tử đầu tiên của mảng.

Lệnh if (local_14[0] != 0x149c) kiểm tra chính xác số nguyên đó.

Lưu ý nhỏ: Ở các level sau, khi No canary found đi kèm với một hàm gets() hoặc scanf("%s") (không giới hạn độ dài), đó mới là lúc bạn dùng đến kỹ thuật ghi đè địa chỉ trả về (EIP/RIP). Còn ở Level00, tác giả chỉ muốn bạn học cách đọc hiểu mã giả và chuyển đổi cơ số thôi!

---------- answer ----

level00@OverRide:~$ ./level00
***********************************
*            -Level00 -           *
***********************************
Password:5276

Authenticated!
$ whoami
level01
$ cat ../level01/.pass
uSq2ehEGT6c9S24zbshexZQBXUGrncxn5sD5QfGL
$ 