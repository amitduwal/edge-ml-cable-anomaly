from scapy.all import Ether, IP, TCP, sendp
import random
import sys

IFACE = "eth0"

print(f"--- Initializing continuous stream on {IFACE} ---")

# 1. Pre-generate a list of packets to avoid overhead during the loop
packet_batch = []
print("Generating packet batch...")
for _ in range(100):
    pkt = (
        Ether(dst="ff:ff:ff:ff:ff:ff") /
        IP(src="192.168.0.2", dst="192.168.0.1") /
        TCP(sport=random.randint(1024, 65535), dport=80, flags="PA") /
        (b"X" * 100)
    )
    packet_batch.append(pkt)

print("Starting continuous loop. Press Ctrl+C to stop.")

# 2. Loop indefinitely
try:
    while True:
        # We send the whole batch at once to reduce Python function call overhead
        sendp(packet_batch, iface=IFACE, verbose=False)
        # No time.sleep() = Maximum speed
except KeyboardInterrupt:
    print("\nStream stopped.")
    sys.exit()