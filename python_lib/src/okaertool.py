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

import ok.ok as ok
import logging as log
from collections import Counter
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import sys
import io

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


class Okaertool:
    """
    Class that manages the OpalKelly USB 3.0 board. This class interfaces with the okaertool FPGA module to send and
    receive information to and from the tool

    Attributes:
        bit_file (string): Path to the FPGA .bit programming file
    """
    OUTPIPE_ENDPOINT = 0xA0
    INPIPE_ENDPOINT = 0x93
    INWIRE_COMMAND_ENDPOINT = 0x00
    INWIRE_SELINPUT_ENDPOINT = 0x01
    NUM_INPUTS = 3
    USB_BLOCK_SIZE = 1024

    def __init__(self, bit_file):
        self.device = ok.okCFrontPanel()
        self.device_count = self.device.GetDeviceCount()
        self.id = self.device.GetDeviceID()
        self.bit_file_path = bit_file
        self.inputs = []
        self.global_timestamp = 0

    def reset_timestamp(self):
        """
        Reset self.global_timestamp
        """
        self.global_timestamp = 0

    def init(self):
        """
        Open the USB device and configure the FPGA using the bit file define in the constructor.
        putting a timestamp to each event.
        :return:
        """
        error = self.device.OpenBySerial("")
        if error != 0:  # No error
            log.error(f"Error at okaertool initialization: {ok.okCFrontPanel_GetErrorString(error)}")
            exit(-1)
        error = self.device.ConfigureFPGA(self.bit_file_path)
        if error != 0:  # No error
            log.error(f"Error at okaertool FPGA configuration: {ok.okCFrontPanel_GetErrorString(error)}")
            exit(-1)
        log.info("okaertool initialized")

    def select_inputs(self, inputs=[]):
        """
        Select the inputs that the user wants to work with. These inputs are captured under the same timestamp domain
        :param inputs: List of input ports to capture information. Possible values: 'Port_A' 'Port_B' 'Node_out'
        :return:
        """
        selinput_endpoint_value = 0x00000000
        if len(inputs) != 0:
            if 'Port_A' in inputs:
                selinput_endpoint_value += 1  # Set 1 in the bit number 0
            if 'Port_B' in inputs:
                selinput_endpoint_value += 2  # Set 1 in the bit number 1
            if 'Node_out' in inputs:
                selinput_endpoint_value += 4  # Set 1 in the bit number 2

        print('Valor entrada PIN', selinput_endpoint_value)

        self.device.SetWireInValue(self.INWIRE_SELINPUT_ENDPOINT, selinput_endpoint_value)
        self.device.UpdateWireIns()

    def select_command(self, command=[]):
        """
        Select the commands that the user wants to work with.
        :param command: List of commands. Possible values: 'idle' 'monitor' 'bypass' 'monitor_bypass' 'sequencer'
        :return:
        """

        command_endpoint_value = 0x00000000
        if len(command) != 0:
            if 'idle' in command:
                command_endpoint_value += 0  # Set 0 in the bit number 0
            if 'monitor' in command:
                command_endpoint_value += 1  # Set 1 in the bit number 0
            if 'bypass' in command:
                command_endpoint_value += 2  # Set 1 in the bit number 1
            if 'monitor_bypass' in command:
                command_endpoint_value += 3  # Set 1 in the bit number 0 and 1
            if 'sequencer' in command:
                command_endpoint_value += 4  # Set 1 in the bit number 2

        print('Valor command:', command_endpoint_value)

        self.device.SetWireInValue(self.INWIRE_COMMAND_ENDPOINT, command_endpoint_value)
        self.device.UpdateWireIns()

    def monitor(self, buffer_length, events):
        """
        Get the information captured by the tool (ECU) and save it in different spikes structs depending on the selected
        inputs. First, the events/spikes are collected in the IMU, next are captured in the ECU and finally, events
        /spikes are sent from CU to PC by USB port.

        :param buffer_length: Number of bytes to be read from the tool
        :param events: Number of events collected with non-zero address and timestamp other than /xff/xff/xff/xff
        :return: spikes: List of captured spikes (ts, addr)
        """
        # Enable capture function
        self.select_command('monitor')
        # Define a list of spikes (ts, addr) to collect spikes from all inputs
        spikes = [Spikes() for x in range(self.NUM_INPUTS)]
        # Read information from the device
        buffer = bytearray(buffer_length)
        buffer = np.array(buffer, dtype=np.uint8)
        num_read_bytes = self.device.ReadFromBlockPipeOut(self.OUTPIPE_ENDPOINT, self.USB_BLOCK_SIZE, buffer)
        # Int type buffer
        buffer_list = list(buffer)
        # Buffer binary file
        # np.save(r"C:\Users\PabloSQ_2023\PycharmProjects\Okaertool_local\okaertool-master\okaertool-master\python_lib\src", buffer)
        # Buffer text file

        # np.savetxt('buffer_text', buffer, fmt='%x')

        # Open file in binary write mode
        binary_file = open("my_file.txt", "wb")

        # Write bytes to file
        binary_file.write(buffer)


        # Numpy Matrix with the 8 bytes of AER protocol
        Matrix_Runner_z = 0
        n_filas = int(((num_read_bytes)/8))
        n_columnas = 8  # Number of bytes of AER protocol: 4 for timestamp (ts) and 4 for address (addr)
        np_matrix = np.zeros(shape=(n_filas, n_columnas))
        for Matrix_Runner_x in range(n_filas):
                for Matrix_Runner_y in range(7, -1, -1):
                    np_matrix[Matrix_Runner_x][Matrix_Runner_y] = buffer[Matrix_Runner_z]
                    Matrix_Runner_z += 1

        # Counter used for counting goods events and debugging
        q = 1
        # Empty lists of address and timestamp datas
        addr_histogram = []
        ts_histogram = []
        # Loop in the collect data and split the information into the right spike input struct
        for b_idx in range(0, num_read_bytes, 8):  # Each spike has a ts(4 bytes) and an addr(4bytes)
            # Example of this range(0, num_read_bytes, 8) with spikes = 1 Mb and by USB_BLOCK_SIZE = 1024 bytes -->
            # Number of iterations: (1048568 / 8) + 1 = 131072
            try:
                print('-------------Índice b_indx-------------', b_idx)
                ts = int.from_bytes(buffer[b_idx:b_idx+3], byteorder='little', signed=False)
                print('Timestamp ts', ts)
                addr = int.from_bytes(buffer[b_idx+4:b_idx+7], byteorder='little', signed=False)
                print('addr', addr)

                if (ts == 0 and addr == 0) or ts == 4294967295:  # Null value. Used to fill de USB packet and 4294967295 = /xff/xff/xff/xff
                    continue
                else:
                    pass

                ts_histogram.append(ts)
                addr_histogram.append(addr)
                q += 1
                print('Iteración con timestamp distinto de 4294967295 y dirección distinta de 0. Número =', q)
                # Increase the global timestamp using the differential timestamp received
                self.global_timestamp += ts
                print('global_timestamp', self.global_timestamp)
                # Get the input index that is encoded in the 3 most significant bits.
                input_idx = (addr & 0xE000_0000) >> 29
                # Save the global timestamp and the address in the spike list corresponding with the input
                spikes[input_idx].timestamps.append(self.global_timestamp)
                print('Timestamp añadido a', spikes[input_idx])
                spikes[input_idx].addresses.append(addr)
                print('Dirección añadida a', spikes[input_idx])
                # Condition to take the number of events selected
                if q <= events:
                    pass
                else:
                    break
            # Except used to neglect the IndexError
            except IndexError as e:
                print('ERROR', e)
        # Disable capture function
        self.device.SetWireInValue(self.INWIRE_COMMAND_ENDPOINT, 0x00000000)
        self.device.UpdateWireIns()
        print('--------------------------')
        print('Número de eventos correctos =', q)
        null_events = (num_read_bytes/8)-q
        print('Número de eventos nulos =', null_events)
        print('spikes', spikes)
        print('Número de elementos de TimeStamp', len(ts_histogram))
        print('Número de elementos de Direcciones', len(addr_histogram))
        # Counting how many times appears the elements of timestamp and addresses creating a dictionary
        recounted_ts = Counter(ts_histogram)
        recounted_addr = Counter(addr_histogram)
        # Separating the keys and values from dictionaries for timestamp and address and creating lists
        ts_keys = list(recounted_ts.keys())
        ts_values = list(recounted_ts.values())
        addr_keys = list(recounted_addr.keys())
        addr_values = list(recounted_addr.values())
        # Transform in string the keys from dictionaries
        ts_keys_string = [str(i) for i in ts_keys]
        addr_keys_string = [str(i) for i in addr_keys]

        # Data Byte Ordering

        in_two_bits_histogram = []
        null_bit_histogram = []
        addr_x_histogram = []
        addr_y_histogram = []
        pol_histogram = []

        i = 0
        j = 2
        k = 3

        try:
            for u in range(n_filas):

                n_binary_in = bin(int(float(np_matrix[u, i]))).lstrip('0b').zfill(8)
                in_two_bits = str(n_binary_in[0:1])
                in_two_bits_histogram.append(in_two_bits)

                n_binary_x = bin(int(float(np_matrix[u, j]))).lstrip('0b').zfill(8)
                null_bit = str(n_binary_x[0])
                addr_x = int(str(n_binary_x[1:8]), 2)
                null_bit_histogram.append(null_bit)
                addr_x_histogram.append(addr_x)

                n_binary_y = bin(int(float(np_matrix[u, k]))).lstrip('0b').zfill(8)
                pol = str(n_binary_y[-1])
                addr_y = int(str(n_binary_y[0:7]), 2)
                pol_histogram.append(pol)
                addr_y_histogram.append(addr_y)

        except IndexError as e:
            print('ERROR', e)

        # Creating a 2-dimensional array with the two addresses x and y

        data_histogram_np = np.array([addr_x_histogram, addr_y_histogram])

        data_histogram = list(zip(addr_x_histogram, addr_y_histogram))

        dictionary_xy = Counter(data_histogram)

        keys_xy = list(dictionary_xy.keys())
        counts_xy = list(dictionary_xy.values())
        counts_xy_string = [str(i) for i in counts_xy]
        keys_xy_string = [str(i) for i in keys_xy]

        # # Plotting Histogram

        # x_addr = np.array(addr_x_histogram)
        # y_addr = np.array(addr_y_histogram)
        # try:
        #     plt.hist2d(x_addr, y_addr, bins=16384, cmap='viridis')
        #     plt.colorbar()
        #     plt.xlabel('X')
        #     plt.ylabel('Y')
        #     plt.title('2-D Histogram')
        # except TypeError as e:
        #     print('ERROR', e)

        # # Plotting bar figures
        # -----------------------------------------------------------------------------------------
        # df = pd.DataFrame({'addr_key': keys_xy_string, 'val_addr': counts_xy_string })
        # df.plot.bar(x='addr_key', y='val_addr', rot=0)

        # df = pd.DataFrame({'addr_key': addr_keys_string, 'val_addr': addr_values})
        # df.plot.bar(x='addr_key', y='val_addr', rot=0)
        # -----------------------------------------------------------------------------------------

        # # 3D graph
        #
        # x = list(np.array(addr_x_histogram))
        # y = list(np.array(addr_y_histogram))
        # z = list(np.array(pol_histogram))
        #
        # ax = plt.figure().add_subplot(projection='3d')
        # ax.scatter(x, y, z)
        #
        # plt.show()

        return spikes  # spikes

    def bypass(self):
        """
        AER data is bypassed from IMU directly into OSU. This command can be used alongside "monitor".
        """
        # Enable Merge (or Passthrough) function
        self.select_command('bypass')

    def sequencer(self, buffer_length, file):
        """
        First, the events/spikes are sent from PC to CU by USB and next are sent to the OSU to obtain them through the
        AER output.

        :param file: txt file containing AER data in TS/ADDR format for the OSU to sequence
        :return:
        """
        #file = "my_file.txt"

        buf = bytearray(buffer_length*1024)  # Create a buffer of 1024 bytes
        buf = np.array(buf, dtype=np.uint8)
        with io.open(file, "rb") as fp:
            size = fp.readinto(buf)  # Read binary data into the buffer


        self.select_command('sequencer')

        self.device.WriteToBlockPipeIn(self.INPIPE_ENDPOINT, self.USB_BLOCK_SIZE, buf)

