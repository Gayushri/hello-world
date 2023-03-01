FROM tomcat:8-jdk8

LABEL maintainer="praveengayathri1009@gmail.com"

COPY ./webapp/target/*.war /usr/local/tomcat/webapps/

EXPOSE 8080

CMD ["catalina.sh", "run"]



