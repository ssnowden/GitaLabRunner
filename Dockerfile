FROM ubuntu:latest

RUN apt update && apt install  openssh-server sudo -y

RUN useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1000 deploymentagent 

RUN  echo 'deploymentagent:testpass123' | chpasswd

RUN service ssh start

CMD ["/usr/sbin/sshd","-D"]
