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
USER app
RUN git clone https://github.com/AlgoLab/pinw
WORKDIR /home/app/pinw
ENV RACK_ENV production

USER root
RUN bundle install

USER app
RUN rake db:setup
RUN whenever -w
USER root
# Add configuration to nginx:
RUN rm /etc/nginx/sites-enabled/default
RUN cp Docker/nginx-pinw.conf /etc/nginx/sites-enabled/pinw.conf
# TODO: better configuration

# TODO: External location for the DB
# Clean up APT when done.
RUN echo "unattended-upgrades	unattended-upgrades/enable_auto_updates	boolean	true" > /root/debconf.tmp
RUN debconf-set-selections /root/debconf.tmp
RUN rm -f /root/debconf.tmp
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80
