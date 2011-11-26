#!/bin/bash
sudo python setup.py install && sudo /etc/init.d/apache2 force-reload

