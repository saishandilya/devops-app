FROM tomcat:9  

# Use LABEL to specify metadata
LABEL maintainer="devops@yourcompany.com"

# Copy the WAR file to the Tomcat webapps directory
COPY ./taxi-booking/target/taxi-booking-1.0.1.war /usr/local/tomcat/webapps  

# Expose port 8080 for the Tomcat server
EXPOSE 8080