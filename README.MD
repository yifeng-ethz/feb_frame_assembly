# **Description**

This IP is generates the Mu3e standard data frame given input of sub-frames.

# **Notes**

* It acts as the CDC stage for transfer from data path clock (125 MHz) to the tranceiver clock (156.25 MHz). 

* It pack upstream subframes packet (containing subheaders and hits if any) into Mu3e main frame. It follows a non-working-conserving arbitration rule that grant the smallest subheader and assert blocking while lane emply. This arbitration rule guarantees the absolute sorting of subframes in mono-increasing subframe timestamp ([11:4]). 

* The output of this IP is the Mu3e Main Data Frame (packetized).

![Data Frame!](./frame_mod.png "Data Frame")
