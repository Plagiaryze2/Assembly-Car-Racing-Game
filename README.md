<div align="center">

# 🏎️ 8086 Assembly Car Racing Game

### A Retro 16-bit DOS Game Written in 8086 assembly Language

![Language](https://img.shields.io/badge/Language-Assembly_8086-red?style=for-the-badge&logo=assembly)
![Assembler](https://img.shields.io/badge/Assembler-NASM-brightgreen?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-DOSBox-blue?style=for-the-badge)

*An Assembly Language course project built at FAST National University, Lahore — Fall 2024 BSE-3B*

---

</div>

## 📋 Table of Contents

- [Overview](#overview)
- [Gameplay & Features](#gameplay--features)
- [How It Works (Technical Architecture)](#how-it-works-technical-architecture)
- [Game Controls](#game-controls)
- [Prerequisites & Running the Game](#prerequisites--running-the-game)
- [Academic Credits](#academic-credits)
- [License](#license)

---

## 🔍 Overview

This is a classic **Car Racing Game** written entirely in **16-bit 8086 assembly language** for DOS. The game targets standard VGA text mode and interacts directly with the PC hardware, hook custom Interrupt Service Routines (ISRs) for responsive keyboard input and real-time screen updating, and utilizes direct memory writing to video segment `0xB800` for high performance rendering.

---

## 🎮 Gameplay & Features

- **Dynamic Start Menu** — Animated ASCII car scrolling horizontally across the title screen with project details.
- **Three-Lane Scrolling Road** — Real-time vertical scrolling simulation with animated dashed lanes and borders.
- **Random Obstacles** — Opponent cars spawn randomly on any of the three lanes.
- **Bonus Pickups** — Collect diamond items (`♦`) spawned on the road to gain extra bonus points (+10).
- **Responsive Gameplay** — Fast and smooth car movement.
- **Collision System** — Custom bounding-box collision detection triggers an instant `CRASH!` game-over overlay.
- **Dynamic Game Over Screen** — Animated "GAME OVER" letters printed character-by-character along with your final score.
- **ESC Confirmation Dialogue** — Pauses the action and prompts the user to safely exit or resume.

---

## 🛠️ How It Works (Technical Architecture)

The game bypasses standard high-level libraries and communicates directly with the processor and BIOS/hardware peripherals:

### 1. Direct Video Memory Access (`0xB800`)
Instead of using slow BIOS print interrupts during active gameplay, the game writes character codes and color attributes directly to the video memory buffer at segment `0xB800:0000`.

### 2. Custom Timer Interrupt (`ISR 08h`)
- The system timer tick is hooked to run `NEW_INTERRUPT_ISR` at standard rates.
- This manages the frame rate, obstacle movement, scrolling speed, and overall game ticks.

### 3. Custom Keyboard Interrupt (`ISR 09h`)
- The hardware keyboard controller is hooked via `NEW_KEYBOARD_ISR` to intercept raw scancodes from port `0x60`.
- Allows instantaneous response when pressing Left/Right arrows and ESC without blocking the game thread.

### 4. LCG Random Generator
- To spawn cars randomly, a **Linear Congruential Generator (LCG)** is implemented using the formula:
  $$\text{Seed} = (\text{Seed} \times 25173 + 13849) \pmod{65536}$$
- Initialized/seeded using the BIOS clock counter via `int 1Ah`.

### 5. Double Buffering & Custom Scrolling
- Relies on a memory buffer (`BUFFER` variables) to store the screen state.
- Scenery is shifted downwards vertically using hardware string instructions (`std` and `rep movsw` / `cld`) to simulate motion.

---

## 🕹️ Game Controls

| Key | Action |
|-----|--------|
| **`Left Arrow`** | Move Car Left |
| **`Right Arrow`** | Move Car Right |
| **`ESC`** | Prompt Quit Menu (`Y` to Exit, `N` to Resume) |
| **`Any Key`** | Skip Intro / Start Game |

---

## 🚀 Prerequisites & Running the Game

Since this is a real-mode DOS application, you must run it inside a DOS emulator like **DOSBox**.

### 1. Software Needed
- [DOSBox](https://www.dosbox.com/)
- **NASM Compiler** (`nasm.exe`)
- *Optional:* **AFD Debugger** (`afd.exe`) for assembly analysis

### 2. Assembly & Compilation
Compile the source code using NASM to generate a DOS `.COM` executable:
```bash
nasm cProj.asm -o cProj.com -l cProj.lst
```

### 3. Execution in DOSBox
1. Open DOSBox.
2. Mount your directory:
   ```dos
   mount c C:\Path\To\assembly-car-racing-game
   c:
   ```
3. Run the compiled executable:
   ```dos
   cProj.com
   ```

---

## 🎓 Academic Credits

This project was developed as part of the **Computer Organization & Assembly Language (COAL)** course:

- **University:** FAST National University of Computer and Emerging Sciences, Lahore Campus
- **Semester:** Fall 2024
- **Section:** BSE-3B
- **Developers:**
  - **Team Yeagerists++** 
  - **M. Anas** (Roll No: `24L-3004`)
  - **Abdul Ahad** (Roll No: `24L-3029`)

---

<div align="center">

**Built with 💻 and ⚙️ in 8086 Assembly**

</div>
