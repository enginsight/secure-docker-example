# Some old deprecated centos 7 image.
FROM centos:7.4.1708

# How ever your dockerfiles look like...

#ADD app.js /var/www/app.js
#CMD ["/usr/bin/node", "/var/www/app.js"] 

# TODO: Copy the vulnerabilities script to the docker container.
COPY vulnerabilities.sh /
# TODO END

#EXPOSE 8080