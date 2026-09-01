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

---------- Convert 0x149c to decimal => 5276 !!!

Why does Ghidra show local_14[4] while scanf uses &DAT_08048636?
If you double-click DAT_08048636 in Ghidra, you'll see it is the format string "%d".

scanf("%d", local_14) reads a single integer and stores it into the first
element of the array.

The check `if (local_14[0] != 0x149c)` compares exactly that integer.

Note for later levels: when "No canary found" is paired with an unbounded input
function such as gets() or scanf("%s"), that's when you reach for return-address
overwrite techniques (EIP/RIP). In Level00 the author only wants you to practice
reading decompiled code and converting number bases!

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
