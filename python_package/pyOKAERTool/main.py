#################################################################################
##                                                                             ##
##    Copyright C 2021  Antonio Rios-Navarro                                   ##
##                                                                             ##
##    This file is part of okaertool.                                          ##
##                                                                             ##
##    okaertool is free software: you can redistribute it and/or modify        ##
##    it under the terms of the GNU General Public License as published by     ##
##    the Free Software Foundation, either version 3 of the License, or        ##
##    (at your option) any later version.                                      ##
##                                                                             ##
##    okaertool is distributed in the hope that it will be useful,             ##
##    but WITHOUT ANY WARRANTY; without even the implied warranty of           ##
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the              ##
##    GNU General Public License for more details.                             ##
##                                                                             ##
##    You should have received a copy of the GNU General Public License        ##
##    along with okaertool.  If not, see <http://www.gnu.org/licenses/>.       ##
##                                                                             ##
#################################################################################
"""Python driver for the OKAERTool AER monitor/sequencer built on an Opal Kelly USB 3.0 board."""
import logging
import threading
import time
from queue import Empty, Full, Queue

import numpy as np

# Prefer the installed FrontPanel package (pip install ok); fall back to the bundled bindings
try:
    import ok
except ImportError:
    from . import ok as ok

# FrontPanel >= 6.0 renamed the error code enum and the error string getter
OK_NO_ERROR = ok.ErrorCode.NoError if hasattr(ok, 'ErrorCode') else ok.okCFrontPanel.NoError


def ok_error_string(error_code):
    if hasattr(ok.okCFrontPanel, 'GetErrorMessage'):
        return ok.okCFrontPanel.GetErrorMessage(error_code)
    return ok.okCFrontPanel.GetErrorString(error_code)


class Spikes:
    """
    Addresses and timestamps of the spikes captured on one input.

    Attributes:
        addresses (int[]): Address of each spike.
        timestamps (int[]): Timestamp of each spike.
    Note:
        Both lists are matched: timestamps[i] is the timestamp of the spike with address addresses[i].
    """

    def __init__(self, addresses=None, timestamps=None):
        self.addresses = addresses if addresses is not None else []
        self.timestamps = timestamps if timestamps is not None else []

    def __str__(self):
        return f"Addresses: {self.addresses}\nTimestamps: {self.timestamps}"

    def get_num_spikes(self):
        """
        Get the number of spikes in the struct.
        :return: Number of spikes.
        """
        return len(self.addresses)


