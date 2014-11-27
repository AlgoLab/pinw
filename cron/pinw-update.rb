# 2 step:

# 1 - Check for updates
#     if there is an update raise the update flag

# 2 - if dev: at scheduled time, if stable after user click
#     - git pull
#     - if version change: stop server, run db:migrate, start server