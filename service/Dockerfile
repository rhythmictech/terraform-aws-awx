FROM alpine

COPY SECRET_KEY /etc/tower/SECRET_KEY
COPY environment.sh /etc/tower/conf.d/environment.sh
COPY credentials.py /etc/tower/conf.d/credentials.py
COPY init.sh /root
COPY settings.py /etc/tower/settings.py

RUN cp -r /etc/tower ~ \
    && chmod +x /root/init.sh

WORKDIR /root

CMD sh init.sh
