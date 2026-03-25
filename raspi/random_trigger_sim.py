from scapy.all import Ether, IP, TCP, sendp
from gpiozero import OutputDevice
import random
import os
import sys
import time

# --- Configuration ---
IFACE = "eth0"
TRIGGER_PIN = 17

# Initialize GPIO
trigger = OutputDevice(TRIGGER_PIN)
trigger.off()

def generate_packet():
    """Generates a single randomized packet."""
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
        os.urandom(94)
    )

print(f"--- Sending individual triggered packets on {IFACE} ---")

count = 0

try:
    while count < 100:  # Limit to 1000 packets for testing
        # 1. Create the packet first (don't waste trigger time on generation)
        pkt = generate_packet()

        # 2. 🔴 Trigger HIGH
        trigger.on()

        # 3. 📡 Send EXACTLY one packet
        sendp(pkt, iface=IFACE, verbose=False)

        # 4. 🔵 Trigger LOW
        trigger.off()

        # 5. Optional: Small gap so the scope can reset/trigger again
        time.sleep(1)
        count += 1

except KeyboardInterrupt:
    print(f"\nStream stopped after {count} packets.")
finally:
    print(f"\n {count} packets.")
    trigger.off()
    sys.exit()