class Okaertool:
    """
    Manages the Opal Kelly USB 3.0 board running the okaertool FPGA design. It sends commands to the tool and
    receives the captured AER events (timestamp + address pairs) through a USB block pipe.

    Attributes:
        bit_file (string): Path to the FPGA .bit programming file
    """
    # Opal Kelly endpoints. They must match the addresses used in src/cu/okt_cu.vhd
    OUTPIPE_ENDPOINT = 0xA0
    INPIPE_ENDPOINT = 0x80
    INWIRE_COMMAND_ENDPOINT = 0x00
    INWIRE_SELINPUT_ENDPOINT = 0x01
    INWIRE_RESET_ENDPOINT = 0x02
    INWIRE_CONFIG_ENDPOINT = 0x03

    NUM_INPUTS = 3
    LOG_LEVEL = logging.INFO
    LOG_FILE = "okaertool.log"

    # Event format: two 32-bit words (timestamp, address)
    SPIKE_SIZE_BYTES = 8
    TIMESTAMP_BITS_WIDTH = 32  # Must match TIMESTAMP_BITS_WIDTH in okt_global_pkg.vhd
    TIMESTAMP_WRAP_VALUE = 1 << TIMESTAMP_BITS_WIDTH  # Added to global_timestamp on each overflow marker
    TIMESTAMP_OVERFLOW_MARKER = (1 << TIMESTAMP_BITS_WIDTH) - 1  # 0xFFFFFFFF in both the timestamp and address words

    # USB parameters
    USB_BLOCK_SIZE = 16 * 1024  # Updated in init() according to the USB speed
    USB_TRANSFER_LENGTH = 1 * 1024 * 1024  # Must be a multiple of USB_BLOCK_SIZE
    MAX_NUM_USB_BUFFERS = 16  # Capacity of the queue between the USB reader thread and the processing loop
    USB_TRANSFER_TIMEOUT_MS = 500

    def __init__(self, bit_file=None):
        """
        Load the Opal Kelly API and initialize the class attributes. The device is not opened until init() is called.

        :param bit_file: Path to the FPGA .bit programming file (default is None)
        """
        self.devices = ok.okCFrontPanelDevices()
        self.device_count = self.devices.GetCount()
        self.device = None  # Opened in init()
        self.fpga = None  # Wire/pipe endpoint access. It is the device itself in FrontPanel < 6.0
        self.device_info = ok.okTDeviceInfo()
        self.bit_file_path = bit_file
        self.inputs = []
        self.global_timestamp = 0
        self.is_monitoring = False

        # A reader thread pulls data from USB while the caller thread processes it
        self.usb_read_thread = None
        self.buffer_queue = Queue(maxsize=self.MAX_NUM_USB_BUFFERS)
        self.stop_usb_thread = threading.Event()
        self.lock = threading.Lock()  # Serializes every access to the device

        self.logger = logging.getLogger('Okaertool')
        logging.basicConfig(
            level=self.LOG_LEVEL,
            format="%(asctime)s - %(levelname)s : %(message)s",
            datefmt="%m/%d/%y %I:%M:%S %p",
            handlers=[
                logging.StreamHandler(),
                logging.FileHandler(self.LOG_FILE, "w"),
            ],
        )

    def reset_board(self, mode='internal'):
        """
        Reset the board using the reset wire.
        :param mode: Reset mode. Possible values: 'internal' (default), 'external', 'both'
        :return:
        """
        reset_values = {'internal': 0x1, 'external': 0x2, 'both': 0x3}
        if mode not in reset_values:
            self.logger.error(f"Invalid reset mode: {mode}. Possible values: 'internal', 'external', 'both'")
            return

        with self.lock:
            self.fpga.SetWireInValue(self.INWIRE_RESET_ENDPOINT, reset_values[mode])
            self.fpga.UpdateWireIns()
            time.sleep(0.1)  # Keep the reset asserted for 100 ms
            self.fpga.SetWireInValue(self.INWIRE_RESET_ENDPOINT, 0x00000000)
            self.fpga.UpdateWireIns()
        self.logger.info("Board reset in mode: " + mode)

    def reset_timestamp(self):
        """
        The OKAERTool timestamps the AER events with an absolute counter that free-runs from 0 while a capture is
        active. global_timestamp only accumulates the wrap-around offset (added once per overflow marker), so it must
        be reset to 0 whenever a new capture starts, in sync with the FPGA counter.
        :return:
        """
        self.global_timestamp = 0
        self.logger.info("Timestamp reset")

    def init(self):
        """
        Open the USB device, program the FPGA with the bit file given in the constructor (if any), configure the USB
        block size according to the negotiated USB speed and leave the tool in idle mode.
        :return: 0 if the operation is successful, -1 otherwise
        """
        self.device = self.devices.Open("")  # Empty serial opens the first available device
        if not self.device:
            self.logger.error(f"Error at okaertool initialization: no Opal Kelly device could be opened "
                              f"({self.device_count} detected)")
            return -1
        # FrontPanel >= 6.0 moved wires and pipes from okCFrontPanel to a separate data port object
        if hasattr(self.device, 'GetFPGADataPortClassic'):
            self.fpga = self.device.GetFPGADataPortClassic()
        else:
            self.fpga = self.device

        if self.bit_file_path is not None:
            error = self.device.ConfigureFPGA(self.bit_file_path)
            if error != OK_NO_ERROR:
                self.logger.error(f"Error at okaertool FPGA configuration: {ok_error_string(error)}")
                return -1
        else:
            self.logger.info("No bit file loaded. Ensure that the FPGA is already programmed")

        error = self.device.GetDeviceInfo(info=self.device_info)
        if error != OK_NO_ERROR:
            self.logger.error(f"Error at okaertool GetDeviceInfo: {ok_error_string(error)}")
            return -1
        self.logger.info(f"Device product ID: {self.device_info.productID}, product name: {self.device_info.productName}, "
                         f"USB speed: {self.device_info.usbSpeed},")

        # Block sizes are limited by the USB speed (see the Opal Kelly ReadFromBlockPipeOut documentation)
        match self.device_info.usbSpeed:
            case ok.OK_USBSPEED_SUPER:
                self.USB_BLOCK_SIZE = 16 * 1024
                self.logger.info("USB 3.0 SuperSpeed. USB block size set to 16 KB")
            case ok.OK_USBSPEED_HIGH:
                self.USB_BLOCK_SIZE = 1024
                self.logger.info("USB 2.0 HighSpeed. USB block size set to 1 KB")
            case ok.OK_USBSPEED_FULL:
                self.USB_BLOCK_SIZE = 64
                self.logger.info("USB 1.1 FullSpeed. USB block size set to 64 Bytes")
            case ok.OK_USBSPEED_UNKNOWN:
                self.USB_BLOCK_SIZE = 64
                self.logger.warning("Unknown USB speed. USB block size set to default 64 Bytes")

        self.device.SetTimeout(self.USB_TRANSFER_TIMEOUT_MS)

        self.__select_command__(['idle'])
        self.logger.info("okaertool initialized as idle")
        return 0

    def __select_inputs__(self, inputs=()):
        """
        Select the inputs to work with. The selected inputs are captured under the same timestamp domain.
        :param inputs: List of input ports. Possible values: 'port_a' 'port_b' 'port_c'
        :return:
        """
        # One bit per input in the input wire
        input_bits = {'port_a': 1, 'port_b': 2, 'port_c': 4}
        selinput_endpoint_value = sum(bit for port, bit in input_bits.items() if port in inputs)
        self.logger.debug(f'Value of input selection: {selinput_endpoint_value}')

        if selinput_endpoint_value == 0:
            self.logger.warning('No inputs defined')

        with self.lock:
            self.fpga.SetWireInValue(self.INWIRE_SELINPUT_ENDPOINT, selinput_endpoint_value)
            self.fpga.UpdateWireIns()

    def __select_command__(self, command=()):
        """
        Select the operation mode of the tool. The values are written in the command wire and must match the
        decoding done in the FPGA design (okt_cu.vhd / okt_cu_pkg.vhd):
        - idle: Do nothing
        - monitor: Capture events from the IMU module, timestamp them in the ECU module and send them to the PC
        - bypass: Forward the events captured by the IMU module directly to the OSU module
        - merge: Monitor and bypass at the same time
        - sequencer: Send events from the PC to the tool to be sequenced by the OSU module
        - debug: Debug mode
        - config_port_a / config_port_b / config_port_c: Configure the device connected to the given port
        :param command: List of commands
        :return:
        """
        command_values = {
            'idle': 0,
            'monitor': 1,
            'bypass': 2,
            'merge': 3,
            'sequencer': 4,
            'debug': 5,
            'config_port_a': 8,
            'config_port_b': 16,
            'config_port_c': 32,
        }
        command_endpoint_value = sum(value for name, value in command_values.items() if name in command)
        self.logger.debug(f'Value of command selection: {command_endpoint_value}')

        with self.lock:
            self.fpga.SetWireInValue(self.INWIRE_COMMAND_ENDPOINT, command_endpoint_value)
            self.fpga.UpdateWireIns()

    def _new_spikes(self):
        """Create an empty Spikes struct for each input."""
        return [Spikes() for _ in range(self.NUM_INPUTS)]

    def _drain_queue(self, spikes=None):
        """
        Empty the buffer queue.
        :param spikes: List of Spikes objects where the queued buffers are processed. If None, buffers are discarded.
        """
        while True:
            try:
                buffer = self.buffer_queue.get_nowait()
            except Empty:
                return
            if spikes is not None:
                self._process_buffer(buffer, spikes)

    def _process_buffer(self, buffer, spikes):
        """
        Process a buffer and extract spikes (timestamps and addresses).

        :param buffer: Buffer containing raw spike data, as (timestamp, address) pairs of 32-bit words
        :param spikes: List of Spikes objects to populate
        """
        data = np.frombuffer(buffer, dtype=np.uint32)

        for word_idx in range(0, len(data) - 1, 2):
            ts = int(data[word_idx])
            addr = int(data[word_idx + 1])

            # The overflow marker (both words 0xFFFFFFFF) must be checked before using the address, since its
            # address word does not represent a real device address
            if ts == self.TIMESTAMP_OVERFLOW_MARKER and addr == self.TIMESTAMP_OVERFLOW_MARKER:
                self.global_timestamp += self.TIMESTAMP_WRAP_VALUE
                self.logger.debug("Timestamp overflow detected")
                continue

            # The two MSBs of the address word identify the input port
            input_idx = (addr & 0xC000_0000) >> 30

            # ts is the time elapsed since the capture start or the last overflow
            spikes[input_idx].timestamps.append(self.global_timestamp + ts)
            spikes[input_idx].addresses.append(addr & 0x3FFFFFFF)

    def _usb_reader_thread(self, buffer_size):
        """
        Thread function that continuously reads from USB and puts the data into the buffer queue.

        :param buffer_size: Size of each buffer to allocate for USB reading
        """
        self.logger.debug("USB reader thread started")

        while not self.stop_usb_thread.is_set():
            buffer = bytearray(buffer_size)

            # The device is not thread-safe: hold the lock during the (blocking) read
            with self.lock:
                num_read_bytes = self.fpga.ReadFromBlockPipeOut(
                    self.OUTPIPE_ENDPOINT,
                    self.USB_BLOCK_SIZE,
                    buffer
                )

            if num_read_bytes < 0:
                self.logger.warning(f'USB read error: {ok_error_string(num_read_bytes)}')
                break

            if num_read_bytes > 0:
                try:
                    self.buffer_queue.put(buffer[:num_read_bytes], timeout=1.0)
                except Full:
                    self.logger.warning("Buffer queue full, dropping data")

        self.logger.debug("USB reader thread stopped")

    def _finish_capture(self, spikes):
        """
        Stop the capture: disable the FPGA monitoring, stop the USB reader thread and process the pending buffers.

        :param spikes: List of Spikes objects where the pending buffers are processed
        """
        self.is_monitoring = False
        self.stop_usb_thread.set()
        self.__select_command__(['idle'])

        if self.usb_read_thread and self.usb_read_thread.is_alive():
            self.usb_read_thread.join(timeout=2.0)
            if self.usb_read_thread.is_alive():
                self.logger.warning("USB thread did not stop cleanly")

        self._drain_queue(spikes)

    def monitor(self, inputs=(), duration=None, max_spikes=None, live=False):
        """
        Capture the events received by the tool and store them in a Spikes struct per input. The events are first
        collected by the IMU, then timestamped by the ECU and finally sent to the PC through the USB port.
        There are three monitoring modes:
            1. Duration-based: Monitor for a specific time period (duration parameter)
            2. Spike-count based: Monitor until a specific number of spikes is captured (max_spikes parameter)
            3. Live mode: Continuous monitoring until stop_monitor() is called (live=True)
        With no mode selected, the capture runs until the USB reader thread stops.
        Each input is stored in the position of the returned list given by its port:
            - Input 0: port_a
            - Input 1: port_b
            - Input 2: port_c

        :param inputs: List of input ports to capture. Possible values: 'port_a', 'port_b', 'port_c'
        :param duration: Duration of capture in seconds (None for other modes)
        :param max_spikes: Maximum number of spikes to capture (None for other modes)
        :param live: If True, continuous monitoring mode until stop_monitor() is called
        :return: List of Spikes objects (one per input), or None if in live mode or on error
        """
        if len(inputs) == 0:
            self.logger.error('No inputs defined')
            return None

        if sum([duration is not None, max_spikes is not None, live]) > 1:
            self.logger.error('Only one monitoring mode can be selected: duration, max_spikes, or live')
            return None

        if self.is_monitoring:
            self.logger.warning('Previous monitoring session active, stopping it')
            self.stop_monitor()
            time.sleep(0.2)

        if self.usb_read_thread and self.usb_read_thread.is_alive():
            self.logger.warning('Waiting for previous USB thread to finish')
            self.stop_usb_thread.set()
            self.usb_read_thread.join(timeout=3.0)
            if self.usb_read_thread.is_alive():
                self.logger.error('Previous USB thread did not stop!')
                return None

        spikes = self._new_spikes()
        self._drain_queue()  # Discard data from previous sessions

        self.reset_timestamp()
        self.__select_inputs__(inputs=inputs)
        self.__select_command__(['monitor'])

        self.stop_usb_thread.clear()
        self.is_monitoring = True
        self.usb_read_thread = threading.Thread(
            target=self._usb_reader_thread,
            args=(self.USB_TRANSFER_LENGTH,),
            daemon=True
        )
        self.usb_read_thread.start()

        self.logger.info(f'Starting monitoring - USB buffer: {self.USB_TRANSFER_LENGTH / (1024 * 1024):.2f} MB')

        if live:
            self.logger.info('Live monitoring started')
            return None

        start_time = time.time()
        buffer_count = 0

        try:
            while self.is_monitoring:
                try:
                    buffer = self.buffer_queue.get(timeout=2.0)
                except Empty:
                    if self.usb_read_thread.is_alive():
                        self.logger.warning("Timeout waiting for a USB buffer")
                        continue
                    self.logger.info("USB reader thread stopped")
                    break

                buffer_count += 1
                self._process_buffer(buffer, spikes)

                if buffer_count % 50 == 0:
                    total_spikes = sum(len(s.timestamps) for s in spikes)
                    elapsed = time.time() - start_time
                    rate = total_spikes / elapsed if elapsed > 0 else 0
                    self.logger.debug(
                        f'Processed {buffer_count} buffers, {total_spikes} spikes, '
                        f'{rate:.0f} spikes/sec, global_ts: {self.global_timestamp}'
                    )

                if duration is not None:
                    elapsed = time.time() - start_time
                    if elapsed >= duration:
                        self.logger.info(f'Duration limit reached: {elapsed:.2f} seconds')
                        break

                if max_spikes is not None:
                    total_spikes = sum(len(s.timestamps) for s in spikes)
                    if total_spikes >= max_spikes:
                        self.logger.info(f'Spike limit reached: {total_spikes} spikes')
                        break
        finally:
            self.logger.debug('Cleaning up monitoring session')
            self._finish_capture(spikes)

            total_spikes = sum(len(s.timestamps) for s in spikes)
            elapsed = time.time() - start_time
            self.logger.info(f'Monitoring completed: {elapsed:.2f} seconds, {total_spikes} spikes captured')

        return spikes

    def get_live_spikes(self):
        """
        Get the spikes captured since the last call during live monitoring. The processed buffers are removed from
        the internal queue.

        :return: List of Spikes objects (one per input), or None if there are no new spikes
        """
        if not self.is_monitoring:
            self.logger.warning('Not in live monitoring mode')
            return None

        spikes = self._new_spikes()
        self._drain_queue(spikes)

        return spikes if any(s.timestamps for s in spikes) else None

    def stop_monitor(self):
        """
        Stop live monitoring and return the spikes captured since the last call to get_live_spikes().

        :return: List of Spikes objects (one per input), or None if no monitoring session is active
        """
        if not self.is_monitoring:
            self.logger.warning('Not currently monitoring')
            return None

        self.logger.info('Stopping live monitor')

        spikes = self._new_spikes()
        self._finish_capture(spikes)

        total_spikes = sum(len(s.timestamps) for s in spikes)
        self.logger.info(f'Live monitoring stopped: {total_spikes} spikes captured')

        return spikes

    def bypass(self, inputs=()):
        """
        AER data is bypassed from the IMU directly into the OSU.

        :param inputs: List of input ports to bypass. Possible values: 'port_a' 'port_b' 'port_c'
        :return:
        """
        self.logger.info(f'Bypassing data over {inputs}')
        self.__select_inputs__(inputs=inputs)
        self.__select_command__(['bypass'])

    def sequencer(self, file):
        """
        Sequencer mode: the content of a binary file is sent to the OSU, which sequences it over the output port in a
        single transfer.
        TODO: Implement the sequencer mode in a thread.

        :param file: Path to a binary file with (timestamp, address) pairs of 32-bit words
        :return:
        """
        self.logger.info('Sequencing data')

        buffer = np.fromfile(file, dtype=np.uint8)
        self.__select_command__(['sequencer'])
        num_sent_bytes = self.fpga.WriteToBlockPipeIn(self.INPIPE_ENDPOINT, self.USB_BLOCK_SIZE, buffer)
        self.logger.info(f'Number of sent bytes: {num_sent_bytes}. Number of sent spikes: {num_sent_bytes / self.SPIKE_SIZE_BYTES}')
        self.__select_command__(['idle'])

    def set_config(self, device, register_address, register_value):
        """
        Set the value of a register of the device connected to a port. The 32-bit value written in the config wire
        has the register address in the upper 16 bits and the register value in the lower 16 bits.

        :param device: Device to be configured. Possible values: 'port_a' 'port_b' 'port_c'
        :param register_address: Address of the register to be set
        :param register_value: Value to be set in the register
        :return: 0 if the operation is successful, -1 if the device is not defined
        """
        config_commands = {'port_a': 'config_port_a', 'port_b': 'config_port_b', 'port_c': 'config_port_c'}
        if device not in config_commands:
            self.logger.error('Device not defined')
            return -1

        address_value = ((register_address & 0xFFFF) << 16) | (register_value & 0xFFFF)
        with self.lock:
            self.fpga.SetWireInValue(self.INWIRE_CONFIG_ENDPOINT, address_value)
            self.fpga.UpdateWireIns()

        # The FPGA latches the register while the config command is active
        self.__select_command__([config_commands[device]])
        self.__select_command__(['idle'])

        with self.lock:
            self.fpga.SetWireInValue(self.INWIRE_CONFIG_ENDPOINT, 0x00000000)
            self.fpga.UpdateWireIns()
        self.logger.info(f'Configuring {device} with address {hex(register_address)} and value {hex(register_value)}')
        return 0
