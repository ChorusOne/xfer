# XFER

Xfer is a utility to allow out-of-band sending of arbitrary data, using animated GIF QR-codes and webcams.

## Installation

1. Clone the repository
2. Run `pip install -r requirements.txt` (may be `pip3`, in place of `pip`, depending on your OS).

## Workflow
The workflow looks something like this:

1. Alice runs Xfer on their local machine, as such: `cat 'This is a message to send' | python3 xfer.py write --outfile send.gif`
2. Alice opens `send.gif` and records the output on a mobile device. 
3. Alice send a message, via a third party service, such as Signal, to Bob.
4. Bob runs `python3 xfer.py read` on his laptop.
5. Bob plays the recording of the animated gif, and captures the video on their laptop's webcam.
6. Once Xfer has captured all the individual frames, it will output the original message on Bob's screen.
 
## How it works

1. `xfer write` breaks the source message down into chunks. By default these are 256 byte chunks. This is not supported as a flag, because the relationship between chunk size and QR code dimensions are not clear. The values can be seen at the top of the `xfer` script, but should not be changed unless you know what you are doing!
2. Each chunk is then encoded to a static QR code, with it's frame number for reassembly. 
3. A keyframe is added to the start of the sequence, to instruct the receiving application on the number of frames it should expect.
4. The collection of static images is then compiled into an animated GIF.

5. On the receiving side, a loop watches for and decodes QR-codes.
6. The keyframe, which may arrive out of sequence, determines how many unique frames are expected.
7. Having received all frames, the loop will exit and the data packet is reassembled.

## Limitations

- Xfer was not written to be secure. It can be used as part of a secure workflow, if PGP keys are shared beforehand and the data transmitted is encrypted.
- Xfer does not compress data; repeated data will be encoded as is. 

## Future work

- (optionally) gzipping, or otherwise compressing the original data will reduce the amount of data required to be transmitted.
- Checksum of the source data, and storing this value in the keyframe, will allow us to verify the received data has not been tampered with or corrupt in transit.
