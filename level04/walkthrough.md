RELRO                STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
Partial RELRO 🟡     No canary found 🔴   NX disabled 🔴      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level04/level04
-----
---

# 📒 EXPLOITATION LOG: LEVEL 04 @ OVERRIDE

## 1. Analysing the "armor" (security protections)

* **NX disabled 🔴**: In theory we could run shellcode directly on the stack.
* **No Canary 🔴**: We can overwrite the return address (EIP) easily.
* **ASLR**: May be enabled on the host, but in this lab environment the `libc`
  addresses are usually fixed.

---

## 2. Code logic: the "strict father" (the sandbox)

This program is interesting because it uses `fork()` to run two processes in
parallel:

### A. Child process
* Handles communication with the user.
* Uses **`gets(local_a0)`**: the fatal vulnerability. `local_a0` is only 128
  bytes wide but `gets` reads unbounded input → **stack-based buffer overflow**.
* It invites you: *"Give me some shellcode, k"*. This is actually a trap.

### B. Parent process
* Acts as a **monitor** using `ptrace`.
* It inspects the child's `ORIG_EAX` register (at offset `0x2c`) whenever the
  child tries to do anything.
* **The rule:** If the child calls **syscall 11 (0xb)** — i.e. `execve` — the
  parent immediately `kill`s the child and prints `"no exec() for you"`.

> **Problem:** 99% of traditional shellcode ends with `execve("/bin/sh")`. So a
> normal shellcode is guaranteed to fail here.

---

## 3. Strategy: `ret2libc` (Return-to-libc)

To beat the "father" we don't use custom shellcode. Instead we force the "child"
to jump into a function that already exists in the system: **`system()`**.

### Why does `system()` succeed?

When `system("/bin/sh")` runs, it spawns a "grandchild" process. That grandchild
is what performs the `execve`. Since the "father" only monitors the "child," the
"grandchild" is completely off its radar and can open a shell freely.

---

## 4. The anatomy of the payload

We arrange the child's stack so that when it returns, it thinks it is performing
a legitimate function call.

### Faked stack frame layout:

| Component | Value | Meaning |
| --- | --- | --- |
| **Padding** | `A` * 156 | Fill from `local_a0` up to EIP. |
| **EIP (target)** | `0xf7e6aed0` | Address of `system()`. |
| **Return address** | `JUNK` (4 bytes) | Where `system` returns afterwards (we don't care). |
| **Argument 1** | `0xf7f897ec` | Address of the `"/bin/sh"` string (argument to `system`). |

---

## 5. Finding the ingredients (GDB)

1. **Find `system()`:** `print system` in GDB.
2. **Find `"/bin/sh"`:** `find &system, +9999999, "/bin/sh"`. This string always
   lives in Linux's `libc`.
3. **Determine the offset (156):** 128 bytes of the array + surrounding locals
   (`local_20`, `local_1c`...) + the saved EBP. In total 156 bytes to reach EIP.

---

## 6. Final command

```bash
(python -c 'print "A" * 156 + "\xd0\xae\xe6\xf7" + "JUNK" + "\xec\x97\xf8\xf7"'; cat) | ./level04

```

* **`"A" * 156`**: Destroys the old stack structure.
* **`\xd0\xae\xe6\xf7`**: Redirects the CPU into `system`.
* **`\xec\x97\xf8\xf7`**: Feeds `"/bin/sh"` as the argument to `system`.
* **`cat`**: Keeps the pipe open so we can type commands into the shell once we
  win it.

---

## 7. Takeaways

* **Introspection:** `ptrace` is a powerful protection, but if it only monitors
  the surface (and not recursively), it can still be bypassed.
* **The power of the library:** `ret2libc` shows that sometimes the best "weapon"
  to attack a system is a tool already present inside that system.
* **Logic bug:** Understanding the parent-child-grandchild relationship in Linux
  is the key to finding the flaw in the author's protection scheme.


------ why +9999999 -------

`+9999999` is used as a hacky shortcut because:

1. **Size of `libc`:** The `libc` library is typically 1.5MB–2MB in memory.
2. **Full coverage:** Starting from `&system` (a point in the middle of `libc`)
   and scanning ~10MB forward guarantees 100% coverage of the rest of `libc`.
3. **Safe auto-stop:** GDB is smart. When it scans past the valid mapped region
   of `libc` and hits unmapped memory, it stops and prints a mild warning:
   `warning: Unable to access target memory at 0xf7fd3b74, halting search.`
   Even though it warns, it has **already found** the `"/bin/sh"` string that sits
   before that boundary.

---

### In short:

Instead of looking up exactly how big `libc` is to write the precise number,
attackers use a very large number (`+9999999` or `+100000000`) to make GDB "scan
as far as it can until it hits a wall."
