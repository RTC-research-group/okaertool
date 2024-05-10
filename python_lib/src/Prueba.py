import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

np.random.seed(1)
x = np.random.normal(size = 10000)
print(type(x))
print(np.size(x))
y = x + np.random.normal(size = 10000)

# addr_x_histogram = list(np.random.rand(128))
# x = np.array(addr_x_histogram)
# print(type(x))
# print(np.size(x))
#
# addr_y_histogram = list(np.random.rand(128))
# y = np.array([addr_y_histogram])
#
#
plt.hist2d(x, y, cmap='viridis')
plt.colorbar()
plt.xlabel('X')
plt.ylabel('Y')
plt.title('2-D Histogram')

plt.show()