# frozen_string_literal: true

control 'mongodb components' do
  title 'should be installed'

  # describe package('unzip') do
  #   it { should be_installed }
  # end
  # describe group('mongodb') do
  #   it { should exist }
  # end
  # describe user('mongodb') do
  #   it { should exist }
  # end
  describe group('mongos') do
    it { should exist }
  end
  # describe user('mongos') do
  #   it { should exist }
  # end
  describe directory('/var/lib/mongodb') do
    it { should exist }
    its('group') { should eq 'root' }
  end
  # describe directory('/usr/local/mongodb/dbtools-100.0.1') do
  #   it { should exist }
  #   its('group') { should eq 'root' }
  # end
  # describe file('/usr/local/mongodb/dbtools-100.0.1/bin/mongodump') do
  #   it { should exist }
  #   its('group') { should eq 'root' }
  # end
  # describe file('/usr/local/mongodb/dbtools-100.0.1/bin/bsondump') do
  #   it { should exist }
  #   its('group') { should eq 'root' }
  # end
  describe directory('/tmp/downloads') do
    it { should exist }
  end
  describe directory('/usr/local/mongodb/mongod-8.0.4') do
    it { should exist }
    its('group') { should eq 'root' }
  end
  describe file('/usr/local/mongodb/mongod-8.0.4/bin/mongod') do
    it { should exist }
  end
  describe file('/usr/local/mongodb/mongod-8.0.4/bin/mongos') do
    it { should exist }
  end
  describe directory('/var/lib/mongodb/mongod') do
    it { should exist }
  end
  describe file('/usr/lib/systemd/system/mongod.service') do
    it { should exist }
    its('group') { should eq 'root' }
    its('mode') { should cmp '0644' }
  end
  describe directory('/usr/local/mongodb/kafka-1.1.0') do
    it { should exist }
    its('group') { should eq 'root' }
  end
  # describe file('/usr/lib/mongodb/kafka-1.1.0/lib/mongo-kafka-1.1.0-all.jar') do
  #   it { should exist }
  #   its('group') { should eq 'root' }
  #   its('mode') { should cmp '0644' }
  # end
  describe file('/etc/init.d/disable-transparent-hugepages') do
    it { should exist }
    its('mode') { should cmp '0755' }
  end
  describe file('/sys/kernel/mm/transparent_hugepage/enabled') do
    it { should exist }
    its('group') { should eq 'root' }
    # its('content') { should eq 'always madvise [never]' }
  end
  describe file('/etc/mongodb') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
  end
  describe file('/etc/mongodb/mongod.conf') do
    it { should exist }
    its('mode') { should cmp '0644' }
    # its('owner') { should eq 'mongodb' }
    # its('group') { should eq 'mongodb' }
  end
  describe file('/etc/mongodb/mongos.conf') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('owner') { should eq 'mongos' }
    its('group') { should eq 'mongos' }
  end
  describe file('/etc/default/mongod.sh') do
    it { should exist }
    its('mode') { should cmp '0640' }
  end
end

control 'mongodb runtime' do
  title 'should be running and accept reads + writes'

  describe service('mongod') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(27_017) do
    it { should be_listening }
  end

  describe file('/usr/local/bin/mongosh') do
    it { should exist }
  end

  # `mongosh` responds with a version banner.
  describe command('/usr/local/bin/mongosh --quiet --eval "db.version()"') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/\d+\.\d+\.\d+/) }
  end

  # Round-trip: insert a document, read it back. Each kitchen run starts
  # fresh so no need to clean up between runs.
  mongosh_smoke_js = <<~JS.chomp.tr("\n", ' ')
    db = db.getSiblingDB("inspec_test");
    db.kitchen_smoke.insertOne({name: "ci-write-test"});
    print(db.kitchen_smoke.findOne({name: "ci-write-test"}).name)
  JS

  describe command("/usr/local/bin/mongosh --quiet --eval '#{mongosh_smoke_js}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should include 'ci-write-test' }
  end
end
