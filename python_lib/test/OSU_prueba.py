from io import BytesIO
import struct
import io
import numpy as np

# Create a BytesIO buffer with initial binary data
bio = BytesIO(b"some initial binary data: \x00\x01")

# Now you can read from or write to this buffer as needed

filename = "my_file.txt"
filename2 = "Hand.dat"

rows= 512
columns=8
columns2=6

buf = bytearray(rows*columns)  # Create a buffer of 1024 bytes
buf = np.array(buf, dtype=np.uint8)
with io.open(filename, "rb") as fp:
    size = fp.readinto(buf)  # Read binary data into the buffer
Matrix_Runner_z = 0
np_matrix = np.zeros(shape=(rows, columns))
for Matrix_Runner_x in range(rows):
        for Matrix_Runner_y in range(7, -1, -1):
            np_matrix[Matrix_Runner_x][Matrix_Runner_y] = buf[Matrix_Runner_z]
            Matrix_Runner_z += 1

buf2 = bytearray(rows*columns2)  # Create a buffer of 1024 bytes
buf2 = np.array(buf2, dtype=np.uint8)
with io.open(filename2, "rb") as fp:
    size = fp.readinto(buf2)  # Read binary data into the buffer
Matrix_Runner_z = 0
np_matrix2 = np.zeros(shape=(rows, columns2))
for Matrix_Runner_x in range(rows):
        for Matrix_Runner_y in range(columns2):
            np_matrix2[Matrix_Runner_x][Matrix_Runner_y] = buf2[Matrix_Runner_z]
            Matrix_Runner_z += 1




#matrx = np.frombuffer(buf, dtype=np.uint8, count=-8, offset=0, like=None)
print(np_matrix)
print(np_matrix2)