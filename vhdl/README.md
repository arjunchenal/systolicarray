## Implementations

### `systolic_array_mac_parallel/`
systolic array implementation using fully parallel MAC units.
- Parallel multiplication and accumulation

### `systolic_array_mac_serial/`
Bit serial systolic array MAC implementation.
- Bit serial multiplication of activations
- Reduced hardware cost compared to the parallel design

### `systolic_array_mac_serial_compression/`
This implementation optimizes the systolic array for Sparse Neural networks by combining bit-serial computation with a compressed weight format.
Here, each Processing elements contains 4 macunit to maximize the throughput by interleaving multiple MAC operations within a single processing element.

