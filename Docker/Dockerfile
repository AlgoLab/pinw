FROM phusion/passenger-ruby20:0.9.18

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

#   Build system and ruby
RUN /pd_build/utilities.sh
RUN /pd_build/ruby2.2.sh
RUN ruby-switch --set ruby2.2
# Enable nginx + passenger
RUN rm -f /etc/service/nginx/down


# Get PInW
USER app
WORKDIR /home/app
RUN git clone https://github.com/AlgoLab/pinw
RUN mkdir data
WORKDIR /home/app/pinw
ENV RACK_ENV production

USER root
RUN bundle install

USER app
RUN rake db:setup

# New crontab:
USER root
RUN cp Docker/crontab /etc/crontab

# Pinw cron jobs:
USER app
RUN whenever -w

# Add configuration to nginx:
USER root
RUN rm /etc/nginx/sites-enabled/default
ADD Docker/nginx-pinw.conf /etc/nginx/sites-enabled/pinw.conf


# TODO: External location for the DB
# Clean up APT when done.
RUN apt-get clean
COPY init-ssh.sh /etc/my_init.d/init-ssh.sh

EXPOSE 80
