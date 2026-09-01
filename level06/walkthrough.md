RELRO                STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
Partial RELRO 🟡     Canary found 🟢        NX enabled 🟢      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level06/level06

--------------

# 📒 EXPLOITATION LOG: LEVEL 06 @ OVERRIDE

## 1. Signature & Barriers

* **Goal:** Pass the `auth()` function to trigger `system("/bin/sh")`.
* **Security:**
* `Canary found`: Blocks buffer-overflow EIP overwrites.
* `NX enabled`: Blocks shellcode execution on the stack.
* `ptrace(PTRACE_TRACEME)`: An anti-debugging mechanism. If it detects GDB
  watching, the program aborts.

---

## 2. Dissecting the `auth()` algorithm

Instead of hunting a memory bug, we **reverse engineer** the rule that generates
the Serial from the Login. This is a predictable hash function.

### Step 1: Seed initialisation

The program takes the 4th character (`index 3`) of the Login as the foundation.

$$local\_14 = (Login[3] \oplus 0x1337) + 0x5eeded$$

### Step 2: The hashing loop

The program walks each character of the Login (start to end). For each character
it updates the Serial with:

$$Serial_{new} = Serial_{old} + (char[i] \oplus Serial_{old}) \bmod 1337$$

> **Note:** `0x539` in the machine code is `1337` in decimal.

---

## 3. Exploitation (the keygen strategy)

Because of the anti-GDB mechanism, reading registers directly is painful. The
best approach is to write a **keygen** script that computes the Serial itself.

### The "unbeatable" Python one-liner

To avoid indentation errors when copy-pasting, use this one-liner. Just replace
`viiiit` with the Login you want:

```bash
python -c 'l="viiiit"; s=(ord(l[3])^0x1337)+0x5eeded; [exec("v=(ord(c)^s)%1337\ns+=v") for c in l]; print(f"Login: {l}\nSerial: {s}")'

```

---

## 4. Result reference table (examples)

| Login (username) | Seed character | Seed value | Final Serial |
| --- | --- | --- | --- |
| `gemini` | `i` | `6226121` | `6232354` |
| `viiiit` | `i` | `6226121` | `6232354` |
| `admin1` | `i` | `6226121` | `6232408` |

*(Note: "gemini" and "viiiit" share the same 4th character 'i' and the same
length, so their Serials can match.)*

---

## 5. Steps to success

1. **Choose a Login:** Any string longer than 6 characters (e.g. `gemini`).
2. **Compute the Serial:** Run the Python script to get the matching number.
3. **Pass the gate:** Run `./level06`, enter the chosen Login and paste the Serial.
4. **Take control:** After `Authenticated!`, run `whoami` to confirm and grab the
   flag at `/home/users/level07/.pass`.

---

## 6. Takeaways

* **Logic flaw:** When a license-check algorithm runs entirely client-side
  (locally), an attacker can reverse it and forge the key.
* **Anti-debug bypass:** `ptrace` protects the program from GDB, but not from
  having its source read and its algorithm re-implemented in another language
  (Python).
* **Indentation matters:** In Python, whitespace is structure, not decoration. In
  an interactive shell, prefer a one-liner for stability.
