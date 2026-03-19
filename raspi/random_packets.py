from scapy.all import Ether, IP, TCP, sendp
import random
import sys
import os

IFACE = "eth0"

print(f"--- Sending random packets continuously on {IFACE} ---")

from scapy.all import Ether, IP, TCP
import random
import os

def generate_packet():
    return (
        Ether(
            dst="ff:ff:ff:ff:ff:ff",
            src="02:%02x:%02x:%02x:%02x:%02x" % tuple(random.randint(0, 255) for _ in range(5))
        ) /
        IP(
            src=f"192.168.{random.randint(0,255)}.{random.randint(1,254)}",
            dst=f"192.168.{random.randint(0,255)}.{random.randint(1,254)}"
        ) /
        TCP(
            sport=random.randint(1024, 65535),
            dport=random.choice([80, 443, 22, 8080]),
            flags=random.choice(["S", "PA", "FA"])
        ) /
        os.urandom(94)  # ✅ fixed payload length
    )

try:
    while True:
        batch = [generate_packet() for _ in range(100)]
        print(f"Sending batch of 100 random packets...")
        print(f"Packet details:")
        for pkt in batch[:5]:  # Print details of the first 5 packets
            print(f"  {pkt[IP].src} -> {pkt[IP].dst} | TCP sport: {pkt[TCP].sport} dport: {pkt[TCP].dport} flags: {pkt[TCP].flags}")
            print(f"  Payload size: {len(pkt[TCP].payload)} bytes")
        sendp(batch, iface=IFACE, verbose=False)

except KeyboardInterrupt:
    print("\nStream stopped.")
    sys.exit()