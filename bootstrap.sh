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
mkdir log

mkdir /tmp/db-dump
tar xf /vagrant/test-data/db-dump.tar -C /tmp/db-dump
mongorestore /tmp/db-dump/depositor-dump 

bundle install
bundle exec resque-pool --daemon
bundle exec rackup -p 9393 -D

