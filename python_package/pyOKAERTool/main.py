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
    USB_BLOCK_SIZE = 1024
    LOG_LEVEL = logging.INFO
    LOG_FILE = "okaertool.log"
    SPIKE_SIZE_BYTES = 8

    def __init__(self, bit_file=None):
        """
        Constructor of the class. It loads the OpalKelly API, gets the number of devices connected to the USB port and
        selects the first one. It also initializes the path to the bit file and creates an empty list of inputs.

        :param bit_file: Path to the FPGA .bit programming file (default is None)
        """
        # Load the OpalKelly API and initialize the class attributes
        self.device = ok.okCFrontPanel()
        self.device_count = self.device.GetDeviceCount()
        self.id = self.device.GetDeviceID()
        self.bit_file_path = bit_file
        self.inputs = []
        self.global_timestamp = 0
        self.is_monitoring = False
        # Define the tread and a list of spikes (ts, addr) to collect spikes from all inputs during the monitor_forever() method
        self.monitor_thread = None
        self.spikes = None

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


    def reset_board(self):
        """
        Reset the board using the reset wire.
        :return:
        """
        # Set the value of the reset wire to 1
        self.device.SetWireInValue(self.INWIRE_RESET_ENDPOINT, 0x00000001)
        self.device.UpdateWireIns()
        # Wait a 100 ms and set the reset back to 0
        time.sleep(0.1)
        self.device.SetWireInValue(self.INWIRE_RESET_ENDPOINT, 0x00000000)
        self.device.UpdateWireIns()
        self.logger.info("Board reset")


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
            if error != 0:
                self.logger.error(f"Error at okaertool FPGA configuration: {ok.okCFrontPanel_GetErrorString(error)}")
                return -1
        else:
            self.logger.info("No bit file loaded. Ensure that the FPGA is already programmed")
        
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
        self.device.SetWireInValue(self.INWIRE_COMMAND_ENDPOINT, command_endpoint_value)
        self.device.UpdateWireIns()


    def monitor(self, inputs=[], max_spikes=None, duration=None):
        """
        Get the information captured by the tool (ECU) and save it in different spikes structs depending on the selected
        inputs. First, the events/spikes are collected in the IMU, next are captured in the ECU putting a timestamp and 
        finally, events/spikes are sent from CU to PC by USB port. The information is read from the device while the number
        of read bytes is less than the buffer length or the duration is not reached. The information is saved in a list of
        spikes structs. Each struct contains the timestamps and addresses of the events/spikes captured in the same input:
        - Input 0: port_a
        - Input 1: port_b
        - Input 2: port_c

        :param inputs: List of strings that contains input port to capture. Possible values: 'port_a' 'port_b' 'port_c'
        :param max_spikes: Maximum number of spikes to be captured.
        :param duration: Duration of the capture in seconds
        :return: spikes: List of captured spikes (ts, addr)
        """
        # Check if the inputs are defined. If not, return None and log an error
        if len(inputs) == 0:
            self.logger.error('No inputs defined')
            return None
        self.__select_inputs__(inputs=inputs)

        # Define a list of spikes (ts, addr) to collect spikes from all inputs
        spikes = [Spikes(addresses=[], timestamps=[]) for x in range(self.NUM_INPUTS)]

        # If the buffer length is defined, read the information from the device while the number of read bytes is less than
        # the buffer length
        if max_spikes is not None and duration is None:
            # Calculate the size of the buffer in bytes according to the number of spikes to be read, the size of a spike and
            # the size of the self.USB_BLOCK_SIZE. Buffer lenght must be an integer multiple of the self.USB_BLOCK_SIZE.
            buffer_length = max_spikes * self.SPIKE_SIZE_BYTES
            buffer_length = buffer_length + (self.USB_BLOCK_SIZE - (buffer_length % self.USB_BLOCK_SIZE))
            self.logger.info(f'Buffer length: {buffer_length}')
            buffer = bytearray(buffer_length)
            buffer = np.array(buffer, dtype=np.uint8)
                
            # Enable capture function
            self.__select_command__(['monitor'])
            self.is_monitoring = True
            # Read information from the device
            num_read_bytes = 0
            # Start counting the time
            start_time = time.time()
            while num_read_bytes < buffer.size / self.SPIKE_SIZE_BYTES:
                num_read_bytes += self.device.ReadFromBlockPipeOut(self.OUTPIPE_ENDPOINT, self.USB_BLOCK_SIZE, buffer[num_read_bytes:])
                if num_read_bytes < 0:
                    self.logger.error(f'Error at monitor: {ok.okCFrontPanel_GetErrorString(num_read_bytes)}')
                    return None

            # Stop counting the time
            now = time.time()
            # Disable capture function
            self.__select_command__(['idle'])
            self.is_monitoring = False

        # If the duration is defined, read the information from the device while the duration is not reached
        elif duration is not None and max_spikes is None:
            # Fix the buffer length to the USB_BLOCK_SIZE
            buffer_length = self.USB_BLOCK_SIZE
            buffer = bytearray(buffer_length)
            buffer = np.array(buffer, dtype=np.uint8)
            self.logger.info(f'Buffer length: {buffer_length}')
            # Create a global buffer to concatenate all information read from the device that is captured in the buffer array
            global_buffer = bytearray()
            global_buffer = np.array(global_buffer, dtype=np.uint8)
            # Enable capture function
            self.__select_command__(['monitor'])
            self.is_monitoring = True
            # Start counting the time
            start_time = time.time()
            # Read information from the device
            num_read_bytes = 0
            now = time.time()
            while now - start_time < duration:
                num_read_bytes += self.device.ReadFromBlockPipeOut(self.OUTPIPE_ENDPOINT, self.USB_BLOCK_SIZE, buffer)
                if num_read_bytes < 0:
                    self.logger.error(f'Error at monitor: {ok.okCFrontPanel_GetErrorString(num_read_bytes)}')
                    return None
                # Concatenate the buffer with the global buffer
                global_buffer = np.concatenate((global_buffer, buffer))
                now = time.time()

            # Disable capture function
            self.__select_command__(['idle'])
            self.is_monitoring = False
            # Save the global buffer in the buffer variable
            buffer = global_buffer

        # If the duration and the number of spikes are defined, read the information from the device while the duration is not
        # reached or the number of spikes is less than the maximum number of spikes
        elif duration is not None and max_spikes is not None:
            # Fix the buffer length to the USB_BLOCK_SIZE
            buffer_length = self.USB_BLOCK_SIZE
            buffer = bytearray(buffer_length)
            buffer = np.array(buffer, dtype=np.uint8)
            self.logger.info(f'Buffer length: {buffer_length}')
            # Calculate the total buffer length according to the maximum number of spikes and the size of a spike
            total_buffer_length = max_spikes * self.SPIKE_SIZE_BYTES
            total_buffer_length = total_buffer_length + (self.USB_BLOCK_SIZE - (total_buffer_length % self.USB_BLOCK_SIZE))
            # Create a global buffer to concatenate all information read from the device that is captured in the buffer array
            global_buffer = bytearray()
            global_buffer = np.array(global_buffer, dtype=np.uint8)

            # Enable capture function
            self.__select_command__(['monitor'])
            self.is_monitoring = True
            # Start counting the time
            start_time = time.time()
            # Read information from the device
            num_read_bytes = 0
            now = time.time()
            while now - start_time < duration:
                num_read_bytes += self.device.ReadFromBlockPipeOut(self.OUTPIPE_ENDPOINT, self.USB_BLOCK_SIZE, buffer)
                if num_read_bytes < 0:
                    self.logger.error(f'Error at monitor: {ok.okCFrontPanel_GetErrorString(num_read_bytes)}')
                    return None
                # Concatenate the buffer with the global buffer
                global_buffer = np.concatenate((global_buffer, buffer))
                # If the number of read bytes is greater than the buffer length, break the loop
                if num_read_bytes >= total_buffer_length:
                    break
                now = time.time()

            # Disable capture function
            self.__select_command__(['idle'])
            self.is_monitoring = False
            # Save the global buffer in the buffer variable
            buffer = global_buffer

        # If the number of spikes and the duration are not defined, read the information from the device until the is_monitoring
        # flag is False. This functionality is implemented in the method monitor_forever()
        else:
            # Fix the buffer length to the USB_BLOCK_SIZE
            buffer_length = self.USB_BLOCK_SIZE
            buffer = bytearray(buffer_length)
            buffer = np.array(buffer, dtype=np.uint8)
            self.logger.info(f'Buffer length: {buffer_length}')
            # Create a global buffer to concatenate all information read from the device that is captured in the buffer array
            global_buffer = bytearray()
            global_buffer = np.array(global_buffer, dtype=np.uint8)
            # Enable capture function
            self.__select_command__(['monitor'])
            self.is_monitoring = True
            # Start counting the time
            start_time = time.time()
            # Read information from the device
            num_read_bytes = 0
            while self.is_monitoring:
                num_read_bytes += self.device.ReadFromBlockPipeOut(self.OUTPIPE_ENDPOINT, self.USB_BLOCK_SIZE, buffer)
                if num_read_bytes < 0:
                    self.logger.error(f'Error at monitor: {ok.okCFrontPanel_GetErrorString(num_read_bytes)}')
                    return None
                # Concatenate the buffer with the global buffer
                global_buffer = np.concatenate((global_buffer, buffer))
            # Stop counting the time
            now = time.time()
            # Disable capture function
            self.__select_command__(['idle'])
            self.is_monitoring = False
            # Save the global buffer in the buffer variable
            buffer = global_buffer
            # Clean the self.spikes attribute
            self.spikes = None

        self.logger.info(f'Monitoring duration: {now-start_time} seconds') 
        self.logger.info(f'Number of spikes: {int(num_read_bytes/self.SPIKE_SIZE_BYTES)}. Number of read bytes: {num_read_bytes}')

        try:
            # Split the information into the right spike input struct
            for b_idx in range(0, num_read_bytes, self.SPIKE_SIZE_BYTES):  # Each spike has a ts(4 bytes) and an addr(4bytes)
                ts = int.from_bytes(buffer[b_idx:b_idx+4], byteorder='little', signed=False)
                addr = int.from_bytes(buffer[b_idx+4:b_idx+8], byteorder='little', signed=False)

                # If the timestamp is 0 or the address is 0, the event is null and it is not saved
                if ts == 0 or addr == 0:
                    continue
                # Check is ts is the maximum value of a 32-bit integer. This is a timestamp overflow event.
                if ts == 0xFFFFFFFF:
                    self.logger.warning(f'Timestamp overflow event at address {addr}')
                    continue
                # Get the input index that is encoded in the 2 most significant bits.
                input_idx = (addr & 0xC000_0000) >> 30
                # Save the global timestamp and the address in the spike list corresponding with the input
                spikes[input_idx].timestamps.append(self.global_timestamp + ts)
                spikes[input_idx].addresses.append(addr & 0x3FFFFFFF) # Remove the input index from the address
                # Update the global timestamp
                self.global_timestamp += ts
    
        except IndexError as e:
            self.logger.error(f'Error at monitor: {e}')

        # Return the list of spikes
        # If the monitor_forever() method is used, the spikes are saved in the self.spikes attribute
        self.spikes = spikes
        return spikes

    
    def monitor_forever(self, inputs=[]):
        """
        Get the information captured by the tool (ECU) and save it in different spikes structs depending on the selected
        inputs. First, the events/spikes are collected in the IMU, next are captured in the ECU putting a timestamp and 
        finally, events/spikes are sent from CU to PC by USB port. The information is read from the device while the flag
        is_monitoring is True. The information is saved in a list of spikes structs. Each struct contains the timestamps and
        addresses of the events/spikes captured in the same input:
        - Input 0: Port A
        - Input 1: Port B
        - Input 2: Node Out

        :return: spikes: List of captured spikes (ts, addr)
        """
        self.logger.info('Monitoring forever started in a new thread') 
        self.monitor_thread = threading.Thread(target=self.monitor, args=(inputs, None, None))
        self.monitor_thread.start()


    def monitor_stop(self):
        """
        Stop the monitoring forever thread.
        
        :return:
        """
        self.logger.info('Monitoring forever stopped')
        self.is_monitoring = False
        self.monitor_thread.join()
        return self.spikes


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
        # Set the value of the register
        self.device.SetWireInValue(self.INWIRE_CONFIG_ENDPOINT, address_value)
        self.device.UpdateWireIns()
        # Set the command to idle
        self.__select_command__(['idle'])
        # Set the value of the register to zero
        self.device.SetWireInValue(self.INWIRE_CONFIG_ENDPOINT, 0x00000000)
        self.device.UpdateWireIns()
        self.logger.info(f'Configuring {device} with address {hex(register_address)} and value {hex(register_value)}')
        # Wait 10ms to ensure that the register is set
        time.sleep(0.01)
        return 0

        