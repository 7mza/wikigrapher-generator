FROM python:3.11-slim
RUN apt-get update && apt-get full-upgrade -y && apt-get install wget aria2 pigz -y && apt-get autoremove --purge && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . /app
RUN chmod +x ./*.sh
RUN pip3 install --trusted-host pypi.python.org --upgrade pip -r requirements.txt
RUN pip3 cache purge
ENTRYPOINT ["/bin/bash", "./entrypoint.sh"]
