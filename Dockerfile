FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends
ca-certificates curl git python3 make g++ 
&& rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]
