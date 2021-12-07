# AMAH-Flex
**A** **M**odular **a**nd **H**ighly **Flex**ible Tool for Generating Relocatable Systems on FPGAs

AMAH-Flex presents a solution to a common problem encountered when using FPGAs in dynamic, ever-changing environments. Even when using dynamic function exchange to accommodate changing workloads, partial bitstreams are typically not relocatable. So the runtime environment needs to store all reconfigurable partition/reconfigurable module combinations as separate bitstreams. A modular and highly flexible tool (AMAH-Flex) converts any static and reconfigurable system into a 2 dimensional dynamically relocatable system. It also features a fully automated floorplanning phase, closing the automation gap between synthesis and bitstream relocation. It integrates with the Xilinx Vivado toolchain and supports both FPGA architectures, the 7-Series and the UltraScale+. In addition, AMAH-Flex can be ported to any Xilinx FPGA family, starting with the 7-Series.

- A modular and very highly flexible tool that can be adapted, extended, and used separately for individual other purposes
- Automatically find, floorplanning, and place reconfigurable partitions
- Accepting different design sources, enabling Isolation Design Flow, and supporting all Xilinx 7-Series and UltraScale+ families
- Contains more than 60 functions
- Functions are TCL based

# Citations
If you use this work in your research, please cite the following paper:

N. Charaf, C. Tietz, M. Raitza, A. Kumar and D. Göhringer, "AMAH-Flex: A Modular and Highly Flexible Tool for Generating Relocatable Systems on FPGAs," 2021 International Conference on Field-Programmable Technology (ICFPT), 2021, pp. 1-6, doi: 10.1109/ICFPT52863.2021.9609948.

# Contact Info
Dipl.-Ing. Najdet Charaf, 
Technische Universität Dresden, 
najdet.charaf@tu-dresden.de,

Google Scholar: https://scholar.google.com/citations?hl=en&user=vCI9Bz0AAAAJ
