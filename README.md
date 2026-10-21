# Table of content
- [Table of content](#table-of-content)
- [Okaertool](#okaertool)
- [Repository folders](#repository-folders)
- [Block Diagram](#block-diagram)
- [Status LEDs](#status-leds)
- [Compilation](#compilation)
- [Python package installation](#python-package-installation)
- [Example of usage](#example-of-usage)

# okaertool
This repository contains the source code for an AER (Address Event Representation) tool to monitor, log and play an stream of aer data. This controller has been implemented for hardware using verilog and VHDL rtl languaje. The hardware is based on a FPGA (Field Programmable Gate Array) from Opal Kelly, model XEM6310-LX150 or XEM7310-A200 (but not limited to these models). The device has been designed to be used in neuromorphic applications, where the data is represented as a stream of events (spikes). The device can be used to monitor and log the events received from neuromorphic sensors, such as DVS (Dynamic Vision Sensor) or NAS (Neuromorphic Auditory Sensor), and can also play back the events to other neuromorphic devices.

# Repository folders
- src: API source code of the device.
  - cu: Control Unit. It will manage the USB messages sent and received and will send commands to other units.
  - ecu: Event Capture Unit. It will capture the received event and store both address and timestamp in a FIFO memory.
  - imu: Input Multiplexer Unit. It will select the preferred input from which the events will be received and connects it to the ECU.
  - osu: Output Sequencer Unit. It will either bypass the input received by the IMU to its output, or it will output the data received via USB.
  - test: It contains the testbench files for performance simultaion.
  - top: The top layer layout of this device. It contains the mapping of ports between units.
  - constraints: Device contraints.
  - XEM6310-LX150: It contains the specific .ngc files provided by okaertool for this device. Also it contains the .ucf file for pin mapping.
  - XEM7310-A200: It contains the specific .ngc files provided by okaertool for this device. Also it contains the .xdc file for pin mapping.
- python_package: Python package to control the device via USB using the Opal Kelly FrontPanel API.
  - test: Contains example scripts to use the python package.
- doc: Contains the layout of the desired final design.

# Block Diagram
<img align="right"  src="https://github.com/RTC-research-group/okaertool/blob/master/doc/okaertool.png"/>

# Status LEDs
The XEM6310 and XEM7310 boards have 8 user LEDs (`LED0`..`LED7`). They show the same information on both platforms, even though their electrical behavior differs (XEM6310: on = `0`, off = `1`; XEM7310: on = `0`, off = high impedance `Z`). The firmware takes care of this difference, so no user action is needed.

```
  LED7   LED6   LED5   LED4   LED3   LED2   LED1   LED0
  [USB]   --     --     --     --    [RDY]  [EMP]  [FUL]
```

| LED | Name | When it is ON | What it tells you |
|:---:|:-----|:--------------|:------------------|
| `LED7` | **USB activity** | While events are being read from the device (monitoring) or written to it (sequencing) through USB | Blinks while data is transferred; off when USB is idle or the device is in reset |
| `LED6` - `LED3` | Not used | Never | Always off |
| `LED2` | **USB ready** | The capture FIFO holds enough events to start a USB transfer | The host can read a block of events |
| `LED1` | **FIFO empty** | The capture FIFO holds no events | No events are waiting to be read |
| `LED0` | **FIFO full** | The capture FIFO is full | New events may be lost: read the data faster or reduce the event rate |

Typical states:

| Situation | `LED7` | `LED2` | `LED1` | `LED0` |
|:----------|:------:|:------:|:------:|:------:|
| Idle, no events captured | off | off | on | off |
| Capturing events, FIFO filling | off | on | off | off |
| Events being downloaded via USB | on | on | off | off |
| FIFO overflow risk | off | on | off | on |

# Compilation
The device can be synthesized using the Xilinx Vivado and ISE tools. Using the Xilinx synthesis tool, you can create a project for the specific FPGA platform you are using (XEM6310-LX150 or XEM7310-A200). You will need to add the source files from the src folder to the project, as well as the constraints file for the specific device. You will also need to add the .ngc files provided by okaertool for the specific device. Once you have added all the files, you can synthesize the design and generate the bitstream file.

# Python package installation
To install the python package, you will need to have Python 3.6 or higher installed on your system. You will also need to have the Opal Kelly FrontPanel drivers installed. You can download the drivers from the Opal Kelly website (https://pins.opalkelly.com/downloads). For windows, download the version 5.3.6. Once you have the drivers installed, you can install the python package using pip. You can run the following command in your terminal:

```
pip install pyokaertool
```

The package is supported on Windows, Linux and MacOS.

# Example of usage
To use the python package, you will need to import the pyokaertool module in your python script. You can then create an instance of the OkaerTool class and use its methods to interact with the device. In the test folder of the python_package, you can find some example scripts (python notebook) that demonstrate how to use the package.

