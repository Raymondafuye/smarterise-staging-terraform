FROM --platform=linux/x86_64 amazonlinux:2

RUN yum update -y &&     yum groupinstall -y "Development Tools" &&     yum install -y python39 python39-devel python39-pip

RUN mkdir -p /output/python/lib/python3.9/site-packages

COPY requirements.txt /requirements.txt

RUN python3.9 -m pip install --upgrade pip &&     python3.9 -m pip install -r /requirements.txt -t /output/python/lib/python3.9/site-packages

RUN cd /output && zip -r /python_packages_layer.zip .
