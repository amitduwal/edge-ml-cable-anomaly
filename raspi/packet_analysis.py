from scapy.all import *
import random
import binascii

# 1. Create the Packet
pkt = (
    Ether(dst="ff:ff:ff:ff:ff:ff") /
    IP(src="192.168.0.2", dst="192.168.0.1") /
    TCP(sport=random.randint(1024, 65535), dport=80, flags="PA") /
    (b"X" * 100)
)

# 2. Get the Layer 2/3/4 Data (The "MAC Client Data")
data_bytes = bytes(pkt)

# 3. Generate Physical Layer & Trailer components
preamble = b'\xaa' * 7          # 7 bytes of 10101010
sfd = b'\xab'                   # 1 byte of 10101011
fcs = struct.pack("<I", binascii.crc32(data_bytes) & 0xffffffff) # 4-byte CRC

# 4. Construct the Full Wire Frame
full_frame = preamble + sfd + data_bytes + fcs

def to_bits(byte_segment):
    return "".join(format(b, '08b') for b in byte_segment)

# 5. Display the Analysis
print(f"{'SECTION':<15} | {'BITS'}")
print("-" * 80)
print(f"{'Preamble':<15} | {to_bits(preamble)}")
print(f"{'SFD':<15} | {to_bits(sfd)}")
print(f"{'Ethernet Hdr':<15} | {to_bits(data_bytes[0:14])}")
print(f"{'IP Header':<15} | {to_bits(data_bytes[14:34])}")
print(f"{'TCP Header':<15} | {to_bits(data_bytes[34:54])}")
print(f"{'Payload (X100)':<15} | {to_bits(data_bytes[54:64])}... [truncated]")
print(f"{'FCS (CRC32)':<15} | {to_bits(fcs)}")
print("-" * 80)

total_bits = len(full_frame) * 8
print(f"Total Bits on Wire: {total_bits}")