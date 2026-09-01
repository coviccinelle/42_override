
RELRO             STACK CANARY        NX                   PIE             RPATH        RUNPATH         FILE
Full RELRO 🟢     Canary found 🟢     NX disabled 🔴      No PIE 🔴       No RPATH 🟢   No RUNPATH 🟢   /home/users/level08/level08
--------------

**CWD (Current Working Directory) Manipulation** combined with **Directory Mirroring**.

---

# 📒 EXPLOITATION LOG: LEVEL 08 @ OVERRIDE

## 1. Target & Privileges

* **Binary:** `/home/users/level08/level08`
* **Privilege:** It carries the **SUID bit of `level09`**. This means the binary
  holds a "royal sword" — it can read any file `level09` can access, including the
  password file `/home/users/level09/.pass`.
* **Feature:** The program is a backup tool. It reads the file you request and
  writes a copy to `./backups/[your_filename]`.

---

## 2. Vulnerability: Relative Path

The binary uses the relative path `./backups/` instead of an absolute path (like
`/var/log/backups/`).

* **Exploit logic:** The binary looks for the `backups` directory wherever you
  currently stand (`.` = current working directory).
* **Problem in the home directory:** At `/home/users/level08`, the `backups`
  directory is owned by `level09` and you can't create subdirectories in it. This
  prevents the copy if the input file has a deep path (like `/home/users/...`).

---

## 3. Strategy: Directory Mirroring

Because the program isn't smart enough to create parent directories (it only calls
`open()` with `O_CREAT` for the final file), we "build the bridge before we cross
it."

### Step 1: Change the execution environment

Move to `/tmp`. This is the "free land" where a normal user has `rwx` (read,
write, execute) permission to create anything.

### Step 2: Build the "mirror" structure

When you feed in `/home/users/level09/.pass`, the binary tries to write to:
`./backups/` + `home/users/level09/.pass`

Manually create that whole structure inside `/tmp`:

1. `mkdir backups`
2. `mkdir backups/home`
3. `mkdir backups/home/users`
4. `mkdir backups/home/users/level09`

### Step 3: Trigger the "proxy"

Run the binary: `/home/users/level08/level08 /home/users/level09/.pass`

1. The binary uses its SUID privilege to read the real password file.
2. It finds the directory `./backups/home/users/level09/` already exists in `/tmp`.
3. It creates `.pass` inside it and copies the password content in.

---

## 4. Result & Takeaways

* **Flag found:** `fjAwpJNs2vvkFLRebEvAQ2hFZ4uQBWfHRsP62d8S`
* **Why it worked:** You controlled the program's **execution context**. By
  changing the working directory, you redirected a privileged action (file write)
  to a location you fully control.

> **Security note:** This is why safe SUID programs must always use **absolute
> paths** and minimize trust in the user-controlled environment (such as the
> current directory or environment variables).

---
