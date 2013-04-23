#!/usr/bin/env bash

apt-get update
apt-get install -y mongodb
apt-get install -y redis-server
apt-get install -y build-essential
apt-get install -y ruby1.9.1 ruby1.9.1-dev
apt-get install -y libxml2-dev libxslt-dev
apt-get install -y htop

gem install bundler

cd /vagrant

mkdir pdfs
mkdir xmls

bundle install
bundle exec rackup -p 9393 -D

QUEUE=extract nohup bundle exec rake resque:work &

