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
    digits_per_chunk = (rows * w_bit) // 4  

    for c in range(cols-1, -1, -1):
        row_val = 0
        for r in range(rows-1, -1, -1):
            val = W[r][c]
            row_val = (row_val << w_bit) | (val & ((1 << w_bit) - 1))

        chunk = f"{row_val:0{digits_per_chunk}X}"
        hex_str += chunk

    f.write(hex_str + "\n")

with open("inputs.txt", "w") as f:
    digits_in_line = (cols * x_bit) // 4

    for r in range(rows):
        row_val = 0
        for c in range(cols-1, -1, -1):
            val = X[r][c]
            row_val = (row_val << x_bit) | (val & ((1 << x_bit) - 1))
        f.write(f"{row_val:0{digits_in_line}X}\n")

    for _ in range(rows):
        f.write(f"{0:0{digits_in_line}X}\n")


with open("output.txt", "w") as f:
    for vec_idx in range(rows):
        hex_line = ""
        for r in range(rows-1, -1, -1):
            val = Y[vec_idx][r]
            hex_line += f"{val & ((1 << y_bit) - 1):0{y_bit//4}X}"
        f.write(hex_line + "\n")
