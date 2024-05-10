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
# device.OpenBySerial("1529000BQK")         # Si NO se descomenta, falla la conexión USB con la OpalKelly
serial_number = device.GetSerialNumber()
print('Número de Serie', serial_number)
device_count = device.GetDeviceCount()
print('device_count =', device_count)
for idx in range(device_count):
    print(f"Device[{idx}] Model: {device.GetDeviceListModel(idx)}")

BIT_FILE = r"C:\Users\PabloSQ_2023\PycharmProjects\Okaertool_local\OKT_TOP 32 ns\okt_top.bit"
opal = okt.Okaertool(bit_file=BIT_FILE)
opal.init()
opal.select_inputs(inputs=['Port_A'])
spikes = opal.monitor(buffer_length=(1*1024*1024), events=17000000)
print('--------------------------')
time_elapsed = (time.perf_counter() - time_start)
print('Tiempo Final de Simulación', time_elapsed)

# Plots.spikegram(spikes[0], settings=SETTINGS)
