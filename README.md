# 42_override

A walkthrough collection for the **OverRide** project (42 School) — a binary
exploitation / reverse engineering wargame with 10 levels (`level00` → `level09`).
Each `levelXX/` directory contains the target `source`, the captured `flag`
(the `.pass` of the next user), and a `walkthrough.md` explaining the exploit.

## Running the VM

`script.sh` boots the OverRide ISO in QEMU:

```bash
./script.sh
```

It expects the ISO at `~/Downloads/OverRide.iso`. Once booted, connect over SSH:

```bash
ssh level00@localhost -p 4242
```

Each level's password is the flag recovered in the previous level.

---

## `checksec` glossary

`checksec` reports the exploit-mitigation "armor" of a binary. Knowing which
protections are on or off tells you which attack is viable. This is the single
most important table to internalize for the defense.

### 1. STACK CANARY

* **What it is:** A random value placed on the stack **just before** the saved
  return address.
* **Mechanism:** Before a function returns, it checks that this value is still
  intact.
* **Purpose:** Defeats **stack buffer overflows**. If an attacker overwrites the
  stack to hijack control flow, the canary is clobbered. The program detects the
  mismatch and aborts immediately (`SIGABRT`) instead of executing attacker code.

### 2. NX (No-Execute)

* **What it is:** Marks memory regions (stack, heap) as **non-executable**.
* **Purpose:** Defeats **shellcode injection**. Historically an attacker would
  place machine code on the stack and jump into it. With NX, even if the code is
  written into memory, the CPU refuses to execute it there.
* **Also known as:** **DEP** (Data Execution Prevention) on Windows.

### 3. PIE (Position Independent Executable)

* **What it is:** Makes the whole executable loadable at any base address in
  memory.
* **Purpose:** Works together with **ASLR** (Address Space Layout Randomization)
  to randomize memory addresses on every run.
* **Effect:** The attacker no longer knows the fixed address of `system` or of
  any variable, so they can't just "aim and fire." Exploiting a PIE binary
  usually requires an **information leak** first.

### 4. RELRO (Relocation Read-Only)

* **What it is:** Protects the **GOT** (Global Offset Table), which stores the
  resolved addresses of library functions such as `printf` and `system`.
* **Variants:**
  * **Partial RELRO:** Part of the GOT remains writable.
  * **Full RELRO:** The entire GOT is made **read-only** after the loader
    finishes resolving symbols.
* **Purpose:** Prevents **GOT hijacking** (e.g. rewriting the `printf` entry to
  point at `system`).

### 5. RPATH and RUNPATH

Both control where the program searches for its dynamically linked libraries
(`.so`) at launch.

* **RPATH (Run Path):** A hard-coded search path embedded in the executable. The
  system searches here **before** the `LD_LIBRARY_PATH` environment variable.
* **RUNPATH:** Same idea, but lower priority — `LD_LIBRARY_PATH` is consulted
  first, and RUNPATH only afterwards.
* **Security risk:** If RPATH/RUNPATH points at a directory the attacker can
  write to (such as `/tmp`), the attacker can drop a malicious library there and
  make the program load it (**library preloading attack**).

---

### One-line mental model

| Term | Analogy |
| :--- | :--- |
| **Stack Canary** | A trip-wire bell at the door: cross it unknowingly and the bell rings. |
| **NX** | A "no code execution here" sign in the storage area — data may be stored, not run. |
| **PIE / ASLR** | A mobile house that sits at different map coordinates every day. |
| **RELRO** | Locking the important filing cabinet (GOT) so no one can alter the addresses inside. |
| **RPATH / RUNPATH** | A note that says "buy your supplies at this specific shop." |
