FROM phusion/passenger-ruby20:0.9.14

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

#   Build system and git.
RUN /build/utilities.sh
#   Ruby support.
RUN /build/ruby2.0.sh
#   Python support.
#RUN /build/python.sh

# ...put your own build instructions here...

# Enable nginx + passenger
RUN rm -f /etc/service/nginx/down

WORKDIR /home/app

# Get PInW
RUN git clone https://github.com/AlgoLab/pinw

# Add configuration to nginx:
RUN cp pinw/nginx-pinw.conf /etc/nginx/sites-enabled/pinw.conf
# TODO: better configuration




# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*