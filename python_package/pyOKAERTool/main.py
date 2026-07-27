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
##    along with pyNAVIS.  If not, see <http://www.gnu.org/licenses/>.         ##
##                                                                             ##
#################################################################################
import time
import logging
import numpy as np
import threading
from queue import Queue
from . import ok as ok

class Spikes:
    """
    Class that contains all the addresses and timestamps of a file.
    Attributes:
        timestamps (int[]): Timestamps of the file.
        addresses (int[]): Addresses of the file.
    Note:
        Timestamps and addresses are matched, which means that timestamps[0] is the timestamp for the spike with address addresses[0].
    """
    def __init__(self, addresses=[], timestamps=[]):
        self.addresses = addresses
        self.timestamps = timestamps

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
    Class that manages the OpalKelly USB 3.0 board. This class interfaces with the okaertool FPGA module to send and
    receive information to and from the tool

    Attributes:
        bit_file (string): Path to the FPGA .bit programming file
    """
    OUTPIPE_ENDPOINT = 0xA0
    INPIPE_ENDPOINT = 0x80
    INWIRE_COMMAND_ENDPOINT = 0x00
    INWIRE_SELINPUT_ENDPOINT = 0x01
    INWIRE_RESET_ENDPOINT = 0x02
    INWIRE_CONFIG_ENDPOINT = 0x03
    NUM_INPUTS = 3
    LOG_LEVEL = logging.INFO
    LOG_FILE = "okaertool.log"
    SPIKE_SIZE_BYTES = 8  # Each spike has a timestamp (4 bytes) and an address (4 bytes)
    # USB parameters
    USB_BLOCK_SIZE = 16 * 1024  # Will be updated in init() based on USB speed
    USB_TRANSFER_LENGTH = 1 * 1024 * 1024  # Must be multiple of USB_BLOCK_SIZE
    MAX_NUM_USB_BUFFERS = 16
    USB_TRANSFER_TIMEOUT_MS = 500  # Timeout for USB transfers in milliseconds
    

    def __init__(self, bit_file=None):
        """
        Constructor of the class. It loads the OpalKelly API, gets the number of devices connected to the USB port and
        selects the first one. It also initializes the path to the bit file and creates an empty list of inputs.

        :param bit_file: Path to the FPGA .bit programming file (default is None)
        """
        # Load the OpalKelly API and initialize the class attributes
        self.device = ok.okCFrontPanel()
        self.device_count = self.device.GetDeviceCount()
        self.device_info = ok.okTDeviceInfo()
        self.bit_file_path = bit_file
        self.inputs = []
        self.global_timestamp = 0
        self.is_monitoring = False
        
        # USB reading thread and double buffer system
        self.usb_read_thread = None
        self.buffer_queue = Queue(maxsize=self.MAX_NUM_USB_BUFFERS)
        self.stop_usb_thread = threading.Event()
        self.lock = threading.Lock()
        
        # Create a logger
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
        if mode not in ['internal', 'external', 'both']:
            self.logger.error(f"Invalid reset mode: {mode}. Possible values: 'internal', 'external', 'both'")
            return
        
        with self.lock:
            if mode == 'internal':
                self.device.SetWireInValue(self.INWIRE_RESET_ENDPOINT, 0x00000001)
            elif mode == 'external':
                self.device.SetWireInValue(self.INWIRE_RESET_ENDPOINT, 0x00000002)
            elif mode == 'both':
                self.device.SetWireInValue(self.INWIRE_RESET_ENDPOINT, 0x00000003)

            self.device.UpdateWireIns()
            # Wait a 100 ms and set the reset back to 0
            time.sleep(0.1)
            self.device.SetWireInValue(self.INWIRE_RESET_ENDPOINT, 0x00000000)
            self.device.UpdateWireIns()
        self.logger.info("Board reset in mode: " + mode)


    def reset_timestamp(self):
        """
        The OKAERTool captures the AER events with a differential timestamp. When the tool monitors the AER events, the golbal
        timestamp is increased by the differential timestamp. This function resets the global timestamp to 0.
        :return:
        """
        # Reset the global timestamp
        self.global_timestamp = 0
        self.logger.info("Timestamp reset")


    def init(self):
        """
        Open the USB device and configure the FPGA using the bit file define in the constructor.
        putting a timestamp to each event.
        :return:
        """
        # Open the USB device
        error = self.device.OpenBySerial("")
        if error != 0:  # No error
            self.logger.error(f"Error at okaertool initialization: {ok.okCFrontPanel_GetErrorString(error)}")
            return -1

        # Configure the FPGA with the bit file if it is defined
        if self.bit_file_path is not None:
            error = self.device.ConfigureFPGA(self.bit_file_path)
            if error != ok.okCFrontPanel.NoError:
                self.logger.error(f"Error at okaertool FPGA configuration: {ok.okCFrontPanel_GetErrorString(error)}")
                return -1
        else:
            self.logger.info("No bit file loaded. Ensure that the FPGA is already programmed")
        
        # Get the device information
        error = self.device.GetDeviceInfo(info=self.device_info)
        if error != ok.okCFrontPanel.NoError:
            self.logger.error(f"Error at okaertool GetDeviceInfo: {ok.okCFrontPanel_GetErrorString(error)}")
            return -1
        self.logger.info(f"Device product ID: {self.device_info.productID}, product name: {self.device_info.productName}, "
                         f"USB speed: {self.device_info.usbSpeed},")
        match self.device_info.usbSpeed:
            case ok.OK_USBSPEED_SUPER:
                self.USB_BLOCK_SIZE = 16 * 1024 # USB 3.0 SuperSpeed - Power of two [16..16384];
                self.logger.info("USB 3.0 SuperSpeed. USB block size set to 16 KB")
            case ok.OK_USBSPEED_HIGH:
                self.USB_BLOCK_SIZE = 1024 # USB 2.0 HighSpeed - Power of two [16..1024]
                self.logger.info("USB 2.0 HighSpeed. USB block size set to 1 KB")
            case ok.OK_USBSPEED_FULL:
                self.USB_BLOCK_SIZE = 64 # USB 1.1 FullSpeed - Power of two [16..64]
                self.logger.info("USB 1.1 FullSpeed. USB block size set to 64 Bytes")
                self.USB_BLOCK_SIZE = 64 # USB 1.1 FullSpeed - Power of two [16..64]
            case ok.OK_USBSPEED_UNKNOWN:
                self.logger.warning("Unknown USB speed. USB block size set to default 64 Bytes")
                self.USB_BLOCK_SIZE = 64
        
        # Set the USB transactions timeout
        self.device.SetTimeout(self.USB_TRANSFER_TIMEOUT_MS)

        # Set the tool to idle mode
        self.__select_command__(['idle'])
        self.logger.info("okaertool initialized as idle")
        return 0


    def __select_inputs__(self, inputs=[]):
        """
        Select the inputs that the user wants to work with. These inputs are captured under the same timestamp domain.
        :param inputs: List of input ports to capture information. Possible values: 'port_a' 'port_b' 'port_c'
        :return:
        """
        # Set the value of the input wire. The value is a 3-bit number where each bit represents an input.
        selinput_endpoint_value = 0x00000000
        if len(inputs) != 0:
            if 'port_a' in inputs:
                selinput_endpoint_value += 1  # Set 1 in the bit number 0
            if 'port_b' in inputs:
                selinput_endpoint_value += 2  # Set 1 in the bit number 1
            if 'port_c' in inputs:
                selinput_endpoint_value += 4  # Set 1 in the bit number 2
        self.logger.debug(f'Value of input selection: {selinput_endpoint_value}')

        # If the selinput_endpoint_value is 0, the input is not defined. Log an warning message
        if selinput_endpoint_value == 0:
            self.logger.warning('No inputs defined')

        # Set the value of the input wire
        with self.lock:
            self.device.SetWireInValue(self.INWIRE_SELINPUT_ENDPOINT, selinput_endpoint_value)
            self.device.UpdateWireIns()


    def __select_command__(self, command=[]):
        """
        Select the commands that the user wants to work with. These commands are used to configure the tool:
        - idle: Do nothing
        - monitor: Capture events from the IMU module, put a timestamp to each event and send them to the ECU module
        - bypass: Capture events from the IMU module and send them directly to the OSU module
        - monitor_bypass: Capture events from the IMU module, put a timestamp to each event sending them to the ECU module and
            bypass the events to the OSU module
        - sequencer: Send events from the software to the OKAERTool to be sequenced using the OSU module
        - config_port_a: Configure the device connected to the port A
        - config_port_b: Configure the device connected to the port B
        :param command: List of commands. Possible values: 'idle' 'monitor' 'bypass' 'monitor_bypass' 'sequencer'
        :return:
        """
        # Set the value of the command wire. The value is a 3-bit number where each bit represents a command or a
        # combination of them.
        command_endpoint_value = 0x00000000
        if len(command) != 0:
            if 'idle' in command:
                command_endpoint_value += 0  # Set 0 in the bit number 0
            if 'monitor' in command:
                command_endpoint_value += 1  # Set 1 in the bit number 0
            if 'bypass' in command:
                command_endpoint_value += 2  # Set 1 in the bit number 1
            if 'merge' in command:
                command_endpoint_value += 3  # Set 1 in the bit number 0 and 1
            if 'sequencer' in command:
                command_endpoint_value += 4  # Set 1 in the bit number 2
            if 'debug' in command:
                command_endpoint_value += 5  
            if 'config_port_a' in command:
                command_endpoint_value += 8  # Set 1 in the bit number 3
            if 'config_port_b' in command:
                command_endpoint_value += 16 # Set 1 in the bit number 4
            if 'config_port_c' in command:
                command_endpoint_value += 32 # Set 1 in the bit number 5

        self.logger.debug(f'Value of command selection: {command_endpoint_value}')

        # Set the value of the command wire
        with self.lock:
            self.device.SetWireInValue(self.INWIRE_COMMAND_ENDPOINT, command_endpoint_value)
            self.device.UpdateWireIns()


    def _process_buffer(self, buffer, spikes):
        """
        Process a buffer and extract spikes (timestamps and addresses).
        
        :param buffer: Buffer containing raw spike data
        :param spikes: List of Spikes objects to populate
        """
        # Convert to numpy array
        data = np.frombuffer(buffer, dtype=np.uint32)
        
        if len(data) < 2:
            return
        
        # Process events in pairs (timestamp, address)
        num_pairs = len(data) // 2
        
        # Process each pair
        for pair_idx in range(num_pairs):
            byte_idx = pair_idx * 2
            
            # # Skip first pair
            # if byte_idx == 0:
            #     continue
            
            # Extract timestamp and address
            ts = int(data[byte_idx])
            addr = int(data[byte_idx + 1])
            
            # Skip null events
            if ts == 0 and addr == 0:
                self.logger.warning("Skipping null event")
                continue
            
            # Validate address
            if (addr & 0x3FFFFFFF) > 256:
                continue
            
            # Handle timestamp overflow
            if ts == 0xFFFFFFFF:
                self.global_timestamp += ts
                self.logger.debug("Timestamp overflow detected")
                continue
            
            # Extract input index
            input_idx = (addr & 0xC000_0000) >> 30
            
            # Save spike with absolute timestamp
            absolute_ts = self.global_timestamp + ts
            spikes[input_idx].timestamps.append(absolute_ts)
            spikes[input_idx].addresses.append(addr & 0x3FFFFFFF)
            
            # Update global_timestamp by the delta
            self.global_timestamp += ts


    def _usb_reader_thread(self, buffer_size):
        """
        Thread function that continuously reads from USB and puts data into the buffer queue.
        
        :param buffer_size: Size of each buffer to allocate for USB reading
        """
        self.logger.debug("USB reader thread started")
        
        while not self.stop_usb_thread.is_set():
            # Allocate a new buffer for this read
            buffer = bytearray(buffer_size)
            
            # CRITICAL: Lock device access before USB read
            with self.lock:
                # Blocking read from USB
                num_read_bytes = self.device.ReadFromBlockPipeOut(
                    self.OUTPIPE_ENDPOINT, 
                    self.USB_BLOCK_SIZE, 
                    buffer
                )
            
            if num_read_bytes < 0:
                self.logger.warning(f'USB read error: {ok.okCFrontPanel_GetErrorString(num_read_bytes)}')
                break
            
            if num_read_bytes > 0:
                # Trim buffer to actual read size
                buffer = buffer[:num_read_bytes]
                # Put the buffer in the queue (blocks if queue is full)
                try:
                    self.buffer_queue.put(buffer, timeout=1.0)
                except:
                    self.logger.warning("Buffer queue full, dropping data")
        
        self.logger.debug("USB reader thread stopped")


    def monitor(self, inputs=[], duration=None, max_spikes=None, live=False):
        """
        Get the information captured by the tool (ECU) and save it in different spikes structs depending on the selected
        inputs. First, the events/spikes are collected in the IMU, next are captured in the ECU putting a timestamp and 
        finally, events/spikes are sent from CU to PC by USB port. The information is read from the device while the number
        of read bytes is less than the buffer length or the duration is not reached. 
            1. Duration-based: Monitor for a specific time period (duration parameter)
            2. Spike-count based: Monitor until a specific number of spikes is captured (max_spikes parameter)
            3. Live mode: Continuous monitoring until stop_monitor() is called (live=True)
        The information is saved in a list of spikes structs. Each struct contains the timestamps and addresses of the 
        events/spikes captured in the same input:
            - Input 0: port_a
            - Input 1: port_b
            - Input 2: port_c
        
        :param inputs: List of input ports to capture. Possible values: 'port_a', 'port_b', 'port_c'
        :param duration: Duration of capture in seconds (None for other modes)
        :param max_spikes: Maximum number of spikes to capture (None for other modes)
        :param live: If True, continuous monitoring mode until stop_monitor() is called
        :return: List of Spikes objects (one per input), or None if in live mode
        """
        # Validate inputs
        if len(inputs) == 0:
            self.logger.error('No inputs defined')
            return None
        
        # Check that only one mode is selected
        mode_count = sum([duration is not None, max_spikes is not None, live])
        if mode_count > 1:
            self.logger.error('Only one monitoring mode can be selected: duration, max_spikes, or live')
            return None
        
        # CRITICAL: Stop any previous monitoring session
        if self.is_monitoring:
            self.logger.warning('Previous monitoring session active, stopping it')
            self.stop_monitor()
            time.sleep(0.2)  # Give time for cleanup
        
        # CRITICAL: Wait for previous USB thread to finish
        if self.usb_read_thread and self.usb_read_thread.is_alive():
            self.logger.warning('Waiting for previous USB thread to finish')
            self.stop_usb_thread.set()
            self.usb_read_thread.join(timeout=3.0)
            if self.usb_read_thread.is_alive():
                self.logger.error('Previous USB thread did not stop!')
                return None

        # Initialize spikes storage
        spikes = [Spikes(addresses=[], timestamps=[]) for _ in range(self.NUM_INPUTS)]
        
        # Clear the buffer queue
        while not self.buffer_queue.empty():
            try:
                self.buffer_queue.get_nowait()
            except:
                break
        
        # Reset global timestamp
        # self.reset_board(mode='internal')
        self.reset_timestamp()
        # Select inputs
        self.__select_inputs__(inputs=inputs)
        # Enable monitoring on FPGA
        self.__select_command__(['monitor'])

        # Start USB reader thread
        self.stop_usb_thread.clear()
        self.is_monitoring = True
        self.usb_read_thread = threading.Thread(
            target=self._usb_reader_thread, 
            args=(self.USB_TRANSFER_LENGTH,),
            daemon=True
        )
        self.usb_read_thread.start()
        
        self.logger.info(f'Starting monitoring - USB buffer: {self.USB_TRANSFER_LENGTH / (1024 * 1024):.2f} MB')
        
        # For live mode, return immediately (thread continues running)
        if live:
            self.logger.info('Live monitoring started')
            return None

        # Start timing
        start_time = time.time()
        total_spikes = 0
        buffer_count = 0
        
        try:
            # Main processing loop
            while self.is_monitoring and not live:
                try:
                    buffer = self.buffer_queue.get(timeout=2.0)
                    buffer_count += 1
                    
                    # Process buffer
                    self._process_buffer(buffer, spikes)
                    
                    # Log progress every 50 buffers
                    if buffer_count % 50 == 0:
                        total_spikes = sum(len(s.timestamps) for s in spikes)
                        elapsed = time.time() - start_time
                        rate = total_spikes / elapsed if elapsed > 0 else 0
                        self.logger.debug(
                            f'Processed {buffer_count} buffers, {total_spikes} spikes, '
                            f'{rate:.0f} spikes/sec, global_ts: {self.global_timestamp}'
                        )
                    
                    # Check stopping conditions
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
                            
                except Exception as e:
                    if self.usb_read_thread and self.usb_read_thread.is_alive():
                        self.logger.warning(f"Timeout or error getting buffer: {e}")
                        continue
                    else:
                        self.logger.info("USB reader thread stopped")
                        break
                
                # In live mode, continue until stop_monitor() is called
        
        finally:
            # Stop monitoring (only for non-live modes)
            self.logger.debug('Cleaning up monitoring session')
            self.is_monitoring = False
            self.stop_usb_thread.set()
            self.__select_command__(['idle'])
            
            # Wait for USB thread to finish
            if self.usb_read_thread and self.usb_read_thread.is_alive():
                self.usb_read_thread.join(timeout=2.0)
                if self.usb_read_thread.is_alive():
                    self.logger.warning("USB thread did not stop cleanly")
            
            # Process any remaining buffers
            while not self.buffer_queue.empty():
                try:
                    buffer = self.buffer_queue.get_nowait()
                    self._process_buffer(buffer, spikes)
                except:
                    break
            
            # Log statistics
            total_spikes = sum(len(s.timestamps) for s in spikes)
            elapsed = time.time() - start_time
            self.logger.info(f'Monitoring completed: {elapsed:.2f} seconds, {total_spikes} spikes captured')
        
        return spikes
        #     # Stop monitoring
        #     if not live or not self.is_monitoring:
        #         self.is_monitoring = False
        #         self.stop_usb_thread.set()
        #         self.__select_command__(['idle'])
                
        #         # Wait for USB thread to finish
        #         if self.usb_read_thread and self.usb_read_thread.is_alive():
        #             self.logger.debug("Waiting for USB thread to finish")
        #             self.usb_read_thread.join()
                
        #         # Log statistics
        #         elapsed = time.time() - start_time
        #         self.logger.info(f'Monitoring completed: {elapsed:.2f} seconds, {total_spikes} spikes captured')
        
        # # Return results (None for live mode, spikes for other modes)
        # if live:
        #     return None
        # else:
        #     return spikes
        

    def get_live_spikes(self):
        """
        Get spikes captured during live monitoring. This method returns accumulated spikes
        and clears the internal buffer.
        
        :return: List of Spikes objects, one per input
        """
        if not self.is_monitoring:
            self.logger.warning('Not in live monitoring mode')
            return None
        
        # Create a snapshot of current spikes
        spikes = [Spikes(addresses=[], timestamps=[]) for _ in range(self.NUM_INPUTS)]
        
        # Process all available buffers
        while not self.buffer_queue.empty():
            try:
                buffer = self.buffer_queue.get_nowait()
                self._process_buffer(buffer, spikes)
            except:
                self.logger.debug("No more buffers to process")
                break
        
        return spikes if sum(len(s.timestamps) for s in spikes) > 0 else None


    def stop_monitor(self):
        """
        Stop live monitoring and return all captured spikes.
        
        :return: List of Spikes objects containing all captured data
        """
        if not self.is_monitoring:
            self.logger.warning('Not currently monitoring')
            return None
        
        self.logger.info('Stopping live monitor')
        
        
        # Signal stop
        self.is_monitoring = False
        self.stop_usb_thread.set()
        
        # Disable FPGA monitoring
        self.__select_command__(['idle'])
        
        # Wait for USB thread to finish
        if self.usb_read_thread and self.usb_read_thread.is_alive():
            self.logger.debug("Waiting for USB thread to finish")
            self.usb_read_thread.join(timeout=2.0)
            if self.usb_read_thread.is_alive():
                self.logger.warning("USB thread did not stop cleanly")
        
        # Process any remaining buffers
        spikes = [Spikes(addresses=[], timestamps=[]) for _ in range(self.NUM_INPUTS)]
        while not self.buffer_queue.empty():
            try:
                buffer = self.buffer_queue.get_nowait()
                self._process_buffer(buffer, spikes)
            except:
                break
        
        total_spikes = sum(len(s.timestamps) for s in spikes)
        self.logger.info(f'Live monitoring stopped: {total_spikes} spikes captured')
        
        return spikes


    def bypass(self, inputs=[]):
        """
        AER data is bypassed from IMU directly into OSU. This command can be used alongside "monitor".
        
        :param inputs: string that contains input port to bypass. Possible values: 'Port_A' 'Port_B' 'Node_out'
        :return:
        """
        self.logger.info(f'Bypassing data over {inputs}')
        self.__select_inputs__(inputs=inputs)
        self.__select_command__('bypass')


    def sequencer(self, file):
        """
        TODO: Implement sequencer mode in a thread.
        MODE SEQUENCER: A file is selected to be sequenced over NODE_IN output in a lone transfer.
        :param file: numpy or txt file that contains binary data for sequencer
        :return:
        """
        self.logger.info('Sequencing data')

        # Read the binary file into a numpy array
        with open(file, 'rb') as binfile:
            buffer = np.frombuffer(binfile.read(), dtype=np.uint8)
            buffer = np.array(buffer, dtype=np.uint8)
        self.__select_command__('sequencer')
        num_sent_bytes = self.device.WriteToBlockPipeIn(self.INPIPE_ENDPOINT, self.USB_BLOCK_SIZE, buffer)
        self.logger.info(f'Number of sent bytes:  {num_sent_bytes}. Number of sent spikes: {num_sent_bytes/self.SPIKE_SIZE_BYTES}')
        self.__select_command__('idle')


    def set_config(self, device, register_address, register_value):
        """
        Set the value of a register pointed by an address. The pair (address, value) is a 32-bit number where the fist 16 bits
        are the register address and the last 16 bits are the register value.
        :param device: Device to be configured. Possible values: 'port_a' 'port_b' 'port_c'
        :param register_address: Address of the register to be set
        :param register_value: Value to be set in the register
        :return: 0 if the operation is successful, -1 if the device is not defined
        """
        # Concatenate the address and value into a 32-bit number
        address = (register_address & 0xFFFF) << 16
        value = register_value & 0xFFFF
        address_value = address | value
        # Set the value of the config register
        with self.lock:
            self.device.SetWireInValue(self.INWIRE_CONFIG_ENDPOINT, address_value)
            self.device.UpdateWireIns()
        # Set the command to configure the device
        if device == 'port_a':
            self.__select_command__(['config_port_a'])
        elif device == 'port_b':
            self.__select_command__(['config_port_b'])
        elif device == 'port_c':
            self.__select_command__(['config_port_c'])
        else:
            self.logger.error('Device not defined')
            return -1
        # Wait 10ms to ensure that the register is set
        # time.sleep(0.01)
        # Set the command to idle to finish the configuration
        self.__select_command__(['idle'])
        # Wait 10ms to ensure that the register is set
        # time.sleep(0.01)
        # Set the value of the register to zero
        with self.lock:
            self.device.SetWireInValue(self.INWIRE_CONFIG_ENDPOINT, 0x00000000)
            self.device.UpdateWireIns()
        self.logger.info(f'Configuring {device} with address {hex(register_address)} and value {hex(register_value)}')
        return 0

