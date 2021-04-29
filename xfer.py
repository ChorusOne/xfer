#!/usr/bin/env python3

import click
import cv2
import qrcode
import pyzbar.pyzbar as pyzbar
from contextlib import contextmanager
from PIL import Image
import sys
from math import log2, floor
import json
import logging

## tweakable params
CHUNK_SIZE=256
PAYLOAD_SIZE=537

## version
__MAJOR__ = 0
__MINOR__ = 0
__PATCH__ = 1
__VERSION__ = "{}.{}.{}".format(__MAJOR__, __MINOR__, __PATCH__)

def create_qr(data: bytes,
        err_correction: int = qrcode.constants.ERROR_CORRECT_M,
        box_size: int = 5, border: int = 4):
    """
    Create a QR code and return Pillow image object for it.
    """
    qr = qrcode.QRCode(
            version = None,
            error_correction = err_correction, box_size = box_size, border = border)
    qr.add_data(int.from_bytes(data, 'big'))
    img = qr.make_image()
    return img.get_image()


@contextmanager
def open_video(idx: int):
    vcap = cv2.VideoCapture(idx)
    try:
        yield vcap
    finally:
        vcap.release()

def capture(idx: int = 0, show_frame: bool = False) -> bytes:
    """Capture a QR code from the default video feed."""
    with open_video(idx) as vcap:
        ## set this implausibly high, until we read the keyframe (which may not be the first frame we see).
        n_frames = 99999999999999
        frames = {}
        while True:
            ret, frame = vcap.read()
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            image = Image.fromarray(gray)

            cv2.imshow("Live Capture Feed", gray)
            if cv2.waitKey(1) == 27: # esc to quit
                break

            for decoded in pyzbar.decode(image):
                try:
                    # Account for zbar error
                    data_int = int(decoded.data)
                except ValueError:
                    continue

                int_size = floor(log2(data_int) / 8) + 1
                bytes = data_int.to_bytes(int_size, 'big')

                ## strip padding
                json_string = bytes.decode('utf-8').rstrip("\x00")
                json_blob = json.loads(json_string)
                if json_blob['frame'] == -1:
                    n_frames = json_blob['data']['frames']
                    logging.info("Keyframe found. Expecting {} frames. ".format(n_frames))
                else:
                    l = len(frames)
                    frames.update({json_blob['frame']: json_blob['data']})
                    if len(frames) > l:
                        logging.info("Found new frame: {}/{}".format(len(frames), n_frames))
                    if len(frames) == n_frames:
                        logging.info('Frame reconstruction complete.')
                        return frames
        logging.info('Frame reconstruction aborted.')
        return frames

@click.group()
def main():
   pass

@main.command()
def version():
  """Print the application version."""
  click.echo("xfer - version {}".format(__VERSION__))

@main.command()
@click.option('--outfile', '-o', is_flag=False, default="out.gif")
@click.option('--duration', '-d', is_flag=False, default=200)
def write(outfile: str, duration: int):
    """
    Take input from stdin and generate animated GIF QR code. 
    """

    frames = []
    input = sys.stdin.read().encode('utf-8')
    length = len(input)
    ptr = 0
    while ptr < length:
      ## chunk data
      data = input[ptr:ptr+CHUNK_SIZE]
      ## json encode (inefficient, but makes handling keyframe easier)
      payload = json.dumps({"frame": len(frames), "data": data.hex()}).encode("utf-8")
      while len(payload) < PAYLOAD_SIZE:
        ## pad data to ensure consistent size qr code
        payload += b'\0'
      ## generate QR and add to array
      frames += [create_qr(payload).convert('P')]
      ptr += CHUNK_SIZE
    ## generate keyframe
    payload = json.dumps({"frame": -1, "data": {"frames": len(frames) }}).encode("utf-8")
    while len(payload) < PAYLOAD_SIZE:
      ## pad keyframe to ensure consistent size qr code
      payload += b'\0'
    im = create_qr(payload).convert('P')
    ## output image
    im.save(outfile, save_all=True, append_images=frames, optimize=False, duration=duration, loop=10)

@main.command()
@click.option('--outfile', '-o', is_flag=False, required=False)
def read(outfile: str):
    """
    Capture QR-code encoded data from webcam. Output defaults to stdout.
    """
    data = capture()
    output = b''
    for idx, val in sorted(data.items()):
      output += bytes.fromhex(val)

    if outfile is None:
      print(output.decode("utf-8"), file=sys.stdout)
    else:
      with open(outfile, 'a+') as fp:
        fp.write(output.decode("utf-8"))
        fp.close()


if __name__ == "__main__":
  logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
  main()
