#!/usr/bin/env python

import os
import sys

if sys.version_info.major < 3:
    sys.stderr.write('Unsupported version of Python. Use python3.\n')
    sys.exit(1)

from setuptools import setup, find_packages

BASE_DIR = os.path.dirname(__file__)
README_PATH = os.path.join(BASE_DIR, 'README.md')
REQS_PATH = os.path.join(BASE_DIR, 'requirements.txt')

def get_dependencies():
    install_reqs = []
    dep_links = []

    with open(REQS_PATH) as fd:
        reqs = fd.read().splitlines()

        for req in reqs:
            if req.find('+') > -1:
                dep_links.append(req)
            else:
                install_reqs.append(req)
    return install_reqs, dep_links

INSTALL_REQUIRES, DEP_LINKS = get_dependencies()

classifiers = [
    'Operating System :: OS Independent',
    'Programming Language :: Python',
    'Natural Language :: English',
    'Intended Audience :: Developers',
    'Intended Audience :: Financial and Insurance Industry',
    'Programming Language :: Python :: 3',
    ]

setup(
        name = 'xfer',
        version = '0.0.5',
        description = 'Utility to allow out-of-band sending of arbitrary data',
        long_description = open(README_PATH).read(),
        maintainer = 'Chorus One',
        maintainer_email = 'tech@chorus.one',
        url = 'http://chorus.one',
        install_requires = INSTALL_REQUIRES,
        dependency_links = DEP_LINKS,
        zip_safe = False,
        py_modules=['xfer'],
        entry_points = {
            'console_scripts': [
                'xfer = xfer:main',
            ],
        },
        packages = find_packages(exclude=['*test*']),
        test_suite = 'nose.collector',
        platforms = 'POSIX',
        classifiers = classifiers,
    )
