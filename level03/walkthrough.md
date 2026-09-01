RELRO               STACK CANARY       NX               PIE             RPATH        RUNPATH         FILE
Partial RELRO 🟡    Canary found 🟢     NX enabled 🟢    No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level03/level03
-----
---

# 📒 EXPLOITATION LOG: LEVEL 03 @ OVERRIDE

## 1. Static Analysis

Unlike the earlier levels, `level03` has a fairly complete set of protections
(**Canary found**, **NX enabled**), signalling that ordinary buffer-overflow
tricks won't work here.

### The vulnerability is in the logic:

Decompiling in Ghidra reveals this chain:

1. **`main`:** Reads a password from the user and calls `test(param_1, param_2)`.
2. **`test`:** Computes a difference: `ctx = param_2 - param_1`.
3. **`decrypt(ctx)`:** Uses `ctx` to decrypt a secret data array.

---

## 2. Reverse Engineering the Logic

Inside `decrypt`, the program **XOR**s a static hex array with `ctx` to produce a
check string.

### The secret XOR:

The program takes the array `local_21` (which starts with `0x51`) and XORs it
with `ctx`. If the result equals `"Congratulations!"`, you win.

* **Source byte:** `0x51` (the first byte of the secret array).
* **Target:** `'C'` (the first character of "Congratulations!").
* **Equation:** $0x51 \oplus \text{ctx} = \text{'C'}$

Using the XOR property: if $A \oplus B = C$ then $A \oplus C = B$.

* $0x51$ (decimal: $81$)
* $'C'$ (ASCII: $67$)
* $81 \oplus 67 = \mathbf{18}$ (this is the "magic" number we need).

---

## 3. Dynamic Analysis with GDB

Why doesn't entering `18` directly work? Because Ghidra didn't fully show how
`test` receives its arguments.

### The GDB turning point:

Running `x/2wd $ebp+8` in GDB reveals the real stack layout while `test` executes:

* **`param_1`:** The value you entered (e.g. `1234`).
* **`param_2`:** A fixed constant the program loads onto the stack: `322424845`.

### The final formula:

For `decrypt` to receive `18`, we must satisfy:

$$\text{param\_2} - \text{param\_1} = 18$$

$$\mathbf{322424845} - \text{password} = 18$$

$$\Rightarrow \text{password} = 322424845 - 18 = \mathbf{322424827}$$

---

## 4. Step-by-Step

1. **Compute the target value:** XOR the array's first byte with `'C'` to get `18`.
2. **Use GDB:** Set `break test`, run, and use `x/2wd $ebp+8` to find the secret
   constant sitting on the stack (`322424845`).
3. **Subtract:** Take the secret constant minus 18 to get the password to enter.
4. **Execute:** Enter the computed password to get a shell.

---

## 5. Takeaways

* **Don't fully trust the decompiler:** Ghidra is powerful but sometimes doesn't
  show arguments pushed onto the stack manually. GDB is always the ground truth.
* **XOR is reversible:** Knowing the desired result and the source data, you can
  always recover the key by XORing them together.
* **Stack "garbage" as hidden input:** Labs sometimes reuse leftover stack data as
  a hidden argument, forcing the player to use a debugger to see it.
