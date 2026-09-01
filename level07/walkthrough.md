RELRO                STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
Partial RELRO 🟡     Canary found 🟢     NX disabled 🔴      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level07/level07

------------------ 
---

# 📒 EXPLOITATION LOG: LEVEL 07 @ OVERRIDE

## 1. Signature and Vulnerability

The program offers a simple number-storage service. Reverse engineering it
reveals an **Out-of-Bounds (OOB) Write** in `store_number`.

* **Logic bug:** The program takes an `Index` from the user but never checks the
  upper bound. It trusts your number completely to compute the write address:
  `*(uint *)(uVar2 * 4 + param_1) = uVar1;`
* **The sandbox:** The author planted two guards:
1. `index % 3 == 0`: Writes to indices divisible by 3 are rejected.
2. `number >> 24 == 0xb7`: Numbers whose top byte is `0xb7` are rejected (to
   block `libc` addresses on some systems).

---

## 2. Stack Forensics

To steer the program we need `main`'s **saved EIP** (the return address). That is
the CPU's "steering wheel."

From live GDB data:

* **Saved EIP address:** `0xffffd30c`
* **Array start address (index 1):** `0xffffd148` → **index 0** is at `0xffffd144`.

**Locating the target:**

$$Distance = EIP\_addr - Array\_start = 0xffffd30c - 0xffffd144 = 0x1c8$$

$$0x1c8 \text{ (hex)} = 456 \text{ bytes}$$

$$\text{Target Index} = \frac{456}{4} = \mathbf{114}$$

---

## 3. Bypassing the guard with Integer Overflow

We want to write to **index 114**, but $114 \bmod 3 = 0$ so it's blocked.

**The trick:** exploit unsigned 32-bit integer arithmetic. When a value exceeds
$2^{32}$, it "wraps around" back to 0.

To find a new index that points at the same memory but is not divisible by 3:

$$\text{New Index} = 114 + \frac{2^{32}}{4} = 114 + 1{,}073{,}741{,}824 = \mathbf{1{,}073{,}741{,}938}$$

Verify:

* $1{,}073{,}741{,}938 \bmod 3 = 1$ → **passes the filter!**
* Multiplied by 4 (`int` size): $1{,}073{,}741{,}938 \times 4 = 4{,}294{,}967{,}752$.
* In 32-bit memory: $4{,}294{,}967{,}752 \equiv 456 \pmod{2^{32}}$.
* Result: it points exactly at offset 456 bytes (index 114), which is what we
  need.

---

## 4. Attack: Ret2Libc

Because the stack has been wiped of environment variables, we use **Ret2Libc** to
borrow functions from the standard C library.

We set up a "fake call chain" on the stack starting at EIP (index 114):

1. **Index 114 (EIP):** Address of `system()`. When `main` returns, the CPU jumps
   here instead of exiting.
2. **Index 115 (return address):** Address of `exit()`. After `system` finishes it
   returns here to exit cleanly without crashing.
3. **Index 116 (argument 1):** Address of the `"/bin/sh"` string — the argument
   `system()` receives.

---

## 5. Final execution

Enter the "golden" sequence:

1. `store` → `4159090384` → `1073741938` (put `system` into EIP).
2. `store` → `4159040368` → `115` (put `exit` after EIP).
3. `store` → `4160264172` → `116` (put `"/bin/sh"` into the argument slot).
4. `quit` → detonate the chain.

**Result:** The program runs `system("/bin/sh")` and hands you a shell as the
higher-privileged user.

---

### Takeaways:

* **Don't trust static code:** Ghidra reported `0x1bc`, but the real value on the
  machine was `0x1c8`. Always trust **live debugging** data from GDB.
* **Math is a weapon:** Integer overflow isn't just a bug — it's a master key for
  opening locked doors.
* **Ret2Libc:** When you can't inject shellcode, control what's already there.
----------------

Summary of the "play" happening in the CPU:

Act 1 (`main` returns): The CPU runs `ret`, sees the `system` address at index 114
(EIP). It jumps there.

Act 2 (enter `system`): `system` starts running and looks down the stack.

Act 3 (find arguments): It sees the slot right below it is `exit` (it thinks: "Ah,
when I'm done I'll return here"). It looks one more slot down and sees `"/bin/sh"`
(it thinks: "Ok, I'll run this").

Act 4 (fire): `/bin/sh` opens with `level08`'s privileges.

The logic: we don't destroy the program — we just restructure the stack to fool
the CPU into thinking it's performing a perfectly legitimate function call!
