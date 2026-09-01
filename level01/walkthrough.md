
---

# 📒 EXPLOITATION LOG: LEVEL01 @ OVERRIDE

## 1. Reconnaissance
The first step is always to inspect the binary's protections with `checksec`.

*   **NX (No-Execute): Disabled 🔴** → This is the most important key. It lets us
    execute code (shellcode) directly on the stack or in a data section.
*   **PIE: Disabled 🔴** → Addresses inside the program are fixed and do not change
    between runs.
*   **Canary: No 🔴** → No "guard" watching the door, so we can freely overwrite
    the return address without being caught mid-way.

---

## 2. Reverse Engineering
Reading the logic in Ghidra reveals three key points:

### A. Logic flaw (the "fake" auth)
In `main`, whether the password is correct or not, the program always executes:
```c
if ((local_14 == 0) || (local_14 != 0)) {
    puts("nope, incorrect password...\n");
}
```
→ **Conclusion:** You can never authenticate the normal way. We must hijack the
CPU's control flow instead.

### B. Buffer overflow (the vulnerability)
In `main`, the password buffer `local_54` is declared as:
*   `char local_54[64];` (64 bytes capacity).
*   But `fgets(local_54, 100, stdin);` reads up to **100 bytes**.
→ **Conclusion:** We have $100 - 64 = 36$ extra bytes to overwrite the sensitive
memory that sits behind this array on the stack (including EBP and, most
importantly, EIP).

### C. Where to plant the "bomb" (shellcode placement)
`verify_user_name` takes the username and stores it into the global variable
`a_user_name`.
*   Because this variable lives in the `.bss` segment (fixed address) and **NX is
    disabled**, we can turn the username into a "warehouse" holding our shellcode.

---

## 3. Exploit Construction

Our goal: **when `main` returns (the `ret` instruction), the CPU jumps to our
shellcode instead of returning to the OS.**

### Step 1: Prepare the shellcode
We use a piece of assembly that calls `execve("/bin/sh")`.
*   Username input: `"dat_wil" + <shellcode>`
*   Why `"dat_wil"`? The program checks the first 7 characters; if they don't
    match it exits immediately.

### Step 2: Find the jump target (target address)
Find the address of `a_user_name` with `nm`.
*   Suppose the address is `0x0804a040`.
*   Since the first 7 bytes are `"dat_wil"`, we must jump to
    `0x0804a040 + 7 = 0x0804a047`.

### Step 3: Compute the offset
`local_54` is 64 bytes wide, followed by other variables and the saved EBP.
*   By experiment (or with GDB), we find we need about **80 bytes** of junk (`A`)
    to fill from the start of `local_54` up to the return address (EIP).

---

## 4. Execution
The final command ties everything together:
```bash
(python -c 'print "dat_wil" + "SHELLCODE_HERE"'; python -c 'print "A"*80 + "\x47\xa0\x04\x08"'; cat) | ./level01
```

1.  **Part 1 (username):** Delivers the "bomb" (shellcode) into memory.
2.  **Part 2 (password):** Sends 80 `A`s to overflow the buffer, then overwrites
    EIP with `0x0804a047`.
3.  **`cat`:** Keeps stdin open. When the CPU jumps into the shellcode and runs
    `/bin/sh`, `cat` lets us type commands like `whoami`, `ls` into the new shell.

---

## 5. Takeaways
*   **Always check bounds:** The bug comes from `fgets` reading more than the
    array can hold.
*   **NX & PIE:** If both were enabled, this approach would fail. We'd then need
    more advanced techniques such as **ROP (Return Oriented Programming)** or an
    **information leak**.
*   **Little Endian:** When writing an address into the payload, write it in
    reverse byte order (e.g. `08 04 a0 47` becomes `\x47\xa0\x04\x08`).
