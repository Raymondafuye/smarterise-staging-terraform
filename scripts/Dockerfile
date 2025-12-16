FROM python:3.9.16-bullseye

RUN mkdir src

WORKDIR /src

COPY . .

RUN pip install -r requirements.txt

ENTRYPOINT ["/bin/bash"]