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

    def monitor(self, buffer_length, events):
        """
        Get the information captured by the tool and save it in different spikes structs depending on the selected
        inputs
        :param buffer_length: Number of bytes to be read from the tool
        :param events: Number of events collected with non-zero address and timestamp other than /xff/xff/xff/xff
        :return: spikes: List of captured spikes (ts, addr)
        """
        # Enable capture function
        self.device.SetWireInValue(self.INWIRE_COMMAND_ENDPOINT, 0x00000001)
        self.device.UpdateWireIns()
        # Define a list of spikes (ts, addr) to collect spikes from all inputs
        spikes = [Spikes() for x in range(self.NUM_INPUTS)]
        # Read information from the device
        buffer = bytearray(buffer_length)
        num_read_bytes = self.device.ReadFromBlockPipeOut(self.OUTPIPE_ENDPOINT, self.USB_BLOCK_SIZE, buffer)
        print('Numero de Bytes Leídos', num_read_bytes)
        buffer_list = list(buffer)
        # Counter used for counting goods events and debugging
        q = 1
        # Empty lists of address and timestamp datas
        addr_histogram = []
        ts_histogram = []
        # Loop in the collect data and split the information into the right spike input struct
        for b_idx in range(0, num_read_bytes, 8):  # Each spike is a ts(4 bytes) and addr(4bytes)
            # Example of this range(0, num_read_bytes, 8) with spikes = 1 Mb and by USB_BLOCK_SIZE = 1024 bytes -->
            # Number of iterations: 1048568 / 8 = 131071
            try:
                print('-------------Índice b_indx-------------', b_idx)
                ts = int.from_bytes(buffer[b_idx:b_idx+4], byteorder='big', signed=False)
                print('Timestamp ts', ts)
                addr = int.from_bytes(buffer[b_idx+4:b_idx+8], byteorder='big', signed=False)
                print('addr', addr)
                # ----------------------------------------------------------------------
                # if ts == 0 and addr == 0:  # Null value. Used to fill de USB packet
                #     continue
                # ----------------------------------------------------------------------
                if ts == 4294967295 or addr == 0:           # 4294967295 = /xff/xff/xff/xff
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

        # # Creating series from the lists
        # freq_series_ts = pd.Series(ts_values)
        # freq_series_addr = pd.Series(addr_values)

        # ts_keys_numbers = []
        # for j in range(0, len(ts_keys)):
        #     ts_keys_numbers.append(j)
        #
        # addr_keys_numbers = []
        # for j in range(0, len(addr_keys)):
        #     addr_keys_numbers.append(j)


        # Plotting bar figures

        df = pd.DataFrame({'ts_key': ts_keys_string, 'val_ts': ts_values})
        df.plot.bar(x='ts_key', y='val_ts', rot=0)

        df = pd.DataFrame({'addr_key': addr_keys_string, 'val_addr': addr_values})
        df.plot.bar(x='addr_key', y='val_addr', rot=0)

        # fig1 = plt.figure(figsize=(10, 10))
        # fig1.autofmt_xdate()
        # plt.xlim(min(ts_keys), max(ts_keys))
        # plt.ylim(min(ts_values), max(ts_values))
        # ax = freq_series_ts.plot(kind="bar")
        # ax.set_title("Time Stamps")
        # ax.set_xlabel("Ts Value")
        # ax.set_ylabel("Frequency Value")
        # # ax.set_xticklabels(ts_keys_numbers)
        #
        # fig2 = plt.figure(figsize=(10, 10))
        # fig2.autofmt_xdate()
        # plt.xlim(min(addr_keys), max(addr_keys))
        # plt.ylim(min(addr_values), max(addr_values))
        # ax = freq_series_addr.plot(kind="bar")
        # ax.set_title("Addresses")
        # ax.set_xlabel("Addr Value")
        # ax.set_ylabel("Frequency Value")
        # # ax.set_xticklabels(addr_keys_numbers)

        plt.show()

        return spikes  # spikes