# robbit

robbit is an easy-to-use, two-wheeled self-balancing robot that utilizes an FPGA.
It is developed using the **Cmod A7-35T** FPGA and an open-source development environment called **CFU-Proving-Ground**.

For more details on CFU-Proving-Ground, please see:
[archlab-science-tokyo/CFU-Proving-Ground](https://github.com/archlab-sciencetokyo/CFU-Proving-Ground)

The recommended OS is **Ubuntu Linux**.
This project works with **Vivado 2024.2**.

Please follow the development procedure below.

-----

## Chap. 1 Purchasing Parts

Table 1 shows the parts required to build robbit.

| Part | Name | Quantity |
| --- | ----- | --- |
| FPGA | Cmod A7-35T | 1 |
| Sensor | MPU-6050 | 1 |
| Motor | Mini Motor Standard Gearbox 70188 | 1 |
| Tires | Slim Tire Set (55mm Dia.) 70193| 1 |
| Motor Driver | TB6612FNG | 1 |
| Battery | EEMB Lithium-Ion Battery 653042 | 1 |
| Display | 240×240 Display with ST7789 IC | 1 |
| Plate | Universal Plate Set 70157 | 1 |

-----

## Chap. 2 Assembling the Robot

作成中

-----

## Chap. 3 Environment Setup

### Chap. 3.1 Setting up CFU-Proving-Ground

Please refer to [archlab-science-tokyo/CFU-Proving-Ground](https://github.com/archlab-sciencetokyo/CFU-Proving-Ground), clone the repository, and set it up for your environment.

The following instructions assume that **CFU-Proving-Ground is ready to use**.
This may take some time as it involves setting up the RISC-V compiler.

### Chap. 3.2 Integrating with the robbit Environment

Clone the robbit repository into the same directory as CFU-Proving-Ground using the following command:

```bash
git clone git@github.com:kumagai0212/robbit_archlab.git
```

Next, integrate the robbit repository with the CFU-Proving-Ground repository using the following commands:

```bash
cd robbit_archlab
make init
```

If you want to revert this repository to its pre-integration state, enter the following command

```bash
make reset 
```

-----

## Chap. 4 Simulation and Bitstream Generation

Compile the program with the following command:

```bash
make
```

robbit allows you to view real-time information, such as parameters, on its display. You can also check the display output in a simulation using the following command:

```bash
make drun
```

When you are ready to program the FPGA, you need to generate a bitstream. Generate it with the following command:

```bash
make bit
```

-----

## History