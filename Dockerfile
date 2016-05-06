FROM ruby:2.3

RUN apt-get update -y && apt-get install -y \
    rake rubygems ruby-sqlite3 libxslt-dev libxml2-dev libsqlite3-dev swig flex bison \
    && rm -rf /var/lib/apt/lists/* && \
    gem update --system && gem update

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY Gemfile /usr/src/app/
RUN bundle install

COPY . /usr/src/app

EXPOSE 2500

CMD ["./instiki"]
