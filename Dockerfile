FROM alpine 

USER root

ENV PUBLIC_IP="127.0.0.1"
ENV SUBNET_IP="10.8.0.0"
ENV SUBNET_MASK="255.255.255.0"
ENV SUBNET_CIDR="10.8.0.0/24"
ENV PORT="1194"
ENV PROTOCOL="udp"
ENV PATH="/etc/openvpn-scripts/:${PATH}"

RUN apk add --no-cache openvpn iptables openssl wget ca-certificates curl iputils tar easy-rsa bash
RUN rm -r /etc/openvpn

RUN mkdir -p /run/openvpn/
RUN mkdir -p /var/log/openvpn

COPY ./scripts /etc/openvpn-scripts/
RUN chmod +x /etc/openvpn-scripts/*

#Fix incorrect line endings (Windows CRLF instead of Unix LF)
RUN sed -i 's/\r$//' /etc/openvpn-scripts/*

CMD ["run-server"]
#RUN sysctl -w net.ipv4.ip_forward=1
