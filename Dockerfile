# define base image
FROM python:3.7.4-alpine3.10

# install tools required for project
RUN apk update && apk upgrade && \
    apk add --no-cache bash git

# setup environment variables
ENV WORKDIR=/tmp
ENV GitRepo=https://github.com/canvassanalytics/k8s-django-rest-take-home.git

# set work directory & get working code
RUN mkdir -p $WORKDIR
RUN git clone $GitRepo $WORKDIR

# modify settings.py to add the dynamic ALLOWED_HOSTS variable. This is required to whitelist the AWS ALB DNS
RUN sed -i "/ALLOWED_HOSTS/ s/^#*/#/" $WORKDIR/project/settings.py
RUN sed -i "$ a ALLOWED_HOSTS = [os.environ.get('LOAD_BALANCER_IP')]" $WORKDIR/project/settings.py

# setup the environment and install python dependencies
RUN pip install --upgrade pip
RUN pip install virtualenv
CMD virtualenv venv -p python3
CMD source venv/bin/activate
RUN pip install -r /tmp/requirements.txt

# start server
EXPOSE 8000
CMD python3 manage.py makemigrations
CMD python3 manage.py migrate
CMD ["python3", "/tmp/manage.py", "runserver", "0.0.0.0:8000"]