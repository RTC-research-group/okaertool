# Table of content
- [Table of content](#table-of-content)
- [Okaertool](#okaertool)
- [Repository folders](#repository-folders)
- [Compilation](#compilation)

# okaertool
This repository contains the source code for an AER (Address Event Representation) tool to monitor, log and play an stream of aer data. This controller has been implemented for hardware using verilog and VHDL rtl languaje.
ISE Version: Xilinx ISE 14.7
Architecture: Spartan-6
Target(s): XEM6310-LX150

# Repository folders
- src: API source code of the device.
  - cu: Control Unit. It will manage the USB messages sent and received and will send commands to other units.
  - ecu: Event Capture Unit. It will capture the received event and store both address and timestamp in a FIFO memory.
  - imu: Input Multiplexer Unit. It will select the preferred input from which the events will be received and connects it to the ECU.
  - osu: Output Sequencer Unit. It will either bypass the input received by the IMU to its output, or it will output the data received via USB.
  - test: It contains the testbench files for performance simultaion.
  - top: The top layer layout of this device. It contains the mapping of ports between units.
  - constraints: Device contraints.
  - XEM6310-LX150: It contains the specific .ngc files provided by okaertool for this device.
- python_lib: Contains a python program to test the performance of the device in real time.
- doc: Contains the layout of the desired final design.
- FrontPanel-Ubuntu18.04LTS-x64-5.2.3: Documentation.

  # Block Diagram
  <img align="right"  src="https://github.com/RTC-research-group/okaertool/blob/master/doc/okaertool.png"/>

