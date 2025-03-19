import ok.ok as ok
import okaertool as okt
from pyNAVIS import *
import time

time_start = time.perf_counter()


# 64 Channels,  Stereo, 16 bits address, recorded using jAER
# NUM_CHANNELS = 64
# BIN_SIZE = 20000

# pyNAVIS settings
# SETTINGS = MainSettings(num_channels=NUM_CHANNELS, mono_stereo=1, on_off_both=1, address_size=2, ts_tick=1,
#                         bin_size=BIN_SIZE)


device = ok.okCFrontPanel()                 # Número de Serie de la OpalKelly: 1529000BQK
#device.OpenBySerial("1529000BQK")         # Si NO se descomenta, falla la conexión USB con la OpalKelly
serial_number = device.GetSerialNumber()
print('Número de Serie', serial_number)
device_count = device.GetDeviceCount()
print('device_count =', device_count)
for idx in range(device_count):
    print(f"Device[{idx}] Model: {device.GetDeviceListModel(idx)}")

BIT_FILE = r"C:\Users\PabloSQ_2023\PycharmProjects\Okaertool_local\okaertool-master\okaertool-master\okt_top_debug.bit"
SEQ_FILE = r"C:\Users\PabloSQ_2023\PycharmProjects\Okaertool_local\okaertool-master\okaertool-master\my_file_sequenced_B"
opal = okt.Okaertool(bit_file=BIT_FILE)
opal.init()
#opal.device.OpenBySerial("") #---ILA DEBUGGING---
opal.select_command('idle')
opal.select_inputs(inputs=['Port_A'])
#opal.bypass(inputs=['Port_A'])
#time.sleep(2.5)
#opal.select_command('bypass')

#opal.select_inputs(inputs=['Port_A'])
#opal.select_command('monitor')

#spikes = opal.monitor(buffer_length=(1024*1024*1), events=200000000, file=SEQ_FILE)
#print('--------------------------')
#time_elapsed = (time.perf_counter() - time_start)
#print('Tiempo Final de Simulación', time_elapsed)
#print('--------------------------')

#opal.select_inputs(inputs=['Port_A'])
opal.debug_file(r'C:\Users\PabloSQ_2023\PycharmProjects\Okaertool_local\okaertool-master\okaertool-master\my_file_sequenced_A',buffer_length=(1024*64))
#opal.select_command('idle')
opal.debug(buffer_length=(1024*64), num_transfers=16)
#opal.sequencer(SEQ_FILE)
# Plots.spikegram(spikes[0], settings=SETTINGS)
