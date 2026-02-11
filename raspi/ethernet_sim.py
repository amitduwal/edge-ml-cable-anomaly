from scapy.all import Ether, IP, TCP, sendp
import random
import time

IFACE = "eth0"

while True:
    burst = random.randint(20, 100)

    for _ in range(burst):
        pkt = (
            Ether(dst="ff:ff:ff:ff:ff:ff") /
            IP(src="192.168.0.2", dst="192.168.0.1") /
            TCP(sport=random.randint(1024, 65535),
                dport=80,
                flags="PA") /
            ("X" * random.randint(40, 1400))
        )

        sendp(pkt, iface=IFACE, verbose=False)
        time.sleep(random.uniform(0.0005, 0.005))

    # time.sleep(random.uniform(0.2, 2))