import random

rows = 4
cols = 4
w_bit = 8
x_bit = 8
y_bit = 32 

def to_hex(val, width):
    return f"{val & ((1 << width) - 1):0{width // 4}X}"

W = [[random.randint(1, 9) for _ in range(cols)] for _ in range(rows)]
X = [[random.randint(1, 5) for _ in range(cols)] for _ in range(rows)]

Y = [[0]*cols for _ in range(rows)]
for r in range(rows):
    for c in range(cols):
        acc = 0
        for k in range(cols):
            acc += X[r][k] * W[k][c]
        Y[r][c] = acc

with open("weights.txt", "w") as f:
    hex_str = ""
    for c in range(cols-1, -1, -1):
        for r in range(rows-1, -1, -1):
            val = W[r][c]
            hex_str += f"{val:02X}" 
    f.write(hex_str + "\n")

with open("inputs.txt", "w") as f:
    for r in range(rows):
        hex_str = ""
        for c in range(cols-1, -1, -1):
            val = X[r][c]
            hex_str += f"{val:02X}"
        f.write(hex_str + "\n")

with open("output.txt", "w") as f:
    hex_str = ""
    for c in range(cols):      
        for r in range(rows-1, -1, -1):
            val = Y[r][c]
            hex_str += f"{val:02X}"
            
    f.write(hex_str + "\n")