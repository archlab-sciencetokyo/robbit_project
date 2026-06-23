# robbit_project (Two-Wheeled Self-Balancing Robot Project)

[日本語版はこちら / Read this document in Japanese](./README_ja.md)

**robbit_project** is a project for building an accessible two-wheeled
self-balancing robot (TW-SBR) using either a microcontroller or an FPGA.
A TW-SBR balances itself by controlling its two wheels and tilting its body.
The FPGA-based TW-SBR is called **robbit**, while the microcontroller-based
TW-SBR is called **robbit-esp**.

## 1. robbit

**robbit** is an accessible FPGA-based two-wheeled self-balancing robot
(TW-SBR). It aims to promote FPGA-based robotics and contribute to FPGA
education and research. Hardware costs are reduced by using inexpensive,
off-the-shelf components, while an FPGA development framework makes the
system easier to develop.

### 1.1. robbit Architecture

The photos below show **robbit**. The upper part of the chassis contains the
FPGA board, sensors, display, motor driver, and other components. The lower
part contains the battery, geared motors, wheels, and other components that
provide propulsion.

<table>
    <tr>
        <td><img src="./robbit/setting/image/bcar-structure-front.JPG" alt="Front view of robbit" width="200"></td>
        <td><img src="./robbit/setting/image/bcar-structure-side.JPG" alt="Side view of robbit" width="200"></td>
    </tr>
</table>

All modules implemented on the FPGA are written in Verilog HDL. **robbit**
uses PID control for motion control, which is implemented in software running
on a RISC-V processor. By developing **robbit**, developers can learn both
hardware development through robot assembly and RTL design, and software
development through improving motion with PID control.

### 1.2. Features

**robbit** is designed for ease of development by using the open-source
[CFU Proving Ground](https://github.com/archlab-sciencetokyo/CFU-Proving-Ground)
framework. It costs slightly less than JPY 20,000 to assemble, making it more
affordable than existing FPGA-based self-balancing robot development kits.
The FPGA board is also removable, so teams can further reduce costs by sharing
one FPGA board among multiple developers.

### 1.3. Ways to Use robbit

Changes to the PID software or hardware can significantly affect how
**robbit** moves. When developing in a group, you could hold a contest to see
whose robot can remain balanced the longest. Adding wind or using a slippery
floor can make the challenge even more interesting.

### 1.4. robbit Project Structure

To develop **robbit**, see the [robbit directory](./robbit/). The directory
also contains a [development manual](./robbit/setting/manual/robbit_manual_en.pdf)
and a [system manual](./robbit/setting/manual/robbit_system_manual_en.pdf).
Refer to these documents as you work. For further details, see the README in
the `robbit` directory.

    .
    └── robbit_project/
        └── robbit/   <----------------- Reference directory
            ├── CFU-Proving-Ground/
            └── setting/
                ├── image/
                ├── manual/
                └── merge_file/

## 2. robbit-esp

In addition to **robbit**, you can build **robbit-esp**, a robot controlled by
an ESP32-C3. The photos below show the completed **robbit-esp**. Its
configuration is kept as similar to **robbit** as possible. Because
**robbit-esp** supports real-time parameter communication over BLE, it does
not have a display. Developing **robbit-esp** lets you learn microcontroller
development and compare its behavior with **robbit**.

<table>
    <tr>
        <td><img src="./robbit-esp/image/esp32c3_front.jpg" alt="Front view of robbit-esp" width="200"></td>
        <td><img src="./robbit-esp/image/esp32c3-structure-side.jpg" alt="Side view of robbit-esp" width="200"></td>
    </tr>
</table>

### 2.1. robbit-esp Project Structure

To develop **robbit-esp**, see the
[robbit-esp directory](./robbit-esp/). It contains a
[development manual](./robbit-esp/manual/robbit-esp_manual_en.pdf) and a
[system manual](./robbit-esp/manual/robbit-esp_system_manual_en.pdf).
Refer to these documents as you work. For further details, see the README in
the `robbit-esp` directory.

    .
    └── robbit_project/
        └── robbit-esp/  <----------------- Reference directory
            ├── image/
            └── manual/

## Libraries Requiring License Compliance

- MadgwickAHRS library
  - Provider: Arduino LLC
  - Source: <https://github.com/arduino-libraries/MadgwickAHRS>
  - Redistributed files:
    - `robbit/setting/merge_file/MadgwickAHRS.c`
    - `robbit/setting/merge_file/MadgwickAHRS.h`
  - Usage:
    - The library is statically linked when compiling the source code for
      both robbit and robbit-esp.
    - Its header file is included by
      `robbit/setting/merge_file/main.cpp` and `robbit-esp/robbit-esp.ino`,
      and the library is statically linked at build time.
  - License: GNU Lesser General Public License v2.1 or later
  - The full license text is included in this repository:
    [COPYING.LESSER](./robbit/setting/new_files/Madgwick/COPYING.LESSER).
  - When reusing or redistributing code that uses this library, ensure that
    you comply with the LGPL terms.

## Changelog

### October 31, 2025

- Released version 1.0 of robbit_project (Two-Wheeled Self-Balancing Robot
  Project).
